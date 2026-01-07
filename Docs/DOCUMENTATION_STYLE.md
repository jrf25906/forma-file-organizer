# Documentation Style Guide

This guide defines conventions for writing and maintaining documentation in this repo.

## Document Header (Recommended)

Add a small metadata block near the top of new docs so readers can quickly judge freshness and intended audience.

**Template (current docs):**

```md
**Status:** Current
**Last Updated:** YYYY-MM-DD
**Audience:** Users | Developers | Designers | Security
```

**Template (archived docs):**

```md
**Status:** Archived (historical)
**Archived:** YYYY-MM
**Superseded By:** <link to current doc, if applicable>
```

## Paths, Commands, and Placeholders

- Prefer **repo-relative paths** (e.g., `Forma File Organizing/Services/FileOperationsService.swift`) over absolute paths like `/Users/...`.
- For examples that must show a user path, use **placeholders**:
  - `/Users/username/...` (preferred in log snippets)
  - `~/...` (preferred in shell commands)
  - `<repo-root>` for clone locations
- For bundle identifiers/domains, use:
  - `com.yourteam.Forma-File-Organizing` (placeholders in `defaults` examples)

## Linking

- Use clickable relative links (e.g., `[Setup](Getting-Started/SETUP.md)`).
- Avoid leading slashes in repo paths (use `Docs/...`, not `/Docs/...`) unless explicitly documenting an absolute filesystem path.

## Archive Policy

Archived docs are kept for historical context, but they should still be safe to share:
- Avoid real usernames/emails in examples and logs when possible.
- Add an “Archived” header and point to the current source of truth when available.
