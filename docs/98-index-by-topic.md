# Index by Topic

**Version:** 1.3.0  
**Last Updated:** November 20, 2025  
**Purpose:** Quick reference for finding documentation by technical topic

**Navigation**: [Home](../README.md) > Index by Topic

---

## Authentication

- [Security Architecture - Authentication Patterns](02-security-architecture.md#authentication-patterns)
- [Security Architecture - JWT Implementation](02-security-architecture.md#jwt-token-validation)
- [Security Architecture - OAuth 2.0 Integration](02-security-architecture.md#oauth-20-integration)
- [Decision Trees - Authentication Method Selection](03d-decision-trees.md#authentication-method-selection)
- [Migration Guides - Migrating Between Authentication Providers](10-migration-guides.md#migrating-between-authentication-providers)
- [Troubleshooting - Authentication Failures](11-troubleshooting.md#authentication-failures)

## Authorization

- [Security Architecture - RBAC Implementation](02-security-architecture.md#role-based-access-control-rbac)
- [Security Architecture - Capability-Based Access Control](02-security-architecture.md#capability-based-access-control)
- [Tool Implementation - Access Control](03-tool-implementation.md#access-control-patterns)
- [Resource Implementation - Access Control Patterns](03b-resource-implementation.md#access-control-patterns)

## Caching

- [Performance & Scalability - Caching Strategies](06a-performance-scalability.md#caching-strategies)
- [Cost Optimization - Caching Strategies for Cost Reduction](12-cost-optimization.md#caching-strategies-for-cost-reduction)
- [Integration Patterns - Multi-Tier Caching](03e-integration-patterns.md#multi-tier-caching-for-cost-and-performance)
- [Decision Trees - Caching Strategy Selection](03d-decision-trees.md#caching-strategy-selection)
- [Architecture Overview - Layer Decision Table](01-architecture-overview.md#when-to-use-each-layer)

## Circuit Breakers

- [Integration Patterns - Circuit Breaker Pattern](03e-integration-patterns.md#circuit-breaker-for-external-api-reliability)
- [Decision Trees - Error Recovery Strategy](03d-decision-trees.md#error-recovery-strategy)
- [Troubleshooting - Circuit Breaker Issues](11-troubleshooting.md#circuit-breaker-issues)

## Compliance

- [Data Privacy & Compliance - Overview](02a-data-privacy-compliance.md)
- [Data Privacy & Compliance - GDPR Compliance](02a-data-privacy-compliance.md#gdpr-compliance)
- [Data Privacy & Compliance - CCPA Compliance](02a-data-privacy-compliance.md#ccpa-compliance)
- [Data Privacy & Compliance - HIPAA Compliance](02a-data-privacy-compliance.md#hipaa-compliance)
- [Security Architecture - Audit Logging](02-security-architecture.md#audit-logging)

## Cost Optimization

- [Cost Optimization - Overview](12-cost-optimization.md)
- [Cost Optimization - Resource Sizing](12-cost-optimization.md#resource-sizing-and-right-sizing)
- [Cost Optimization - Caching Strategies](12-cost-optimization.md#caching-strategies-for-cost-reduction)
- [Cost Optimization - Query Optimization](12-cost-optimization.md#database-query-optimization)
- [Cost Optimization - API Call Batching](12-cost-optimization.md#api-call-batching)
- [Cost Optimization - Auto-Scaling Policies](12-cost-optimization.md#auto-scaling-policies)
- [Performance Benchmarks - Cost-Optimized Scaling](14-performance-benchmarks.md#cost-optimized-scaling)

## Database

- [Integration Patterns - Database Access Patterns](03e-integration-patterns.md#database-access-patterns)
- [Decision Trees - Database Choice Selection](03d-decision-trees.md#database-choice-selection)
- [Cost Optimization - Query Optimization](12-cost-optimization.md#database-query-optimization)
- [Troubleshooting - Database Connection Issues](11-troubleshooting.md#database-connection-issues)
- [Migration Guides - Database Migration](10-migration-guides.md#database-migration-with-shadow-writes)

## Deployment

- [Deployment Patterns - Overview](07-deployment-patterns.md)
- [Deployment Patterns - Container Best Practices](07-deployment-patterns.md#container-best-practices)
- [Deployment Patterns - Kubernetes Patterns](07-deployment-patterns.md#kubernetes-deployment-patterns)
- [Deployment Patterns - CI/CD Pipelines](07-deployment-patterns.md#cicd-pipeline-stages)
- [Deployment Patterns - Blue-Green Deployment](07-deployment-patterns.md#blue-green-deployment)
- [Deployment Patterns - Canary Deployment](07-deployment-patterns.md#canary-deployment)
- [Decision Trees - Deployment Platform Selection](03d-decision-trees.md#deployment-platform-selection)
- [Migration Guides - Zero-Downtime Migration](10-migration-guides.md#zero-downtime-migration-strategies)

## Error Handling

- [Tool Implementation - Error Handling Framework](03-tool-implementation.md#error-handling-patterns)
- [Decision Trees - Error Recovery Strategy](03d-decision-trees.md#error-recovery-strategy)
- [Troubleshooting - Overview](11-troubleshooting.md)
- [Integration Patterns - Circuit Breaker](03e-integration-patterns.md#circuit-breaker-for-external-api-reliability)

## Load Balancing

- [Architecture Overview - Gateway Layer](01-architecture-overview.md#layer-descriptions)
- [Performance & Scalability - Load Balancing Patterns](06a-performance-scalability.md#load-balancing-patterns)
- [Deployment Patterns - Load Balancing](07-deployment-patterns.md#load-balancing)

## Logging

- [Observability Architecture - Structured Logging](05-observability.md#structured-logging)
- [Observability Architecture - Log Correlation](05-observability.md#correlation-ids)
- [Security Architecture - Audit Logging](02-security-architecture.md#audit-logging)
- [Troubleshooting - Log Analysis](11-troubleshooting.md#log-analysis-patterns)

## Metrics

- [Observability Architecture - Metrics Collection](05-observability.md#metrics-collection)
- [Metrics and KPIs - SLO Tracking](13-metrics-kpis.md#service-level-objectives-slos)
- [Metrics and KPIs - Business Metrics](13-metrics-kpis.md#business-metrics)
- [Metrics and KPIs - DORA Metrics](13-metrics-kpis.md#dora-metrics)
- [Performance Benchmarks - Baseline Metrics](14-performance-benchmarks.md#baseline-performance-metrics)

## Migration

- [Migration Guides - Overview](10-migration-guides.md)
- [Migration Guides - REST API to MCP](10-migration-guides.md#migrating-from-rest-api-to-mcp)
- [Migration Guides - MCP Protocol Upgrades](10-migration-guides.md#mcp-protocol-version-upgrades)
- [Migration Guides - Authentication Provider Migration](10-migration-guides.md#migrating-between-authentication-providers)
- [Migration Guides - Database Migration](10-migration-guides.md#database-migration-with-shadow-writes)
- [Migration Guides - Zero-Downtime Strategies](10-migration-guides.md#zero-downtime-migration-strategies)

## Monitoring

- [Observability Architecture - Overview](05-observability.md)
- [Observability Architecture - Health Checks](05-observability.md#health-check-implementations)
- [Observability Architecture - Alerting](05-observability.md#alerting-strategies)
- [Operational Runbooks - Monitoring Setup](08-operational-runbooks.md#monitoring-and-alerting-setup)
- [Metrics and KPIs - Dashboard Examples](13-metrics-kpis.md#grafana-dashboards)

## Performance

- [Performance & Scalability - Overview](06a-performance-scalability.md)
- [Performance & Scalability - Horizontal Scaling](06a-performance-scalability.md#horizontal-scaling)
- [Performance & Scalability - Caching Strategies](06a-performance-scalability.md#caching-strategies)
- [Performance & Scalability - Connection Pooling](06a-performance-scalability.md#connection-pooling)
- [Performance Benchmarks - Overview](14-performance-benchmarks.md)
- [Performance Benchmarks - Load Testing](14-performance-benchmarks.md#load-testing-results)
- [Performance Benchmarks - Scaling Analysis](14-performance-benchmarks.md#scaling-analysis)
- [Troubleshooting - Performance Degradation](11-troubleshooting.md#performance-degradation)
- [Troubleshooting - Flame Graph Analysis](11-troubleshooting.md#understanding-flame-graphs)

## Prompts

- [Prompt Implementation Standards - Overview](03a-prompt-implementation.md)
- [Prompt Implementation - User-Controlled Workflows](03a-prompt-implementation.md#user-controlled-workflow-templates)
- [Prompt Implementation - Parameter Completion](03a-prompt-implementation.md#parameter-completion-patterns)
- [Prompt Implementation - Dynamic Injection](03a-prompt-implementation.md#dynamic-prompt-injection)
- [Decision Trees - Tool vs Prompt vs Resource](03d-decision-trees.md#tool-vs-prompt-vs-resource-selection)
- [Agentic Best Practices - Prompt System Design](09-agentic-best-practices.md#prompt-system-design)

## Rate Limiting

- [Security Architecture - Rate Limiting](02-security-architecture.md#rate-limiting)
- [Decision Trees - Error Recovery Strategy](03d-decision-trees.md#error-recovery-strategy)
- [Troubleshooting - Rate Limiting Issues](11-troubleshooting.md#rate-limiting-errors)

## Requirements

- [Requirements Engineering - Overview](02b-requirements-engineering.md)
- [Requirements Engineering - EARS Format](02b-requirements-engineering.md#ears-easy-approach-to-requirements-syntax)
- [Requirements Engineering - User Stories](02b-requirements-engineering.md#agile-user-story-format)
- [Requirements Engineering - Traceability](02b-requirements-engineering.md#requirements-traceability)
- [Architecture Decision Records - ADR Format](01b-architecture-decisions.md#adr-format-and-template)

## Resources

- [Resource Implementation Standards - Overview](03b-resource-implementation.md)
- [Resource Implementation - URI Design Patterns](03b-resource-implementation.md#uri-design-patterns)
- [Resource Implementation - Pagination](03b-resource-implementation.md#pagination-patterns)
- [Resource Implementation - Subscriptions](03b-resource-implementation.md#subscription-patterns)
- [Decision Trees - Tool vs Prompt vs Resource](03d-decision-trees.md#tool-vs-prompt-vs-resource-selection)
- [Agentic Best Practices - Resource Templates](09-agentic-best-practices.md#resource-template-architecture)

## Sampling

- [Sampling Patterns - Overview](03c-sampling-patterns.md)
- [Sampling Patterns - Server-Initiated LLM Requests](03c-sampling-patterns.md#server-initiated-llm-requests)
- [Sampling Patterns - Model Selection](03c-sampling-patterns.md#model-selection-and-temperature-control)
- [Sampling Patterns - Structured Output](03c-sampling-patterns.md#structured-output-patterns)
- [Agentic Best Practices - LLM-Specific Considerations](09-agentic-best-practices.md#llm-specific-considerations)

## Scaling

- [Performance & Scalability - Horizontal Scaling](06a-performance-scalability.md#horizontal-scaling)
- [Performance & Scalability - Vertical Scaling](06a-performance-scalability.md#vertical-scaling)
- [Performance Benchmarks - Scaling Analysis](14-performance-benchmarks.md#scaling-analysis)
- [Cost Optimization - Auto-Scaling](12-cost-optimization.md#auto-scaling-policies)
- [Decision Trees - Deployment Platform Selection](03d-decision-trees.md#deployment-platform-selection)

## Security

- [Security Architecture - Overview](02-security-architecture.md)
- [Security Architecture - Authentication Patterns](02-security-architecture.md#authentication-patterns)
- [Security Architecture - Authorization Frameworks](02-security-architecture.md#role-based-access-control-rbac)
- [Security Architecture - Input Validation](02-security-architecture.md#input-validation-and-sanitization)
- [Security Architecture - Security Headers](02-security-architecture.md#security-headers-and-cors)
- [Security Architecture - Audit Logging](02-security-architecture.md#audit-logging)
- [Testing Strategy - Security Testing](04-testing-strategy.md#security-testing)
- [Data Privacy & Compliance - Overview](02a-data-privacy-compliance.md)

## Testing

- [Testing Strategy - Overview](04-testing-strategy.md)
- [Testing Strategy - Unit Testing](04-testing-strategy.md#unit-testing)
- [Testing Strategy - Integration Testing](04-testing-strategy.md#integration-testing)
- [Testing Strategy - Contract Testing](04-testing-strategy.md#contract-testing)
- [Testing Strategy - Security Testing](04-testing-strategy.md#security-testing)
- [Testing Strategy - Performance Testing](04-testing-strategy.md#performance-testing)
- [Testing Strategy - Coverage Requirements](04-testing-strategy.md#coverage-requirements)

## Tools

- [Tool Implementation Standards - Overview](03-tool-implementation.md)
- [Tool Implementation - Naming Conventions](03-tool-implementation.md#naming-conventions)
- [Tool Implementation - Parameter Design](03-tool-implementation.md#parameter-design)
- [Tool Implementation - Error Handling](03-tool-implementation.md#error-handling-patterns)
- [Tool Implementation - Pagination](03-tool-implementation.md#pagination-patterns)
- [Tool Implementation - Versioning](03-tool-implementation.md#versioning-strategies)
- [Decision Trees - Tool vs Prompt vs Resource](03d-decision-trees.md#tool-vs-prompt-vs-resource-selection)
- [Integration Patterns - OpenAPI to MCP](03e-integration-patterns.md#openapi-to-mcp-tool-generation)

## Traceability

- [Requirements Engineering - Traceability Matrix](02b-requirements-engineering.md#requirements-traceability)
- [Requirements Engineering - Automated Tracking](02b-requirements-engineering.md#automated-traceability-tracking)
- [Observability Architecture - Distributed Tracing](05-observability.md#distributed-tracing-patterns)

## Troubleshooting

- [Troubleshooting Guide - Overview](11-troubleshooting.md)
- [Troubleshooting - Authentication Failures](11-troubleshooting.md#authentication-failures)
- [Troubleshooting - Rate Limiting](11-troubleshooting.md#rate-limiting-errors)
- [Troubleshooting - Performance Issues](11-troubleshooting.md#performance-degradation)
- [Troubleshooting - Memory Leaks](11-troubleshooting.md#memory-leaks)
- [Troubleshooting - Database Connections](11-troubleshooting.md#database-connection-issues)
- [Troubleshooting - Log Analysis](11-troubleshooting.md#log-analysis-patterns)
- [Troubleshooting - Flame Graphs](11-troubleshooting.md#understanding-flame-graphs)
- [Operational Runbooks - Incident Response](08-operational-runbooks.md#incident-response-procedures)

## Versioning

- [Tool Implementation - Versioning Strategies](03-tool-implementation.md#versioning-strategies)
- [MCP Protocol Compatibility - Version Management](15-mcp-protocol-compatibility.md#protocol-version-management)
- [MCP Protocol Compatibility - Feature Matrix](15-mcp-protocol-compatibility.md#feature-compatibility-matrix)
- [Migration Guides - Protocol Upgrades](10-migration-guides.md#mcp-protocol-version-upgrades)

---

## How to Use This Index

1. **Find Your Topic**: Use your browser's search (Ctrl+F / Cmd+F) to find keywords
2. **Multiple References**: Topics appear in multiple contexts - start with the most relevant
3. **Cross-References**: Follow links to discover related topics
4. **Deep Dives**: Use section anchors to jump directly to specific content

## Related Documentation

- [Quick Reference Guide](99-quick-reference.md) - Command cheat sheets and quick lookups
- [Table of Contents](00-table-of-contents.md) - Sequential document listing
- [README](../README.md) - Documentation overview and getting started

---

**Note**: This index is manually maintained. If you find broken links or missing topics, please update this document or file an issue.
