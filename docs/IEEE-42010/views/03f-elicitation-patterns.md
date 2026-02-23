# Elicitation Patterns

**Navigation**: [Home](../README.md) > Implementation Standards > Elicitation Patterns  
**Related**: [← Previous: Integration Patterns](03e-integration-patterns.md) | [Next: Task Patterns →](03g-task-patterns.md) | [Sampling Patterns](03c-sampling-patterns.md)

**Version:** 2.0.0  
**Last Updated:** July 19, 2025  
**Status:** Production Ready

> **SRS References:** FR-ELIC-001 through FR-ELIC-005

## Introduction

Elicitation enables MCP servers to request user input during workflows. Unlike sampling (which requests LLM completions), elicitation requests **human input** through the client's UI. This is useful for gathering missing parameters, confirming destructive actions, or requesting credentials during tool execution.

Elicitation is defined in the [MCP specification 2025-11-25](https://modelcontextprotocol.io/docs/) as an optional server capability.

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

### Basic Elicitation

```python
@mcp.tool()
async def deploy_service(
    service_name: str,
    environment: str | None = None,
) -> dict:
    """Deploy a service to an environment."""
    
    # If environment not provided, ask the user
    if not environment:
        result = await mcp.elicit(
            message="Which environment should the service be deployed to?",
            schema={
                "type": "object",
                "properties": {
                    "environment": {
                        "type": "string",
                        "enum": ["development", "staging", "production"],
                        "default": "staging",
                        "description": "Target deployment environment"
                    }
                },
                "required": ["environment"]
            }
        )
        
        if result.action == "accept":
            environment = result.content["environment"]
        elif result.action == "decline":
            return {"content": [{"type": "text", "text": "Deployment cancelled by user."}]}
    
    # Proceed with deployment
    deploy_result = await perform_deploy(service_name, environment)
    return {"content": [{"type": "text", "text": f"Deployed {service_name} to {environment}"}]}
```

### Confirmation Before Destructive Action

```python
@mcp.tool()
async def delete_resource(resource_id: str) -> dict:
    """Delete a resource permanently."""
    
    resource = await get_resource(resource_id)
    
    # Confirm destructive action
    result = await mcp.elicit(
        message=f"Are you sure you want to permanently delete '{resource.name}'? This cannot be undone.",
        schema={
            "type": "object",
            "properties": {
                "confirm": {
                    "type": "string",
                    "oneOf": [
                        {"const": "yes_delete", "title": "Yes, delete permanently"},
                        {"const": "cancel", "title": "Cancel"}
                    ],
                    "default": "cancel"
                }
            },
            "required": ["confirm"]
        }
    )
    
    if result.action != "accept" or result.content.get("confirm") != "yes_delete":
        return {"content": [{"type": "text", "text": "Deletion cancelled."}]}
    
    await perform_deletion(resource_id)
    return {"content": [{"type": "text", "text": f"Resource '{resource.name}' deleted."}]}
```

### Multi-Field Elicitation

```python
@mcp.tool()
async def create_issue() -> dict:
    """Create a new issue with user-provided details."""
    
    result = await mcp.elicit(
        message="Please provide issue details:",
        schema={
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Issue title"
                },
                "priority": {
                    "type": "string",
                    "enum": ["low", "medium", "high", "critical"],
                    "default": "medium"
                },
                "assignee_url": {
                    "type": "string",
                    "format": "uri",
                    "description": "Assignee profile URL"
                }
            },
            "required": ["title", "priority"]
        }
    )
    
    if result.action != "accept":
        return {"content": [{"type": "text", "text": "Issue creation cancelled."}]}
    
    issue = await create_new_issue(**result.content)
    return {"content": [{"type": "text", "text": f"Created issue #{issue.id}: {issue.title}"}]}
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
@mcp.tool()
async def connect_github(org_name: str) -> dict:
    """Connect a GitHub organization — requires OAuth authorization."""
    
    auth_url = build_github_oauth_url(org_name)
    
    result = await mcp.elicit(
        message=f"Please authorize access to the '{org_name}' GitHub organization.",
        url=auth_url,
        elicitation_id="github-auth"
    )
    
    if result.action == "accept":
        # User completed the OAuth flow
        token = await retrieve_oauth_token("github-auth")
        return {"content": [{"type": "text", "text": f"Connected to {org_name}."}]}
    elif result.action == "decline":
        return {"content": [{"type": "text", "text": "Authorization cancelled."}]}
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
@mcp.tool()
async def operation_with_fallback() -> dict:
    """Operation that gracefully handles elicitation failure."""
    try:
        result = await mcp.elicit(
            message="Select an option:",
            schema={"type": "object", "properties": {"choice": {"type": "string"}}}
        )
        if result.action == "accept":
            return process(result.content["choice"])
    except ElicitationNotSupportedError:
        # Client doesn't support elicitation — degrade gracefully
        pass
    
    # Fallback: use defaults or return isError
    return {
        "content": [{"type": "text", "text": "Please provide the 'choice' parameter directly."}],
        "isError": True,
    }
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
