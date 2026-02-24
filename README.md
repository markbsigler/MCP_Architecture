# Model Context Protocol (MCP) Server Architecture and Design Guidelines

**Version:** 2.1.0  
**Last Updated:** February 23, 2026  
**Status:** Production Ready  
**Repository:** MCP_Architecture  
**Author:** Mark Sigler

[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC_BY--SA_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by-sa/4.0/)
[![Documentation](https://img.shields.io/badge/docs-comprehensive-blue.svg)](docs/)
[![MCP Protocol](https://img.shields.io/badge/MCP-2.0-green.svg)](https://modelcontextprotocol.io)
[![Python](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org)
[![FastMCP](https://img.shields.io/badge/FastMCP-enabled-orange.svg)](https://github.com/jlowin/fastmcp)
[![Tests](https://img.shields.io/badge/coverage-80%25+-success.svg)](docs/IEEE-42010/views/04-testing-strategy.md)
[![Security](https://img.shields.io/badge/security-hardened-red.svg)](docs/IEEE-42010/views/02-security-architecture.md)
[![DORA](https://img.shields.io/badge/DORA-elite-purple.svg)](docs/IEEE-42010/views/13-metrics-kpis.md)

## Overview

This repository contains comprehensive architectural and systems design guidelines for developing enterprise-grade Model Context Protocol (MCP) servers. It establishes consistent patterns, best practices, and implementation standards to ensure robust, secure, and maintainable agentic MCP services.

### 🎯 What You'll Find Here

- **31+ comprehensive documentation modules** covering architecture, security, implementation, operations, and compliance
- **IEEE 29148:2018 SRS** with formal EARS-syntax requirements and full traceability
- **IEEE 42010:2022 AD** with six architectural viewpoints and correspondence rules
- **Production-ready code examples** in Python with FastMCP
- **Decision trees and flowcharts** for architectural choices
- **Complete testing strategies** with 80%+ coverage targets
- **Security hardening guides** with RBAC, OAuth 2.1+PKCE, and audit logging
- **Observability patterns** with Prometheus, Grafana, and OpenTelemetry
- **DORA metrics tracking** for deployment excellence
- **Migration guides** for REST API → MCP transitions

## Purpose

These guidelines are designed to help engineering teams:

- Build MCP servers with consistent patterns and conventions
- Implement security best practices from the ground up
- Ensure production-readiness through comprehensive testing
- Maintain observability and operational excellence
- Integrate with enterprise systems reliably
- Follow agentic system best practices

## Target Audience

- **Backend Engineers**: Implementing MCP server functionality
- **Platform Engineers**: Deploying and operating MCP infrastructure
- **Security Engineers**: Reviewing and hardening implementations
- **Engineering Managers**: Understanding architectural decisions
- **QA Engineers**: Testing MCP server implementations

## Documentation Structure

### Foundation & Reference

**[Terminology Guide](docs/IEEE-42010/ref/00-terminology-guide.md)** ⭐ **NEW**

- Standard terminology definitions (MCP server, tool, resource, prompt)
- Consistent naming conventions across all documentation
- Code example standards (✅ RECOMMENDED vs ❌ AVOID patterns)
- Capitalization and abbreviation rules

### Core Architecture

**[Architecture Overview](docs/IEEE-42010/views/01-architecture-overview.md)**

- Enterprise MCP architecture layers
- Request flow patterns
- Component interactions
- FastMCP integration patterns

**[Architecture Decision Records](docs/IEEE-42010/views/01b-architecture-decisions.md)**

- ADR format and templates
- Key architectural decisions
- Technology selection rationale

### Implementation Standards

**[Security Architecture](docs/IEEE-42010/views/02-security-architecture.md)**

- Authentication patterns (JWT, OAuth 2.0, WorkOS)
- Authorization frameworks (RBAC, capability-based)
- Rate limiting with token bucket algorithm
- Input validation and sanitization
- Security headers and CORS
- Audit logging requirements

**[Data Privacy & Compliance](docs/IEEE-42010/views/02a-data-privacy-compliance.md)**

- PII detection and classification
- Data masking and redaction
- Retention policies and deletion
- GDPR, CCPA, HIPAA compliance

**[Requirements Engineering](docs/IEEE-29148/methodology/02b-requirements-engineering.md)**

- EARS (Easy Approach to Requirements Syntax)
- Agile user story format
- Acceptance criteria standards
- ISO/IEEE 29148 principles
- Requirements traceability

**[Tool Implementation Standards](docs/IEEE-42010/views/03-tool-implementation.md)**

- Naming conventions (verb-noun pattern)
- Parameter design standards
- Response format consistency
- Error handling framework
- Pagination patterns
- Versioning strategies

**[Prompt Implementation Standards](docs/IEEE-42010/views/03a-prompt-implementation.md)**

- User-controlled workflow templates
- Parameter completion patterns
- Dynamic prompt injection
- Multi-message sequences
- Versioning and compatibility

**[Resource Implementation Standards](docs/IEEE-42010/views/03b-resource-implementation.md)**

- URI design patterns and templates
- MIME type handling
- Pagination and subscriptions
- Caching strategies
- Access control patterns

**[Sampling Patterns and LLM Interaction](docs/IEEE-42010/views/03c-sampling-patterns.md)**

- Server-initiated LLM requests
- Model selection and temperature control
- Structured output patterns
- Prompt engineering techniques
- Performance optimization

### Decision Support

**[Decision Trees](docs/IEEE-42010/views/03d-decision-trees.md)**

- Structured architectural choice guides
- Tool vs prompt vs resource selection matrices
- Authentication method decision flows
- Caching, database, and deployment pattern trees

**[Integration Patterns](docs/IEEE-42010/views/03e-integration-patterns.md)**

- REST API integration with circuit breakers
- Multi-tier caching strategies
- OpenAPI-to-MCP tool generation
- Database access patterns
- Event-driven patterns
- Multi-service orchestration

**[Elicitation Patterns](docs/IEEE-42010/views/03f-elicitation-patterns.md)**

- Human-in-the-loop structured input
- Supported input types (string, number, enum, URL)
- Confirmation before destructive actions
- Fallback when client lacks elicitation support

**[Task Patterns](docs/IEEE-42010/views/03g-task-patterns.md)**

- Durable long-running operation tracking (experimental)
- Task lifecycle state management
- Status polling and cancellation
- Production considerations (persistence, expiration)

**[Multi-Server Orchestration](docs/IEEE-42010/views/03h-multi-server-orchestration.md)**

- Cross-server workflow composition
- Sequential and parallel aggregation patterns
- Failure isolation between servers
- Capability boundary declaration

**[AI Service Provider Gateway](docs/IEEE-42010/views/03i-ai-service-provider-gateway.md)**

- Provider-agnostic LLM routing (OpenAI, Azure, Anthropic, Bedrock, vLLM)
- Automatic failover on 429/5xx/timeout
- Credential rotation and secret management
- Enterprise header injection and cost tracking

### Quality & Operations

**[Testing Strategy](docs/IEEE-42010/views/04-testing-strategy.md)**

- Unit testing patterns with mocking
- Integration testing approaches
- Security testing procedures
- Performance testing guidelines
- Coverage requirements (80%+ for enterprise)
- Test data management

**[Observability Architecture](docs/IEEE-42010/views/05-observability.md)**

- Structured logging standards (JSON format)
- Metrics collection (Prometheus/OpenTelemetry)
- Distributed tracing patterns
- Health check implementations
- SLI/SLO definitions
- Alerting strategies

### Development & Operations

**[Development Lifecycle](docs/IEEE-42010/views/06-development-lifecycle.md)**

- Project structure standards
- Configuration management patterns
- Environment handling (dev/staging/prod)
- Dependency management
- Code quality standards
- Documentation requirements

**[Performance & Scalability](docs/IEEE-42010/views/06a-performance-scalability.md)**

- Horizontal and vertical scaling
- Caching strategies
- Connection pooling
- Load balancing patterns

**[Deployment Patterns](docs/IEEE-42010/views/07-deployment-patterns.md)**

- Container best practices (Dockerfile standards)
- Kubernetes deployment patterns
- CI/CD pipeline stages
- Blue-green and canary deployments
- Environment management
- Secrets management

**[Operational Runbooks](docs/IEEE-42010/views/08-operational-runbooks.md)**

- Common issues and resolutions
- Incident response procedures
- Performance tuning guidelines
- Capacity planning
- Disaster recovery
- Monitoring and alerting setup

### Advanced Topics

**[Agentic System Best Practices](docs/IEEE-42010/views/09-agentic-best-practices.md)**

- Context management and token optimization
- User elicitation patterns
- Resource template architecture
- Prompt system design
- Safety and confirmation patterns
- LLM-specific considerations

**[Migration Guides](docs/IEEE-42010/views/10-migration-guides.md)**

- REST API → MCP transition phases
- MCP protocol version upgrade strategies
- Authentication provider migration steps
- Database migration and shadow write patterns
- Zero-downtime deployment approaches

**[Troubleshooting Guide](docs/IEEE-42010/views/11-troubleshooting.md)**

- Common authentication and rate limiting issues
- Performance degradation diagnostics
- Memory leak detection and resolution
- Database connection troubleshooting
- Log analysis patterns and profiling techniques

**[Cost Optimization](docs/IEEE-42010/views/12-cost-optimization.md)**

- Resource sizing recommendations
- Caching strategies for cost reduction
- Database query optimization
- API call batching patterns
- Cold start optimization
- Auto-scaling policies

### Metrics & Reference

**[Metrics and KPIs](docs/IEEE-42010/views/13-metrics-kpis.md)**

- Service Level Objectives (SLOs): availability, latency, error rate
- Business metrics: tool executions, active users, API volume
- Operational metrics: deployment frequency, MTTR, change failure rate
- DORA metrics tracking for elite performance

**[Performance Benchmarks](docs/IEEE-42010/views/14-performance-benchmarks.md)**

- Baseline performance metrics
- Configuration comparisons
- Load testing results
- Scaling characteristics
- Hardware recommendations

**[MCP Protocol Compatibility](docs/IEEE-42010/views/15-mcp-protocol-compatibility.md)**

- Supported MCP spec versions (2024-11-05 through 2025-11-25)
- Feature progression across specification versions
- Version negotiation during initialize handshake
- Migration guidance for spec version upgrades

### IEEE Standards

**[IEEE 29148:2018 — Software Requirements Specification](docs/IEEE-29148/SRS.md)** ⭐ **NEW**

- Formal requirements using EARS syntax
- Functional requirements (protocol, resources, tools, prompts, sampling, elicitation, tasks, orchestration, gateway)
- Non-functional requirements (security, performance, observability, container)
- Verification method mapping and traceability matrix

**[IEEE 42010:2022 — Architecture Description](docs/IEEE-42010/AD.md)** ⭐ **NEW**

- Six viewpoints: Functional, Information, Deployment, Security, Operational, Development
- Mermaid diagrams for every architectural view
- Correspondence rules across viewpoints
- Traceability to SRS requirements

## Development Setup

### Prerequisites

- **Python 3.11+** - Required for build scripts
- **Node.js & npm** - Optional, for markdownlint (recommended)
- **Git** - Version control

### Quick Setup

```bash
# Clone the repository
git clone https://github.com/markbsigler/MCP_Architecture.git
cd MCP_Architecture

# Run setup script (installs git hooks and dependencies)
./setup.sh

# Verify installation
make check-deps
```

### Available Commands

```bash
# Check for required dependencies
make check-deps

# Install missing dependencies (markdownlint)
make install-deps

# Run linting (link checker + markdownlint)
make lint

# Generate table of contents
make toc

# Build consolidated documentation
make md

# Clean generated files
make clean
```

### Pre-commit Hooks

The setup script automatically configures git hooks that will run before each commit:

- ✅ **Link validation** - Ensures all internal documentation links are valid
- ✅ **Markdown linting** - Checks formatting and style consistency
- ✅ **Critical files check** - Verifies required files are present

To manually run pre-commit checks:

```bash
./.githooks/pre-commit
```

To bypass hooks (not recommended):

```bash
git commit --no-verify
```

### Contributing Guidelines

1. Run `./setup.sh` to configure your environment
2. Make your changes
3. Run `make lint` to verify changes pass all checks
4. Commit (pre-commit hooks will run automatically)
5. Submit a pull request

All documentation must pass:

- Link validation (`python3 scripts/check_links.py`)
- Markdown linting (`npx markdownlint`)
- Build verification (`make md`)

## Quick Start

### 🎯 Choose Your Path

**New Project (0 → Production in 4 weeks)**

```text
├─ Week 1: Foundation
│  ├─ [Architecture](docs/IEEE-42010/views/01-architecture-overview.md) → Understand 5-layer enterprise design
│  ├─ [Security](docs/IEEE-42010/views/02-security-architecture.md) → Implement JWT/OAuth 2.0 from day one
│  ├─ [Privacy](docs/IEEE-42010/views/02a-data-privacy-compliance.md) → Set up PII detection and compliance
│  └─ [Requirements](docs/IEEE-29148/methodology/02b-requirements-engineering.md) → Define requirements with EARS format
│
├─ Week 2: Core Implementation
│  ├─ [Tools](docs/IEEE-42010/views/03-tool-implementation.md) → Build APIs with verb-noun naming
│  ├─ [Prompts](docs/IEEE-42010/views/03a-prompt-implementation.md) → Create workflow templates
│  ├─ [Resources](docs/IEEE-42010/views/03b-resource-implementation.md) → Implement data access patterns
│  └─ [Testing](docs/IEEE-42010/views/04-testing-strategy.md) → Achieve 80%+ coverage
│
├─ Week 3: Quality & Operations
│  ├─ [Observability](docs/IEEE-42010/views/05-observability.md) → Add logging, metrics, tracing
│  ├─ [Performance](docs/IEEE-42010/views/06a-performance-scalability.md) → Optimize for scale
│  ├─ [Deployment](docs/IEEE-42010/views/07-deployment-patterns.md) → Containerize with Docker/Kubernetes
│  └─ [Integration](docs/IEEE-42010/views/03e-integration-patterns.md) → Connect external systems
│
└─ Week 4: Production Readiness
   ├─ [Operations](docs/IEEE-42010/views/08-operational-runbooks.md) → Set up incident response
   ├─ [Agentic Best Practices](docs/IEEE-42010/views/09-agentic-best-practices.md) → Optimize context management
   ├─ [Metrics](docs/IEEE-42010/views/13-metrics-kpis.md) → Configure dashboards and SLOs
   └─ Production Launch! 🚀
```

**Existing Project (Continuous Improvement)**

```text
├─ Security Enhancement
│  ├─ [Audit Checklist](docs/IEEE-42010/views/02-security-architecture.md#security-checklist) → Review current controls
│  ├─ [Authentication](docs/IEEE-42010/views/02-security-architecture.md#authentication-patterns) → Upgrade auth
│  ├─ [Authorization](docs/IEEE-42010/views/02-security-architecture.md#role-based-access-control-rbac) → Add RBAC
│  └─ [Compliance](docs/IEEE-42010/views/02a-data-privacy-compliance.md) → Meet GDPR/CCPA requirements
│
├─ Quality Improvement
│  ├─ [Testing Strategy](docs/IEEE-42010/views/04-testing-strategy.md) → Increase coverage to 80%+
│  ├─ [Coverage Requirements](docs/IEEE-42010/views/04-testing-strategy.md#coverage-requirements) → Set targets
│  ├─ [Security Testing](docs/IEEE-42010/views/04-testing-strategy.md#security-testing) → Add security tests
│  └─ [Performance Testing](docs/IEEE-42010/views/04-testing-strategy.md#performance-testing) → Benchmark system
│
├─ Performance Optimization
│  ├─ [Optimization Guide](docs/IEEE-42010/views/06a-performance-scalability.md) → Identify bottlenecks
│  ├─ [Benchmarks](docs/IEEE-42010/views/14-performance-benchmarks.md) → Compare against baselines
│  ├─ [Cost Optimization](docs/IEEE-42010/views/12-cost-optimization.md) → Reduce infrastructure costs
│  └─ [Troubleshooting](docs/IEEE-42010/views/11-troubleshooting.md#understanding-flame-graphs) → Profile with flame graphs
│
└─ Operational Excellence
   ├─ [Runbooks](docs/IEEE-42010/views/08-operational-runbooks.md) → Document incident procedures
   ├─ [Troubleshooting](docs/IEEE-42010/views/11-troubleshooting.md) → Build diagnostic playbooks
   ├─ [Metrics](docs/IEEE-42010/views/13-metrics-kpis.md#dora-metrics) → Track DORA metrics
   └─ [Alerting](docs/IEEE-42010/views/05-observability.md#alerting-strategies) → Set up smart alerts
```

**Migration (REST → MCP)**

```text
└─ Start Here: [Migration Guides](docs/IEEE-42010/views/10-migration-guides.md#migrating-from-rest-api-to-mcp)
   │
   ├─ Phase 1: Planning
   │  ├─ [MCP vs REST Decision](docs/IEEE-42010/views/03d-decision-trees.md#when-to-use-mcp-vs-rest-api) → Validate migration
   │  ├─ [Architecture Overview](docs/IEEE-42010/views/01-architecture-overview.md) → Understand MCP patterns
   │  └─ [Requirements](docs/IEEE-29148/methodology/02b-requirements-engineering.md) → Map REST endpoints to MCP tools
   │
   ├─ Phase 2: Parallel Implementation
   │  ├─ [Tool Implementation](docs/IEEE-42010/views/03-tool-implementation.md) → Build MCP tools
   │  ├─ [OpenAPI to MCP](docs/IEEE-42010/views/03e-integration-patterns.md#openapi-to-mcp-tool-generation) → Auto-generate tools
   │  └─ [Testing](docs/IEEE-42010/views/04-testing-strategy.md#contract-testing) → Contract tests for compatibility
   │
   ├─ Phase 3: Gradual Migration
   │  ├─ [Zero-Downtime Migration](docs/IEEE-42010/views/10-migration-guides.md#zero-downtime-migration-strategies) → Deploy safely
   │  ├─ [Protocol Compatibility](docs/IEEE-42010/views/15-mcp-protocol-compatibility.md) → Handle version differences
   │  └─ [Database Migration](docs/IEEE-42010/views/10-migration-guides.md#database-migration-with-shadow-writes) → Shadow writes pattern
   │
   └─ Phase 4: Cutover & Decommission
      ├─ [Monitoring](docs/IEEE-42010/views/05-observability.md) → Watch for issues
      ├─ [Troubleshooting](docs/IEEE-42010/views/11-troubleshooting.md) → Quick diagnostic guide
      └─ Decommission REST API
```

### 📚 Quick Navigation

- **Find a Topic**: See [Index by Topic](docs/IEEE-42010/ref/98-index-by-topic.md) for comprehensive topic index
- **Quick Reference**: See [Quick Reference](docs/IEEE-42010/ref/99-quick-reference.md) for command cheat sheets
- **Table of Contents**: See [Table of Contents](docs/IEEE-42010/ref/00-table-of-contents.md) for sequential listing
- **Decision Help**: Use [Decision Trees](docs/IEEE-42010/views/03d-decision-trees.md) for architectural choices

## Reference Implementation

A reference implementation demonstrating these patterns is available but not directly referenced in this documentation to maintain vendor neutrality. The patterns and examples shown here are based on production-proven implementations using FastMCP with Python.

## Technology Stack

While these guidelines are language-agnostic in principle, examples and patterns are primarily shown using:

- **Framework**: FastMCP (Python)
- **Language**: Python 3.11+
- **Authentication**: JWT/JWKS, OAuth 2.1+PKCE
- **Observability**: OpenTelemetry, Prometheus
- **Container Runtime**: Docker
- **Orchestration**: Kubernetes (examples are generic)
- **CI/CD**: Vendor-agnostic patterns

## Contributing

This documentation is maintained by the platform engineering team. For suggestions, corrections, or additions:

1. Create an issue describing the proposed change
2. For substantial changes, discuss with the team first
3. Submit a pull request with clear descriptions
4. Ensure all examples are tested and verified

## Maintenance

- **Review Cadence**: Quarterly review for updates
- **Version Updates**: Semantic versioning (MAJOR.MINOR.PATCH)
- **Change Log**: Maintained in each document's header
- **Feedback**: Collected from engineering teams using these guidelines

## Community

### 🤝 Contributing

We welcome contributions from the community! Here's how you can help:

#### Documentation Improvements

- Fix typos or clarify confusing sections
- Add missing examples or use cases
- Update outdated information
- Translate documentation to other languages

#### Code Examples

- Add implementations in other languages (Go, TypeScript, Rust)
- Provide framework-specific examples (Quart, Starlette, etc.)
- Contribute integration examples with popular services

#### Best Practices

- Share production learnings and patterns
- Document edge cases and solutions
- Add troubleshooting scenarios

#### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-contribution`)
3. Make your changes with clear commit messages
4. Add tests if applicable
5. Update documentation as needed
6. Submit a pull request with detailed description

### 📚 Additional Resources

#### MCP Protocol

- [Official MCP Specification](https://modelcontextprotocol.io)
- [MCP GitHub Organization](https://github.com/modelcontextprotocol)
- [FastMCP Framework](https://github.com/jlowin/fastmcp)

#### Related Standards

- [OpenAPI Specification](https://www.openapis.org/)
- [OAuth 2.0](https://oauth.net/2/)
- [OpenTelemetry](https://opentelemetry.io/)
- [Prometheus](https://prometheus.io/)

#### Compliance & Security

- [OWASP API Security Top 10](https://owasp.org/API-Security/)
- [GDPR Compliance Guide](https://gdpr.eu/)
- [CCPA Resource Center](https://oag.ca.gov/privacy/ccpa)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/)

## Roadmap

### ✅ Completed (v2.1.0)

**IEEE Directory Restructure (v2.1.0)**

- ✅ Reorganized 31 documentation files into IEEE-compliant directory structure
- ✅ Moved 27 implementation guides → `docs/IEEE-42010/views/`
- ✅ Moved 4 reference documents → `docs/IEEE-42010/ref/`
- ✅ Moved requirements methodology → `docs/IEEE-29148/methodology/`
- ✅ Updated 347 cross-references across 38 files
- ✅ Preserved git history using `git mv` for all file relocations

**IEEE Standards Adoption (v2.0.0)**

- ✅ IEEE 29148:2018 Software Requirements Specification (SRS.md)
- ✅ IEEE 42010:2022 Architecture Description (AD.md)
- ✅ Elicitation patterns, Task patterns, Multi-server orchestration, AI gateway docs
- ✅ Security architecture update (OAuth 2.1, RBAC alignment)
- ✅ Protocol compatibility rewrite (real MCP spec versions)
- ✅ Legacy file consolidation (MCP-PRD.md and MCP-ARCHITECTURE.md removed)

**Core Documentation (v1.0.0 - v1.4.0)**

- Core architecture and implementation standards
- Security architecture with OAuth 2.1 and RBAC
- Testing strategy with 80%+ coverage targets
- Observability with Prometheus and OpenTelemetry
- Deployment patterns for Docker/Kubernetes
- Migration guides for REST API transitions
- Troubleshooting guide with diagnostics
- Metrics and KPIs with DORA tracking
- MCP protocol compatibility documentation
- Breadcrumb navigation across all documents
- Cross-reference index by topic (98-index-by-topic.md)
- Comprehensive terminology guide (00-terminology-guide.md)

### 🔮 Future Enhancements

For detailed planning and upcoming work, see [ROADMAP.md](ROADMAP.md).

**Planned priorities include:**

- Mermaid diagram improvements (request flows, security zones, deployment architecture)
- Interactive code examples and templates
- Security audit checklists (pre-production, compliance, incident response)
- Performance testing toolkit and benchmarking
- Migration tooling (REST → MCP, OpenAPI conversion)

## FAQ

### General Questions

**Q: What is MCP?**
A: The Model Context Protocol (MCP) is an open standard for connecting AI assistants to external data sources and tools. It provides a unified way to expose functionality to Large Language Models (LLMs).

**Q: Why use these guidelines?**
A: These guidelines codify production-proven patterns for building secure, scalable, and maintainable MCP servers. They help teams avoid common pitfalls and accelerate development.

**Q: Are these guidelines language-specific?**
A: While examples use Python with FastMCP, the patterns and principles apply to any language. Community contributions for other languages are welcome.

### Implementation Questions

**Q: Do I need to implement everything?**
A: No. Start with core patterns (architecture, security, testing) and adopt others based on your needs. Use [Decision Trees](docs/IEEE-42010/views/03d-decision-trees.md) to guide choices.

**Q: How do I migrate from REST APIs?**
A: Follow the [Migration Guides](docs/IEEE-42010/views/10-migration-guides.md) for phased approaches, shadow writing, and zero-downtime strategies.

**Q: What test coverage should I target?**
A: 80%+ for enterprise applications. See [Testing Strategy](docs/IEEE-42010/views/04-testing-strategy.md) for details.

**Q: How do I handle authentication?**
A: We recommend JWT with JWKS or OAuth 2.1 with PKCE. See [Security Architecture](docs/IEEE-42010/views/02-security-architecture.md) for implementation patterns.

### Operational Questions

**Q: What observability tools should I use?**
A: We recommend Prometheus for metrics, OpenTelemetry for tracing, and structured JSON logging. See [Observability Architecture](docs/IEEE-42010/views/05-observability.md).

**Q: How do I monitor SLOs?**
A: Use the [Metrics and KPIs](docs/IEEE-42010/views/13-metrics-kpis.md) guide for SLO definitions, error budget tracking, and alerting rules.

**Q: What deployment patterns are recommended?**
A: Docker containers with Kubernetes orchestration. Blue-green and canary deployments for zero-downtime. See [Deployment Patterns](docs/IEEE-42010/views/07-deployment-patterns.md).

**Q: How do I troubleshoot production issues?**
A: Start with the [Troubleshooting Guide](docs/IEEE-42010/views/11-troubleshooting.md) for common issues, diagnostic commands, and profiling techniques.

### Compliance Questions

**Q: How do I ensure GDPR compliance?**
A: Follow [Data Privacy & Compliance](docs/IEEE-42010/views/02a-data-privacy-compliance.md) for PII detection, data masking, retention policies, and deletion procedures.

**Q: What about HIPAA compliance?**
A: Implement encryption (transit/rest), audit logging, access controls, and data retention per [Data Privacy & Compliance](docs/IEEE-42010/views/02a-data-privacy-compliance.md).

**Q: How do I handle security audits?**
A: Use security checklists (coming in v1.4.0) and review [Security Architecture](docs/IEEE-42010/views/02-security-architecture.md) for hardening measures.

## Support

### 📞 Getting Help

#### Documentation Issues

- Open an issue on GitHub for documentation bugs
- Tag with `documentation` label
- Include page reference and description

#### Technical Questions

- Review relevant documentation sections first
- Check [Troubleshooting Guide](docs/IEEE-42010/views/11-troubleshooting.md)
- Search existing GitHub issues
- Open a new issue with detailed context

#### Security Concerns

- **DO NOT** open public issues for security vulnerabilities
- Email security concerns directly to maintainers
- Use GitHub Security Advisories for responsible disclosure

#### Community Support

- Join discussions in GitHub Discussions
- Share your implementations and learnings
- Help others by answering questions

### 🏢 Enterprise Support

For organizations requiring:

- Custom implementation guidance
- Architecture review and consultation
- Security audit assistance
- Training workshops
- Priority support

Contact the maintainers for enterprise support options.

## License

This documentation is licensed under [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](https://creativecommons.org/licenses/by-sa/4.0/).

You are free to:

- **Share** — copy and redistribute the material
- **Adapt** — remix, transform, and build upon the material

Under the following terms:

- **Attribution** — give appropriate credit
- **ShareAlike** — distribute adaptations under the same license

---

**Next Steps**: Start with [Architecture Overview](docs/IEEE-42010/views/01-architecture-overview.md) to understand the foundational concepts.

---

Made with ❤️ by the MCP community | [Report Issues](https://github.com/markbsigler/MCP_Architecture/issues) | [Contribute](https://github.com/markbsigler/MCP_Architecture/pulls) | [Discussions](https://github.com/markbsigler/MCP_Architecture/discussions)
