# Data Privacy & Compliance

**Navigation**: [Home](../README.md) > Implementation Standards > Data Privacy & Compliance  
**Related**: [← Previous: Security Architecture](02-security-architecture.md) | [Next: Requirements Engineering →](02b-requirements-engineering.md) | [Security Audit](02-security-architecture.md#audit-logging)

**Version:** 1.3.0  
**Last Updated:** November 20, 2025  
**Status:** Production Ready

## Introduction

Enterprise MCP servers must handle sensitive data responsibly and comply with privacy regulations (GDPR, CCPA, HIPAA). This document covers PII handling, data residency, audit requirements, consent management, and compliance frameworks.

## Regulatory Overview

### Key Regulations

| Regulation | Scope | Key Requirements |
|------------|-------|------------------|
| **GDPR** | EU residents | Right to access, erasure, portability; consent; breach notification |
| **CCPA** | California residents | Right to know, delete, opt-out; disclosure requirements |
| **HIPAA** | US healthcare | PHI protection, access controls, audit logs, breach notification |
| **SOC 2** | Service providers | Security, availability, confidentiality, privacy controls |
| **ISO 27001** | International | Information security management system |

### Compliance Checklist

- ✅ Identify and classify data (PII, PHI, financial)
- ✅ Implement data minimization (collect only necessary)
- ✅ Obtain explicit consent for data processing
- ✅ Provide user access to their data
- ✅ Enable data deletion (right to be forgotten)
- ✅ Encrypt data in transit and at rest
- ✅ Maintain audit logs (who accessed what, when)
- ✅ Implement data retention and deletion policies
- ✅ Conduct privacy impact assessments
- ✅ Appoint Data Protection Officer (if required)

## PII Detection & Classification

### Automatic PII Detection

```python
# src/mcp_server/privacy/detector.py
"""PII detection in tool responses."""

import re
from typing import Any, Dict, List
from enum import Enum

class PIIType(Enum):
    """Types of PII."""
    EMAIL = "email"
    PHONE = "phone"
    SSN = "ssn"
    CREDIT_CARD = "credit_card"
    IP_ADDRESS = "ip_address"
    NAME = "name"
    ADDRESS = "address"
    DATE_OF_BIRTH = "date_of_birth"

class PIIDetector:
    """Detect PII in data."""
    
    PATTERNS = {
        PIIType.EMAIL: re.compile(
            r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        ),
        PIIType.PHONE: re.compile(
            r'\b(\+?1[-.]?)?\(?([0-9]{3})\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\b'
        ),
        PIIType.SSN: re.compile(
            r'\b\d{3}-\d{2}-\d{4}\b'
        ),
        PIIType.CREDIT_CARD: re.compile(
            r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'
        ),
        PIIType.IP_ADDRESS: re.compile(
            r'\b(?:\d{1,3}\.){3}\d{1,3}\b'
        ),
    }
    
    def detect(self, text: str) -> List[Dict[str, Any]]:
        """
        Detect PII in text.
        
        Returns list of matches with type and location.
        """
        findings = []
        
        for pii_type, pattern in self.PATTERNS.items():
            for match in pattern.finditer(text):
                findings.append({
                    "type": pii_type.value,
                    "value": match.group(),
                    "start": match.start(),
                    "end": match.end()
                })
        
        return findings
    
    def has_pii(self, text: str) -> bool:
        """Check if text contains any PII."""
        return len(self.detect(text)) > 0
    
    def detect_in_dict(self, data: dict) -> Dict[str, List[str]]:
        """
        Detect PII in dictionary values.
        
        Returns dict mapping field names to PII types found.
        """
        findings = {}
        
        for key, value in data.items():
            if isinstance(value, str):
                pii_found = self.detect(value)
                if pii_found:
                    findings[key] = [f["type"] for f in pii_found]
            elif isinstance(value, dict):
                nested = self.detect_in_dict(value)
                if nested:
                    findings[key] = nested
        
        return findings

# Global detector
pii_detector = PIIDetector()
```

### Data Classification

```python
# src/mcp_server/privacy/classification.py
"""Data classification system."""

from enum import Enum
from dataclasses import dataclass
from typing import Set

class DataClassification(Enum):
    """Data sensitivity levels."""
    PUBLIC = "public"  # No restrictions
    INTERNAL = "internal"  # Company internal only
    CONFIDENTIAL = "confidential"  # Limited access
    RESTRICTED = "restricted"  # Highly sensitive (PII, PHI)

class PIICategory(Enum):
    """PII categories for GDPR."""
    SPECIAL = "special"  # Health, biometric, genetic
    SENSITIVE = "sensitive"  # Race, religion, political
    PERSONAL = "personal"  # Name, email, address
    IDENTIFIERS = "identifiers"  # IDs, account numbers

@dataclass
class DataField:
    """Classified data field."""
    name: str
    classification: DataClassification
    pii_categories: Set[PIICategory]
    retention_days: int
    encryption_required: bool
    audit_access: bool

# Schema registry with classifications
FIELD_CLASSIFICATIONS = {
    "user": {
        "id": DataField(
            name="id",
            classification=DataClassification.INTERNAL,
            pii_categories={PIICategory.IDENTIFIERS},
            retention_days=2555,  # 7 years
            encryption_required=True,
            audit_access=True
        ),
        "email": DataField(
            name="email",
            classification=DataClassification.RESTRICTED,
            pii_categories={PIICategory.PERSONAL},
            retention_days=2555,
            encryption_required=True,
            audit_access=True
        ),
        "name": DataField(
            name="name",
            classification=DataClassification.RESTRICTED,
            pii_categories={PIICategory.PERSONAL},
            retention_days=2555,
            encryption_required=True,
            audit_access=True
        ),
        "health_records": DataField(
            name="health_records",
            classification=DataClassification.RESTRICTED,
            pii_categories={PIICategory.SPECIAL},
            retention_days=3650,  # 10 years (HIPAA)
            encryption_required=True,
            audit_access=True
        ),
    }
}
```

## PII Masking & Redaction

### Automatic Masking

```python
# src/mcp_server/privacy/masking.py
"""PII masking strategies."""

from typing import Any, Dict, List
import hashlib

class MaskingStrategy(Enum):
    """Masking strategies."""
    FULL = "full"  # Complete redaction: ***
    PARTIAL = "partial"  # Show first/last: u***@example.com
    HASH = "hash"  # One-way hash: sha256(value)
    TOKENIZE = "tokenize"  # Replace with token: <TOKEN_123>

class PIIMasker:
    """Mask PII in data."""
    
    def mask_email(self, email: str, strategy: MaskingStrategy) -> str:
        """Mask email address."""
        if strategy == MaskingStrategy.FULL:
            return "***@***.***"
        
        elif strategy == MaskingStrategy.PARTIAL:
            username, domain = email.split("@")
            masked_user = username[0] + "***" if len(username) > 1 else "***"
            return f"{masked_user}@{domain}"
        
        elif strategy == MaskingStrategy.HASH:
            return hashlib.sha256(email.encode()).hexdigest()
        
        elif strategy == MaskingStrategy.TOKENIZE:
            token = hashlib.md5(email.encode()).hexdigest()[:8]
            return f"<EMAIL_TOKEN_{token}>"
    
    def mask_phone(self, phone: str, strategy: MaskingStrategy) -> str:
        """Mask phone number."""
        if strategy == MaskingStrategy.FULL:
            return "***-***-****"
        
        elif strategy == MaskingStrategy.PARTIAL:
            # Show last 4 digits
            digits = re.sub(r'\D', '', phone)
            return f"***-***-{digits[-4:]}"
        
        elif strategy == MaskingStrategy.HASH:
            return hashlib.sha256(phone.encode()).hexdigest()
        
        elif strategy == MaskingStrategy.TOKENIZE:
            token = hashlib.md5(phone.encode()).hexdigest()[:8]
            return f"<PHONE_TOKEN_{token}>"
    
    def mask_ssn(self, ssn: str, strategy: MaskingStrategy) -> str:
        """Mask SSN."""
        if strategy == MaskingStrategy.FULL:
            return "***-**-****"
        
        elif strategy == MaskingStrategy.PARTIAL:
            # Show last 4 digits
            return f"***-**-{ssn[-4:]}"
        
        # SSN should never be hashed or tokenized without encryption
        return "***-**-****"
    
    def mask_dict(
        self,
        data: dict,
        field_classifications: Dict[str, DataField],
        strategy: MaskingStrategy = MaskingStrategy.PARTIAL
    ) -> dict:
        """Mask PII fields in dictionary."""
        masked = {}
        
        for key, value in data.items():
            field_def = field_classifications.get(key)
            
            if field_def and PIICategory.PERSONAL in field_def.pii_categories:
                # Mask based on field type
                if key == "email" and isinstance(value, str):
                    masked[key] = self.mask_email(value, strategy)
                elif key == "phone" and isinstance(value, str):
                    masked[key] = self.mask_phone(value, strategy)
                elif key == "ssn" and isinstance(value, str):
                    masked[key] = self.mask_ssn(value, strategy)
                else:
                    # Generic masking
                    masked[key] = "***"
            else:
                masked[key] = value
        
        return masked

# Global masker
pii_masker = PIIMasker()
```

### Tool Response Masking

```python
from mcp_server.privacy import pii_masker, FIELD_CLASSIFICATIONS

@mcp.tool()
async def get_user_profile(
    user_id: str,
    include_pii: bool = False  # Explicit consent required
) -> dict:
    """
    Get user profile with automatic PII masking.
    
    Args:
        user_id: User identifier
        include_pii: Whether to include unmasked PII (requires consent)
    """
    # Fetch user data
    user = await backend.get_user(user_id)
    user_dict = user.to_dict()
    
    # Mask PII unless explicitly requested
    if not include_pii:
        user_dict = pii_masker.mask_dict(
            user_dict,
            FIELD_CLASSIFICATIONS["user"],
            strategy=MaskingStrategy.PARTIAL
        )
    else:
        # Log PII access for audit
        await audit_log.log_pii_access(
            user_id=user_id,
            accessed_by=current_user_id,
            fields=["email", "phone", "ssn"],
            reason="explicit_consent"
        )
    
    return {
        "success": True,
        "data": user_dict,
        "pii_masked": not include_pii
    }
```

## Data Retention & Deletion

### Retention Policy

```python
# src/mcp_server/privacy/retention.py
"""Data retention policy enforcement."""

from datetime import datetime, timedelta
from typing import List

class RetentionPolicy:
    """Data retention policy manager."""
    
    # Retention periods by data type
    RETENTION_PERIODS = {
        "audit_logs": timedelta(days=2555),  # 7 years
        "tool_execution_logs": timedelta(days=90),
        "user_pii": timedelta(days=2555),  # 7 years or until deletion request
        "session_data": timedelta(hours=24),
        "cache_data": timedelta(hours=1),
        "metrics": timedelta(days=395),  # 13 months
    }
    
    async def enforce_retention(self):
        """Delete expired data."""
        now = datetime.utcnow()
        
        for data_type, retention in self.RETENTION_PERIODS.items():
            cutoff = now - retention
            
            if data_type == "audit_logs":
                await self._delete_old_audit_logs(cutoff)
            elif data_type == "tool_execution_logs":
                await self._delete_old_tool_logs(cutoff)
            elif data_type == "session_data":
                await self._delete_old_sessions(cutoff)
    
    async def _delete_old_audit_logs(self, cutoff: datetime):
        """Delete audit logs older than retention period."""
        await db_pool.execute(
            """
            DELETE FROM audit_logs
            WHERE timestamp < $1
            AND retention_category = 'standard'
            """,
            cutoff
        )
    
    async def _delete_old_tool_logs(self, cutoff: datetime):
        """Delete tool execution logs."""
        await db_pool.execute(
            "DELETE FROM tool_execution_logs WHERE timestamp < $1",
            cutoff
        )
    
    async def _delete_old_sessions(self, cutoff: datetime):
        """Delete expired session data."""
        if redis_cache.redis:
            # Redis TTL handles this automatically
            pass

# Schedule retention enforcement
@mcp.scheduled("0 2 * * *")  # Daily at 2 AM
async def enforce_retention_policy():
    """Run retention policy enforcement."""
    policy = RetentionPolicy()
    await policy.enforce_retention()
```

### Right to Erasure (GDPR)

```python
@mcp.tool()
async def delete_user_data(
    user_id: str,
    reason: str,
    requester: str
) -> dict:
    """
    Delete all user data (Right to be Forgotten).
    
    GDPR Article 17: Right to erasure
    
    Args:
        user_id: User to delete
        reason: Reason for deletion
        requester: Who requested deletion
    """
    # Log deletion request for audit
    await audit_log.log_deletion_request(
        user_id=user_id,
        reason=reason,
        requester=requester
    )
    
    # Delete user data from all systems
    async with db_pool.pool.acquire() as conn:
        async with conn.transaction():
            # Delete user record
            await conn.execute(
                "DELETE FROM users WHERE id = $1",
                user_id
            )
            
            # Delete related data
            await conn.execute(
                "DELETE FROM user_sessions WHERE user_id = $1",
                user_id
            )
            
            # Anonymize audit logs (keep for compliance)
            await conn.execute(
                """
                UPDATE audit_logs
                SET user_id = 'DELETED_USER',
                    user_email = 'deleted@example.com'
                WHERE user_id = $1
                """,
                user_id
            )
    
    # Clear caches
    await redis_cache.clear_pattern(f"user:{user_id}:*")
    
    # Log completion
    await audit_log.log_deletion_completed(user_id=user_id)
    
    return {
        "success": True,
        "user_id": user_id,
        "deleted_at": datetime.utcnow().isoformat(),
        "message": "All user data deleted"
    }
```

## Data Access Rights

### Right to Access (GDPR Article 15)

```python
@mcp.tool()
async def export_user_data(
    user_id: str,
    format: str = "json"
) -> dict:
    """
    Export all data for a user (GDPR data portability).
    
    Args:
        user_id: User identifier
        format: Export format (json, csv, xml)
    """
    # Collect all user data
    user_data = {
        "user_profile": await backend.get_user(user_id),
        "assignments": await backend.get_user_assignments(user_id),
        "activity_log": await backend.get_user_activity(user_id),
        "preferences": await backend.get_user_preferences(user_id),
        "consents": await backend.get_user_consents(user_id),
    }
    
    # Format data
    if format == "json":
        export_data = json.dumps(user_data, indent=2)
    elif format == "csv":
        export_data = convert_to_csv(user_data)
    elif format == "xml":
        export_data = convert_to_xml(user_data)
    
    # Log data export for audit
    await audit_log.log_data_export(
        user_id=user_id,
        format=format,
        timestamp=datetime.utcnow()
    )
    
    return {
        "success": True,
        "user_id": user_id,
        "format": format,
        "data": export_data,
        "exported_at": datetime.utcnow().isoformat()
    }
```

## Consent Management

### Consent Tracking

```python
# src/mcp_server/privacy/consent.py
"""User consent management."""

from enum import Enum
from datetime import datetime

class ConsentType(Enum):
    """Types of consent."""
    ESSENTIAL = "essential"  # Required for service
    ANALYTICS = "analytics"  # Usage analytics
    MARKETING = "marketing"  # Marketing communications
    THIRD_PARTY = "third_party"  # Third-party data sharing
    PII_ACCESS = "pii_access"  # Access to PII

class ConsentManager:
    """Manage user consents."""
    
    async def record_consent(
        self,
        user_id: str,
        consent_type: ConsentType,
        granted: bool,
        version: str = "1.0"
    ):
        """Record user consent."""
        await db_pool.execute(
            """
            INSERT INTO user_consents
            (user_id, consent_type, granted, version, timestamp)
            VALUES ($1, $2, $3, $4, $5)
            """,
            user_id,
            consent_type.value,
            granted,
            version,
            datetime.utcnow()
        )
    
    async def check_consent(
        self,
        user_id: str,
        consent_type: ConsentType
    ) -> bool:
        """Check if user has granted consent."""
        row = await db_pool.fetch(
            """
            SELECT granted FROM user_consents
            WHERE user_id = $1 AND consent_type = $2
            ORDER BY timestamp DESC
            LIMIT 1
            """,
            user_id,
            consent_type.value
        )
        return row[0]["granted"] if row else False
    
    async def get_user_consents(self, user_id: str) -> dict:
        """Get all consents for user."""
        rows = await db_pool.fetch(
            """
            SELECT DISTINCT ON (consent_type)
                consent_type, granted, version, timestamp
            FROM user_consents
            WHERE user_id = $1
            ORDER BY consent_type, timestamp DESC
            """,
            user_id
        )
        return {r["consent_type"]: r["granted"] for r in rows}

# Global consent manager
consent_manager = ConsentManager()

# Consent decorator
def requires_consent(consent_type: ConsentType):
    """Decorator to enforce consent check."""
    def decorator(func):
        @wraps(func)
        async def wrapper(user_id: str, **kwargs):
            # Check consent
            has_consent = await consent_manager.check_consent(
                user_id,
                consent_type
            )
            
            if not has_consent:
                return {
                    "success": False,
                    "error": "consent_required",
                    "message": f"User must consent to {consent_type.value}",
                    "consent_url": f"/consent/{consent_type.value}"
                }
            
            return await func(user_id=user_id, **kwargs)
        return wrapper
    return decorator

# Usage
@mcp.tool()
@requires_consent(ConsentType.PII_ACCESS)
async def get_sensitive_user_data(user_id: str) -> dict:
    """Get sensitive data requiring explicit consent."""
    return await backend.get_user_pii(user_id)
```

## Data Residency

### Geographic Data Placement

```python
# src/mcp_server/privacy/residency.py
"""Data residency enforcement."""

from enum import Enum

class DataRegion(Enum):
    """Supported data regions."""
    US = "us"
    EU = "eu"
    UK = "uk"
    APAC = "apac"

class ResidencyPolicy:
    """Enforce data residency requirements."""
    
    # Region-specific database connections
    REGION_DATABASES = {
        DataRegion.US: "postgresql://us-db.example.com/mcp",
        DataRegion.EU: "postgresql://eu-db.example.com/mcp",
        DataRegion.UK: "postgresql://uk-db.example.com/mcp",
        DataRegion.APAC: "postgresql://apac-db.example.com/mcp",
    }
    
    def get_user_region(self, user_id: str) -> DataRegion:
        """Determine user's data region."""
        # Lookup user's region from profile
        user = await backend.get_user(user_id)
        return DataRegion(user.data_region)
    
    def get_regional_db(self, region: DataRegion):
        """Get database connection for region."""
        return self.REGION_DATABASES[region]

# Regional routing middleware
@mcp.middleware
async def regional_routing(request, call_next):
    """Route requests to regional database."""
    user_id = request.headers.get("X-User-ID")
    
    if user_id:
        region = residency_policy.get_user_region(user_id)
        regional_db = residency_policy.get_regional_db(region)
        
        # Set regional database in request context
        request.state.db = regional_db
    
    return await call_next(request)
```

## Audit Logging for Compliance

### Comprehensive Audit Trail

```python
# src/mcp_server/privacy/audit.py
"""Compliance audit logging."""

class ComplianceAuditLog:
    """Audit log for compliance."""
    
    async def log_pii_access(
        self,
        user_id: str,
        accessed_by: str,
        fields: List[str],
        reason: str
    ):
        """Log PII access for compliance."""
        await db_pool.execute(
            """
            INSERT INTO compliance_audit_log
            (event_type, user_id, accessed_by, fields, reason, timestamp)
            VALUES ('pii_access', $1, $2, $3, $4, $5)
            """,
            user_id,
            accessed_by,
            fields,
            reason,
            datetime.utcnow()
        )
    
    async def log_deletion_request(
        self,
        user_id: str,
        reason: str,
        requester: str
    ):
        """Log data deletion request."""
        await db_pool.execute(
            """
            INSERT INTO compliance_audit_log
            (event_type, user_id, accessed_by, reason, timestamp)
            VALUES ('deletion_request', $1, $2, $3, $4)
            """,
            user_id,
            requester,
            reason,
            datetime.utcnow()
        )
    
    async def log_consent_change(
        self,
        user_id: str,
        consent_type: str,
        granted: bool
    ):
        """Log consent changes."""
        await db_pool.execute(
            """
            INSERT INTO compliance_audit_log
            (event_type, user_id, metadata, timestamp)
            VALUES ('consent_change', $1, $2, $3)
            """,
            user_id,
            json.dumps({"consent_type": consent_type, "granted": granted}),
            datetime.utcnow()
        )

# Global audit log
compliance_audit = ComplianceAuditLog()
```

## Privacy Impact Assessment

### Assessment Template

When implementing new tools or features, complete this assessment:

1. **Data Collection**
   - What personal data is collected?
   - Is it necessary for the tool's purpose?
   - Can it be minimized or anonymized?

2. **Data Usage**
   - How will the data be used?
   - Who will have access?
   - Is consent required?

3. **Data Retention**
   - How long will data be kept?
   - What is the deletion process?
   - Are backups included?

4. **Data Sharing**
   - Will data be shared with third parties?
   - Is data transferred across borders?
   - Are appropriate safeguards in place?

5. **Risk Assessment**
   - What are the privacy risks?
   - What is the impact if data is breached?
   - What mitigations are in place?

## Summary

Privacy and compliance requirements:

1. **Detect and classify PII automatically**
2. **Mask sensitive data by default**
3. **Enforce retention policies**
4. **Support right to erasure and access**
5. **Track and verify user consent**
6. **Respect data residency requirements**
7. **Maintain comprehensive audit logs**
8. **Conduct privacy impact assessments**
9. **Train team on privacy requirements**
10. **Regular compliance audits**
