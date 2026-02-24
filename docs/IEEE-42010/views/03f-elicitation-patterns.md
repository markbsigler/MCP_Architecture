# Elicitation Patterns

**Navigation**: [Home](../README.md) > Implementation Standards > Elicitation Patterns  
**Related**: [← Previous: Integration Patterns](03e-integration-patterns.md) | [Next: Task Patterns →](03g-task-patterns.md) | [Sampling Patterns](03c-sampling-patterns.md)

**Version:** 3.0.0  
**Last Updated:** February 24, 2026  
**Status:** Production Ready  
**Framework:** FastMCP v3.x (ADR-002)

> **SRS References:** FR-ELIC-001 through FR-ELIC-005  
> **ADR References:** ADR-002 (FastMCP v3.x)  
> **FastMCP Docs:** [User Elicitation](https://gofastmcp.com/servers/elicitation)

## Introduction

Elicitation enables MCP servers to request user input during workflows. Unlike sampling (which requests LLM completions), elicitation requests **human input** through the client's UI. This is useful for gathering missing parameters, confirming destructive actions, or requesting credentials during tool execution.

Elicitation is defined in the [MCP specification 2025-11-25](https://modelcontextprotocol.io/docs/) as an optional server capability. FastMCP v3.x (per ADR-002) exposes elicitation through the `Context.elicit()` method with Python-native type annotations — dataclasses, Pydantic models, `Literal` types, and enums — eliminating manual JSON Schema construction.

## When to Use Elicitation

| Scenario | Use Elicitation? | Alternative |
|----------|-----------------|-------------|
| Missing required parameter during tool execution | ✅ Yes | Return isError asking user to retry |
| Confirming a destructive action (delete, deploy) | ✅ Yes | Consent level metadata on tool |
| Requesting credentials or API keys | ✅ Yes | Environment variables |
| Multi-step wizard workflow | ✅ Yes | Multiple tool calls |
| Asking the LLM for a decision | ❌ No | Use sampling instead |

## Capability Declaration

Elicitation is a **client** capability — the client declares which elicitation modes it supports during initialization. The server then sends `elicitation/create` requests to the client when human input is needed.

### Sub-Capabilities: Form and URL Modes

MCP 2025-11-25 introduces two elicitation modes:

| Mode | Purpose | When to Use |
|------|---------|-------------|
| **form** | In-band structured data collection via JSON Schema | Missing parameters, confirmations, multi-field input |
| **url** | Out-of-band interaction via URL navigation | OAuth flows, payment, sensitive data entry, third-party integrations |

**Client capability declaration (during initialize):**

```json
{
  "capabilities": {
    "elicitation": {
      "form": {},
      "url": {}
    }
  }
}
```

**FastMCP example:**

```python
from fastmcp import FastMCP

mcp = FastMCP(
    "Enterprise MCP Server",
    # Elicitation is a client capability — the server requests it.
    # Ensure your client supports form and/or url modes.
)
```

> **Note:** If the client only declares `"form": {}`, the server MUST NOT send URL-mode elicitation requests. Servers should check `clientCapabilities.elicitation` before choosing a mode.

## FastMCP v3 Elicitation API

> **ADR Reference:** ADR-002 (FastMCP v3.x)

FastMCP v3 provides a typed `ctx.elicit()` method that accepts Python types as `response_type` and auto-generates MCP-compliant JSON Schema. Use `Context` as a tool parameter to access elicitation.

### Response Types

| Python Type | MCP Schema | Example |
|------------|------------|--------|
| `str` | `{"type": "string"}` | Free-text input |
| `int` | `{"type": "integer"}` | Numeric input |
| `bool` | `{"type": "boolean"}` | Yes/No toggle |
| `["a", "b", "c"]` | `{"type": "string", "enum": [...]}` | Single-select dropdown |
| `[["a", "b", "c"]]` | `{"type": "array", "items": {"enum": [...]}}` | Multi-select |
| `{"a": {"title": "A"}}` | `{"oneOf": [{"const": "a", "title": "A"}]}` | Titled single-select |
| `dataclass` / `BaseModel` | `{"type": "object", "properties": {...}}` | Structured multi-field |
| `Literal["x", "y"]` | `{"type": "string", "enum": ["x", "y"]}` | Constrained string |
| `None` | No data expected | Approval/confirmation |

### Result Pattern Matching

FastMCP v3 provides typed result classes for idiomatic pattern matching:

```python
from fastmcp import FastMCP, Context
from fastmcp.server.elicitation import (
    AcceptedElicitation,
    DeclinedElicitation,
    CancelledElicitation,
)

mcp = FastMCP("Enterprise MCP Server")

@mcp.tool
async def get_user_name(ctx: Context) -> str:
    """Get user name via elicitation with pattern matching."""
    result = await ctx.elicit("What's your name?", response_type=str)
    
    match result:
        case AcceptedElicitation(data=name):
            return f"Hello {name}!"
        case DeclinedElicitation():
            return "No name provided"
        case CancelledElicitation():
            return "Operation cancelled"
```

### Structured Response with Dataclass

```python
from dataclasses import dataclass
from typing import Literal

@dataclass
class DeploymentConfig:
    service_name: str
    environment: Literal["development", "staging", "production"]
    replicas: int

@mcp.tool
async def configure_deployment(ctx: Context) -> str:
    """Configure deployment via structured elicitation."""
    result = await ctx.elicit(
        "Please provide deployment configuration",
        response_type=DeploymentConfig
    )
    
    if result.action == "accept":
        cfg = result.data
        return f"Deploying {cfg.service_name} to {cfg.environment} with {cfg.replicas} replicas"
    return "Deployment configuration cancelled"
```

### Default Values with Pydantic

```python
from pydantic import BaseModel, Field
from enum import Enum

class Priority(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"

class IssueDetails(BaseModel):
    title: str = Field(description="Issue title")
    description: str = Field(default="", description="Issue description")
    priority: Priority = Field(default=Priority.MEDIUM, description="Priority level")

@mcp.tool
async def create_issue(ctx: Context) -> str:
    """Create an issue with pre-populated defaults."""
    result = await ctx.elicit(
        "Please provide issue details",
        response_type=IssueDetails
    )
    
    if result.action == "accept":
        issue = result.data
        return f"Created issue: {issue.title} (Priority: {issue.priority.value})"
    return "Issue creation cancelled"
```

### Multi-Turn Elicitation

Tools can make multiple `ctx.elicit()` calls to gather information progressively:

```python
@mcp.tool
async def plan_meeting(ctx: Context) -> str:
    """Plan a meeting by gathering details step by step."""
    title_result = await ctx.elicit("What's the meeting title?", response_type=str)
    if title_result.action != "accept":
        return "Meeting planning cancelled"
    
    duration_result = await ctx.elicit("Duration in minutes?", response_type=int)
    if duration_result.action != "accept":
        return "Meeting planning cancelled"
    
    priority_result = await ctx.elicit(
        "Is this urgent?",
        response_type=["yes", "no"]
    )
    if priority_result.action != "accept":
        return "Meeting planning cancelled"
    
    urgent = priority_result.data == "yes"
    return f"Meeting '{title_result.data}' for {duration_result.data} min (Urgent: {urgent})"
```

### Confirmation (No Data Expected)

```python
@mcp.tool
async def delete_resource(resource_id: str, ctx: Context) -> str:
    """Delete a resource permanently with user confirmation."""
    resource = await get_resource(resource_id)
    
    result = await ctx.elicit(
        f"Are you sure you want to permanently delete '{resource.name}'? This cannot be undone.",
        response_type=None  # No data — just approve/decline
    )
    
    if result.action == "accept":
        await perform_deletion(resource_id)
        return f"Resource '{resource.name}' deleted."
    return "Deletion cancelled."
```

## Supported Input Types

> **SRS Reference:** FR-ELIC-002, FR-ELIC-003, FR-ELIC-004

| Type | JSON Schema | Default Support | Example |
|------|------------|-----------------|---------|
| `string` | `{"type": "string"}` | ✅ | Free-text input |
| `number` | `{"type": "number"}` | ✅ | Numeric value |
| `enum` (single) | `{"type": "string", "enum": [...]}` | ✅ | Dropdown |
| `enum` (multi) | `{"type": "array", "items": {"enum": [...]}}` | ✅ | Multi-select |
| `url` | `{"type": "string", "format": "uri"}` | ✅ | URL input |

### Titled vs Untitled Enum Variants

```python
# Untitled enum — values displayed directly
untitled_enum = {
    "type": "string",
    "enum": ["development", "staging", "production"]
}

# Titled enum — display labels differ from values
titled_enum = {
    "type": "string",
    "enum": ["dev", "stg", "prod"],
    "enumTitles": ["Development", "Staging", "Production"]
}
```

## Implementation Patterns

The following patterns use FastMCP v3's `ctx.elicit()` API (ADR-002). For raw JSON Schema usage, see the [MCP specification](https://modelcontextprotocol.io/specification/2025-11-25).

### Basic Elicitation

```python
from fastmcp import FastMCP, Context

mcp = FastMCP("Enterprise MCP Server")

@mcp.tool
async def deploy_service(
    service_name: str,
    ctx: Context,
    environment: str | None = None,
) -> str:
    """Deploy a service to an environment."""
    
    # If environment not provided, ask the user
    if not environment:
        result = await ctx.elicit(
            "Which environment should the service be deployed to?",
            response_type=["development", "staging", "production"]
        )
        
        if result.action == "accept":
            environment = result.data
        else:
            return "Deployment cancelled by user."
    
    # Proceed with deployment
    await perform_deploy(service_name, environment)
    return f"Deployed {service_name} to {environment}"
```

### Confirmation Before Destructive Action

```python
@mcp.tool
async def delete_resource(resource_id: str, ctx: Context) -> str:
    """Delete a resource permanently."""
    resource = await get_resource(resource_id)
    
    # Confirm destructive action — titled options
    result = await ctx.elicit(
        f"Are you sure you want to permanently delete '{resource.name}'? This cannot be undone.",
        response_type={
            "yes_delete": {"title": "Yes, delete permanently"},
            "cancel": {"title": "Cancel"},
        }
    )
    
    if result.action != "accept" or result.data != "yes_delete":
        return "Deletion cancelled."
    
    await perform_deletion(resource_id)
    return f"Resource '{resource.name}' deleted."
```

### Multi-Field Elicitation

```python
from pydantic import BaseModel, Field

class IssueInput(BaseModel):
    title: str = Field(description="Issue title")
    priority: str = Field(default="medium", description="Priority level")
    assignee_url: str = Field(default="", description="Assignee profile URL")

@mcp.tool
async def create_issue(ctx: Context) -> str:
    """Create a new issue with user-provided details."""
    result = await ctx.elicit(
        "Please provide issue details:",
        response_type=IssueInput
    )
    
    if result.action != "accept":
        return "Issue creation cancelled."
    
    issue = await create_new_issue(
        title=result.data.title,
        priority=result.data.priority,
        assignee_url=result.data.assignee_url,
    )
    return f"Created issue #{issue.id}: {issue.title}"
```

## URL Mode Elicitation

> **Added in MCP 2025-11-25**

URL mode enables out-of-band interaction by directing the user to a URL. This is ideal for workflows that require external UIs — OAuth consent screens, payment flows, sensitive-data forms, or third-party app integrations.

### URL Mode Request

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "elicitation/create",
  "params": {
    "message": "Please authorize access to your GitHub account.",
    "url": "https://github.com/login/oauth/authorize?client_id=abc123&scope=repo",
    "elicitationId": "elic-auth-001"
  }
}
```

### URL Mode Response

The client navigates the user to the URL. When the flow completes, the client sends `notifications/elicitation/complete`:

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/elicitation/complete",
  "params": {
    "elicitationId": "elic-auth-001"
  }
}
```

### URL Mode Implementation

```python
@mcp.tool
async def connect_github(org_name: str, ctx: Context) -> str:
    """Connect a GitHub organization — requires OAuth authorization."""
    auth_url = build_github_oauth_url(org_name)
    
    result = await ctx.elicit(
        f"Please authorize access to the '{org_name}' GitHub organization.",
        url=auth_url,
        elicitation_id="github-auth"
    )
    
    if result.action == "accept":
        token = await retrieve_oauth_token("github-auth")
        return f"Connected to {org_name}."
    return "Authorization cancelled."
```

### URL Mode Security Considerations

- **Phishing risk:** Clients SHOULD display the URL domain prominently and warn on non-HTTPS URLs
- **Safe URL handling:** Clients MUST validate that URLs use `https://` before navigating
- **User confirmation:** Clients SHOULD require explicit user consent before opening external URLs
- **URL provenance:** Clients SHOULD indicate that the URL was provided by the MCP server, not the AI model

## Error Handling

### Standard Errors

When a client does not support elicitation or the user declines:

```python
from fastmcp.exceptions import ToolError

@mcp.tool
async def operation_with_fallback(ctx: Context) -> str:
    """Operation that gracefully handles elicitation failure."""
    try:
        result = await ctx.elicit(
            "Select an option:",
            response_type=["option_a", "option_b", "option_c"]
        )
        if result.action == "accept":
            return process(result.data)
    except Exception:
        # Client doesn't support elicitation — degrade gracefully
        pass
    
    # Fallback: use defaults or return error
    raise ToolError("Please provide the 'choice' parameter directly.")
```

### MCP Elicitation Error Codes

| Code | Name | When |
|------|------|------|
| `-32042` | `URLElicitationRequiredError` | Server requires URL mode elicitation but the client does not support it |

When the server needs URL-mode elicitation but the client only declared `"form"`, the server SHOULD return this error.

### Notifications

| Notification | Direction | Purpose |
|-------------|-----------|---------|
| `notifications/elicitation/complete` | Client → Server | Signals that a URL-mode elicitation flow completed |

## Testing

```python
import pytest
from unittest.mock import AsyncMock

async def test_elicitation_accept():
    """Test tool behavior when user accepts elicitation."""
    mock_elicit = AsyncMock(return_value=ElicitResult(
        action="accept",
        content={"environment": "staging"}
    ))
    mcp.elicit = mock_elicit
    
    result = await deploy_service("my-service")
    assert "staging" in result["content"][0]["text"]

async def test_elicitation_decline():
    """Test tool behavior when user declines elicitation."""
    mock_elicit = AsyncMock(return_value=ElicitResult(action="decline", content={}))
    mcp.elicit = mock_elicit
    
    result = await deploy_service("my-service")
    assert "cancelled" in result["content"][0]["text"]

async def test_url_mode_elicitation():
    """Test URL mode elicitation flow."""
    mock_elicit = AsyncMock(return_value=ElicitResult(
        action="accept",
        content={}
    ))
    mcp.elicit = mock_elicit
    
    result = await connect_github("my-org")
    assert "Connected" in result["content"][0]["text"]
```

## Summary

- Elicitation enables **human-in-the-loop** workflows during MCP tool execution
- Two modes: **form** (in-band structured data) and **url** (out-of-band URL navigation)
- Supports string, number, boolean, enum (single/multi via `oneOf`/`anyOf`), and URL input types
- All types support `default` values for pre-population
- Use `oneOf` with `const` + `title` for titled single-select enums; `anyOf` for multi-select
- Always handle the `decline` action and `ElicitationNotSupportedError` gracefully
- URL mode requires phishing mitigation and HTTPS URL validation
- Error code `-32042` (`URLElicitationRequiredError`) for missing URL-mode support
- Test both accept and decline paths for both form and URL modes

---

**Next**: Review [Task Patterns](03g-task-patterns.md) for durable request handling.
