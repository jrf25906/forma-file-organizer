# Security Documentation

This folder contains all security-related documentation for Forma.

**Status:** Current  
**Last Updated:** 2026-01-06  
**Audience:** Developers | Security

## Overview

Forma handles sensitive file operations and requires careful security considerations for:
- File system access and sandboxing
- Bookmark storage and validation
- Path traversal prevention
- Symlink attack protection

## Key Documents

### Security Checklists
- **[SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md)** - Comprehensive security checklist
- **[SECURITY_CHECKLIST_BOOKMARK_HANDLING.md](SECURITY_CHECKLIST_BOOKMARK_HANDLING.md)** - Bookmark-specific security

### Implementation Guides
- **[SECURITY_CONFIGURATION.md](SECURITY_CONFIGURATION.md)** - Security configuration options
- **[SECURITY_IMPLEMENTATION_SUMMARY.md](SECURITY_IMPLEMENTATION_SUMMARY.md)** - Implementation overview
- **[SECURE_BOOKMARK_STORAGE_GUIDE.md](SECURE_BOOKMARK_STORAGE_GUIDE.md)** - Secure bookmark storage

### Audit Reports
- **[SECURITY_AUDIT_BOOKMARK_STORAGE.md](SECURITY_AUDIT_BOOKMARK_STORAGE.md)** - Bookmark storage audit
- **[SECURITY_AUDIT_BOOKMARK_VALIDATION.md](SECURITY_AUDIT_BOOKMARK_VALIDATION.md)** - Bookmark validation audit
- **[SECURITY_AUDIT_PATH_TRAVERSAL_FIX.md](SECURITY_AUDIT_PATH_TRAVERSAL_FIX.md)** - Path traversal fix
- **[SECURITY_AUDIT_RATE_LIMITING.md](SECURITY_AUDIT_RATE_LIMITING.md)** - Rate limiting implementation
- **[SECURITY_AUDIT_SYMLINK_PROTECTION.md](SECURITY_AUDIT_SYMLINK_PROTECTION.md)** - Symlink protection
- **[SECURITY_AUDIT_TOCTOU_FIX.md](SECURITY_AUDIT_TOCTOU_FIX.md)** - TOCTOU vulnerability fix

### Technical Details
- **[SECURITY_FLOW_DIAGRAM.md](SECURITY_FLOW_DIAGRAM.md)** - Security flow diagrams
- **[SECURITY_VALIDATION_FLOW.md](SECURITY_VALIDATION_FLOW.md)** - Validation flow details
- **[SECURITY_FIX_SUMMARY.md](SECURITY_FIX_SUMMARY.md)** - Summary of security fixes
- **[SECURITY_HEADERS_CONFIG.md](SECURITY_HEADERS_CONFIG.md)** - Headers configuration
- **[SECURITY_SCOPED_RESOURCE_FIX.md](SECURITY_SCOPED_RESOURCE_FIX.md)** - Scoped resource handling
- **[SECURITY_TEST_EXAMPLES.md](SECURITY_TEST_EXAMPLES.md)** - Security testing examples

### Quick References
- **[SYMLINK_SECURITY_QUICK_REFERENCE.md](SYMLINK_SECURITY_QUICK_REFERENCE.md)** - Symlink security quick ref
- **[TOCTOU_FIX_SUMMARY.md](TOCTOU_FIX_SUMMARY.md)** - TOCTOU fix summary
- **[IMPLEMENTATION_SUMMARY_SYMLINK_PROTECTION.md](IMPLEMENTATION_SUMMARY_SYMLINK_PROTECTION.md)** - Symlink protection summary
