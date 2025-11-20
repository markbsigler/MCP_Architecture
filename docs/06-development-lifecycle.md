# Development Lifecycle

**Version:** 1.3.0  
**Last Updated:** November 19, 2025  
**Status:** Draft

## Introduction

Establishing a consistent development lifecycle ensures maintainability, collaboration, and quality across MCP server projects. This document covers project structure, configuration management, dependency management, version control, and development workflows.

## Project Structure

### Standard Directory Layout

```text
mcp-server/
├── .github/
│   └── workflows/
│       ├── test.yml
│       ├── lint.yml
│       └── deploy.yml
├── src/
│   └── mcp_server/
│       ├── __init__.py
│       ├── __main__.py
│       ├── server.py
│       ├── config.py
│       ├── tools/
│       │   ├── __init__.py
│       │   ├── assignments.py
│       │   ├── releases.py
│       │   └── deployments.py
│       ├── models/
│       │   ├── __init__.py
│       │   ├── assignment.py
│       │   └── release.py
│       ├── services/
│       │   ├── __init__.py
│       │   ├── backend.py
│       │   ├── auth.py
│       │   └── cache.py
│       ├── middleware/
│       │   ├── __init__.py
│       │   ├── auth.py
│       │   ├── rate_limit.py
│       │   └── logging.py
│       └── utils/
│           ├── __init__.py
│           ├── validation.py
│           └── formatting.py
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── e2e/
│   ├── conftest.py
│   └── fixtures/
├── docs/
│   ├── architecture.md
│   ├── api.md
│   └── deployment.md
├── config/
│   ├── development.yaml
│   ├── staging.yaml
│   └── production.yaml
├── scripts/
│   ├── setup.sh
│   ├── migrate.py
│   └── seed_data.py
├── .gitignore
├── .dockerignore
├── Dockerfile
├── docker-compose.yml
├── pyproject.toml
├── requirements.txt
├── requirements-dev.txt
├── README.md
├── CHANGELOG.md
└── LICENSE
```

### Module Organization

```python
# src/mcp_server/__init__.py
"""
MCP Server Package.

This package provides tools for managing assignments, releases,
and deployments through the Model Context Protocol.
"""

__version__ = "1.0.0"
__author__ = "Your Team"

from .server import create_server
from .config import Config

__all__ = ["create_server", "Config"]
```

```python
# src/mcp_server/tools/__init__.py
"""Tool implementations."""

from .assignments import (
    create_assignment,
    get_assignment,
    list_assignments,
    update_assignment,
    delete_assignment
)
from .releases import (
    create_release,
    get_release,
    list_releases
)

__all__ = [
    # Assignments
    "create_assignment",
    "get_assignment",
    "list_assignments",
    "update_assignment",
    "delete_assignment",
    # Releases
    "create_release",
    "get_release",
    "list_releases",
]
```

## Configuration Management

### Configuration Structure

```python
# src/mcp_server/config.py
from pydantic import BaseModel, Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
from enum import Enum

class Environment(str, Enum):
    """Deployment environment."""
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"

class DatabaseConfig(BaseModel):
    """Database configuration."""
    host: str = Field(..., description="Database host")
    port: int = Field(5432, description="Database port")
    database: str = Field(..., description="Database name")
    username: str = Field(..., description="Database username")
    password: SecretStr = Field(..., description="Database password")
    pool_size: int = Field(10, ge=1, le=100)
    max_overflow: int = Field(20, ge=0)
    
    @property
    def connection_string(self) -> str:
        """Generate database connection string."""
        return (
            f"postgresql+asyncpg://{self.username}:"
            f"{self.password.get_secret_value()}@"
            f"{self.host}:{self.port}/{self.database}"
        )

class CacheConfig(BaseModel):
    """Cache configuration."""
    host: str = Field("localhost", description="Redis host")
    port: int = Field(6379, description="Redis port")
    password: Optional[SecretStr] = None
    db: int = Field(0, ge=0, le=15)
    ttl_seconds: int = Field(3600, ge=0)

class AuthConfig(BaseModel):
    """Authentication configuration."""
    jwt_secret: SecretStr = Field(..., description="JWT signing secret")
    jwt_algorithm: str = Field("HS256", description="JWT algorithm")
    jwt_expiry_minutes: int = Field(60, ge=1)
    jwks_url: Optional[str] = None
    oauth_client_id: Optional[str] = None
    oauth_client_secret: Optional[SecretStr] = None

class RateLimitConfig(BaseModel):
    """Rate limiting configuration."""
    enabled: bool = Field(True, description="Enable rate limiting")
    requests_per_minute: int = Field(60, ge=1)
    burst_size: int = Field(10, ge=1)

class ObservabilityConfig(BaseModel):
    """Observability configuration."""
    log_level: str = Field("INFO", description="Logging level")
    log_format: str = Field("json", description="Log format: json or text")
    jaeger_host: Optional[str] = None
    jaeger_port: Optional[int] = 6831
    prometheus_port: int = Field(9090, ge=1024)
    enable_tracing: bool = Field(True)

class Config(BaseSettings):
    """Application configuration."""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_nested_delimiter="__",
        case_sensitive=False
    )
    
    # Environment
    environment: Environment = Field(
        Environment.DEVELOPMENT,
        description="Deployment environment"
    )
    
    # Server
    host: str = Field("0.0.0.0", description="Server host")
    port: int = Field(8000, ge=1024, le=65535)
    debug: bool = Field(False, description="Enable debug mode")
    
    # Database
    database: DatabaseConfig
    
    # Cache
    cache: CacheConfig = Field(default_factory=CacheConfig)
    
    # Authentication
    auth: AuthConfig
    
    # Rate Limiting
    rate_limit: RateLimitConfig = Field(default_factory=RateLimitConfig)
    
    # Observability
    observability: ObservabilityConfig = Field(
        default_factory=ObservabilityConfig
    )
    
    @classmethod
    def from_yaml(cls, path: str) -> "Config":
        """Load configuration from YAML file."""
        import yaml
        with open(path) as f:
            data = yaml.safe_load(f)
        return cls(**data)
    
    @classmethod
    def get_config(cls) -> "Config":
        """Get configuration for current environment."""
        import os
        env = os.getenv("ENVIRONMENT", "development")
        config_path = f"config/{env}.yaml"
        
        if os.path.exists(config_path):
            return cls.from_yaml(config_path)
        return cls()

# Global config instance
config = Config.get_config()
```

### Environment-Specific Configuration

```yaml
# config/development.yaml
environment: development
debug: true

host: localhost
port: 8000

database:
  host: localhost
  port: 5432
  database: mcp_dev
  username: dev_user
  password: dev_password
  pool_size: 5
  max_overflow: 10

cache:
  host: localhost
  port: 6379
  db: 0
  ttl_seconds: 300

auth:
  jwt_secret: dev-secret-key-change-in-production
  jwt_algorithm: HS256
  jwt_expiry_minutes: 60

rate_limit:
  enabled: true
  requests_per_minute: 100
  burst_size: 20

observability:
  log_level: DEBUG
  log_format: text
  enable_tracing: true
  prometheus_port: 9090
```

```yaml
# config/production.yaml
environment: production
debug: false

host: 0.0.0.0
port: 8000

database:
  host: ${DB_HOST}
  port: 5432
  database: ${DB_NAME}
  username: ${DB_USER}
  password: ${DB_PASSWORD}
  pool_size: 20
  max_overflow: 40

cache:
  host: ${REDIS_HOST}
  port: 6379
  password: ${REDIS_PASSWORD}
  db: 0
  ttl_seconds: 3600

auth:
  jwt_secret: ${JWT_SECRET}
  jwt_algorithm: RS256
  jwt_expiry_minutes: 30
  jwks_url: ${JWKS_URL}
  oauth_client_id: ${OAUTH_CLIENT_ID}
  oauth_client_secret: ${OAUTH_CLIENT_SECRET}

rate_limit:
  enabled: true
  requests_per_minute: 60
  burst_size: 10

observability:
  log_level: INFO
  log_format: json
  enable_tracing: true
  jaeger_host: jaeger
  jaeger_port: 6831
  prometheus_port: 9090
```

### Secrets Management

```python
# Use environment variables for secrets in production
import os
from typing import Optional

def get_secret(name: str) -> Optional[str]:
    """
    Get secret from environment or secrets manager.
    
    Priority:
    1. Environment variable
    2. AWS Secrets Manager (if available)
    3. Azure Key Vault (if available)
    """
    # Try environment variable first
    value = os.getenv(name)
    if value:
        return value
    
    # Try AWS Secrets Manager
    try:
        import boto3
        client = boto3.client('secretsmanager')
        response = client.get_secret_value(SecretId=name)
        return response['SecretString']
    except:
        pass
    
    # Try Azure Key Vault
    try:
        from azure.identity import DefaultAzureCredential
        from azure.keyvault.secrets import SecretClient
        
        vault_url = os.getenv('AZURE_KEYVAULT_URL')
        if vault_url:
            credential = DefaultAzureCredential()
            client = SecretClient(vault_url=vault_url, credential=credential)
            secret = client.get_secret(name)
            return secret.value
    except:
        pass
    
    return None
```

## Dependency Management

### Requirements Files

```txt
# requirements.txt - Production dependencies
fastmcp==1.2.0
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.3
pydantic-settings==2.1.0
sqlalchemy[asyncio]==2.0.25
asyncpg==0.29.0
redis[hiredis]==5.0.1
httpx==0.26.0
structlog==24.1.0
python-json-logger==2.0.7
opentelemetry-api==1.22.0
opentelemetry-sdk==1.22.0
opentelemetry-instrumentation-fastapi==0.43b0
opentelemetry-exporter-jaeger==1.22.0
prometheus-client==0.19.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
```

```txt
# requirements-dev.txt - Development dependencies
-r requirements.txt

# Testing
pytest==7.4.4
pytest-asyncio==0.23.3
pytest-cov==4.1.0
pytest-mock==3.12.0
httpx==0.26.0
testcontainers==3.7.1

# Linting & Formatting
ruff==0.1.14
black==24.1.1
mypy==1.8.0
pylint==3.0.3

# Documentation
mkdocs==1.5.3
mkdocs-material==9.5.6

# Development Tools
ipython==8.20.0
ipdb==0.13.13
watchdog==3.0.0
```

### Python Package Configuration

```toml
# pyproject.toml
[build-system]
requires = ["setuptools>=68.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "mcp-server"
version = "1.0.0"
description = "MCP Server for assignment and release management"
readme = "README.md"
requires-python = ">=3.11"
license = {text = "MIT"}
authors = [
    {name = "Your Team", email = "team@example.com"}
]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
]
dependencies = [
    "fastmcp>=1.2.0",
    "fastapi>=0.109.0",
    "uvicorn[standard]>=0.27.0",
    "pydantic>=2.5.3",
    "sqlalchemy[asyncio]>=2.0.25",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.4",
    "pytest-asyncio>=0.23.3",
    "pytest-cov>=4.1.0",
    "ruff>=0.1.14",
    "black>=24.1.1",
    "mypy>=1.8.0",
]

[project.scripts]
mcp-server = "mcp_server.__main__:main"

[tool.setuptools.packages.find]
where = ["src"]

[tool.black]
line-length = 88
target-version = ["py311", "py312"]
include = '\.pyi?$'

[tool.ruff]
line-length = 88
target-version = "py311"
select = [
    "E",   # pycodestyle errors
    "W",   # pycodestyle warnings
    "F",   # pyflakes
    "I",   # isort
    "B",   # flake8-bugbear
    "C4",  # flake8-comprehensions
    "UP",  # pyupgrade
]
ignore = [
    "E501",  # line too long (handled by black)
    "B008",  # do not perform function call in argument defaults
]

[tool.ruff.per-file-ignores]
"__init__.py" = ["F401"]  # unused imports

[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_incomplete_defs = true
check_untyped_defs = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_no_return = true
strict_equality = true

[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false

[tool.pytest.ini_options]
minversion = "7.0"
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
asyncio_mode = "auto"
addopts = [
    "--strict-markers",
    "--tb=short",
    "--cov=mcp_server",
    "--cov-report=term-missing",
    "--cov-report=html",
    "--cov-report=xml",
]
markers = [
    "unit: Unit tests",
    "integration: Integration tests",
    "e2e: End-to-end tests",
    "slow: Slow-running tests",
]

[tool.coverage.run]
source = ["src/mcp_server"]
omit = ["*/tests/*", "*/migrations/*"]

[tool.coverage.report]
precision = 2
show_missing = true
skip_covered = false
fail_under = 80
```

## Version Control

### Git Workflow

```text
main (production)
  │
  ├── develop (staging)
  │     │
  │     ├── feature/add-assignment-tool
  │     │
  │     ├── feature/improve-auth
  │     │
  │     └── bugfix/fix-rate-limit
  │
  └── hotfix/critical-bug
```

### Branch Naming

```bash
# Feature branches
feature/add-assignment-priority
feature/implement-oauth

# Bugfix branches
bugfix/fix-cache-expiry
bugfix/correct-validation

# Hotfix branches (for production)
hotfix/security-patch
hotfix/critical-error

# Release branches
release/1.0.0
release/1.1.0
```

### Commit Messages

Follow Conventional Commits:

```bash
# Format
<type>(<scope>): <subject>

<body>

<footer>

# Types
feat:     # New feature
fix:      # Bug fix
docs:     # Documentation only
style:    # Formatting, missing semicolons, etc.
refactor: # Code change that neither fixes a bug nor adds a feature
perf:     # Performance improvement
test:     # Adding or updating tests
chore:    # Build process or auxiliary tool changes

# Examples
feat(tools): add assignment priority field

Added priority field to assignments with validation (1-5).
Updated database schema and API documentation.

Closes #123

---

fix(auth): correct JWT token expiry validation

Token expiry was not being validated correctly, allowing
expired tokens to be accepted.

Fixes #456

---

docs(api): update tool documentation

Added examples for create_assignment and list_assignments
tools with sample responses.
```

### Git Hooks

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Run linting
echo "Running linters..."
ruff check src/ tests/
if [ $? -ne 0 ]; then
    echo "Linting failed. Please fix errors before committing."
    exit 1
fi

# Run type checking
echo "Running type checker..."
mypy src/
if [ $? -ne 0 ]; then
    echo "Type checking failed. Please fix errors before committing."
    exit 1
fi

# Run tests
echo "Running tests..."
pytest tests/unit -q
if [ $? -ne 0 ]; then
    echo "Tests failed. Please fix before committing."
    exit 1
fi

echo "Pre-commit checks passed!"
```

## Development Workflows

### Local Development Setup

```bash
#!/bin/bash
# scripts/setup.sh

set -e

echo "Setting up MCP Server development environment..."

# Check Python version
python_version=$(python3 --version | cut -d ' ' -f 2)
required_version="3.11"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "Error: Python $required_version or higher is required"
    exit 1
fi

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Setup pre-commit hooks
echo "Setting up pre-commit hooks..."
cp scripts/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit

# Create .env file
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
    echo "Please update .env with your configuration"
fi

# Setup database
echo "Setting up database..."
docker-compose up -d postgres redis

# Wait for database
echo "Waiting for database..."
sleep 5

# Run migrations
echo "Running migrations..."
python scripts/migrate.py

# Seed data
echo "Seeding data..."
python scripts/seed_data.py

echo "Setup complete! Run 'source venv/bin/activate' to activate the environment."
```

### Running Locally

```bash
# Start dependencies
docker-compose up -d postgres redis jaeger

# Activate virtual environment
source venv/bin/activate

# Run server in development mode
uvicorn mcp_server.server:app \
  --host 0.0.0.0 \
  --port 8000 \
  --reload \
  --log-level debug

# Or use the package entry point
mcp-server --environment development
```

### Development Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: mcp_dev
      POSTGRES_USER: dev_user
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
  
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "5775:5775/udp"
      - "6831:6831/udp"
      - "6832:6832/udp"
      - "5778:5778"
      - "16686:16686"
      - "14268:14268"
      - "14250:14250"
      - "9411:9411"
  
  mcp-server:
    build: .
    ports:
      - "8000:8000"
    environment:
      - ENVIRONMENT=development
      - DB_HOST=postgres
      - REDIS_HOST=redis
      - JAEGER_HOST=jaeger
    depends_on:
      - postgres
      - redis
      - jaeger
    volumes:
      - ./src:/app/src
      - ./config:/app/config
    command: uvicorn mcp_server.server:app --host 0.0.0.0 --reload

volumes:
  postgres_data:
  redis_data:
```

## Code Quality

### Pre-commit Configuration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
  
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.14
    hooks:
      - id: ruff
        args: [--fix, --exit-non-zero-on-fix]
  
  - repo: https://github.com/psf/black
    rev: 24.1.1
    hooks:
      - id: black
  
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.8.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic]
```

### Makefile for Common Tasks

```makefile
# Makefile
.PHONY: help install test lint format clean run

help:  ## Show this help message
 @grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install:  ## Install dependencies
 pip install -r requirements.txt -r requirements-dev.txt

test:  ## Run tests
 pytest tests/ -v --cov=mcp_server

test-unit:  ## Run unit tests only
 pytest tests/unit -v

test-integration:  ## Run integration tests
 pytest tests/integration -v

lint:  ## Run linters
 ruff check src/ tests/
 mypy src/

format:  ## Format code
 black src/ tests/
 ruff check --fix src/ tests/

clean:  ## Clean build artifacts
 find . -type d -name __pycache__ -exec rm -rf {} +
 find . -type f -name '*.pyc' -delete
 rm -rf .pytest_cache .mypy_cache .coverage htmlcov dist build *.egg-info

run:  ## Run server locally
 uvicorn mcp_server.server:app --reload --log-level debug

docker-build:  ## Build Docker image
 docker build -t mcp-server:latest .

docker-run:  ## Run Docker container
 docker run -p 8000:8000 mcp-server:latest
```

## Summary

A well-structured development lifecycle ensures:

- **Standard Structure**: Consistent project organization
- **Configuration**: Environment-specific settings with secrets management
- **Dependencies**: Clear dependency management with pyproject.toml
- **Version Control**: Git workflow with conventional commits
- **Development Workflow**: Automated setup and local development
- **Code Quality**: Linting, formatting, and type checking

---

**Next**: Review [Deployment Patterns](07-deployment-patterns.md) for production deployment strategies.
