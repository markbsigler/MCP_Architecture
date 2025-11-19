# Operational Runbooks

**Version:** 1.0.0  
**Last Updated:** November 18, 2025  
**Status:** Draft

## Introduction

Operational runbooks provide standardized procedures for troubleshooting, incident response, performance tuning, and routine maintenance of MCP servers. These runbooks ensure consistent responses to common operational scenarios.

## Troubleshooting

### Service Not Responding

**Symptoms:**

- Health check endpoints returning 503 or timing out
- No response from service
- Kubernetes pods in CrashLoopBackOff

**Diagnosis Steps:**

```bash
# 1. Check pod status
kubectl get pods -n mcp -l app=mcp-server

# 2. Check pod logs
kubectl logs -n mcp deployment/mcp-server --tail=100

# 3. Check events
kubectl get events -n mcp --sort-by='.lastTimestamp'

# 4. Check resource usage
kubectl top pods -n mcp -l app=mcp-server

# 5. Describe problematic pod
kubectl describe pod -n mcp <pod-name>
```

**Common Causes & Resolutions:**

| Cause | Resolution |
|-------|------------|
| Database connection failure | Check DB credentials, connectivity, and connection limits |
| Out of memory | Increase memory limits or optimize memory usage |
| Configuration error | Validate ConfigMap and Secret values |
| Startup timeout | Increase startupProbe failureThreshold |
| Port conflict | Verify port configuration and service mappings |

**Resolution Script:**

```bash
#!/bin/bash
# scripts/diagnose_service.sh

NAMESPACE="mcp"
APP="mcp-server"

echo "=== Pod Status ==="
kubectl get pods -n $NAMESPACE -l app=$APP

echo -e "\n=== Recent Events ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20

echo -e "\n=== Pod Logs (last 50 lines) ==="
kubectl logs -n $NAMESPACE deployment/$APP --tail=50

echo -e "\n=== Resource Usage ==="
kubectl top pods -n $NAMESPACE -l app=$APP

echo -e "\n=== Endpoint Status ==="
kubectl get endpoints -n $NAMESPACE $APP
```

### High Error Rate

**Symptoms:**

- Elevated 500 errors in logs
- Increased error metrics
- Alerts firing for error rate

**Diagnosis:**

```bash
# 1. Check error logs
kubectl logs -n mcp deployment/mcp-server \
  | grep '"level":"error"' \
  | tail -100

# 2. Query Prometheus for error rate
curl 'http://prometheus:9090/api/v1/query' \
  --data-urlencode 'query=rate(mcp_errors_total[5m])'

# 3. Check database connectivity
kubectl exec -n mcp deployment/mcp-server -- \
  python -c "import asyncpg; print('DB check...')"

# 4. Check external service health
curl https://api.external.com/health
```

**Common Error Patterns:**

```python
# scripts/analyze_errors.py
"""Analyze error patterns in logs."""

import json
from collections import Counter
from datetime import datetime, timedelta

def analyze_error_logs(log_file: str):
    """Analyze error logs and identify patterns."""
    
    errors = []
    error_types = Counter()
    error_tools = Counter()
    
    with open(log_file) as f:
        for line in f:
            try:
                log = json.loads(line)
                if log.get('level') == 'error':
                    errors.append(log)
                    error_types[log.get('error_type', 'unknown')] += 1
                    error_tools[log.get('tool', 'unknown')] += 1
            except json.JSONDecodeError:
                continue
    
    print(f"Total errors: {len(errors)}")
    print(f"\nTop error types:")
    for error_type, count in error_types.most_common(10):
        print(f"  {error_type}: {count}")
    
    print(f"\nTop affected tools:")
    for tool, count in error_tools.most_common(10):
        print(f"  {tool}: {count}")
    
    # Check for error spikes
    recent_errors = [
        e for e in errors
        if datetime.fromisoformat(e['timestamp']) > 
           datetime.now() - timedelta(minutes=5)
    ]
    
    if len(recent_errors) > len(errors) * 0.5:
        print(f"\n⚠️  ALERT: {len(recent_errors)} errors in last 5 minutes!")

if __name__ == "__main__":
    analyze_error_logs("/var/log/mcp-server/app.log")
```

**Resolution:**

1. **Database Issues:**

   ```bash
   # Check database connections
   kubectl exec -n mcp postgres-0 -- \
     psql -U mcp_user -c "SELECT count(*) FROM pg_stat_activity;"
   
   # Kill idle connections
   kubectl exec -n mcp postgres-0 -- \
     psql -U mcp_user -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < now() - interval '10 minutes';"
   ```

2. **External Service Failures:**

   ```bash
   # Check circuit breaker status
   kubectl exec -n mcp deployment/mcp-server -- \
     curl localhost:8000/circuit-breakers
   
   # Reset circuit breaker if needed
   kubectl exec -n mcp deployment/mcp-server -- \
     curl -X POST localhost:8000/circuit-breakers/external-api/reset
   ```

3. **Application Restart:**

   ```bash
   # Rolling restart
   kubectl rollout restart deployment/mcp-server -n mcp
   kubectl rollout status deployment/mcp-server -n mcp
   ```

### High Latency

**Symptoms:**

- P99 latency above 1000ms
- Slow response times
- Timeout errors

**Diagnosis:**

```bash
# 1. Check current latency metrics
curl 'http://prometheus:9090/api/v1/query' \
  --data-urlencode 'query=histogram_quantile(0.99, rate(mcp_request_duration_bucket[5m]))'

# 2. Check database query performance
kubectl exec -n mcp postgres-0 -- \
  psql -U mcp_user -c "SELECT query, calls, mean_exec_time, max_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"

# 3. Check cache hit rate
kubectl exec -n mcp deployment/mcp-server -- \
  python -c "from mcp_server.services.cache import get_stats; print(get_stats())"

# 4. Profile application
kubectl exec -n mcp deployment/mcp-server -- \
  py-spy top --pid 1
```

**Performance Analysis:**

```python
# scripts/analyze_performance.py
"""Analyze performance bottlenecks."""

import asyncio
import httpx
from statistics import mean, median, stdev

async def benchmark_endpoint(url: str, n: int = 100):
    """Benchmark endpoint performance."""
    
    async with httpx.AsyncClient() as client:
        latencies = []
        
        for _ in range(n):
            start = asyncio.get_event_loop().time()
            response = await client.get(url)
            elapsed = (asyncio.get_event_loop().time() - start) * 1000
            latencies.append(elapsed)
        
        print(f"URL: {url}")
        print(f"Requests: {n}")
        print(f"Mean: {mean(latencies):.2f}ms")
        print(f"Median: {median(latencies):.2f}ms")
        print(f"Std Dev: {stdev(latencies):.2f}ms")
        print(f"P95: {sorted(latencies)[int(n * 0.95)]:.2f}ms")
        print(f"P99: {sorted(latencies)[int(n * 0.99)]:.2f}ms")
        print(f"Max: {max(latencies):.2f}ms")

if __name__ == "__main__":
    asyncio.run(benchmark_endpoint("http://localhost:8000/tools/list_assignments"))
```

**Resolution:**

1. **Database Optimization:**

   ```sql
   -- Add missing indexes
   CREATE INDEX CONCURRENTLY idx_assignments_assignee ON assignments(assignee);
   CREATE INDEX CONCURRENTLY idx_assignments_created_at ON assignments(created_at DESC);
   
   -- Update statistics
   ANALYZE assignments;
   
   -- Check for missing indexes
   SELECT schemaname, tablename, attname, n_distinct, correlation
   FROM pg_stats
   WHERE schemaname = 'public'
   AND tablename = 'assignments'
   ORDER BY abs(correlation) DESC;
   ```

2. **Cache Tuning:**

   ```python
   # Increase cache TTL for frequently accessed data
   cache.set("assignments:user:123", data, ttl=3600)
   
   # Pre-warm cache
   await cache.warm_cache(["assignments:active", "releases:latest"])
   ```

3. **Connection Pooling:**

   ```python
   # Increase connection pool size
   engine = create_async_engine(
       database_url,
       pool_size=20,  # Increase from 10
       max_overflow=40  # Increase from 20
   )
   ```

### Memory Leak

**Symptoms:**

- Gradually increasing memory usage
- OOMKilled pods
- Slow memory growth over time

**Diagnosis:**

```bash
# 1. Monitor memory over time
kubectl top pods -n mcp -l app=mcp-server --containers

# 2. Get memory profile
kubectl exec -n mcp deployment/mcp-server -- \
  python -m memory_profiler scripts/profile_memory.py

# 3. Check for object leaks
kubectl exec -n mcp deployment/mcp-server -- \
  python -c "import gc; print(f'Objects: {len(gc.get_objects())}')"
```

**Memory Profiling:**

```python
# scripts/profile_memory.py
"""Profile memory usage."""

import tracemalloc
import asyncio
from mcp_server.tools import create_assignment

async def test_memory_leak():
    """Test for memory leaks in tool execution."""
    
    tracemalloc.start()
    
    # Baseline
    snapshot1 = tracemalloc.take_snapshot()
    
    # Execute tool 1000 times
    for i in range(1000):
        await create_assignment(
            title=f"Test {i}",
            assignee="test@example.com"
        )
    
    # Take snapshot
    snapshot2 = tracemalloc.take_snapshot()
    
    # Compare
    top_stats = snapshot2.compare_to(snapshot1, 'lineno')
    
    print("Top 10 memory allocations:")
    for stat in top_stats[:10]:
        print(stat)

if __name__ == "__main__":
    asyncio.run(test_memory_leak())
```

**Resolution:**

1. **Identify Leak Source:**

   ```python
   # Add explicit cleanup
   async def create_assignment(title: str, assignee: str):
       try:
           result = await backend.create_assignment(title, assignee)
           return result
       finally:
           # Explicit cleanup
           await backend.close_connections()
           gc.collect()
   ```

2. **Fix Connection Leaks:**

   ```python
   # Use context managers
   async with httpx.AsyncClient() as client:
       response = await client.get(url)
   
   # Close sessions properly
   try:
       session = aiohttp.ClientSession()
       response = await session.get(url)
   finally:
       await session.close()
   ```

3. **Restart Pods:**

   ```bash
   kubectl delete pod -n mcp -l app=mcp-server
   ```

## Incident Response

### Incident Response Process

```text
1. DETECT
   ├─ Alert fires
   ├─ User reports issue
   └─ Monitoring detects anomaly

2. TRIAGE
   ├─ Assess severity
   ├─ Page on-call engineer
   └─ Create incident ticket

3. INVESTIGATE
   ├─ Gather logs & metrics
   ├─ Identify root cause
   └─ Document findings

4. MITIGATE
   ├─ Apply temporary fix
   ├─ Restore service
   └─ Verify resolution

5. RESOLVE
   ├─ Apply permanent fix
   ├─ Verify fix
   └─ Close incident

6. POST-MORTEM
   ├─ Document timeline
   ├─ Identify improvements
   └─ Create action items
```

### Severity Levels

| Severity | Description | Response Time | Examples |
|----------|-------------|---------------|----------|
| **SEV1 - Critical** | Service down, data loss | 15 minutes | Complete outage, database corruption |
| **SEV2 - High** | Major functionality broken | 1 hour | Authentication broken, high error rate |
| **SEV3 - Medium** | Minor functionality impaired | 4 hours | Single tool failing, degraded performance |
| **SEV4 - Low** | Cosmetic issues | 1 business day | Typos, non-critical warnings |

### Incident Response Checklist

```markdown
# Incident Response Checklist

## Detection
- [ ] Alert received
- [ ] Incident ticket created
- [ ] Severity assigned
- [ ] On-call engineer paged (SEV1/SEV2)

## Triage
- [ ] Service status verified
- [ ] Scope of impact assessed
- [ ] Affected users identified
- [ ] Communication channels established

## Investigation
- [ ] Logs collected
- [ ] Metrics reviewed
- [ ] Recent changes identified
- [ ] Root cause hypothesis formed

## Mitigation
- [ ] Rollback initiated (if applicable)
- [ ] Temporary fix applied
- [ ] Service restored
- [ ] Users notified

## Resolution
- [ ] Permanent fix deployed
- [ ] Monitoring verified
- [ ] Documentation updated
- [ ] Incident closed

## Post-Mortem
- [ ] Timeline documented
- [ ] Root cause analysis completed
- [ ] Action items created
- [ ] Post-mortem published
```

### Rollback Procedure

```bash
#!/bin/bash
# scripts/rollback.sh

set -e

NAMESPACE="mcp"
DEPLOYMENT="mcp-server"
PREVIOUS_VERSION="${1:-}"

if [ -z "$PREVIOUS_VERSION" ]; then
    echo "Usage: $0 <previous-version>"
    echo "Available versions:"
    kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE
    exit 1
fi

echo "Rolling back $DEPLOYMENT to revision $PREVIOUS_VERSION..."

# Rollback
kubectl rollout undo deployment/$DEPLOYMENT \
  --to-revision=$PREVIOUS_VERSION \
  -n $NAMESPACE

# Wait for rollout
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE

# Verify health
echo "Verifying health..."
sleep 10
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT

# Run smoke tests
echo "Running smoke tests..."
python scripts/smoke_tests.py

echo "Rollback complete!"
```

## Performance Tuning

### Database Tuning

```sql
-- Connection pooling
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '4GB';
ALTER SYSTEM SET effective_cache_size = '12GB';
ALTER SYSTEM SET maintenance_work_mem = '1GB';
ALTER SYSTEM SET work_mem = '16MB';

-- Query performance
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- Autovacuum
ALTER SYSTEM SET autovacuum_max_workers = 4;
ALTER SYSTEM SET autovacuum_vacuum_scale_factor = 0.1;

-- Reload configuration
SELECT pg_reload_conf();

-- Monitor query performance
SELECT query, calls, total_exec_time, mean_exec_time, max_exec_time
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Application Tuning

```python
# config/production.yaml
database:
  pool_size: 20
  max_overflow: 40
  pool_timeout: 30
  pool_recycle: 3600

cache:
  max_connections: 50
  connection_timeout: 5
  ttl_seconds: 3600

rate_limit:
  requests_per_minute: 100
  burst_size: 20

# Use connection pooling
from sqlalchemy.pool import QueuePool

engine = create_async_engine(
    database_url,
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=True,
    pool_recycle=3600
)
```

### Resource Limits

```yaml
# k8s/deployment.yaml
resources:
  requests:
    cpu: 1000m      # Guaranteed CPU
    memory: 1Gi     # Guaranteed memory
  limits:
    cpu: 2000m      # Max CPU (2 cores)
    memory: 2Gi     # Max memory (hard limit)
```

## Routine Maintenance

### Daily Tasks

```bash
#!/bin/bash
# scripts/daily_maintenance.sh

# Check service health
echo "=== Service Health ==="
kubectl get pods -n mcp -l app=mcp-server

# Check resource usage
echo -e "\n=== Resource Usage ==="
kubectl top pods -n mcp -l app=mcp-server

# Check error logs
echo -e "\n=== Recent Errors ==="
kubectl logs -n mcp deployment/mcp-server --since=24h \
  | grep '"level":"error"' \
  | wc -l

# Database health
echo -e "\n=== Database Health ==="
kubectl exec -n mcp postgres-0 -- \
  psql -U mcp_user -c "SELECT pg_database_size('mcp_prod');"
```

### Weekly Tasks

```bash
#!/bin/bash
# scripts/weekly_maintenance.sh

# Vacuum database
kubectl exec -n mcp postgres-0 -- \
  psql -U mcp_user -c "VACUUM ANALYZE;"

# Update database statistics
kubectl exec -n mcp postgres-0 -- \
  psql -U mcp_user -c "ANALYZE;"

# Clear old logs
kubectl logs -n mcp deployment/mcp-server --since=7d > /dev/null

# Review metrics
echo "Review weekly metrics at: http://grafana.example.com"
```

### Monthly Tasks

- Review and update dependencies
- Analyze performance trends
- Review and update documentation
- Conduct security audit
- Review and update monitoring/alerts
- Backup and test restore procedures

## Disaster Recovery

### Backup Procedures

```bash
#!/bin/bash
# scripts/backup.sh

BACKUP_DIR="/backups/mcp-server"
DATE=$(date +%Y%m%d-%H%M%S)

# Database backup
kubectl exec -n mcp postgres-0 -- \
  pg_dump -U mcp_user mcp_prod | \
  gzip > $BACKUP_DIR/db-$DATE.sql.gz

# Configuration backup
kubectl get configmap -n mcp mcp-config -o yaml > $BACKUP_DIR/config-$DATE.yaml
kubectl get secret -n mcp mcp-secrets -o yaml > $BACKUP_DIR/secrets-$DATE.yaml

# Upload to S3
aws s3 cp $BACKUP_DIR/ s3://mcp-backups/ --recursive

echo "Backup complete: $DATE"
```

### Restore Procedures

```bash
#!/bin/bash
# scripts/restore.sh

BACKUP_FILE="${1:-}"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file>"
    exit 1
fi

# Stop application
kubectl scale deployment/mcp-server --replicas=0 -n mcp

# Restore database
gunzip < $BACKUP_FILE | \
  kubectl exec -i -n mcp postgres-0 -- \
  psql -U mcp_user mcp_prod

# Restart application
kubectl scale deployment/mcp-server --replicas=3 -n mcp

echo "Restore complete!"
```

## Summary

Operational excellence requires:

- **Troubleshooting**: Systematic diagnosis and resolution procedures
- **Incident Response**: Structured process with clear severity levels
- **Performance Tuning**: Database and application optimization
- **Routine Maintenance**: Daily, weekly, and monthly tasks
- **Disaster Recovery**: Backup and restore procedures

---

**Next**: Review [Integration Patterns](09-integration-patterns.md) for external service integrations.
