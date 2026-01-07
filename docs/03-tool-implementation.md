# Tool Implementation Standards

**Navigation**: [Home](../README.md) > Implementation Standards > Tool Implementation  
**Related**: [← Previous: Requirements Engineering](02b-requirements-engineering.md) | [Next: Prompt Implementation →](03a-prompt-implementation.md) | [Decision Trees](03d-decision-trees.md#tool-vs-prompt-vs-resource-selection)

**Version:** 1.4.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Quick Links

- [Domain Focus Reminder](#domain-focus-reminder)
- [Naming Conventions](#naming-conventions)
- [Parameter Design](#parameter-design)
- [Response Standards](#response-standards)
- [Error Handling](#error-handling)
- [STDIO Logging Constraints](#stdio-logging-constraints)
- [External API Integration](#external-api-integration-patterns)
- [Icon Metadata](#icon-metadata-mcp-2025-11-25)
- [Documentation Standards](#documentation-standards)
- [Versioning Strategy](#versioning-strategy)
- [Testing Standards](#testing-standards)
- [Summary](#summary)

## Introduction

Consistent tool implementation is critical for maintainability and user experience. This document establishes naming conventions, parameter design patterns, response formats, and error handling standards for MCP tools.

**Related Documentation:**

- [Prompt Implementation Standards](03a-prompt-implementation.md) - User-controlled workflow templates
- [Resource Implementation Standards](03b-resource-implementation.md) - Application-driven data access
- [Sampling Patterns](03c-sampling-patterns.md) - Server-initiated LLM interactions
- [Testing Strategy](04-testing-strategy.md) - Testing approaches for tools

---

## Domain Focus Reminder

> **All tools in an MCP server MUST relate to a single integration domain.**

Before implementing tools, verify they belong in this server:

| Check | Question |
|-------|----------|
| **Same Domain** | Do all tools interact with the same external system? |
| **Cohesive Context** | Can tools be described without "and also..."? |
| **Clear Ownership** | Is there one team responsible for the underlying integration? |

**Example:** A `mcp-github` server should only have GitHub-related tools:

```python
# ✅ CORRECT: All tools relate to GitHub
@mcp.tool()
async def create_issue(...): ...    # GitHub Issues

@mcp.tool()
async def list_pull_requests(...): ...    # GitHub PRs

@mcp.tool()
async def get_repository(...): ...    # GitHub Repos

# ❌ WRONG: Cross-domain tools don't belong here
@mcp.tool()
async def send_slack_message(...): ...    # Should be in mcp-slack

@mcp.tool()
async def create_jira_ticket(...): ...    # Should be in mcp-jira
```

Cross-domain workflows are handled by AI agents orchestrating multiple focused servers.

See [Architecture: Single Integration Domain](01-architecture-overview.md#core-architectural-principle-single-integration-domain) for details.

---

## Naming Conventions

Per the [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/changelog) (SEP-986), tool names should follow these guidelines for discoverability and clarity.

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

### Input Validation Errors (MCP 2025-11-25)

Per the [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/changelog) (SEP-1303), **input validation errors MUST be returned as Tool Execution Errors**, not Protocol Errors.

**Why?** Returning validation errors as Tool Execution Errors allows the LLM to:

- Understand what went wrong
- Self-correct and retry with valid parameters
- Provide meaningful feedback to the user

```python
@mcp.tool()
async def create_assignment(title: str, priority: int) -> str:
    """Create an assignment with validation."""
    
    # ❌ BAD: Raising exception causes Protocol Error
    # if priority < 1 or priority > 5:
    #     raise ValueError("Priority must be between 1 and 5")
    
    # ✅ GOOD: Return validation error as Tool Execution Error
    if priority < 1 or priority > 5:
        return json.dumps({
            "isError": True,
            "content": [{
                "type": "text",
                "text": "Validation failed: priority must be between 1 and 5"
            }]
        })
    
    # ✅ GOOD: FastMCP pattern - return error message directly
    if not title.strip():
        return "Error: title cannot be empty. Please provide a descriptive title."
    
    # Proceed with valid input
    assignment = await db.create_assignment(title=title, priority=priority)
    return f"Created assignment {assignment.id}: {title}"
```

**Error Response Pattern:**

| Error Type | Return As | LLM Behavior |
|------------|-----------|--------------|
| **Input Validation** | Tool Execution Error | LLM can self-correct |
| **Protocol Error** | JSON-RPC Error | LLM cannot recover |
| **External Service Failure** | Tool Execution Error | LLM can retry or inform user |

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

## STDIO Logging Constraints

When implementing MCP servers with STDIO transport (used for local development and Claude Desktop integration), you must follow strict logging rules to avoid corrupting the JSON-RPC protocol.

### The Problem

STDIO-based MCP servers communicate via stdin/stdout using JSON-RPC messages. Any non-JSON-RPC output to stdout (like `print()` statements) corrupts the protocol and breaks your server.

Per [MCP best practices](https://modelcontextprotocol.io/docs/develop/build-server):

> For STDIO-based servers: Never write to standard output (stdout). This includes `print()` statements in Python, `console.log()` in JavaScript, `fmt.Println()` in Go.

### Language-Specific Constraints

| Language | Prohibited | Recommended |
|----------|------------|-------------|
| **Python** | `print()` | `logging.info()` to stderr |
| **TypeScript** | `console.log()` | `console.error()` or structured logger |
| **Go** | `fmt.Println()` | `log.SetOutput(os.Stderr)` |
| **Rust** | `println!()` | `eprintln!()` or `tracing` to stderr |
| **Java** | `System.out.println()` | `Logger` to stderr or file |

### Python Logging Setup

```python
import logging
import sys

# ✅ RECOMMENDED: Configure logging to stderr
def setup_logging():
    """Configure logging for STDIO MCP server."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        stream=sys.stderr  # Critical: use stderr, not stdout
    )
    return logging.getLogger(__name__)

logger = setup_logging()

# ✅ RECOMMENDED: Use logger throughout
@mcp.tool()
async def process_data(data: str) -> str:
    """Process data with proper logging."""
    logger.info(f"Processing data: {len(data)} bytes")
    
    try:
        result = await do_processing(data)
        logger.debug(f"Processing complete: {result}")
        return result
    except Exception as e:
        logger.error(f"Processing failed: {e}")
        return f"Error: Unable to process data"

# ❌ AVOID: print() corrupts JSON-RPC protocol
@mcp.tool()
async def bad_example(data: str) -> str:
    print(f"Processing: {data}")  # BREAKS THE SERVER
    return "done"
```

### TypeScript Logging Setup

```typescript
// ✅ RECOMMENDED: Use stderr for logging
const log = {
  info: (msg: string) => console.error(`[INFO] ${msg}`),
  error: (msg: string) => console.error(`[ERROR] ${msg}`),
  debug: (msg: string) => console.error(`[DEBUG] ${msg}`)
};

// ❌ AVOID: console.log() writes to stdout
console.log("Debug message");  // BREAKS THE SERVER
```

### HTTP Transport Exception

This constraint only applies to STDIO transport. HTTP-based servers can log to stdout normally since HTTP responses are separate from log output:

```python
# For HTTP transport, stdout logging is fine
if transport_type == "http":
    logging.basicConfig(stream=sys.stdout)  # OK for HTTP
else:
    logging.basicConfig(stream=sys.stderr)  # Required for STDIO
```

## External API Integration Patterns

When tools integrate with external APIs, follow these patterns for reliability and maintainability.

### Helper Function Pattern

Create reusable helper functions for external API calls:

```python
from typing import Any
import httpx

# Constants
API_BASE = "https://api.example.com"
USER_AGENT = "my-mcp-server/1.0"
DEFAULT_TIMEOUT = 30.0

async def make_api_request(
    url: str,
    method: str = "GET",
    headers: dict | None = None,
    json_data: dict | None = None,
    timeout: float = DEFAULT_TIMEOUT
) -> dict[str, Any] | None:
    """Make an HTTP request to external API with proper error handling.
    
    This helper implements best practices:
    - Explicit timeout handling (prevents hanging)
    - User-Agent header (API etiquette)
    - Graceful error handling (returns None on failure)
    - Async for non-blocking I/O
    
    Args:
        url: Full URL to request
        method: HTTP method (GET, POST, PUT, DELETE)
        headers: Additional headers to include
        json_data: JSON body for POST/PUT requests
        timeout: Request timeout in seconds
        
    Returns:
        Parsed JSON response or None on error
    """
    default_headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json"
    }
    
    if headers:
        default_headers.update(headers)
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.request(
                method=method,
                url=url,
                headers=default_headers,
                json=json_data,
                timeout=timeout
            )
            response.raise_for_status()
            return response.json()
        except httpx.TimeoutException:
            logger.error(f"Request timeout: {url}")
            return None
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error {e.response.status_code}: {url}")
            return None
        except Exception as e:
            logger.error(f"Request failed: {url} - {e}")
            return None
```

### Tool with External API

```python
@mcp.tool()
async def get_weather(city: str) -> str:
    """Get current weather for a city.
    
    Args:
        city: City name (e.g., "New York", "London")
    """
    url = f"{API_BASE}/weather?city={city}"
    data = await make_api_request(url)
    
    if not data:
        # User-friendly error message, not technical details
        return f"Unable to fetch weather data for {city}. Please try again later."
    
    return format_weather_response(data)
```

### Retry Pattern with Exponential Backoff

For transient failures, implement retry logic:

```python
import asyncio
from typing import TypeVar, Callable, Awaitable

T = TypeVar('T')

async def with_retry(
    func: Callable[[], Awaitable[T]],
    max_retries: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 30.0
) -> T | None:
    """Execute async function with exponential backoff retry.
    
    Args:
        func: Async function to execute
        max_retries: Maximum retry attempts
        base_delay: Initial delay in seconds
        max_delay: Maximum delay between retries
        
    Returns:
        Function result or None after all retries exhausted
    """
    for attempt in range(max_retries + 1):
        try:
            return await func()
        except Exception as e:
            if attempt == max_retries:
                logger.error(f"All retries exhausted: {e}")
                return None
            
            delay = min(base_delay * (2 ** attempt), max_delay)
            logger.warning(f"Attempt {attempt + 1} failed, retrying in {delay}s: {e}")
            await asyncio.sleep(delay)
    
    return None

# Usage in a tool
@mcp.tool()
async def fetch_data_with_retry(resource_id: str) -> str:
    """Fetch data with automatic retry on failure."""
    
    async def _fetch():
        url = f"{API_BASE}/resources/{resource_id}"
        response = await make_api_request(url)
        if response is None:
            raise Exception("Request failed")
        return response
    
    data = await with_retry(_fetch, max_retries=3)
    
    if data is None:
        return f"Unable to fetch resource {resource_id} after multiple attempts."
    
    return format_resource(data)
```

### Circuit Breaker Pattern

For services that may be unavailable for extended periods:

```python
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum

class CircuitState(Enum):
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Failing, reject requests
    HALF_OPEN = "half_open"  # Testing if service recovered

@dataclass
class CircuitBreaker:
    """Simple circuit breaker implementation."""
    
    failure_threshold: int = 5
    recovery_timeout: float = 30.0
    
    _state: CircuitState = CircuitState.CLOSED
    _failure_count: int = 0
    _last_failure_time: datetime | None = None
    
    def can_execute(self) -> bool:
        """Check if request should be allowed."""
        if self._state == CircuitState.CLOSED:
            return True
        
        if self._state == CircuitState.OPEN:
            if self._last_failure_time:
                elapsed = (datetime.now() - self._last_failure_time).total_seconds()
                if elapsed > self.recovery_timeout:
                    self._state = CircuitState.HALF_OPEN
                    return True
            return False
        
        return True  # HALF_OPEN allows one request
    
    def record_success(self):
        """Record successful request."""
        self._failure_count = 0
        self._state = CircuitState.CLOSED
    
    def record_failure(self):
        """Record failed request."""
        self._failure_count += 1
        self._last_failure_time = datetime.now()
        
        if self._failure_count >= self.failure_threshold:
            self._state = CircuitState.OPEN

# Usage
weather_circuit = CircuitBreaker(failure_threshold=5, recovery_timeout=30.0)

@mcp.tool()
async def get_weather_with_circuit_breaker(city: str) -> str:
    """Get weather with circuit breaker protection."""
    
    if not weather_circuit.can_execute():
        return "Weather service temporarily unavailable. Please try again later."
    
    data = await make_api_request(f"{API_BASE}/weather?city={city}")
    
    if data is None:
        weather_circuit.record_failure()
        return f"Unable to fetch weather for {city}."
    
    weather_circuit.record_success()
    return format_weather_response(data)
```

## Icon Metadata (MCP 2025-11-25)

Per the [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/changelog) (SEP-973), servers can expose **icons as additional metadata** for tools, resources, resource templates, and prompts. This improves UI presentation in MCP clients.

### Tool Icon Definition

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.tool(
    icon="https://example.com/icons/search.svg"  # Optional icon URL
)
async def search_documents(query: str) -> str:
    """Search for documents matching the query."""
    # Implementation
    return f"Found results for: {query}"
```

### Icon Requirements

| Requirement | Specification |
|-------------|---------------|
| **Format** | SVG, PNG, or data URI |
| **Size** | Recommended: 24x24 or 32x32 pixels |
| **Accessibility** | HTTPS URLs only (no HTTP) |
| **Caching** | Clients should cache icons |
| **Fallback** | Clients should handle missing/invalid icons gracefully |

### Icon Best Practices

| Practice | Recommendation |
|----------|----------------|
| **Consistent Style** | Use consistent icon style across all tools |
| **Semantic Icons** | Choose icons that represent the tool's action |
| **SVG Preferred** | SVGs scale better and are smaller |
| **CDN Hosting** | Host icons on a CDN for performance |
| **Versioning** | Include version in icon URL for cache busting |

**Example with Data URI:**

```python
# Inline SVG as data URI (no external dependency)
SEARCH_ICON = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiPjxjaXJjbGUgY3g9IjExIiBjeT0iMTEiIHI9IjgiLz48bGluZSB4MT0iMjEiIHkxPSIyMSIgeDI9IjE2LjY1IiB5Mj0iMTYuNjUiLz48L3N2Zz4="

@mcp.tool(icon=SEARCH_ICON)
async def search_documents(query: str) -> str:
    """Search for documents."""
    pass
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
