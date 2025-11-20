# Integration Patterns

**Navigation**: [Home](../README.md) > Decision Support > Integration Patterns  
**Related**: [← Previous: Decision Trees](03d-decision-trees.md) | [Next: Testing Strategy →](04-testing-strategy.md) | [Cost Optimization](12-cost-optimization.md#caching-strategies-for-cost-reduction)

**Version:** 1.4.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Introduction

MCP servers often need to integrate with external services, databases, APIs, and other systems. This document covers integration patterns including REST API integration, caching strategies, circuit breakers, retry logic, and webhook handling.

For structured guidance on migrating existing REST integrations to MCP primitives and evolving database backends, see **Migration Guides (12)**.

## External API Integration

### HTTP Client Configuration

```python
# src/mcp_server/clients/http_client.py
"""Configured HTTP client for external API integration."""

import httpx
from typing import Optional, Dict, Any
from datetime import timedelta
import structlog

logger = structlog.get_logger()

class HTTPClient:
    """HTTP client with retries, timeouts, and error handling."""
    
    def __init__(
        self,
        base_url: str,
        timeout: float = 30.0,
        max_retries: int = 3,
        headers: Optional[Dict[str, str]] = None
    ):
        self.base_url = base_url
        self.timeout = timeout
        self.max_retries = max_retries
        self.default_headers = headers or {}
        
        # Create client with retry transport
        transport = httpx.HTTPTransport(retries=max_retries)
        self.client = httpx.AsyncClient(
            base_url=base_url,
            timeout=timeout,
            transport=transport,
            headers=self.default_headers
        )
    
    async def get(
        self,
        path: str,
        params: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None
    ) -> httpx.Response:
        """GET request with logging."""
        merged_headers = {**self.default_headers, **(headers or {})}
        
        logger.info(
            "http_request",
            method="GET",
            url=f"{self.base_url}{path}",
            params=params
        )
        
        try:
            response = await self.client.get(
                path,
                params=params,
                headers=merged_headers
            )
            response.raise_for_status()
            
            logger.info(
                "http_response",
                method="GET",
                url=f"{self.base_url}{path}",
                status_code=response.status_code,
                duration_ms=(response.elapsed.total_seconds() * 1000)
            )
            
            return response
            
        except httpx.HTTPStatusError as e:
            logger.error(
                "http_error",
                method="GET",
                url=f"{self.base_url}{path}",
                status_code=e.response.status_code,
                error=str(e)
            )
            raise
        except httpx.TimeoutException as e:
            logger.error(
                "http_timeout",
                method="GET",
                url=f"{self.base_url}{path}",
                timeout=self.timeout
            )
            raise
        except Exception as e:
            logger.error(
                "http_request_failed",
                method="GET",
                url=f"{self.base_url}{path}",
                error=str(e),
                exc_info=True
            )
            raise
    
    async def post(
        self,
        path: str,
        json: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None
    ) -> httpx.Response:
        """POST request with logging."""
        merged_headers = {**self.default_headers, **(headers or {})}
        
        logger.info(
            "http_request",
            method="POST",
            url=f"{self.base_url}{path}"
        )
        
        try:
            response = await self.client.post(
                path,
                json=json,
                headers=merged_headers
            )
            response.raise_for_status()
            
            logger.info(
                "http_response",
                method="POST",
                url=f"{self.base_url}{path}",
                status_code=response.status_code
            )
            
            return response
            
        except httpx.HTTPStatusError as e:
            logger.error(
                "http_error",
                method="POST",
                url=f"{self.base_url}{path}",
                status_code=e.response.status_code,
                response_body=e.response.text
            )
            raise
    
    async def close(self):
        """Close client connections."""
        await self.client.aclose()
```

### API Client Example

```python
# src/mcp_server/clients/external_api.py
"""Client for external API integration."""

from typing import List, Optional
from pydantic import BaseModel
from .http_client import HTTPClient

class ExternalResource(BaseModel):
    """External resource model."""
    id: str
    name: str
    status: str
    created_at: str

class ExternalAPIClient:
    """Client for external API."""
    
    def __init__(self, api_key: str):
        self.client = HTTPClient(
            base_url="https://api.external.com",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Accept": "application/json"
            }
        )
    
    async def get_resource(self, resource_id: str) -> ExternalResource:
        """Get resource by ID."""
        response = await self.client.get(f"/resources/{resource_id}")
        return ExternalResource(**response.json())
    
    async def list_resources(
        self,
        page: int = 1,
        page_size: int = 50
    ) -> List[ExternalResource]:
        """List resources with pagination."""
        response = await self.client.get(
            "/resources",
            params={"page": page, "page_size": page_size}
        )
        data = response.json()
        return [ExternalResource(**item) for item in data["items"]]
    
    async def create_resource(
        self,
        name: str,
        **kwargs
    ) -> ExternalResource:
        """Create new resource."""
        response = await self.client.post(
            "/resources",
            json={"name": name, **kwargs}
        )
        return ExternalResource(**response.json())
    
    async def close(self):
        """Close client."""
        await self.client.close()
```

## Caching Strategies

### Multi-Tier Cache Implementation

```python
# src/mcp_server/services/cache.py
"""Multi-tier caching service."""

import asyncio
from typing import Optional, Any, Dict
from datetime import timedelta
import redis.asyncio as redis
import pickle
import structlog

logger = structlog.get_logger()

class CacheService:
    """Multi-tier cache: in-memory L1, Redis L2."""
    
    def __init__(
        self,
        redis_url: str,
        l1_max_size: int = 1000,
        l1_ttl: int = 300,
        l2_ttl: int = 3600
    ):
        # L1: In-memory cache
        self.l1_cache: Dict[str, Any] = {}
        self.l1_max_size = l1_max_size
        self.l1_ttl = l1_ttl
        
        # L2: Redis cache
        self.redis = redis.from_url(redis_url)
        self.l2_ttl = l2_ttl
        
        # Stats
        self.l1_hits = 0
        self.l1_misses = 0
        self.l2_hits = 0
        self.l2_misses = 0
    
    async def get(self, key: str) -> Optional[Any]:
        """Get value from cache (L1 -> L2 -> None)."""
        
        # Try L1 cache first
        if key in self.l1_cache:
            self.l1_hits += 1
            logger.debug("cache_hit", tier="L1", key=key)
            return self.l1_cache[key]
        
        self.l1_misses += 1
        
        # Try L2 cache (Redis)
        try:
            value = await self.redis.get(key)
            if value:
                self.l2_hits += 1
                logger.debug("cache_hit", tier="L2", key=key)
                
                # Deserialize and populate L1
                deserialized = pickle.loads(value)
                await self._set_l1(key, deserialized)
                return deserialized
        except Exception as e:
            logger.error("cache_error", tier="L2", key=key, error=str(e))
        
        self.l2_misses += 1
        logger.debug("cache_miss", key=key)
        return None
    
    async def set(
        self,
        key: str,
        value: Any,
        ttl: Optional[int] = None
    ) -> bool:
        """Set value in both cache tiers."""
        
        # Set in L1
        await self._set_l1(key, value)
        
        # Set in L2 (Redis)
        try:
            serialized = pickle.dumps(value)
            await self.redis.setex(
                key,
                ttl or self.l2_ttl,
                serialized
            )
            logger.debug("cache_set", key=key, ttl=ttl or self.l2_ttl)
            return True
        except Exception as e:
            logger.error("cache_set_error", key=key, error=str(e))
            return False
    
    async def _set_l1(self, key: str, value: Any):
        """Set value in L1 cache with size limit."""
        # Evict oldest if at capacity
        if len(self.l1_cache) >= self.l1_max_size:
            oldest_key = next(iter(self.l1_cache))
            del self.l1_cache[oldest_key]
        
        self.l1_cache[key] = value
    
    async def delete(self, key: str) -> bool:
        """Delete from both cache tiers."""
        # Delete from L1
        if key in self.l1_cache:
            del self.l1_cache[key]
        
        # Delete from L2
        try:
            await self.redis.delete(key)
            logger.debug("cache_delete", key=key)
            return True
        except Exception as e:
            logger.error("cache_delete_error", key=key, error=str(e))
            return False
    
    async def invalidate_pattern(self, pattern: str):
        """Invalidate keys matching pattern."""
        # Clear L1 matching pattern
        keys_to_delete = [
            k for k in self.l1_cache.keys()
            if pattern in k
        ]
        for key in keys_to_delete:
            del self.l1_cache[key]
        
        # Clear L2 matching pattern
        try:
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
            
            logger.info("cache_invalidate_pattern", pattern=pattern)
        except Exception as e:
            logger.error(
                "cache_invalidate_error",
                pattern=pattern,
                error=str(e)
            )
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics."""
        total_requests = (
            self.l1_hits + self.l1_misses +
            self.l2_hits + self.l2_misses
        )
        
        return {
            "l1_size": len(self.l1_cache),
            "l1_max_size": self.l1_max_size,
            "l1_hits": self.l1_hits,
            "l1_misses": self.l1_misses,
            "l1_hit_rate": (
                self.l1_hits / total_requests if total_requests > 0 else 0
            ),
            "l2_hits": self.l2_hits,
            "l2_misses": self.l2_misses,
            "l2_hit_rate": (
                (self.l1_hits + self.l2_hits) / total_requests
                if total_requests > 0 else 0
            )
        }
    
    async def close(self):
        """Close connections."""
        await self.redis.close()

# Global cache instance
cache = CacheService(
    redis_url="redis://localhost:6379",
    l1_max_size=1000,
    l1_ttl=300,
    l2_ttl=3600
)
```

### Cache Usage Pattern

```python
from mcp_server.services.cache import cache

@mcp.tool()
async def get_assignment(assignment_id: str) -> dict:
    """Get assignment with caching."""
    
    cache_key = f"assignment:{assignment_id}"
    
    # Try cache first
    cached = await cache.get(cache_key)
    if cached:
        logger.info("assignment_from_cache", assignment_id=assignment_id)
        return {
            "success": True,
            "data": cached,
            "from_cache": True
        }
    
    # Fetch from database
    assignment = await backend.get_assignment(assignment_id)
    
    if assignment:
        # Cache for 1 hour
        await cache.set(cache_key, assignment.to_dict(), ttl=3600)
    
    return {
        "success": True,
        "data": assignment.to_dict() if assignment else None,
        "from_cache": False
    }

@mcp.tool()
async def update_assignment(assignment_id: str, **updates) -> dict:
    """Update assignment and invalidate cache."""
    
    assignment = await backend.update_assignment(assignment_id, **updates)
    
    # Invalidate cache
    await cache.delete(f"assignment:{assignment_id}")
    await cache.invalidate_pattern(f"assignments:user:*")
    
    return {
        "success": True,
        "data": assignment.to_dict()
    }
```

## Circuit Breaker Pattern

### Circuit Breaker Implementation

```python
# src/mcp_server/patterns/circuit_breaker.py
"""Circuit breaker pattern for fault tolerance."""

import asyncio
from enum import Enum
from typing import Callable, Optional, Any
from datetime import datetime, timedelta
import structlog

logger = structlog.get_logger()

class CircuitState(Enum):
    """Circuit breaker states."""
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Failing, reject requests
    HALF_OPEN = "half_open"  # Testing recovery

class CircuitBreaker:
    """Circuit breaker for external service calls."""
    
    def __init__(
        self,
        name: str,
        failure_threshold: int = 5,
        recovery_timeout: int = 60,
        success_threshold: int = 2
    ):
        self.name = name
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.success_threshold = success_threshold
        
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.success_count = 0
        self.last_failure_time: Optional[datetime] = None
        self.opened_at: Optional[datetime] = None
    
    async def call(
        self,
        func: Callable,
        *args,
        fallback: Optional[Callable] = None,
        **kwargs
    ) -> Any:
        """Execute function with circuit breaker protection."""
        
        # Check if circuit should transition to half-open
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                logger.info(
                    "circuit_breaker_half_open",
                    name=self.name
                )
                self.state = CircuitState.HALF_OPEN
                self.success_count = 0
            else:
                logger.warning(
                    "circuit_breaker_open",
                    name=self.name,
                    failure_count=self.failure_count
                )
                if fallback:
                    return await fallback(*args, **kwargs)
                raise CircuitBreakerOpenError(
                    f"Circuit breaker {self.name} is OPEN"
                )
        
        try:
            # Execute function
            result = await func(*args, **kwargs)
            
            # Record success
            await self._on_success()
            
            return result
            
        except Exception as e:
            # Record failure
            await self._on_failure()
            
            # Use fallback if available
            if fallback:
                logger.warning(
                    "circuit_breaker_fallback",
                    name=self.name,
                    error=str(e)
                )
                return await fallback(*args, **kwargs)
            
            raise
    
    async def _on_success(self):
        """Handle successful call."""
        self.failure_count = 0
        
        if self.state == CircuitState.HALF_OPEN:
            self.success_count += 1
            
            if self.success_count >= self.success_threshold:
                logger.info(
                    "circuit_breaker_closed",
                    name=self.name
                )
                self.state = CircuitState.CLOSED
                self.success_count = 0
                self.opened_at = None
    
    async def _on_failure(self):
        """Handle failed call."""
        self.failure_count += 1
        self.last_failure_time = datetime.utcnow()
        
        if self.state == CircuitState.HALF_OPEN:
            logger.warning(
                "circuit_breaker_reopened",
                name=self.name
            )
            self.state = CircuitState.OPEN
            self.opened_at = datetime.utcnow()
            self.success_count = 0
        
        elif self.failure_count >= self.failure_threshold:
            logger.error(
                "circuit_breaker_opened",
                name=self.name,
                failure_count=self.failure_count
            )
            self.state = CircuitState.OPEN
            self.opened_at = datetime.utcnow()
    
    def _should_attempt_reset(self) -> bool:
        """Check if circuit should attempt reset."""
        if not self.opened_at:
            return False
        
        elapsed = (datetime.utcnow() - self.opened_at).total_seconds()
        return elapsed >= self.recovery_timeout
    
    def get_state(self) -> dict:
        """Get circuit breaker state."""
        return {
            "name": self.name,
            "state": self.state.value,
            "failure_count": self.failure_count,
            "success_count": self.success_count,
            "opened_at": self.opened_at.isoformat() if self.opened_at else None,
            "last_failure": (
                self.last_failure_time.isoformat()
                if self.last_failure_time else None
            )
        }

class CircuitBreakerOpenError(Exception):
    """Exception raised when circuit breaker is open."""
    pass
```

### Circuit Breaker Usage

```python
from mcp_server.patterns.circuit_breaker import CircuitBreaker

# Create circuit breaker for external API
external_api_breaker = CircuitBreaker(
    name="external_api",
    failure_threshold=5,
    recovery_timeout=60,
    success_threshold=2
)

async def fetch_external_data_fallback() -> dict:
    """Fallback when external API is unavailable."""
    logger.warning("using_fallback_data")
    return {"data": [], "from_fallback": True}

@mcp.tool()
async def get_external_data() -> dict:
    """Get data from external API with circuit breaker."""
    
    async def fetch():
        async with httpx.AsyncClient() as client:
            response = await client.get("https://api.external.com/data")
            response.raise_for_status()
            return response.json()
    
    try:
        data = await external_api_breaker.call(
            fetch,
            fallback=fetch_external_data_fallback
        )
        
        return {
            "success": True,
            "data": data
        }
        
    except CircuitBreakerOpenError:
        return {
            "success": False,
            "error": "external_api_unavailable",
            "message": "External API is temporarily unavailable"
        }
```

## Retry Logic

### Exponential Backoff with Jitter

```python
# src/mcp_server/patterns/retry.py
"""Retry logic with exponential backoff."""

import asyncio
import random
from typing import Callable, Optional, Any, Type
from datetime import timedelta
import structlog

logger = structlog.get_logger()

async def retry_with_backoff(
    func: Callable,
    *args,
    max_attempts: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 60.0,
    exponential_base: float = 2.0,
    jitter: bool = True,
    retry_on: tuple[Type[Exception], ...] = (Exception,),
    **kwargs
) -> Any:
    """
    Retry function with exponential backoff and jitter.
    
    Args:
        func: Async function to retry
        max_attempts: Maximum number of attempts
        base_delay: Initial delay between retries (seconds)
        max_delay: Maximum delay between retries (seconds)
        exponential_base: Base for exponential backoff
        jitter: Add random jitter to delay
        retry_on: Tuple of exceptions to retry on
    """
    
    last_exception = None
    
    for attempt in range(1, max_attempts + 1):
        try:
            result = await func(*args, **kwargs)
            
            if attempt > 1:
                logger.info(
                    "retry_success",
                    func=func.__name__,
                    attempt=attempt
                )
            
            return result
            
        except retry_on as e:
            last_exception = e
            
            if attempt == max_attempts:
                logger.error(
                    "retry_exhausted",
                    func=func.__name__,
                    attempts=attempt,
                    error=str(e)
                )
                raise
            
            # Calculate delay with exponential backoff
            delay = min(
                base_delay * (exponential_base ** (attempt - 1)),
                max_delay
            )
            
            # Add jitter
            if jitter:
                delay = delay * (0.5 + random.random() * 0.5)
            
            logger.warning(
                "retry_attempt",
                func=func.__name__,
                attempt=attempt,
                max_attempts=max_attempts,
                delay=delay,
                error=str(e)
            )
            
            await asyncio.sleep(delay)
    
    # Should never reach here, but just in case
    if last_exception:
        raise last_exception

# Usage example
@mcp.tool()
async def create_external_resource(name: str) -> dict:
    """Create resource with retry logic."""
    
    async def create():
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.external.com/resources",
                json={"name": name}
            )
            response.raise_for_status()
            return response.json()
    
    try:
        result = await retry_with_backoff(
            create,
            max_attempts=3,
            base_delay=1.0,
            retry_on=(httpx.HTTPStatusError, httpx.TimeoutException)
        )
        
        return {
            "success": True,
            "data": result
        }
        
    except Exception as e:
        logger.error("create_resource_failed", error=str(e))
        return {
            "success": False,
            "error": "failed_to_create_resource"
        }
```

## Webhook Handling

### Webhook Receiver

```python
# src/mcp_server/webhooks.py
"""Webhook receiver for external events."""

from fastapi import APIRouter, Request, HTTPException, Header
from typing import Optional
import hmac
import hashlib
import structlog

logger = structlog.get_logger()
router = APIRouter()

async def verify_webhook_signature(
    payload: bytes,
    signature: str,
    secret: str
) -> bool:
    """Verify webhook signature."""
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected)

@router.post("/webhooks/external-service")
async def handle_external_webhook(
    request: Request,
    x_signature: Optional[str] = Header(None)
):
    """Handle webhook from external service."""
    
    # Get raw body for signature verification
    body = await request.body()
    
    # Verify signature
    webhook_secret = config.external_service_webhook_secret
    if not await verify_webhook_signature(body, x_signature, webhook_secret):
        logger.warning("webhook_invalid_signature")
        raise HTTPException(status_code=401, detail="Invalid signature")
    
    # Parse JSON
    payload = await request.json()
    event_type = payload.get("event_type")
    
    logger.info(
        "webhook_received",
        event_type=event_type,
        payload_size=len(body)
    )
    
    # Process event
    if event_type == "resource.created":
        await handle_resource_created(payload["data"])
    elif event_type == "resource.updated":
        await handle_resource_updated(payload["data"])
    elif event_type == "resource.deleted":
        await handle_resource_deleted(payload["data"])
    else:
        logger.warning("webhook_unknown_event", event_type=event_type)
    
    return {"status": "processed"}

async def handle_resource_created(data: dict):
    """Handle resource created event."""
    logger.info("resource_created", resource_id=data["id"])
    
    # Invalidate cache
    await cache.invalidate_pattern("resources:*")
    
    # Trigger follow-up actions
    await trigger_resource_sync(data["id"])

async def handle_resource_updated(data: dict):
    """Handle resource updated event."""
    logger.info("resource_updated", resource_id=data["id"])
    await cache.delete(f"resource:{data['id']}")

async def handle_resource_deleted(data: dict):
    """Handle resource deleted event."""
    logger.info("resource_deleted", resource_id=data["id"])
    await cache.delete(f"resource:{data['id']}")
```

## Summary

Effective integration patterns ensure:

- **HTTP Client**: Configured client with retries, timeouts, and logging
- **Caching**: Multi-tier cache (L1 in-memory, L2 Redis) for performance
- **Circuit Breaker**: Fault tolerance for external service failures
- **Retry Logic**: Exponential backoff with jitter for transient failures
- **Webhooks**: Secure webhook handling for event-driven integration

---

**Next**: Review [Agentic Best Practices](09-agentic-best-practices.md) for AI agent integration patterns.
