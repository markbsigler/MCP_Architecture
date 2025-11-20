# Resource Implementation Standards

**Navigation**: [Home](../README.md) > Implementation Standards > Resource Implementation  
**Related**: [← Previous: Prompt Implementation](03a-prompt-implementation.md) | [Next: Sampling Patterns →](03c-sampling-patterns.md) | [Agentic Best Practices](09-agentic-best-practices.md#resource-template-architecture)

**Version:** 1.3.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Overview

Resources provide structured, read-only access to data sources that AI applications can retrieve and provide to models as context. Unlike tools (which enable actions) and prompts (which provide workflows), **resources are application-driven** - the client application decides when and how to retrieve resource data and present it to the model.

According to the [official MCP server documentation](https://modelcontextprotocol.io/docs/learn/server-concepts), resources expose data from:

- File systems (documents, configurations, logs)
- APIs (external service responses, structured data)
- Databases (query results, schemas, metadata)
- Live data sources (real-time feeds, monitoring systems)

This section establishes implementation standards for creating effective, scalable MCP resources.

**Related Documentation:**

- [Tool Implementation Standards](03-tool-implementation.md) - Action-oriented APIs
- [Prompt Implementation Standards](03a-prompt-implementation.md) - Leveraging resources in prompts
- [Integration Patterns](03e-integration-patterns.md) - API and database integration
- [Performance & Scalability](06a-performance-scalability.md) - Caching and optimization

---

## Core Resource Concepts

### Application-Driven Access

Resources differ fundamentally from tools and prompts in their control model:

```text
Tools:    Model-controlled → Automatic execution (with approval)
Prompts:  User-controlled → Explicit invocation with parameters
Resources: Application-controlled → Fetched and processed by client
```

**Key characteristics:**

- Provide read-only access to data
- Support both static URIs and dynamic templates
- Enable client-side filtering and processing
- Allow subscription for change notifications

### Resource Protocol Operations

The MCP specification defines four core operations:

| Operation | Purpose | Response |
|-----------|---------|----------|
| `resources/list` | List available static resources | Array of resource descriptors |
| `resources/templates/list` | Discover dynamic resource templates | Array of template definitions |
| `resources/read` | Retrieve resource contents | Resource data with metadata |
| `resources/subscribe` | Monitor resource changes | Subscription confirmation |

---

## URI Design Patterns

### URI Scheme Standards

Resource URIs should follow consistent, descriptive patterns:

**Good examples:**

```text
file:///path/to/document.md
calendar://events/2024
weather://forecast/barcelona/2024-06-15
database://schema/users
api://github/repos/owner/repo/issues
travel://preferences/europe
trips://history/barcelona-2023
```

**Avoid:**

```text
resource://1                    # Generic - no context
data                            # Missing scheme
http://api.example.com/v1/data  # Direct HTTP - wrap in semantic URI
file://relative/path            # Use absolute paths
```

### URI Component Structure

Follow hierarchical patterns for discoverability:

```text
scheme://category/subcategory/identifier

Examples:
  calendar://events/2024/june
  weather://forecast/barcelona/2024-06-15
  database://tables/users/schema
  api://github/repos/modelcontextprotocol/servers/issues/42
```

**Guidelines:**

- Use hierarchical paths (most general → most specific)
- Include semantic categories for organization
- Support prefix-based discovery
- Maintain consistent depth within domain

### Static vs. Dynamic Resources

**Static Resources** - Fixed URIs pointing to specific data:

```python
from mcp.server.fastmcp import FastMCP
from mcp.types import Resource, TextContent

mcp = FastMCP("calendar-server")

@mcp.resource("calendar://events/2024")
async def calendar_2024() -> str:
    """Return all calendar events for 2024."""
    events = await fetch_calendar_events(year=2024)
    return format_events_as_markdown(events)
```

**Dynamic Resources (Templates)** - Parameterized URIs for flexible queries:

```python
@mcp.resource("weather://forecast/{city}/{date}")
async def weather_forecast(city: str, date: str) -> str:
    """Return weather forecast for any city/date combination."""
    forecast = await fetch_weather_data(city, date)
    return format_forecast_as_json(forecast)
```

---

## Resource Definition Standards

### Basic Resource Structure

Every resource must provide clear identification and metadata:

```python
from mcp.server.fastmcp import FastMCP
from mcp.types import Resource, TextContent

mcp = FastMCP("documentation-server")

@mcp.resource("file:///docs/architecture.md")
async def architecture_doc() -> str:
    """Architecture documentation.
    
    Returns the complete system architecture documentation
    including diagrams, design decisions, and component descriptions.
    """
    with open("/docs/architecture.md", "r") as f:
        return f.read()
```

### Resource Metadata

Include comprehensive metadata for discovery:

```python
from mcp.types import Resource

@mcp.resource(
    uri="database://schema/users",
    name="user-database-schema",
    description="User database schema including tables, columns, and relationships",
    mimeType="application/json"
)
async def user_schema() -> str:
    """Return database schema as JSON."""
    schema = await fetch_database_schema("users")
    return json.dumps(schema, indent=2)
```

**Required metadata:**

- `uri` - Unique resource identifier
- `name` - Machine-readable identifier (kebab-case)
- `description` - Human-readable purpose description
- `mimeType` - Content type for appropriate handling

---

## MIME Type Handling

### Standard MIME Types

Use standard MIME types for proper content handling:

**Text formats:**

```python
@mcp.resource("file:///docs/readme.md", mimeType="text/markdown")
async def readme() -> str:
    """Return README in Markdown format."""
    pass

@mcp.resource("file:///config/app.yaml", mimeType="text/yaml")
async def app_config() -> str:
    """Return application configuration in YAML."""
    pass

@mcp.resource("file:///logs/app.log", mimeType="text/plain")
async def app_logs() -> str:
    """Return application logs as plain text."""
    pass
```

**Structured data:**

```python
@mcp.resource("api://users/list", mimeType="application/json")
async def user_list() -> str:
    """Return user list as JSON."""
    users = await fetch_users()
    return json.dumps(users)

@mcp.resource("database://export", mimeType="application/xml")
async def database_export() -> str:
    """Return database export as XML."""
    pass
```

**Binary formats:**

```python
@mcp.resource("file:///assets/logo.png", mimeType="image/png")
async def logo_image() -> bytes:
    """Return logo image as PNG bytes."""
    with open("/assets/logo.png", "rb") as f:
        return f.read()

@mcp.resource("file:///docs/manual.pdf", mimeType="application/pdf")
async def user_manual() -> bytes:
    """Return user manual as PDF."""
    pass
```

### Content Type Detection

Automatically detect MIME types when appropriate:

```python
import mimetypes

@mcp.resource("file:///{path}")
async def file_resource(path: str) -> str | bytes:
    """Return file with automatic MIME type detection."""
    
    # Detect MIME type from file extension
    mime_type, _ = mimetypes.guess_type(path)
    
    # Read as binary for non-text types
    if mime_type and not mime_type.startswith("text/"):
        with open(path, "rb") as f:
            return f.read()
    
    # Read as text for text types
    with open(path, "r") as f:
        return f.read()
```

---

## Resource Templates

### Template URI Patterns

Define flexible templates with clear parameter patterns:

```python
@mcp.resource("weather://forecast/{city}/{date}")
async def weather_forecast_template(
    city: str,
    date: str
) -> str:
    """Weather forecast template.
    
    Args:
        city: City name (e.g., "Barcelona", "Paris")
        date: ISO 8601 date (YYYY-MM-DD)
    
    Returns:
        Weather forecast as JSON
    """
    forecast = await fetch_weather(city, date)
    return json.dumps(forecast, indent=2)
```

### Multi-Parameter Templates

Support complex queries with multiple parameters:

```python
@mcp.resource("travel://activities/{city}/{category}/{price_range}")
async def activity_search(
    city: str,
    category: str,
    price_range: str
) -> str:
    """Search activities with multiple filters.
    
    Examples:
        travel://activities/barcelona/museums/budget
        travel://activities/paris/restaurants/luxury
        travel://activities/tokyo/technology/moderate
    """
    activities = await search_activities(
        city=city,
        category=category,
        price_range=price_range
    )
    return format_activities_json(activities)
```

### Optional Template Parameters

Support optional parameters with query strings:

```python
from urllib.parse import parse_qs, urlparse

@mcp.resource("api://repos/{owner}/{repo}/issues")
async def github_issues(
    owner: str,
    repo: str,
    uri: str  # Full URI for query string parsing
) -> str:
    """GitHub issues with optional filters.
    
    Supports query parameters:
        ?state=open|closed|all
        ?labels=bug,enhancement
        ?sort=created|updated|comments
    
    Examples:
        api://repos/owner/repo/issues?state=open
        api://repos/owner/repo/issues?labels=bug&sort=updated
    """
    # Parse query parameters
    parsed = urlparse(uri)
    params = parse_qs(parsed.query)
    
    state = params.get("state", ["open"])[0]
    labels = params.get("labels", [""])[0].split(",") if "labels" in params else None
    sort = params.get("sort", ["created"])[0]
    
    issues = await fetch_github_issues(
        owner=owner,
        repo=repo,
        state=state,
        labels=labels,
        sort=sort
    )
    
    return json.dumps(issues, indent=2)
```

---

## Parameter Completion

### Implementing Completion Suggestions

Provide completion suggestions for discoverable parameter values:

```python
@mcp.resource("weather://forecast/{city}/{date}")
async def weather_forecast(city: str, date: str) -> str:
    """Weather forecast with parameter completion."""
    pass

# Completion handler for city parameter
@mcp.complete_resource_template_argument(
    template="weather://forecast/{city}/{date}",
    argument="city"
)
async def complete_city(prefix: str) -> list[str]:
    """Suggest city names matching prefix.
    
    Args:
        prefix: Partial city name (e.g., "Par")
    
    Returns:
        Matching city names (e.g., ["Paris", "Park City"])
    """
    cities = await search_cities(prefix)
    return [city.name for city in cities]

# Completion handler for date parameter
@mcp.complete_resource_template_argument(
    template="weather://forecast/{city}/{date}",
    argument="date"
)
async def complete_date(prefix: str) -> list[str]:
    """Suggest dates matching prefix.
    
    Args:
        prefix: Partial date (e.g., "2024-")
    
    Returns:
        Valid dates (e.g., ["2024-01-01", "2024-01-02"])
    """
    # Generate next 7 days
    from datetime import datetime, timedelta
    today = datetime.now()
    dates = [(today + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(7)]
    
    # Filter by prefix
    return [d for d in dates if d.startswith(prefix)]
```

### Context-Aware Completion

Provide intelligent suggestions based on context:

```python
@mcp.complete_resource_template_argument(
    template="travel://flights/{origin}/{destination}",
    argument="destination"
)
async def complete_destination(
    prefix: str,
    origin: str  # Use origin parameter for context
) -> list[str]:
    """Suggest destinations based on origin airport.
    
    Provides popular routes and nearby airports first.
    """
    # Get popular destinations from this origin
    popular = await fetch_popular_routes(origin)
    
    # Search all airports matching prefix
    all_airports = await search_airports(prefix)
    
    # Prioritize popular routes
    suggestions = []
    for airport in popular:
        if airport.code.startswith(prefix.upper()):
            suggestions.append(f"{airport.code} - {airport.name}")
    
    for airport in all_airports:
        suggestion = f"{airport.code} - {airport.name}"
        if suggestion not in suggestions:
            suggestions.append(suggestion)
    
    return suggestions[:10]  # Limit to 10 suggestions
```

---

## Data Formatting and Presentation

### Structured Data (JSON)

Format structured data consistently:

```python
@mcp.resource("api://users/{user_id}")
async def user_profile(user_id: str) -> str:
    """Return user profile as structured JSON."""
    
    user = await fetch_user(user_id)
    
    # Format with consistent structure
    profile = {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "created_at": user.created_at.isoformat(),
        "metadata": {
            "last_login": user.last_login.isoformat(),
            "account_status": user.status,
            "preferences": user.preferences
        }
    }
    
    return json.dumps(profile, indent=2, ensure_ascii=False)
```

### Markdown for Rich Text

Use Markdown for human-readable formatted content:

```python
@mcp.resource("calendar://events/{date}")
async def daily_events(date: str) -> str:
    """Return daily events as formatted Markdown."""
    
    events = await fetch_events_for_date(date)
    
    # Build Markdown output
    md = f"# Events for {date}\n\n"
    
    for event in events:
        md += f"## {event.title}\n\n"
        md += f"**Time:** {event.start_time} - {event.end_time}\n"
        md += f"**Location:** {event.location}\n\n"
        
        if event.description:
            md += f"{event.description}\n\n"
        
        if event.attendees:
            md += f"**Attendees:** {', '.join(event.attendees)}\n\n"
        
        md += "---\n\n"
    
    return md
```

### Tables and Lists

Format tabular data appropriately:

```python
@mcp.resource("database://tables/{table_name}/schema")
async def table_schema(table_name: str) -> str:
    """Return table schema as Markdown table."""
    
    columns = await fetch_table_columns(table_name)
    
    # Build Markdown table
    md = f"# Schema: {table_name}\n\n"
    md += "| Column | Type | Nullable | Default | Description |\n"
    md += "|--------|------|----------|---------|-------------|\n"
    
    for col in columns:
        nullable = "Yes" if col.nullable else "No"
        default = col.default or "-"
        description = col.description or "-"
        md += f"| {col.name} | {col.type} | {nullable} | {default} | {description} |\n"
    
    return md
```

---

## Pagination and Large Data

### Cursor-Based Pagination

Implement pagination for large datasets:

```python
@mcp.resource("api://repos/{owner}/{repo}/commits")
async def repo_commits(
    owner: str,
    repo: str,
    uri: str
) -> str:
    """Return paginated commit history.
    
    Query parameters:
        ?cursor=<commit_sha> - Start after this commit
        ?limit=<number> - Items per page (default: 50, max: 100)
    
    Response includes:
        - commits: Array of commit objects
        - next_cursor: SHA of last commit (for next page)
        - has_more: Boolean indicating more results available
    """
    parsed = urlparse(uri)
    params = parse_qs(parsed.query)
    
    cursor = params.get("cursor", [None])[0]
    limit = min(int(params.get("limit", ["50"])[0]), 100)
    
    commits = await fetch_commits(
        owner=owner,
        repo=repo,
        after=cursor,
        limit=limit + 1  # Fetch one extra to check for more
    )
    
    has_more = len(commits) > limit
    if has_more:
        commits = commits[:limit]
    
    response = {
        "commits": [format_commit(c) for c in commits],
        "next_cursor": commits[-1].sha if commits else None,
        "has_more": has_more
    }
    
    return json.dumps(response, indent=2)
```

### Streaming Large Resources

Stream large resources to avoid memory issues:

```python
@mcp.resource("file:///logs/application.log")
async def large_log_file() -> AsyncIterator[str]:
    """Stream large log file in chunks."""
    
    chunk_size = 8192  # 8KB chunks
    
    async with aiofiles.open("/logs/application.log", "r") as f:
        while chunk := await f.read(chunk_size):
            yield chunk
```

### Truncation with Metadata

Truncate large responses with clear indicators:

```python
@mcp.resource("database://query/results")
async def query_results(uri: str) -> str:
    """Return query results with truncation metadata."""
    
    parsed = urlparse(uri)
    params = parse_qs(parsed.query)
    query = params.get("sql", [""])[0]
    max_rows = int(params.get("max_rows", ["1000"])[0])
    
    results = await execute_query(query, limit=max_rows + 1)
    
    truncated = len(results) > max_rows
    if truncated:
        results = results[:max_rows]
    
    response = {
        "query": query,
        "row_count": len(results),
        "truncated": truncated,
        "message": f"Results limited to {max_rows} rows" if truncated else None,
        "results": results
    }
    
    return json.dumps(response, indent=2)
```

---

## Resource Subscriptions

### Change Notifications

Implement subscriptions for real-time updates:

```python
from typing import AsyncIterator
from mcp.types import ResourceUpdate

@mcp.resource("file:///config/app.yaml", subscribable=True)
async def app_config() -> str:
    """Application configuration with change notifications."""
    with open("/config/app.yaml", "r") as f:
        return f.read()

# Subscription handler
@mcp.subscribe_resource("file:///config/app.yaml")
async def watch_app_config() -> AsyncIterator[ResourceUpdate]:
    """Watch for configuration file changes."""
    
    import asyncio
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    
    class ConfigHandler(FileSystemEventHandler):
        def __init__(self):
            self.queue = asyncio.Queue()
        
        def on_modified(self, event):
            if event.src_path.endswith("app.yaml"):
                self.queue.put_nowait(event)
    
    handler = ConfigHandler()
    observer = Observer()
    observer.schedule(handler, "/config", recursive=False)
    observer.start()
    
    try:
        while True:
            event = await handler.queue.get()
            
            # Read updated content
            with open("/config/app.yaml", "r") as f:
                content = f.read()
            
            yield ResourceUpdate(
                uri="file:///config/app.yaml",
                content=content,
                mimeType="text/yaml"
            )
    finally:
        observer.stop()
        observer.join()
```

### Polling for Updates

Implement polling for resources without native change detection:

```python
@mcp.resource("api://service/status", subscribable=True)
async def service_status() -> str:
    """Service status with polling-based updates."""
    status = await fetch_service_status()
    return json.dumps(status)

@mcp.subscribe_resource("api://service/status")
async def poll_service_status() -> AsyncIterator[ResourceUpdate]:
    """Poll service status every 30 seconds."""
    
    import asyncio
    
    previous_status = None
    
    while True:
        await asyncio.sleep(30)  # Poll every 30 seconds
        
        current_status = await fetch_service_status()
        
        # Only notify on changes
        if current_status != previous_status:
            yield ResourceUpdate(
                uri="api://service/status",
                content=json.dumps(current_status),
                mimeType="application/json"
            )
            previous_status = current_status
```

---

## Access Control and Security

### Resource-Level Permissions

Implement authorization checks:

```python
from mcp.server.fastmcp import Context

@mcp.resource("database://sensitive/user_data")
async def sensitive_data(ctx: Context) -> str:
    """Access controlled sensitive data."""
    
    # Check user permissions
    if not await has_permission(ctx.user_id, "read:sensitive_data"):
        raise PermissionError(
            f"User {ctx.user_id} not authorized to access sensitive data"
        )
    
    # Audit log access
    await log_access(
        user_id=ctx.user_id,
        resource="database://sensitive/user_data",
        timestamp=datetime.utcnow()
    )
    
    data = await fetch_sensitive_data()
    return json.dumps(data)
```

### Data Redaction

Redact sensitive information automatically:

```python
import re

def redact_pii(content: str) -> str:
    """Redact personally identifiable information."""
    
    # Redact email addresses
    content = re.sub(
        r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        '[EMAIL REDACTED]',
        content
    )
    
    # Redact phone numbers
    content = re.sub(
        r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b',
        '[PHONE REDACTED]',
        content
    )
    
    # Redact SSNs
    content = re.sub(
        r'\b\d{3}-\d{2}-\d{4}\b',
        '[SSN REDACTED]',
        content
    )
    
    return content

@mcp.resource("file:///logs/user_activity.log")
async def user_activity_log() -> str:
    """Return activity log with PII redacted."""
    
    with open("/logs/user_activity.log", "r") as f:
        content = f.read()
    
    return redact_pii(content)
```

### Rate Limiting

Protect resources from excessive access:

```python
from collections import defaultdict
from datetime import datetime, timedelta
import asyncio

class RateLimiter:
    def __init__(self, requests_per_minute: int):
        self.requests_per_minute = requests_per_minute
        self.requests = defaultdict(list)
    
    async def check_limit(self, client_id: str) -> bool:
        """Check if client is within rate limit."""
        now = datetime.utcnow()
        minute_ago = now - timedelta(minutes=1)
        
        # Clean old requests
        self.requests[client_id] = [
            req_time for req_time in self.requests[client_id]
            if req_time > minute_ago
        ]
        
        # Check limit
        if len(self.requests[client_id]) >= self.requests_per_minute:
            return False
        
        self.requests[client_id].append(now)
        return True

rate_limiter = RateLimiter(requests_per_minute=60)

@mcp.resource("api://expensive/computation")
async def expensive_resource(ctx: Context) -> str:
    """Rate-limited expensive resource."""
    
    if not await rate_limiter.check_limit(ctx.client_id):
        raise RateLimitError(
            f"Rate limit exceeded for client {ctx.client_id}. "
            f"Max {rate_limiter.requests_per_minute} requests per minute."
        )
    
    result = await perform_expensive_computation()
    return json.dumps(result)
```

---

## Caching Strategies

### Time-Based Caching

Cache resources with TTL:

```python
from functools import wraps
from datetime import datetime, timedelta
from typing import Dict, Tuple

class TTLCache:
    def __init__(self):
        self.cache: Dict[str, Tuple[str, datetime]] = {}
    
    def get(self, key: str, ttl: timedelta) -> str | None:
        """Get cached value if not expired."""
        if key in self.cache:
            value, timestamp = self.cache[key]
            if datetime.utcnow() - timestamp < ttl:
                return value
            else:
                del self.cache[key]
        return None
    
    def set(self, key: str, value: str) -> None:
        """Cache value with current timestamp."""
        self.cache[key] = (value, datetime.utcnow())

cache = TTLCache()

def cached_resource(ttl_seconds: int):
    """Decorator for caching resource responses."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Build cache key from function name and arguments
            cache_key = f"{func.__name__}:{args}:{kwargs}"
            
            # Check cache
            cached = cache.get(cache_key, timedelta(seconds=ttl_seconds))
            if cached:
                return cached
            
            # Fetch fresh data
            result = await func(*args, **kwargs)
            
            # Cache result
            cache.set(cache_key, result)
            
            return result
        return wrapper
    return decorator

@mcp.resource("api://weather/current/{city}")
@cached_resource(ttl_seconds=300)  # Cache for 5 minutes
async def current_weather(city: str) -> str:
    """Return current weather with 5-minute cache."""
    weather = await fetch_weather_api(city)
    return json.dumps(weather)
```

### Conditional Requests

Support ETag and Last-Modified headers:

```python
import hashlib
from datetime import datetime

@mcp.resource("file:///docs/api.md")
async def api_documentation(ctx: Context) -> dict:
    """Return API docs with caching headers."""
    
    with open("/docs/api.md", "r") as f:
        content = f.read()
    
    # Generate ETag from content
    etag = hashlib.md5(content.encode()).hexdigest()
    
    # Get file modification time
    import os
    mtime = os.path.getmtime("/docs/api.md")
    last_modified = datetime.fromtimestamp(mtime)
    
    # Check if client has current version
    client_etag = ctx.request_headers.get("If-None-Match")
    if client_etag == etag:
        return {
            "status": 304,  # Not Modified
            "headers": {
                "ETag": etag,
                "Last-Modified": last_modified.isoformat()
            }
        }
    
    return {
        "status": 200,
        "headers": {
            "ETag": etag,
            "Last-Modified": last_modified.isoformat(),
            "Content-Type": "text/markdown"
        },
        "content": content
    }
```

---

## Error Handling

### Resource Not Found

Handle missing resources gracefully:

```python
@mcp.resource("file:///{path}")
async def file_resource(path: str) -> str:
    """Return file contents with error handling."""
    
    import os
    
    if not os.path.exists(path):
        raise ResourceNotFoundError(
            f"File not found: {path}",
            uri=f"file:///{path}"
        )
    
    if not os.path.isfile(path):
        raise ResourceError(
            f"Path is not a file: {path}",
            uri=f"file:///{path}"
        )
    
    try:
        with open(path, "r") as f:
            return f.read()
    except PermissionError:
        raise ResourceAccessError(
            f"Permission denied: {path}",
            uri=f"file:///{path}"
        )
```

### Validation Errors

Validate parameters before processing:

```python
from datetime import datetime

@mcp.resource("weather://forecast/{city}/{date}")
async def weather_forecast(city: str, date: str) -> str:
    """Weather forecast with parameter validation."""
    
    # Validate date format
    try:
        forecast_date = datetime.fromisoformat(date)
    except ValueError:
        raise ValidationError(
            f"Invalid date format: {date}. Expected ISO 8601 (YYYY-MM-DD)"
        )
    
    # Validate date range (within next 7 days)
    today = datetime.now()
    max_date = today + timedelta(days=7)
    
    if forecast_date < today:
        raise ValidationError(
            f"Date must be in the future: {date}"
        )
    
    if forecast_date > max_date:
        raise ValidationError(
            f"Forecast only available for next 7 days. Requested: {date}"
        )
    
    # Validate city
    if not await is_valid_city(city):
        raise ValidationError(
            f"Unknown city: {city}. Use parameter completion to find valid cities."
        )
    
    # Fetch forecast
    forecast = await fetch_weather_data(city, date)
    return json.dumps(forecast)
```

### Timeout Handling

Protect against slow external APIs:

```python
import asyncio

@mcp.resource("api://external/slow-endpoint")
async def slow_external_api() -> str:
    """Fetch from external API with timeout."""
    
    try:
        result = await asyncio.wait_for(
            fetch_external_api(),
            timeout=10.0  # 10 second timeout
        )
        return json.dumps(result)
    except asyncio.TimeoutError:
        raise ResourceTimeoutError(
            "External API request timed out after 10 seconds",
            uri="api://external/slow-endpoint"
        )
```

---

## Testing Strategies

### Unit Testing Resources

Test resource generation with various parameters:

```python
import pytest
from mcp.types import Resource

@pytest.mark.asyncio
async def test_weather_forecast():
    """Test weather forecast resource."""
    
    result = await weather_forecast(
        city="Barcelona",
        date="2024-06-15"
    )
    
    assert isinstance(result, str)
    
    # Parse JSON response
    data = json.loads(result)
    assert "city" in data
    assert data["city"] == "Barcelona"
    assert "date" in data
    assert "forecast" in data

@pytest.mark.asyncio
async def test_weather_forecast_validation():
    """Test parameter validation."""
    
    # Invalid date format
    with pytest.raises(ValidationError, match="Invalid date format"):
        await weather_forecast("Paris", "invalid-date")
    
    # Past date
    with pytest.raises(ValidationError, match="must be in the future"):
        await weather_forecast("London", "2020-01-01")
    
    # Unknown city
    with pytest.raises(ValidationError, match="Unknown city"):
        await weather_forecast("NonexistentCity", "2024-12-31")
```

### Integration Testing

Test resources with real data sources:

```python
@pytest.mark.integration
async def test_database_resource():
    """Test database resource with real connection."""
    
    # Setup: Create test database
    await create_test_database()
    await populate_test_data()
    
    try:
        # Test resource access
        result = await user_schema("test_users")
        
        data = json.loads(result)
        assert "columns" in data
        assert len(data["columns"]) > 0
        
        # Verify schema structure
        first_column = data["columns"][0]
        assert "name" in first_column
        assert "type" in first_column
        assert "nullable" in first_column
    finally:
        # Cleanup: Drop test database
        await drop_test_database()
```

### Caching Tests

Verify caching behavior:

```python
@pytest.mark.asyncio
async def test_resource_caching():
    """Test resource caching with TTL."""
    
    # First call - cache miss
    start = time.time()
    result1 = await current_weather("Barcelona")
    first_duration = time.time() - start
    
    # Second call - cache hit (should be much faster)
    start = time.time()
    result2 = await current_weather("Barcelona")
    second_duration = time.time() - start
    
    assert result1 == result2
    assert second_duration < first_duration / 10  # At least 10x faster
    
    # Wait for cache expiration
    await asyncio.sleep(301)  # TTL is 300 seconds
    
    # Third call - cache miss again
    start = time.time()
    result3 = await current_weather("Barcelona")
    third_duration = time.time() - start
    
    assert third_duration > second_duration  # Slower than cached call
```

---

## Performance Optimization

### Lazy Loading

Defer expensive operations until needed:

```python
@mcp.resource("database://export/full")
async def full_database_export() -> str:
    """Export full database lazily."""
    
    # Don't actually export until client reads the resource
    # Return a lightweight reference
    return json.dumps({
        "export_uri": "database://export/full",
        "status": "ready",
        "size_estimate": "~2GB",
        "message": "Use resources/read to retrieve actual export"
    })

# Actual export happens in read handler
@mcp.read_resource("database://export/full")
async def read_full_export() -> AsyncIterator[str]:
    """Stream database export in chunks."""
    
    async for chunk in stream_database_export():
        yield chunk
```

### Parallel Resource Fetching

Fetch multiple resources concurrently:

```python
import asyncio

@mcp.resource("api://summary/user/{user_id}")
async def user_summary(user_id: str) -> str:
    """Aggregate user data from multiple sources."""
    
    # Fetch multiple resources in parallel
    profile_task = fetch_user_profile(user_id)
    orders_task = fetch_user_orders(user_id)
    reviews_task = fetch_user_reviews(user_id)
    
    profile, orders, reviews = await asyncio.gather(
        profile_task,
        orders_task,
        reviews_task
    )
    
    summary = {
        "profile": profile,
        "order_count": len(orders),
        "review_count": len(reviews),
        "recent_orders": orders[:5],
        "recent_reviews": reviews[:5]
    }
    
    return json.dumps(summary, indent=2)
```

### Connection Pooling

Reuse database connections:

```python
from contextlib import asynccontextmanager
import asyncpg

class DatabasePool:
    def __init__(self):
        self.pool = None
    
    async def initialize(self):
        """Initialize connection pool."""
        self.pool = await asyncpg.create_pool(
            dsn="postgresql://localhost/mydb",
            min_size=5,
            max_size=20
        )
    
    @asynccontextmanager
    async def connection(self):
        """Get connection from pool."""
        async with self.pool.acquire() as conn:
            yield conn

db_pool = DatabasePool()

@mcp.resource("database://query/{query_id}")
async def execute_saved_query(query_id: str) -> str:
    """Execute query using connection pool."""
    
    query = await get_saved_query(query_id)
    
    async with db_pool.connection() as conn:
        results = await conn.fetch(query)
    
    return json.dumps([dict(row) for row in results], indent=2)
```

---

## Documentation and Discovery

### Comprehensive Docstrings

Provide detailed resource documentation:

```python
@mcp.resource("weather://forecast/{city}/{date}")
async def weather_forecast(city: str, date: str) -> str:
    """Get weather forecast for a city and date.
    
    Returns detailed weather forecast including temperature, precipitation,
    wind speed, and general conditions for the specified city and date.
    
    Args:
        city: City name (e.g., "Barcelona", "Paris", "Tokyo")
              Use parameter completion to discover valid cities.
        date: ISO 8601 date (YYYY-MM-DD)
              Must be within next 7 days from today.
    
    Returns:
        JSON object with forecast data:
        {
            "city": "Barcelona",
            "date": "2024-06-15",
            "temperature": {"high": 28, "low": 18, "unit": "celsius"},
            "precipitation": {"chance": 20, "amount": 0},
            "wind": {"speed": 15, "direction": "NE", "unit": "km/h"},
            "conditions": "Partly cloudy"
        }
    
    Examples:
        weather://forecast/barcelona/2024-06-15
        weather://forecast/paris/2024-07-20
        weather://forecast/tokyo/2024-08-10
    
    Raises:
        ValidationError: If city is unknown or date is invalid/out of range
        ResourceTimeoutError: If weather API request times out
    
    See Also:
        - weather://current/{city} - Current weather conditions
        - weather://historical/{city}/{date} - Historical weather data
    """
    pass
```

### Resource Metadata

Include rich metadata for discovery:

```python
from mcp.types import ResourceMetadata

@mcp.resource(
    uri="weather://forecast/{city}/{date}",
    metadata=ResourceMetadata(
        name="weather-forecast",
        description="Weather forecast for any city and date",
        mimeType="application/json",
        category="Weather",
        tags=["forecast", "weather", "temperature"],
        updateFrequency="hourly",
        dataSource="National Weather Service API",
        reliability=0.95,
        cacheTTL=300  # 5 minutes
    )
)
async def weather_forecast(city: str, date: str) -> str:
    """Weather forecast with rich metadata."""
    pass
```

---

## Related Documentation

For more information on MCP resources and implementation:

- **[MCP Server Concepts](https://modelcontextprotocol.io/docs/learn/server-concepts)** - Core understanding of resources, tools, and prompts
- **[Build an MCP Server](https://modelcontextprotocol.io/docs/develop/build-server)** - Complete server implementation guide
- **[Tool Implementation Standards](./03-tool-implementation.md)** - Parallel implementation guide for tools
- **[Prompt Implementation Standards](./03a-prompt-implementation.md)** - Parallel implementation guide for prompts

---

## Summary

Effective MCP resources combine:

1. **Semantic URIs** - Hierarchical, descriptive resource identifiers
2. **MIME type handling** - Proper content type declarations for various formats
3. **Template patterns** - Flexible parameterized URIs with completion support
4. **Data formatting** - Consistent structure for JSON, Markdown, and other formats
5. **Pagination** - Cursor-based pagination for large datasets
6. **Subscriptions** - Real-time change notifications where applicable
7. **Access control** - Authorization checks, redaction, and rate limiting
8. **Caching** - TTL-based and conditional request caching
9. **Error handling** - Graceful validation, timeout, and not-found handling
10. **Performance** - Lazy loading, parallel fetching, connection pooling
11. **Documentation** - Comprehensive docstrings and discovery metadata

By following these standards, MCP resources become discoverable, efficient, and reliable data sources that provide AI applications with structured access to the information they need while maintaining security and performance.
