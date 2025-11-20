# Troubleshooting Guide

**Navigation**: [Home](../README.md) > Advanced Topics > Troubleshooting  
**Related**: [← Previous: Migration Guides](10-migration-guides.md) | [Next: Cost Optimization →](12-cost-optimization.md) | [Operational Runbooks](08-operational-runbooks.md)

**Version:** 1.3.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Quick Links

- [Authentication Failures](#authentication-failures)
- [Rate Limiting Errors](#rate-limiting-errors)
- [Performance Degradation](#performance-degradation)
- [Memory Leaks](#memory-leaks)
- [Database Connection Issues](#database-connection-issues)
- [Log Analysis Patterns](#log-analysis-patterns)
- [Flame Graph Analysis](#understanding-flame-graphs)
- [Summary](#summary)

## Introduction

This guide provides systematic approaches to diagnosing and resolving common issues in MCP server deployments. It covers authentication failures, rate limiting, performance degradation, memory leaks, database connection issues, and provides diagnostic tools and analysis patterns.

## Common Issues

### Authentication Failures

#### Symptom: 401 Unauthorized Responses

**Possible Causes:**

1. **Expired Tokens**

```python
# Check token expiration
import jwt
from datetime import datetime

def diagnose_token(token: str):
    """Diagnose JWT token issues."""
    try:
        # Decode without verification first
        header = jwt.get_unverified_header(token)
        payload = jwt.decode(token, options={"verify_signature": False})
        
        print(f"Algorithm: {header.get('alg')}")
        print(f"Issued at: {datetime.fromtimestamp(payload.get('iat', 0))}")
        print(f"Expires at: {datetime.fromtimestamp(payload.get('exp', 0))}")
        print(f"Subject: {payload.get('sub')}")
        
        # Check if expired
        exp = payload.get('exp', 0)
        if datetime.now().timestamp() > exp:
            print("❌ Token is EXPIRED")
            print(f"Expired {int((datetime.now().timestamp() - exp) / 60)} minutes ago")
        else:
            print("✅ Token is still valid")
            print(f"Valid for {int((exp - datetime.now().timestamp()) / 60)} more minutes")
            
    except jwt.DecodeError as e:
        print(f"❌ Invalid token format: {e}")
    except Exception as e:
        print(f"❌ Error: {e}")

# Usage
diagnose_token("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
```

1. **Invalid Signature**

```bash
# Test token signature with curl
TOKEN="your-jwt-token"
SECRET="your-secret-key"

# Verify token manually
python3 << EOF
import jwt
import sys

try:
    decoded = jwt.decode(
        "${TOKEN}",
        "${SECRET}",
        algorithms=["HS256"]
    )
    print("✅ Token signature valid")
    print(f"User: {decoded.get('sub')}")
except jwt.InvalidSignatureError:
    print("❌ Invalid signature - secret key mismatch")
except jwt.ExpiredSignatureError:
    print("❌ Token expired")
except Exception as e:
    print(f"❌ Error: {e}")
EOF
```

1. **Missing Authorization Header**

```bash
# Test with proper header
curl -v https://api.example.com/v2/assignments \
  -H "Authorization: Bearer ${TOKEN}" \
  2>&1 | grep -E "(Authorization|401|403)"

# Common mistakes
curl https://api.example.com/v2/assignments \
  -H "Bearer: ${TOKEN}"  # ❌ Wrong header name

curl https://api.example.com/v2/assignments \
  -H "Authorization: ${TOKEN}"  # ❌ Missing "Bearer" prefix
```

**Resolution Steps:**

```bash
# 1. Check server logs for auth failures
kubectl logs -n production deployment/mcp-server \
  | grep "authentication_failed" \
  | jq '{timestamp: .timestamp, user: .user_id, reason: .error_details}'

# 2. Verify auth service connectivity
curl -f https://auth.example.com/.well-known/openid-configuration

# 3. Test token refresh
curl -X POST https://auth.example.com/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=${REFRESH_TOKEN}&client_id=${CLIENT_ID}"

# 4. Check token blacklist/revocation
redis-cli GET "revoked:${TOKEN_JTI}"
```

#### Symptom: 403 Forbidden Responses

**Possible Causes:**

1. **Insufficient Permissions**

```python
# Check user permissions
async def diagnose_permissions(user_id: str, required_permission: str):
    """Check if user has required permission."""
    user = await db.get_user(user_id)
    roles = await db.get_user_roles(user_id)
    
    print(f"User: {user_id}")
    print(f"Roles: {[r.name for r in roles]}")
    
    all_permissions = set()
    for role in roles:
        permissions = await db.get_role_permissions(role.id)
        all_permissions.update(p.name for p in permissions)
    
    print(f"Permissions: {sorted(all_permissions)}")
    
    if required_permission in all_permissions:
        print(f"✅ User HAS permission: {required_permission}")
    else:
        print(f"❌ User MISSING permission: {required_permission}")
        print(f"Required role: {await db.get_roles_with_permission(required_permission)}")

# Usage
await diagnose_permissions("user-123", "assignments:delete")
```

1. **IP Whitelist Restrictions**

```bash
# Check current IP
MY_IP=$(curl -s https://api.ipify.org)
echo "Current IP: ${MY_IP}"

# Check if IP is whitelisted
curl -s https://api.example.com/v2/admin/ip-whitelist \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq --arg ip "$MY_IP" '.whitelist[] | select(.ip == $ip)'

# Add IP to whitelist
curl -X POST https://api.example.com/v2/admin/ip-whitelist \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"ip\": \"${MY_IP}\", \"description\": \"DevOps workstation\"}"
```

### Rate Limiting Problems

#### Symptom: 429 Too Many Requests

**Diagnostic Commands:**

```bash
# Check rate limit headers
curl -I https://api.example.com/v2/assignments \
  -H "Authorization: Bearer ${TOKEN}" \
  | grep -E "X-RateLimit|Retry-After"

# Output:
# X-RateLimit-Limit: 100
# X-RateLimit-Remaining: 0
# X-RateLimit-Reset: 1700500000
# Retry-After: 58

# Calculate reset time
python3 -c "
from datetime import datetime
reset_timestamp = 1700500000
reset_time = datetime.fromtimestamp(reset_timestamp)
print(f'Rate limit resets at: {reset_time}')
print(f'Seconds until reset: {reset_timestamp - datetime.now().timestamp():.0f}')
"
```

**Check Rate Limit Status:**

```python
# rate_limit_check.py
import redis
import time

async def check_rate_limits(user_id: str):
    """Check user's rate limit status across all buckets."""
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    
    # Fixed window
    key = f"rate_limit:fixed:{user_id}:{int(time.time() / 60)}"
    count = r.get(key) or 0
    print(f"Fixed window (1 min): {count}/100 requests")
    
    # Sliding window
    key = f"rate_limit:sliding:{user_id}"
    count = r.zcount(key, time.time() - 60, time.time())
    print(f"Sliding window (1 min): {count}/100 requests")
    
    # Token bucket
    key = f"rate_limit:tokens:{user_id}"
    tokens = float(r.get(key) or 100)
    print(f"Token bucket: {tokens:.2f}/100 tokens")
    
    # Get all rate limit keys for user
    all_keys = r.keys(f"rate_limit:*:{user_id}*")
    print(f"\nAll rate limit keys: {len(all_keys)}")
    for key in all_keys[:10]:  # Show first 10
        ttl = r.ttl(key)
        print(f"  {key}: TTL {ttl}s")

# Usage
await check_rate_limits("user-123")
```

**Resolution Steps:**

```bash
# 1. Request rate limit increase
curl -X POST https://api.example.com/v2/admin/rate-limits \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user-123",
    "limit": 1000,
    "window_seconds": 60,
    "reason": "High-volume integration"
  }'

# 2. Reset rate limit for user (emergency)
redis-cli DEL "rate_limit:*:user-123:*"

# 3. Implement exponential backoff in client
python3 << 'EOF'
import time
import random

def request_with_backoff(url, max_retries=5):
    """Make request with exponential backoff."""
    for attempt in range(max_retries):
        response = requests.get(url)
        
        if response.status_code != 429:
            return response
        
        # Exponential backoff with jitter
        retry_after = int(response.headers.get('Retry-After', 0))
        if retry_after:
            wait_time = retry_after
        else:
            wait_time = (2 ** attempt) + random.uniform(0, 1)
        
        print(f"Rate limited. Waiting {wait_time:.2f}s before retry {attempt + 1}/{max_retries}")
        time.sleep(wait_time)
    
    raise Exception("Max retries exceeded")
EOF
```

### Performance Degradation

#### Symptom: Slow Response Times

**Quick Diagnostics:**

```bash
# 1. Check endpoint latency distribution
curl -s https://api.example.com/metrics \
  | grep "mcp_request_duration_seconds" \
  | grep "quantile"

# Output:
# mcp_request_duration_seconds{quantile="0.5"} 0.125
# mcp_request_duration_seconds{quantile="0.95"} 0.487
# mcp_request_duration_seconds{quantile="0.99"} 1.234

# 2. Identify slow endpoints
curl -s https://api.example.com/metrics \
  | grep "mcp_request_duration_seconds_sum" \
  | awk '{print $NF, $0}' \
  | sort -rn \
  | head -10

# 3. Check system resources
kubectl top pods -n production | grep mcp-server

# Output:
# NAME                          CPU(cores)   MEMORY(bytes)
# mcp-server-7d8f9c4b5-abc12    985m         2048Mi
# mcp-server-7d8f9c4b5-def34    1200m        2304Mi  # ⚠️ High CPU
```

**Database Query Performance:**

```python
# diagnose_slow_queries.py
import asyncpg
from datetime import datetime, timedelta

async def find_slow_queries(threshold_ms: int = 1000):
    """Find queries slower than threshold."""
    conn = await asyncpg.connect(DATABASE_URL)
    
    # PostgreSQL: pg_stat_statements extension required
    slow_queries = await conn.fetch("""
        SELECT
            calls,
            total_exec_time / 1000 AS total_seconds,
            mean_exec_time / 1000 AS mean_seconds,
            max_exec_time / 1000 AS max_seconds,
            stddev_exec_time / 1000 AS stddev_seconds,
            rows,
            query
        FROM pg_stat_statements
        WHERE mean_exec_time > $1
        ORDER BY mean_exec_time DESC
        LIMIT 10
    """, threshold_ms)
    
    print(f"Queries slower than {threshold_ms}ms:")
    print("-" * 100)
    
    for row in slow_queries:
        print(f"\nCalls: {row['calls']}")
        print(f"Mean: {row['mean_seconds']:.3f}s | Max: {row['max_seconds']:.3f}s | StdDev: {row['stddev_seconds']:.3f}s")
        print(f"Total: {row['total_seconds']:.1f}s | Rows: {row['rows']}")
        print(f"Query: {row['query'][:200]}...")
        print("-" * 100)
    
    await conn.close()

# Usage
await find_slow_queries(threshold_ms=1000)
```

**Application Profiling:**

```python
# profile_endpoint.py
import cProfile
import pstats
from io import StringIO

def profile_request():
    """Profile a request handler."""
    profiler = cProfile.Profile()
    profiler.enable()
    
    # Execute request
    response = app.get("/v2/assignments?limit=100")
    
    profiler.disable()
    
    # Print stats
    s = StringIO()
    stats = pstats.Stats(profiler, stream=s)
    stats.sort_stats('cumulative')
    stats.print_stats(20)  # Top 20 functions
    
    print(s.getvalue())

# Alternative: Use py-spy for live profiling
# pip install py-spy
# sudo py-spy record -o profile.svg --pid $(pgrep -f "mcp-server")
```

**Resolution Steps:**

```bash
# 1. Add database indexes
psql $DATABASE_URL << 'EOF'
-- Find missing indexes
SELECT
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname = 'public'
    AND n_distinct > 100
    AND correlation < 0.1
ORDER BY n_distinct DESC;

-- Add index for slow query
CREATE INDEX CONCURRENTLY idx_assignments_assignee_status
ON assignments (assignee_id, status)
WHERE deleted_at IS NULL;
EOF

# 2. Enable query caching
redis-cli << 'EOF'
CONFIG SET maxmemory 2gb
CONFIG SET maxmemory-policy allkeys-lru
EOF

# 3. Scale horizontally
kubectl scale deployment mcp-server --replicas=5 -n production

# 4. Enable connection pooling
# Update config
cat > config/database.yaml << 'EOF'
database:
  pool_size: 20
  max_overflow: 10
  pool_timeout: 30
  pool_recycle: 3600
EOF
```

### Memory Leaks

#### Symptom: Increasing Memory Usage

**Detection:**

```bash
# 1. Monitor memory growth over time
kubectl top pod -n production mcp-server-xxx --containers | \
  awk '{print strftime("%Y-%m-%d %H:%M:%S"), $0}' >> memory.log

# Watch for 5 minutes
for i in {1..60}; do
  kubectl top pod mcp-server-7d8f9c4b5-abc12 -n production >> memory.log
  sleep 5
done

# Analyze growth rate
awk '{if(NR>1) print $3}' memory.log | \
  python3 -c "
import sys
values = [int(line.strip().replace('Mi','')) for line in sys.stdin]
print(f'Initial: {values[0]}Mi')
print(f'Final: {values[-1]}Mi')
print(f'Growth: {values[-1] - values[0]}Mi')
print(f'Rate: {(values[-1] - values[0]) / len(values) * 60:.1f}Mi/hour')
"
```

**Memory Profiling:**

```python
# memory_profiler.py
from memory_profiler import profile
import tracemalloc

@profile
async def process_assignments():
    """Profile memory usage of assignment processing."""
    assignments = await db.get_assignments(limit=10000)
    
    # Process assignments
    results = []
    for assignment in assignments:
        processed = await process_assignment(assignment)
        results.append(processed)
    
    return results

# Alternative: tracemalloc for detailed analysis
def analyze_memory_leaks():
    """Find memory leaks using tracemalloc."""
    tracemalloc.start()
    
    # Take snapshot before
    snapshot1 = tracemalloc.take_snapshot()
    
    # Execute suspected code
    for _ in range(1000):
        await process_assignments()
    
    # Take snapshot after
    snapshot2 = tracemalloc.take_snapshot()
    
    # Compare snapshots
    top_stats = snapshot2.compare_to(snapshot1, 'lineno')
    
    print("Top 10 memory allocations:")
    for stat in top_stats[:10]:
        print(f"{stat}")

# Usage
await analyze_memory_leaks()
```

**Common Leak Patterns:**

```python
# 1. Unclosed database connections
# ❌ Bad: Connection leak
async def get_user(user_id: str):
    conn = await asyncpg.connect(DATABASE_URL)
    user = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)
    return user  # Connection never closed!

# ✅ Good: Proper cleanup
async def get_user(user_id: str):
    conn = await asyncpg.connect(DATABASE_URL)
    try:
        user = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)
        return user
    finally:
        await conn.close()

# 2. Growing cache without eviction
# ❌ Bad: Unbounded cache
cache = {}
async def get_assignment(assignment_id: str):
    if assignment_id not in cache:
        cache[assignment_id] = await db.get_assignment(assignment_id)
    return cache[assignment_id]

# ✅ Good: LRU cache with size limit
from functools import lru_cache
@lru_cache(maxsize=1000)
def get_assignment_cached(assignment_id: str):
    return db.get_assignment(assignment_id)

# 3. Circular references
# ❌ Bad: Circular reference preventing GC
class Assignment:
    def __init__(self):
        self.parent = None
        self.children = []
    
    def add_child(self, child):
        child.parent = self  # Circular reference
        self.children.append(child)

# ✅ Good: Use weak references
import weakref
class Assignment:
    def __init__(self):
        self.parent = None  # Will use weakref
        self.children = []
    
    def add_child(self, child):
        child.parent = weakref.ref(self)
        self.children.append(child)
```

**Resolution Steps:**

```bash
# 1. Restart pods with memory leak
kubectl rollout restart deployment/mcp-server -n production

# 2. Set memory limits to prevent OOM
kubectl set resources deployment mcp-server \
  --limits=memory=2Gi \
  --requests=memory=1Gi \
  -n production

# 3. Enable memory profiling in production
kubectl set env deployment/mcp-server \
  PYTHONTRACEMALLOC=1 \
  MALLOC_TRIM_THRESHOLD_=100000 \
  -n production

# 4. Configure aggressive garbage collection
kubectl set env deployment/mcp-server \
  PYTHONGC="1,10,10" \
  -n production
```

### Database Connection Issues

#### Symptom: Connection Pool Exhausted

**Diagnostic Commands:**

```bash
# 1. Check connection pool status
psql $DATABASE_URL -c "
SELECT
    COUNT(*) as total_connections,
    COUNT(*) FILTER (WHERE state = 'active') as active,
    COUNT(*) FILTER (WHERE state = 'idle') as idle,
    COUNT(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction
FROM pg_stat_activity
WHERE datname = current_database()
    AND application_name = 'mcp-server';
"

# Output:
# total_connections | active | idle | idle_in_transaction
#                45 |     12 |   28 |                   5  ⚠️

# 2. Find long-running transactions
psql $DATABASE_URL -c "
SELECT
    pid,
    application_name,
    state,
    query_start,
    NOW() - query_start AS duration,
    LEFT(query, 100) AS query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
    AND NOW() - query_start > INTERVAL '5 minutes'
ORDER BY query_start;
"

# 3. Check for locks
psql $DATABASE_URL -c "
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
"
```

**Connection Leak Detection:**

```python
# connection_leak_detector.py
import asyncpg
import asyncio
from contextlib import asynccontextmanager

class ConnectionPoolMonitor:
    """Monitor database connection pool for leaks."""
    
    def __init__(self, pool):
        self.pool = pool
        self.active_connections = {}
    
    @asynccontextmanager
    async def acquire(self):
        """Acquire connection with leak detection."""
        import traceback
        
        conn = await self.pool.acquire()
        conn_id = id(conn)
        
        # Track where connection was acquired
        stack = ''.join(traceback.format_stack())
        self.active_connections[conn_id] = {
            'acquired_at': asyncio.get_event_loop().time(),
            'stack': stack
        }
        
        try:
            yield conn
        finally:
            await self.pool.release(conn)
            del self.active_connections[conn_id]
    
    def check_leaks(self, threshold_seconds: int = 60):
        """Find connections held longer than threshold."""
        current_time = asyncio.get_event_loop().time()
        
        leaks = []
        for conn_id, info in self.active_connections.items():
            age = current_time - info['acquired_at']
            if age > threshold_seconds:
                leaks.append({
                    'conn_id': conn_id,
                    'age_seconds': age,
                    'stack': info['stack']
                })
        
        return leaks

# Usage
pool = await asyncpg.create_pool(DATABASE_URL)
monitor = ConnectionPoolMonitor(pool)

# Periodically check for leaks
async def leak_checker():
    while True:
        await asyncio.sleep(60)
        leaks = monitor.check_leaks(threshold_seconds=60)
        if leaks:
            for leak in leaks:
                print(f"⚠️ Connection leak detected!")
                print(f"Connection ID: {leak['conn_id']}")
                print(f"Age: {leak['age_seconds']:.1f}s")
                print(f"Acquired at:\n{leak['stack']}")
```

**Resolution Steps:**

```bash
# 1. Kill idle transactions
psql $DATABASE_URL -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
    AND NOW() - query_start > INTERVAL '5 minutes';
"

# 2. Increase pool size temporarily
kubectl set env deployment/mcp-server \
  DB_POOL_SIZE=50 \
  DB_POOL_MAX_OVERFLOW=20 \
  -n production

# 3. Enable connection timeout
kubectl set env deployment/mcp-server \
  DB_POOL_TIMEOUT=10 \
  DB_POOL_RECYCLE=1800 \
  -n production

# 4. Monitor connection pool metrics
curl -s http://localhost:9090/api/v1/query \
  -d 'query=mcp_db_connection_pool_size' \
  | jq '.data.result[0].value[1]'
```

## Diagnostic Commands

### System Health Check

```bash
#!/bin/bash
# health_check.sh - Comprehensive system health check

echo "=== MCP Server Health Check ==="
echo

# 1. Service availability
echo "1. Service Availability"
if curl -sf https://api.example.com/health > /dev/null; then
  echo "✅ API is responding"
else
  echo "❌ API is DOWN"
fi
echo

# 2. Pod status
echo "2. Pod Status"
kubectl get pods -n production -l app=mcp-server \
  -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp
echo

# 3. Resource usage
echo "3. Resource Usage"
kubectl top pods -n production -l app=mcp-server
echo

# 4. Recent errors
echo "4. Recent Errors (last 5 minutes)"
kubectl logs -n production -l app=mcp-server --since=5m \
  | grep -i error \
  | tail -10
echo

# 5. Database connectivity
echo "5. Database Connectivity"
psql $DATABASE_URL -c "SELECT 1" > /dev/null 2>&1 \
  && echo "✅ Database connected" \
  || echo "❌ Database connection failed"
echo

# 6. Redis connectivity
echo "6. Redis Connectivity"
redis-cli ping > /dev/null 2>&1 \
  && echo "✅ Redis connected" \
  || echo "❌ Redis connection failed"
echo

# 7. Active alerts
echo "7. Active Alerts"
curl -s http://alertmanager:9093/api/v2/alerts \
  | jq -r '.[] | select(.status.state == "active") | .labels.alertname' \
  | sort -u
echo

# 8. Request rate
echo "8. Request Rate (last minute)"
curl -s http://prometheus:9090/api/v1/query \
  -d 'query=rate(mcp_requests_total[1m])' \
  | jq -r '.data.result[] | "\(.metric.endpoint): \(.value[1]) req/s"'
echo

# 9. Error rate
echo "9. Error Rate (last 5 minutes)"
curl -s http://prometheus:9090/api/v1/query \
  -d 'query=rate(mcp_requests_total{status=~"5.."}[5m])' \
  | jq -r '.data.result[] | "\(.metric.endpoint): \(.value[1]) errors/s"'
echo

echo "=== Health Check Complete ==="
```

### Network Diagnostics

```bash
# network_diagnostics.sh
#!/bin/bash

echo "=== Network Diagnostics ==="
echo

# 1. DNS resolution
echo "1. DNS Resolution"
for host in api.example.com auth.example.com db.example.com; do
  if nslookup $host > /dev/null 2>&1; then
    ip=$(nslookup $host | awk '/^Address: / { print $2 }' | tail -1)
    echo "✅ $host -> $ip"
  else
    echo "❌ $host - DNS resolution failed"
  fi
done
echo

# 2. Port connectivity
echo "2. Port Connectivity"
for endpoint in api.example.com:443 db.example.com:5432 redis.example.com:6379; do
  if timeout 3 bash -c "cat < /dev/null > /dev/tcp/${endpoint/:/ }" 2>/dev/null; then
    echo "✅ $endpoint - reachable"
  else
    echo "❌ $endpoint - unreachable"
  fi
done
echo

# 3. TLS certificate check
echo "3. TLS Certificate"
echo | openssl s_client -servername api.example.com -connect api.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates 2>/dev/null \
  | sed 's/^/  /'
echo

# 4. Latency test
echo "4. Latency Test"
for i in {1..5}; do
  time=$(curl -o /dev/null -s -w '%{time_total}\n' https://api.example.com/health)
  echo "  Attempt $i: ${time}s"
done
echo

# 5. Trace route
echo "5. Network Path"
traceroute -m 10 api.example.com 2>&1 | head -10
echo
```

### Dependency Health Check

```bash
# check_dependencies.sh
#!/bin/bash

echo "=== Dependency Health Check ==="
echo

# PostgreSQL
echo "PostgreSQL:"
psql $DATABASE_URL -c "
SELECT
    version() as version,
    current_database() as database,
    pg_size_pretty(pg_database_size(current_database())) as size,
    (SELECT count(*) FROM pg_stat_activity) as connections
" 2>&1 | grep -v "^(" | grep -v "^-" | sed 's/^/  /'
echo

# Redis
echo "Redis:"
redis-cli INFO server | grep -E "redis_version|os|uptime_in_days" | sed 's/^/  /'
echo

# Message Queue (RabbitMQ)
echo "RabbitMQ:"
curl -s -u guest:guest http://rabbitmq:15672/api/overview \
  | jq -r '"\(.rabbitmq_version) | \(.queue_totals.messages) messages"' \
  | sed 's/^/  /'
echo

# Object Storage (S3)
echo "S3 Bucket:"
aws s3 ls s3://mcp-storage --summarize 2>&1 \
  | grep -E "Total" \
  | sed 's/^/  /'
echo
```

## Log Analysis Patterns

### Structured Log Queries

```bash
# 1. Authentication failures by user
kubectl logs -n production -l app=mcp-server --since=1h \
  | jq -r 'select(.event == "authentication_failed") | [.timestamp, .user_id, .reason] | @tsv' \
  | sort | uniq -c | sort -rn

# 2. Slow requests (>1s)
kubectl logs -n production -l app=mcp-server --since=1h \
  | jq -r 'select(.duration_ms > 1000) | [.endpoint, .duration_ms, .timestamp] | @tsv' \
  | sort -t$'\t' -k2 -rn \
  | head -20

# 3. Error rate by endpoint
kubectl logs -n production -l app=mcp-server --since=1h \
  | jq -r 'select(.level == "error") | .endpoint' \
  | sort | uniq -c | sort -rn

# 4. Database query errors
kubectl logs -n production -l app=mcp-server --since=1h \
  | jq -r 'select(.error_type == "database_error") | [.timestamp, .query, .error_message] | @tsv'

# 5. Rate limit violations
kubectl logs -n production -l app=mcp-server --since=1h \
  | jq -r 'select(.event == "rate_limit_exceeded") | [.user_id, .endpoint, .timestamp] | @tsv' \
  | awk '{print $1}' | sort | uniq -c | sort -rn
```

### Log Correlation

```python
# log_correlator.py
import json
from collections import defaultdict
from datetime import datetime

def correlate_logs_by_request_id(log_file: str):
    """Correlate log entries by request ID."""
    requests = defaultdict(list)
    
    with open(log_file) as f:
        for line in f:
            try:
                log = json.loads(line)
                request_id = log.get('request_id')
                if request_id:
                    requests[request_id].append(log)
            except json.JSONDecodeError:
                continue
    
    # Analyze requests
    for request_id, logs in requests.items():
        logs.sort(key=lambda x: x['timestamp'])
        
        start_time = datetime.fromisoformat(logs[0]['timestamp'])
        end_time = datetime.fromisoformat(logs[-1]['timestamp'])
        duration = (end_time - start_time).total_seconds()
        
        # Find errors
        errors = [log for log in logs if log.get('level') == 'error']
        
        if errors or duration > 1.0:
            print(f"\n{'='*80}")
            print(f"Request ID: {request_id}")
            print(f"Duration: {duration:.3f}s")
            print(f"Endpoint: {logs[0].get('endpoint')}")
            print(f"User: {logs[0].get('user_id')}")
            print(f"Entries: {len(logs)}")
            
            if errors:
                print(f"\n❌ Errors:")
                for error in errors:
                    print(f"  - {error.get('message')}")
            
            print(f"\nTimeline:")
            for log in logs:
                timestamp = datetime.fromisoformat(log['timestamp'])
                elapsed = (timestamp - start_time).total_seconds()
                print(f"  +{elapsed:.3f}s: {log.get('message', log.get('event'))}")

# Usage
correlate_logs_by_request_id('mcp-server.log')
```

### Anomaly Detection

```python
# anomaly_detection.py
import re
from collections import Counter
from datetime import datetime, timedelta

def detect_log_anomalies(log_file: str, baseline_hours: int = 24):
    """Detect anomalies in log patterns."""
    
    # Read logs
    logs = []
    with open(log_file) as f:
        for line in f:
            try:
                log = json.loads(line)
                logs.append(log)
            except json.JSONDecodeError:
                continue
    
    # Split into baseline and recent
    cutoff = datetime.now() - timedelta(hours=1)
    baseline_cutoff = datetime.now() - timedelta(hours=baseline_hours)
    
    baseline_logs = [
        log for log in logs
        if baseline_cutoff <= datetime.fromisoformat(log['timestamp']) < cutoff
    ]
    recent_logs = [
        log for log in logs
        if datetime.fromisoformat(log['timestamp']) >= cutoff
    ]
    
    # Analyze error patterns
    baseline_errors = Counter(log['error_type'] for log in baseline_logs if 'error_type' in log)
    recent_errors = Counter(log['error_type'] for log in recent_logs if 'error_type' in log)
    
    print("=== Error Anomalies ===")
    for error_type, recent_count in recent_errors.items():
        baseline_count = baseline_errors.get(error_type, 0)
        baseline_rate = baseline_count / len(baseline_logs) if baseline_logs else 0
        recent_rate = recent_count / len(recent_logs) if recent_logs else 0
        
        if recent_rate > baseline_rate * 2:  # 2x increase
            print(f"⚠️ {error_type}")
            print(f"  Baseline: {baseline_rate:.4f} ({baseline_count} occurrences)")
            print(f"  Recent: {recent_rate:.4f} ({recent_count} occurrences)")
            print(f"  Increase: {recent_rate / baseline_rate if baseline_rate else float('inf'):.1f}x")
    
    # Analyze new errors
    new_errors = set(recent_errors.keys()) - set(baseline_errors.keys())
    if new_errors:
        print("\n=== New Error Types ===")
        for error_type in new_errors:
            print(f"🆕 {error_type}: {recent_errors[error_type]} occurrences")

# Usage
detect_log_anomalies('mcp-server.log')
```

## Performance Profiling

### CPU Profiling

```bash
# 1. Install profiling tools
pip install py-spy

# 2. Profile running process
sudo py-spy record -o cpu_profile.svg --pid $(pgrep -f "mcp-server")

# 3. Top functions (live view)
sudo py-spy top --pid $(pgrep -f "mcp-server")

# 4. Flame graph generation
sudo py-spy record -o flamegraph.svg --format speedscope --pid $(pgrep -f "mcp-server")
```

#### Understanding Flame Graphs

Flame graphs visualize CPU time spent in different code paths. Here's how to interpret them:

**Flame Graph Anatomy:**

```text
┌─────────────────────────────────────────────────────────────┐
│                     main() [100%]                            │  ← Root (bottom)
├─────────────────────────────────────────────────────────────┤
│  run_server() [98%]                    idle() [2%]           │
├─────────────────────────────────────────────────────────────┤
│  handle_request() [95%]                                      │
├─────────────────────────────────────────────────────────────┤
│  process_tool() [70%]        validate() [15%]  log() [10%]  │
├─────────────────────────────────────────────────────────────┤
│  db_query() [60%]  parse()[10%]                             │  ← Hot paths (wider)
├─────────────────────────────────────────────────────────────┤
│  execute_sql() [60%]                                         │
└─────────────────────────────────────────────────────────────┘
  ↑ Stack depth (bottom = root, top = leaf functions)
  ↑ Width = CPU time percentage
```

**Key Patterns to Look For:**

**1. Wide Plateaus (Hot Paths)** - High CPU consumption:

```text
Example: Database Query Hot Path
┌────────────────────────────────────────────┐
│         handle_request() [100%]            │
├────────────────────────────────────────────┤
│  ████████ db_query() [80%] ████████        │  ← PROBLEM: 80% time in DB
├────────────────────────────────────────────┤
│  ████ execute_sql() [75%] ████             │
└────────────────────────────────────────────┘

Solution:
- Add database indexes
- Use connection pooling
- Implement query caching
- Reduce N+1 queries
```

**2. Tall Stacks (Deep Call Chains)** - Excessive function calls:

```text
Example: Recursive Processing
┌──────────────┐
│  process() [100%]   │
├──────────────┤
│  validate()  │
├──────────────┤
│  check()     │
├──────────────┤
│  verify()    │  ← PROBLEM: Deep nesting (8+ levels)
├──────────────┤
│  inspect()   │
├──────────────┤
│  analyze()   │
├──────────────┤
│  examine()   │
└──────────────┘

Solution:
- Flatten call hierarchy
- Cache validation results
- Combine multiple validation steps
- Use iterative instead of recursive approach
```

**3. Repeated Patterns (Inefficient Loops)** - Same functions called repeatedly:

```text
Example: N+1 Query Problem
┌────────────────────────────────────────────┐
│         process_users() [100%]             │
├────────────────────────────────────────────┤
│ get_user() get_user() get_user() get_user()│  ← PROBLEM: Repeated calls
│   [5%]       [5%]       [5%]       [5%]    │
└────────────────────────────────────────────┘

Solution:
- Batch database queries
- Use JOINs instead of multiple queries
- Implement eager loading
- Add result caching
```

**4. Blocking I/O (Synchronous Calls)** - Functions waiting for I/O:

```text
Example: Synchronous HTTP Calls
┌────────────────────────────────────────────┐
│         handle_tool() [100%]               │
├────────────────────────────────────────────┤
│  ████ http_request() [60%] ████            │  ← PROBLEM: Blocking wait
│  (waiting for response...)                 │
└────────────────────────────────────────────┘

Solution:
- Use async/await for I/O
- Implement connection pooling
- Add request timeouts
- Use circuit breakers
```

**5. JSON Parsing Overhead** - Serialization bottleneck:

```text
Example: Heavy JSON Processing
┌────────────────────────────────────────────┐
│         handle_response() [100%]           │
├────────────────────────────────────────────┤
│  ████ json.dumps() [40%] ████              │  ← PROBLEM: Slow serialization
├────────────────────────────────────────────┤
│  dict_to_json() [38%]                      │
└────────────────────────────────────────────┘

Solution:
- Use orjson or ujson (faster alternatives)
- Reduce response payload size
- Cache serialized responses
- Stream large responses
```

**6. Regex Compilation** - Repeated pattern compilation:

```text
Example: Uncompiled Regular Expressions
┌────────────────────────────────────────────┐
│         validate_input() [100%]            │
├────────────────────────────────────────────┤
│ re.match() re.match() re.match() re.match()│  ← PROBLEM: Recompiling regex
│   [10%]      [10%]      [10%]      [10%]   │
└────────────────────────────────────────────┘

Solution:
- Precompile regex patterns
- Use re.compile() at module level
- Cache compiled patterns
```

**Real-World Example: Database Query Optimization**

**Before (Slow - 800ms P99):**

```text
Flame Graph:
┌─────────────────────────────────────────────────────┐
│              handle_list_issues() [100%]            │
├─────────────────────────────────────────────────────┤
│  ████████████ get_issues() [85%] ████████████       │
├─────────────────────────────────────────────────────┤
│  ████████ execute_query() [80%] ████████            │
├─────────────────────────────────────────────────────┤
│  ████ wait_for_result() [75%] ████                  │  ← Blocking on DB
└─────────────────────────────────────────────────────┘

Code:
async def get_issues():
    issues = await db.query("SELECT * FROM issues")
    for issue in issues:
        issue.author = await db.query(f"SELECT * FROM users WHERE id={issue.user_id}")  # N+1!
        issue.comments = await db.query(f"SELECT * FROM comments WHERE issue_id={issue.id}")  # N+1!
    return issues
```

**After (Fast - 120ms P99):**

```text
Flame Graph:
┌─────────────────────────────────────────────────────┐
│              handle_list_issues() [100%]            │
├─────────────────────────────────────────────────────┤
│  ██ get_issues() [20%] ██   format() [10%]          │  ← Much faster!
├─────────────────────────────────────────────────────┤
│  execute_query() [18%]                              │
└─────────────────────────────────────────────────────┘

Code:
async def get_issues():
    # Single query with JOINs
    query = """
        SELECT 
            i.*,
            u.name as author_name,
            COUNT(c.id) as comment_count
        FROM issues i
        LEFT JOIN users u ON i.user_id = u.id
        LEFT JOIN comments c ON i.id = c.issue_id
        GROUP BY i.id, u.name
    """
    return await db.query(query)
```

**Profiling Workflow:**

```bash
# 1. Generate flame graph
sudo py-spy record -o profile.svg --duration 60 --pid $(pgrep -f "mcp-server")

# 2. Open in browser
open profile.svg

# 3. Identify hot paths (widest sections)
# 4. Click to zoom into specific functions
# 5. Note cumulative time percentages

# 6. For interactive analysis, use speedscope format
sudo py-spy record -o profile.json --format speedscope --duration 60 --pid $(pgrep -f "mcp-server")
# Upload to https://www.speedscope.app/
```

**Optimization Checklist:**

- ✅ Wide plateaus → Add caching, optimize algorithm
- ✅ Tall stacks → Flatten call hierarchy, reduce indirection
- ✅ Repeated patterns → Batch operations, use loops efficiently
- ✅ Blocking I/O → Convert to async, add timeouts
- ✅ JSON overhead → Use faster parsers (orjson)
- ✅ Regex compilation → Precompile patterns
- ✅ Database queries → Add indexes, use JOINs, batch queries

### Application Profiling

```python
# profiler.py
import cProfile
import pstats
import io
from fastapi import Request

class ProfilerMiddleware:
    """Middleware to profile request handlers."""
    
    def __init__(self, app, enabled: bool = False):
        self.app = app
        self.enabled = enabled
    
    async def __call__(self, scope, receive, send):
        if not self.enabled or scope["type"] != "http":
            return await self.app(scope, receive, send)
        
        profiler = cProfile.Profile()
        profiler.enable()
        
        try:
            await self.app(scope, receive, send)
        finally:
            profiler.disable()
            
            # Print stats
            s = io.StringIO()
            stats = pstats.Stats(profiler, stream=s)
            stats.sort_stats('cumulative')
            stats.print_stats(20)
            
            print(f"\nProfile for {scope['path']}:")
            print(s.getvalue())

# Add to FastAPI app
from fastapi import FastAPI
app = FastAPI()
app.add_middleware(ProfilerMiddleware, enabled=True)
```

## Memory Profiling

### Heap Analysis

```python
# memory_analysis.py
import tracemalloc
import gc

def analyze_memory_usage():
    """Detailed memory usage analysis."""
    
    # Force garbage collection
    gc.collect()
    
    # Start tracing
    tracemalloc.start()
    
    # Take snapshot
    snapshot = tracemalloc.take_snapshot()
    
    print("=== Top Memory Allocations ===")
    top_stats = snapshot.statistics('lineno')
    for index, stat in enumerate(top_stats[:10], 1):
        frame = stat.traceback[0]
        print(f"\n#{index}")
        print(f"  File: {frame.filename}:{frame.lineno}")
        print(f"  Size: {stat.size / 1024 / 1024:.2f} MB")
        print(f"  Count: {stat.count}")
    
    # Object counts by type
    print("\n=== Object Counts by Type ===")
    import sys
    from collections import Counter
    
    type_counts = Counter()
    for obj in gc.get_objects():
        type_counts[type(obj).__name__] += 1
    
    for obj_type, count in type_counts.most_common(20):
        print(f"  {obj_type}: {count}")

# Usage
analyze_memory_usage()
```

### Memory Leak Detection

```python
# leak_detector.py
import objgraph
import gc

def find_memory_leaks():
    """Find potential memory leaks."""
    
    # Take initial snapshot
    gc.collect()
    objgraph.show_growth(limit=10)
    
    print("\n=== Execute suspicious code ===")
    # Run your code here
    for _ in range(1000):
        await process_request()
    
    # Take second snapshot
    gc.collect()
    print("\n=== Growth Analysis ===")
    objgraph.show_growth(limit=10)
    
    # Find backreferences for leaked objects
    print("\n=== Backreferences for leaked objects ===")
    objgraph.show_backrefs(
        objgraph.by_type('Assignment'),
        max_depth=5,
        filename='backrefs.png'
    )

# Usage
await find_memory_leaks()
```

## Summary

This troubleshooting guide provides systematic approaches to common MCP server issues:

- **Common Issues**: Authentication failures, rate limiting, performance degradation, memory leaks, database connections
- **Diagnostic Commands**: Health checks, network diagnostics, dependency verification
- **Log Analysis**: Structured queries, correlation, anomaly detection
- **Performance Profiling**: CPU profiling with py-spy, application profiling, flame graphs
- **Memory Profiling**: Heap analysis, leak detection with tracemalloc and objgraph

---

**Next**: Review [Operational Runbooks](08-operational-runbooks.md) for incident response procedures.
