# MCP Protocol Version Compatibility

**Navigation**: [Home](../README.md) > Metrics & Reference > MCP Protocol Compatibility  
**Related**: [← Previous: Performance Benchmarks](14-performance-benchmarks.md) | [Migration Guides](10-migration-guides.md#mcp-protocol-version-upgrades) | [Index by Topic](../ref/98-index-by-topic.md)

**Version:** 2.0.0  
**Last Updated:** July 19, 2025  
**Status:** Production Ready

## Introduction

The Model Context Protocol (MCP) evolves through **date-based** versioned releases to add features, improve security, and enhance interoperability. Unlike semver, MCP versions are calendar dates (e.g., `2025-11-25`). This document defines supported protocol versions, feature compatibility, upgrade paths, and version negotiation behavior for the actual MCP specification published at <https://modelcontextprotocol.io>.

## Supported Protocol Versions

### Current Support Matrix

| Protocol Version | Status | Specification URL | Transport |
|-----------------|--------|-------------------|-----------|
| **2025-11-25** | Current | [spec](https://modelcontextprotocol.io/specification/2025-11-25) | stdio, Streamable HTTP |
| **2025-06-18** | Previous | [spec](https://modelcontextprotocol.io/specification/2025-06-18) | stdio, Streamable HTTP |
| **2025-03-26** | Legacy | [spec](https://modelcontextprotocol.io/specification/2025-03-26) | stdio, Streamable HTTP |
| **2024-11-05** | Initial | [spec](https://modelcontextprotocol.io/specification/2024-11-05) | stdio, HTTP+SSE (deprecated) |

### Governance

Starting with 2025-11-25, the MCP specification is governed by an open governance model under the Linux Foundation, with formalized working groups and an SDK tiering system (Tier 1 = official, Tier 2 = community-maintained).

## Protocol Version Feature Matrix

### Core Capabilities by Version

| Feature | 2024-11-05 | 2025-03-26 | 2025-06-18 | 2025-11-25 |
|---------|-----------|-----------|-----------|-----------|
| **Transport** | | | | |
| stdio (stdin/stdout) | ✅ | ✅ | ✅ | ✅ |
| HTTP+SSE (legacy) | ✅ | ❌¹ | ❌¹ | ❌¹ |
| Streamable HTTP | ❌ | ✅ | ✅ | ✅ |
| Polling SSE streams | ❌ | ❌ | ❌ | ✅ |
| `MCP-Protocol-Version` header | ❌ | ✅ | ✅ | ✅ |
| `Mcp-Session-Id` header | ❌ | ✅ | ✅ | ✅ |
| **Server Features** | | | | |
| Tools (`tools/list`, `tools/call`) | ✅ | ✅ | ✅ | ✅ |
| Resources (`resources/list`, `resources/read`) | ✅ | ✅ | ✅ | ✅ |
| Prompts (`prompts/list`, `prompts/get`) | ✅ | ✅ | ✅ | ✅ |
| Logging | ✅ | ✅ | ✅ | ✅ |
| Completions | ❌ | ✅ | ✅ | ✅ |
| Tool annotations | ❌ | ❌ | ✅ | ✅ |
| Tool `title` / `icons` | ❌ | ❌ | ❌ | ✅ |
| Tool `outputSchema` / `structuredContent` | ❌ | ❌ | ❌ | ✅ |
| Tool naming guidance (1–128 chars) | ❌ | ❌ | ❌ | ✅ |
| Resource `title` / `icons` / `size` | ❌ | ❌ | ❌ | ✅ |
| Prompt `title` / `icons` | ❌ | ❌ | ❌ | ✅ |
| Audio content type | ❌ | ❌ | ❌ | ✅ |
| **Client Features** | | | | |
| Sampling (`sampling/createMessage`) | ✅ | ✅ | ✅ | ✅ |
| Roots | ✅ | ✅ | ✅ | ✅ |
| Elicitation (form mode) | ❌ | ❌ | ✅ | ✅ |
| Elicitation (url mode) | ❌ | ❌ | ❌ | ✅ |
| Tools in sampling (`sampling.tools`) | ❌ | ❌ | ❌ | ✅ |
| **Tasks** | | | | |
| Tasks capability | ❌ | ❌ | ❌ | ✅ |
| `tasks/get`, `tasks/result`, `tasks/list` | ❌ | ❌ | ❌ | ✅ |
| `tasks/cancel` | ❌ | ❌ | ❌ | ✅ |
| Tool-level `execution.taskSupport` | ❌ | ❌ | ❌ | ✅ |
| **Utilities** | | | | |
| Progress notifications | ✅ | ✅ | ✅ | ✅ |
| Cancellation | ✅ | ✅ | ✅ | ✅ |
| Pagination (cursor-based) | ✅ | ✅ | ✅ | ✅ |

¹ *HTTP+SSE from 2024-11-05 was replaced by Streamable HTTP in 2025-03-26. Servers may still offer the old endpoint for backwards compatibility.*

### Authorization & Security by Version

| Feature | 2024-11-05 | 2025-03-26 | 2025-06-18 | 2025-11-25 |
|---------|-----------|-----------|-----------|-----------|
| OAuth 2.1 + PKCE | ❌ | ✅ | ✅ | ✅ |
| Dynamic Client Registration (RFC 7591) | ❌ | ✅ | ✅ | ✅ |
| OIDC Discovery | ❌ | ❌ | ❌ | ✅ |
| Protected Resource Metadata (RFC 9728) | ❌ | ❌ | ✅ | ✅ |
| Client ID Metadata Documents | ❌ | ❌ | ❌ | ✅ |
| Incremental scope consent (`WWW-Authenticate`) | ❌ | ❌ | ❌ | ✅ |
| Resource Indicators (RFC 8707) | ❌ | ❌ | ✅ | ✅ |
| Origin header validation → 403 | ❌ | ❌ | ✅ | ✅ |
| Input validation as tool error | ❌ | ❌ | ❌ | ✅ |
| JSON Schema 2020-12 default dialect | ❌ | ❌ | ❌ | ✅ |

### Implementation / Metadata by Version

| Feature | 2024-11-05 | 2025-03-26 | 2025-06-18 | 2025-11-25 |
|---------|-----------|-----------|-----------|-----------|
| `clientInfo` / `serverInfo` (name, version) | ✅ | ✅ | ✅ | ✅ |
| `title`, `description` on Implementation | ❌ | ❌ | ❌ | ✅ |
| `icons` on Implementation | ❌ | ❌ | ❌ | ✅ |
| `websiteUrl` on Implementation | ❌ | ❌ | ❌ | ✅ |
| stderr for all logging types | ❌ | ❌ | ❌ | ✅ |

## Version-Specific Details

### 2025-11-25 (Current)

**Changelog highlights (vs. 2025-06-18):**

**Major changes:**

1. **OIDC Discovery** — Clients MUST support both RFC 8414 and OpenID Connect Discovery to locate authorization servers
2. **Icon metadata** — Tools, resources, and prompts now include `icons` array (`[{src, mimeType, sizes}]`)
3. **Incremental scope consent** — `WWW-Authenticate` header carries scope hints for step-up authorization (403 Forbidden)
4. **Tool naming guidance** — Names 1–128 chars, case-sensitive, allowed chars: `A-Za-z0-9_-.`
5. **Elicitation enhancements** — Standards-based enum schemas (`oneOf`/`anyOf`), default values, titled/untitled enums
6. **URL mode elicitation** — Out-of-band interaction via URL navigation for auth flows and sensitive data
7. **Tools in sampling** — Servers can include `tools` and `toolChoice` in `sampling/createMessage` requests
8. **Client ID Metadata Documents** — HTTPS URLs as client identifiers (`draft-ietf-oauth-client-id-metadata-document-00`)
9. **Tasks support** — Durable state machines for long-running requests with polling, cancellation, and deferred result retrieval

**Minor changes:**

- stderr now usable for ALL logging types (not just errors)
- `description` field added to Implementation (clientInfo/serverInfo)
- Origin header validation returns 403 Forbidden specifically
- Input validation failures should be reported as tool execution errors (not protocol errors)
- Polling SSE streams — server MAY close connection at will; client reconnects with `Last-Event-ID`
- GET stream supports polling/resumption via `Last-Event-ID`
- RFC 9728 alignment — `WWW-Authenticate` optional with well-known URI fallback
- Default values supported in elicitation schemas
- JSON Schema 2020-12 is the default dialect when no `$schema` field is present

**Schema changes:**

- Decoupled request payloads from RPC method definitions

### 2025-06-18

**Key additions over 2025-03-26:**

- Elicitation (form mode) for human-in-the-loop input
- Tool annotations with audience/priority metadata
- OAuth 2.0 Protected Resource Metadata (RFC 9728) for authorization server discovery
- Resource Indicators (RFC 8707) for audience binding
- Origin header validation requirement
- `resource_link` content type in tool results

### 2025-03-26

**Key additions over 2024-11-05:**

- Streamable HTTP transport (replaces HTTP+SSE)
- OAuth 2.1 + PKCE authorization framework
- Dynamic Client Registration (RFC 7591)
- `Mcp-Session-Id` session management
- Completions capability
- Sampling capability

### 2024-11-05 (Initial Release)

**Foundation:**

- stdio transport
- HTTP+SSE transport (deprecated in 2025-03-26)
- JSON-RPC 2.0 message framing
- Core primitives: tools, resources, prompts
- Basic sampling
- Progress notifications and cancellation

## Version Negotiation

### How MCP Version Negotiation Works

MCP uses an `initialize` handshake where the client proposes a `protocolVersion` and the server responds with the version it will use:

```json
// Client → Server: initialize request
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "sampling": { "tools": {} },
      "elicitation": { "form": {}, "url": {} },
      "roots": { "listChanged": true },
      "tasks": {
        "list": {},
        "cancel": {},
        "requests": {
          "sampling": { "createMessage": {} },
          "elicitation": { "create": {} }
        }
      }
    },
    "clientInfo": {
      "name": "enterprise-client",
      "version": "3.0.0",
      "title": "Enterprise MCP Client",
      "description": "Production MCP client",
      "icons": [{ "src": "https://example.com/icon.png", "mimeType": "image/png" }],
      "websiteUrl": "https://example.com"
    }
  }
}
```

```json
// Server → Client: initialize result
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "tools": { "listChanged": true },
      "resources": { "subscribe": true, "listChanged": true },
      "prompts": { "listChanged": true },
      "logging": {},
      "completions": {},
      "tasks": {
        "list": {},
        "cancel": {},
        "requests": {
          "tools": { "call": {} }
        }
      }
    },
    "serverInfo": {
      "name": "enterprise-server",
      "version": "2.0.0",
      "title": "Enterprise MCP Server",
      "icons": [{ "src": "https://example.com/server-icon.png", "mimeType": "image/png" }]
    }
  }
}
```

### MCP-Protocol-Version HTTP Header

For Streamable HTTP transport, the client **MUST** include the `MCP-Protocol-Version` header on **all** subsequent HTTP requests after initialization:

```http
POST /mcp HTTP/1.1
Host: mcp.example.com
Content-Type: application/json
MCP-Protocol-Version: 2025-11-25
Mcp-Session-Id: abc123-session-id
Authorization: Bearer eyJhbGciOi...

{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}
```

- If the header is **missing**, the server SHOULD assume protocol version `2025-03-26`
- If the header value is **invalid**, the server MUST return `400 Bad Request`

### Backwards Compatibility

Servers can host Streamable HTTP alongside the legacy HTTP+SSE endpoint:

| Client Version | Server Behavior |
|---------------|----------------|
| 2025-03-26+ | Client sends POST to single MCP endpoint; server responds with Streamable HTTP |
| 2024-11-05 | Client sends to legacy SSE endpoint; server responds with old HTTP+SSE protocol |

Clients should try POST first; if the server returns a non-success response, fall back to GET for old SSE transport.

## Session Management

### Mcp-Session-Id

- The server generates a session ID during initialization and returns it in the `Mcp-Session-Id` response header
- The session ID MUST be printable ASCII (0x21–0x7E), cryptographically secure
- The client MUST include `Mcp-Session-Id` on all subsequent requests
- The client sends `HTTP DELETE` to the MCP endpoint with the session ID to terminate the session

### Resumability

- Event IDs MUST be globally unique within a session and SHOULD encode stream identity
- Clients reconnect with `Last-Event-ID` header
- Resumption always uses GET with `Last-Event-ID`, regardless of what method started the original stream
- Servers SHOULD send the `retry` field before closing a SSE stream

## Capability Negotiation Reference

### Client Capabilities (2025-11-25)

```json
{
  "capabilities": {
    "roots": { "listChanged": true },
    "sampling": { "tools": {} },
    "elicitation": { "form": {}, "url": {} },
    "tasks": {
      "list": {},
      "cancel": {},
      "requests": {
        "sampling": { "createMessage": {} },
        "elicitation": { "create": {} }
      }
    }
  }
}
```

| Capability | Sub-capability | Description |
|-----------|---------------|-------------|
| `roots` | `listChanged` | Client notifies server when root list changes |
| `sampling` | (empty) | Basic sampling support |
| `sampling` | `tools` | Sampling with tool-use support |
| `elicitation` | `form` | In-band structured data collection |
| `elicitation` | `url` | Out-of-band URL navigation for sensitive flows |
| `tasks` | `list` | Client supports `tasks/list` |
| `tasks` | `cancel` | Client supports `tasks/cancel` |
| `tasks.requests` | `sampling.createMessage` | Task-augmented sampling |
| `tasks.requests` | `elicitation.create` | Task-augmented elicitation |

### Server Capabilities (2025-11-25)

```json
{
  "capabilities": {
    "tools": { "listChanged": true },
    "resources": { "subscribe": true, "listChanged": true },
    "prompts": { "listChanged": true },
    "logging": {},
    "completions": {},
    "tasks": {
      "list": {},
      "cancel": {},
      "requests": {
        "tools": { "call": {} }
      }
    }
  }
}
```

| Capability | Sub-capability | Description |
|-----------|---------------|-------------|
| `tools` | `listChanged` | Server notifies when tool list changes |
| `resources` | `subscribe` | Client can subscribe to resource changes |
| `resources` | `listChanged` | Server notifies when resource list changes |
| `prompts` | `listChanged` | Server notifies when prompt list changes |
| `logging` | — | Server supports log message sending |
| `completions` | — | Server supports auto-completion |
| `tasks` | `list` | Server supports `tasks/list` |
| `tasks` | `cancel` | Server supports `tasks/cancel` |
| `tasks.requests` | `tools.call` | Task-augmented tool calls |

## Migration Guidance

### Upgrading from 2025-06-18 to 2025-11-25

**Effort:** Low–Medium  
**Breaking Changes:** None (additive only)

**Steps:**

1. **Update `protocolVersion`** in your `initialize` request to `"2025-11-25"`
2. **Add `MCP-Protocol-Version` header** to all HTTP requests (required for Streamable HTTP)
3. **Opt in to new capabilities** as needed:
   - Add `elicitation.url` if your client supports URL-mode elicitation
   - Add `sampling.tools` if your client supports tool-use in sampling
   - Add `tasks` capabilities for durable request handling
4. **Update tool definitions** to include `title`, `icons`, and optionally `outputSchema`
5. **Update enum schemas** in elicitation to use `oneOf`/`anyOf` for titled enums instead of `enumTitles`
6. **Support OIDC Discovery** in addition to RFC 8414 for authorization server metadata
7. **Handle Client ID Metadata Documents** as a new client registration approach

### Upgrading from 2025-03-26 to 2025-11-25

**Effort:** Medium  
**Breaking Changes:** None (additive only)

**Additional steps beyond the 2025-06-18 → 2025-11-25 list:**

1. Add elicitation capability (`form` mode at minimum)
2. Implement Origin header validation (return 403 Forbidden)
3. Implement RFC 9728 Protected Resource Metadata for authorization server discovery
4. Add Resource Indicators (RFC 8707) `resource` parameter to authorization requests

### Upgrading from 2024-11-05 to 2025-11-25

**Effort:** High  
**Breaking Changes:** Transport change (HTTP+SSE → Streamable HTTP)

**Key steps:**

1. Replace HTTP+SSE transport with Streamable HTTP (single endpoint, POST for messages)
2. Implement full OAuth 2.1 + PKCE authorization
3. Add session management (`Mcp-Session-Id`)
4. Add `MCP-Protocol-Version` header
5. All of the above feature additions

## Security Considerations

### Origin Validation (Streamable HTTP)

Servers running on Streamable HTTP **MUST** validate the `Origin` header on incoming requests. If the origin is not in the allow-list, the server MUST return `403 Forbidden`. When running locally, servers MUST bind to `localhost` to limit access.

### Session Security

- Session IDs MUST be cryptographically secure (non-deterministic)
- Servers MUST NOT use sessions for authentication
- Servers SHOULD bind session IDs to user-specific information (e.g., `<user_id>:<session_id>`)
- Servers SHOULD rotate or expire session IDs to reduce exposure

### Token Audience Binding

MCP clients MUST include the `resource` parameter (RFC 8707) in authorization and token requests. MCP servers MUST validate that tokens were specifically issued for their use. Token passthrough (forwarding client tokens to downstream APIs) is explicitly forbidden.

## Summary

- MCP uses **date-based version strings** (not semver): `2024-11-05`, `2025-03-26`, `2025-06-18`, `2025-11-25`
- Version negotiation occurs during the JSON-RPC `initialize` handshake
- The `MCP-Protocol-Version` HTTP header is required on all Streamable HTTP requests
- Each version is **additive** — no breaking changes between 2025-03-26 and 2025-11-25
- The 2024-11-05 → 2025-03-26 transition changed the transport (HTTP+SSE → Streamable HTTP)
- Authorization evolved from none (2024-11-05) through OAuth 2.1 (2025-03-26) to full OIDC + Client ID Metadata Documents (2025-11-25)

---

**Next**: Review [Migration Guides](10-migration-guides.md) for specific upgrade scenarios.
