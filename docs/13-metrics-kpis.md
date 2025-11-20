# Metrics and KPIs

**Navigation**: [Home](../README.md) > Metrics & Reference > Metrics and KPIs  
**Related**: [← Previous: Cost Optimization](12-cost-optimization.md) | [Next: Performance Benchmarks →](14-performance-benchmarks.md) | [Observability](05-observability.md)

**Version:** 1.3.0  
**Last Updated:** November 20, 2025  
**Status:** Draft

## Introduction

This document defines key performance indicators (KPIs), service level objectives (SLOs), and metrics for monitoring MCP server health, business performance, and operational efficiency. These metrics guide capacity planning, incident response, and continuous improvement.

## Service Level Objectives (SLOs)

### Availability SLO

**Target:** 99.9% uptime (43.2 minutes downtime per month)

**Measurement:**

```promql
# Availability percentage
(
  sum(up{job="mcp-server"})
  /
  count(up{job="mcp-server"})
) * 100

# Error budget remaining (monthly)
(1 - (
  sum(rate(mcp_requests_total{status=~"5.."}[30d]))
  /
  sum(rate(mcp_requests_total[30d]))
)) * 100
```

**Calculation:**

```python
# availability_calculator.py
from datetime import datetime, timedelta

def calculate_availability(uptime_minutes: float, total_minutes: float) -> dict:
    """Calculate availability metrics."""
    availability = (uptime_minutes / total_minutes) * 100
    downtime_minutes = total_minutes - uptime_minutes
    
    # Error budget (1 - SLO)
    slo_target = 99.9
    error_budget_percent = 100 - slo_target
    error_budget_minutes = total_minutes * (error_budget_percent / 100)
    
    # Remaining budget
    budget_consumed_minutes = downtime_minutes
    budget_remaining_minutes = error_budget_minutes - budget_consumed_minutes
    budget_remaining_percent = (budget_remaining_minutes / error_budget_minutes) * 100
    
    return {
        'availability_percent': availability,
        'uptime_minutes': uptime_minutes,
        'downtime_minutes': downtime_minutes,
        'slo_target_percent': slo_target,
        'error_budget_minutes': error_budget_minutes,
        'budget_consumed_minutes': budget_consumed_minutes,
        'budget_remaining_minutes': budget_remaining_minutes,
        'budget_remaining_percent': budget_remaining_percent,
        'slo_met': availability >= slo_target
    }

# Example: 30-day period
total_minutes = 30 * 24 * 60  # 43,200 minutes
uptime_minutes = 43_180  # 20 minutes downtime

metrics = calculate_availability(uptime_minutes, total_minutes)
print(f"Availability: {metrics['availability_percent']:.3f}%")
print(f"Downtime: {metrics['downtime_minutes']:.1f} minutes")
print(f"Error budget remaining: {metrics['budget_remaining_percent']:.1f}%")
print(f"SLO met: {'✅' if metrics['slo_met'] else '❌'}")
```

**Monitoring:**

```yaml
# prometheus/rules/slo_availability.yaml
groups:
  - name: availability_slo
    interval: 1m
    rules:
      # Track error budget burn rate
      - record: slo:availability:error_budget_remaining
        expr: |
          1 - (
            sum(rate(mcp_requests_total{status=~"5.."}[30d]))
            /
            sum(rate(mcp_requests_total[30d]))
          )
      
      # Alert if burning budget too fast
      - alert: ErrorBudgetBurnRateCritical
        expr: |
          (
            sum(rate(mcp_requests_total{status=~"5.."}[1h]))
            /
            sum(rate(mcp_requests_total[1h]))
          ) > 0.014  # Burns 100% of 30-day budget in 3 days
        for: 5m
        labels:
          severity: critical
          slo: availability
        annotations:
          summary: "Critical error budget burn rate"
          description: "At current rate, will exhaust error budget in <3 days"
      
      - alert: AvailabilitySLOBreached
        expr: slo:availability:error_budget_remaining < 0
        for: 5m
        labels:
          severity: critical
          slo: availability
        annotations:
          summary: "Availability SLO breached"
          description: "Error budget exhausted - availability below 99.9%"
```

### Latency SLO

**Target:** P99 latency < 500ms

**Measurement:**

```promql
# P99 latency
histogram_quantile(0.99,
  sum by (le) (
    rate(mcp_request_duration_seconds_bucket[5m])
  )
)

# Latency SLI (requests meeting SLO)
sum(rate(mcp_request_duration_seconds_bucket{le="0.5"}[5m]))
/
sum(rate(mcp_request_duration_seconds_count[5m]))
```

**Monitoring:**

```yaml
# prometheus/rules/slo_latency.yaml
groups:
  - name: latency_slo
    rules:
      # Record P99 latency
      - record: slo:latency:p99_seconds
        expr: |
          histogram_quantile(0.99,
            sum by (le) (
              rate(mcp_request_duration_seconds_bucket[5m])
            )
          )
      
      # Calculate SLI (% of requests meeting SLO)
      - record: slo:latency:success_rate
        expr: |
          sum(rate(mcp_request_duration_seconds_bucket{le="0.5"}[5m]))
          /
          sum(rate(mcp_request_duration_seconds_count[5m]))
      
      # Alert on SLO breach
      - alert: LatencySLOBreached
        expr: slo:latency:p99_seconds > 0.5
        for: 5m
        labels:
          severity: warning
          slo: latency
        annotations:
          summary: "P99 latency above SLO"
          description: "P99 latency {{ $value }}s exceeds 500ms target"
      
      # Alert on sustained degradation
      - alert: LatencyDegradationSustained
        expr: |
          (
            slo:latency:p99_seconds > 0.5
            and
            slo:latency:success_rate < 0.95
          )
        for: 15m
        labels:
          severity: critical
          slo: latency
        annotations:
          summary: "Sustained latency degradation"
          description: "P99 {{ $value }}s, only {{ .slo:latency:success_rate }}% meeting SLO"
```

### Error Rate SLO

**Target:** Error rate < 0.1% (99.9% success rate)

**Measurement:**

```promql
# Error rate
sum(rate(mcp_requests_total{status=~"5.."}[5m]))
/
sum(rate(mcp_requests_total[5m]))

# Success rate
sum(rate(mcp_requests_total{status=~"2..|3.."}[5m]))
/
sum(rate(mcp_requests_total[5m]))
```

**Monitoring:**

```yaml
# prometheus/rules/slo_errors.yaml
groups:
  - name: error_rate_slo
    rules:
      # Record error rate
      - record: slo:error_rate:ratio
        expr: |
          sum(rate(mcp_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(mcp_requests_total[5m]))
      
      # Record success rate
      - record: slo:success_rate:ratio
        expr: |
          sum(rate(mcp_requests_total{status=~"2..|3.."}[5m]))
          /
          sum(rate(mcp_requests_total[5m]))
      
      # Alert on error rate breach
      - alert: ErrorRateSLOBreached
        expr: slo:error_rate:ratio > 0.001  # 0.1%
        for: 5m
        labels:
          severity: critical
          slo: error_rate
        annotations:
          summary: "Error rate above SLO"
          description: "Error rate {{ $value | humanizePercentage }} exceeds 0.1% target"
      
      # Alert on error spike
      - alert: ErrorRateSpike
        expr: |
          (
            slo:error_rate:ratio > 0.01  # 1%
            and
            rate(slo:error_rate:ratio[5m]) > 0.002  # Increasing
          )
        for: 2m
        labels:
          severity: critical
          slo: error_rate
        annotations:
          summary: "Error rate spike detected"
          description: "Error rate {{ $value | humanizePercentage }} and rising"
```

### Composite SLO Dashboard

```json
{
  "dashboard": {
    "title": "Service Level Objectives",
    "panels": [
      {
        "title": "SLO Compliance",
        "type": "stat",
        "targets": [
          {
            "expr": "slo:availability:error_budget_remaining * 100",
            "legendFormat": "Availability"
          },
          {
            "expr": "slo:latency:success_rate * 100",
            "legendFormat": "Latency"
          },
          {
            "expr": "slo:success_rate:ratio * 100",
            "legendFormat": "Success Rate"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"value": 0, "color": "red"},
                {"value": 95, "color": "yellow"},
                {"value": 99, "color": "green"}
              ]
            }
          }
        }
      },
      {
        "title": "Error Budget Consumption",
        "type": "gauge",
        "targets": [
          {
            "expr": "(1 - slo:availability:error_budget_remaining) * 100"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "max": 100,
            "thresholds": {
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 50, "color": "yellow"},
                {"value": 80, "color": "red"}
              ]
            }
          }
        }
      }
    ]
  }
}
```

## Business Metrics

### Tools Executed Per Day

**Definition:** Total number of MCP tool invocations per day

**Measurement:**

```promql
# Daily tool executions
sum(increase(mcp_tool_executions_total[1d]))

# By tool type
sum by (tool_name) (increase(mcp_tool_executions_total[1d]))

# Growth rate (week-over-week)
(
  sum(increase(mcp_tool_executions_total[7d]))
  /
  sum(increase(mcp_tool_executions_total[7d] offset 7d))
  - 1
) * 100
```

**Tracking:**

```python
# metrics/business_metrics.py
from prometheus_client import Counter
from datetime import datetime, timedelta

tool_executions = Counter(
    'mcp_tool_executions_total',
    'Total tool executions',
    ['tool_name', 'user_id', 'status']
)

async def track_tool_execution(
    tool_name: str,
    user_id: str,
    status: str
):
    """Track tool execution."""
    tool_executions.labels(
        tool_name=tool_name,
        user_id=user_id,
        status=status
    ).inc()

# Daily report
async def generate_daily_report():
    """Generate daily business metrics report."""
    yesterday = datetime.now() - timedelta(days=1)
    
    query = """
        SELECT
            tool_name,
            COUNT(*) as executions,
            COUNT(DISTINCT user_id) as unique_users,
            AVG(duration_ms) as avg_duration_ms,
            COUNT(*) FILTER (WHERE status = 'success') as successful,
            COUNT(*) FILTER (WHERE status = 'error') as failed
        FROM tool_executions
        WHERE created_at >= $1
            AND created_at < $2
        GROUP BY tool_name
        ORDER BY executions DESC
    """
    
    results = await db.fetch(query, yesterday, datetime.now())
    
    print(f"\n{'='*80}")
    print(f"Tool Execution Report - {yesterday.date()}")
    print(f"{'='*80}")
    
    total_executions = sum(r['executions'] for r in results)
    print(f"\nTotal Executions: {total_executions:,}")
    print(f"\nTop Tools:")
    
    for row in results[:10]:
        success_rate = (row['successful'] / row['executions']) * 100
        print(f"  {row['tool_name']:30} {row['executions']:>6} executions | "
              f"{row['unique_users']:>4} users | {success_rate:>5.1f}% success")

# Usage
await generate_daily_report()
```

**Targets:**

- Daily executions: 10,000+ (baseline)
- Week-over-week growth: 5%+
- Success rate: >95%

### Active Users

**Definition:** Unique users making at least one request in the last 30 days

**Measurement:**

```promql
# Daily Active Users (DAU)
count(
  count by (user_id) (
    mcp_requests_total{timestamp > (time() - 86400)}
  )
)

# Weekly Active Users (WAU)
count(
  count by (user_id) (
    mcp_requests_total{timestamp > (time() - 604800)}
  )
)

# Monthly Active Users (MAU)
count(
  count by (user_id) (
    mcp_requests_total{timestamp > (time() - 2592000)}
  )
)

# Engagement ratio
DAU / MAU
```

**User Segmentation:**

```sql
-- Active user analysis
SELECT
    CASE
        WHEN request_count >= 100 THEN 'Power User'
        WHEN request_count >= 20 THEN 'Active User'
        WHEN request_count >= 5 THEN 'Casual User'
        ELSE 'Inactive User'
    END as segment,
    COUNT(DISTINCT user_id) as users,
    AVG(request_count) as avg_requests,
    SUM(request_count) as total_requests
FROM (
    SELECT
        user_id,
        COUNT(*) as request_count
    FROM requests
    WHERE created_at > NOW() - INTERVAL '30 days'
    GROUP BY user_id
) user_activity
GROUP BY segment
ORDER BY avg_requests DESC;
```

**Retention Analysis:**

```python
# cohort_analysis.py
import pandas as pd
from datetime import datetime, timedelta

async def calculate_retention_cohorts():
    """Calculate user retention by cohort."""
    
    query = """
        WITH user_first_seen AS (
            SELECT
                user_id,
                DATE_TRUNC('month', MIN(created_at)) as cohort_month
            FROM requests
            GROUP BY user_id
        ),
        user_activity AS (
            SELECT
                r.user_id,
                ufs.cohort_month,
                DATE_TRUNC('month', r.created_at) as activity_month
            FROM requests r
            JOIN user_first_seen ufs ON r.user_id = ufs.user_id
        )
        SELECT
            cohort_month,
            activity_month,
            COUNT(DISTINCT user_id) as active_users
        FROM user_activity
        GROUP BY cohort_month, activity_month
        ORDER BY cohort_month, activity_month
    """
    
    df = pd.DataFrame(await db.fetch(query))
    
    # Calculate retention percentages
    cohort_sizes = df.groupby('cohort_month')['active_users'].first()
    
    retention = df.copy()
    retention['retention_rate'] = (
        retention['active_users'] / 
        retention['cohort_month'].map(cohort_sizes)
    ) * 100
    
    # Pivot for display
    retention_pivot = retention.pivot_table(
        index='cohort_month',
        columns='activity_month',
        values='retention_rate'
    )
    
    print("\nCohort Retention Analysis:")
    print(retention_pivot.to_string())
    
    return retention_pivot

# Usage
await calculate_retention_cohorts()
```

**Targets:**

- MAU: 1,000+ active users
- DAU/MAU ratio: >20% (engagement)
- 30-day retention: >50%

### API Call Volume

**Definition:** Total API requests per time period

**Measurement:**

```promql
# Requests per second
sum(rate(mcp_requests_total[5m]))

# Requests per day
sum(increase(mcp_requests_total[1d]))

# By endpoint
sum by (endpoint) (rate(mcp_requests_total[5m]))

# Growth trend (7-day moving average)
avg_over_time(
  sum(rate(mcp_requests_total[1h]))[7d:1h]
)
```

**Peak Analysis:**

```python
# traffic_analysis.py
from datetime import datetime, timedelta
import pytz

async def analyze_traffic_patterns():
    """Analyze API traffic patterns."""
    
    query = """
        SELECT
            EXTRACT(hour FROM created_at) as hour,
            EXTRACT(dow FROM created_at) as day_of_week,
            COUNT(*) as request_count,
            AVG(duration_ms) as avg_duration_ms
        FROM requests
        WHERE created_at > NOW() - INTERVAL '30 days'
        GROUP BY hour, day_of_week
        ORDER BY request_count DESC
    """
    
    results = await db.fetch(query)
    
    print("\n=== Traffic Patterns ===")
    print("\nPeak Hours:")
    for row in results[:5]:
        day_names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        print(f"  {day_names[int(row['day_of_week'])]} {int(row['hour']):02d}:00 - "
              f"{row['request_count']:>6} requests | "
              f"{row['avg_duration_ms']:>6.1f}ms avg")
    
    # Calculate capacity requirements
    peak_rps = max(r['request_count'] for r in results) / 3600  # Requests per second
    avg_rps = sum(r['request_count'] for r in results) / len(results) / 3600
    
    print(f"\nCapacity Analysis:")
    print(f"  Average RPS: {avg_rps:.2f}")
    print(f"  Peak RPS: {peak_rps:.2f}")
    print(f"  Peak/Avg Ratio: {peak_rps/avg_rps:.1f}x")
    print(f"  Recommended capacity: {peak_rps * 1.5:.2f} RPS (1.5x peak)")

# Usage
await analyze_traffic_patterns()
```

**Targets:**

- API call volume: 100,000+ requests/day
- Growth rate: 10%+ month-over-month
- Peak capacity: 200 RPS with <500ms P99 latency

## Operational Metrics

### Deployment Frequency

**Definition:** Number of production deployments per time period

**Measurement:**

```promql
# Deployments per day
sum(increase(deployment_events_total[1d]))

# Time between deployments
timestamp(deployment_events_total) - timestamp(deployment_events_total offset 1h)

# Deployment success rate
sum(increase(deployment_events_total{status="success"}[7d]))
/
sum(increase(deployment_events_total[7d]))
```

**Tracking:**

```python
# deployment_metrics.py
from prometheus_client import Counter, Histogram
from datetime import datetime

deployment_counter = Counter(
    'deployment_events_total',
    'Total deployment events',
    ['environment', 'status', 'version']
)

deployment_duration = Histogram(
    'deployment_duration_seconds',
    'Deployment duration',
    ['environment'],
    buckets=[30, 60, 120, 300, 600, 1200]
)

async def record_deployment(
    environment: str,
    version: str,
    status: str,
    duration_seconds: float
):
    """Record deployment metrics."""
    deployment_counter.labels(
        environment=environment,
        status=status,
        version=version
    ).inc()
    
    if status == 'success':
        deployment_duration.labels(
            environment=environment
        ).observe(duration_seconds)
    
    # Store in database
    await db.execute("""
        INSERT INTO deployments (
            environment, version, status, duration_seconds, deployed_at
        ) VALUES ($1, $2, $3, $4, $5)
    """, environment, version, status, duration_seconds, datetime.now())

# Deployment report
async def generate_deployment_report(days: int = 30):
    """Generate deployment frequency report."""
    
    query = """
        SELECT
            environment,
            COUNT(*) as total_deployments,
            COUNT(*) FILTER (WHERE status = 'success') as successful,
            COUNT(*) FILTER (WHERE status = 'failed') as failed,
            AVG(duration_seconds) as avg_duration_seconds,
            MAX(deployed_at) as last_deployment
        FROM deployments
        WHERE deployed_at > NOW() - INTERVAL '${days} days'
        GROUP BY environment
        ORDER BY total_deployments DESC
    """
    
    results = await db.fetch(query.replace('${days}', str(days)))
    
    print(f"\n{'='*80}")
    print(f"Deployment Report - Last {days} Days")
    print(f"{'='*80}\n")
    
    for row in results:
        success_rate = (row['successful'] / row['total_deployments']) * 100
        deployments_per_day = row['total_deployments'] / days
        
        print(f"{row['environment'].upper()}:")
        print(f"  Deployments: {row['total_deployments']} ({deployments_per_day:.1f}/day)")
        print(f"  Success rate: {success_rate:.1f}%")
        print(f"  Avg duration: {row['avg_duration_seconds']:.0f}s")
        print(f"  Last deployed: {row['last_deployment']}")
        print()

# Usage
await generate_deployment_report(days=30)
```

**Targets (DORA Metrics - Elite):**

- Frequency: Multiple deploys per day
- Success rate: >95%
- Deployment duration: <10 minutes

### MTTR (Mean Time To Recovery)

**Definition:** Average time from incident detection to resolution

**Measurement:**

```promql
# MTTR (hours)
avg(
  (incident_resolved_timestamp - incident_detected_timestamp) / 3600
)

# MTTR by severity
avg by (severity) (
  (incident_resolved_timestamp - incident_detected_timestamp) / 3600
)
```

**Tracking:**

```python
# incident_metrics.py
from prometheus_client import Histogram
from datetime import datetime
from enum import Enum

class Severity(Enum):
    SEV1 = "critical"  # Service down
    SEV2 = "high"      # Major functionality impaired
    SEV3 = "medium"    # Minor functionality impaired
    SEV4 = "low"       # Cosmetic issues

incident_duration = Histogram(
    'incident_duration_seconds',
    'Time from detection to resolution',
    ['severity'],
    buckets=[300, 900, 1800, 3600, 7200, 14400, 28800]  # 5m to 8h
)

class Incident:
    """Track incident lifecycle."""
    
    def __init__(self, title: str, severity: Severity):
        self.id = generate_incident_id()
        self.title = title
        self.severity = severity
        self.detected_at = datetime.now()
        self.acknowledged_at = None
        self.resolved_at = None
    
    async def acknowledge(self, responder: str):
        """Mark incident as acknowledged."""
        self.acknowledged_at = datetime.now()
        
        # Time to acknowledge
        tta = (self.acknowledged_at - self.detected_at).total_seconds()
        
        await db.execute("""
            UPDATE incidents
            SET acknowledged_at = $1, responder = $2, tta_seconds = $3
            WHERE id = $4
        """, self.acknowledged_at, responder, tta, self.id)
    
    async def resolve(self, resolution: str):
        """Mark incident as resolved."""
        self.resolved_at = datetime.now()
        
        # MTTR calculation
        mttr = (self.resolved_at - self.detected_at).total_seconds()
        
        # Record metric
        incident_duration.labels(
            severity=self.severity.value
        ).observe(mttr)
        
        await db.execute("""
            UPDATE incidents
            SET resolved_at = $1, resolution = $2, mttr_seconds = $3
            WHERE id = $4
        """, self.resolved_at, resolution, mttr, self.id)
        
        print(f"✅ Incident {self.id} resolved")
        print(f"   MTTR: {mttr/60:.1f} minutes")

# MTTR analysis
async def analyze_mttr(days: int = 30):
    """Analyze MTTR trends."""
    
    query = """
        SELECT
            severity,
            COUNT(*) as incident_count,
            AVG(mttr_seconds) / 60 as avg_mttr_minutes,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mttr_seconds) / 60 as p50_minutes,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY mttr_seconds) / 60 as p95_minutes
        FROM incidents
        WHERE detected_at > NOW() - INTERVAL '${days} days'
            AND resolved_at IS NOT NULL
        GROUP BY severity
        ORDER BY avg_mttr_minutes DESC
    """
    
    results = await db.fetch(query.replace('${days}', str(days)))
    
    print(f"\n{'='*80}")
    print(f"MTTR Analysis - Last {days} Days")
    print(f"{'='*80}\n")
    
    for row in results:
        print(f"{row['severity'].upper()}:")
        print(f"  Incidents: {row['incident_count']}")
        print(f"  Avg MTTR: {row['avg_mttr_minutes']:.1f} minutes")
        print(f"  P50 MTTR: {row['p50_minutes']:.1f} minutes")
        print(f"  P95 MTTR: {row['p95_minutes']:.1f} minutes")
        print()

# Usage
await analyze_mttr(days=30)
```

**Targets (DORA Metrics - Elite):**

- SEV1 (Critical): <15 minutes
- SEV2 (High): <1 hour
- SEV3 (Medium): <4 hours
- SEV4 (Low): <24 hours

### Change Failure Rate

**Definition:** Percentage of deployments causing incidents

**Measurement:**

```promql
# Change failure rate
(
  sum(increase(deployment_events_total{status="failed"}[7d]))
  +
  sum(increase(deployment_rollback_total[7d]))
)
/
sum(increase(deployment_events_total[7d]))
```

**Tracking:**

```python
# change_failure_tracking.py
from datetime import datetime, timedelta

async def calculate_change_failure_rate(days: int = 30):
    """Calculate change failure rate."""
    
    query = """
        WITH deployment_outcomes AS (
            SELECT
                d.id as deployment_id,
                d.version,
                d.deployed_at,
                d.status as deployment_status,
                EXISTS(
                    SELECT 1 FROM incidents i
                    WHERE i.detected_at >= d.deployed_at
                        AND i.detected_at <= d.deployed_at + INTERVAL '2 hours'
                        AND i.root_cause LIKE '%deployment%'
                ) as caused_incident
            FROM deployments d
            WHERE d.deployed_at > NOW() - INTERVAL '${days} days'
                AND d.environment = 'production'
        )
        SELECT
            COUNT(*) as total_deployments,
            COUNT(*) FILTER (WHERE deployment_status = 'failed') as failed_deployments,
            COUNT(*) FILTER (WHERE caused_incident) as incident_causing_deployments,
            (
                COUNT(*) FILTER (WHERE deployment_status = 'failed' OR caused_incident)
            ) as total_failures
        FROM deployment_outcomes
    """
    
    result = await db.fetchrow(query.replace('${days}', str(days)))
    
    cfr = (result['total_failures'] / result['total_deployments']) * 100
    
    print(f"\n{'='*80}")
    print(f"Change Failure Rate - Last {days} Days")
    print(f"{'='*80}\n")
    print(f"Total deployments: {result['total_deployments']}")
    print(f"Failed deployments: {result['failed_deployments']}")
    print(f"Incident-causing deployments: {result['incident_causing_deployments']}")
    print(f"\nChange Failure Rate: {cfr:.2f}%")
    
    # DORA classification
    if cfr <= 5:
        tier = "Elite"
    elif cfr <= 10:
        tier = "High"
    elif cfr <= 15:
        tier = "Medium"
    else:
        tier = "Low"
    
    print(f"DORA Performance Tier: {tier}")
    
    return cfr

# Usage
await calculate_change_failure_rate(days=30)
```

**Targets (DORA Metrics - Elite):**

- Change failure rate: <5%
- Rollback rate: <2%
- Time to rollback: <5 minutes

## Metrics Dashboard

### Executive Dashboard

```json
{
  "dashboard": {
    "title": "Executive Metrics Dashboard",
    "refresh": "5m",
    "panels": [
      {
        "title": "Service Health",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6},
        "targets": [
          {"expr": "slo:availability:error_budget_remaining * 100", "legendFormat": "Availability"},
          {"expr": "slo:latency:p99_seconds * 1000", "legendFormat": "P99 Latency (ms)"},
          {"expr": "slo:error_rate:ratio * 100", "legendFormat": "Error Rate (%)"}
        ]
      },
      {
        "title": "Business Metrics",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12},
        "targets": [
          {"expr": "sum(increase(mcp_tool_executions_total[1d]))", "legendFormat": "Daily Tool Executions"},
          {"expr": "count(count by (user_id) (mcp_requests_total{timestamp > (time() - 2592000)}))", "legendFormat": "Monthly Active Users"},
          {"expr": "sum(increase(mcp_requests_total[1d]))", "legendFormat": "Daily API Calls"}
        ]
      },
      {
        "title": "Operational Excellence",
        "type": "table",
        "gridPos": {"h": 6, "w": 12},
        "targets": [
          {"expr": "sum(increase(deployment_events_total{status='success'}[7d]))", "legendFormat": "Deployments (7d)"},
          {"expr": "avg(incident_duration_seconds) / 60", "legendFormat": "MTTR (minutes)"},
          {"expr": "sum(increase(deployment_events_total{status='failed'}[7d])) / sum(increase(deployment_events_total[7d])) * 100", "legendFormat": "Change Failure Rate (%)"}
        ]
      }
    ]
  }
}
```

## Summary

Comprehensive metrics and KPIs track MCP server performance across three dimensions:

- **Service Level Objectives**: Availability (99.9%), latency (P99 <500ms), error rate (<0.1%) with error budget tracking
- **Business Metrics**: Tool executions, active users (DAU/WAU/MAU), API call volume, retention analysis
- **Operational Metrics**: Deployment frequency, MTTR, change failure rate aligned with DORA metrics

---

**Next**: Review [API Reference](18-api-reference.md) for complete endpoint documentation.
