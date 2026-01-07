# AI-Powered Features

**Version:** 1.0
**Last Updated:** December 2025
**Status:** Implemented (Phase 1 & 2)

## Overview

Forma's AI-powered features provide intelligent file organization suggestions by learning from user behavior, detecting related files, and identifying duplicates. These features operate locally without external API calls, ensuring privacy and fast performance.

## Core Concept

The AI layer observes how users organize files and builds a model of their preferences:
- **Pattern Learning** — Detects repeated behaviors and suggests rules
- **Project Detection** — Groups related files by client, project, or context
- **Duplicate Detection** — Identifies redundant files to recover disk space

---

## Feature 1: Pattern Learning

### Overview

The Learning Service observes user file movements and detects patterns that could be automated into rules.

### How It Works

1. User manually organizes files (approve/reject suggestions)
2. System records each action with file metadata
3. Pattern detection runs after sufficient data collected
4. Patterns with high confidence become rule suggestions

### Pattern Types

| Type | Description | Example |
|------|-------------|---------|
| **Extension Pattern** | Files with same extension go to same folder | `.pdf` files → `~/Documents/PDFs` |
| **Name Prefix Pattern** | Files with common prefix grouped | `Invoice_*` → `~/Finance/Invoices` |
| **Temporal Pattern** | Time-based organization habits | Work files organized Monday mornings |
| **Compound Pattern** | Multiple conditions combined | `.psd` files with "ClientX_" prefix → `~/Clients/X/Design` |
| **Negative Pattern** | Rejections that should be avoided | User always rejects `.tmp` file suggestions |

### Pattern Condition Types

```swift
enum PatternCondition: Codable, Hashable {
    case fileExtension(String)      // .pdf, .docx
    case nameContains(String)       // "invoice", "report"
    case namePrefix(String)         // "ClientABC_"
    case sizeGreaterThan(Int64)     // Files > 10MB
    case sizeLessThan(Int64)        // Files < 1KB
    case sourceFolder(String)       // From ~/Downloads
    case dayOfWeek(Int)             // Monday = 2
    case timeOfDay(hour: Int, minute: Int)  // 9:00 AM
}
```

### Confidence Scoring

Patterns are scored based on:
- **Occurrence count** — More observations = higher confidence
- **Consistency** — Same behavior repeated = higher confidence
- **Recency** — Recent actions weighted more heavily
- **Rejection tracking** — Rejections reduce confidence

**Thresholds:**
- `< 0.5` — Not suggested
- `0.5 - 0.7` — Suggested with "Review" action
- `0.7 - 0.9` — Suggested with moderate confidence
- `> 0.9` — High confidence, prominent suggestion

### UI Integration

Learned patterns appear in:
- **AIInsightsView** — Dashboard panel showing discovered patterns
- **RuleSuggestionView** — Converts patterns to rules on user confirmation
- **InlineRuleBuilderView** — Pre-fills conditions from patterns

---

## Feature 2: Project/Client Detection

### Overview

The Context Detection Service identifies files that belong together based on naming, timing, or content patterns.

### Detection Methods

#### 1. Prefix Detection
Groups files sharing a common prefix before `_`, `-`, or space.

**Example:**
```
ClientABC_proposal.pdf
ClientABC_contract.docx
ClientABC_invoice.xlsx
→ Detected as "ClientABC" project
```

#### 2. Pattern Matching (Regex)
Detects structured identifiers in filenames.

**Supported Patterns:**
| Pattern | Example | Description |
|---------|---------|-------------|
| Ticket IDs | `JIRA-123`, `TICKET-456` | Issue tracker references |
| Project Codes | `P-1024`, `PRJ-2024-001` | Alphanumeric project codes |
| Date Stamps | `2024-12-01`, `20241201` | Date-based groupings |
| Version Markers | `v1.0`, `v2.1.3` | Version series detection |

#### 3. Temporal Clustering
Groups files modified within the same work session.

**Parameters:**
- Session window: 4 hours (configurable)
- Minimum cluster size: 3 files
- Same-day preference for initial grouping

### Cluster Types

```swift
enum ClusterType: String, Codable {
    case projectCode     // Detected via prefix/pattern
    case temporal        // Detected via timing
    case nameSimilarity  // Detected via Levenshtein
    case dateStamp       // Detected via date patterns
}
```

### ProjectCluster Model

```swift
@Model class ProjectCluster {
    var projectName: String           // "ClientABC" or "Website Redesign"
    var suggestedFolderName: String   // Recommended organization folder
    var files: [String]               // File paths in cluster
    var clusterType: ClusterType      // How it was detected
    var confidence: Double            // Detection confidence (0-1)
}
```

### UI Integration

Project clusters appear in:
- **ProjectClusterView** — Expandable cards showing detected groups
- **AIInsightsView** — Summary count of detected projects
- **RightPanelView** — Context panel when cluster selected

---

## Feature 3: Duplicate Detection

### Overview

The Duplicate Detection Service identifies redundant files using three detection strategies.

### Detection Strategies

#### 1. Exact Duplicates (SHA-256)
Files with identical content regardless of filename.

**Process:**
1. Group files by size (quick filter)
2. Calculate SHA-256 hash for size-matched files
3. Group files with matching hashes

**Use Case:** Same file saved multiple times with different names.

#### 2. Version Series
Files that are versions of the same document.

**Detected Markers:**
- `v1`, `v2`, `v3`
- `FINAL`, `Final`, `final`
- `copy`, `Copy`, `COPY`
- `backup`, `Backup`
- `(1)`, `(2)`, `(3)` — system-generated copies

**Example:**
```
Report.docx
Report v2.docx
Report FINAL.docx
Report FINAL (1).docx
→ Detected as version series
```

#### 3. Near Duplicates (Levenshtein)
Files with similar names that may be duplicates.

**Algorithm:**
- Calculate Levenshtein distance between filenames
- Distance < 3 characters = potential duplicate
- Group by base name similarity

**Example:**
```
Screenshot 2024-12-01.png
Screenshot 2024-12-01 2.png
→ Levenshtein distance: 2 (near duplicate)
```

### Duplicate Types

```swift
enum DuplicateType {
    case exactDuplicate   // Same SHA-256 hash
    case versionSeries    // Version markers detected
    case nearDuplicate    // Similar filename (Levenshtein < 3)
}
```

### DuplicateGroup Model

```swift
struct DuplicateGroup: Identifiable {
    let id: UUID
    let files: [FileItem]
    let type: DuplicateType
    let description: String           // Human-readable description
    let potentialSpaceSavings: Int64  // Bytes recoverable
    let suggestedAction: SuggestedAction
}

enum SuggestedAction {
    case keepNewest    // Keep most recently modified
    case keepLargest   // Keep largest file
    case review        // Manual review needed
}
```

### Space Savings Calculation

For each duplicate group:
```
savings = sum(all file sizes) - max(file size in group)
```

The largest/newest file is suggested to keep, others contribute to savings.

### UI Integration

Duplicates appear in:
- **DuplicateGroupsView** — Full duplicate management interface
- **AIInsightsView** — Summary with total potential savings
- **Summary Card** — Shows breakdown by duplicate type

---

## Architecture

### Service Layer

| Service | Purpose | Key Method |
|---------|---------|------------|
| `LearningService` | Pattern learning | `learnPatterns() -> [LearnedPattern]` |
| `ContextDetectionService` | Project detection | `detectProjects(from:) -> [ProjectCluster]` |
| `DuplicateDetectionService` | Duplicate finding | `detectDuplicates(in:) -> [DuplicateGroup]` |

### Data Flow

```
User Action (approve/reject)
        ↓
LearningService.recordUserAction()
        ↓
Pattern Analysis (on threshold)
        ↓
LearnedPattern stored in SwiftData
        ↓
AIInsightsView displays suggestion
        ↓
User creates rule (or dismisses)
```

### SwiftData Models

- `LearnedPattern` — Persisted learned patterns
- `ProjectCluster` — Persisted project groupings
- `UserActionHistory` — Action log for learning

---

## Privacy & Performance

### Local Processing
All AI features run entirely on-device:
- No external API calls
- No data leaves the device
- Works offline

### Performance Considerations
- Pattern learning runs asynchronously
- Duplicate detection uses size pre-filtering
- SHA-256 hashing done on-demand (not for all files)
- Temporal clustering uses indexed date queries

### User Control
- All suggestions can be dismissed
- Patterns can be deleted from learning history
- Detection can be disabled per-folder in settings

---

## Future Enhancements (Phase 3+)

The following features are planned but not yet implemented:

| Feature | Description | Status |
|---------|-------------|--------|
| ML-Based Prediction | CoreML model for destination prediction | Implemented (`DestinationPredictionService`, FileScanPipeline) |
| Natural Language Parsing | "Move invoices to finance folder" | Implemented (`NaturalLanguageRuleParser`, `NaturalLanguageRuleView`) |
| Content Analysis | AI-based image/document categorization | Planned |
| Smart Folders | Auto-updating organization based on rules | Planned |

---

## Related Documentation

- [Architecture/ARCHITECTURE.md](../Architecture/ARCHITECTURE.md) — Service architecture
- [Architecture/ComponentArchitecture.md](../Architecture/ComponentArchitecture.md) — AI component docs
- [AI-Feature-Development-Plan.md](../Research/AI-Feature-Development-Plan.md) — Implementation roadmap
- [API-Reference/API_REFERENCE.md](../API-Reference/API_REFERENCE.md) — Service API details
