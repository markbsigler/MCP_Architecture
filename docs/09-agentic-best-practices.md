# Agentic Best Practices

**Version:** 1.0.0  
**Last Updated:** November 18, 2025  
**Status:** Draft

## Introduction

MCP servers are designed to work with AI agents, providing tools and context that enable agents to accomplish complex tasks. This document covers best practices for designing agentic systems including context management, user elicitation patterns, resource templates, prompt engineering, and agent workflow design.

## Context Management

### Maintaining Conversation Context

```python
# src/mcp_server/context.py
"""Context management for agentic interactions."""

from typing import Dict, List, Optional, Any
from datetime import datetime
from pydantic import BaseModel
import structlog

logger = structlog.get_logger()

class Message(BaseModel):
    """Conversation message."""
    role: str  # "user", "assistant", "system"
    content: str
    timestamp: datetime = datetime.utcnow()
    metadata: Dict[str, Any] = {}

class ConversationContext(BaseModel):
    """Conversation context tracker."""
    
    conversation_id: str
    user_id: str
    messages: List[Message] = []
    state: Dict[str, Any] = {}
    created_at: datetime = datetime.utcnow()
    updated_at: datetime = datetime.utcnow()
    
    def add_message(
        self,
        role: str,
        content: str,
        **metadata
    ):
        """Add message to conversation."""
        message = Message(
            role=role,
            content=content,
            metadata=metadata
        )
        self.messages.append(message)
        self.updated_at = datetime.utcnow()
        
        logger.debug(
            "context_message_added",
            conversation_id=self.conversation_id,
            role=role,
            message_count=len(self.messages)
        )
    
    def update_state(self, key: str, value: Any):
        """Update conversation state."""
        self.state[key] = value
        self.updated_at = datetime.utcnow()
        
        logger.debug(
            "context_state_updated",
            conversation_id=self.conversation_id,
            key=key
        )
    
    def get_state(self, key: str, default: Any = None) -> Any:
        """Get state value."""
        return self.state.get(key, default)
    
    def get_recent_messages(
        self,
        n: int = 10,
        role: Optional[str] = None
    ) -> List[Message]:
        """Get recent messages, optionally filtered by role."""
        messages = self.messages[-n:]
        if role:
            messages = [m for m in messages if m.role == role]
        return messages
    
    def to_prompt_context(self) -> str:
        """Format context for prompt inclusion."""
        context_parts = []
        
        # Add conversation history
        recent = self.get_recent_messages(n=5)
        if recent:
            context_parts.append("## Recent Conversation")
            for msg in recent:
                context_parts.append(f"**{msg.role}**: {msg.content}")
        
        # Add relevant state
        if "current_assignment" in self.state:
            assignment = self.state["current_assignment"]
            context_parts.append(f"\n## Current Assignment")
            context_parts.append(f"ID: {assignment['id']}")
            context_parts.append(f"Title: {assignment['title']}")
        
        return "\n".join(context_parts)

class ContextManager:
    """Manage conversation contexts."""
    
    def __init__(self):
        self.contexts: Dict[str, ConversationContext] = {}
    
    def get_or_create(
        self,
        conversation_id: str,
        user_id: str
    ) -> ConversationContext:
        """Get or create conversation context."""
        if conversation_id not in self.contexts:
            self.contexts[conversation_id] = ConversationContext(
                conversation_id=conversation_id,
                user_id=user_id
            )
            logger.info(
                "context_created",
                conversation_id=conversation_id,
                user_id=user_id
            )
        
        return self.contexts[conversation_id]
    
    def get(self, conversation_id: str) -> Optional[ConversationContext]:
        """Get existing context."""
        return self.contexts.get(conversation_id)
    
    def delete(self, conversation_id: str):
        """Delete conversation context."""
        if conversation_id in self.contexts:
            del self.contexts[conversation_id]
            logger.info("context_deleted", conversation_id=conversation_id)

# Global context manager
context_manager = ContextManager()
```

### Using Context in Tools

```python
from mcp_server.context import context_manager

@mcp.tool()
async def create_assignment_with_context(
    conversation_id: str,
    title: str,
    assignee: str,
    description: Optional[str] = None
) -> dict:
    """
    Create assignment with conversation context.
    
    This tool tracks the created assignment in the conversation
    context so that follow-up questions can reference it.
    """
    
    # Get conversation context
    context = context_manager.get_or_create(conversation_id, assignee)
    
    # Create assignment
    assignment = await backend.create_assignment(
        title=title,
        assignee=assignee,
        description=description
    )
    
    # Update context
    context.update_state("current_assignment", assignment.to_dict())
    context.add_message(
        role="assistant",
        content=f"Created assignment '{title}' with ID {assignment.id}",
        assignment_id=assignment.id
    )
    
    return {
        "success": True,
        "data": assignment.to_dict(),
        "context": {
            "message": "Assignment created and tracked in conversation context"
        }
    }

@mcp.tool()
async def update_current_assignment(
    conversation_id: str,
    **updates
) -> dict:
    """
    Update the current assignment from conversation context.
    
    This tool uses the conversation context to determine which
    assignment to update, avoiding the need to specify the ID.
    """
    
    # Get conversation context
    context = context_manager.get(conversation_id)
    if not context:
        raise ValueError("No active conversation found")
    
    # Get current assignment from context
    current_assignment = context.get_state("current_assignment")
    if not current_assignment:
        raise ValueError("No current assignment in context")
    
    assignment_id = current_assignment["id"]
    
    # Update assignment
    updated = await backend.update_assignment(assignment_id, **updates)
    
    # Update context
    context.update_state("current_assignment", updated.to_dict())
    context.add_message(
        role="assistant",
        content=f"Updated assignment {assignment_id}",
        updates=updates
    )
    
    return {
        "success": True,
        "data": updated.to_dict()
    }
```

## User Elicitation Patterns

### Progressive Information Gathering

```python
@mcp.tool()
async def create_assignment_interactive(
    conversation_id: str,
    title: Optional[str] = None,
    assignee: Optional[str] = None,
    priority: Optional[int] = None,
    description: Optional[str] = None
) -> dict:
    """
    Create assignment with progressive elicitation.
    
    This tool guides the agent to gather required information
    progressively rather than failing on missing data.
    """
    
    context = context_manager.get_or_create(conversation_id, "system")
    
    # Track gathering state
    gathering_state = context.get_state("assignment_gathering", {})
    
    # Update with provided values
    if title:
        gathering_state["title"] = title
    if assignee:
        gathering_state["assignee"] = assignee
    if priority:
        gathering_state["priority"] = priority
    if description:
        gathering_state["description"] = description
    
    context.update_state("assignment_gathering", gathering_state)
    
    # Check what's still needed
    missing = []
    if "title" not in gathering_state:
        missing.append("title")
    if "assignee" not in gathering_state:
        missing.append("assignee")
    
    if missing:
        # Return guidance for agent to elicit missing information
        return {
            "success": False,
            "status": "incomplete",
            "missing_fields": missing,
            "gathered_so_far": gathering_state,
            "next_prompt": _generate_elicitation_prompt(missing),
            "message": "Please provide the missing information"
        }
    
    # All required information gathered, create assignment
    assignment = await backend.create_assignment(
        title=gathering_state["title"],
        assignee=gathering_state["assignee"],
        priority=gathering_state.get("priority", 3),
        description=gathering_state.get("description")
    )
    
    # Clear gathering state
    context.update_state("assignment_gathering", {})
    context.update_state("current_assignment", assignment.to_dict())
    
    return {
        "success": True,
        "data": assignment.to_dict(),
        "message": "Assignment created successfully"
    }

def _generate_elicitation_prompt(missing_fields: List[str]) -> str:
    """Generate prompt to elicit missing information."""
    prompts = {
        "title": "What should the title of the assignment be?",
        "assignee": "Who should this assignment be assigned to? (email address)",
        "priority": "What priority should this have? (1-5, default is 3)",
        "description": "Would you like to add a description?"
    }
    
    if len(missing_fields) == 1:
        return prompts[missing_fields[0]]
    else:
        return "Please provide: " + ", ".join(
            f"{field} ({prompts[field]})"
            for field in missing_fields
        )
```

### Confirmation Patterns

```python
@mcp.tool()
async def delete_assignment_with_confirmation(
    conversation_id: str,
    assignment_id: str,
    confirmed: bool = False
) -> dict:
    """
    Delete assignment with confirmation.
    
    For destructive operations, require explicit confirmation
    to prevent accidental data loss.
    """
    
    context = context_manager.get_or_create(conversation_id, "system")
    
    if not confirmed:
        # Get assignment details for confirmation
        assignment = await backend.get_assignment(assignment_id)
        
        if not assignment:
            return {
                "success": False,
                "error": "Assignment not found"
            }
        
        # Store pending deletion in context
        context.update_state("pending_deletion", {
            "type": "assignment",
            "id": assignment_id,
            "details": assignment.to_dict()
        })
        
        return {
            "success": False,
            "status": "confirmation_required",
            "assignment": assignment.to_dict(),
            "message": (
                f"Are you sure you want to delete assignment '{assignment.title}'? "
                f"This action cannot be undone. "
                f"Call this tool again with confirmed=True to proceed."
            )
        }
    
    # Verify this is the pending deletion
    pending = context.get_state("pending_deletion")
    if not pending or pending["id"] != assignment_id:
        return {
            "success": False,
            "error": "No pending deletion for this assignment"
        }
    
    # Proceed with deletion
    await backend.delete_assignment(assignment_id)
    
    # Clear pending deletion
    context.update_state("pending_deletion", None)
    
    return {
        "success": True,
        "message": f"Assignment {assignment_id} deleted"
    }
```

## Resource Templates

### Structured Templates for Common Operations

```python
# src/mcp_server/templates.py
"""Resource templates for agentic operations."""

from typing import Dict, Any, List
from pydantic import BaseModel, Field

class AssignmentTemplate(BaseModel):
    """Template for creating assignments."""
    
    title: str = Field(..., description="Assignment title")
    assignee: str = Field(..., description="Assignee email")
    priority: int = Field(3, ge=1, le=5, description="Priority 1-5")
    description: str = Field("", description="Detailed description")
    tags: List[str] = Field(default=[], description="Tags for categorization")
    due_date: Optional[str] = Field(None, description="ISO 8601 due date")
    
    class Config:
        schema_extra = {
            "examples": [
                {
                    "title": "Implement user authentication",
                    "assignee": "dev@example.com",
                    "priority": 4,
                    "description": "Add OAuth 2.0 authentication to the API",
                    "tags": ["security", "api"],
                    "due_date": "2025-12-01T00:00:00Z"
                }
            ]
        }

class ReleaseTemplate(BaseModel):
    """Template for creating releases."""
    
    name: str = Field(..., description="Release name (semantic version)")
    description: str = Field(..., description="Release notes")
    target_environment: str = Field(..., description="Target environment")
    scheduled_at: Optional[str] = Field(None, description="Scheduled deployment time")
    included_changes: List[str] = Field(default=[], description="List of changes")
    
    class Config:
        schema_extra = {
            "examples": [
                {
                    "name": "v1.2.0",
                    "description": "Feature release with authentication improvements",
                    "target_environment": "production",
                    "scheduled_at": "2025-12-01T10:00:00Z",
                    "included_changes": [
                        "Added OAuth 2.0 support",
                        "Fixed rate limiting bug",
                        "Updated documentation"
                    ]
                }
            ]
        }

@mcp.tool()
async def create_assignment_from_template(
    template: AssignmentTemplate
) -> dict:
    """
    Create assignment from structured template.
    
    This tool accepts a fully-formed template, making it easy
    for agents to construct valid assignments.
    """
    
    assignment = await backend.create_assignment(
        title=template.title,
        assignee=template.assignee,
        priority=template.priority,
        description=template.description,
        tags=template.tags,
        due_date=template.due_date
    )
    
    return {
        "success": True,
        "data": assignment.to_dict()
    }
```

## Prompt Engineering for Tools

### Tool Descriptions

```python
@mcp.tool()
async def search_assignments(
    query: Optional[str] = None,
    assignee: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[int] = None,
    tags: Optional[List[str]] = None,
    created_after: Optional[str] = None,
    created_before: Optional[str] = None
) -> dict:
    """
    Search assignments with flexible criteria.
    
    This tool supports searching assignments by multiple criteria.
    All parameters are optional - omit parameters you don't need to filter by.
    
    Search Strategies:
    - **Text search**: Use `query` to search titles and descriptions
    - **Filter by assignee**: Use `assignee` to find assignments for a specific user
    - **Filter by status**: Use `status` to find assignments in a specific state
    - **Filter by priority**: Use `priority` to find high/low priority items
    - **Filter by tags**: Use `tags` to find assignments with specific tags
    - **Time range**: Use `created_after`/`created_before` for date filtering
    
    Examples:
    - Find all high priority assignments: `priority=5`
    - Find my assignments: `assignee="user@example.com"`
    - Find assignments about authentication: `query="authentication"`
    - Find recent urgent assignments: `priority=5, created_after="2025-11-01"`
    
    Args:
        query: Text to search in title and description
        assignee: Filter by assignee email address
        status: Filter by status (pending, in_progress, completed)
        priority: Filter by priority level (1-5)
        tags: Filter by tags (returns assignments with ANY of these tags)
        created_after: ISO 8601 timestamp for start of date range
        created_before: ISO 8601 timestamp for end of date range
    
    Returns:
        List of matching assignments with metadata
    """
    
    # Build search criteria
    criteria = {}
    if query:
        criteria["query"] = query
    if assignee:
        criteria["assignee"] = assignee
    if status:
        criteria["status"] = status
    if priority:
        criteria["priority"] = priority
    if tags:
        criteria["tags"] = tags
    if created_after:
        criteria["created_after"] = created_after
    if created_before:
        criteria["created_before"] = created_before
    
    results = await backend.search_assignments(**criteria)
    
    return {
        "success": True,
        "data": [assignment.to_dict() for assignment in results],
        "count": len(results),
        "criteria": criteria
    }
```

### Guided Tool Usage

```python
@mcp.tool()
async def create_assignment_guided(
    title: str,
    assignee: str,
    priority: Optional[int] = None,
    description: Optional[str] = None
) -> dict:
    """
    Create a new assignment (GUIDED VERSION).
    
    This tool creates a task assignment for a team member. Use this when a user
    wants to assign work, create a task, or delegate something to someone.
    
    **When to use this tool:**
    - User says: "Create a task for..."
    - User says: "Assign X to Y"
    - User says: "I need someone to work on..."
    
    **Required information:**
    - Title: A clear, concise description of the task
    - Assignee: The email address of the person to assign to
    
    **Optional information:**
    - Priority: How urgent is this? (1=low, 5=critical, default=3)
    - Description: Additional details about the task
    
    **Agent guidance:**
    If the user doesn't provide all required information, ask for it:
    - "What would you like to call this assignment?"
    - "Who should I assign this to?"
    
    For priority, you can infer from language:
    - "urgent", "critical", "ASAP" → priority 5
    - "important", "high priority" → priority 4
    - "when you get a chance", "low priority" → priority 1-2
    - If not mentioned → use default (3)
    
    Args:
        title: Clear task title (required)
        assignee: Email of person to assign to (required)
        priority: Urgency level 1-5 (optional, default 3)
        description: Additional task details (optional)
    
    Returns:
        Created assignment with ID and details
    """
    
    # Validate priority
    if priority is not None:
        if priority < 1 or priority > 5:
            return {
                "success": False,
                "error": "invalid_priority",
                "message": "Priority must be between 1 and 5",
                "guidance": "Ask the user to clarify the priority level"
            }
    
    # Create assignment
    assignment = await backend.create_assignment(
        title=title,
        assignee=assignee,
        priority=priority or 3,
        description=description
    )
    
    return {
        "success": True,
        "data": assignment.to_dict(),
        "message": f"Created assignment '{title}' for {assignee}",
        "next_steps": [
            f"You can update this assignment with: update_assignment('{assignment.id}', ...)",
            f"You can view details with: get_assignment('{assignment.id}')"
        ]
    }
```

## Agent Workflow Patterns

### Multi-Step Workflows

```python
@mcp.tool()
async def create_release_workflow(
    release_name: str,
    environment: str,
    assignments: List[str]
) -> dict:
    """
    Execute a complete release workflow.
    
    This tool orchestrates multiple steps:
    1. Validate all assignments are completed
    2. Create release
    3. Generate release notes
    4. Schedule deployment
    5. Send notifications
    
    Agents should use this for end-to-end release management.
    """
    
    workflow_id = str(uuid.uuid4())
    steps = []
    
    # Step 1: Validate assignments
    steps.append({"step": "validate_assignments", "status": "running"})
    incomplete = []
    for assignment_id in assignments:
        assignment = await backend.get_assignment(assignment_id)
        if assignment.status != "completed":
            incomplete.append(assignment_id)
    
    if incomplete:
        steps[-1]["status"] = "failed"
        return {
            "success": False,
            "workflow_id": workflow_id,
            "steps": steps,
            "error": "incomplete_assignments",
            "incomplete_assignments": incomplete,
            "message": "Cannot create release with incomplete assignments"
        }
    
    steps[-1]["status"] = "completed"
    
    # Step 2: Create release
    steps.append({"step": "create_release", "status": "running"})
    release = await backend.create_release(
        name=release_name,
        environment=environment,
        assignments=assignments
    )
    steps[-1].update({
        "status": "completed",
        "release_id": release.id
    })
    
    # Step 3: Generate release notes
    steps.append({"step": "generate_notes", "status": "running"})
    notes = await generate_release_notes(assignments)
    await backend.update_release(release.id, notes=notes)
    steps[-1]["status"] = "completed"
    
    # Step 4: Schedule deployment
    steps.append({"step": "schedule_deployment", "status": "running"})
    deployment = await backend.schedule_deployment(
        release_id=release.id,
        environment=environment
    )
    steps[-1].update({
        "status": "completed",
        "deployment_id": deployment.id
    })
    
    # Step 5: Send notifications
    steps.append({"step": "notify", "status": "running"})
    await send_release_notification(release, deployment)
    steps[-1]["status"] = "completed"
    
    return {
        "success": True,
        "workflow_id": workflow_id,
        "release_id": release.id,
        "deployment_id": deployment.id,
        "steps": steps,
        "message": f"Release {release_name} created and scheduled for {environment}"
    }
```

### Error Recovery

```python
@mcp.tool()
async def recover_from_error(
    conversation_id: str,
    error_details: dict
) -> dict:
    """
    Attempt to recover from an error.
    
    This tool helps agents handle errors gracefully by:
    1. Logging the error for debugging
    2. Checking if recovery is possible
    3. Suggesting alternative approaches
    4. Updating conversation context
    
    Agents should call this when encountering errors in other tools.
    """
    
    context = context_manager.get_or_create(conversation_id, "system")
    
    # Log error
    logger.error(
        "agent_error",
        conversation_id=conversation_id,
        error=error_details
    )
    
    # Update context
    context.add_message(
        role="system",
        content=f"Error occurred: {error_details.get('message', 'Unknown error')}",
        error=error_details
    )
    
    # Analyze error and suggest recovery
    error_type = error_details.get("type")
    
    if error_type == "not_found":
        return {
            "success": True,
            "recovery_suggestion": "resource_not_found",
            "actions": [
                "Verify the ID is correct",
                "Search for the resource instead",
                "Create a new resource if needed"
            ],
            "message": "The resource was not found. Try searching or creating a new one."
        }
    
    elif error_type == "validation_error":
        validation_errors = error_details.get("validation_errors", [])
        return {
            "success": True,
            "recovery_suggestion": "fix_validation",
            "validation_errors": validation_errors,
            "actions": [
                f"Fix {error['field']}: {error['message']}"
                for error in validation_errors
            ],
            "message": "There were validation errors. Please correct them and try again."
        }
    
    elif error_type == "permission_denied":
        return {
            "success": True,
            "recovery_suggestion": "permission_denied",
            "actions": [
                "Ask the user to grant necessary permissions",
                "Try a different operation that doesn't require this permission",
                "Contact an administrator"
            ],
            "message": "Permission denied. The user may need different access rights."
        }
    
    else:
        return {
            "success": True,
            "recovery_suggestion": "unknown_error",
            "actions": [
                "Retry the operation",
                "Try an alternative approach",
                "Ask the user for clarification"
            ],
            "message": "An unexpected error occurred. Consider retrying or trying a different approach."
        }
```

## Best Practices Summary

### Tool Design Principles

1. **Clear Naming**: Use descriptive, action-oriented names
2. **Rich Documentation**: Provide comprehensive docstrings with examples
3. **Progressive Disclosure**: Allow agents to gather information incrementally
4. **Confirmation for Destructive Actions**: Require explicit confirmation
5. **Context Awareness**: Track and use conversation context
6. **Error Guidance**: Provide actionable error messages and recovery suggestions
7. **Templates**: Offer structured templates for complex operations
8. **Workflow Support**: Provide tools for common multi-step workflows

### Agent Interaction Guidelines

1. **Maintain Context**: Track conversation state across tool calls
2. **Elicit Gracefully**: Ask for missing information progressively
3. **Confirm Destructive Actions**: Always confirm before deleting or modifying
4. **Handle Errors**: Provide recovery suggestions and alternatives
5. **Use Templates**: Leverage templates for consistent data structures
6. **Follow Workflows**: Use workflow tools for complex operations
7. **Log for Debugging**: Log all agent interactions for troubleshooting

## Multi-Agent Coordination

### Agent Handoff Pattern

When one agent should delegate to another specialist:

```python
@mcp.tool()
async def escalate_to_specialist(
    task_id: str,
    reason: str,
    specialist_type: str
) -> dict:
    """
    Hand off current task to specialist agent.
    
    Use when:
    - Current agent lacks required capability
    - Task requires domain expertise  
    - Human escalation needed
    
    Args:
        task_id: Current task identifier
        reason: Why escalation is needed
        specialist_type: Type of specialist (security, sre, qa, human)
    """
    handoff = await agent_registry.create_handoff(
        from_agent=current_agent_id,
        to_agent_type=specialist_type,
        task_id=task_id,
        context={
            "reason": reason,
            "history": get_conversation_context(),
            "attempted_actions": get_agent_actions()
        }
    )
    
    return {
        "success": True,
        "handoff_id": handoff.id,
        "specialist_agent": handoff.assigned_agent,
        "message": f"Task escalated to {specialist_type} agent"
    }
```

### Consensus Pattern

Multiple agents validate critical decisions:

```python
@mcp.tool()
async def propose_production_deployment(
    release_id: str,
    changes: list[dict]
) -> dict:
    """
    Propose deployment requiring multi-agent approval.
    
    Requires consensus from:
    - Security agent (vulnerability scan)
    - SRE agent (capacity check)  
    - QA agent (test coverage validation)
    """
    proposal = await create_deployment_proposal(release_id, changes)
    
    # Parallel agent validation
    results = await asyncio.gather(
        security_agent.validate(proposal),
        sre_agent.validate(proposal),
        qa_agent.validate(proposal),
        return_exceptions=True
    )
    
    approvals = [r for r in results if not isinstance(r, Exception) and r.approved]
    rejections = [r for r in results if not isinstance(r, Exception) and not r.approved]
    errors = [r for r in results if isinstance(r, Exception)]
    
    if len(approvals) == 3:
        return {
            "status": "approved",
            "proposal_id": proposal.id,
            "approvals": [a.agent_id for a in approvals],
            "message": "All validations passed"
        }
    else:
        return {
            "status": "rejected",
            "proposal_id": proposal.id,
            "approvals": [a.agent_id for a in approvals],
            "blockers": [
                {"agent": r.agent_id, "reason": r.reason}
                for r in rejections
            ],
            "errors": [str(e) for e in errors],
            "message": "Deployment blocked by validation failures"
        }
```

### Collaborative Problem Solving

```python
@mcp.tool()
async def solve_complex_issue(
    issue_id: str,
    max_iterations: int = 5
) -> dict:
    """
    Collaborative multi-agent problem solving.
    
    Agents work together iteratively:
    1. Diagnostic agent analyzes problem
    2. Research agent finds solutions
    3. Planning agent creates action plan
    4. Execution agent implements solution
    5. Validation agent verifies fix
    """
    issue = await get_issue(issue_id)
    iteration = 0
    
    while iteration < max_iterations:
        # Step 1: Diagnosis
        diagnosis = await diagnostic_agent.analyze(issue)
        
        if diagnosis.root_cause_found:
            # Step 2: Research solutions
            solutions = await research_agent.find_solutions(
                diagnosis.root_cause
            )
            
            # Step 3: Plan
            plan = await planning_agent.create_plan(
                diagnosis,
                solutions
            )
            
            # Step 4: Execute
            result = await execution_agent.execute(plan)
            
            # Step 5: Validate
            validation = await validation_agent.verify(result)
            
            if validation.success:
                return {
                    "status": "resolved",
                    "issue_id": issue_id,
                    "iterations": iteration + 1,
                    "solution": plan,
                    "result": result
                }
        
        iteration += 1
    
    return {
        "status": "unresolved",
        "issue_id": issue_id,
        "iterations": iteration,
        "message": "Max iterations reached without resolution"
    }
```

## Summary

Agentic best practices ensure effective AI agent interactions:

- **Context Management**: Track conversation state and user intent
- **User Elicitation**: Gather information progressively and gracefully
- **Resource Templates**: Provide structured templates for common operations
- **Prompt Engineering**: Write clear, actionable tool descriptions
- **Workflow Patterns**: Support multi-step workflows with error recovery
- **Error Handling**: Provide actionable guidance for error recovery
- **Multi-Agent Coordination**: Enable agent handoffs and consensus
- **Collaborative Problem Solving**: Orchestrate multiple specialist agents

---

**Congratulations!** You've completed the MCP Architecture documentation. These guidelines provide a comprehensive foundation for building production-ready MCP servers with enterprise-grade security, observability, and operational excellence.
