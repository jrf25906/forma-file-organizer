# Recursive Scan Pipeline

**Status:** Current  
**Last Updated:** 2026-02-11

## Flow

1. Scan entrypoint resolves runtime options via `ScanOptionsResolver.current()`.
2. `FileScanPipeline.scanAndPersist(...)` forwards `FileScanOptions` to `FileSystemService`.
3. `FileSystemService` enumerates each root with bounded recursion and skip rules.
4. Each discovered file is emitted as `FileMetadata` with:
   - `scanRootPath`
   - `relativeParentPath`
5. Pipeline evaluates rules/patterns/ML as before.
6. Pipeline upserts `FileItem` rows and reconciles stale rows under scanned roots.

## Key Types

- `FileScanOptions` (scan constraints)
- `ScanOptionsResolver` (feature-flag + user-setting merge)
- `ScanResult.scannedRootPaths` (used for reconciliation)

## Reconciliation Policy (Current)

- Remove missing files under scanned roots when status is:
  - `pending`
  - `ready`
  - `skipped`
- Preserve `completed` records.

## UI Contract

- UI stays flat (no tree navigation).
- Nested context comes from `FileItem.relativePathContextLabel`.
