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
