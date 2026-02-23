# Cost Optimization Guide

**Navigation**: [Home](../README.md) > Advanced Topics > Cost Optimization  
**Related**: [← Previous: Troubleshooting](11-troubleshooting.md) | [Next: Metrics & KPIs →](13-metrics-kpis.md) | [Performance Benchmarks](14-performance-benchmarks.md)

**Version:** 1.4.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Quick Links

- [Resource Sizing](#resource-sizing-and-right-sizing)
- [Caching Strategies](#caching-strategies-for-cost-reduction)
- [Query Optimization](#database-query-optimization)
- [API Call Batching](#api-call-batching)
- [Cold Start Optimization](#cold-start-optimization)
- [Auto-Scaling Policies](#auto-scaling-policies)
- [Summary](#summary)

## Introduction

This guide provides comprehensive strategies for optimizing costs in MCP server deployments while maintaining performance and reliability. Cost optimization is not a one-time activity but an ongoing process of monitoring, analyzing, and adjusting resource usage.

## Cost Visibility and Tracking

### Cost Monitoring Dashboard

```python
# cost_tracking/cost_monitor.py
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Dict, List
import boto3

@dataclass
class CostBreakdown:
    """Cost breakdown by service."""
    compute: float
    database: float
    cache: float
    storage: float
    network: float
    other: float
    total: float
    period_days: int

class CostMonitor:
    """Track and analyze infrastructure costs."""
    
    def __init__(self, aws_profile: str = "default"):
        self.ce_client = boto3.client('ce', profile_name=aws_profile)
    
    async def get_cost_breakdown(self, days: int = 30) -> CostBreakdown:
        """Get cost breakdown for specified period."""
        
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days)
        
        response = self.ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.isoformat(),
                'End': end_date.isoformat()
            },
            Granularity='MONTHLY',
            Metrics=['UnblendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'SERVICE'}
            ]
        )
        
        # Parse costs by service
        costs = {
            'compute': 0.0,
            'database': 0.0,
            'cache': 0.0,
            'storage': 0.0,
            'network': 0.0,
            'other': 0.0
        }
        
        for result in response['ResultsByTime']:
            for group in result['Groups']:
                service = group['Keys'][0]
                amount = float(group['Metrics']['UnblendedCost']['Amount'])
                
                # Categorize costs
                if 'EC2' in service or 'ECS' in service or 'Lambda' in service:
                    costs['compute'] += amount
                elif 'RDS' in service or 'DynamoDB' in service:
                    costs['database'] += amount
                elif 'ElastiCache' in service:
                    costs['cache'] += amount
                elif 'S3' in service or 'EBS' in service:
                    costs['storage'] += amount
                elif 'DataTransfer' in service or 'CloudFront' in service:
                    costs['network'] += amount
                else:
                    costs['other'] += amount
        
        total = sum(costs.values())
        
        return CostBreakdown(
            compute=costs['compute'],
            database=costs['database'],
            cache=costs['cache'],
            storage=costs['storage'],
            network=costs['network'],
            other=costs['other'],
            total=total,
            period_days=days
        )
    
    async def calculate_cost_per_request(self, days: int = 30) -> float:
        """Calculate cost per API request."""
        
        costs = await self.get_cost_breakdown(days)
        
        # Get total requests from metrics
        query = f"""
            SELECT SUM(value) as total_requests
            FROM requests_total
            WHERE timestamp > NOW() - INTERVAL '{days} days'
        """
        
        result = await db.fetchrow(query)
        total_requests = result['total_requests']
        
        cost_per_request = (costs.total / total_requests) if total_requests > 0 else 0
        cost_per_million = cost_per_request * 1_000_000
        
        print(f"\n{'='*60}")
        print(f"Cost Analysis - Last {days} Days")
        print(f"{'='*60}")
        print(f"Total Cost: ${costs.total:,.2f}")
        print(f"Total Requests: {total_requests:,}")
        print(f"Cost per Request: ${cost_per_request:.6f}")
        print(f"Cost per Million: ${cost_per_million:.2f}")
        print(f"\nBreakdown:")
        print(f"  Compute:  ${costs.compute:>8,.2f} ({costs.compute/costs.total*100:>5.1f}%)")
        print(f"  Database: ${costs.database:>8,.2f} ({costs.database/costs.total*100:>5.1f}%)")
        print(f"  Cache:    ${costs.cache:>8,.2f} ({costs.cache/costs.total*100:>5.1f}%)")
        print(f"  Storage:  ${costs.storage:>8,.2f} ({costs.storage/costs.total*100:>5.1f}%)")
        print(f"  Network:  ${costs.network:>8,.2f} ({costs.network/costs.total*100:>5.1f}%)")
        print(f"  Other:    ${costs.other:>8,.2f} ({costs.other/costs.total*100:>5.1f}%)")
        
        return cost_per_request

# Usage
monitor = CostMonitor()
await monitor.calculate_cost_per_request(days=30)
```

### Cost Allocation Tags

```yaml
# terraform/tags.tf
locals {
  common_tags = {
    Project     = "mcp-server"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
    Owner       = "platform-team"
  }
  
  resource_tags = {
    compute = merge(local.common_tags, {
      Component = "compute"
      Service   = "mcp-api"
    })
    
    database = merge(local.common_tags, {
      Component = "database"
      Service   = "postgresql"
    })
    
    cache = merge(local.common_tags, {
      Component = "cache"
      Service   = "redis"
    })
  }
}

# Apply tags to all resources
resource "aws_instance" "app_server" {
  # ... other config
  tags = local.resource_tags.compute
}
```

## Resource Sizing Recommendations

### Compute Resources

#### Right-Sizing Strategy

**Analysis Script:**

```python
# cost_optimization/rightsizing.py
import asyncio
from datetime import datetime, timedelta
from typing import Dict, List

async def analyze_resource_utilization(days: int = 7) -> Dict:
    """Analyze resource utilization to identify rightsizing opportunities."""
    
    query = """
        SELECT
            instance_id,
            AVG(cpu_percent) as avg_cpu,
            MAX(cpu_percent) as max_cpu,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY cpu_percent) as p95_cpu,
            AVG(memory_percent) as avg_memory,
            MAX(memory_percent) as max_memory,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY memory_percent) as p95_memory,
            COUNT(*) as samples
        FROM resource_metrics
        WHERE timestamp > NOW() - INTERVAL '7 days'
        GROUP BY instance_id
    """
    
    instances = await db.fetch(query)
    
    recommendations = []
    savings = 0.0
    
    for instance in instances:
        recommendation = None
        
        # Over-provisioned (CPU < 30% and Memory < 40%)
        if instance['p95_cpu'] < 30 and instance['p95_memory'] < 40:
            recommendation = {
                'instance_id': instance['instance_id'],
                'action': 'DOWNSIZE',
                'reason': f"Low utilization - CPU: {instance['avg_cpu']:.1f}%, Memory: {instance['avg_memory']:.1f}%",
                'current_cost': 200.0,  # Example
                'recommended_cost': 100.0,
                'monthly_savings': 100.0
            }
            savings += 100.0
        
        # Under-provisioned (CPU > 80% or Memory > 85%)
        elif instance['p95_cpu'] > 80 or instance['p95_memory'] > 85:
            recommendation = {
                'instance_id': instance['instance_id'],
                'action': 'UPSIZE',
                'reason': f"High utilization - CPU: {instance['avg_cpu']:.1f}%, Memory: {instance['avg_memory']:.1f}%",
                'current_cost': 200.0,
                'recommended_cost': 400.0,
                'additional_cost': 200.0
            }
        
        # Well-sized
        else:
            recommendation = {
                'instance_id': instance['instance_id'],
                'action': 'NO_CHANGE',
                'reason': f"Optimal utilization - CPU: {instance['avg_cpu']:.1f}%, Memory: {instance['avg_memory']:.1f}%"
            }
        
        if recommendation:
            recommendations.append(recommendation)
    
    print(f"\n{'='*80}")
    print(f"Resource Right-Sizing Analysis")
    print(f"{'='*80}\n")
    
    for rec in recommendations:
        if rec['action'] == 'DOWNSIZE':
            print(f"✅ {rec['instance_id']}: DOWNSIZE")
            print(f"   {rec['reason']}")
            print(f"   Monthly savings: ${rec['monthly_savings']:.2f}\n")
        elif rec['action'] == 'UPSIZE':
            print(f"⚠️  {rec['instance_id']}: UPSIZE")
            print(f"   {rec['reason']}")
            print(f"   Additional cost: ${rec['additional_cost']:.2f}\n")
    
    print(f"Total potential monthly savings: ${savings:.2f}")
    
    return {
        'recommendations': recommendations,
        'total_savings': savings
    }

# Usage
await analyze_resource_utilization(days=7)
```

#### Instance Type Selection

**Cost vs Performance Matrix:**

| Instance Type | vCPUs | RAM (GB) | Cost/Hour | Throughput (req/s) | Cost per 1M req | Use Case |
|---------------|-------|----------|-----------|-------------------|-----------------|----------|
| t3.small | 2 | 2 | $0.021 | 300 | $0.194 | Development |
| t3.medium | 2 | 4 | $0.042 | 520 | $0.224 | Small production |
| **t3.large** | **2** | **8** | **$0.083** | **850** | **$0.271** | **Recommended** |
| c6i.large | 2 | 4 | $0.085 | 920 | $0.256 | CPU-intensive |
| m6i.large | 2 | 8 | $0.096 | 880 | $0.303 | Balanced |
| r6i.large | 2 | 16 | $0.126 | 900 | $0.389 | Memory-intensive |

**Recommendation:** t3.large offers best cost/performance for typical MCP workloads.

#### Reserved Instances vs On-Demand

**Cost Comparison (1-year commitment):**

| Payment Option | Upfront | Monthly | Total Annual | Savings vs On-Demand |
|----------------|---------|---------|--------------|----------------------|
| On-Demand | $0 | $730 | $8,760 | 0% |
| No Upfront RI | $0 | $474 | $5,688 | 35% |
| Partial Upfront RI | $2,600 | $217 | $5,204 | 41% |
| All Upfront RI | $4,932 | $0 | $4,932 | 44% |

**Recommendation:** Use partial upfront RI for predictable workloads (40%+ savings).

### Database Resources

#### Connection Pool Optimization

**Cost Impact of Connection Pooling:**

```python
# cost_optimization/connection_pooling.py
from typing import Dict

def calculate_database_cost_savings(
    queries_per_second: float,
    with_pooling: bool = True
) -> Dict:
    """Calculate cost savings from connection pooling."""
    
    # Without pooling: new connection per query
    if not with_pooling:
        connection_time_ms = 50  # Time to establish connection
        query_time_ms = 10       # Actual query time
        total_time_ms = connection_time_ms + query_time_ms
        
        # Need larger instance to handle connection overhead
        instance_type = "db.r5.xlarge"
        hourly_cost = 0.50
    
    # With pooling: reuse connections
    else:
        connection_time_ms = 0   # Connection already established
        query_time_ms = 10       # Actual query time
        total_time_ms = query_time_ms
        
        # Can use smaller instance
        instance_type = "db.r5.large"
        hourly_cost = 0.25
    
    # Calculate throughput
    queries_per_hour = queries_per_second * 3600
    
    # Calculate costs
    daily_cost = hourly_cost * 24
    monthly_cost = daily_cost * 30
    cost_per_million_queries = (hourly_cost / (queries_per_second * 3600)) * 1_000_000
    
    return {
        'instance_type': instance_type,
        'hourly_cost': hourly_cost,
        'daily_cost': daily_cost,
        'monthly_cost': monthly_cost,
        'queries_per_second': queries_per_second,
        'query_time_ms': total_time_ms,
        'cost_per_million_queries': cost_per_million_queries
    }

# Compare with and without pooling
without_pooling = calculate_database_cost_savings(100, with_pooling=False)
with_pooling = calculate_database_cost_savings(100, with_pooling=True)

savings = without_pooling['monthly_cost'] - with_pooling['monthly_cost']
savings_percent = (savings / without_pooling['monthly_cost']) * 100

print(f"\n{'='*60}")
print(f"Database Connection Pooling Cost Analysis")
print(f"{'='*60}\n")
print(f"Without Pooling:")
print(f"  Instance: {without_pooling['instance_type']}")
print(f"  Monthly cost: ${without_pooling['monthly_cost']:.2f}")
print(f"  Query time: {without_pooling['query_time_ms']} ms\n")
print(f"With Pooling:")
print(f"  Instance: {with_pooling['instance_type']}")
print(f"  Monthly cost: ${with_pooling['monthly_cost']:.2f}")
print(f"  Query time: {with_pooling['query_time_ms']} ms\n")
print(f"Monthly savings: ${savings:.2f} ({savings_percent:.0f}%)")
```

**Result:** Connection pooling enables 50% cost reduction by using smaller database instances.

#### Database Read Replicas

**Cost vs Availability Trade-off:**

| Configuration | Cost/Month | Read Capacity | Availability | Use Case |
|---------------|-----------|---------------|--------------|----------|
| Single instance | $360 | 1x | 99.5% | Development |
| Primary + 1 replica | $720 | 2x | 99.9% | Standard production |
| Primary + 2 replicas | $1,080 | 3x | 99.95% | High availability |
| Multi-region | $2,160 | 4x+ | 99.99% | Mission critical |

**Optimization:** Use read replicas only when read traffic justifies cost (> 60% read queries).

### Cache Resources

#### Cache Sizing Optimization

```python
# cost_optimization/cache_sizing.py
from typing import Dict

def calculate_optimal_cache_size(
    total_data_gb: float,
    cache_hit_rate_target: float = 0.80
) -> Dict:
    """Calculate optimal cache size for cost/performance balance."""
    
    # Working set estimation (Pareto principle: 20% of data = 80% of accesses)
    working_set_gb = total_data_gb * 0.20
    
    # Cache size options
    cache_options = [
        {'size_gb': 1, 'cost_monthly': 15, 'hit_rate': 0.50},
        {'size_gb': 2, 'cost_monthly': 30, 'hit_rate': 0.65},
        {'size_gb': 4, 'cost_monthly': 60, 'hit_rate': 0.78},
        {'size_gb': 8, 'cost_monthly': 120, 'hit_rate': 0.85},
        {'size_gb': 16, 'cost_monthly': 240, 'hit_rate': 0.92},
    ]
    
    # Calculate cost per hit
    for option in cache_options:
        hits_per_million = option['hit_rate'] * 1_000_000
        cost_per_million_hits = option['cost_monthly'] / hits_per_million
        option['cost_per_million_hits'] = cost_per_million_hits
        
        # Database cost savings from cache hits
        # Assume $0.10 per 1M database queries
        db_cost_saved = hits_per_million * 0.0001
        net_savings = db_cost_saved - option['cost_monthly']
        option['net_monthly_savings'] = net_savings
    
    # Find optimal size (best net savings)
    optimal = max(cache_options, key=lambda x: x['net_monthly_savings'])
    
    print(f"\n{'='*70}")
    print(f"Cache Size Optimization Analysis")
    print(f"{'='*70}")
    print(f"Total data size: {total_data_gb:.1f} GB")
    print(f"Estimated working set: {working_set_gb:.1f} GB\n")
    print(f"{'Size':<8} {'Cost/Month':<12} {'Hit Rate':<12} {'Net Savings':<15}")
    print(f"{'-'*70}")
    
    for option in cache_options:
        marker = " ⭐" if option == optimal else ""
        print(f"{option['size_gb']:<7}GB ${option['cost_monthly']:<10.2f} "
              f"{option['hit_rate']*100:<11.1f}% ${option['net_monthly_savings']:<14.2f}{marker}")
    
    return optimal

# Usage
optimal_cache = calculate_optimal_cache_size(total_data_gb=50)
```

#### Multi-Tier Caching Strategy

**Cost Analysis:**

| Strategy | L1 (In-Memory) | L2 (Redis) | Total Cost/Month | Hit Rate | Cost per 1M req |
|----------|----------------|------------|------------------|----------|-----------------|
| No cache | - | - | $0 | 0% | $5.20 |
| L2 only | - | 4 GB | $60 | 78% | $1.14 |
| L1 + L2 | 512 MB | 2 GB | $30 | 85% | $0.78 |
| L1 + L2 (large) | 1 GB | 4 GB | $60 | 92% | $0.42 |

**Recommendation:** L1 (512 MB) + L2 (2 GB) provides best cost/performance for most workloads.

## Caching Strategies for Cost Reduction

### Intelligent Cache Warming

```python
# cost_optimization/cache_warming.py
import asyncio
from typing import List, Dict
import aioredis

class IntelligentCacheWarmer:
    """Proactively warm cache with frequently accessed data."""
    
    def __init__(self, redis_client: aioredis.Redis):
        self.redis = redis_client
    
    async def identify_hot_keys(self, hours: int = 24) -> List[str]:
        """Identify most frequently accessed keys."""
        
        query = """
            SELECT
                cache_key,
                COUNT(*) as access_count,
                AVG(fetch_time_ms) as avg_fetch_time
            FROM cache_access_log
            WHERE timestamp > NOW() - INTERVAL '24 hours'
            GROUP BY cache_key
            HAVING COUNT(*) > 100
            ORDER BY access_count DESC
            LIMIT 1000
        """
        
        hot_keys = await db.fetch(query)
        return [row['cache_key'] for row in hot_keys]
    
    async def warm_cache(self):
        """Pre-populate cache with hot data."""
        
        hot_keys = await self.identify_hot_keys()
        
        print(f"Warming cache with {len(hot_keys)} hot keys...")
        
        # Batch fetch from database
        batch_size = 100
        for i in range(0, len(hot_keys), batch_size):
            batch = hot_keys[i:i + batch_size]
            
            # Fetch data
            data = await self.fetch_batch_from_database(batch)
            
            # Populate cache
            pipeline = self.redis.pipeline()
            for key, value in data.items():
                pipeline.setex(key, 300, value)  # 5-minute TTL
            await pipeline.execute()
            
            print(f"  Warmed {min(i + batch_size, len(hot_keys))}/{len(hot_keys)} keys")
        
        print("✅ Cache warming complete")
    
    async def schedule_warming(self):
        """Schedule cache warming during off-peak hours."""
        
        while True:
            # Check if off-peak hours (e.g., 2-4 AM)
            current_hour = datetime.now().hour
            
            if 2 <= current_hour < 4:
                await self.warm_cache()
                
                # Wait until next warming window
                await asyncio.sleep(24 * 3600)
            else:
                # Check again in 1 hour
                await asyncio.sleep(3600)

# Cost Impact:
# - Reduces cold cache miss rate from 22% to 5%
# - Saves ~$145/month in database query costs
# - Improves P99 latency by 40%
```

### Cache Invalidation Strategies

```python
# cost_optimization/cache_invalidation.py
from enum import Enum
from typing import Set, Optional
import asyncio

class InvalidationStrategy(Enum):
    """Cache invalidation strategies."""
    TTL = "time_to_live"           # Simplest, least accurate
    EVENT = "event_driven"         # Most accurate, more complex
    HYBRID = "ttl_with_events"     # Balanced approach

class SmartCacheInvalidation:
    """Cost-optimized cache invalidation."""
    
    def __init__(self, strategy: InvalidationStrategy = InvalidationStrategy.HYBRID):
        self.strategy = strategy
        self.pending_invalidations: Set[str] = set()
    
    async def invalidate_on_write(self, key: str):
        """Invalidate cache entry on data update."""
        
        if self.strategy == InvalidationStrategy.TTL:
            # Do nothing - rely on TTL
            pass
        
        elif self.strategy == InvalidationStrategy.EVENT:
            # Immediate invalidation
            await self.redis.delete(key)
        
        elif self.strategy == InvalidationStrategy.HYBRID:
            # Batch invalidations
            self.pending_invalidations.add(key)
            
            # Flush batch every second
            if len(self.pending_invalidations) >= 100:
                await self.flush_invalidations()
    
    async def flush_invalidations(self):
        """Batch invalidate pending keys."""
        
        if not self.pending_invalidations:
            return
        
        pipeline = self.redis.pipeline()
        for key in self.pending_invalidations:
            pipeline.delete(key)
        
        await pipeline.execute()
        
        print(f"Invalidated {len(self.pending_invalidations)} cache keys")
        self.pending_invalidations.clear()

# Cost Impact by Strategy:
# TTL: Lowest complexity, 15% stale data, $30/month cache cost
# Event: Highest accuracy, 1% stale data, $45/month (more invalidations)
# Hybrid: Balanced, 3% stale data, $32/month (recommended)
```

## Database Query Optimization

### Query Cost Analysis

```python
# cost_optimization/query_cost_analysis.py
from typing import List, Dict
import hashlib

class QueryCostAnalyzer:
    """Analyze and optimize database query costs."""
    
    async def analyze_expensive_queries(self, min_cost: float = 0.01) -> List[Dict]:
        """Identify expensive queries."""
        
        query = """
            SELECT
                query_hash,
                LEFT(query, 100) as query_preview,
                COUNT(*) as execution_count,
                AVG(duration_ms) as avg_duration_ms,
                MAX(duration_ms) as max_duration_ms,
                SUM(duration_ms) / 1000.0 as total_seconds,
                AVG(rows_examined) as avg_rows_examined,
                AVG(rows_returned) as avg_rows_returned
            FROM query_log
            WHERE timestamp > NOW() - INTERVAL '7 days'
            GROUP BY query_hash, LEFT(query, 100)
            HAVING SUM(duration_ms) / 1000.0 > 100
            ORDER BY total_seconds DESC
            LIMIT 20
        """
        
        expensive_queries = await db.fetch(query)
        
        print(f"\n{'='*100}")
        print(f"Top 20 Most Expensive Queries (Last 7 Days)")
        print(f"{'='*100}\n")
        
        total_time = 0
        for idx, q in enumerate(expensive_queries, 1):
            efficiency = (q['avg_rows_returned'] / q['avg_rows_examined']) * 100 if q['avg_rows_examined'] > 0 else 0
            total_time += q['total_seconds']
            
            print(f"{idx}. Query Hash: {q['query_hash']}")
            print(f"   Preview: {q['query_preview']}...")
            print(f"   Executions: {q['execution_count']:,}")
            print(f"   Avg duration: {q['avg_duration_ms']:.1f} ms")
            print(f"   Total time: {q['total_seconds']:.1f} seconds")
            print(f"   Efficiency: {efficiency:.1f}% (returned/examined)")
            print()
        
        print(f"Total time spent on top 20 queries: {total_time:.1f} seconds")
        print(f"Estimated cost impact: ${total_time * 0.0001:.2f}")  # Example pricing
        
        return expensive_queries
    
    async def suggest_optimizations(self, query_hash: str) -> List[str]:
        """Suggest optimizations for expensive query."""
        
        # Get query details
        query_info = await db.fetchrow("""
            SELECT query, avg_rows_examined, avg_rows_returned
            FROM query_log
            WHERE query_hash = $1
            LIMIT 1
        """, query_hash)
        
        suggestions = []
        
        # Check if needs index
        if query_info['avg_rows_examined'] > query_info['avg_rows_returned'] * 10:
            suggestions.append({
                'type': 'INDEX',
                'description': 'High scan ratio suggests missing index',
                'impact': 'HIGH',
                'estimated_savings': '60-80% query time reduction'
            })
        
        # Check if query can be cached
        if 'SELECT' in query_info['query'].upper() and 'NOW()' not in query_info['query'].upper():
            suggestions.append({
                'type': 'CACHE',
                'description': 'Query results can be cached',
                'impact': 'MEDIUM',
                'estimated_savings': '90% reduction in database load'
            })
        
        # Check if needs materialized view
        if 'GROUP BY' in query_info['query'].upper() or 'JOIN' in query_info['query'].upper():
            suggestions.append({
                'type': 'MATERIALIZED_VIEW',
                'description': 'Complex aggregation query - consider materialized view',
                'impact': 'HIGH',
                'estimated_savings': '80-95% query time reduction'
            })
        
        return suggestions

# Usage
analyzer = QueryCostAnalyzer()
expensive = await analyzer.analyze_expensive_queries()
suggestions = await analyzer.suggest_optimizations(expensive[0]['query_hash'])
```

### Index Optimization

**Cost Impact of Proper Indexing:**

```sql
-- Before: Full table scan (expensive)
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user@example.com';

-- Result: Seq Scan on users (cost=0.00..1829.00 rows=1)
--         Execution time: 145.23 ms

-- After: Index scan (cheap)
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user@example.com';

-- Result: Index Scan using idx_users_email (cost=0.42..8.44 rows=1)
--         Execution time: 0.87 ms

-- Cost Reduction: 99.4% faster
-- Database CPU savings: ~$50/month for frequently used query
```

**Index Maintenance Cost:**

| Index Type | Storage Cost | Write Performance Impact | Read Performance Gain | Use Case |
|------------|--------------|-------------------------|----------------------|----------|
| B-tree | Low | 5-10% slower | 100x faster | Most queries |
| Hash | Medium | 10-15% slower | 200x faster | Exact matches |
| GiST | High | 20-30% slower | 50x faster | Full-text search |
| GIN | Very High | 30-50% slower | 500x faster | JSONB queries |

**Recommendation:** Balance index count - too many indexes increase write costs.

## API Call Batching Patterns

### Request Batching

```python
# cost_optimization/request_batching.py
import asyncio
from typing import List, Any, Dict
from dataclasses import dataclass
from datetime import datetime

@dataclass
class BatchConfig:
    """Batch processing configuration."""
    max_batch_size: int = 100
    max_wait_ms: int = 100
    cost_per_api_call: float = 0.001

class RequestBatcher:
    """Batch API requests to reduce costs."""
    
    def __init__(self, config: BatchConfig = BatchConfig()):
        self.config = config
        self.pending_requests: List[Dict] = []
        self.batch_task = None
    
    async def add_request(self, request: Dict) -> Any:
        """Add request to batch queue."""
        
        # Add to pending queue
        future = asyncio.Future()
        self.pending_requests.append({
            'request': request,
            'future': future,
            'timestamp': datetime.now()
        })
        
        # Start batch processor if not running
        if self.batch_task is None or self.batch_task.done():
            self.batch_task = asyncio.create_task(self._process_batch())
        
        # Wait for result
        return await future
    
    async def _process_batch(self):
        """Process batched requests."""
        
        # Wait for batch to fill or timeout
        await asyncio.sleep(self.config.max_wait_ms / 1000.0)
        
        if not self.pending_requests:
            return
        
        # Extract batch
        batch = self.pending_requests[:self.config.max_batch_size]
        self.pending_requests = self.pending_requests[self.config.max_batch_size:]
        
        print(f"Processing batch of {len(batch)} requests")
        
        # Make single API call with batch
        try:
            results = await self._execute_batch([item['request'] for item in batch])
            
            # Distribute results to futures
            for item, result in zip(batch, results):
                item['future'].set_result(result)
        
        except Exception as e:
            # Propagate error to all futures
            for item in batch:
                item['future'].set_exception(e)
    
    async def _execute_batch(self, requests: List[Dict]) -> List[Any]:
        """Execute batch API call."""
        
        # Single API call for entire batch
        response = await api_client.post('/batch', json={'requests': requests})
        return response.json()['results']

# Cost Savings Example:
# Without batching: 10,000 requests × $0.001 = $10.00
# With batching (100 per batch): 100 API calls × $0.001 = $0.10
# Savings: $9.90 (99% reduction)

# Usage
batcher = RequestBatcher()

# Queue multiple requests
tasks = []
for i in range(1000):
    task = batcher.add_request({'action': 'process', 'id': i})
    tasks.append(task)

# All requests batched into ~10 API calls
results = await asyncio.gather(*tasks)
```

### Database Query Batching

```python
# cost_optimization/query_batching.py
from typing import List, Dict, Any
import asyncio

class QueryBatcher:
    """Batch database queries to reduce round trips."""
    
    async def fetch_users_efficient(self, user_ids: List[str]) -> List[Dict]:
        """Fetch multiple users in single query (efficient)."""
        
        # Single query with IN clause
        query = """
            SELECT id, name, email, created_at
            FROM users
            WHERE id = ANY($1)
        """
        
        users = await db.fetch(query, user_ids)
        return users
    
    async def fetch_users_inefficient(self, user_ids: List[str]) -> List[Dict]:
        """Fetch users one by one (inefficient)."""
        
        users = []
        for user_id in user_ids:
            user = await db.fetchrow(
                "SELECT id, name, email, created_at FROM users WHERE id = $1",
                user_id
            )
            users.append(user)
        
        return users

# Performance comparison for 100 users:
# Inefficient: 100 queries × 5ms = 500ms
# Efficient: 1 query × 8ms = 8ms
# Improvement: 62x faster

# Cost comparison:
# Inefficient: 100 queries × $0.0001 = $0.01
# Efficient: 1 query × $0.0001 = $0.0001
# Savings: 99% per operation
```

## Cold Start Optimization

### Lambda/Serverless Optimization

```python
# cost_optimization/cold_start.py
import asyncio
from typing import Optional
import time

class ColdStartOptimizer:
    """Reduce cold start latency and cost for serverless functions."""
    
    def __init__(self):
        self._initialized = False
        self._db_pool = None
        self._cache_client = None
    
    async def lazy_init(self):
        """Lazy initialization to reduce cold start time."""
        
        if self._initialized:
            return
        
        start = time.time()
        
        # Initialize only essential resources
        await self._init_database_pool()
        
        self._initialized = True
        
        duration = (time.time() - start) * 1000
        print(f"Cold start initialization: {duration:.1f} ms")
    
    async def _init_database_pool(self):
        """Initialize database connection pool."""
        
        # Use smaller pool for serverless (2-5 connections)
        self._db_pool = await asyncpg.create_pool(
            dsn=DATABASE_URL,
            min_size=2,
            max_size=5,
            command_timeout=10
        )
    
    async def warm_function(self):
        """Keep function warm to avoid cold starts."""
        
        # Periodic ping to keep function warm
        while True:
            await asyncio.sleep(300)  # Every 5 minutes
            
            # Make lightweight request
            await self.health_check()

# Cold Start Cost Analysis:
# Cold start: 1200ms initialization + 150ms execution = 1350ms
# Warm start: 150ms execution
# 
# Without optimization:
# - Cold starts: 40% of invocations
# - Avg latency: (0.4 × 1350) + (0.6 × 150) = 630ms
# - Cost: Higher due to longer execution time
#
# With optimization + warming:
# - Cold starts: 5% of invocations
# - Avg latency: (0.05 × 800) + (0.95 × 150) = 183ms
# - Cost savings: 25% reduction in compute costs
```

### Provisioned Concurrency Strategy

```yaml
# serverless.yml - Cost-optimized provisioned concurrency
functions:
  mcp-api:
    handler: handler.main
    timeout: 30
    memorySize: 1024
    
    # Provisioned concurrency for predictable latency
    provisionedConcurrency:
      - schedule: cron(0 8 * * ? *)   # 8 AM
        min: 10
        max: 50
      - schedule: cron(0 22 * * ? *)  # 10 PM
        min: 2
        max: 10
    
    # Auto-scaling for unpredictable spikes
    reservedConcurrency: 100

# Cost Analysis:
# Always-on (50 concurrent): $1,200/month
# On-demand only: $400/month (high cold start rate)
# Time-based provisioning: $650/month (balanced)
# Savings vs always-on: $550/month (46%)
```

## Auto-Scaling Policies

### Cost-Optimized Scaling

```python
# cost_optimization/autoscaling.py
from dataclasses import dataclass
from typing import Dict
from datetime import datetime, time

@dataclass
class ScalingPolicy:
    """Auto-scaling policy configuration."""
    min_instances: int
    max_instances: int
    target_cpu_percent: int
    target_requests_per_second: int
    scale_up_cooldown_seconds: int = 60
    scale_down_cooldown_seconds: int = 300

class CostOptimizedScaling:
    """Implement cost-optimized auto-scaling policies."""
    
    def __init__(self):
        self.policies = {
            'business_hours': ScalingPolicy(
                min_instances=4,
                max_instances=20,
                target_cpu_percent=70,
                target_requests_per_second=750
            ),
            'off_hours': ScalingPolicy(
                min_instances=2,
                max_instances=8,
                target_cpu_percent=60,
                target_requests_per_second=300
            ),
            'weekend': ScalingPolicy(
                min_instances=1,
                max_instances=4,
                target_cpu_percent=50,
                target_requests_per_second=150
            )
        }
    
    def get_active_policy(self) -> ScalingPolicy:
        """Get scaling policy based on time of day."""
        
        now = datetime.now()
        current_time = now.time()
        is_weekend = now.weekday() >= 5
        
        if is_weekend:
            return self.policies['weekend']
        elif time(8, 0) <= current_time <= time(18, 0):
            return self.policies['business_hours']
        else:
            return self.policies['off_hours']
    
    def calculate_cost_savings(self) -> Dict:
        """Calculate cost savings from time-based scaling."""
        
        # Static configuration (no auto-scaling)
        static_instances = 20  # Always max capacity
        static_hours = 24 * 30
        static_cost = static_instances * static_hours * 0.10  # $0.10/hour
        
        # Time-based auto-scaling
        business_hours = 10 * 5 * 4  # 10 hours × 5 days × 4 weeks
        off_hours = (14 * 5 * 4) + (24 * 2 * 4)  # Off hours + weekends
        
        business_cost = 12 * business_hours * 0.10  # Avg 12 instances
        off_hours_cost = 3 * off_hours * 0.10      # Avg 3 instances
        
        autoscale_cost = business_cost + off_hours_cost
        
        savings = static_cost - autoscale_cost
        savings_percent = (savings / static_cost) * 100
        
        return {
            'static_cost': static_cost,
            'autoscale_cost': autoscale_cost,
            'monthly_savings': savings,
            'savings_percent': savings_percent
        }

# Usage
scaler = CostOptimizedScaling()
savings = scaler.calculate_cost_savings()

print(f"\n{'='*60}")
print(f"Auto-Scaling Cost Analysis")
print(f"{'='*60}")
print(f"Static (always 20 instances): ${savings['static_cost']:.2f}/month")
print(f"Auto-scaled (time-based): ${savings['autoscale_cost']:.2f}/month")
print(f"Monthly savings: ${savings['monthly_savings']:.2f} ({savings['savings_percent']:.0f}%)")
```

### Predictive Scaling

```python
# cost_optimization/predictive_scaling.py
import numpy as np
from sklearn.linear_model import LinearRegression
from datetime import datetime, timedelta

class PredictiveScaling:
    """Use ML to predict traffic and scale proactively."""
    
    def __init__(self):
        self.model = LinearRegression()
        self.trained = False
    
    async def train_model(self, days: int = 30):
        """Train model on historical traffic data."""
        
        query = """
            SELECT
                EXTRACT(hour FROM timestamp) as hour,
                EXTRACT(dow FROM timestamp) as day_of_week,
                AVG(requests_per_minute) as avg_requests
            FROM traffic_metrics
            WHERE timestamp > NOW() - INTERVAL '30 days'
            GROUP BY hour, day_of_week
            ORDER BY day_of_week, hour
        """
        
        data = await db.fetch(query)
        
        # Prepare features
        X = np.array([[row['hour'], row['day_of_week']] for row in data])
        y = np.array([row['avg_requests'] for row in data])
        
        # Train model
        self.model.fit(X, y)
        self.trained = True
        
        print("✅ Predictive scaling model trained")
    
    def predict_traffic(self, hours_ahead: int = 1) -> float:
        """Predict traffic N hours ahead."""
        
        if not self.trained:
            raise ValueError("Model not trained")
        
        future_time = datetime.now() + timedelta(hours=hours_ahead)
        hour = future_time.hour
        day_of_week = future_time.weekday()
        
        prediction = self.model.predict([[hour, day_of_week]])[0]
        return prediction
    
    def calculate_required_instances(self, predicted_rps: float) -> int:
        """Calculate required instances for predicted traffic."""
        
        # Each instance handles 850 req/s
        instance_capacity = 850 / 60  # Per minute
        
        # Add 20% buffer
        required = int((predicted_rps / instance_capacity) * 1.2)
        
        # Ensure minimum
        return max(required, 2)

# Cost Impact:
# Reactive scaling: Scale after load increases (lag time = 2-3 minutes)
#   - Result: Brief performance degradation
#   - Over-provisioning to compensate: +30% cost
#
# Predictive scaling: Scale before load increases
#   - Result: Smooth performance
#   - Optimal provisioning: -20% cost vs reactive
#   - Annual savings: $1,800 for medium deployment
```

## Storage Optimization

### S3 Storage Classes

**Cost Comparison:**

| Storage Class | Cost/GB/Month | Retrieval Cost | Use Case |
|---------------|---------------|----------------|----------|
| S3 Standard | $0.023 | $0 | Frequently accessed |
| S3 Intelligent-Tiering | $0.0025-$0.023 | $0 | Unknown access patterns |
| S3 Standard-IA | $0.0125 | $0.01/GB | Infrequently accessed |
| S3 Glacier Instant | $0.004 | $0.03/GB | Archive with instant access |
| S3 Glacier Flexible | $0.0036 | $0.05/GB + wait | Long-term archive |

**Lifecycle Policy:**

```json
{
  "Rules": [
    {
      "Id": "intelligent-tiering-policy",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "INTELLIGENT_TIERING"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER_IR"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 2555
      }
    }
  ]
}
```

**Cost Savings Example:**

```text
10 TB storage with proper lifecycle management:

Without optimization:
- S3 Standard: 10,000 GB × $0.023 = $230/month

With optimization:
- Hot (30 days): 500 GB × $0.023 = $11.50
- Warm (60 days): 1,500 GB × $0.0125 = $18.75
- Cold (275 days): 8,000 GB × $0.004 = $32.00
- Total: $62.25/month

Monthly savings: $167.75 (73% reduction)
```

### Database Storage Optimization

```sql
-- Identify large tables for partitioning
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY size_bytes DESC
LIMIT 10;

-- Partition large table by date
CREATE TABLE requests_partitioned (
    id BIGSERIAL,
    user_id UUID,
    endpoint TEXT,
    created_at TIMESTAMP NOT NULL,
    -- other columns
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE requests_2025_01 PARTITION OF requests_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

-- Archive old partitions to cold storage
-- Saves 60% on storage costs for old data
```

## Network Cost Optimization

### Data Transfer Costs

**Cost Breakdown:**

| Transfer Type | Cost/GB | Annual Cost (1 TB/month) |
|---------------|---------|-------------------------|
| Inbound (to AWS) | $0 | $0 |
| Outbound (to internet) | $0.09 | $1,080 |
| Inter-region | $0.02 | $240 |
| Intra-region (AZ) | $0.01 | $120 |
| Intra-AZ | $0 | $0 |

**Optimization Strategies:**

```python
# cost_optimization/network_optimization.py

class NetworkCostOptimizer:
    """Optimize network transfer costs."""
    
    async def enable_compression(self):
        """Enable response compression to reduce bandwidth."""
        
        # Middleware for FastAPI
        from fastapi import FastAPI
        from fastapi.middleware.gzip import GZipMiddleware
        
        app = FastAPI()
        app.add_middleware(GZipMiddleware, minimum_size=1000)
        
        # Cost impact:
        # - Compression ratio: 70% average
        # - 1 TB uncompressed = 300 GB compressed
        # - Savings: 700 GB × $0.09 = $63/month
    
    async def use_cloudfront_cdn(self):
        """Use CDN to reduce origin data transfer."""
        
        # CloudFront pricing:
        # - First 10 TB: $0.085/GB (vs $0.09 direct)
        # - Cache hit rate: 80%
        # - Effective transfer: 20% of traffic from origin
        #
        # Cost comparison for 1 TB/month:
        # - Direct: 1,000 GB × $0.09 = $90
        # - CloudFront: (200 GB × $0.09) + (1,000 GB × $0.085) = $103
        # - But: Reduced latency = better user experience
        # - Breakeven: > 5 TB/month
        pass
    
    async def optimize_api_responses(self):
        """Reduce response payload sizes."""
        
        # Techniques:
        # 1. Return only requested fields (GraphQL-style)
        # 2. Paginate large result sets
        # 3. Use efficient serialization (MessagePack vs JSON)
        # 4. Implement response filtering
        #
        # Impact: 40% reduction in response size
        # Savings: $36/month for 1 TB traffic
        pass

# Total network optimization savings: $99/month (52% reduction)
```

## Summary

Comprehensive cost optimization strategies for MCP servers:

### Key Savings Opportunities

| Strategy | Monthly Savings | Implementation Effort | Priority |
|----------|----------------|----------------------|----------|
| Right-sizing instances | $100-500 | Low | HIGH |
| Connection pooling | $180 | Medium | HIGH |
| Multi-tier caching | $145 | Medium | HIGH |
| Request batching | $200-400 | High | MEDIUM |
| Auto-scaling policies | $550 | Medium | HIGH |
| Storage lifecycle | $168 | Low | MEDIUM |
| Network optimization | $99 | Medium | MEDIUM |
| Reserved instances | $3,068/year | Low | HIGH |

**Total Potential Savings:** $1,500-2,500/month (40-60% cost reduction)

### Cost Optimization Checklist

- [ ] Implement cost tracking and monitoring
- [ ] Analyze resource utilization and right-size instances
- [ ] Configure connection pooling (50% database cost reduction)
- [ ] Implement multi-tier caching strategy
- [ ] Enable request/query batching where applicable
- [ ] Configure time-based auto-scaling policies
- [ ] Set up storage lifecycle policies
- [ ] Enable response compression
- [ ] Purchase reserved instances for predictable workloads
- [ ] Schedule regular cost reviews (monthly)

---

**Next**: Review [Performance Benchmarks](14-performance-benchmarks.md) for optimization targets.
