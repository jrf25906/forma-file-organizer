# SwiftData Performance Audit: FileItem

**Current Status**: `FileItem` is currently a Swift `struct`, not a SwiftData `@Model`.
**Goal**: Scale to 10,000+ files.

## 🚨 Critical Findings

### 1. Persistence Strategy
*   **Current**: In-memory struct. Data is lost on app restart.
*   **Risk**: With 10k files, rescanning every launch is slow and battery-intensive.
*   **Recommendation**: Convert to `@Model` to persist scan results and user decisions.

### 2. Identity Stability
*   **Current**: `let id = UUID()` generates a new ID every time the struct is created.
*   **Risk**: If you rescan the folder, the same file gets a new ID, breaking any "History" or "Undo" logic.
*   **Recommendation**: Use the file **path** (or a hash of path + modification date) as the stable persistent identifier.

### 3. Scalability Bottlenecks (for 10k items)

| Feature | Impact | Solution |
| :--- | :--- | :--- |
| **List Rendering** | High | Use `LazyVStack` (SwiftUI) and fetch limits (SwiftData). |
| **Sorting** | Medium | Add `@Attribute(.unique)` to `path` and index `creationDate`. |
| **Memory** | Low | 10k structs is ~2MB RAM. Trivial. But 10k *images* will crash. |

## 🛠 Proposed SwiftData Model

```swift
import SwiftData
import Foundation

@Model
final class FileItem {
    @Attribute(.unique) var path: String // Stable ID
    var name: String
    var fileExtension: String
    var sizeBytes: Int64 // Better than String for sorting
    var creationDate: Date
    var modificationDate: Date // Critical for "stale" rules
    
    var suggestedDestination: String?
    var status: OrganizationStatus
    
    // Relationships (Future)
    // var ruleApplied: Rule? 

    init(path: String, ...) { ... }
}
```

## ⚡️ Optimization Checklist

- [ ] **Batch Inserts**: When scanning, insert items in batches of 500 to avoid UI freeze.
- [ ] **Background Context**: Perform scanning and saving on a background `ModelActor`.
- [ ] **Fetch Descriptors**: Use `FetchDescriptor` with `fetchLimit` for the UI (don't load all 10k at once).
- [ ] **Thumbnail Caching**: Do **not** store image data in SwiftData. Store a path to a cached thumbnail on disk.
