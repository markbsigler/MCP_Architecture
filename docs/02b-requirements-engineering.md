# Requirements Engineering Standards

**Version:** 1.3.0  
**Last Updated:** November 19, 2025  
**Status:** Draft

## Overview

Requirements engineering is a critical foundation for MCP server development, ensuring that tools, prompts, and resources meet stakeholder needs while maintaining clarity, testability, and traceability. This section establishes standards for documenting requirements using industry-proven approaches including EARS syntax, Agile story formats, and ISO/IEEE 29148 principles.

**Related Documentation:**

- [Tool Implementation Standards](03-tool-implementation.md) - Implementing tools from requirements
- [Testing Strategy](04-testing-strategy.md) - Verifying requirements satisfaction
- [Development Lifecycle](06-development-lifecycle.md) - Requirements in the development process

---

## Requirements Engineering Fundamentals

### ISO/IEEE 29148 Principles

[ISO/IEC/IEEE 29148:2018](https://standards.ieee.org/ieee/29148/6937/) provides international standards for requirements engineering processes and products. Key principles include:

**Requirements Quality Characteristics:**

- **Necessary**: Each requirement addresses a stakeholder need
- **Verifiable**: Can be proven through inspection, analysis, demonstration, or test
- **Attainable**: Technically feasible within constraints
- **Unambiguous**: Has one and only one interpretation
- **Complete**: Fully describes required capability
- **Consistent**: Does not contradict other requirements
- **Traceable**: Can be linked to source and downstream artifacts

**Requirements Information Items:**

- Stakeholder Requirements: Needs from users, operators, maintainers
- System Requirements: What the system must do
- Software Requirements: What the software components must do
- Interface Requirements: How components interact

### Requirements Hierarchy for MCP Servers

```text
┌─────────────────────────────────────────────────┐
│ Business Requirements                           │
│ (Why: Business objectives, ROI)                 │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│ Stakeholder Requirements                        │
│ (Who & What: User needs, use cases)             │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│ System Requirements                             │
│ (What: Functional & non-functional)             │
└───────────────────┬─────────────────────────────┘
                    │
        ┌───────────┴──────────┐
        │                      │
┌───────▼─────────┐   ┌────────▼────────┐
│ Tool            │   │ Resource        │
│ Requirements    │   │ Requirements    │
└───────┬─────────┘   └────────┬────────┘
        │                      │
┌───────▼──────────────────────▼────────┐
│ Acceptance Criteria                   │
│ (How to verify)                       │
└───────────────────────────────────────┘
```

---

## EARS: Easy Approach to Requirements Syntax

[EARS (Easy Approach to Requirements Syntax)](https://alistairmavin.com/ears/) provides structured patterns for writing clear, unambiguous requirements. Developed at Rolls-Royce PLC and adopted by organizations including Airbus, NASA, Bosch, Intel, and Siemens.

### EARS Benefits for MCP Development

- **Clarity**: Structured syntax reduces ambiguity
- **Consistency**: All requirements follow same patterns
- **Testability**: Clear conditions and responses enable verification
- **Global Teams**: Especially effective for non-native English speakers
- **Lightweight**: No special tools required

### EARS Patterns

#### 1. Ubiquitous Requirements

Requirements that are always active (no conditional keywords).

**Syntax:**

```text
The <system name> shall <system response>
```

**MCP Examples:**

```text
The file_access_server shall support files up to 100MB.

The database_tool shall return results in JSON format.

The authentication_service shall use JWT tokens.

The search_resource shall respond within 2 seconds for 95% of requests.
```

**When to Use:**

- Constant constraints (size limits, formats, protocols)
- Always-active capabilities
- Performance requirements
- Interface specifications

#### 2. State-Driven Requirements

Requirements active while a specified state remains true. Use keyword **"While"**.

**Syntax:**

```text
While <precondition(s)>, the <system name> shall <system response>
```

**MCP Examples:**

```text
While the user is not authenticated, the mcp_server shall reject all tool invocations.

While a file is being uploaded, the file_tool shall display upload progress.

While the database connection is unavailable, the query_tool shall return cached results.

While rate limit is exceeded, the api_gateway shall return HTTP 429 status.
```

**When to Use:**

- Behavior dependent on system state
- Conditional functionality
- Degraded mode operations
- Feature availability

#### 3. Event-Driven Requirements

Requirements specifying response to triggering events. Use keyword **"When"**.

**Syntax:**

```text
When <trigger>, the <system name> shall <system response>
```

**MCP Examples:**

```text
When a tool execution fails, the mcp_server shall log the error with full context.

When a user requests a resource, the resource_handler shall validate permissions before retrieval.

When a prompt is invoked, the prompt_manager shall validate all required parameters.

When authentication fails, the server shall wait 1 second before responding.
```

**When to Use:**

- Response to user actions
- Handling external events
- Error conditions
- State transitions

#### 4. Optional Feature Requirements

Requirements for optional system features. Use keyword **"Where"**.

**Syntax:**

```text
Where <feature is included>, the <system name> shall <system response>
```

**MCP Examples:**

```text
Where caching is enabled, the mcp_server shall store results for 5 minutes.

Where multi-tenancy is configured, the server shall isolate data by tenant_id.

Where observability is enabled, the tool shall emit OpenTelemetry traces.

Where admin mode is active, the server shall expose debug endpoints.
```

**When to Use:**

- Configurable features
- Optional modules
- Plugin capabilities
- Environment-specific behavior

#### 5. Unwanted Behavior Requirements

Requirements specifying response to undesired situations. Use keywords **"If"** and **"Then"**.

**Syntax:**

```text
If <trigger>, then the <system name> shall <system response>
```

**MCP Examples:**

```text
If an invalid JWT token is provided, then the server shall return a 401 Unauthorized error.

If a tool execution times out, then the server shall cancel the operation and return an error.

If a resource URI is malformed, then the server shall return a validation error with details.

If PII is detected in logs, then the logging system shall mask sensitive data.
```

**When to Use:**

- Error handling
- Security violations
- Invalid inputs
- Failure modes

#### 6. Complex Requirements

Combining multiple EARS keywords for richer behavior.

**Syntax:**

```text
While <precondition(s)>, When <trigger>, the <system name> shall <system response>

While <precondition(s)>, If <trigger>, then the <system name> shall <system response>
```

**MCP Examples:**

```text
While a file upload is in progress, when the connection is lost, the file_tool shall save partial progress and enable resume.

While the user has admin privileges, when a dangerous operation is requested, the server shall require additional confirmation.

Where rate limiting is enabled, if the limit is exceeded, then the server shall queue requests up to 100 entries.

While in read-only mode, if a write operation is attempted, then the server shall return an error with explanation.
```

**When to Use:**

- Complex operational scenarios
- Multi-condition logic
- Sophisticated error handling
- Feature interactions

---

## Agile User Stories

### Story Format

User stories capture requirements from the user's perspective using the standard format:

```text
As a <user role>,
I want <capability>,
So that <business value>.
```

### MCP-Specific Story Examples

**Tool Development:**

```text
As a developer,
I want to create a database query tool,
So that AI agents can retrieve data without direct database access.
```

**Resource Implementation:**

```text
As a data analyst,
I want to access configuration files as resources,
So that the AI can understand system settings when making recommendations.
```

**Prompt Creation:**

```text
As a project manager,
I want a structured code review prompt,
So that I can consistently evaluate pull requests.
```

**Security Feature:**

```text
As a security engineer,
I want all tool invocations to be logged with user context,
So that I can audit actions and investigate incidents.
```

### Story Structure Best Practices

**Story Elements:**

1. **Title**: Brief description (5-10 words)
2. **User Story**: As/I want/So that format
3. **Acceptance Criteria**: EARS-formatted verifiable conditions
4. **Technical Notes**: Implementation guidance
5. **Definition of Done**: Completion checklist

### Example: Complete Story

```markdown
## [STORY-123] File Upload Tool with Progress

As a content creator,
I want to upload large files to the MCP server,
So that AI agents can process documents without manual file management.

### Acceptance Criteria

1. The file_upload_tool shall accept files up to 1GB.
2. While a file is being uploaded, the tool shall report progress every 5%.
3. When upload completes successfully, the tool shall return a unique file_id.
4. If the upload fails, then the tool shall return an error with retry guidance.
5. Where resume capability is enabled, the tool shall support resumable uploads.

### Technical Notes
- Use multipart upload for files > 10MB
- Store metadata in PostgreSQL
- Files stored in S3 with encryption
- Implement presigned URL pattern

### Definition of Done
- [ ] Unit tests with 80%+ coverage
- [ ] Integration tests for happy path and errors
- [ ] Security review completed
- [ ] API documentation updated
- [ ] Observability instrumentation added
```

---

## Acceptance Criteria

Acceptance criteria define specific, measurable conditions that must be met for a requirement to be considered satisfied.

### Acceptance Criteria Standards

**EARS-Based Criteria:**

Use EARS syntax for clarity and testability:

```text
✅ Good:
- When a user provides invalid credentials, the server shall return HTTP 401.
- While no API key is configured, the integration_tool shall return a configuration error.

❌ Poor:
- Handle bad credentials properly.
- API key should be checked.
```

**Characteristics of Good Acceptance Criteria:**

- **Specific**: Precise expected behavior
- **Measurable**: Can be objectively verified
- **Achievable**: Technically feasible
- **Relevant**: Directly relates to story
- **Testable**: Can write automated test

### Acceptance Criteria Templates

#### Functional Criteria

```text
Given <initial context>,
When <action occurs>,
Then <expected outcome>.
```

**Example:**

```text
Given a user with valid authentication,
When they invoke the create_issue tool with required parameters,
Then the tool shall create an issue and return the issue ID.
```

#### Non-Functional Criteria

```text
The <system> shall <performance characteristic> <measurable target>.
```

**Examples:**

```text
The search_tool shall return results within 500ms for 99% of queries.

The resource_cache shall reduce database load by at least 60%.

The authentication_service shall handle 1000 requests/second.
```

#### Security Criteria

```text
The <system> shall <security control> to <protect against threat>.
```

**Examples:**

```text
The api_gateway shall validate JWT signatures to prevent token forgery.

The logging_system shall mask PII to comply with GDPR.

The file_tool shall restrict access to user-owned files only.
```

### Complete Acceptance Criteria Example

### Story: Database Query Tool

```markdown
### Acceptance Criteria

#### Functional Requirements
1. When a valid SQL query is provided, the query_tool shall execute it and return results.
2. If the query contains dangerous operations (DROP, DELETE without WHERE), then the tool shall reject the request.
3. The query_tool shall support SELECT, INSERT, UPDATE with appropriate permissions.
4. While a query is executing, the tool shall enforce a 30-second timeout.

#### Non-Functional Requirements
5. The query_tool shall return results for 95% of queries within 2 seconds.
6. The tool shall support result sets up to 10,000 rows.
7. Where pagination is enabled, the tool shall return results in pages of 100 rows.

#### Security Requirements
8. The query_tool shall use parameterized queries to prevent SQL injection.
9. The tool shall validate user permissions before executing any query.
10. When a query fails, the tool shall log the error without exposing schema details.

#### Observability Requirements
11. The tool shall emit metrics for query duration, result size, and error rate.
12. The tool shall include request_id in all log entries for tracing.
```

---

## Requirements for MCP Primitives

### Tool Requirements Pattern

```markdown
## Tool: [tool_name]

### Purpose
Brief description of what the tool does and why it exists.

### Functional Requirements (EARS)
1. The [tool_name] shall [primary function].
2. When [trigger], the tool shall [response].
3. If [error condition], then the tool shall [error handling].

### Input Requirements
- Parameter: [name] (type) - [description]
- Parameter: [name] (type) - [description]

### Output Requirements
- The tool shall return [output format] on success.
- The tool shall return structured errors with code and message.

### Non-Functional Requirements
- Performance: [latency target]
- Scalability: [throughput target]
- Availability: [uptime target]

### Acceptance Criteria
[Testable conditions using Given/When/Then format]
```

### Example: create_issue Tool

```markdown
## Tool: create_issue

### Purpose
Enable AI agents to create issues in project management systems without requiring users to leave their workflow.

### Functional Requirements (EARS)
1. The create_issue tool shall accept title, description, and project_id as parameters.
2. When invoked with valid parameters, the tool shall create an issue and return the issue_id.
3. If the project_id is invalid, then the tool shall return RESOURCE_NOT_FOUND error.
4. Where labels are provided, the tool shall apply them to the created issue.
5. While the user lacks create permission, the tool shall return ACCESS_FORBIDDEN error.

### Input Requirements
- title (string, required): Issue title, 5-200 characters
- description (string, required): Issue description, markdown format
- project_id (string, required): Target project identifier
- labels (list[string], optional): Issue labels
- assignee (string, optional): User ID to assign

### Output Requirements
- Success: { "issue_id": "string", "url": "string", "created_at": "ISO8601" }
- Error: { "code": "ERROR_CODE", "message": "string", "details": {} }

### Non-Functional Requirements
- Performance: 95th percentile latency < 500ms
- Scalability: Support 100 req/sec per server
- Availability: 99.9% uptime

### Acceptance Criteria
1. Given valid authentication and permissions, when create_issue is called with required parameters, then an issue is created and issue_id returned.
2. Given missing required parameter, when tool is invoked, then validation error is returned immediately.
3. Given invalid project_id, when tool is invoked, then RESOURCE_NOT_FOUND error includes available projects.
```

### Prompt Requirements Pattern

```markdown
## Prompt: [prompt_name]

### Purpose
[Workflow description and use case]

### Workflow Requirements (EARS)
1. When [prompt is invoked], the prompt shall [present workflow].
2. While [condition], the prompt shall [behavior].

### Parameter Requirements
- [parameter]: [type] - [description and completion support]

### Output Requirements
- The prompt shall return [message structure].

### Acceptance Criteria
[Workflow verification conditions]
```

### Resource Requirements Pattern

```markdown
## Resource: [resource_uri_pattern]

### Purpose
[Data source description]

### Access Requirements (EARS)
1. The [resource] shall provide [data type] via [URI pattern].
2. When [accessed], the resource shall return [format].
3. If [condition], then the resource shall [behavior].

### URI Template
[URI pattern with parameters]

### Data Requirements
- Format: [MIME type]
- Size limit: [maximum size]
- Refresh rate: [cache TTL]

### Acceptance Criteria
[Data access and format verification]
```

---

## Requirements Traceability

### Traceability Matrix

Maintain bidirectional traceability between requirements and implementation:

```text
┌──────────────────────┬────────────────────┬─────────────────┐
│ Requirement ID       │ Implementation     │ Test Cases      │
├──────────────────────┼────────────────────┼─────────────────┤
│ REQ-TOOL-001         │ create_issue()     │ test_create_*   │
│ REQ-TOOL-002         │ error_handler()    │ test_errors_*   │
│ REQ-SECURITY-010     │ jwt_validator()    │ test_auth_*     │
└──────────────────────┴────────────────────┴─────────────────┘
```

#### Automated Traceability Tracking

For comprehensive traceability, use decorators and automated reporting:

```python
from typing import Callable, List
from functools import wraps
import inspect

# Global traceability registry
_traceability_registry = {}

def implements(*requirement_ids: str):
    """Decorator to mark functions as implementing specific requirements."""
    def decorator(func: Callable) -> Callable:
        module = inspect.getmodule(func).__name__
        func_name = func.__qualname__
        
        for req_id in requirement_ids:
            if req_id not in _traceability_registry:
                _traceability_registry[req_id] = {
                    "implementations": [],
                    "tests": []
                }
            
            _traceability_registry[req_id]["implementations"].append({
                "module": module,
                "function": func_name,
                "file": inspect.getfile(func),
                "line": inspect.getsourcelines(func)[1]
            })
        
        @wraps(func)
        async def wrapper(*args, **kwargs):
            return await func(*args, **kwargs)
        
        wrapper._requirements = requirement_ids
        return wrapper
    
    return decorator


def verifies(*requirement_ids: str):
    """Decorator to mark tests as verifying specific requirements."""
    def decorator(func: Callable) -> Callable:
        module = inspect.getmodule(func).__name__
        func_name = func.__qualname__
        
        for req_id in requirement_ids:
            base_req = req_id if not req_id.startswith("AC-") else req_id.rsplit("-", 1)[0]
            
            if base_req not in _traceability_registry:
                _traceability_registry[base_req] = {
                    "implementations": [],
                    "tests": []
                }
            
            _traceability_registry[base_req]["tests"].append({
                "module": module,
                "function": func_name,
                "file": inspect.getfile(func),
                "line": inspect.getsourcelines(func)[1],
                "criteria": req_id if req_id.startswith("AC-") else None
            })
        
        @wraps(func)
        async def wrapper(*args, **kwargs):
            return await func(*args, **kwargs)
        
        wrapper._verifies = requirement_ids
        return wrapper
    
    return decorator


def generate_traceability_report() -> str:
    """Generate a comprehensive traceability report."""
    from datetime import datetime
    
    report = []
    report.append("# Requirements Traceability Report\n")
    report.append(f"Generated: {datetime.now().isoformat()}\n\n")
    
    for req_id in sorted(_traceability_registry.keys()):
        data = _traceability_registry[req_id]
        report.append(f"## {req_id}\n")
        
        report.append("### Implementations\n")
        if data["implementations"]:
            for impl in data["implementations"]:
                report.append(f"- `{impl['module']}.{impl['function']}` ({impl['file']}:{impl['line']})\n")
        else:
            report.append("- ⚠️ **No implementations found**\n")
        
        report.append("\n### Tests\n")
        if data["tests"]:
            for test in data["tests"]:
                criteria = f" [{test['criteria']}]" if test['criteria'] else ""
                report.append(f"- `{test['module']}.{test['function']}`{criteria} ({test['file']}:{test['line']})\n")
        else:
            report.append("- ⚠️ **No tests found**\n")
        
        coverage = "✅ Complete" if data["implementations"] and data["tests"] else "❌ Incomplete"
        report.append(f"\n**Coverage:** {coverage}\n\n")
    
    return "".join(report)
```

**Usage in Implementation:**

```python
@implements("REQ-TOOL-001", "REQ-SEC-005", "REQ-OBS-002")
@mcp.tool()
async def create_issue(
    title: str,
    description: str,
    project_id: str
) -> dict:
    """Create a new project issue.
    
    Requirements Traceability:
        - REQ-TOOL-001: Issue creation functionality
        - REQ-SEC-005: Permission validation
        - REQ-OBS-002: Operation logging
    
    Acceptance Criteria:
        - AC-001: Returns issue_id on success
        - AC-002: Validates all parameters
        - AC-003: Enforces permissions
    """
    correlation_id = get_correlation_id()
    logger.info(f"Creating issue", extra={"correlation_id": correlation_id})
    
    # REQ-SEC-005: Validate authentication
    if not get_current_user():
        raise AuthenticationError("Authentication required")
    
    # AC-002: Validate parameters
    if not title or not description:
        raise ValidationError("Title and description required")
    
    # REQ-TOOL-001: Create issue
    issue_id = await db.issues.insert({
        "title": title,
        "description": description,
        "project_id": project_id,
        "created_by": get_current_user()
    })
    
    # REQ-OBS-002: Log operation
    logger.info(f"Issue created: {issue_id}", extra={"correlation_id": correlation_id})
    
    # AC-001: Return issue_id
    return {"issue_id": issue_id}
```

**Usage in Tests:**

```python
@verifies("REQ-TOOL-001", "AC-001", "AC-002", "AC-003")
def test_create_issue_success():
    """Verify REQ-TOOL-001: Successful issue creation.
    
    Acceptance Criteria:
        - AC-001: Returns issue_id on success
        - AC-002: Validates all parameters
        - AC-003: Enforces permissions
    
    Given: Valid auth and parameters
    When: create_issue is invoked
    Then: Issue created and ID returned
    """
    result = await create_issue("Test Issue", "Test Description", "proj-123")
    
    # AC-001: Issue ID returned
    assert result["issue_id"] is not None
    
    # AC-002: Parameters validated and stored
    issue = await db.issues.get(result["issue_id"])
    assert issue["title"] == "Test Issue"
    assert issue["description"] == "Test Description"
    
    # AC-003: Permissions enforced (user must be authenticated)
    assert issue["created_by"] == get_current_user()


@verifies("REQ-TOOL-001", "AC-002")
def test_create_issue_validation():
    """Verify AC-002: Parameter validation."""
    with pytest.raises(ValidationError):
        await create_issue("", "Description", "proj-123")


@verifies("REQ-SEC-005")
def test_create_issue_authentication():
    """Verify REQ-SEC-005: Authentication required."""
    clear_current_user()
    with pytest.raises(AuthenticationError):
        await create_issue("Test", "Description", "proj-123")
```

**Generate Traceability Report:**

```python
# In CI/CD pipeline or development workflow
def test_generate_traceability_report():
    """Generate and validate traceability report."""
    report = generate_traceability_report()
    
    # Save report
    with open("docs/traceability-report.md", "w") as f:
        f.write(report)
    
    # Verify all requirements have coverage
    for req_id, data in _traceability_registry.items():
        assert data["implementations"], f"{req_id} missing implementation"
        assert data["tests"], f"{req_id} missing tests"
```

**Example Generated Report:**

```markdown
# Requirements Traceability Report
Generated: 2025-01-15T10:30:00

## REQ-TOOL-001
### Implementations
- `tools.issue_tracker.create_issue` (src/tools/issue_tracker.py:45)

### Tests
- `tests.test_issue_tracker.test_create_issue_success` [AC-001] (tests/test_issue_tracker.py:12)
- `tests.test_issue_tracker.test_create_issue_success` [AC-002] (tests/test_issue_tracker.py:12)
- `tests.test_issue_tracker.test_create_issue_success` [AC-003] (tests/test_issue_tracker.py:12)
- `tests.test_issue_tracker.test_create_issue_validation` [AC-002] (tests/test_issue_tracker.py:35)

**Coverage:** ✅ Complete

## REQ-SEC-005
### Implementations
- `tools.issue_tracker.create_issue` (src/tools/issue_tracker.py:45)

### Tests
- `tests.test_issue_tracker.test_create_issue_authentication` (tests/test_issue_tracker.py:50)

**Coverage:** ✅ Complete
```

### Requirements Tracking

**In Code Documentation:**

```python
@mcp.tool()
async def create_issue(
    title: str,
    description: str,
    project_id: str
) -> dict:
    """Create a new project issue.
    
    Requirements Traceability:
        - REQ-TOOL-001: Issue creation functionality
        - REQ-SEC-005: Permission validation
        - REQ-OBS-002: Operation logging
    
    Acceptance Criteria:
        - AC-001: Returns issue_id on success
        - AC-002: Validates all parameters
        - AC-003: Enforces permissions
    """
    pass
```

**In Test Cases:**

```python
def test_create_issue_success():
    """Verify REQ-TOOL-001: Successful issue creation.
    
    Acceptance Criteria: AC-001
    Given: Valid auth and parameters
    When: create_issue is invoked
    Then: Issue created and ID returned
    """
    result = await create_issue("Test", "Description", "proj-123")
    assert result["issue_id"] is not None
```

---

## Requirements Documentation Workflow

### 1. Requirements Elicitation

**Stakeholder Interviews:**

- Identify user roles and needs
- Document use cases
- Capture business objectives

**Requirements Workshops:**

- Collaborative story writing
- Acceptance criteria definition
- Priority ranking

### 2. Requirements Analysis

**EARS Conversion:**

- Convert natural language to EARS syntax
- Identify requirement patterns
- Ensure verifiability

**Quality Checks:**

- Verify completeness
- Check for ambiguity
- Validate against quality characteristics

### 3. Requirements Documentation

**Story Documentation:**

```markdown
# Epic: [Epic Name]

## Background
[Context and motivation]

## User Stories

### [STORY-001] Story Title
As a [role], I want [capability], so that [value].

#### EARS Requirements
1. The system shall [ubiquitous requirement].
2. When [event], the system shall [response].
3. If [unwanted condition], then the system shall [handling].

#### Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Technical Requirements (ISO/IEEE 29148)
### Functional Requirements
[EARS-formatted requirements]

### Non-Functional Requirements
- Performance: [metrics]
- Security: [controls]
- Reliability: [targets]

## Traceability
Links to architecture, design, tests
```

### 4. Requirements Review

**Review Checklist:**

- [ ] All requirements follow EARS patterns
- [ ] Each requirement is verifiable
- [ ] Acceptance criteria are testable
- [ ] Requirements are traced to stories
- [ ] Non-functional requirements included
- [ ] Security requirements addressed
- [ ] Quality characteristics verified

### 5. Requirements Baseline

**Version Control:**

- Store requirements in Git with code
- Tag releases with requirement versions
- Maintain change history

**Change Management:**

- Document requirement changes
- Impact analysis for changes
- Update traceability links

---

## Anti-Patterns to Avoid

### ❌ Poor Requirements

```text
"The tool should handle errors."
Problem: Vague, not testable, no specific behavior

"The system must be fast."
Problem: Not measurable, no target specified

"Support all file types."
Problem: Unbounded, not achievable

"Implement create function."
Problem: Missing conditions, no acceptance criteria
```

### ✅ Good Requirements

```text
"When a tool execution fails, the server shall log the error with timestamp, tool name, parameters, and stack trace."
EARS: Event-driven, specific, testable

"The query_tool shall return results within 2 seconds for 95% of queries under normal load."
Measurable: Clear performance target

"The file_tool shall support PDF, DOCX, TXT, and MD file types up to 100MB each."
Achievable: Bounded, specific formats

"The create_user tool shall validate email format, check for duplicates, and return user_id or validation error."
Complete: All behaviors specified with acceptance criteria
```

---

## Requirements Tools and Templates

### Story Template

```markdown
## [STORY-XXX] [Brief Title]

**As a** [user role]
**I want** [capability]
**So that** [business value]

### Context
[Background information]

### EARS Requirements
1. [Ubiquitous] The system shall [always-active requirement].
2. [State] While [condition], the system shall [behavior].
3. [Event] When [trigger], the system shall [response].
4. [Optional] Where [feature], the system shall [capability].
5. [Unwanted] If [error], then the system shall [handling].

### Acceptance Criteria
- [ ] Given [context], when [action], then [outcome]
- [ ] Given [context], when [action], then [outcome]

### Technical Notes
- [Implementation guidance]
- [Dependencies]
- [Risks]

### Definition of Done
- [ ] Code complete
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Documentation updated
- [ ] Security review complete
```

### Requirements Review Checklist

```markdown
## Requirements Quality Review

### Completeness
- [ ] All user stories have acceptance criteria
- [ ] Functional requirements documented
- [ ] Non-functional requirements specified
- [ ] Interface requirements defined
- [ ] Security requirements included

### EARS Compliance
- [ ] Requirements use appropriate EARS patterns
- [ ] Keywords (While, When, Where, If/Then) used correctly
- [ ] System name specified in each requirement
- [ ] System response clearly stated

### Testability
- [ ] Each requirement is verifiable
- [ ] Acceptance criteria are measurable
- [ ] Test scenarios can be derived
- [ ] Performance targets specified

### ISO/IEEE 29148 Characteristics
- [ ] Necessary: Addresses real need
- [ ] Unambiguous: Single interpretation
- [ ] Complete: Fully describes capability
- [ ] Consistent: No contradictions
- [ ] Traceable: Linked to source and implementation

### Traceability
- [ ] Requirements traced to stories
- [ ] Implementation traced to requirements
- [ ] Tests traced to acceptance criteria
```

---

## Summary

Effective requirements engineering for MCP servers combines:

- **EARS Syntax**: Structured patterns for clarity and testability
- **Agile Stories**: User-centric format with business value
- **ISO/IEEE 29148**: International standards for quality
- **Acceptance Criteria**: Specific, measurable success conditions
- **Traceability**: Links between requirements, code, and tests

**Key Practices:**

1. Use EARS patterns for all functional requirements
2. Write user stories with clear business value
3. Define measurable acceptance criteria
4. Maintain requirements-to-code traceability
5. Review requirements for quality characteristics
6. Version control requirements with code

**Next Steps:**

- Review [Tool Implementation Standards](03-tool-implementation.md) for translating requirements to code
- See [Testing Strategy](04-testing-strategy.md) for requirements verification
- Consult [Development Lifecycle](06-development-lifecycle.md) for requirements management

---

**References:**

- [EARS - Easy Approach to Requirements Syntax](https://alistairmavin.com/ears/)
- [ISO/IEC/IEEE 29148:2018 - Requirements Engineering](https://standards.ieee.org/ieee/29148/6937/)
- [Agile Alliance - User Stories](https://www.agilealliance.org/glossary/user-stories/)
- [Tool Implementation Standards](03-tool-implementation.md)
- [Testing Strategy](04-testing-strategy.md)
