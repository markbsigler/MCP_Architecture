# Quick Reference Guide

**Version:** 1.4.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Overview

This quick reference provides at-a-glance guidance for common MCP implementation decisions and patterns. Use this as a starting point, then refer to detailed sections for comprehensive information.

---

## EARS Requirements Patterns Quick Reference

### When to Use Each EARS Pattern

```text
Requirements Type → EARS Pattern → Keyword

Constant behavior   → Ubiquitous    → (none)
State-dependent     → State-driven  → While
Event response      → Event-driven  → When
Optional feature    → Optional      → Where
Error handling      → Unwanted      → If...Then
Complex behavior    → Complex       → Multiple keywords
```

### EARS Syntax Templates

```text
Ubiquitous:  The <system> shall <response>
State:       While <condition>, the <system> shall <response>
Event:       When <trigger>, the <system> shall <response>
Optional:    Where <feature>, the <system> shall <response>
Unwanted:    If <trigger>, then the <system> shall <response>
Complex:     While <condition>, When <trigger>, the <system> shall <response>
```

### Quick Examples

```text
✅ Ubiquitous: The file_tool shall support files up to 100MB.
✅ State:      While user is unauthenticated, the server shall reject requests.
✅ Event:      When upload completes, the tool shall return file_id.
✅ Optional:   Where caching is enabled, the server shall cache for 5 minutes.
✅ Unwanted:   If invalid token is provided, then the server shall return 401.
```

---

## MCP Primitives Decision Tree

### When to Use Tools vs Prompts vs Resources

```text
Start: What are you implementing?

├─ Does the AI model need to TAKE ACTION?
│  ├─ YES → Use TOOL
│  │   Examples: create_file, send_email, update_database
│  │   See: docs/03-tool-implementation.md
│  │
│  └─ NO → Continue...
│
├─ Does the user need GUIDED WORKFLOW with parameters?
│  ├─ YES → Use PROMPT
│  │   Examples: code_review_workflow, bug_report_template
│  │   See: docs/03a-prompt-implementation.md
│  │
│  └─ NO → Continue...
│
├─ Do you need to PROVIDE DATA/CONTEXT?
│  ├─ YES → Use RESOURCE
│  │   Examples: config://settings, logs://recent, docs://readme
│  │   See: docs/03b-resource-implementation.md
│  │
│  └─ NO → Continue...
│
└─ Does your tool/resource need LLM PROCESSING?
   └─ YES → Use SAMPLING (within tool/resource)
       Examples: summarize text, extract entities, classify content
       See: docs/03c-sampling-patterns.md
```

---

## Common Patterns Cheat Sheet

### Tool Naming Standards

```python
# ✅ Correct verb-noun pattern
create_issue()
list_repositories()
update_configuration()
delete_resource()
get_status()

# ❌ Incorrect
issue()              # Missing verb
createNewIssue()     # camelCase
repos_list()         # Reversed order
```

### Prompt Naming Standards

```python
# ✅ Descriptive workflow names
analyze_code_quality
plan_sprint
review_security
debug_application

# ❌ Incorrect
analyze()            # Too generic
code-analysis()      # Hyphen instead of underscore
```

### Resource URI Patterns

```python
# ✅ Well-structured URIs
"config://app/settings"
"logs://system/{date}/errors"
"docs://api/{version}/{endpoint}"

# ❌ Incorrect
"settings"           # No scheme
"config:/settings"   # Single slash
"config://user data" # Spaces in URI
```

---

## Response Format Standards

### Success Response

```python
{
    "success": true,
    "data": {
        # Actual response data
    },
    "message": "Operation completed successfully",
    "metadata": {
        "timestamp": "2025-11-18T12:00:00Z"
    }
}
```

### Error Response

```python
{
    "success": false,
    "error": {
        "code": "RESOURCE_NOT_FOUND",
        "message": "The requested resource 'config://app/missing' does not exist",
        "details": {
            "resource_uri": "config://app/missing",
            "suggestion": "Check available resources with list_resources()"
        }
    }
}
```

---

## Error Code Categories

```text
┌─────────────────┬──────────────────────┬─────────────────────┐
│ Category        │ Code Prefix          │ Example             │
├─────────────────┼──────────────────────┼─────────────────────┤
│ Input           │ INVALID_*, MISSING_* │ INVALID_PARAMETER   │
│ Resources       │ *_NOT_FOUND          │ RESOURCE_NOT_FOUND  │
│ External        │ *_FAILED             │ API_CALL_FAILED     │
│ Permissions     │ *_FORBIDDEN          │ ACCESS_FORBIDDEN    │
│ Rate Limiting   │ RATE_LIMIT_*         │ RATE_LIMIT_EXCEEDED │
│ System          │ INTERNAL_*           │ INTERNAL_ERROR      │
└─────────────────┴──────────────────────┴─────────────────────┘
```

---

## Security Checklist

### Before Deploying Any MCP Server

- [ ] Authentication configured (JWT/OAuth 2.0)
- [ ] RBAC or capability-based access control implemented
- [ ] Rate limiting configured (per-user and global)
- [ ] Input validation on all parameters (Pydantic models)
- [ ] SQL injection prevention (parameterized queries)
- [ ] Path traversal prevention (path validation)
- [ ] Command injection prevention (no shell=True)
- [ ] PII detection and masking configured
- [ ] Audit logging enabled for all operations
- [ ] TLS/HTTPS enforced
- [ ] Security headers configured (HSTS, CSP, etc.)
- [ ] Secrets management setup (no hardcoded credentials)
- [ ] Error messages don't leak sensitive info

---

## Testing Coverage Targets

```text
┌──────────────────┬─────────────┬──────────────────────┐
│ Test Type        │ Min Coverage│ Focus                │
├──────────────────┼─────────────┼──────────────────────┤
│ Unit             │ 80%         │ Tool logic           │
│ Integration      │ 70%         │ External APIs        │
│ Security         │ 100%        │ Auth & validation    │
│ Contract         │ 100%        │ MCP protocol         │
│ E2E              │ Critical    │ User workflows       │
└──────────────────┴─────────────┴──────────────────────┘
```

---

## Sampling Temperature Guide

```python
# Deterministic (structured data extraction)
temperature = 0.0

# Focused (technical summaries, documentation)
temperature = 0.2 - 0.4

# Balanced (general content generation)
temperature = 0.5 - 0.7

# Creative (brainstorming, storytelling)
temperature = 0.8 - 1.0
```

---

## Common Anti-Patterns to Avoid

### ❌ Don't: Implement Tools Without Versioning

```python
# Bad: No version, breaking changes affect all users
@mcp.tool()
async def create_issue(title: str):
    pass
```

### ✅ Do: Version Breaking Changes

```python
# Good: v1 deprecated, v2 with new required parameter
@mcp.tool()
@deprecated(version="2.0.0", alternative="create_issue_v2")
async def create_issue(title: str):
    pass

@mcp.tool()
async def create_issue_v2(title: str, project: str):
    pass
```

### ❌ Don't: Return Unstructured Errors

```python
# Bad: No structure, no actionable information
return {"error": "something went wrong"}
```

### ✅ Do: Return Structured Errors

```python
# Good: Structured with code, message, and action
return {
    "success": false,
    "error": {
        "code": "INVALID_PARAMETER",
        "message": "Parameter 'date' must be in YYYY-MM-DD format",
        "details": {"received": "2025/11/18", "expected_format": "YYYY-MM-DD"}
    }
}
```

### ❌ Don't: Expose Raw Database Errors

```python
# Bad: Leaks implementation details
except Exception as e:
    return {"error": str(e)}  # "pg_dump: connection failed..."
```

### ✅ Do: Wrap and Sanitize Errors

```python
# Good: Generic user-facing error, log details internally
except DatabaseError as e:
    logger.error(f"Database error: {e}", exc_info=True)
    return {
        "success": false,
        "error": {
            "code": "DATABASE_ERROR",
            "message": "Unable to complete database operation. Please try again."
        }
    }
```

---

## Performance Quick Wins

### Caching Strategy

```python
# TTL-based caching for relatively static data
@mcp.resource("config://app/settings")
@cache(ttl=300)  # 5 minutes
async def get_settings():
    return await expensive_operation()
```

### Connection Pooling

```python
# Reuse database connections
pool = await asyncpg.create_pool(
    dsn=DATABASE_URL,
    min_size=5,
    max_size=20
)
```

### Pagination

```python
# Always paginate large datasets
@mcp.tool()
async def list_items(
    limit: int = 50,
    cursor: str | None = None
) -> dict:
    return {
        "items": [...],
        "cursor": "next_page_token",
        "has_more": true
    }
```

---

## Observability Essentials

### Structured Logging

```python
import structlog

logger = structlog.get_logger()

logger.info(
    "tool_executed",
    tool_name="create_issue",
    user_id="user-123",
    duration_ms=156,
    success=True
)
```

### Key Metrics to Track

```text
1. Request rate (requests/sec)
2. Error rate (errors/total requests)
3. Latency (p50, p95, p99)
4. Tool execution time
5. Authentication failures
6. Rate limit hits
```

### Distributed Tracing

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("tool_execution"):
    result = await execute_tool()
```

---

## Integration Patterns Summary

### REST API Integration

```python
# With retry and circuit breaker
from tenacity import retry, stop_after_attempt
from circuitbreaker import circuit

@circuit(failure_threshold=5, recovery_timeout=60)
@retry(stop=stop_after_attempt(3))
async def call_external_api():
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        response.raise_for_status()
        return response.json()
```

### Database Integration

```python
# Using connection pool
async def get_data(user_id: str):
    async with pool.acquire() as conn:
        result = await conn.fetchrow(
            "SELECT * FROM users WHERE id = $1",
            user_id
        )
        return dict(result)
```

---

## Deployment Checklist

### Pre-Production

- [ ] All tests passing (unit, integration, security)
- [ ] Load testing completed
- [ ] Security scan passed
- [ ] Documentation updated
- [ ] Runbooks prepared
- [ ] Monitoring configured
- [ ] Alerts defined
- [ ] Rollback plan documented

### Production Deployment

- [ ] Blue-green or canary deployment
- [ ] Health checks responding
- [ ] Metrics being collected
- [ ] Logs aggregated
- [ ] Error tracking active
- [ ] On-call team notified

---

## Useful Commands

### Build Documentation

```bash
make clean  # Remove old build
make md     # Generate consolidated doc
make toc    # Regenerate TOC only
```

### Local Testing

```bash
# Run tests
pytest tests/

# Run with coverage
pytest --cov=src tests/

# Security scan
bandit -r src/
```

### Docker Operations

```bash
# Build
docker build -t mcp-server:latest .

# Run locally
docker run -p 8000:8000 mcp-server:latest

# Check logs
docker logs -f container_id
```

---

## Reference Links

- [Architecture Overview](01-architecture-overview.md)
- [Security Architecture](02-security-architecture.md)
- [Requirements Engineering](02b-requirements-engineering.md) ⭐ NEW
- [Tool Standards](03-tool-implementation.md)
- [Prompt Standards](03a-prompt-implementation.md)
- [Resource Standards](03b-resource-implementation.md)
- [Sampling Patterns](03c-sampling-patterns.md)
- [Testing Strategy](04-testing-strategy.md)
- [Observability](05-observability.md)
- [Deployment Patterns](07-deployment-patterns.md)
- [Operational Runbooks](08-operational-runbooks.md)
- [Contributing Guide](../CONTRIBUTING.md)

---

**Need more detail?** Each pattern and standard has a comprehensive guide in the full documentation. Use this quick reference as a starting point, then dive into specific sections for in-depth information.
