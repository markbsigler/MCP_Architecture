# Architecture Decision Records (ADRs)

**Navigation**: [Home](../README.md) > Core Architecture > Architecture Decisions  
**Related**: [← Previous: Architecture Overview](01-architecture-overview.md) | [Next: Security Architecture →](02-security-architecture.md) | [Decision Trees](03d-decision-trees.md)

**Version:** 1.4.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Quick Links

- [ADR Format and Template](#adr-format-and-template)
- [ADR 001: FastMCP Framework](#adr-001-fastmcp-as-mcp-server-framework)
- [ADR 002: JWT Authentication](#adr-002-jwt-and-oauth-20-for-authentication)
- [ADR 003: Observability Stack](#adr-003-opentelemetry-for-observability)
- [ADR 004: Deployment Platform](#adr-004-kubernetes-for-production-deployment)
- [Summary](#summary)

## Introduction

This document captures key architectural decisions made during the design of enterprise MCP servers. Each decision record includes context, considered alternatives, and rationale to help teams understand tradeoffs and make consistent choices.

## Decision Record Format

Each ADR follows this structure:

- **Decision:** What was decided
- **Context:** Why this decision was needed
- **Alternatives Considered:** Other options evaluated
- **Decision:** The chosen approach
- **Rationale:** Why this choice was made
- **Consequences:** Implications and tradeoffs
- **Status:** Accepted, Superseded, or Deprecated

## ADR-001: FastMCP Framework vs Native SDK

**Status:** Accepted  
**Date:** 2025-11-01

### Context

MCP servers can be implemented using either:

- FastMCP framework (high-level abstraction)
- Native MCP Python SDK (low-level protocol implementation)

### Alternatives Considered

1. **FastMCP Framework**
   - Pros: Built-in auth, SSE, dependency injection, declarative tools
   - Cons: Additional abstraction layer, framework lock-in

2. **Native MCP SDK**
   - Pros: Direct protocol control, maximum flexibility
   - Cons: Manual implementation of common patterns, more boilerplate

3. **Custom Framework**
   - Pros: Tailored to specific needs
   - Cons: High maintenance burden, reinventing solved problems

### Decision

Use FastMCP framework as the standard implementation approach.

### Rationale

- **Rapid Development:** Declarative tool registration reduces boilerplate by ~60%
- **Built-in Enterprise Features:** Auth, dependency injection, lifecycle hooks included
- **Consistency:** Standard patterns across all MCP servers
- **Active Development:** FastMCP actively maintained with enterprise focus
- **Escape Hatch:** Can drop to native SDK for specific edge cases if needed

### Consequences

- **Positive:**
  - Faster server development
  - Consistent patterns across team
  - Security and observability built-in
  - Easy onboarding for new developers

- **Negative:**
  - Framework dependency in deployment
  - Must wait for FastMCP updates for new protocol features
  - Learning curve for FastMCP-specific patterns

### Review Date

2026-06-01 (Reassess when MCP 2.0 protocol released)

---

## ADR-002: JWT/JWKS vs mTLS Authentication

**Status:** Accepted  
**Date:** 2025-11-05

### Context

Enterprise MCP servers require strong authentication. Two primary approaches:

- JWT tokens with JWKS validation (token-based)
- Mutual TLS (certificate-based)

### Alternatives Considered

1. **JWT with JWKS**
   - Pros: SSO integration, token rotation, works through proxies
   - Cons: Token theft risk, requires secure key management

2. **Mutual TLS (mTLS)**
   - Pros: Strong cryptographic auth, no token theft risk
   - Cons: Certificate management complexity, poor proxy/LB support

3. **API Keys**
   - Pros: Simple implementation
   - Cons: No standard rotation, poor audit trail, static secrets

4. **OAuth 2.0 Client Credentials**
   - Pros: Standard flow, refresh tokens
   - Cons: Additional OAuth server dependency

### Decision

Use JWT/JWKS as primary authentication mechanism, with optional mTLS for high-security deployments.

### Rationale

- **Enterprise SSO:** JWT integrates with existing identity providers (Okta, Azure AD, Auth0)
- **Token Lifecycle:** Short-lived tokens (15min) with refresh mechanism reduces exposure window
- **Proxy Compatible:** Works through API gateways and load balancers
- **Cloud Native:** Standard in Kubernetes/service mesh environments
- **Audit Trail:** Token claims provide user identity and permissions for logging
- **Gradual Rollout:** Can enable mTLS per-environment without changing all clients

### Consequences

- **Positive:**
  - Seamless SSO integration
  - Standard OAuth 2.0 ecosystem tools work
  - Easy key rotation via JWKS endpoint
  - Works with existing API gateways

- **Negative:**
  - Token theft possible if TLS compromised
  - Clock synchronization required (exp validation)
  - JWKS endpoint becomes critical dependency
  - Need secure token storage on clients

### Mitigations

- Enforce short token TTL (15min max)
- Implement token binding (OAuth 2.0 extension)
- Add rate limiting per token/user
- Use secure token storage (keychain/vault)
- Monitor for anomalous token usage patterns

### Implementation Notes

```python
# Standard JWT configuration
JWT_CONFIG = {
    "jwks_uri": "https://auth.example.com/.well-known/jwks.json",
    "issuer": "https://auth.example.com",
    "audience": "mcp-server-production",
    "jwks_cache_ttl": 3600,  # 1 hour
    "clock_skew": 60,  # Allow 60s time drift
    "required_claims": ["sub", "email", "roles"]
}
```

---

## ADR-003: Stateless vs Stateful Server Design

**Status:** Accepted  
**Date:** 2025-11-10

### Context

MCP servers need to decide whether to maintain state between requests or remain stateless.

### Alternatives Considered

1. **Stateless Design**
   - Pros: Horizontal scaling, simple deployment, no session management
   - Cons: Context passed in each request, larger payloads

2. **Stateful with In-Memory**
   - Pros: Fast context access, smaller requests
   - Cons: No horizontal scaling, session affinity required

3. **Stateful with External Store (Redis)**
   - Pros: Horizontal scaling, fast session access
   - Cons: Additional infrastructure, network latency, complexity

4. **Hybrid (Stateless + Optional Context Cache)**
   - Pros: Best of both worlds, graceful degradation
   - Cons: More complex implementation

### Decision

Use stateless design by default with optional Redis-backed context caching for conversation history.

### Rationale

- **Cloud Native:** Stateless enables auto-scaling and rolling updates
- **Simplicity:** No session affinity or sticky sessions required
- **Reliability:** Server failures don't lose critical state
- **Optional Enhancement:** Context caching improves UX without breaking stateless contract
- **Cost Effective:** No Redis needed for simple deployments

### Consequences

- **Positive:**
  - Deploy anywhere (containers, serverless, edge)
  - Scale horizontally without coordination
  - Zero-downtime deployments
  - No session affinity configuration

- **Negative:**
  - Larger request payloads (must include context)
  - Client manages conversation state
  - Cache warming needed for performance-critical paths

### Implementation Pattern

```python
# Stateless tool execution
@mcp.tool()
async def create_assignment(
    title: str,
    assignee: str,
    # Optional conversation context passed by client
    conversation_id: Optional[str] = None
) -> dict:
    """Stateless tool - no server-side session."""
    
    # Optional: Check cache for recent conversation context
    if conversation_id:
        cached_context = await redis.get(f"conv:{conversation_id}")
    
    # Tool logic doesn't depend on cached state
    assignment = await backend.create_assignment(title, assignee)
    
    # Optional: Update cache for next request
    if conversation_id:
        await redis.setex(
            f"conv:{conversation_id}",
            300,  # 5min TTL
            json.dumps({"last_assignment": assignment.id})
        )
    
    return {"success": True, "data": assignment.to_dict()}
```

---

## ADR-004: Database Selection for Tool Metadata

**Status:** Accepted  
**Date:** 2025-11-12

### Context

MCP servers need to store tool metadata, schemas, and optionally audit logs.

### Alternatives Considered

1. **PostgreSQL**
   - Pros: ACID, JSON support, full-text search, mature
   - Cons: Operational overhead, slower for high-write workloads

2. **MongoDB**
   - Pros: Flexible schema, horizontal scaling, fast writes
   - Cons: Eventual consistency, complex queries harder

3. **SQLite (Embedded)**
   - Pros: Zero configuration, serverless, fast
   - Cons: Single writer, no network access, limited scale

4. **File-based (JSON)**
   - Pros: Simple, version control friendly
   - Cons: No transactions, no concurrent writes, no queries

### Decision

Use **PostgreSQL** for production deployments, **SQLite** for development/testing.

### Rationale

- **ACID Guarantees:** Critical for audit logs and compliance
- **JSON Support:** Native JSONB for flexible tool schemas
- **Full-Text Search:** Tool discovery by description/tags
- **Mature Ecosystem:** Connection pooling, replication, backup tools
- **Developer Experience:** SQLite for fast local development
- **Cloud Support:** Managed PostgreSQL available on all platforms

### Consequences

- **Positive:**
  - Strong consistency for audit trails
  - Rich query capabilities for tool discovery
  - JSON flexibility for evolving schemas
  - Battle-tested reliability

- **Negative:**
  - Operational overhead (backups, monitoring)
  - Vertical scaling limits (use read replicas)
  - Not ideal for ultra-high write rates (use time-series DB for metrics)

### Schema Design

```sql
-- Tool registry table
CREATE TABLE mcp_tools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    schema JSONB NOT NULL,
    version VARCHAR(50) NOT NULL,
    deprecated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tools_name ON mcp_tools(name);
CREATE INDEX idx_tools_schema ON mcp_tools USING GIN(schema);

-- Audit log table
CREATE TABLE mcp_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    tool_name VARCHAR(255) NOT NULL,
    parameters JSONB,
    result_status VARCHAR(50),
    duration_ms INTEGER,
    correlation_id UUID
);

CREATE INDEX idx_audit_timestamp ON mcp_audit_logs(timestamp DESC);
CREATE INDEX idx_audit_user ON mcp_audit_logs(user_id);
CREATE INDEX idx_audit_tool ON mcp_audit_logs(tool_name);
```

---

## ADR-005: HTTP/SSE vs WebSocket Transport

**Status:** Accepted  
**Date:** 2025-11-15

### Context

MCP protocol supports multiple transports. Choose between HTTP+SSE and WebSocket for production.

### Alternatives Considered

1. **HTTP + Server-Sent Events (SSE)**
   - Pros: Simpler, works through proxies, unidirectional streaming
   - Cons: HTTP overhead per request, connection limits

2. **WebSocket**
   - Pros: Bidirectional, lower latency, efficient binary protocol
   - Cons: Proxy/firewall issues, connection state management

3. **HTTP Long Polling**
   - Pros: Universal compatibility
   - Cons: Inefficient, high latency, resource intensive

### Decision

Use **HTTP + SSE** as primary transport with WebSocket as opt-in for specific use cases.

### Rationale

- **Proxy Friendly:** Works through corporate proxies and CDNs
- **Simpler Scaling:** Stateless HTTP requests easier to load balance
- **Standard Tools:** All HTTP monitoring/debugging tools work
- **Security:** TLS termination at load balancer
- **MCP Fit:** Request-response pattern fits HTTP model
- **SSE for Streaming:** Efficient streaming for long-running tools

### Consequences

- **Positive:**
  - Standard load balancer configuration
  - Works in restrictive networks
  - Easy debugging (curl, browser devtools)
  - Cloud provider compatibility

- **Negative:**
  - Slightly higher latency than WebSocket
  - Connection limit per browser (6 per domain)
  - Unidirectional stream (server→client only)

### When to Use WebSocket

- Real-time bidirectional updates required
- Mobile apps needing battery efficiency
- High-frequency low-latency operations
- Private networks where proxy issues don't apply

---

## Decision Process Guidelines

### When to Create an ADR

Create an ADR for decisions that:

- Impact multiple teams or components
- Are difficult or expensive to reverse
- Have significant tradeoffs
- Establish patterns others will follow
- Address cross-cutting concerns

### ADR Review Process

1. **Draft:** Author creates ADR with alternatives and rationale
2. **Review:** Architecture team reviews, suggests improvements
3. **Discussion:** Stakeholder input via comments or meetings
4. **Decision:** Tech lead or architect approves
5. **Publish:** ADR added to documentation
6. **Implement:** Communicate decision to affected teams

### Updating ADRs

ADRs are immutable once accepted. To change a decision:

1. Create new ADR superseding the old one
2. Link from old ADR to new one
3. Mark old ADR as "Superseded"
4. Document migration path

### ADR Template

```markdown
## ADR-XXX: [Decision Title]

**Status:** [Proposed|Accepted|Superseded|Deprecated]  
**Date:** YYYY-MM-DD

### Context
[Why is this decision needed?]

### Alternatives Considered
1. Option A: [Pros/Cons]
2. Option B: [Pros/Cons]

### Decision
[What was chosen?]

### Rationale
[Why this choice?]

### Consequences
**Positive:**
- [Benefit 1]

**Negative:**
- [Tradeoff 1]

### Review Date
[When to reassess this decision]
```
