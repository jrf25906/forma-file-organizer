# API Reference

Canonical API reference: [Docs/API-Reference/API_REFERENCE.md](Docs/API-Reference/API_REFERENCE.md).

## Recent Additions (Unreleased)

- `FileScanOptions` (`Forma File Organizing/Services/FileSystemService.swift`)
  - `isRecursive: Bool`
  - `maxDepth: Int`
  - `maxFilesPerRoot: Int`
  - `skipPackages: Bool`
  - `skipHidden: Bool`
- `FileMetadata`
  - `scanRootPath: String?`
  - `relativeParentPath: String?`
- `FileItem`
  - `scanRootPath: String?`
  - `relativeParentPath: String?`
  - `relativePathContextLabel: String?` (computed)
- `InsightsService.generateInsights(...)`
  - Async API now supports `precomputedClusters: [ProjectCluster]?` for reusing dashboard-detected clusters.
  - Insight generation now checks cancellation between major phases and returns early without partial completion metadata when superseded.
- `DashboardViewModel`
  - Content-search pipeline now deduplicates unchanged query/file snapshots before scheduling a new search.
  - Publishes `scanPhaseStatusText: String?` for lightweight scan progress messaging (`Preparing scan`, `Scanning folders`, `Analyzing clusters`, `Updating dashboard`).
