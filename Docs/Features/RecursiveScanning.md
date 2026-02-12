# Recursive Scanning

**Status:** Implemented (Unreleased)  
**Last Updated:** 2026-02-11

## Overview

Forma now scans nested files inside monitored roots (Desktop, Downloads, Documents, Pictures, Music) by default. This applies consistently to:

- Dashboard/manual scans
- Automation scans
- Menu bar scans
- Review scans

Rule behavior is unchanged: existing rules evaluate nested files the same way they evaluate root-level files.

## User Experience

- File views remain flat (card/list/grid).
- Nested files show lightweight path context badges (for example: `Desktop/ProjectX/Assets`).
- Settings now includes `Scan Subfolders` under **General**.

## Safety + Performance Guards

Recursive scanning is bounded by `FileScanOptions`:

- `maxDepth`
- `maxFilesPerRoot`
- `skipHidden`
- `skipPackages`
- symlink exclusion (always on)

This keeps scans predictable for large folder trees.

## Data Model Additions

- `FileMetadata.scanRootPath`
- `FileMetadata.relativeParentPath`
- `FileItem.scanRootPath`
- `FileItem.relativeParentPath`

## Reconciliation Behavior

After each scan, Forma removes stale `pending` / `ready` / `skipped` records under scanned roots if those paths are no longer present in the latest scan result.
