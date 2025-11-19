# Performance & Scalability

**Version:** 1.0.0  
**Last Updated:** November 18, 2025  
**Status:** Draft

## Introduction

This document provides guidance on building performant and scalable MCP servers. Topics include async I/O patterns, connection pooling, caching strategies, batch operations, and backpressure handling.

## Async I/O Patterns

### When to Use AsyncIO

```python
# ✅ Good - I/O bound operations benefit from async
@mcp.tool()
async def fetch_user_data(user_ids: list[str]) -> dict:
    """Fetch multiple users concurrently."""
    async with httpx.AsyncClient() as client:
        # Concurrent I/O operations
        tasks = [
            client.get(f"https://api.example.com/users/{uid}")
            for uid in user_ids
        ]
        responses = await asyncio.gather(*tasks)
    
    return {"users": [r.json() for r in responses]}

# ❌ Bad - CPU-bound work blocks event loop
@mcp.tool()
async def process_large_dataset(data: list) -> dict:
    """CPU-intensive operation."""
    # This blocks the event loop!
    result = expensive_computation(data)  # Synchronous CPU work
    return {"result": result}

# ✅ Good - Use thread pool for CPU work
@mcp.tool()
async def process_large_dataset(data: list) -> dict:
    """CPU-intensive operation in thread pool."""
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        None,  # Uses default ThreadPoolExecutor
        expensive_computation,
        data
    )
    return {"result": result}
```

### Async Best Practices

**DO:**

- Use `async`/`await` for I/O operations (network, disk, database)
- Use `asyncio.gather()` for concurrent independent operations
- Set timeouts on all external calls
- Use connection pooling for frequently accessed resources

**DON'T:**

- Use `async` for CPU-intensive computations
- Block the event loop with `time.sleep()` (use `asyncio.sleep()`)
- Create unbounded concurrent tasks (use semaphores)
- Forget to handle task cancellation

### Concurrency Control

```python
import asyncio
from asyncio import Semaphore

# Limit concurrent external API calls
API_SEMAPHORE = Semaphore(10)  # Max 10 concurrent calls

@mcp.tool()
async def fetch_with_limit(urls: list[str]) -> list[dict]:
    """Fetch URLs with concurrency limit."""
    
    async def fetch_one(url: str) -> dict:
        async with API_SEMAPHORE:  # Acquire semaphore
            async with httpx.AsyncClient() as client:
                response = await client.get(url, timeout=30.0)
                return response.json()
    
    results = await asyncio.gather(
        *[fetch_one(url) for url in urls],
        return_exceptions=True  # Don't fail all if one fails
    )
    
    return [r for r in results if not isinstance(r, Exception)]
```

## Connection Pooling

### Database Connection Pool

```python
# src/mcp_server/database.py
"""Database connection pool configuration."""

import asyncpg
from typing import Optional

class DatabasePool:
    """Async database connection pool."""
    
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None
    
    async def initialize(
        self,
        dsn: str,
        min_size: int = 10,
        max_size: int = 20,
        max_queries: int = 50000,
        max_inactive_connection_lifetime: float = 300.0
    ):
        """Initialize connection pool."""
        self.pool = await asyncpg.create_pool(
            dsn=dsn,
            min_size=min_size,  # Keep 10 connections warm
            max_size=max_size,  # Max 20 concurrent connections
            max_queries=max_queries,  # Recycle after 50k queries
            max_inactive_connection_lifetime=max_inactive_connection_lifetime,  # 5min
            command_timeout=30.0,  # 30s query timeout
        )
    
    async def close(self):
        """Close pool gracefully."""
        if self.pool:
            await self.pool.close()
    
    async def fetch(self, query: str, *args):
        """Execute query from pool."""
        async with self.pool.acquire() as connection:
            return await connection.fetch(query, *args)
    
    async def execute(self, query: str, *args):
        """Execute non-query from pool."""
        async with self.pool.acquire() as connection:
            return await connection.execute(query, *args)

# Global pool instance
db_pool = DatabasePool()

# Initialize on startup
@mcp.on_startup
async def startup():
    await db_pool.initialize(
        dsn=os.getenv("DATABASE_URL"),
        min_size=10,
        max_size=20
    )

# Usage in tools
@mcp.tool()
async def get_user(user_id: str) -> dict:
    """Get user from database."""
    row = await db_pool.fetch(
        "SELECT * FROM users WHERE id = $1",
        user_id
    )
    return dict(row[0]) if row else None
```

### HTTP Client Pool

```python
# src/mcp_server/http_pool.py
"""Shared HTTP client with connection pooling."""

import httpx
from typing import Optional

class HTTPClientPool:
    """Shared async HTTP client."""
    
    def __init__(self):
        self.client: Optional[httpx.AsyncClient] = None
    
    async def initialize(self):
        """Initialize shared client."""
        # Connection pool limits
        limits = httpx.Limits(
            max_connections=100,  # Total pool size
            max_keepalive_connections=20,  # Keep-alive pool
            keepalive_expiry=30.0  # 30s keep-alive
        )
        
        self.client = httpx.AsyncClient(
            limits=limits,
            timeout=30.0,
            follow_redirects=True,
            http2=True  # Enable HTTP/2
        )
    
    async def close(self):
        """Close client gracefully."""
        if self.client:
            await self.client.aclose()
    
    async def get(self, url: str, **kwargs):
        """GET request."""
        return await self.client.get(url, **kwargs)
    
    async def post(self, url: str, **kwargs):
        """POST request."""
        return await self.client.post(url, **kwargs)

# Global client
http_pool = HTTPClientPool()

@mcp.on_startup
async def startup():
    await http_pool.initialize()

@mcp.on_shutdown
async def shutdown():
    await http_pool.close()
```

## Caching Strategies

### Tool Result Caching

```python
# src/mcp_server/cache.py
"""Result caching for expensive tools."""

import hashlib
import json
from typing import Any, Optional
from functools import wraps
import asyncio

class ResultCache:
    """In-memory result cache with TTL."""
    
    def __init__(self):
        self._cache: dict[str, tuple[Any, float]] = {}
        self._lock = asyncio.Lock()
    
    def _make_key(self, tool_name: str, params: dict) -> str:
        """Generate cache key from tool and params."""
        stable_params = json.dumps(params, sort_keys=True)
        param_hash = hashlib.sha256(stable_params.encode()).hexdigest()
        return f"tool:{tool_name}:{param_hash}"
    
    async def get(self, tool_name: str, params: dict) -> Optional[Any]:
        """Get cached result."""
        key = self._make_key(tool_name, params)
        async with self._lock:
            if key in self._cache:
                result, expiry = self._cache[key]
                if asyncio.get_event_loop().time() < expiry:
                    return result
                else:
                    # Expired
                    del self._cache[key]
        return None
    
    async def set(
        self,
        tool_name: str,
        params: dict,
        result: Any,
        ttl: int = 300
    ):
        """Set cached result with TTL."""
        key = self._make_key(tool_name, params)
        expiry = asyncio.get_event_loop().time() + ttl
        async with self._lock:
            self._cache[key] = (result, expiry)
    
    async def clear_expired(self):
        """Remove expired entries."""
        now = asyncio.get_event_loop().time()
        async with self._lock:
            expired = [
                k for k, (_, expiry) in self._cache.items()
                if expiry < now
            ]
            for k in expired:
                del self._cache[k]

# Global cache
result_cache = ResultCache()

# Cache decorator
def cached(ttl: int = 300):
    """Decorator to cache tool results."""
    def decorator(func):
        @wraps(func)
        async def wrapper(**kwargs):
            # Check cache
            cached_result = await result_cache.get(func.__name__, kwargs)
            if cached_result is not None:
                return cached_result
            
            # Execute tool
            result = await func(**kwargs)
            
            # Cache result
            await result_cache.set(func.__name__, kwargs, result, ttl)
            
            return result
        return wrapper
    return decorator

# Usage
@mcp.tool()
@cached(ttl=600)  # Cache for 10 minutes
async def get_org_structure() -> dict:
    """
    Get organization structure (expensive, slow-changing).
    Cached for 10 minutes.
    """
    return await backend.fetch_org_structure()
```

### When to Cache

**✅ Cache These:**

- Static resources (documentation, schemas)
- Slow-changing data (org structure, configuration)
- Expensive queries with TTL tolerance
- External API responses with rate limits
- Computed aggregations (reports, summaries)

**❌ Don't Cache These:**

- Real-time data (live metrics, current status)
- User-specific sensitive data (PII)
- Transaction-critical operations
- Frequently changing data
- Large result sets (memory pressure)

### Redis-Backed Caching

```python
# src/mcp_server/redis_cache.py
"""Redis-backed distributed cache."""

import redis.asyncio as redis
import json
from typing import Any, Optional

class RedisCache:
    """Distributed cache using Redis."""
    
    def __init__(self):
        self.redis: Optional[redis.Redis] = None
    
    async def initialize(self, url: str):
        """Initialize Redis connection."""
        self.redis = await redis.from_url(
            url,
            encoding="utf-8",
            decode_responses=True,
            max_connections=20
        )
    
    async def get(self, key: str) -> Optional[Any]:
        """Get cached value."""
        value = await self.redis.get(key)
        return json.loads(value) if value else None
    
    async def set(
        self,
        key: str,
        value: Any,
        ttl: int = 300
    ):
        """Set cached value with TTL."""
        await self.redis.setex(
            key,
            ttl,
            json.dumps(value)
        )
    
    async def delete(self, key: str):
        """Delete cached value."""
        await self.redis.delete(key)
    
    async def clear_pattern(self, pattern: str):
        """Clear keys matching pattern."""
        cursor = 0
        while True:
            cursor, keys = await self.redis.scan(
                cursor,
                match=pattern,
                count=100
            )
            if keys:
                await self.redis.delete(*keys)
            if cursor == 0:
                break

# Global Redis cache
redis_cache = RedisCache()
```

## Batch Operations

### Batching Pattern

```python
@mcp.tool()
async def batch_create_assignments(
    assignments: list[dict]
) -> dict:
    """
    Create multiple assignments in one operation.
    More efficient than N individual create_assignment calls.
    """
    # Validate all upfront
    errors = []
    for i, assignment in enumerate(assignments):
        if not assignment.get("title"):
            errors.append({"index": i, "error": "missing title"})
    
    if errors:
        return {"success": False, "errors": errors}
    
    # Batch database insert
    async with db_pool.pool.acquire() as conn:
        async with conn.transaction():
            results = await conn.executemany(
                """
                INSERT INTO assignments (title, assignee, priority)
                VALUES ($1, $2, $3)
                RETURNING id
                """,
                [
                    (a["title"], a["assignee"], a.get("priority", 3))
                    for a in assignments
                ]
            )
    
    return {
        "success": True,
        "created": len(results),
        "ids": [r["id"] for r in results]
    }
```

### DataLoader Pattern

```python
# src/mcp_server/dataloader.py
"""DataLoader pattern for batching/caching."""

from typing import Callable, Any
import asyncio

class DataLoader:
    """Batch and cache data loading."""
    
    def __init__(
        self,
        batch_fn: Callable[[list], list],
        max_batch_size: int = 100
    ):
        self.batch_fn = batch_fn
        self.max_batch_size = max_batch_size
        self._queue: list = []
        self._cache: dict = {}
        self._batch_task = None
    
    async def load(self, key: Any) -> Any:
        """Load single item (batched automatically)."""
        # Check cache
        if key in self._cache:
            return self._cache[key]
        
        # Add to batch queue
        future = asyncio.Future()
        self._queue.append((key, future))
        
        # Schedule batch execution
        if self._batch_task is None:
            self._batch_task = asyncio.create_task(self._dispatch_batch())
        
        return await future
    
    async def _dispatch_batch(self):
        """Execute batched load."""
        await asyncio.sleep(0.01)  # Small delay to collect batch
        
        if not self._queue:
            self._batch_task = None
            return
        
        # Take batch
        batch = self._queue[:self.max_batch_size]
        self._queue = self._queue[self.max_batch_size:]
        
        keys = [k for k, _ in batch]
        futures = [f for _, f in batch]
        
        try:
            # Execute batch load
            results = await self.batch_fn(keys)
            
            # Cache and resolve futures
            for key, result, future in zip(keys, results, futures):
                self._cache[key] = result
                future.set_result(result)
        
        except Exception as e:
            # Fail all futures
            for _, future in batch:
                future.set_exception(e)
        
        finally:
            self._batch_task = None
            
            # Dispatch next batch if queue not empty
            if self._queue:
                self._batch_task = asyncio.create_task(self._dispatch_batch())

# Usage
async def batch_load_users(user_ids: list[str]) -> list[dict]:
    """Batch load users from database."""
    query = "SELECT * FROM users WHERE id = ANY($1)"
    rows = await db_pool.fetch(query, user_ids)
    return [dict(r) for r in rows]

user_loader = DataLoader(batch_load_users)

@mcp.tool()
async def get_user_details(user_id: str) -> dict:
    """Get user (automatically batched)."""
    return await user_loader.load(user_id)
```

## Backpressure Handling

### Request Queue Depth Limiting

```python
# src/mcp_server/backpressure.py
"""Backpressure and load shedding."""

from asyncio import Queue, QueueFull
import time

class BackpressureQueue:
    """Queue with backpressure signaling."""
    
    def __init__(self, maxsize: int = 1000):
        self.queue = Queue(maxsize=maxsize)
        self.rejected_count = 0
    
    async def enqueue(self, item: Any, timeout: float = 1.0) -> bool:
        """
        Enqueue item with timeout.
        Returns False if queue full (backpressure).
        """
        try:
            await asyncio.wait_for(
                self.queue.put(item),
                timeout=timeout
            )
            return True
        except asyncio.TimeoutError:
            self.rejected_count += 1
            return False
    
    async def dequeue(self) -> Any:
        """Dequeue item."""
        return await self.queue.get()
    
    def qsize(self) -> int:
        """Current queue size."""
        return self.queue.qsize()
    
    def is_healthy(self) -> bool:
        """Check if queue is healthy (not overloaded)."""
        utilization = self.qsize() / self.queue.maxsize
        return utilization < 0.8  # 80% threshold

# Global request queue
request_queue = BackpressureQueue(maxsize=1000)

# Middleware to enforce backpressure
@mcp.middleware
async def backpressure_middleware(request, call_next):
    """Reject requests when queue full."""
    
    if not request_queue.is_healthy():
        # Shed load - return 503
        return {
            "error": "server_overloaded",
            "message": "Server at capacity, try again later",
            "retry_after": 10
        }, 503
    
    # Enqueue request
    future = asyncio.Future()
    enqueued = await request_queue.enqueue((request, future))
    
    if not enqueued:
        return {
            "error": "request_timeout",
            "message": "Request queue full"
        }, 503
    
    # Wait for result
    return await future
```

### Circuit Breaker Pattern

```python
# src/mcp_server/circuit_breaker.py
"""Circuit breaker for external dependencies."""

from enum import Enum
import time

class CircuitState(Enum):
    CLOSED = "closed"  # Normal operation
    OPEN = "open"      # Failing, reject requests
    HALF_OPEN = "half_open"  # Testing recovery

class CircuitBreaker:
    """Circuit breaker implementation."""
    
    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: float = 60.0,
        expected_exception: type = Exception
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        
        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED
    
    def call(self, func, *args, **kwargs):
        """Execute function with circuit breaker."""
        
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self.state = CircuitState.HALF_OPEN
            else:
                raise Exception("Circuit breaker is OPEN")
        
        try:
            result = func(*args, **kwargs)
            self._on_success()
            return result
        
        except self.expected_exception as e:
            self._on_failure()
            raise
    
    def _on_success(self):
        """Reset on successful call."""
        self.failure_count = 0
        self.state = CircuitState.CLOSED
    
    def _on_failure(self):
        """Handle failure."""
        self.failure_count += 1
        self.last_failure_time = time.time()
        
        if self.failure_count >= self.failure_threshold:
            self.state = CircuitState.OPEN
    
    def _should_attempt_reset(self) -> bool:
        """Check if recovery timeout elapsed."""
        return (
            self.last_failure_time is not None and
            time.time() - self.last_failure_time >= self.recovery_timeout
        )

# Usage
external_api_breaker = CircuitBreaker(
    failure_threshold=5,
    recovery_timeout=60.0
)

@mcp.tool()
async def call_external_api(endpoint: str) -> dict:
    """Call external API with circuit breaker."""
    try:
        result = external_api_breaker.call(
            lambda: http_pool.get(f"https://api.example.com/{endpoint}")
        )
        return {"success": True, "data": result}
    except Exception as e:
        return {"success": False, "error": "service_unavailable"}
```

## Performance Monitoring

### Key Metrics

```python
# Track these performance metrics
METRICS = {
    "tool_execution_duration_seconds": Histogram(
        "tool_execution_duration_seconds",
        "Tool execution time",
        ["tool_name", "status"]
    ),
    "concurrent_requests": Gauge(
        "concurrent_requests",
        "Current concurrent requests"
    ),
    "queue_depth": Gauge(
        "queue_depth",
        "Request queue depth"
    ),
    "cache_hit_ratio": Gauge(
        "cache_hit_ratio",
        "Cache hit ratio",
        ["cache_type"]
    ),
    "db_connection_pool_size": Gauge(
        "db_connection_pool_size",
        "Database connection pool utilization"
    )
}
```

### Performance Testing

```python
# tests/performance/test_load.py
"""Load testing for MCP server."""

import asyncio
import time

async def load_test_tool(
    tool_name: str,
    params: dict,
    concurrent_requests: int = 100,
    duration_seconds: int = 60
):
    """Load test a specific tool."""
    
    results = {
        "total_requests": 0,
        "successful": 0,
        "failed": 0,
        "latencies": []
    }
    
    async def make_request():
        start = time.time()
        try:
            await mcp.call_tool(tool_name, params)
            results["successful"] += 1
        except Exception:
            results["failed"] += 1
        finally:
            results["latencies"].append(time.time() - start)
            results["total_requests"] += 1
    
    # Run concurrent requests for duration
    end_time = time.time() + duration_seconds
    
    while time.time() < end_time:
        tasks = [make_request() for _ in range(concurrent_requests)]
        await asyncio.gather(*tasks, return_exceptions=True)
    
    # Calculate statistics
    latencies = sorted(results["latencies"])
    n = len(latencies)
    
    return {
        "total_requests": results["total_requests"],
        "successful": results["successful"],
        "failed": results["failed"],
        "requests_per_second": results["total_requests"] / duration_seconds,
        "latency_p50": latencies[int(n * 0.50)],
        "latency_p95": latencies[int(n * 0.95)],
        "latency_p99": latencies[int(n * 0.99)],
    }
```

## Summary

Key performance principles:

1. **Use async for I/O, threads for CPU work**
2. **Pool connections, don't create per-request**
3. **Cache expensive operations with appropriate TTL**
4. **Batch operations when possible**
5. **Implement backpressure before overload occurs**
6. **Monitor and alert on performance metrics**
7. **Load test before production deployment**
