# Getting Started with MCP Server Development

**Navigation**: [Home](../README.md) > Getting Started  
**Related**: [Architecture Overview](01-architecture-overview.md) | [Tool Implementation](03-tool-implementation.md) | [Development Lifecycle](06-development-lifecycle.md)

**Version:** 1.0.0  
**Last Updated:** January 2026  
**Status:** Production Ready

## Introduction

This guide provides a fast path to building your first enterprise-grade MCP server. You'll have a working server in under 15 minutes, then can explore detailed documentation for production hardening.

**What you'll build:** A simple MCP server with tools that can be tested with Claude Desktop or other MCP clients.

**Prerequisites:**

- Python 3.10+ (recommended) or Node.js 18+
- Basic understanding of async/await patterns
- Familiarity with JSON and REST APIs

## Quick Links

- [Development vs Production Requirements](#development-vs-production-requirements)
- [SDK Selection](#sdk-selection)
- [Environment Setup](#environment-setup)
- [Your First MCP Server](#your-first-mcp-server)
- [Testing with Claude Desktop](#testing-with-claude-desktop)
- [Next Steps](#next-steps)

---

## Development vs Production Requirements

> **Opinionated Guidance:** This section establishes clear boundaries between development/testing and production environments. Following these guidelines ensures your MCP server is secure, scalable, and production-ready.

### Transport Layer

| Aspect | Development/Testing | Production |
|--------|---------------------|------------|
| **Transport Protocol** | STDIO | Streamable HTTP with SSE |
| **Use Case** | Local testing, Claude Desktop, MCP Inspector | Deployed services, multi-client access |
| **Why** | Simple setup, no network config | Scalable, firewall-friendly, supports concurrent clients |

**STDIO is for development only.** It works well for:

- Local testing with Claude Desktop
- Interactive debugging with MCP Inspector  
- Unit and integration testing in CI/CD

**Streamable HTTP is required for production.** It provides:

- Concurrent client connections
- Network-accessible endpoints
- Load balancer compatibility
- Health check endpoints
- Graceful shutdown handling

### Authentication & Authorization

| Aspect | Development/Testing | Production |
|--------|---------------------|------------|
| **Authentication** | Optional / API keys in `.env` | **OAuth 2.1 with PKCE** (REQUIRED) |
| **Token Format** | N/A | JWT with short expiry (15-60 min) |
| **Secret Storage** | `.env` files (gitignored) | Secret management service (Vault, AWS Secrets Manager) |
| **TLS** | Optional (localhost) | **TLS 1.2+ required** |
| **CORS** | Permissive (`*`) | Strict origin allowlist |

**Production Authentication Requirements:**

- OAuth 2.1 with PKCE for client authentication
- JWT tokens validated against JWKS endpoint
- Tokens must include `iss`, `aud`, `exp`, `iat` claims
- Token refresh flow for long-running clients
- See [Security Architecture](02-security-architecture.md) for implementation details

### Deployment & Packaging

| Aspect | Development/Testing | Production |
|--------|---------------------|------------|
| **Packaging** | Local Python/Node.js execution | **Container image (Docker/OCI)** |
| **Orchestration** | Direct process execution | Kubernetes, ECS, Cloud Run |
| **Scaling** | Single instance | Horizontal auto-scaling |
| **Configuration** | `.env` files, CLI args | Environment variables from orchestrator |

**Container Packaging Requirements:**

- Multi-stage Dockerfile for minimal image size
- Non-root user execution
- Health check endpoints (`/health`, `/health/ready`)
- Graceful shutdown handling (SIGTERM)
- See [Deployment Patterns](07-deployment-patterns.md) for reference implementations

### Logging & Observability

| Aspect | Development/Testing | Production |
|--------|---------------------|------------|
| **Log Format** | Human-readable, stderr | **Structured JSON** |
| **Log Level** | DEBUG | INFO (DEBUG on-demand) |
| **Metrics** | Optional | **Prometheus/OpenTelemetry** |
| **Tracing** | Optional | **Distributed tracing required** |
| **Alerting** | None | PagerDuty/Opsgenie integration |

**Production Observability Requirements:**

- Structured JSON logs with correlation IDs
- Prometheus metrics endpoint (`/metrics`)
- OpenTelemetry tracing with span propagation
- No sensitive data in logs (PII masking)
- See [Observability](05-observability.md) for implementation details

### Error Handling

| Aspect | Development/Testing | Production |
|--------|---------------------|------------|
| **Error Detail** | Full stack traces | **Sanitized messages only** |
| **Internal Errors** | Expose for debugging | Hide implementation details |
| **Error Codes** | Descriptive | Standardized MCP error codes |

**Production Error Handling:**

- Return user-friendly error messages
- Log full details internally with correlation ID
- Never expose stack traces, file paths, or internal state
- Use MCP-standard error codes (-32700 to -32600 range)

### Resource Limits

| Aspect | Development/Testing | Production |
|--------|---------------------|------------|
| **Rate Limiting** | Disabled or generous | **Multi-tier enforcement** |
| **Timeouts** | Relaxed (60s+) | Strict (5-30s per operation) |
| **Memory Limits** | Unrestricted | Container resource limits |
| **Connection Pools** | Default | Tuned for expected load |

### External Dependencies

| Aspect | Development/Testing | Production |
|--------|---------------------|------------|
| **Databases** | Local instances, SQLite | Managed services with failover |
| **APIs** | Test/sandbox environments | Production endpoints with retries |
| **Circuit Breakers** | Optional | Required for external calls |
| **Connection Handling** | Simple | Connection pooling, retry with backoff |

### Quick Checklist

Before deploying to production, verify:

- [ ] **Transport**: HTTP with SSE (not STDIO)
- [ ] **Auth**: OAuth 2.1 with PKCE configured
- [ ] **TLS**: HTTPS with valid certificates
- [ ] **Secrets**: All credentials in secret management service
- [ ] **Container**: Docker image with health checks
- [ ] **Logging**: Structured JSON, no sensitive data
- [ ] **Metrics**: Prometheus endpoint exposed
- [ ] **Tracing**: OpenTelemetry configured
- [ ] **Rate Limits**: Multi-tier limits configured
- [ ] **Errors**: Sanitized error messages

---

## SDK Selection

Choose your MCP SDK based on your team's expertise and requirements:

| Language | SDK | Framework | Best For | Docs |
|----------|-----|-----------|----------|------|
| **Python** | `mcp` | FastMCP | Rapid development, type hints, auto-schema | [MCP Python SDK](https://modelcontextprotocol.io/docs/develop/sdks) |
| **TypeScript** | `@modelcontextprotocol/sdk` | Native | Node.js apps, full type safety | [MCP TypeScript SDK](https://modelcontextprotocol.io/docs/develop/sdks) |
| **Java** | `io.modelcontextprotocol:sdk` | Native | Enterprise Java, Spring integration | [MCP Java SDK](https://modelcontextprotocol.io/docs/develop/sdks) |
| **Kotlin** | `io.modelcontextprotocol:sdk` | Native | Android, JVM applications | [MCP Kotlin SDK](https://modelcontextprotocol.io/docs/develop/sdks) |
| **C#** | `ModelContextProtocol.Sdk` | Native | .NET applications | [MCP C# SDK](https://modelcontextprotocol.io/docs/develop/sdks) |
| **Rust** | `mcp-server` | rmcp | Performance-critical applications | [MCP Rust SDK](https://modelcontextprotocol.io/docs/develop/sdks) |

**Recommendation:** Start with **Python + FastMCP** for the fastest development experience. FastMCP automatically generates tool schemas from Python type hints and docstrings.

### SDK Version Requirements

| SDK | Minimum Version | Notes |
|-----|-----------------|-------|
| Python `mcp` | 1.2.0+ | Required for latest MCP spec features |
| TypeScript | 1.0.0+ | Full MCP 2025-11-25 support |

## Environment Setup

### Python (Recommended)

We recommend using `uv` for fast, reliable Python package management:

```bash
# Install uv package manager (macOS/Linux)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Restart your terminal after installation
```

Create your project:

```bash
# Create project directory
uv init my-mcp-server
cd my-mcp-server

# Create and activate virtual environment
uv venv
source .venv/bin/activate  # macOS/Linux
# .venv\Scripts\activate   # Windows

# Install MCP SDK with CLI tools
uv add "mcp[cli]" httpx

# Verify installation
python -c "import mcp; print(f'MCP SDK version: {mcp.__version__}')"
```

### TypeScript

```bash
# Create project
mkdir my-mcp-server && cd my-mcp-server
npm init -y

# Install dependencies
npm install @modelcontextprotocol/sdk zod

# Initialize TypeScript
npx tsc --init
```

## Your First MCP Server

### Python with FastMCP

Create `server.py`:

```python
"""
Simple MCP Server Example.

This server demonstrates the basic structure of an MCP server
with tool definitions using FastMCP.
"""

from typing import Any
import httpx
from mcp.server.fastmcp import FastMCP

# Initialize the MCP server
mcp = FastMCP("my-first-server")

# Constants for external API (example: weather API)
API_BASE = "https://api.example.com"
USER_AGENT = "my-mcp-server/1.0"


async def make_api_request(url: str) -> dict[str, Any] | None:
    """Make a request to external API with proper error handling.
    
    This helper function demonstrates best practices:
    - Explicit timeout handling
    - User-Agent header
    - Graceful error handling
    """
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json"
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers, timeout=30.0)
            response.raise_for_status()
            return response.json()
        except Exception:
            return None


@mcp.tool()
async def hello_world(name: str) -> str:
    """Greet a user by name.
    
    Args:
        name: The name of the person to greet
    """
    return f"Hello, {name}! Welcome to MCP."


@mcp.tool()
async def add_numbers(a: float, b: float) -> str:
    """Add two numbers together.
    
    Args:
        a: First number
        b: Second number
    """
    result = a + b
    return f"The sum of {a} and {b} is {result}"


@mcp.tool()
async def get_current_time() -> str:
    """Get the current server time in ISO format."""
    from datetime import datetime, timezone
    
    now = datetime.now(timezone.utc)
    return f"Current UTC time: {now.isoformat()}"


def main():
    """Run the MCP server with STDIO transport."""
    # STDIO transport for local development
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
```

### Key Concepts Explained

1. **FastMCP Initialization**: `FastMCP("server-name")` creates your server instance

2. **Tool Decorator**: `@mcp.tool()` registers a function as an MCP tool
   - Type hints → JSON Schema for input validation
   - Docstrings → Tool descriptions for LLM understanding
   - Return type → Response format

3. **Async Functions**: Tools should be async for non-blocking I/O

4. **Error Handling**: Return user-friendly error messages, not exceptions

### Run Your Server

```bash
# Ensure virtual environment is activated
source .venv/bin/activate  # macOS/Linux
# .venv\Scripts\activate   # Windows

# Test the server runs without errors
python server.py

# The server will wait for STDIO input - press Ctrl+C to exit
```

## Testing with Claude Desktop

### Configure Claude Desktop

1. Open Claude Desktop configuration file:

**macOS:**

```bash
code ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

**Windows:**

```bash
code %APPDATA%\Claude\claude_desktop_config.json
```

1. Add your server configuration:

```json
{
  "mcpServers": {
    "my-first-server": {
      "command": "/absolute/path/to/your/project/.venv/bin/python",
      "args": ["/absolute/path/to/your/server.py"],
      "env": {
        "PYTHONPATH": "/absolute/path/to/your/project"
      }
    }
  }
}
```

**Important:**

- Use the **virtual environment's Python**, not the system Python
- Use absolute paths, not relative paths
- On Windows, use `.venv/Scripts/python.exe`

1. **Restart Claude Desktop completely:**
   - macOS: Cmd+Q (don't just close the window)
   - Windows: Right-click system tray icon → Quit

### Verify Your Server

1. Open Claude Desktop
2. Look for the connector icon (plug icon or similar)
3. Your server should appear in the list
4. Try asking: "Say hello to Alice" or "What time is it?"

### Troubleshooting

If your server doesn't appear:

1. **Check logs:**

   ```bash
   # macOS
   tail -f ~/Library/Logs/Claude/mcp*.log
   ```

2. **Verify the server runs standalone:**

   ```bash
   python /absolute/path/to/server.py
   # Should start without errors
   ```

3. **Check JSON syntax:**

   ```bash
   python -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

See [Troubleshooting Guide](11-troubleshooting.md) for more debugging tips.

## STDIO Logging Constraint (Development Only)

> **Reminder:** STDIO transport is for **development and testing only**. Production deployments must use Streamable HTTP with OAuth 2.1. See [Development vs Production Requirements](#development-vs-production-requirements).

**Critical:** When using STDIO transport for local development, never write to stdout except for JSON-RPC messages:

```python
# ❌ BAD - Corrupts JSON-RPC protocol
print("Processing request...")

# ✅ GOOD - Use logging to stderr
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stderr  # Critical: stderr, not stdout
)
logger = logging.getLogger(__name__)

logger.info("Processing request...")
```

This constraint only applies to STDIO transport. HTTP-based servers can log to stdout normally.

## Next Steps

Now that you have a working MCP server, explore these topics:

### Production Hardening

| Topic | Document | Priority |
|-------|----------|----------|
| **Project Structure** | [Development Lifecycle](06-development-lifecycle.md) | High |
| **Tool Patterns** | [Tool Implementation Standards](03-tool-implementation.md) | High |
| **Security** | [Security Architecture](02-security-architecture.md) | High |
| **Testing** | [Testing Strategy](04-testing-strategy.md) | High |

### Advanced Features

| Topic | Document | Priority |
|-------|----------|----------|
| **Resources** | [Resource Implementation](03b-resource-implementation.md) | Medium |
| **Prompts** | [Prompt Implementation](03a-prompt-implementation.md) | Medium |
| **Sampling** | [Sampling Patterns](03c-sampling-patterns.md) | Medium |
| **Observability** | [Observability](05-observability.md) | Medium |

### Deployment

| Topic | Document | Priority |
|-------|----------|----------|
| **Containers** | [Deployment Patterns](07-deployment-patterns.md) | High |
| **Operations** | [Operational Runbooks](08-operational-runbooks.md) | Medium |
| **Performance** | [Performance & Scalability](06a-performance-scalability.md) | Medium |

## Quick Reference

### MCP Server Checklist

Before deploying to production:

- [ ] All tools have clear docstrings and type hints
- [ ] Error handling returns user-friendly messages
- [ ] External API calls have timeouts and retries
- [ ] Logging uses stderr (for STDIO) or structured logging
- [ ] Tests cover happy path and error scenarios
- [ ] Security review completed (see [Security Architecture](02-security-architecture.md))
- [ ] HTTP transport configured for production (not STDIO)

### Common Commands

```bash
# Activate virtual environment first
source .venv/bin/activate  # macOS/Linux
# .venv\Scripts\activate   # Windows

# Run server locally
python server.py

# Run with MCP Inspector for debugging
npx @modelcontextprotocol/inspector .venv/bin/python server.py

# Run tests
pytest tests/ -v

# Check code quality
ruff check src/
mypy src/
```

## External Resources

- [Official MCP Documentation](https://modelcontextprotocol.io/docs/)
- [MCP Build Server Guide](https://modelcontextprotocol.io/docs/develop/build-server)
- [MCP SDKs](https://modelcontextprotocol.io/docs/develop/sdks)
- [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector)
- [MCP Specification](https://modelcontextprotocol.io/specification/2025-11-25/)

---

**Next:** [Architecture Overview](01-architecture-overview.md) | [Tool Implementation Standards](03-tool-implementation.md)
