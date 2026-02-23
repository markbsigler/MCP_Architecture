# Tool Implementation Standards

**Navigation**: [Home](../README.md) > Implementation Standards > Tool Implementation  
**Related**: [← Previous: Requirements Engineering](../../IEEE-29148/methodology/02b-requirements-engineering.md) | [Next: Prompt Implementation →](03a-prompt-implementation.md) | [Decision Trees](03d-decision-trees.md#tool-vs-prompt-vs-resource-selection)

**Version:** 2.0.0  
**Last Updated:** July 19, 2025  
**Status:** Production Ready

## Quick Links

- [Naming Conventions](#naming-conventions)
- [Parameter Design](#parameter-design)
- [Response Format](#response-format-consistency)
- [Error Handling](#error-handling-patterns)
- [Pagination Patterns](#pagination-patterns)
- [Versioning Strategies](#versioning-strategies)
- [Summary](#summary)

## Introduction

Consistent tool implementation is critical for maintainability and user experience. This document establishes naming conventions, parameter design patterns, response formats, and error handling standards for MCP tools.

**Related Documentation:**

- [Prompt Implementation Standards](03a-prompt-implementation.md) - User-controlled workflow templates
- [Resource Implementation Standards](03b-resource-implementation.md) - Application-driven data access
- [Sampling Patterns](03c-sampling-patterns.md) - Server-initiated LLM interactions
- [Testing Strategy](04-testing-strategy.md) - Testing approaches for tools

## Naming Conventions

### Verb-Noun Pattern

All tool names follow the **verb-noun** pattern for clarity and consistency.

**Format:** `{verb}_{noun}` or `{verb}_{adjective}_{noun}`

**Examples:**

```python
# ✅ Good - Clear verb-noun pattern
@mcp.tool()
async def create_assignment(...):
    """Create a new assignment."""

@mcp.tool()
async def list_releases(...):
    """List all releases."""

@mcp.tool()
async def update_pipeline_config(...):
    """Update pipeline configuration."""

@mcp.tool()
async def delete_workflow(...):
    """Delete a workflow."""

# ❌ Bad - Unclear or inconsistent naming
@mcp.tool()
async def assignment(...):  # Missing verb
    
@mcp.tool()
async def getAllReleases(...):  # camelCase, not snake_case
    
@mcp.tool()
async def do_stuff(...):  # Vague, not descriptive
```

### Standard Verbs

Use consistent verbs across all tools:

| Verb | Use Case | Example |
|------|----------|---------|
| `create` | Create new resource | `create_assignment` |
| `get` | Retrieve single resource | `get_release` |
| `list` | Retrieve multiple resources | `list_pipelines` |
| `update` | Modify existing resource | `update_workflow` |
| `delete` | Remove resource | `delete_deployment` |
| `search` | Query resources with criteria | `search_logs` |
| `execute` | Perform action | `execute_pipeline` |
| `trigger` | Start async process | `trigger_build` |
| `validate` | Check validity | `validate_config` |
| `export` | Extract data | `export_metrics` |
| `import` | Load data | `import_configuration` |

### Noun Naming

Nouns should be:

- **Singular** for operations on single resources: `create_assignment`
- **Plural** for operations on collections: `list_assignments`
- **Descriptive** and domain-specific: `pipeline_config` not `config`

### Avoid Abbreviations

Spell out words unless they are industry-standard abbreviations:

```python
# ✅ Good - Clear, spelled out
create_application
get_configuration

# ⚠️ Acceptable - Industry standard
create_api_key
list_cicd_pipelines

# ❌ Bad - Unclear abbreviations
create_app  # Use create_application
get_cfg     # Use get_configuration
```

### MCP 2025-11-25 Naming Rules

Per the MCP specification, tool names have strict constraints:

| Rule | Value |
|------|-------|
| Length | 1–128 characters |
| Allowed characters | `A-Za-z0-9_-.` |
| Case sensitivity | Case-sensitive |

Names outside these constraints will be rejected by compliant clients and servers.

## Tool Metadata (MCP 2025-11-25)

> **Added in MCP 2025-11-25**

### Title, Icons, and Display Metadata

Tools now support human-readable display metadata:

```json
{
  "name": "deploy_application",
  "title": "Deploy Application",
  "description": "Deploy an application to the specified environment.",
  "icons": [
    { "src": "https://cdn.example.com/deploy-icon.png", "mimeType": "image/png", "sizes": "32x32" }
  ],
  "inputSchema": { ... }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Machine-readable identifier (1–128 chars, `A-Za-z0-9_-.`) |
| `title` | `string` | Human-readable display name |
| `description` | `string` | Description of what the tool does |
| `icons` | `array` | Array of `{ src, mimeType, sizes }` icon objects |
| `inputSchema` | `object` | JSON Schema for input parameters |
| `outputSchema` | `object` | JSON Schema for structured output (optional) |

### Output Schema and Structured Content

Tools can declare an `outputSchema` to return typed, machine-readable results alongside human-readable content:

```json
{
  "name": "get_metrics",
  "description": "Get application metrics.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "app_name": { "type": "string" }
    },
    "required": ["app_name"]
  },
  "outputSchema": {
    "type": "object",
    "properties": {
      "cpu_percent": { "type": "number" },
      "memory_mb": { "type": "number" },
      "request_count": { "type": "integer" }
    },
    "required": ["cpu_percent", "memory_mb", "request_count"]
  }
}
```

When `outputSchema` is declared, the tool response includes `structuredContent`:

```json
{
  "content": [
    { "type": "text", "text": "CPU: 42%, Memory: 512 MB, Requests: 1234" }
  ],
  "structuredContent": {
    "cpu_percent": 42.0,
    "memory_mb": 512,
    "request_count": 1234
  }
}
```

- `content` is always present (human-readable fallback)
- `structuredContent` is present only when the tool declares `outputSchema`
- Clients should prefer `structuredContent` for programmatic use

### JSON Schema Dialect

MCP uses **JSON Schema 2020-12** as the default dialect. If a schema does not include a `$schema` field, clients and servers MUST assume `https://json-schema.org/draft/2020-12/schema`.

### Content Types in Tool Results

Tool results can now include the following content types:

| Type | Description | Added |
|------|-------------|-------|
| `text` | Plain text content | 2024-11-05 |
| `image` | Base64-encoded image with MIME type | 2024-11-05 |
| `audio` | Base64-encoded audio with MIME type | 2025-11-25 |
| `resource_link` | Reference to an MCP resource by URI | 2025-06-18 |

```python
# Audio content in tool result
return {
    "content": [
        {"type": "text", "text": "Generated audio summary."},
        {"type": "audio", "data": base64_audio, "mimeType": "audio/mp3"}
    ]
}

# Resource link in tool result
return {
    "content": [
        {"type": "text", "text": "Created report."},
        {"type": "resource_link", "uri": "resource:///reports/2025-q3.pdf", "name": "Q3 Report", "mimeType": "application/pdf"}
    ]
}
```

## Parameter Design

### Required vs Optional

Clearly distinguish required and optional parameters:

```python
from typing import Optional, List

@mcp.tool()
async def create_assignment(
    # Required parameters first
    title: str,
    assignee: str,
    
    # Optional parameters with defaults
    description: Optional[str] = None,
    priority: int = 3,
    tags: List[str] = [],
    due_date: Optional[str] = None
) -> dict:
    """
    Create a new assignment.
    
    Args:
        title: Assignment title (required)
        assignee: User email to assign to (required)
        description: Detailed description (optional)
        priority: Priority level 1-5, default 3 (optional)
        tags: List of tags (optional)
        due_date: ISO 8601 date string (optional)
    
    Returns:
        Created assignment details
    """
    pass
```

### Parameter Naming

Use `snake_case` for all parameter names:

```python
# ✅ Good
async def create_release(
    release_name: str,
    target_environment: str,
    deployment_config: dict
):
    pass

# ❌ Bad - camelCase
async def create_release(
    releaseName: str,
    targetEnvironment: str,
    deploymentConfig: dict
):
    pass
```

### Type Annotations

Always provide type annotations:

```python
from typing import List, Dict, Optional, Union
from datetime import datetime
from pydantic import BaseModel

@mcp.tool()
async def search_logs(
    query: str,
    start_time: datetime,
    end_time: datetime,
    log_level: Optional[str] = None,
    limit: int = 100,
    include_metadata: bool = False
) -> List[Dict[str, any]]:
    """Search logs with type annotations."""
    pass
```

### Complex Parameters

Use Pydantic models for complex parameter structures:

```python
from pydantic import BaseModel, Field
from typing import List, Optional

class DeploymentConfig(BaseModel):
    """Deployment configuration."""
    
    environment: str = Field(..., description="Target environment")
    replicas: int = Field(default=3, ge=1, le=10)
    resources: dict = Field(default={})
    health_check_path: str = Field(default="/health")

class RolloutStrategy(BaseModel):
    """Rollout strategy configuration."""
    
    type: str = Field(..., description="Strategy type: blue-green, canary, rolling")
    steps: List[dict] = Field(default=[])
    timeout_seconds: int = Field(default=300, ge=0)

@mcp.tool()
async def deploy_application(
    app_name: str,
    version: str,
    config: DeploymentConfig,
    strategy: Optional[RolloutStrategy] = None
) -> dict:
    """
    Deploy application with complex configuration.
    
    Args:
        app_name: Application identifier
        version: Version to deploy
        config: Deployment configuration
        strategy: Optional rollout strategy
    
    Returns:
        Deployment status and details
    """
    pass
```

### Default Values

Provide sensible defaults for optional parameters:

```python
@mcp.tool()
async def list_resources(
    page: int = 1,
    page_size: int = 50,
    sort_by: str = "created_at",
    sort_order: str = "desc",
    include_deleted: bool = False
) -> dict:
    """List resources with sensible pagination defaults."""
    pass
```

## Response Standards

### Consistent Structure

All tool responses follow a consistent structure:

```python
{
    "success": true,
    "data": { ... },
    "metadata": {
        "timestamp": "2025-11-18T10:30:00Z",
        "correlation_id": "abc-123-xyz",
        "version": "1.0.0"
    }
}
```

### Success Response

```python
@mcp.tool()
async def create_assignment(title: str, assignee: str) -> dict:
    """Create assignment with standard success response."""
    
    assignment = await backend.create_assignment(title, assignee)
    
    return {
        "success": True,
        "data": {
            "id": assignment.id,
            "title": assignment.title,
            "assignee": assignment.assignee,
            "status": "created",
            "created_at": assignment.created_at.isoformat()
        },
        "metadata": {
            "timestamp": datetime.utcnow().isoformat(),
            "correlation_id": get_correlation_id(),
            "version": "1.0.0"
        }
    }
```

### Error Response

```python
from fastapi import HTTPException

@mcp.tool()
async def get_assignment(assignment_id: str) -> dict:
    """Get assignment with error handling."""
    
    try:
        assignment = await backend.get_assignment(assignment_id)
        
        if not assignment:
            raise HTTPException(
                status_code=404,
                detail={
                    "error": "not_found",
                    "message": f"Assignment {assignment_id} not found",
                    "correlation_id": get_correlation_id()
                }
            )
        
        return {
            "success": True,
            "data": assignment.to_dict(),
            "metadata": {
                "timestamp": datetime.utcnow().isoformat(),
                "correlation_id": get_correlation_id()
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving assignment: {e}")
        raise HTTPException(
            status_code=500,
            detail={
                "error": "internal_error",
                "message": "Failed to retrieve assignment",
                "correlation_id": get_correlation_id()
            }
        )
```

### Pagination Response

```python
@mcp.tool()
async def list_assignments(
    page: int = 1,
    page_size: int = 50
) -> dict:
    """List assignments with pagination."""
    
    results = await backend.list_assignments(page, page_size)
    
    return {
        "success": True,
        "data": [item.to_dict() for item in results.items],
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": results.total,
            "total_pages": (results.total + page_size - 1) // page_size,
            "has_next": page < results.total_pages,
            "has_previous": page > 1
        },
        "metadata": {
            "timestamp": datetime.utcnow().isoformat(),
            "correlation_id": get_correlation_id()
        }
    }
```

## Error Handling

> **SRS References:** FR-PROTO-019 through FR-PROTO-024, FR-TOOL-004, FR-TOOL-013

### Protocol Errors vs Tool Execution Errors

MCP distinguishes two error categories. Using the wrong one breaks client error handling:

| Category | When to Use | Transport | Key |
|----------|-------------|-----------|-----|
| **Protocol Error** | Invalid JSON-RPC, unknown method, transport failure | JSON-RPC `error` field | Standard error codes |
| **Tool Execution Error** | Tool logic failure, validation, backend error | JSON-RPC `result` with `isError: true` | `result.content[].text` |

**Protocol Error Codes (JSON-RPC 2.0):**

| Code | Name | When |
|------|------|------|
| `-32700` | Parse Error | Malformed JSON received |
| `-32600` | Invalid Request | Request is not valid JSON-RPC |
| `-32601` | Method Not Found | Tool/method does not exist |
| `-32602` | Invalid Params | Params fail JSON Schema validation at protocol level |
| `-32603` | Internal Error | Unexpected server crash |

**Tool Execution Error (isError pattern):**

```python
@mcp.tool()
async def get_forecast(city: str) -> dict:
    """Get weather forecast — returns isError on business failure."""
    try:
        data = await weather_api.get(city, timeout=30)
        return {"content": [{"type": "text", "text": json.dumps(data)}]}
    except ValidationError as e:
        # Tool execution error — NOT a protocol error
        return {
            "content": [{"type": "text", "text": f"Invalid input: {e}"}],
            "isError": True,
        }
    except ExternalAPIError as e:
        return {
            "content": [{"type": "text", "text": f"Service unavailable: {e}"}],
            "isError": True,
        }
```

**Critical rule:** Input validation failures **must** return `isError: true` in the result, not a JSON-RPC error code (FR-TOOL-004, FR-PROTO-020). Protocol error codes are reserved for protocol-level failures.

**All error responses must:**

- Include a correlation ID (FR-PROTO-023)
- Never expose stack traces, internal paths, or secrets (FR-PROTO-021, FR-TOOL-013)
- Log full context server-side: correlation ID, user, endpoint, parameters (FR-PROTO-024)

### Error Code Framework

Define standard error codes:

```python
from enum import Enum

class ErrorCode(str, Enum):
    """Standard error codes."""
    
    # Client errors (4xx)
    INVALID_INPUT = "invalid_input"
    NOT_FOUND = "not_found"
    UNAUTHORIZED = "unauthorized"
    FORBIDDEN = "forbidden"
    CONFLICT = "conflict"
    RATE_LIMITED = "rate_limited"
    
    # Server errors (5xx)
    INTERNAL_ERROR = "internal_error"
    SERVICE_UNAVAILABLE = "service_unavailable"
    TIMEOUT = "timeout"
    DEPENDENCY_FAILURE = "dependency_failure"
```

### Structured Error Responses

```python
from dataclasses import dataclass
from typing import Optional, Dict, Any

@dataclass
class ErrorResponse:
    """Structured error response."""
    
    error_code: ErrorCode
    message: str
    details: Optional[Dict[str, Any]] = None
    correlation_id: Optional[str] = None
    timestamp: Optional[str] = None
    
    def to_dict(self) -> dict:
        return {
            "error": self.error_code.value,
            "message": self.message,
            "details": self.details or {},
            "correlation_id": self.correlation_id,
            "timestamp": self.timestamp or datetime.utcnow().isoformat()
        }

@mcp.tool()
async def validate_config(config: dict) -> dict:
    """Validate configuration with structured errors."""
    
    try:
        # Validate configuration
        errors = []
        
        if "environment" not in config:
            errors.append({
                "field": "environment",
                "error": "required",
                "message": "Environment field is required"
            })
        
        if "replicas" in config:
            if not isinstance(config["replicas"], int):
                errors.append({
                    "field": "replicas",
                    "error": "invalid_type",
                    "message": "Replicas must be an integer"
                })
            elif config["replicas"] < 1:
                errors.append({
                    "field": "replicas",
                    "error": "invalid_range",
                    "message": "Replicas must be at least 1"
                })
        
        if errors:
            error_response = ErrorResponse(
                error_code=ErrorCode.INVALID_INPUT,
                message="Configuration validation failed",
                details={"validation_errors": errors},
                correlation_id=get_correlation_id()
            )
            
            raise HTTPException(
                status_code=400,
                detail=error_response.to_dict()
            )
        
        return {
            "success": True,
            "data": {"valid": True},
            "metadata": {"correlation_id": get_correlation_id()}
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Validation error: {e}")
        error_response = ErrorResponse(
            error_code=ErrorCode.INTERNAL_ERROR,
            message="Internal validation error",
            correlation_id=get_correlation_id()
        )
        raise HTTPException(status_code=500, detail=error_response.to_dict())
```

### Error Context

Include actionable information in error messages:

```python
# ✅ Good - Actionable error message
{
    "error": "invalid_input",
    "message": "Invalid priority value",
    "details": {
        "field": "priority",
        "provided_value": 10,
        "allowed_range": "1-5",
        "suggestion": "Use a priority value between 1 and 5"
    }
}

# ❌ Bad - Vague error message
{
    "error": "error",
    "message": "Something went wrong"
}
```

## Documentation Standards

### Tool Docstrings

Provide comprehensive docstrings:

```python
@mcp.tool()
async def create_deployment(
    app_name: str,
    version: str,
    environment: str,
    config: Optional[dict] = None
) -> dict:
    """
    Create a new deployment for an application.
    
    This tool initiates a deployment process for the specified application
    version to the target environment. The deployment follows the configured
    rollout strategy and includes health checks.
    
    Args:
        app_name: Application identifier (e.g., "web-api", "data-processor")
        version: Semantic version to deploy (e.g., "1.2.3", "2.0.0-beta.1")
        environment: Target environment ("dev", "staging", "production")
        config: Optional deployment configuration overrides
    
    Returns:
        Deployment details including:
        - deployment_id: Unique identifier for this deployment
        - status: Current deployment status
        - started_at: Deployment start timestamp
        - estimated_completion: Estimated completion time
    
    Raises:
        HTTPException (400): Invalid input parameters
        HTTPException (404): Application or version not found
        HTTPException (409): Deployment already in progress
        HTTPException (500): Internal deployment error
    
    Example:
        >>> result = await create_deployment(
        ...     app_name="web-api",
        ...     version="1.2.3",
        ...     environment="production"
        ... )
        >>> print(result["data"]["deployment_id"])
        "deploy-abc123"
    """
    pass
```

### Parameter Descriptions

Document parameter constraints and formats:

```python
@mcp.tool()
async def search_logs(
    query: str,
    start_time: str,
    end_time: str,
    log_level: Optional[str] = None
) -> dict:
    """
    Search application logs within a time range.
    
    Args:
        query: Search query string. Supports:
               - Exact match: "error message"
               - Wildcards: "error*"
               - Boolean: "error AND timeout"
        start_time: ISO 8601 timestamp (e.g., "2025-11-18T10:00:00Z")
        end_time: ISO 8601 timestamp (e.g., "2025-11-18T12:00:00Z")
        log_level: Filter by level. One of: DEBUG, INFO, WARN, ERROR
    
    Returns:
        List of log entries matching the search criteria.
        Each entry includes timestamp, level, message, and metadata.
    """
    pass
```

## Versioning Strategy

### Tool Versioning

Version tools when making breaking changes:

```python
# Version 1 - Original
@mcp.tool()
async def create_assignment(
    title: str,
    assignee: str
) -> dict:
    """Create assignment (v1)."""
    pass

# Version 2 - Breaking change (required new parameter)
@mcp.tool()
async def create_assignment_v2(
    title: str,
    assignee: str,
    project_id: str  # New required parameter
) -> dict:
    """Create assignment (v2) - requires project_id."""
    pass

# Deprecate v1
@mcp.tool(deprecated=True)
async def create_assignment(
    title: str,
    assignee: str
) -> dict:
    """
    Create assignment (v1) - DEPRECATED.
    
    This version is deprecated. Use create_assignment_v2 instead.
    Will be removed in version 3.0.0.
    """
    pass
```

### Backward Compatibility

Maintain backward compatibility when possible:

```python
@mcp.tool()
async def list_resources(
    page: int = 1,
    page_size: int = 50,
    # New optional parameter - backward compatible
    include_metadata: bool = False
) -> dict:
    """
    List resources with optional metadata.
    
    Version History:
    - v1.0.0: Initial release
    - v1.1.0: Added include_metadata parameter (backward compatible)
    """
    pass
```

## Testing Standards

### Unit Tests for Tools

```python
import pytest
from unittest.mock import AsyncMock, patch

@pytest.mark.asyncio
async def test_create_assignment_success():
    """Test successful assignment creation."""
    # Mock backend
    with patch('backend.create_assignment') as mock_create:
        mock_create.return_value = AsyncMock(
            id="123",
            title="Test Assignment",
            assignee="user@example.com",
            created_at=datetime.utcnow()
        )
        
        # Call tool
        result = await create_assignment(
            title="Test Assignment",
            assignee="user@example.com"
        )
        
        # Assertions
        assert result["success"] is True
        assert result["data"]["id"] == "123"
        assert result["data"]["title"] == "Test Assignment"
        
        # Verify backend called correctly
        mock_create.assert_called_once_with(
            "Test Assignment",
            "user@example.com"
        )

@pytest.mark.asyncio
async def test_create_assignment_validation_error():
    """Test assignment creation with invalid input."""
    with pytest.raises(HTTPException) as exc_info:
        await create_assignment(
            title="",  # Invalid: empty title
            assignee="user@example.com"
        )
    
    assert exc_info.value.status_code == 400
    assert "title" in exc_info.value.detail["details"]
```

## Summary

Consistent tool implementation ensures:

- **Clear Naming**: Verb-noun pattern for all tools
- **Type Safety**: Full type annotations on parameters and returns
- **Validation**: Pydantic models for complex inputs
- **Standard Responses**: Consistent success/error structures
- **Error Handling**: Structured errors with actionable messages
- **Documentation**: Comprehensive docstrings with examples
- **Versioning**: Clear deprecation and backward compatibility
- **Testing**: Unit tests for all tools

---

**Next**: Review [Testing Strategy](04-testing-strategy.md) for comprehensive testing approaches.
