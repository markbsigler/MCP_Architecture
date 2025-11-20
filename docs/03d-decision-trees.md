# Decision Trees

**Version:** 1.3.0  
**Last Updated:** November 19, 2025  
**Status:** Draft

## Introduction

This document provides decision trees to help architects and developers make informed choices when designing and implementing MCP servers. Each decision tree guides you through common architectural decisions with clear criteria and recommendations.

## When to Use MCP vs REST API

```
START: Should I use MCP or traditional REST API?

├─ Is this service primarily for AI agent interaction?
│  ├─ YES → Continue to next question
│  └─ NO → Use REST API (better for traditional clients)
│
├─ Do you need to provide multiple interaction patterns?
│  ├─ Tools (actions), Prompts (workflows), Resources (data)
│  │  └─ YES → Use MCP (native support for all patterns)
│  └─ NO → Continue to next question
│
├─ Is context management critical?
│  ├─ Long-running conversations with state
│  │  └─ YES → Use MCP (built-in context handling)
│  └─ NO → Continue to next question
│
├─ Do you need standardized AI agent integration?
│  ├─ Multiple AI clients (Claude, ChatGPT, etc.)
│  │  └─ YES → Use MCP (protocol standard)
│  └─ NO → REST API may be sufficient
│
└─ Do you have existing REST APIs to wrap?
   ├─ YES → Use MCP with REST integration (see 03e-integration-patterns.md)
   └─ NO → Use MCP for greenfield AI services

RECOMMENDATION SUMMARY:
✅ Use MCP when:
   - Primary consumers are AI agents
   - Need tools + prompts + resources
   - Context-aware interactions required
   - Multi-client agent support needed

✅ Use REST API when:
   - Traditional client applications (web, mobile)
   - Simple CRUD operations
   - Stateless request/response pattern
   - Non-AI use cases
```

## Tool vs Prompt vs Resource Selection

```
START: What MCP primitive should I implement?

├─ What is the primary purpose?
│
├─ TAKING ACTION (modifying state, executing operations)
│  └─ Use TOOL
│     Examples:
│     - create_user(name, email)
│     - send_email(to, subject, body)
│     - deploy_application(app_id, environment)
│     - delete_file(path)
│     
│     Characteristics:
│     - Changes system state
│     - Has side effects
│     - Returns operation result
│     - May require confirmation
│
├─ GUIDED WORKFLOW (user-driven, parameter collection)
│  └─ Use PROMPT
│     Examples:
│     - code_review_workflow (guides through review steps)
│     - bug_report_template (collects bug details)
│     - deployment_checklist (ensures all steps completed)
│     
│     Characteristics:
│     - User controls execution
│     - Parameters filled interactively
│     - Multi-step process
│     - Template-based
│
├─ PROVIDING DATA (reading state, exposing information)
│  └─ Use RESOURCE
│     Examples:
│     - config://app/settings (application configuration)
│     - logs://system/recent (recent system logs)
│     - docs://api/v1/endpoints (API documentation)
│     
│     Characteristics:
│     - Read-only access
│     - URI-addressable
│     - May support subscriptions
│     - Can be cached
│
└─ PROCESSING WITH LLM (analysis, transformation, generation)
   └─ Use SAMPLING (within Tool or Resource)
      Examples:
      - summarize_document(text)
      - extract_entities(content)
      - classify_issue(description)
      
      Characteristics:
      - Requires LLM processing
      - Structured output
      - Temperature-controlled
      - May need prompt engineering

DECISION MATRIX:

┌─────────────────┬──────┬────────┬──────────┬──────────┐
│ Capability      │ Tool │ Prompt │ Resource │ Sampling │
├─────────────────┼──────┼────────┼──────────┼──────────┤
│ Modify State    │  ✅  │   ❌   │    ❌    │    ❌    │
│ Read Data       │  ✅  │   ❌   │    ✅    │    ✅    │
│ User-Guided     │  ❌  │   ✅   │    ❌    │    ❌    │
│ Side Effects    │  ✅  │   ❌   │    ❌    │    ❌    │
│ Cacheable       │  ⚠️  │   ❌   │    ✅    │    ⚠️   │
│ Subscriptions   │  ❌  │   ❌   │    ✅    │    ❌    │
│ LLM Processing  │  ⚠️  │   ⚠️   │    ⚠️    │    ✅    │
└─────────────────┴──────┴────────┴──────────┴──────────┘

Legend: ✅ Primary use case, ⚠️ Can be used, ❌ Not applicable
```

## Authentication Method Selection

```
START: Which authentication method should I use?

├─ What type of users/clients?
│
├─ Enterprise SSO Integration Required?
│  ├─ YES (SAML/OIDC/Azure AD)
│  │  └─ Use WorkOS or OAuth 2.0 with SSO provider
│  │     Configuration: WorkOSProvider(org_id=...)
│  │     See: docs/02-security-architecture.md#workos
│  │
│  └─ NO → Continue to next question
│
├─ Multiple User Types (developers, end-users, services)?
│  ├─ YES → Use JWT with JWKS
│  │  Benefits:
│  │  - Supports multiple identity providers
│  │  - Stateless token verification
│  │  - Standard protocol
│  │  - Role/claim support
│  │  Configuration: JWTVerifier(jwks_uri=...)
│  │  See: docs/02-security-architecture.md#jwt
│  │
│  └─ NO → Continue to next question
│
├─ Service-to-Service Communication?
│  ├─ YES → Use API Keys
│  │  Benefits:
│  │  - Simple implementation
│  │  - Easy rotation
│  │  - Per-service isolation
│  │  Configuration: API_KEY authentication
│  │  See: docs/02-security-architecture.md#api-keys
│  │
│  └─ NO → Continue to next question
│
├─ Open Source Project / Public API?
│  ├─ YES → Use OAuth 2.0 with GitHub/Google
│  │  Benefits:
│  │  - No credential management
│  │  - User-friendly
│  │  - Wide adoption
│  │  Configuration: GitHubProvider() or GoogleProvider()
│  │  See: docs/02-security-architecture.md#oauth
│  │
│  └─ NO → Use JWT with custom issuer
│
└─ Development/Testing Only?
   └─ YES → Use mocked authentication
      ⚠️  NEVER use in production
      Configuration: MockAuthProvider()

AUTHENTICATION COMPARISON:

┌──────────────┬──────────┬────────────┬───────────┬─────────┐
│ Method       │ Security │ Complexity │ SSO       │ Cost    │
├──────────────┼──────────┼────────────┼───────────┼─────────┤
│ JWT/JWKS     │   High   │   Medium   │    Yes    │   Low   │
│ OAuth 2.0    │   High   │   Medium   │    Yes    │   Low   │
│ WorkOS       │   High   │    Low     │    Yes    │  Medium │
│ API Keys     │  Medium  │    Low     │    No     │   Low   │
│ Basic Auth   │   Low    │    Low     │    No     │   Low   │
└──────────────┴──────────┴────────────┴───────────┴─────────┘

RECOMMENDED COMBINATIONS:

1. Enterprise SaaS:
   - Primary: JWT/JWKS for users
   - Secondary: API Keys for services
   - SSO: WorkOS for enterprise customers

2. Open Source Tool:
   - Primary: OAuth 2.0 (GitHub/Google)
   - Secondary: API Keys for CLI tools

3. Internal Service:
   - Primary: JWT with internal IdP
   - Secondary: mTLS for service mesh

4. Microservices:
   - API Keys with service registry
   - mTLS for transport security
```

## Caching Strategy Selection

```
START: What caching strategy should I implement?

├─ What is the data volatility?
│
├─ Data changes frequently (< 1 minute)?
│  ├─ YES → No caching or very short TTL (5-30 seconds)
│  │  Use case: Real-time metrics, live status
│  │  Implementation: cache.set(key, value, ttl=5)
│  │
│  └─ NO → Continue to next question
│
├─ Data is user-specific?
│  ├─ YES → User-scoped cache
│  │  Cache key: f"user:{user_id}:{resource}"
│  │  TTL: 60-300 seconds
│  │  Example: User preferences, user-specific data
│  │
│  └─ NO → Continue to next question
│
├─ Data is globally shared?
│  ├─ YES → Global cache with longer TTL
│  │  Cache key: f"global:{resource}"
│  │  TTL: 300-3600 seconds
│  │  Example: Configuration, reference data
│  │
│  └─ NO → Continue to next question
│
├─ Data is expensive to compute?
│  ├─ YES (> 1 second compute time)
│  │  └─ Aggressive caching with background refresh
│  │     Strategy: Cache-aside with refresh-ahead
│  │     TTL: 1800-3600 seconds
│  │     Background job: Refresh before expiry
│  │
│  └─ NO → Moderate caching
│
├─ Data has strong consistency requirements?
│  ├─ YES → Cache with invalidation
│  │  Strategy: Write-through or write-behind
│  │  Invalidate on updates
│  │  Example: Financial data, inventory
│  │
│  └─ NO → Simple TTL-based caching
│
└─ Acceptable staleness?
   ├─ < 30 seconds → TTL: 15-30 seconds
   ├─ < 5 minutes → TTL: 120-300 seconds
   ├─ < 30 minutes → TTL: 900-1800 seconds
   └─ > 30 minutes → TTL: 1800-3600 seconds

CACHING PATTERNS:

┌─────────────────┬────────────────┬───────────┬──────────────┐
│ Pattern         │ Consistency    │ Complexity│ Use Case     │
├─────────────────┼────────────────┼───────────┼──────────────┤
│ Cache-Aside     │ Eventual       │    Low    │ Read-heavy   │
│ Read-Through    │ Eventual       │   Medium  │ Read-heavy   │
│ Write-Through   │ Strong         │   Medium  │ Write-heavy  │
│ Write-Behind    │ Eventual       │    High   │ Write-heavy  │
│ Refresh-Ahead   │ Eventual       │    High   │ Predictable  │
└─────────────────┴────────────────┴───────────┴──────────────┘

CACHE INVALIDATION STRATEGIES:

1. TTL-based (Simplest)
   - Set expiration time
   - No manual invalidation
   - Good for: Static data, external APIs

2. Event-based (Most accurate)
   - Invalidate on data changes
   - Requires event system
   - Good for: Frequently updated data

3. Pattern-based (Bulk invalidation)
   - Invalidate by key pattern
   - Example: cache.delete_pattern("user:123:*")
   - Good for: Related data sets

4. Version-based (Cache busting)
   - Include version in cache key
   - Example: f"data:{version}:{id}"
   - Good for: API responses, assets

EXAMPLE IMPLEMENTATIONS:

# Cache-Aside (Lazy Loading)
async def get_data(key: str):
    cached = await cache.get(key)
    if cached:
        return cached
    
    data = await expensive_operation()
    await cache.set(key, data, ttl=300)
    return data

# Write-Through (Immediate consistency)
async def update_data(key: str, value: dict):
    await database.update(key, value)
    await cache.set(key, value, ttl=300)

# Refresh-Ahead (Background refresh)
async def get_with_refresh(key: str):
    cached = await cache.get_with_ttl(key)
    
    if cached.ttl < 60:  # Refresh if expiring soon
        asyncio.create_task(refresh_cache(key))
    
    return cached.value
```

## Database Technology Selection

```
START: Which database should I use?

├─ What is your primary access pattern?
│
├─ Relational data with ACID requirements?
│  ├─ YES → SQL Database
│  │  ├─ Need global distribution?
│  │  │  ├─ YES → CockroachDB or Google Spanner
│  │  │  └─ NO → PostgreSQL (recommended)
│  │  │     Benefits:
│  │  │     - JSONB support
│  │  │     - Full-text search
│  │  │     - Mature ecosystem
│  │  │     - Strong consistency
│  │  │
│  │  └─ Alternative: MySQL if existing expertise
│  │
│  └─ NO → Continue to next question
│
├─ Document-oriented data?
│  ├─ YES → Document Database
│  │  ├─ Need querying flexibility?
│  │  │  ├─ YES → MongoDB
│  │  │  │  Use case: Dynamic schemas, complex queries
│  │  │  └─ NO → Continue
│  │  │
│  │  ├─ AWS environment?
│  │  │  └─ YES → DynamoDB
│  │  │     Use case: Serverless, auto-scaling
│  │  │
│  │  └─ Default: MongoDB Atlas
│  │
│  └─ NO → Continue to next question
│
├─ Time-series data?
│  ├─ YES → Time-Series Database
│  │  Options:
│  │  - TimescaleDB (PostgreSQL extension)
│  │  - InfluxDB (purpose-built)
│  │  Use case: Metrics, logs, sensor data
│  │
│  └─ NO → Continue to next question
│
├─ Key-value store / Caching?
│  ├─ YES → Key-Value Store
│  │  - Redis (in-memory, rich data structures)
│  │  - Memcached (simple caching)
│  │  Use case: Session storage, caching, pub/sub
│  │
│  └─ NO → Continue to next question
│
├─ Graph relationships?
│  ├─ YES → Graph Database
│  │  - Neo4j (mature, Cypher query language)
│  │  - Amazon Neptune (managed)
│  │  Use case: Social networks, recommendations
│  │
│  └─ NO → Continue to next question
│
└─ Search and analytics?
   └─ YES → Search Engine
      - Elasticsearch (full-text search)
      - OpenSearch (AWS alternative)
      Use case: Log analysis, full-text search

DATABASE COMPARISON:

┌──────────────┬────────────┬──────────┬────────────┬──────────┐
│ Database     │ Type       │ Scale    │ Complexity │ Cost     │
├──────────────┼────────────┼──────────┼────────────┼──────────┤
│ PostgreSQL   │ Relational │   High   │   Medium   │   Low    │
│ MongoDB      │ Document   │   High   │   Medium   │  Medium  │
│ DynamoDB     │ Key-Value  │  V.High  │   Medium   │  High*   │
│ Redis        │ Key-Value  │  Medium  │    Low     │   Low    │
│ TimescaleDB  │ TimeSeries │   High   │   Medium   │   Low    │
│ Elasticsearch│ Search     │   High   │    High    │  Medium  │
└──────────────┴────────────┴──────────┴────────────┴──────────┘

*DynamoDB cost varies significantly with usage pattern

RECOMMENDED STACK FOR MCP SERVERS:

1. Primary Storage:
   - PostgreSQL for transactional data
   - JSONB for flexible schemas

2. Caching Layer:
   - Redis for session/cache
   - 5-15 minute TTL for API responses

3. Full-Text Search (if needed):
   - PostgreSQL full-text search (simple cases)
   - Elasticsearch (complex search requirements)

4. Time-Series (if needed):
   - TimescaleDB extension on PostgreSQL
   - Single database to manage

EXAMPLE CONFIGURATION:

# PostgreSQL for main data
DATABASE_URL = "postgresql://user:pass@host:5432/mcp_server"

# Redis for caching
REDIS_URL = "redis://localhost:6379/0"

# Connection pooling
DATABASE_POOL_MIN = 5
DATABASE_POOL_MAX = 20
```

## Deployment Model Selection

```
START: How should I deploy my MCP server?

├─ What is your operational maturity?
│
├─ Limited DevOps experience?
│  ├─ YES → Managed Platform
│  │  Options:
│  │  - Heroku (simplest)
│  │  - Railway (modern alternative)
│  │  - Render (good free tier)
│  │  - Google Cloud Run (serverless containers)
│  │
│  │  Benefits:
│  │  - Minimal configuration
│  │  - Automatic scaling
│  │  - Integrated monitoring
│  │  - Quick deployment
│  │
│  └─ NO → Continue to next question
│
├─ Need enterprise control?
│  ├─ YES → Kubernetes
│  │  ├─ Cloud provider?
│  │  │  ├─ AWS → EKS
│  │  │  ├─ Azure → AKS
│  │  │  ├─ GCP → GKE
│  │  │  └─ Multi-cloud → Self-managed K8s
│  │  │
│  │  Benefits:
│  │  - Complete control
│  │  - Cloud-agnostic
│  │  - Rich ecosystem
│  │  - Auto-scaling
│  │
│  └─ NO → Continue to next question
│
├─ Serverless requirements?
│  ├─ YES (event-driven, variable load)
│  │  Options:
│  │  - AWS Lambda + API Gateway
│  │  - Google Cloud Functions
│  │  - Azure Functions
│  │  
│  │  Considerations:
│  │  ⚠️  Cold start latency
│  │  ⚠️  Execution time limits (15 min)
│  │  ✅ Auto-scaling to zero
│  │  ✅ Pay per invocation
│  │
│  └─ NO → Continue to next question
│
├─ Existing infrastructure?
│  ├─ Docker Swarm → Continue with Swarm
│  ├─ Nomad → Continue with Nomad
│  ├─ VM-based → Docker Compose on VMs
│  └─ Bare metal → Docker Compose or systemd
│
└─ Development stage?
   ├─ Prototype → Local Docker Compose
   ├─ MVP → Managed platform (Render/Railway)
   ├─ Growth → Kubernetes or managed platform
   └─ Enterprise → Kubernetes with multi-region

DEPLOYMENT PATTERN COMPARISON:

┌─────────────────┬──────────┬────────────┬──────────┬──────────┐
│ Pattern         │ Control  │ Complexity │ Cost     │ Scale    │
├─────────────────┼──────────┼────────────┼──────────┼──────────┤
│ Managed Platform│   Low    │    Low     │  Medium  │  Medium  │
│ Kubernetes      │   High   │    High    │  Medium  │  V.High  │
│ Docker Compose  │  Medium  │    Low     │   Low    │   Low    │
│ Serverless      │   Low    │   Medium   │  Low*    │  V.High  │
│ VMs             │   High   │   Medium   │  Medium  │  Medium  │
└─────────────────┴──────────┴────────────┴──────────┴──────────┘

*Serverless cost can be high with constant traffic

RECOMMENDED PROGRESSION:

Phase 1 (0-100 users):
- Deploy: Railway or Render
- Database: Managed PostgreSQL
- Monitoring: Built-in platform monitoring

Phase 2 (100-10K users):
- Deploy: Google Cloud Run or AWS ECS
- Database: Managed PostgreSQL with read replicas
- Monitoring: Application-level (Datadog, New Relic)

Phase 3 (10K+ users):
- Deploy: Kubernetes (EKS/GKE/AKS)
- Database: Multi-region PostgreSQL
- Monitoring: Full observability stack
- Architecture: Multi-region active-active
```

## Error Recovery Strategy

Choose the appropriate error recovery strategy based on error characteristics and business requirements:

```text
START: Error Detected
│
├─ What type of error occurred?
│
├─ TRANSIENT ERROR (Network timeout, rate limit, temporary unavailability)
│  │
│  ├─ Is immediate retry safe?
│  │  │
│  │  ├─ YES (Idempotent operation)
│  │  │  │
│  │  │  ├─ How critical is the operation?
│  │  │  │
│  │  │  ├─ HIGH PRIORITY
│  │  │  │  └─> EXPONENTIAL BACKOFF RETRY
│  │  │  │      • Max retries: 5
│  │  │  │      • Base delay: 100ms
│  │  │  │      • Backoff factor: 2x
│  │  │  │      • Max delay: 30s
│  │  │  │      • Add jitter: ±25%
│  │  │  │
│  │  │  └─ NORMAL PRIORITY
│  │  │     └─> LINEAR BACKOFF RETRY
│  │  │         • Max retries: 3
│  │  │         • Delay: 1s, 2s, 4s
│  │  │         • Circuit breaker threshold: 50% failures
│  │  │
│  │  └─ NO (Non-idempotent operation)
│  │     └─> DEDUPLICATION + RETRY
│  │         • Generate idempotency key
│  │         • Store operation result
│  │         • Retry with same key
│  │         • TTL: 24 hours
│  │
│  └─ Rate Limiting Detected?
│     │
│     ├─ YES
│     │  └─> ADAPTIVE RATE LIMITING
│     │      • Respect Retry-After header
│     │      • Implement token bucket
│     │      • Reduce request rate: 50%
│     │      • Gradual recovery: +10% per minute
│     │
│     └─ NO
│        └─> STANDARD RETRY (see above)
│
├─ PERMANENT ERROR (404, 403, validation failure)
│  │
│  ├─ User-Correctable?
│  │  │
│  │  ├─ YES (Invalid input, missing permissions)
│  │  │  └─> USER FEEDBACK + NO RETRY
│  │  │      • Return detailed error message
│  │  │      • Suggest corrective actions
│  │  │      • Log for analytics
│  │  │      • Do NOT retry automatically
│  │  │
│  │  └─ NO (Configuration error, system misconfiguration)
│  │     └─> ALERT + FALLBACK
│  │         • Send alert to operations team
│  │         • Log with HIGH severity
│  │         • Disable failing feature
│  │         • Return cached/default response
│  │
│  └─ Resource Not Found?
│     │
│     ├─ YES
│     │  └─> VALIDATE + FALLBACK
│     │      • Verify resource should exist
│     │      • Check for data consistency issues
│     │      • Provide alternative resources
│     │      • Cache negative results (5 min TTL)
│     │
│     └─ NO
│        └─> FAIL FAST (see above)
│
├─ TIMEOUT ERROR (Operation exceeded deadline)
│  │
│  ├─ Upstream Service Timeout?
│  │  │
│  │  ├─ YES
│  │  │  └─> CIRCUIT BREAKER PATTERN
│  │  │      States:
│  │  │      • CLOSED: Normal operation
│  │  │        - Failure threshold: 5 consecutive failures
│  │  │        - Success threshold: Reset counter on success
│  │  │      • OPEN: Fail fast without calling service
│  │  │        - Duration: 30 seconds
│  │  │        - Return: Cached/default response
│  │  │      • HALF-OPEN: Test service recovery
│  │  │        - Allow 1 request
│  │  │        - Success → CLOSED
│  │  │        - Failure → OPEN (60s)
│  │  │
│  │  └─ NO (Local operation timeout)
│  │     └─> INCREASE TIMEOUT + OPTIMIZE
│  │         • Analyze operation duration
│  │         • Identify bottlenecks
│  │         • Add progress indicators
│  │         • Consider async processing
│  │
│  └─ Cascading Timeout?
│     │
│     ├─ YES (Multiple services timing out)
│     │  └─> BULKHEAD PATTERN
│     │      • Isolate failing components
│     │      • Limit concurrent requests: 10 per service
│     │      • Separate thread pools
│     │      • Degrade gracefully
│     │
│     └─ NO
│        └─> CIRCUIT BREAKER (see above)
│
├─ RESOURCE EXHAUSTION (Memory, connections, disk space)
│  │
│  ├─ Recoverable?
│  │  │
│  │  ├─ YES (Can free resources)
│  │  │  └─> SHED LOAD + BACKPRESSURE
│  │  │      • Reject new requests (503 Service Unavailable)
│  │  │      • Return Retry-After: 60 header
│  │  │      • Trigger resource cleanup
│  │  │      • Complete in-flight requests
│  │  │      • Alert operations team
│  │  │
│  │  └─ NO (System-level issue)
│  │     └─> EMERGENCY SHUTDOWN
│  │         • Stop accepting requests
│  │         • Drain existing connections
│  │         • Save state if possible
│  │         • Alert with CRITICAL severity
│  │         • Auto-restart with rate limiting
│  │
│  └─ Memory Leak Detected?
│     │
│     ├─ YES
│     │  └─> RESTART + INVESTIGATE
│     │      • Schedule graceful restart
│     │      • Enable heap dump
│     │      • Analyze memory profile
│     │      • Implement memory limits
│     │
│     └─ NO
│        └─> LOAD SHEDDING (see above)
│
└─ PARTIAL FAILURE (Some operations succeed, some fail)
   │
   ├─ Batch Operation?
   │  │
   │  ├─ YES
   │  │  └─> RETRY FAILED ITEMS ONLY
   │  │      • Track successful items
   │  │      • Retry failed subset
   │  │      • Return partial success response
   │  │      • Log failure reasons
   │  │      • Consider batch size reduction
   │  │
   │  └─ NO
   │     └─> COMPENSATING TRANSACTION
   │         • Identify completed steps
   │         • Roll back successful operations
   │         • Use saga pattern for distributed transactions
   │         • Log compensation actions
   │
   └─ Distributed Transaction?
      │
      ├─ YES
      │  └─> SAGA PATTERN
      │      Forward Recovery:
      │      • T1 → T2 → T3 → ... → Tn
      │      • On failure at Ti:
      │        - Option A: Continue with partial success
      │        - Option B: Compensate T(i-1) ... T1
      │      
      │      Compensation Actions:
      │      • C1 ← C2 ← C3 ← ... ← Ci
      │      • Idempotent compensations
      │      • Store compensation log
      │      • Retry compensations on failure
      │
      └─ NO
         └─> RETRY FAILED ITEMS (see above)

RECOMMENDATION SUMMARY:

✅ Transient Errors → Retry with exponential backoff + circuit breaker
✅ Permanent Errors → Fail fast with user feedback, no retries
✅ Timeouts → Circuit breaker pattern, prevent cascading failures
✅ Resource Exhaustion → Load shedding + backpressure, alert immediately
✅ Partial Failures → Compensating transactions or retry failed subset

ANTI-PATTERNS TO AVOID:

❌ Retrying non-idempotent operations without deduplication
❌ Infinite retry loops without backoff or circuit breaker
❌ Ignoring Retry-After headers on rate limit errors
❌ Synchronous blocking on retry logic
❌ Failing to distinguish transient vs permanent errors
❌ Retrying permanent errors (wastes resources)
❌ No timeout on retry attempts (can compound failures)

IMPLEMENTATION EXAMPLE:

```python
from enum import Enum
import asyncio
from typing import TypeVar, Callable
import random

class ErrorType(Enum):
    TRANSIENT = "transient"
    PERMANENT = "permanent"
    TIMEOUT = "timeout"
    RESOURCE_EXHAUSTION = "resource_exhaustion"

class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class CircuitBreaker:
    def __init__(self, failure_threshold: int = 5, timeout: int = 30):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failure_count = 0
        self.state = CircuitState.CLOSED
        self.last_failure_time = None
    
    async def call(self, func: Callable, *args, **kwargs):
        if self.state == CircuitState.OPEN:
            if time.time() - self.last_failure_time > self.timeout:
                self.state = CircuitState.HALF_OPEN
            else:
                raise CircuitBreakerOpenError("Circuit breaker is OPEN")
        
        try:
            result = await func(*args, **kwargs)
            self.on_success()
            return result
        except Exception as e:
            self.on_failure()
            raise
    
    def on_success(self):
        self.failure_count = 0
        if self.state == CircuitState.HALF_OPEN:
            self.state = CircuitState.CLOSED
    
    def on_failure(self):
        self.failure_count += 1
        self.last_failure_time = time.time()
        if self.failure_count >= self.failure_threshold:
            self.state = CircuitState.OPEN

async def retry_with_backoff(
    func: Callable,
    max_retries: int = 3,
    base_delay: float = 1.0,
    backoff_factor: float = 2.0,
    max_delay: float = 30.0,
    jitter: bool = True
):
    """Retry with exponential backoff and jitter."""
    for attempt in range(max_retries + 1):
        try:
            return await func()
        except Exception as e:
            if attempt == max_retries:
                raise
            
            # Classify error
            error_type = classify_error(e)
            
            if error_type == ErrorType.PERMANENT:
                # Don't retry permanent errors
                raise
            
            # Calculate delay
            delay = min(base_delay * (backoff_factor ** attempt), max_delay)
            
            # Add jitter to prevent thundering herd
            if jitter:
                delay = delay * (0.75 + random.random() * 0.5)
            
            await asyncio.sleep(delay)

def classify_error(error: Exception) -> ErrorType:
    """Classify error type for recovery strategy."""
    if isinstance(error, (ConnectionError, TimeoutError)):
        return ErrorType.TRANSIENT
    elif isinstance(error, (ValueError, PermissionError)):
        return ErrorType.PERMANENT
    elif isinstance(error, asyncio.TimeoutError):
        return ErrorType.TIMEOUT
    elif isinstance(error, MemoryError):
        return ErrorType.RESOURCE_EXHAUSTION
    else:
        return ErrorType.TRANSIENT  # Default to transient for unknown errors
```

```

## Summary

These decision trees provide a structured approach to common architectural decisions. Use them as starting points, then refer to detailed documentation sections for implementation guidance.

For multi-phase transition planning (e.g., REST → MCP, protocol negotiation, auth rotation), consult **Migration Guides (12)** alongside these trees.

**Key Principles:**

1. **Start Simple**: Choose the simplest solution that meets requirements
2. **Iterate**: Re-evaluate as requirements evolve
3. **Measure**: Use metrics to validate decisions
4. **Document**: Record decisions and rationale (see ADRs in docs/01b-architecture-decisions.md)
5. **Review**: Periodically revisit decisions as system evolves

---

**Related Documentation:**

- [Architecture Overview](01-architecture-overview.md)
- [Architecture Decisions](01b-architecture-decisions.md)
- [Security Architecture](02-security-architecture.md)
- [Tool Implementation](03-tool-implementation.md)
- [Testing Strategy](04-testing-strategy.md)
- [Deployment Patterns](07-deployment-patterns.md)
- [Integration Patterns](03e-integration-patterns.md)
- [Migration Guides](10-migration-guides.md)
