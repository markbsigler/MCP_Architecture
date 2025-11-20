# Terminology Guide

**Version:** 1.3.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready  
**Navigation**: [Home](../README.md) > Reference > Terminology Guide  
**Related**: [Quick Reference](99-quick-reference.md) | [Index by Topic](98-index-by-topic.md)

## Purpose

This guide establishes consistent terminology across all MCP Architecture documentation to ensure clarity and maintainability.

## Core Terms

### MCP Server

**✅ USE:** "MCP server"

**❌ AVOID:**
- "server" (too generic)
- "MCP service"
- "MCP application"
- "MCP instance"

**Definition:** A server implementation that communicates using the Model Context Protocol (MCP) to provide tools, resources, and prompts to AI agents.

**Usage Examples:**

```markdown
✅ "The MCP server handles authentication..."
✅ "Deploy the MCP server to Kubernetes..."
✅ "This MCP server provides file access tools..."

❌ "The server processes requests..." (ambiguous)
❌ "The MCP service is running..." (inconsistent)
❌ "The application uses FastMCP..." (too vague)
```

### Tool

**✅ USE:** "tool" (lowercase unless starting a sentence)

**❌ AVOID:**
- "function" (implementation detail)
- "method" (implementation detail)
- "endpoint" (REST terminology)
- "API" (too generic)
- "command" (different abstraction)

**Definition:** An MCP primitive that enables AI agents to perform actions or retrieve dynamic data through function calls.

**Usage Examples:**

```markdown
✅ "The create_user tool validates input..."
✅ "Tools should follow verb-noun naming..."
✅ "Implement tools with proper error handling..."

❌ "The create_user function..." (implementation detail)
❌ "Call the API endpoint..." (REST terminology)
❌ "The method handles..." (OOP terminology)
```

**Code Comments:**

```python
# ✅ CORRECT
@mcp.tool()
async def create_user(name: str) -> dict:
    """Tool to create a new user."""
    pass

# ❌ AVOID
@mcp.tool()
async def create_user(name: str) -> dict:
    """Function to create a new user."""  # Wrong term
    pass
```

### Resource

**✅ USE:** "resource" (lowercase unless starting a sentence)

**❌ AVOID:**
- "data source"
- "read endpoint"
- "data provider"
- "content source"

**Definition:** An MCP primitive that exposes data or content that AI agents can read, typically with URI-based addressing.

**Usage Examples:**

```markdown
✅ "Resources provide read-only data access..."
✅ "The file:///path resource returns content..."
✅ "Implement resources with proper caching..."

❌ "The data source provides..." (too generic)
❌ "The read endpoint returns..." (REST terminology)
```

**Code Comments:**

```python
# ✅ CORRECT
@mcp.resource("config://settings")
async def get_settings() -> str:
    """Resource exposing application settings."""
    pass

# ❌ AVOID
@mcp.resource("config://settings")
async def get_settings() -> str:
    """Data source for settings."""  # Wrong term
    pass
```

### Prompt

**✅ USE:** "prompt" (lowercase unless starting a sentence)

**❌ AVOID:**
- "template" (implementation detail)
- "workflow" (higher-level concept)
- "prompt template" (redundant in MCP context)
- "prompt pattern"

**Definition:** An MCP primitive that provides reusable, parameterized message templates for AI agent interactions.

**Usage Examples:**

```markdown
✅ "Prompts enable user-controlled workflows..."
✅ "The code_review prompt generates review instructions..."
✅ "Design prompts with clear parameter descriptions..."

❌ "The template provides..." (implementation detail)
❌ "The workflow guides..." (higher abstraction)
```

**Code Comments:**

```python
# ✅ CORRECT
@mcp.prompt()
async def code_review(language: str) -> list[Message]:
    """Prompt for structured code review workflow."""
    pass

# ❌ AVOID
@mcp.prompt()
async def code_review(language: str) -> list[Message]:
    """Template for code reviews."""  # Wrong term
    pass
```

### Client

**✅ USE:** "MCP client" or "AI agent"

**❌ AVOID:**
- "consumer"
- "caller"
- "user" (when referring to the AI, not the human)
- "application"

**Definition:** The software (typically an AI agent or IDE) that connects to an MCP server and invokes tools, accesses resources, and uses prompts.

**Usage Examples:**

```markdown
✅ "The MCP client initiates the connection..."
✅ "AI agents invoke tools through the MCP protocol..."
✅ "Claude Desktop acts as the MCP client..."

❌ "The consumer calls the API..." (REST terminology)
❌ "The user invokes..." (when referring to AI, not human)
```

### Gateway

**✅ USE:** "MCP gateway" or "gateway layer"

**❌ AVOID:**
- "API gateway" (too REST-specific)
- "proxy"
- "router" (implementation detail)
- "load balancer" (just one function)

**Definition:** The entry point layer that handles authentication, routing, and load balancing for MCP servers.

**Usage Examples:**

```markdown
✅ "The MCP gateway handles JWT validation..."
✅ "Deploy the gateway layer for multi-server routing..."

❌ "The API gateway processes..." (REST terminology)
❌ "The proxy forwards..." (implementation detail)
```

## Architecture Terms

### Layer

**✅ USE:** Specific layer names with capitalization:
- Gateway Layer
- Server Layer  
- Security Layer
- Observability Layer
- Integration Layer

**❌ AVOID:**
- "tier" (different abstraction)
- "component layer"
- lowercase when referring to specific layers

**Usage Examples:**

```markdown
✅ "The Gateway Layer handles routing..."
✅ "Implement security controls in the Security Layer..."
✅ "The five-layer architecture includes..."

❌ "The gateway tier processes..." (wrong term)
❌ "The server layer handles..." (inconsistent capitalization)
```

## Protocol Terms

### MCP Protocol

**✅ USE:** "MCP protocol" or "Model Context Protocol"

**❌ AVOID:**
- "MCP API"
- "MCP interface"
- "MCP specification" (unless referring to the spec document)

**Usage Examples:**

```markdown
✅ "The MCP protocol uses JSON-RPC..."
✅ "Model Context Protocol version 1.0..."

❌ "The MCP API defines..." (mixing terms)
```

### JSON-RPC

**✅ USE:** "JSON-RPC" (with hyphen)

**❌ AVOID:**
- "JSON RPC" (missing hyphen)
- "JSONRPC" (missing hyphen)
- "json-rpc" (wrong capitalization)

### Transport

**✅ USE:**
- "SSE transport" (Server-Sent Events)
- "stdio transport" (standard input/output)
- "HTTP transport"

**❌ AVOID:**
- "SSE connection"
- "stdio channel"
- "HTTP protocol" (protocol vs transport confusion)

## Implementation Terms

### FastMCP

**✅ USE:** "FastMCP" (with specific capitalization)

**❌ AVOID:**
- "fast-mcp"
- "fastmcp"
- "FastMcp"

**Usage Examples:**

```markdown
✅ "FastMCP simplifies MCP server development..."
✅ "This example uses FastMCP decorators..."

❌ "The fast-mcp framework..." (wrong capitalization)
```

### Decorator

**✅ USE:** "decorator" (when referring to Python @syntax)

**❌ AVOID:**
- "annotation" (different concept)
- "attribute"
- "marker"

**Usage Examples:**

```python
# ✅ CORRECT
# Use the @mcp.tool() decorator to register tools
@mcp.tool()
async def create_user(name: str) -> dict:
    pass

# ❌ AVOID  
# Use the @mcp.tool() annotation  # Wrong term
```

## Authentication & Security Terms

### JWT

**✅ USE:** "JWT" (all caps) or "JSON Web Token" (spelled out)

**❌ AVOID:**
- "jwt" (lowercase)
- "Jwt"
- "JWT token" (redundant - "token" is the T)

**Usage Examples:**

```markdown
✅ "Validate the JWT signature..."
✅ "Use JSON Web Tokens for authentication..."
✅ "The JWT contains claims..."

❌ "The JWT token includes..." (redundant)
❌ "Parse the jwt..." (wrong capitalization)
```

### OAuth 2.0

**✅ USE:** "OAuth 2.0" (with space and version)

**❌ AVOID:**
- "OAuth2" (missing space)
- "OAuth" (missing version)
- "oauth 2.0" (wrong capitalization)

### RBAC

**✅ USE:** "RBAC" (all caps) or "role-based access control" (spelled out, lowercase)

**❌ AVOID:**
- "Rbac"
- "rbac"
- "Role-Based Access Control" (unnecessary capitalization when spelled out)

## Observability Terms

### Metric

**✅ USE:** "metric" (singular) or "metrics" (plural)

**❌ AVOID:**
- "measure"
- "measurement" (unless specifically referring to a measurement event)
- "KPI" (higher-level concept)

### Log

**✅ USE:** 
- "log" (noun or verb)
- "log entry"
- "log message"

**❌ AVOID:**
- "log record" (too database-focused)
- "log event" (use "event" separately)

### Trace

**✅ USE:**
- "distributed trace"
- "trace" (when context is clear)
- "tracing" (the practice)

**❌ AVOID:**
- "trace log" (different concepts)
- "trace record"

## Testing Terms

### Test

**✅ USE:**
- "unit test"
- "integration test"
- "end-to-end test"
- "contract test"

**❌ AVOID:**
- "unit testing" (when referring to a specific test)
- "e2e test" (spell out "end-to-end")
- "E2E" (acceptable in code, avoid in docs)

## Status Terms

**✅ USE for document status:**
- "Production Ready" - Finalized, stable
- "Draft" - Work in progress
- "Deprecated" - No longer recommended

**❌ AVOID:**
- "Active" (ambiguous)
- "Complete" (use "Production Ready")
- "WIP" (use "Draft")
- "In Progress" (use "Draft")

## Code Example Standards

### Recommended Pattern Marker

**✅ USE:**
```python
# ✅ RECOMMENDED: This pattern
async def good_example():
    """
    This is the recommended approach because...
    """
    pass
```

**❌ AVOID:**
```python
# ❌ AVOID: This anti-pattern
def bad_example():
    """Don't do this because..."""
    pass
```

### Comment Style

**✅ RECOMMENDED:**
- Use `# ✅ RECOMMENDED:` for good examples
- Use `# ❌ AVOID:` for anti-patterns
- Always explain WHY in the docstring

**❌ AVOID:**
- `# Good:` (not visual enough)
- `# Bad:` (not visual enough)
- `# Do this:` (less clear)
- `# Don't:` (less clear)

## Capitalization Rules

### Document Titles

**✅ USE:** Title Case for document names
- "Architecture Overview"
- "Security Architecture"
- "Tool Implementation Standards"

**❌ AVOID:** 
- "architecture overview" (missing capitals)
- "ARCHITECTURE OVERVIEW" (all caps)

### Section Headers

**✅ USE:** Title Case for major sections (##)

**USE:** Sentence case for subsections (### and below)

```markdown
## Authentication Patterns

### JWT token validation

### OAuth 2.0 integration
```

### Code Elements

**✅ USE:** Backticks for inline code references:
- \`create_user\` (function names)
- \`User\` (class names)
- \`MCP_AUTH_TOKEN\` (environment variables)

## Plural Forms

### Standard Plurals

- tool → tools
- resource → resources
- prompt → prompts
- metric → metrics
- trace → traces

### Keep Singular

- "observability" (not "observabilities")
- "authentication" (not "authentications")
- "authorization" (not "authorizations")

## Abbreviation Standards

### Always Spell Out (First Use)

- MCP (Model Context Protocol)
- JWT (JSON Web Token)
- RBAC (role-based access control)
- SLO (Service Level Objective)
- SLI (Service Level Indicator)

### Never Abbreviate

- "authentication" (not "auth" in documentation)
- "configuration" (not "config" in documentation)
- "database" (not "DB" in documentation)

Exception: Abbreviations are acceptable in:
- Code examples
- File paths
- Environment variable names
- Quick reference guides

## Related Documentation

- [Quick Reference Guide](99-quick-reference.md) - Command cheat sheets
- [Index by Topic](98-index-by-topic.md) - Topic-based navigation
- [Architecture Overview](01-architecture-overview.md) - Core architecture terms
- [Tool Implementation](03-tool-implementation.md) - Tool-specific terminology

---

**Usage Note:** When contributing to this documentation, consult this guide to ensure terminology consistency. If you identify missing terms or inconsistencies, update this guide first, then apply changes across affected documents.
