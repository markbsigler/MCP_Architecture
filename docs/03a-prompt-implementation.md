# Prompt Implementation Standards

**Navigation**: [Home](../README.md) > Implementation Standards > Prompt Implementation  
**Related**: [← Previous: Tool Implementation](03-tool-implementation.md) | [Next: Resource Implementation →](03b-resource-implementation.md) | [Agentic Best Practices](09-agentic-best-practices.md#prompt-system-design)

**Version:** 1.3.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Overview

Prompts are pre-built, reusable templates that provide structured interaction patterns for AI models. Unlike tools (which are model-controlled) and resources (which are application-driven), **prompts are user-controlled** - they require explicit invocation and guide users through specific workflows with parameterized inputs.

According to the [official MCP server concepts documentation](https://modelcontextprotocol.io/docs/learn/server-concepts), prompts serve three key purposes:

1. **Workflow Templates**: Pre-structured interaction patterns for common tasks
2. **Parameter Guidance**: Structured input validation with completion support
3. **Context Awareness**: Integration with available resources and tools

This section establishes implementation standards for creating effective, maintainable MCP prompts.

**Related Documentation:**

- [Tool Implementation Standards](03-tool-implementation.md) - Model-controlled actions
- [Resource Implementation Standards](03b-resource-implementation.md) - Data access patterns for prompts
- [Sampling Patterns](03c-sampling-patterns.md) - LLM interactions within tools
- [Agentic Best Practices](09-agentic-best-practices.md) - User elicitation patterns

---

## Core Prompt Concepts

### User-Controlled Invocation

Prompts differ fundamentally from tools in their interaction model:

```text
Tools:  Model decides → Executes automatically (with user approval)
Prompts: User selects → Provides parameters → Explicit invocation
```

**Key characteristics:**

- Require explicit user selection (slash commands, UI buttons, command palettes)
- Accept structured arguments with validation
- Return formatted message sequences ready for model consumption
- Support parameter completion for discoverability

### Prompt Protocol Operations

The MCP specification defines two core operations:

| Operation | Purpose | Response |
|-----------|---------|----------|
| `prompts/list` | Discover available prompts | Array of prompt descriptors with metadata |
| `prompts/get` | Retrieve prompt with arguments | Full message sequence ready for model |

---

## Naming and Identification

### Prompt Name Standards

Prompt names should follow kebab-case conventions and clearly indicate purpose:

**Good examples:**

```text
plan-vacation
analyze-codebase
generate-test-suite
summarize-meeting-notes
debug-production-issue
```

**Avoid:**

```text
planVacation          # camelCase - inconsistent with MCP conventions
analyze_code          # snake_case - harder to parse in UIs
prompt1               # Generic - provides no context
do_the_thing          # Vague - unclear purpose
```

### Title and Description

Every prompt must include human-readable metadata:

```python
@mcp.prompt()
async def plan_vacation():
    """Plan a comprehensive vacation itinerary.
    
    Guides users through destination selection, budget planning,
    activity scheduling, and booking coordination using available
    travel tools and resources.
    """
    return PromptMessage(
        role="user",
        content={
            "type": "text",
            "text": "Let's plan your vacation..."
        }
    )
```

**Title guidelines:**

- 3-7 words maximum
- Action-oriented (starts with verb when appropriate)
- Clear value proposition
- Title case formatting

**Description guidelines:**

- 1-3 sentences explaining purpose and workflow
- Mention integration points (tools, resources)
- Highlight key capabilities
- Avoid implementation details

---

## Parameter Design

### Argument Structure

Prompts accept structured arguments following JSON Schema patterns:

```python
from mcp.server.fastmcp import FastMCP
from mcp.types import PromptArgument, TextContent

mcp = FastMCP("travel-server")

@mcp.prompt()
async def plan_vacation(
    destination: str,
    departure_date: str,
    return_date: str,
    budget: float,
    travelers: int = 1,
    interests: list[str] | None = None
) -> list[PromptMessage]:
    """Plan a vacation with structured inputs."""
    
    # Build context-aware prompt
    context = f"""
    Destination: {destination}
    Dates: {departure_date} to {return_date}
    Budget: ${budget:,.2f}
    Travelers: {travelers}
    """
    
    if interests:
        context += f"\nInterests: {', '.join(interests)}"
    
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Plan a comprehensive vacation:\n{context}"
            )
        )
    ]
```

### Argument Best Practices

**Required vs. Optional:**

```python
# Core workflow parameters should be required
destination: str          # Required - cannot proceed without
departure_date: str       # Required - essential for planning

# Enhancement parameters should be optional
budget: float = 5000.0    # Optional - default assumption
interests: list[str] = [] # Optional - can infer from other context
```

**Type Annotations:**

```python
# Primitive types for simple inputs
state_code: str           # Two-letter US state
temperature: float        # Numeric value with precision
max_results: int          # Integer count

# Complex types for structured data
preferences: dict[str, Any]        # Nested configuration
exclude_dates: list[str]           # Multiple discrete values
filters: tuple[str, str, int]      # Fixed-length structure
```

**Validation and Constraints:**

```python
from typing import Annotated
from pydantic import Field

@mcp.prompt()
async def book_flight(
    passengers: Annotated[int, Field(ge=1, le=9)],
    departure: Annotated[str, Field(pattern=r"^[A-Z]{3}$")],
    arrival: Annotated[str, Field(pattern=r"^[A-Z]{3}$")],
    max_price: Annotated[float, Field(gt=0)] = 1000.0
):
    """Book flight with validated inputs."""
    # Type validation handled automatically by FastMCP
    pass
```

### Parameter Completion

Support parameter completion for discoverable values:

```python
@mcp.prompt()
async def get_weather_forecast(
    city: str,  # Supports completion: "Par" → ["Paris", "Park City"]
    date: str   # Supports completion: "2024-" → ["2024-01-01", "2024-01-02"]
):
    """Get weather forecast with completion support."""
    # Implementation provides completion suggestions via resources
    pass
```

Completion patterns:

- City names from `weather://cities` resource template
- Date formats following ISO 8601 (YYYY-MM-DD)
- Enum values from tool/resource definitions
- Historical values from user's previous prompts

---

## Message Construction

### Multi-Message Sequences

Prompts can return multiple messages to provide rich context:

```python
@mcp.prompt()
async def analyze_codebase(
    repository: str,
    focus_area: str
) -> list[PromptMessage]:
    """Analyze codebase with multi-message context."""
    
    return [
        # System context
        PromptMessage(
            role="system",
            content=TextContent(
                type="text",
                text="You are an expert code reviewer specializing in architecture analysis."
            )
        ),
        
        # User instruction
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Analyze the {repository} codebase, focusing on {focus_area}."
            )
        ),
        
        # Resource references (embedded images, docs, etc.)
        PromptMessage(
            role="user",
            content=EmbeddedResource(
                type="resource",
                resource={
                    "uri": f"file://{repository}/README.md",
                    "mimeType": "text/markdown"
                }
            )
        )
    ]
```

### Content Types

Prompts support multiple content types:

**Text Content:**

```python
TextContent(
    type="text",
    text="Structured text instructions or context"
)
```

**Image Content:**

```python
ImageContent(
    type="image",
    data="base64_encoded_image_data",
    mimeType="image/png"
)
```

**Embedded Resources:**

```python
EmbeddedResource(
    type="resource",
    resource={
        "uri": "file:///path/to/resource",
        "mimeType": "application/json"
    }
)
```

---

## Dynamic Prompt Injection

### Context-Aware Prompts

Inject dynamic context based on available resources and tools:

```python
@mcp.prompt()
async def debug_production_issue(
    service_name: str,
    error_pattern: str
) -> list[PromptMessage]:
    """Debug issue with dynamic context injection."""
    
    # Discover available debugging tools
    available_tools = await mcp.list_tools()
    tool_names = [t.name for t in available_tools]
    
    # Build context-aware instructions
    instructions = f"Debug {service_name} error: {error_pattern}\n\n"
    
    if "get_logs" in tool_names:
        instructions += "- Use get_logs to retrieve recent error traces\n"
    if "query_metrics" in tool_names:
        instructions += "- Use query_metrics to check service health\n"
    if "get_deployment_history" in tool_names:
        instructions += "- Use get_deployment_history to identify recent changes\n"
    
    return [
        PromptMessage(
            role="user",
            content=TextContent(type="text", text=instructions)
        )
    ]
```

### Tool and Resource Discovery

Query available capabilities to adapt prompts:

```python
# List available resources
resources = await mcp.list_resources()
resource_uris = [r.uri for r in resources]

# List available tools
tools = await mcp.list_tools()
tool_capabilities = {t.name: t.description for t in tools}

# Build adaptive prompt
if "calendar://events" in resource_uris:
    # Include calendar-aware instructions
    pass

if "send_email" in tool_capabilities:
    # Offer email notification option
    pass
```

---

## Testing Strategies

### Unit Testing Prompts

Test prompt generation with various argument combinations:

```python
import pytest
from mcp.types import PromptMessage, TextContent

@pytest.mark.asyncio
async def test_plan_vacation_prompt():
    """Test vacation planning prompt generation."""
    
    # Test minimal required arguments
    result = await plan_vacation(
        destination="Barcelona",
        departure_date="2024-06-15",
        return_date="2024-06-22",
        budget=3000.0
    )
    
    assert isinstance(result, list)
    assert len(result) > 0
    assert all(isinstance(m, PromptMessage) for m in result)
    
    # Verify content structure
    user_message = result[0]
    assert user_message.role == "user"
    assert "Barcelona" in user_message.content.text
    assert "2024-06-15" in user_message.content.text

@pytest.mark.asyncio
async def test_prompt_with_optional_args():
    """Test prompt with optional arguments."""
    
    result = await plan_vacation(
        destination="Tokyo",
        departure_date="2024-09-01",
        return_date="2024-09-10",
        budget=5000.0,
        travelers=2,
        interests=["food", "culture", "technology"]
    )
    
    # Verify optional parameters are included
    content_text = result[0].content.text
    assert "2 travelers" in content_text.lower()
    assert "food" in content_text.lower()
    assert "culture" in content_text.lower()
```

### Integration Testing

Test prompts with real tool and resource context:

```python
@pytest.mark.integration
async def test_debug_prompt_with_tools():
    """Test debug prompt adapts to available tools."""
    
    # Mock available tools
    mcp._tools = {
        "get_logs": Tool(name="get_logs", description="Retrieve logs"),
        "query_metrics": Tool(name="query_metrics", description="Query metrics")
    }
    
    result = await debug_production_issue(
        service_name="api-gateway",
        error_pattern="timeout"
    )
    
    instructions = result[0].content.text
    
    # Verify tool-aware instructions
    assert "get_logs" in instructions
    assert "query_metrics" in instructions
    assert "timeout" in instructions
```

### Parameter Validation Testing

Verify argument validation behavior:

```python
@pytest.mark.asyncio
async def test_prompt_parameter_validation():
    """Test parameter validation for prompts."""
    
    # Test invalid types
    with pytest.raises(ValidationError):
        await plan_vacation(
            destination="Paris",
            departure_date="invalid-date-format",  # Should be ISO 8601
            return_date="2024-12-31",
            budget=-1000.0  # Negative budget should fail
        )
    
    # Test missing required parameters
    with pytest.raises(TypeError):
        await plan_vacation(
            destination="London"
            # Missing required departure_date and return_date
        )
```

---

## Versioning and Evolution

### Prompt Versioning Strategy

As prompts evolve, maintain backward compatibility:

```python
# Version 1: Original prompt
@mcp.prompt()
async def analyze_code(repository: str):
    """Basic code analysis."""
    pass

# Version 2: Enhanced with optional parameters
@mcp.prompt()
async def analyze_code(
    repository: str,
    focus_area: str = "architecture",  # New optional parameter
    depth: str = "high"                 # New optional parameter
):
    """Enhanced code analysis with focus areas."""
    # Maintains compatibility - old calls still work
    pass
```

**Versioning best practices:**

- Add new parameters as optional (with defaults)
- Never remove or rename required parameters
- Use deprecation warnings for parameter changes
- Document version history in prompt docstrings

### Breaking Changes

When breaking changes are unavoidable, create new prompt variants:

```python
# Old prompt (maintained for compatibility)
@mcp.prompt()
async def analyze_code(repository: str):
    """Legacy code analysis - deprecated."""
    warnings.warn(
        "analyze_code is deprecated, use analyze_code_v2",
        DeprecationWarning
    )
    pass

# New prompt with improved interface
@mcp.prompt()
async def analyze_code_v2(
    repository_uri: str,  # Changed from 'repository' to 'repository_uri'
    analysis_type: AnalysisType  # Changed from string to enum
):
    """Modern code analysis with improved interface."""
    pass
```

---

## Prompt Chaining and Composition

### Multi-Step Workflows

Chain prompts to create complex workflows:

```python
@mcp.prompt()
async def plan_vacation_phase1_research(
    destination: str
) -> list[PromptMessage]:
    """Phase 1: Research destination options."""
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Research {destination}: weather, attractions, costs"
            )
        )
    ]

@mcp.prompt()
async def plan_vacation_phase2_itinerary(
    destination: str,
    selected_attractions: list[str]
) -> list[PromptMessage]:
    """Phase 2: Build detailed itinerary."""
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Create day-by-day itinerary for {destination} including: {', '.join(selected_attractions)}"
            )
        )
    ]

@mcp.prompt()
async def plan_vacation_phase3_booking(
    itinerary: dict[str, Any]
) -> list[PromptMessage]:
    """Phase 3: Coordinate bookings."""
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text="Book accommodations and activities based on itinerary"
            )
        )
    ]
```

### Prompt Composition Patterns

**Sequential Execution:**

```text
User selects: plan_vacation
  ↓
System executes: plan_vacation_phase1_research
  ↓
User reviews results
  ↓
System executes: plan_vacation_phase2_itinerary
  ↓
User approves itinerary
  ↓
System executes: plan_vacation_phase3_booking
```

**Conditional Branching:**

```python
@mcp.prompt()
async def analyze_codebase_router(
    repository: str,
    analysis_type: str
) -> list[PromptMessage]:
    """Route to specialized analysis prompts."""
    
    if analysis_type == "security":
        return await analyze_security_issues(repository)
    elif analysis_type == "performance":
        return await analyze_performance_bottlenecks(repository)
    elif analysis_type == "architecture":
        return await analyze_architecture_patterns(repository)
    else:
        raise ValueError(f"Unknown analysis type: {analysis_type}")
```

---

## User Interaction Patterns

### Discovery Mechanisms

Implement multiple discovery patterns for different UI contexts:

**1. Slash Commands:**

```text
User types: /plan-vacation
System displays: Parameter input form with completion
```

**2. Command Palettes:**

```text
User presses: Cmd+K (or Ctrl+K)
System shows: Searchable list of all prompts with descriptions
User searches: "vacation"
System filters: Shows plan-vacation and related prompts
```

**3. Context Menus:**

```text
User right-clicks: On selected text/resource
System suggests: Relevant prompts based on context
  - Selected JSON → "validate-json-schema"
  - Selected code → "explain-code-snippet"
  - Selected date range → "analyze-time-period"
```

**4. Smart Suggestions:**

```text
Context: User viewing calendar with upcoming trip dates
System suggests: "Would you like to plan your vacation to Barcelona?"
User clicks: Opens plan-vacation prompt with pre-filled dates
```

### Parameter Input UX

Design parameter inputs for usability:

```python
@mcp.prompt()
async def book_flight(
    passengers: Annotated[int, Field(ge=1, le=9, description="Number of passengers (1-9)")],
    departure: Annotated[str, Field(pattern=r"^[A-Z]{3}$", description="3-letter airport code (e.g., JFK)")],
    arrival: Annotated[str, Field(pattern=r"^[A-Z]{3}$", description="3-letter airport code (e.g., LAX)")],
    travel_class: Annotated[str, Field(description="Seat class")] = "economy",
    flexible_dates: Annotated[bool, Field(description="Search ±3 days")] = False
):
    """Book flight with user-friendly parameter descriptions."""
    pass
```

**UI rendering considerations:**

- `description` fields become input placeholders/tooltips
- `ge`/`le` constraints render as number steppers
- `pattern` constraints show validation hints
- Enum types render as dropdown selects
- Boolean types render as toggles/checkboxes

### Progress and Feedback

Provide clear feedback during prompt execution:

```python
@mcp.prompt()
async def generate_comprehensive_report(
    data_sources: list[str],
    report_type: str
) -> list[PromptMessage]:
    """Generate report with progress updates."""
    
    # Send progress notification (if client supports)
    await mcp.send_log_message(
        level="info",
        data=f"Collecting data from {len(data_sources)} sources..."
    )
    
    # Build prompt with clear expectations
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"""Generate {report_type} report from {len(data_sources)} sources.
                
                Expected steps:
                1. Validate data source access
                2. Retrieve and normalize data
                3. Perform analysis
                4. Generate visualizations
                5. Compile final report
                
                This may take 2-3 minutes.
                """
            )
        )
    ]
```

---

## Security and Access Control

### Sensitive Parameter Handling

Treat sensitive parameters with care:

```python
from typing import Annotated
from pydantic import SecretStr, Field

@mcp.prompt()
async def connect_to_database(
    host: str,
    database: str,
    username: str,
    password: Annotated[SecretStr, Field(description="Database password (masked)")]
) -> list[PromptMessage]:
    """Connect to database with secure password handling."""
    
    # Password is automatically masked in logs/UI
    # Access with: password.get_secret_value()
    
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Connecting to {database} on {host} as {username}"
                # Never include password in prompt text
            )
        )
    ]
```

### Authorization Checks

Validate user permissions before executing sensitive prompts:

```python
from mcp.server.fastmcp import Context

@mcp.prompt()
async def deploy_to_production(
    ctx: Context,
    service: str,
    version: str
) -> list[PromptMessage]:
    """Deploy service with authorization check."""
    
    # Check user authorization (implementation-specific)
    if not await check_deployment_permission(ctx.user_id, service):
        raise PermissionError(
            f"User {ctx.user_id} not authorized to deploy {service}"
        )
    
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Deploy {service} version {version} to production"
            )
        )
    ]
```

### Audit Logging

Log prompt invocations for compliance and debugging:

```python
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

@mcp.prompt()
async def delete_user_data(
    ctx: Context,
    user_id: str,
    data_types: list[str]
) -> list[PromptMessage]:
    """Delete user data with comprehensive audit logging."""
    
    # Log invocation with all relevant context
    logger.info(
        "Prompt invoked",
        extra={
            "prompt_name": "delete_user_data",
            "invoked_by": ctx.user_id,
            "target_user": user_id,
            "data_types": data_types,
            "timestamp": datetime.utcnow().isoformat(),
            "client_info": ctx.client_info
        }
    )
    
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Delete {', '.join(data_types)} data for user {user_id}"
            )
        )
    ]
```

---

## Performance Considerations

### Lazy Prompt Generation

Defer expensive operations until prompt is actually invoked:

```python
@mcp.prompt()
async def analyze_large_dataset(
    dataset_uri: str,
    analysis_type: str
) -> list[PromptMessage]:
    """Analyze dataset with lazy resource loading."""
    
    # Don't load full dataset during prompt generation
    # Instead, reference it for the model to retrieve later
    
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Analyze {analysis_type} patterns in dataset"
            )
        ),
        PromptMessage(
            role="user",
            content=EmbeddedResource(
                type="resource",
                resource={
                    "uri": dataset_uri,  # Model will fetch when needed
                    "mimeType": "application/json"
                }
            )
        )
    ]
```

### Caching Prompt Definitions

Cache static prompt metadata for faster discovery:

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def get_prompt_definition(prompt_name: str) -> dict[str, Any]:
    """Cache prompt definitions for fast retrieval."""
    
    # Expensive operation: parse docstrings, validate schemas, etc.
    # Only execute once per prompt name
    
    return {
        "name": prompt_name,
        "description": "...",
        "arguments": [...]
    }
```

### Streaming Long Prompts

For prompts generating very long content, use streaming:

```python
@mcp.prompt()
async def generate_documentation(
    project: str
) -> list[PromptMessage]:
    """Generate documentation with streaming support."""
    
    # Return initial instruction immediately
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Generate comprehensive documentation for {project}. Stream sections as they complete."
            )
        )
    ]
    
    # Model will stream response back to user incrementally
```

---

## Error Handling

### Validation Errors

Handle parameter validation failures gracefully:

```python
from pydantic import ValidationError

@mcp.prompt()
async def book_flight(
    departure: str,
    arrival: str,
    date: str
) -> list[PromptMessage]:
    """Book flight with validation error handling."""
    
    # Validate date format
    try:
        from datetime import datetime
        datetime.fromisoformat(date)
    except ValueError as e:
        raise ValidationError(
            f"Invalid date format: {date}. Expected ISO 8601 (YYYY-MM-DD)"
        ) from e
    
    # Validate airport codes
    if not (len(departure) == 3 and departure.isupper()):
        raise ValidationError(
            f"Invalid departure airport code: {departure}. Expected 3-letter code (e.g., JFK)"
        )
    
    return [...]
```

### Resource Unavailability

Handle missing resources gracefully:

```python
@mcp.prompt()
async def analyze_with_context(
    topic: str,
    context_resource: str
) -> list[PromptMessage]:
    """Analyze with context resource, handle missing gracefully."""
    
    try:
        # Try to retrieve context resource
        resource = await mcp.read_resource(context_resource)
        
        return [
            PromptMessage(
                role="user",
                content=TextContent(
                    type="text",
                    text=f"Analyze {topic} with provided context"
                )
            ),
            PromptMessage(
                role="user",
                content=EmbeddedResource(
                    type="resource",
                    resource=resource
                )
            )
        ]
    except ResourceNotFoundError:
        # Fallback: proceed without context
        return [
            PromptMessage(
                role="user",
                content=TextContent(
                    type="text",
                    text=f"Analyze {topic} (context resource unavailable, proceeding without additional context)"
                )
            )
        ]
```

### Timeout Handling

Set reasonable timeouts for prompt generation:

```python
import asyncio

@mcp.prompt()
async def generate_complex_prompt(
    **kwargs
) -> list[PromptMessage]:
    """Generate prompt with timeout protection."""
    
    try:
        # Time-bound expensive operations
        result = await asyncio.wait_for(
            _generate_prompt_content(**kwargs),
            timeout=5.0  # 5 second timeout
        )
        return result
    except asyncio.TimeoutError:
        # Return simplified prompt on timeout
        return [
            PromptMessage(
                role="user",
                content=TextContent(
                    type="text",
                    text="Request received. Proceeding with simplified analysis due to complexity."
                )
            )
        ]
```

---

## Documentation and Discovery

### Inline Documentation

Provide comprehensive docstrings:

```python
@mcp.prompt()
async def plan_vacation(
    destination: str,
    departure_date: str,
    return_date: str,
    budget: float,
    travelers: int = 1,
    interests: list[str] | None = None
) -> list[PromptMessage]:
    """Plan a comprehensive vacation itinerary.
    
    This prompt guides users through vacation planning by:
    1. Researching destination (weather, attractions, costs)
    2. Building day-by-day itinerary based on interests
    3. Coordinating bookings (flights, hotels, activities)
    4. Creating calendar events and notifications
    
    Args:
        destination: City or region name (e.g., "Barcelona", "Tokyo")
        departure_date: ISO 8601 date (YYYY-MM-DD)
        return_date: ISO 8601 date (YYYY-MM-DD)
        budget: Total budget in USD (must be positive)
        travelers: Number of travelers (default: 1)
        interests: List of activity categories (e.g., ["food", "museums"])
    
    Returns:
        Multi-message prompt sequence with context-aware instructions
    
    Examples:
        >>> await plan_vacation("Barcelona", "2024-06-15", "2024-06-22", 3000.0)
        >>> await plan_vacation("Tokyo", "2024-09-01", "2024-09-10", 5000.0, 
        ...                     travelers=2, interests=["food", "technology"])
    
    References:
        - Uses tools: searchFlights, bookHotel, createCalendarEvent
        - References resources: calendar://events, travel://preferences
    """
    pass
```

### Example Usage

Include working examples in documentation:

```python
# Basic usage
prompt = await plan_vacation(
    destination="Paris",
    departure_date="2024-07-01",
    return_date="2024-07-07",
    budget=4000.0
)

# With optional parameters
prompt = await plan_vacation(
    destination="Barcelona",
    departure_date="2024-06-15",
    return_date="2024-06-22",
    budget=3000.0,
    travelers=2,
    interests=["beaches", "architecture", "food"]
)

# Error handling
try:
    prompt = await plan_vacation(
        destination="London",
        departure_date="invalid-date",
        return_date="2024-12-31",
        budget=2000.0
    )
except ValidationError as e:
    print(f"Invalid parameters: {e}")
```

### Metadata for Discovery

Include rich metadata for client UIs:

```python
from mcp.types import PromptMetadata

@mcp.prompt(
    metadata=PromptMetadata(
        category="Travel & Planning",
        tags=["vacation", "itinerary", "booking"],
        difficulty="intermediate",
        estimated_duration="5-10 minutes",
        requires_tools=["searchFlights", "bookHotel"],
        requires_resources=["calendar://events"]
    )
)
async def plan_vacation(**kwargs):
    """Plan vacation with rich discovery metadata."""
    pass
```

---

## Migration and Compatibility

### Migrating from String-Based Prompts

**Before (legacy string prompts):**

```python
# Simple string template
prompt_template = "Plan a vacation to {destination} from {start} to {end}"

# Manual string interpolation
user_prompt = prompt_template.format(
    destination="Barcelona",
    start="2024-06-15",
    end="2024-06-22"
)
```

**After (structured MCP prompts):**

```python
@mcp.prompt()
async def plan_vacation(
    destination: str,
    departure_date: str,
    return_date: str
) -> list[PromptMessage]:
    """Structured MCP prompt with validation."""
    return [
        PromptMessage(
            role="user",
            content=TextContent(
                type="text",
                text=f"Plan a vacation to {destination} from {departure_date} to {return_date}"
            )
        )
    ]
```

**Benefits:**

- Type validation on parameters
- Schema-driven discovery
- Standardized protocol operations
- Client UI generation
- Version management

### Backward Compatibility

Support legacy clients during migration:

```python
# Support both old and new formats
@mcp.prompt()
async def plan_vacation_v2(
    destination: str,
    departure_date: str,
    return_date: str,
    **legacy_kwargs  # Accept old parameter names
) -> list[PromptMessage]:
    """New prompt supporting legacy parameter names."""
    
    # Map legacy parameter names
    if "start_date" in legacy_kwargs:
        departure_date = legacy_kwargs["start_date"]
    if "end_date" in legacy_kwargs:
        return_date = legacy_kwargs["end_date"]
    
    return [...]
```

---

## Related Documentation

For more information on MCP prompts and server development:

- **[MCP Server Concepts](https://modelcontextprotocol.io/docs/learn/server-concepts)** - Core understanding of prompts, resources, and tools
- **[Build an MCP Server](https://modelcontextprotocol.io/docs/develop/build-server)** - Complete server implementation guide
- **[Tool Implementation Standards](./03-tool-implementation.md)** - Parallel implementation guide for tools
- **[Resource Implementation Standards](./03b-resource-implementation.md)** - Parallel implementation guide for resources

---

## Summary

Effective MCP prompts combine:

1. **Clear naming** - Kebab-case, action-oriented names with descriptive titles
2. **Structured parameters** - Type-safe arguments with validation and completion
3. **Rich messages** - Multi-message sequences with context and resources
4. **User control** - Explicit invocation with transparent parameter input
5. **Testing** - Comprehensive unit and integration test coverage
6. **Security** - Sensitive parameter handling, authorization, and audit logging
7. **Performance** - Lazy generation, caching, and streaming support
8. **Documentation** - Inline docstrings, examples, and discovery metadata

By following these standards, MCP prompts become discoverable, maintainable, and user-friendly workflow templates that enhance AI application capabilities while maintaining security and reliability.
