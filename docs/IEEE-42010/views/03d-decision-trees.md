# Decision Trees

**Version:** 1.4.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Introduction

This document provides decision trees to help architects and developers make informed choices when designing and implementing MCP servers. Each decision tree guides you through common architectural decisions with clear criteria and recommendations.

## When to Use MCP vs REST API

```mermaid
flowchart TD
    Start([Should I use MCP or traditional REST API?])
    Q1{Is this service primarily<br/>for AI agent interaction?}
    Q2{Do you need multiple<br/>interaction patterns?<br/>Tools, Prompts, Resources}
    Q3{Is context management<br/>critical?<br/>Long-running conversations}
    Q4{Do you need standardized<br/>AI agent integration?<br/>Multiple AI clients}
    Q5{Do you have existing<br/>REST APIs to wrap?}
    
    UseMCP[✅ Use MCP]
    UseREST[Use REST API<br/>Better for traditional clients]
    MCPIntegration[Use MCP with REST integration<br/>See 03e-integration-patterns.md]
    MCPGreenfield[Use MCP for<br/>greenfield AI services]
    RESTSufficient[REST API may be sufficient]
    
    Start --> Q1
    Q1 -->|YES| Q2
    Q1 -->|NO| UseREST
    
    Q2 -->|YES| UseMCP
    Q2 -->|NO| Q3
    
    Q3 -->|YES| UseMCP
    Q3 -->|NO| Q4
    
    Q4 -->|YES| UseMCP
    Q4 -->|NO| Q5
    
    Q5 -->|YES| MCPIntegration
    Q5 -->|NO| MCPGreenfield
    
    style UseMCP fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseREST fill:#fff3cd,stroke:#856404
    style MCPIntegration fill:#d4f4dd,stroke:#2d662d
    style MCPGreenfield fill:#d4f4dd,stroke:#2d662d
    style Start fill:#e3f2fd,stroke:#1976d2
    style Q1 fill:#fff,stroke:#666
    style Q2 fill:#fff,stroke:#666
    style Q3 fill:#fff,stroke:#666
    style Q4 fill:#fff,stroke:#666
    style Q5 fill:#fff,stroke:#666
```

**Recommendation Summary:**

✅ **Use MCP when:**

- Primary consumers are AI agents
- Need tools + prompts + resources
- Context-aware interactions required
- Multi-client agent support needed

✅ **Use REST API when:**

- Traditional client applications (web, mobile)
- Simple CRUD operations
- Stateless request/response pattern
- Non-AI use cases

## Tool vs Prompt vs Resource Selection

```mermaid
flowchart TD
    Start([What MCP primitive should I implement?])
    Purpose{What is the<br/>primary purpose?}
    
    UseTool[🔨 Use TOOL<br/>Taking Action]
    UsePrompt[📝 Use PROMPT<br/>Guided Workflow]
    UseResource[📚 Use RESOURCE<br/>Providing Data]
    UseSampling[🤖 Use SAMPLING<br/>LLM Processing]
    
    ToolDetails["<b>Tool Examples:</b><br/>• create_user(name, email)<br/>• send_email(to, subject, body)<br/>• deploy_application(app_id, env)<br/>• delete_file(path)<br/><br/><b>Characteristics:</b><br/>• Changes system state<br/>• Has side effects<br/>• Returns operation result<br/>• May require confirmation"]
    
    PromptDetails["<b>Prompt Examples:</b><br/>• code_review_workflow<br/>• bug_report_template<br/>• deployment_checklist<br/><br/><b>Characteristics:</b><br/>• User controls execution<br/>• Parameters filled interactively<br/>• Multi-step process<br/>• Template-based"]
    
    ResourceDetails["<b>Resource Examples:</b><br/>• config://app/settings<br/>• logs://system/recent<br/>• docs://api/v1/endpoints<br/><br/><b>Characteristics:</b><br/>• Read-only access<br/>• URI-addressable<br/>• May support subscriptions<br/>• Can be cached"]
    
    SamplingDetails["<b>Sampling Examples:</b><br/>• summarize_document(text)<br/>• extract_entities(content)<br/>• classify_issue(description)<br/><br/><b>Characteristics:</b><br/>• Requires LLM processing<br/>• Structured output<br/>• Temperature-controlled<br/>• Prompt engineering"]
    
    Start --> Purpose
    
    Purpose -->|Modifying state<br/>Executing operations| UseTool
    Purpose -->|User-driven<br/>Parameter collection| UsePrompt
    Purpose -->|Reading state<br/>Exposing information| UseResource
    Purpose -->|Analysis<br/>Transformation<br/>Generation| UseSampling
    
    UseTool --> ToolDetails
    UsePrompt --> PromptDetails
    UseResource --> ResourceDetails
    UseSampling --> SamplingDetails
    
    style UseTool fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UsePrompt fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    style UseResource fill:#fff3e0,stroke:#ff6f00,stroke-width:2px
    style UseSampling fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style Start fill:#e3f2fd,stroke:#1976d2
    style Purpose fill:#fff,stroke:#666
    style ToolDetails fill:#f0f9f0,stroke:#2d662d
    style PromptDetails fill:#f0f1f9,stroke:#3f51b5
    style ResourceDetails fill:#fffbf0,stroke:#ff6f00
    style SamplingDetails fill:#f9f0f9,stroke:#7b1fa2
```

**Decision Matrix:**

| Capability      | Tool | Prompt | Resource | Sampling |
|-----------------|------|--------|----------|----------|
| Modify State    |  ✅  |   ❌   |    ❌    |    ❌    |
| Read Data       |  ✅  |   ❌   |    ✅    |    ✅    |
| User-Guided     |  ❌  |   ✅   |    ❌    |    ❌    |
| Side Effects    |  ✅  |   ❌   |    ❌    |    ❌    |
| Cacheable       |  ⚠️  |   ❌   |    ✅    |    ⚠️   |
| Subscriptions   |  ❌  |   ❌   |    ✅    |    ❌    |
| LLM Processing  |  ⚠️  |   ⚠️   |    ⚠️    |    ✅    |

Legend: ✅ Primary use case, ⚠️ Can be used, ❌ Not applicable

## Authentication Method Selection

```mermaid
flowchart TD
    Start([Which authentication method should I use?])
    Q1{Enterprise SSO<br/>Integration Required?<br/>SAML/OIDC/Azure AD}
    Q2{Multiple User Types?<br/>Developers, end-users,<br/>services}
    Q3{Service-to-Service<br/>Communication?}
    Q4{Open Source Project<br/>or Public API?}
    Q5{Development/Testing<br/>Only?}
    
    UseWorkOS[✅ Use WorkOS or<br/>OAuth 2.0 with SSO<br/><br/>Configuration: WorkOSProvider<br/>See: 02-security-architecture.md#workos]
    UseJWT[✅ Use JWT with JWKS<br/><br/>Benefits:<br/>• Multiple identity providers<br/>• Stateless token verification<br/>• Standard protocol<br/>• Role/claim support<br/><br/>Configuration: JWTVerifier<br/>See: 02-security-architecture.md#jwt]
    UseAPIKeys[✅ Use API Keys<br/><br/>Benefits:<br/>• Simple implementation<br/>• Easy rotation<br/>• Per-service isolation<br/><br/>Configuration: API_KEY<br/>See: 02-security-architecture.md#api-keys]
    UseOAuth[✅ Use OAuth 2.0<br/>with GitHub/Google<br/><br/>Benefits:<br/>• No credential management<br/>• User-friendly<br/>• Wide adoption<br/><br/>Configuration: GitHubProvider<br/>See: 02-security-architecture.md#oauth]
    UseJWTCustom[Use JWT with<br/>custom issuer]
    UseMock[⚠️ Use mocked authentication<br/><br/>NEVER use in production<br/>Configuration: MockAuthProvider]
    
    Start --> Q1
    Q1 -->|YES| UseWorkOS
    Q1 -->|NO| Q2
    
    Q2 -->|YES| UseJWT
    Q2 -->|NO| Q3
    
    Q3 -->|YES| UseAPIKeys
    Q3 -->|NO| Q4
    
    Q4 -->|YES| UseOAuth
    Q4 -->|NO| UseJWTCustom
    
    UseJWTCustom --> Q5
    Q5 -->|YES| UseMock
    
    style UseWorkOS fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseJWT fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseAPIKeys fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseOAuth fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseJWTCustom fill:#fff3cd,stroke:#856404
    style UseMock fill:#f8d7da,stroke:#721c24,stroke-width:2px
    style Start fill:#e3f2fd,stroke:#1976d2
    style Q1 fill:#fff,stroke:#666
    style Q2 fill:#fff,stroke:#666
    style Q3 fill:#fff,stroke:#666
    style Q4 fill:#fff,stroke:#666
    style Q5 fill:#fff,stroke:#666
```

**Authentication Comparison:**

| Method       | Security | Complexity | SSO       | Cost    |
|--------------|----------|------------|-----------|----------|
| JWT/JWKS     | High     | Medium     | Yes       | Low     |
| OAuth 2.0    | High     | Medium     | Yes       | Low     |
| WorkOS       | High     | Low        | Yes       | Medium  |
| API Keys     | Medium   | Low        | No        | Low     |
| Basic Auth   | Low      | Low        | No        | Low     |

**Recommended Combinations:**

1. **Enterprise SaaS:**
   - Primary: JWT/JWKS for users
   - Secondary: API Keys for services
   - SSO: WorkOS for enterprise customers

2. **Open Source Tool:**
   - Primary: OAuth 2.0 (GitHub/Google)
   - Secondary: API Keys for CLI tools

3. **Internal Service:**
   - Primary: JWT with internal IdP
   - Secondary: mTLS for service mesh

4. **Microservices:**
   - API Keys with service registry
   - mTLS for transport security

## Caching Strategy Selection

```mermaid
flowchart TD
    Start([What caching strategy should I implement?])
    Q1{Data changes<br/>frequently?<br/>< 1 minute}
    Q2{Data is<br/>user-specific?}
    Q3{Data is<br/>globally shared?}
    Q4{Data is expensive<br/>to compute?<br/>> 1 second}
    Q5{Strong consistency<br/>requirements?}
    Q6{Acceptable<br/>staleness?}
    
    NoCache[No caching or<br/>very short TTL: 5-30s<br/><br/>Use case: Real-time metrics,<br/>live status<br/>Implementation: cache.set ttl=5]
    UserCache[✅ User-scoped cache<br/><br/>Cache key: user:id:resource<br/>TTL: 60-300 seconds<br/>Example: User preferences]
    GlobalCache[✅ Global cache<br/>with longer TTL<br/><br/>Cache key: global:resource<br/>TTL: 300-3600 seconds<br/>Example: Configuration, reference data]
    AggressiveCache[✅ Aggressive caching<br/>with background refresh<br/><br/>Strategy: Cache-aside + refresh-ahead<br/>TTL: 1800-3600 seconds<br/>Background job: Refresh before expiry]
    ModerateCache[Moderate caching<br/>TTL: 300-900 seconds]
    InvalidationCache[✅ Cache with invalidation<br/><br/>Strategy: Write-through or write-behind<br/>Invalidate on updates<br/>Example: Financial data, inventory]
    TTLCache[Simple TTL-based caching]
    
    TTL30s[TTL: 15-30 seconds]
    TTL5m[TTL: 120-300 seconds]
    TTL30m[TTL: 900-1800 seconds]
    TTL60m[TTL: 1800-3600 seconds]
    
    Start --> Q1
    Q1 -->|YES| NoCache
    Q1 -->|NO| Q2
    
    Q2 -->|YES| UserCache
    Q2 -->|NO| Q3
    
    Q3 -->|YES| GlobalCache
    Q3 -->|NO| Q4
    
    Q4 -->|YES| AggressiveCache
    Q4 -->|NO| ModerateCache
    
    ModerateCache --> Q5
    Q5 -->|YES| InvalidationCache
    Q5 -->|NO| TTLCache
    
    TTLCache --> Q6
    Q6 -->|< 30 sec| TTL30s
    Q6 -->|< 5 min| TTL5m
    Q6 -->|< 30 min| TTL30m
    Q6 -->|> 30 min| TTL60m
    
    style UserCache fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style GlobalCache fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style AggressiveCache fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style InvalidationCache fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style NoCache fill:#fff3cd,stroke:#856404
    style ModerateCache fill:#fff3cd,stroke:#856404
    style TTLCache fill:#fff3cd,stroke:#856404
    style TTL30s fill:#e3f2fd,stroke:#1976d2
    style TTL5m fill:#e3f2fd,stroke:#1976d2
    style TTL30m fill:#e3f2fd,stroke:#1976d2
    style TTL60m fill:#e3f2fd,stroke:#1976d2
    style Start fill:#e3f2fd,stroke:#1976d2
    style Q1 fill:#fff,stroke:#666
    style Q2 fill:#fff,stroke:#666
    style Q3 fill:#fff,stroke:#666
    style Q4 fill:#fff,stroke:#666
    style Q5 fill:#fff,stroke:#666
    style Q6 fill:#fff,stroke:#666
```

**Caching Patterns:**

| Pattern         | Consistency    | Complexity | Use Case     |
|-----------------|----------------|------------|---------------|
| Cache-Aside     | Eventual       | Low        | Read-heavy   |
| Read-Through    | Eventual       | Medium     | Read-heavy   |
| Write-Through   | Strong         | Medium     | Write-heavy  |
| Write-Behind    | Eventual       | High       | Write-heavy  |
| Refresh-Ahead   | Eventual       | High       | Predictable  |

**Cache Invalidation Strategies:**

1. **TTL-based (Simplest)**
   - Set expiration time
   - No manual invalidation
   - Good for: Static data, external APIs

2. **Event-based (Most accurate)**
   - Invalidate on data changes
   - Requires event system
   - Good for: Frequently updated data

3. **Pattern-based (Bulk invalidation)**
   - Invalidate by key pattern
   - Example: cache.delete_pattern("user:123:*")
   - Good for: Related data sets

4. **Version-based (Cache busting)**
   - Include version in cache key
   - Example: f"data:{version}:{id}"
   - Good for: API responses, assets

**Example Implementations:**

```python
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

```mermaid
flowchart TD
    Start([Which database should I use?])
    Q1{Relational data with<br/>ACID requirements?}
    Q2{Need global<br/>distribution?}
    Q3{Document-oriented<br/>data?}
    Q4{Need querying<br/>flexibility?}
    Q5{AWS environment?}
    Q6{Time-series data?}
    Q7{Key-value store<br/>or Caching?}
    Q8{Graph<br/>relationships?}
    Q9{Search and<br/>analytics?}
    
    UseGlobalSQL[✅ Use CockroachDB or<br/>Google Spanner<br/><br/>For global distribution]
    UsePostgreSQL[✅ Use PostgreSQL<br/>Recommended<br/><br/>Benefits:<br/>• JSONB support<br/>• Full-text search<br/>• Mature ecosystem<br/>• Strong consistency]
    UseMySQL[Use MySQL<br/><br/>If existing expertise]
    UseMongoDB[✅ Use MongoDB<br/><br/>Use case: Dynamic schemas,<br/>complex queries]
    UseDynamoDB[✅ Use DynamoDB<br/><br/>Use case: Serverless,<br/>auto-scaling]
    UseMongoAtlas[Use MongoDB Atlas<br/><br/>Default choice]
    UseTimescale[✅ Use TimescaleDB or InfluxDB<br/><br/>Options:<br/>• TimescaleDB PostgreSQL extension<br/>• InfluxDB purpose-built<br/><br/>Use case: Metrics, logs, sensor data]
    UseRedis[✅ Use Redis or Memcached<br/><br/>• Redis: in-memory, rich data structures<br/>• Memcached: simple caching<br/><br/>Use case: Session, cache, pub/sub]
    UseNeo4j[✅ Use Neo4j or Amazon Neptune<br/><br/>• Neo4j: Cypher query language<br/>• Amazon Neptune: managed<br/><br/>Use case: Social networks, recommendations]
    UseElastic[✅ Use Elasticsearch or OpenSearch<br/><br/>• Elasticsearch: full-text search<br/>• OpenSearch: AWS alternative<br/><br/>Use case: Log analysis, full-text search]
    
    Start --> Q1
    Q1 -->|YES| Q2
    Q1 -->|NO| Q3
    
    Q2 -->|YES| UseGlobalSQL
    Q2 -->|NO| UsePostgreSQL
    UsePostgreSQL -.Alternative.-> UseMySQL
    
    Q3 -->|YES| Q4
    Q3 -->|NO| Q6
    
    Q4 -->|YES| UseMongoDB
    Q4 -->|NO| Q5
    
    Q5 -->|YES| UseDynamoDB
    Q5 -->|NO| UseMongoAtlas
    
    Q6 -->|YES| UseTimescale
    Q6 -->|NO| Q7
    
    Q7 -->|YES| UseRedis
    Q7 -->|NO| Q8
    
    Q8 -->|YES| UseNeo4j
    Q8 -->|NO| Q9
    
    Q9 -->|YES| UseElastic
    
    style UseGlobalSQL fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UsePostgreSQL fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseMongoDB fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseDynamoDB fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseTimescale fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseRedis fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseNeo4j fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseElastic fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseMySQL fill:#fff3cd,stroke:#856404
    style UseMongoAtlas fill:#fff3cd,stroke:#856404
    style Start fill:#e3f2fd,stroke:#1976d2
    style Q1 fill:#fff,stroke:#666
    style Q2 fill:#fff,stroke:#666
    style Q3 fill:#fff,stroke:#666
    style Q4 fill:#fff,stroke:#666
    style Q5 fill:#fff,stroke:#666
    style Q6 fill:#fff,stroke:#666
    style Q7 fill:#fff,stroke:#666
    style Q8 fill:#fff,stroke:#666
    style Q9 fill:#fff,stroke:#666
```

**Database Comparison:**

| Database     | Type       | Scale    | Complexity | Cost     |
|--------------|------------|----------|------------|----------|
| PostgreSQL   | Relational | High     | Medium     | Low      |
| MongoDB      | Document   | High     | Medium     | Medium   |
| DynamoDB     | Key-Value  | V.High   | Medium     | High*    |
| Redis        | Key-Value  | Medium   | Low        | Low      |
| TimescaleDB  | TimeSeries | High     | Medium     | Low      |
| Elasticsearch| Search     | High     | High       | Medium   |

*DynamoDB cost varies significantly with usage pattern

**Recommended Stack for MCP Servers:**

1. **Primary Storage:**
   - PostgreSQL for transactional data
   - JSONB for flexible schemas

2. **Caching Layer:**
   - Redis for session/cache
   - 5-15 minute TTL for API responses

3. **Full-Text Search (if needed):**
   - PostgreSQL full-text search (simple cases)
   - Elasticsearch (complex search requirements)

4. **Time-Series (if needed):**
   - TimescaleDB extension on PostgreSQL
   - Single database to manage

**Example Configuration:**

```python
# PostgreSQL for main data
DATABASE_URL = "postgresql://user:pass@host:5432/mcp_server"

# Redis for caching
REDIS_URL = "redis://localhost:6379/0"

# Connection pooling
DATABASE_POOL_MIN = 5
DATABASE_POOL_MAX = 20
```

## Deployment Model Selection

```mermaid
flowchart TD
    Start([How should I deploy my MCP server?])
    Q1{Limited DevOps<br/>experience?}
    Q2{Need enterprise<br/>control?}
    Q3{Cloud provider?}
    Q4{Serverless<br/>requirements?<br/>Event-driven,<br/>variable load}
    Q5{Existing<br/>infrastructure?}
    Q6{Development<br/>stage?}
    
    UseManagedPlatform[✅ Use Managed Platform<br/><br/>Options:<br/>• Heroku simplest<br/>• Railway modern alternative<br/>• Render good free tier<br/>• Google Cloud Run serverless containers<br/><br/>Benefits:<br/>• Minimal configuration<br/>• Automatic scaling<br/>• Integrated monitoring<br/>• Quick deployment]
    UseEKS[✅ Use AWS EKS]
    UseAKS[✅ Use Azure AKS]
    UseGKE[✅ Use Google GKE]
    UseSelfK8s[✅ Use Self-managed Kubernetes]
    K8sBenefits[Benefits:<br/>• Complete control<br/>• Cloud-agnostic<br/>• Rich ecosystem<br/>• Auto-scaling]
    UseServerless[✅ Use Serverless<br/><br/>Options:<br/>• AWS Lambda + API Gateway<br/>• Google Cloud Functions<br/>• Azure Functions<br/><br/>Considerations:<br/>⚠️ Cold start latency<br/>⚠️ Execution time limits 15 min<br/>✅ Auto-scaling to zero<br/>✅ Pay per invocation]
    UseSwarm[Continue with Docker Swarm]
    UseNomad[Continue with Nomad]
    UseVMs[Use Docker Compose on VMs]
    UseBareMetal[Use Docker Compose or systemd]
    UsePrototype[Use Local Docker Compose]
    UseMVP[Use Managed Platform<br/>Render/Railway]
    UseGrowth[Use Kubernetes or<br/>Managed Platform]
    UseEnterprise[✅ Use Kubernetes<br/>with multi-region]
    
    Start --> Q1
    Q1 -->|YES| UseManagedPlatform
    Q1 -->|NO| Q2
    
    Q2 -->|YES| Q3
    Q2 -->|NO| Q4
    
    Q3 -->|AWS| UseEKS
    Q3 -->|Azure| UseAKS
    Q3 -->|GCP| UseGKE
    Q3 -->|Multi-cloud| UseSelfK8s
    
    UseEKS --> K8sBenefits
    UseAKS --> K8sBenefits
    UseGKE --> K8sBenefits
    UseSelfK8s --> K8sBenefits
    
    Q4 -->|YES| UseServerless
    Q4 -->|NO| Q5
    
    Q5 -->|Docker Swarm| UseSwarm
    Q5 -->|Nomad| UseNomad
    Q5 -->|VM-based| UseVMs
    Q5 -->|Bare metal| UseBareMetal
    Q5 -->|None| Q6
    
    Q6 -->|Prototype| UsePrototype
    Q6 -->|MVP| UseMVP
    Q6 -->|Growth| UseGrowth
    Q6 -->|Enterprise| UseEnterprise
    
    style UseManagedPlatform fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseEKS fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseAKS fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseGKE fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseSelfK8s fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseServerless fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseEnterprise fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UseSwarm fill:#fff3cd,stroke:#856404
    style UseNomad fill:#fff3cd,stroke:#856404
    style UseVMs fill:#fff3cd,stroke:#856404
    style UseBareMetal fill:#fff3cd,stroke:#856404
    style UsePrototype fill:#e3f2fd,stroke:#1976d2
    style UseMVP fill:#e3f2fd,stroke:#1976d2
    style UseGrowth fill:#e3f2fd,stroke:#1976d2
    style K8sBenefits fill:#f0f9f0,stroke:#2d662d
    style Start fill:#e3f2fd,stroke:#1976d2
    style Q1 fill:#fff,stroke:#666
    style Q2 fill:#fff,stroke:#666
    style Q3 fill:#fff,stroke:#666
    style Q4 fill:#fff,stroke:#666
    style Q5 fill:#fff,stroke:#666
    style Q6 fill:#fff,stroke:#666
```

**Deployment Pattern Comparison:**

| Pattern          | Control  | Complexity | Cost     | Scale    |
|------------------|----------|------------|----------|----------|
| Managed Platform | Low      | Low        | Medium   | Medium   |
| Kubernetes       | High     | High       | Medium   | V.High   |
| Docker Compose   | Medium   | Low        | Low      | Low      |
| Serverless       | Low      | Medium     | Low*     | V.High   |
| VMs              | High     | Medium     | Medium   | Medium   |

*Serverless cost can be high with constant traffic

**Recommended Progression:**

**Phase 1 (0-100 users):**

- Deploy: Railway or Render
- Database: Managed PostgreSQL
- Monitoring: Built-in platform monitoring

**Phase 2 (100-10K users):**

- Deploy: Google Cloud Run or AWS ECS
- Database: Managed PostgreSQL with read replicas
- Monitoring: Application-level (Datadog, New Relic)

**Phase 3 (10K+ users):**

- Deploy: Kubernetes (EKS/GKE/AKS)
- Database: Multi-region PostgreSQL
- Monitoring: Full observability stack
- Architecture: Multi-region active-active

## Error Recovery Strategy

Choose the appropriate error recovery strategy based on error characteristics and business requirements:

```mermaid
flowchart TD
    Start([Error Detected])
    ErrorType{What type of<br/>error occurred?}
    
    Transient[TRANSIENT ERROR<br/>Network timeout, rate limit,<br/>temporary unavailability]
    Permanent[PERMANENT ERROR<br/>404, 403,<br/>validation failure]
    Timeout[TIMEOUT ERROR<br/>Operation exceeded<br/>deadline]
    ResourceExhaustion[RESOURCE EXHAUSTION<br/>Memory, connections,<br/>disk space]
    PartialFailure[PARTIAL FAILURE<br/>Some operations succeed,<br/>some fail]
    
    Q1{Is immediate<br/>retry safe?<br/>Idempotent?}
    Q2{How critical is<br/>the operation?}
    Q3{Rate limiting<br/>detected?}
    
    ExpBackoff[✅ EXPONENTIAL BACKOFF RETRY<br/><br/>• Max retries: 5<br/>• Base delay: 100ms<br/>• Backoff factor: 2x<br/>• Max delay: 30s<br/>• Add jitter: ±25%]
    LinearBackoff[✅ LINEAR BACKOFF RETRY<br/><br/>• Max retries: 3<br/>• Delay: 1s, 2s, 4s<br/>• Circuit breaker threshold: 50% failures]
    Dedup[✅ DEDUPLICATION + RETRY<br/><br/>• Generate idempotency key<br/>• Store operation result<br/>• Retry with same key<br/>• TTL: 24 hours]
    AdaptiveRate[✅ ADAPTIVE RATE LIMITING<br/><br/>• Respect Retry-After header<br/>• Implement token bucket<br/>• Reduce request rate: 50%<br/>• Gradual recovery: +10% per min]
    
    Q4{User-Correctable?<br/>Invalid input,<br/>missing permissions}
    Q5{Resource<br/>Not Found?}
    
    UserFeedback[✅ USER FEEDBACK + NO RETRY<br/><br/>• Return detailed error message<br/>• Suggest corrective actions<br/>• Log for analytics<br/>• Do NOT retry automatically]
    AlertFallback[✅ ALERT + FALLBACK<br/><br/>• Send alert to operations team<br/>• Log with HIGH severity<br/>• Disable failing feature<br/>• Return cached/default response]
    ValidateFallback[✅ VALIDATE + FALLBACK<br/><br/>• Verify resource should exist<br/>• Check data consistency issues<br/>• Provide alternative resources<br/>• Cache negative results 5 min TTL]
    
    Q6{Upstream Service<br/>Timeout?}
    Q7{Cascading<br/>Timeout?}
    
    CircuitBreaker[✅ CIRCUIT BREAKER PATTERN<br/><br/>States:<br/>• CLOSED: Normal operation<br/>  Failure threshold: 5 consecutive<br/>• OPEN: Fail fast 30s<br/>  Return cached/default response<br/>• HALF-OPEN: Test recovery<br/>  Allow 1 request]
    IncreaseTimeout[INCREASE TIMEOUT + OPTIMIZE<br/><br/>• Analyze operation duration<br/>• Identify bottlenecks<br/>• Add progress indicators<br/>• Consider async processing]
    Bulkhead[✅ BULKHEAD PATTERN<br/><br/>• Isolate failing components<br/>• Limit concurrent requests: 10/service<br/>• Separate thread pools<br/>• Degrade gracefully]
    
    Q8{Recoverable?<br/>Can free resources}
    Q9{Memory Leak<br/>Detected?}
    
    ShedLoad[✅ SHED LOAD + BACKPRESSURE<br/><br/>• Reject new requests 503<br/>• Return Retry-After: 60<br/>• Trigger resource cleanup<br/>• Complete in-flight requests<br/>• Alert operations team]
    EmergencyShutdown[✅ EMERGENCY SHUTDOWN<br/><br/>• Stop accepting requests<br/>• Drain existing connections<br/>• Save state if possible<br/>• Alert CRITICAL severity<br/>• Auto-restart with rate limiting]
    RestartInvestigate[✅ RESTART + INVESTIGATE<br/><br/>• Schedule graceful restart<br/>• Enable heap dump<br/>• Analyze memory profile<br/>• Implement memory limits]
    
    Q10{Batch<br/>Operation?}
    Q11{Distributed<br/>Transaction?}
    
    RetryFailed[✅ RETRY FAILED ITEMS ONLY<br/><br/>• Track successful items<br/>• Retry failed subset<br/>• Return partial success response<br/>• Log failure reasons<br/>• Consider batch size reduction]
    CompensatingTx[✅ COMPENSATING TRANSACTION<br/><br/>• Identify completed steps<br/>• Roll back successful operations<br/>• Use saga pattern<br/>• Log compensation actions]
    SagaPattern[✅ SAGA PATTERN<br/><br/>Forward Recovery: T1→T2→T3→Tn<br/>On failure at Ti:<br/>• Option A: Continue partial success<br/>• Option B: Compensate T i-1...T1<br/>Compensation: Idempotent actions]
    
    Start --> ErrorType
    
    ErrorType -->|Transient| Transient
    ErrorType -->|Permanent| Permanent
    ErrorType -->|Timeout| Timeout
    ErrorType -->|Resource| ResourceExhaustion
    ErrorType -->|Partial| PartialFailure
    
    Transient --> Q1
    Q1 -->|YES| Q2
    Q1 -->|NO| Dedup
    
    Q2 -->|HIGH| ExpBackoff
    Q2 -->|NORMAL| LinearBackoff
    
    ExpBackoff --> Q3
    LinearBackoff --> Q3
    Q3 -->|YES| AdaptiveRate
    
    Permanent --> Q4
    Q4 -->|YES| UserFeedback
    Q4 -->|NO| Q5
    
    Q5 -->|YES| ValidateFallback
    Q5 -->|NO| AlertFallback
    
    Timeout --> Q6
    Q6 -->|YES| CircuitBreaker
    Q6 -->|NO| IncreaseTimeout
    
    CircuitBreaker --> Q7
    Q7 -->|YES| Bulkhead
    
    ResourceExhaustion --> Q8
    Q8 -->|YES| ShedLoad
    Q8 -->|NO| Q9
    
    Q9 -->|YES| RestartInvestigate
    Q9 -->|NO| EmergencyShutdown
    
    PartialFailure --> Q10
    Q10 -->|YES| RetryFailed
    Q10 -->|NO| CompensatingTx
    
    CompensatingTx --> Q11
    Q11 -->|YES| SagaPattern
    
    style ExpBackoff fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style LinearBackoff fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style Dedup fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style AdaptiveRate fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style UserFeedback fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style AlertFallback fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style ValidateFallback fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style CircuitBreaker fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style Bulkhead fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style ShedLoad fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style EmergencyShutdown fill:#f8d7da,stroke:#721c24,stroke-width:2px
    style RestartInvestigate fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style RetryFailed fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style CompensatingTx fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style SagaPattern fill:#d4f4dd,stroke:#2d662d,stroke-width:2px
    style IncreaseTimeout fill:#fff3cd,stroke:#856404
    style Transient fill:#e3f2fd,stroke:#1976d2
    style Permanent fill:#e3f2fd,stroke:#1976d2
    style Timeout fill:#e3f2fd,stroke:#1976d2
    style ResourceExhaustion fill:#e3f2fd,stroke:#1976d2
    style PartialFailure fill:#e3f2fd,stroke:#1976d2
    style Start fill:#e3f2fd,stroke:#1976d2
    style ErrorType fill:#fff,stroke:#666
    style Q1 fill:#fff,stroke:#666
    style Q2 fill:#fff,stroke:#666
    style Q3 fill:#fff,stroke:#666
    style Q4 fill:#fff,stroke:#666
    style Q5 fill:#fff,stroke:#666
    style Q6 fill:#fff,stroke:#666
    style Q7 fill:#fff,stroke:#666
    style Q8 fill:#fff,stroke:#666
    style Q9 fill:#fff,stroke:#666
    style Q10 fill:#fff,stroke:#666
    style Q11 fill:#fff,stroke:#666
```

**Recommendation Summary:**

✅ **Transient Errors** → Retry with exponential backoff + circuit breaker  
✅ **Permanent Errors** → Fail fast with user feedback, no retries  
✅ **Timeouts** → Circuit breaker pattern, prevent cascading failures  
✅ **Resource Exhaustion** → Load shedding + backpressure, alert immediately  
✅ **Partial Failures** → Compensating transactions or retry failed subset

**Anti-Patterns to Avoid:**

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
