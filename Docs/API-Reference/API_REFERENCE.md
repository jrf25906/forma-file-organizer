# Forma - API Reference

**Version:** 2.3
**Last Updated:** April 2026
**Status:** Current Implementation

---

## Table of Contents

### Services
1. [Overview](#overview)
2. [FileSystemService](#filesystemservice)
3. [RuleEngine](#ruleengine)
4. [FileOperationsService](#fileoperationsservice)
5. [ContextDetectionService](#contextdetectionservice)
6. [LearningService](#learningservice)
7. [PersonalMemoryService](#personalmemoryservice)
8. [InsightsService](#insightsservice)
9. [CustomFolderManager](#customfoldermanager)
10. [SecureBookmarkStore](#securebookmarkstore)
11. [NotificationService](#notificationservice)
12. [RuleService](#ruleservice)
13. [ThumbnailService](#thumbnailservice)
14. [UndoCommand](#undocommand)
15. [AutomationEngine](#automationengine)

### ViewModels
16. [ReviewViewModel](#reviewviewmodel)

### Models
17. [FileItem](#fileitem)
18. [Rule](#rule)
19. [OrganizationTemplate](#organizationtemplate)
20. [OrganizationPersonality](#organizationpersonality)
21. [ProjectCluster](#projectcluster)
22. [LearnedPattern](#learnedpattern)
23. [ActivityItem](#activityitem)
24. [CustomFolder](#customfolder)

### Website Public API
25. [Website Public API (forma-website)](#website-public-api-forma-website)

### Reference
26. [Error Types](#error-types)
27. [Usage Examples](#usage-examples)

---

## Overview

This document provides detailed API documentation for Forma's core services and components. All APIs are designed for internal use within the Forma application.

### Import Requirements

```swift
import Foundation
import SwiftUI
import Combine
import AppKit
import SwiftData
```

### Thread Safety

All service methods are thread-safe and use `async/await` for concurrency. ViewModel methods must be called on `@MainActor`.

### Recent API Updates (April 2026)

- `Scripts/verify_test_plan_membership.py` now discovers XCTest and Swift Testing suites from the app and UI test targets, classifies Unit/Integration/Performance/UI ownership, and fails when Xcode `selectedTests` membership drifts from the filesystem.
- `ThumbnailService.shared` now constructs the singleton before scheduling startup cache maintenance, retains that maintenance `Task`, and routes thumbnail diagnostics through `Log.debug` instead of writing previewed file paths to a shared `/tmp` file.
- `UITestFolderAccessConfiguration.isEnabled` now reads UI/perf harness argv only in `DEBUG` or `UI_TESTS` builds; `isEnabled(arguments:)` exposes the same parser for unit coverage, Release builds compile a false-only stub, and a compile-time guard prevents `UI_TESTS` from being defined outside Debug.
- `Scripts/verify_security_configuration.sh` builds the Release app, verifies the compiled binary omits UI-test env overrides plus the legacy thumbnail `/tmp` log path, and confirms Release builds fail when `UI_TESTS` is defined.
- `CoreMLPredictionEngine.outcome(from:)` now extracts destination-prediction labels and sorted confidence values from Core ML feature-provider output when probabilities are available, and `CoreMLPredictionEngine.predictedLabel(from:)` supports label-only evaluator scoring without inventing confidence.
- `DestinationPredictionService` now trains and evaluates destination classifiers through off-main `DestinationModelTrainer`, `DestinationModelEvaluator`, and `MLModel.prediction(from:)`, uses real probabilities when exposed, rejects label-only output with an explicit missing-probability note, reports weak confidence separation with threshold-specific notes, compiles classifiers off the main actor through `DestinationModelCompiler`, uses bounded sample-before-cap dataset preparation through `DestinationTrainingDatasetPreparer.prepare(records:maximumDatasetSize:trainFraction:sampler:)`, and emits POSIX UTC model versions through `DestinationModelVersion.string(for:)`.
- `RetentionConfig` and `FormaConfig.retention` now define the shared retention window/caps used for workflow audit, trusted-scope run history, and personal-memory event history.
- `HistoryRetentionService` now centralizes full-sweep and surface-specific pruning with a 90-day cutoff plus default caps of 2,000 workflow runs, 100 trusted-scope runs per scope, and 10,000 personal-memory events.
- `WorkflowAuditStore.init(modelContext:nowProvider:)` now supports deterministic cutoff testing, and latest-run / latest-path / step / file-action lookups now use bounded predicates, sort descriptors, and fetch limits instead of fetch-all plus in-memory filtering.
- `TrustedAutomationScopeCatalogService` and `TrustedAutomationScopeService` now build trusted-scope latest-run summaries and recommendation evidence from the same bounded retention window instead of scanning unbounded history.
- `FileMetadataFoundationService.recordTransitionWithoutSaving(...)`, `PersonalMemoryService.recordDecisionWithoutSaving(...)`, `PersonalMemoryService.pruneRetainedHistory(now:)`, and the new no-save activity logging helpers now let bulk organize/undo/redo stage metadata history, personal-memory events, and audit rows inside one transaction.
- `FileOrganizationCoordinator` now prefetches bulk organize/undo/redo state once, commits one `ModelContext` save per batch, and compensates successful disk moves if the final persistence save fails so disk and SwiftData remain aligned.
- `DashboardPermissionState.requestAccess(for:using:)` now treats `.granted` as "picker request succeeded and post-request runtime verification passed", and `OnboardingFlowView` keeps users on `Get Started` with a retryable error when Downloads access is cancelled or cannot be verified.
- `RightPanelWidthClass`, `RightPanelLayout`, and `EnvironmentValues.rightPanelLayout` now define the shared measured-width contract for the dashboard detail column.
- `RightPanelView` now derives that contract from the live detail-column width and `FormaSpacing.Column.rightPanelIdeal`, while `FormaSpacing.Column.rightPanelMin/Ideal/Max` remain the only right-panel width source of truth.
- `DefaultPanelView`, `FileInspectorView`, `RulesManagementView`, `InlineRuleBuilderView`, `CelebrationView`, and `CompletionCelebrationView` now consume `rightPanelLayout` so compact right-panel layouts stack or wrap controls before content truncates.
- `ProjectCluster.filePathsSearchBlob` now defaults to an empty string so stores created before that denormalized search field existed can still open under the current app schema and rebuild the blob lazily from `filePaths`.
- Added `Forma File OrganizingTests/AppStoreMigrationTests.swift` coverage for legacy pre-metadata stores containing `FileItem`, `LearnedPattern`, and `ProjectCluster` rows.
- `FeatureFlagService.Feature.projectSpaces` still gates the shipped project-space retrieval slice, and `FeatureFlagService.Feature.projectSpaceAutomationBoard` now gates the policy-centered board layered on top of it.
- `ProjectSpaceSummary`, `ProjectSpaceFileRow`, `ProjectSpaceDetail`, `FileMetadataFoundationService.fetchProjectSpaceSummaries()`, and `fetchProjectSpaceDetail(for:)` still provide the metadata-backed retrieval surface and strict membership rules for files with durable `projectAssociation` labels that still resolve locally.
- `ProjectSpaceAutomationProfile`, `ProjectSpaceAutomationPolicy`, `ProjectSpaceAutomationRunRecord`, `ProjectSpaceAutomationService`, `ProjectSpaceAutomationRecommendationService`, `ProjectSpaceAdmissionResolver`, `ProjectAutomationOwnershipResolver`, and `ProjectSpaceAutomationCoordinator` now model policy recommendations, lifecycle state, latest runs, and admission checks for project-space-owned automation.
- `ProjectSpaceAutomationBoard`, `ProjectSpaceAutomationBoardGroup`, `ProjectSpaceAutomationPolicyDetail`, and `ProjectSpaceDetailView.Snapshot.automationSection` now power the grouped project-policy board in the dashboard.
- `DashboardViewModel`, `ProjectSpacesSection`, `ProjectSpaceDetailView`, and `DefaultPanelView` now surface draft, recommended, active, paused, and revoked policies with derived health/latest-run context, constrained creation, policy inspection, lifecycle controls, and manual policy runs.
- Project policies can bootstrap from the legacy manual project-workflow profile, and project-policy manual, realtime, and scheduled runs stay behind strong-confirmed project association before workflow execution.
- `PersonalMemoryService` now records local organization decisions, surfaces personal-memory destination predictions, derives memory-backed rule suggestions, and supports summary/reset flows for the learned-memory layer.
- `PersonalMemoryEvent` and `PersonalMemoryPreference` now persist structured organization-memory history separately from generic activity-derived `LearnedPattern` rows.
- `SuggestionSource` now includes `.personalMemory` so persisted file suggestions can distinguish user-specific memory from rules, learned patterns, and ML predictions.
- `FileMetadata` and `FileItem` now carry `originalSuggestedDestination`, preserving the first recommendation shown to the user for later override and undo learning.
- `LearnedPattern` now includes `source: LearnedPatternSource` so analytics can distinguish activity-history patterns from personal-memory-derived suggestions.
- `OrganizationMemorySnapshot`, `BulkMoveOperation`, and `MoveFileCommand.memorySnapshot` now preserve decision context for undo recovery and replay-safe feedback loops.
- `ExternalReviewPromotionCandidate` now lets eligible one-time Finder/Spotlight folder reviews carry a bookmark-backed standard-folder promotion target through `ExternalReviewSession`.
- `ExternalReviewSession.promotionCandidate` now survives review-session synchronization as requested files leave the pending queue.
- `ExternalReviewPromotionSuggestion` and `DashboardViewModel.externalReviewPromotionSuggestion` now drive the in-flow `Keep monitoring <Folder>` affordance shown during eligible external review sessions.
- `DashboardViewModel.promoteExternalReviewFolder()` now persists the promoted standard folder through `BookmarkFolderService.saveBookmark(_:for:)`.
- `BookmarkFolderService.saveBookmark(_:for:)` remains the persistence path for promoted standard folders and preserves any preexisting enabled-state or automation-exclusion preferences for that folder type.
- `WindowPresentationStore` now encapsulates persisted inspector-visibility defaults with `savedInspectorVisibility`, `setInspectorVisible(_:)`, and `resetInspectorVisibility()`.
- `DashboardLaunchPresentation` now carries launch-width-derived inspector defaults so `DashboardViewModel` can choose between two-column and three-column startup without reading AppKit window state directly.
- `DashboardViewModel.setRightPanelVisible(_:)` now persists user-driven inspector visibility changes instead of mutating the published flag only in-memory.
- UI tests can now isolate persisted window-presentation state with `FORMA_WINDOW_PRESENTATION_SUITE` and reset it with `FORMA_RESET_WINDOW_PRESENTATION=1`, in addition to `FORMA_WINDOW_SIZE`.
- `DestinationResolver.materializeForExplicitSave(_:)` now resolves placeholder destinations during explicit rule-save flows, creates folders inside already-permitted roots, and throws actionable errors for unresolvable destinations.
- `DestinationResolver.requestDestinationAccess(forSuggestedPath:)` now powers guided destination permission flows by pre-seeding the nearest existing parent folder, prefilling the first missing folder name for nested suggestions, and materializing any remaining subfolders after access is granted.
- `RuleHealthService` centralizes Smart Rules health classification with `duplicate`, `overlap`, `needsPermission`, `willCreate`, `ready`, and `disabled` states.
- `RuleService.createRule(_:source:save:)` and `createRules(_:source:)` now require `RuleSource` metadata so activity logging can distinguish editor, inline, template, default, and learned-pattern creation flows.
- `OrganizationTemplate.generateRules(baseDocumentsPath:)` now expects canonical root-relative bases such as `Documents`, `Desktop`, or `Downloads` rather than absolute `/Users/...` paths.

- `ContentSearchService` now executes heavy content scanning off-main and returns results directly to callers rather than publishing internal scan state.
- `DashboardViewModel` content-search orchestration now deduplicates unchanged query/file snapshots before scheduling a new search pass.
- `DashboardViewModel` now publishes `scanPhaseStatusText` during long-running scan/apply flows so UI surfaces can show lightweight progress messages.
- `FileSystemService.scan(baseFolders:)` now performs standard folder scans in parallel and aggregates per-folder failures via `ScanResult.errors`.
- `FileScanOptions` now controls recursive scan depth/caps/skip behavior, and scan entrypoints resolve shared options across dashboard, automation, menu bar, and review flows.
- `FileMetadata`/`FileItem` now carry `scanRootPath` and `relativeParentPath` for nested-folder context in flat UI lists.
- `DuplicateDetectionService` now performs streaming SHA-256 hashing and internal hash-cache reuse for repeated scans of unchanged files.
- `FileFilterManager` now invalidates cached filter results when `contentMatchedPaths` changes and supports caching empty result sets safely.
- `InsightsService.generateInsights(...)` is async and accepts optional `precomputedClusters` so callers can reuse dashboard-detected clusters instead of repeating context detection.
- `InsightsService.generateInsights(...)` now checks `Task.isCancelled` between major phases and exits early when a refresh is superseded.

### Website API Updates (February 2026)

- Added public, read-only website endpoints for machine consumption:
  - `GET /api/public/product`
  - `GET /api/public/faq`
  - `GET /api/public/faq/{id}`
- Added website integration discovery endpoints:
  - `GET /llms.txt`
  - `GET /openapi.json`
  - `GET /for-agents`

---

## Website Public API (forma-website)

The following endpoints are exposed by `forma-website` for crawlers, integrations, and agent retrieval workflows.

### Versioning

- Envelope version: `v1`
- Base URL: `https://formafiles.com`

### `GET /api/public/product`

**Returns**

```json
{
  "version": "v1",
  "data": {
    "name": "Forma",
    "tagline": "A file organizer that actually sticks",
    "platform": "macOS 14+",
    "price_usd": 29,
    "purchase_url": "https://apps.apple.com/...",
    "last_updated": "2026-02-11T00:00:00.000Z"
  }
}
```

### `GET /api/public/faq`

**Returns**

```json
{
  "version": "v1",
  "data": {
    "items": [
      {
        "id": "privacy",
        "question": "Is my data private?",
        "answer": "...",
        "category": "privacy",
        "last_updated": "2026-02-11T00:00:00.000Z"
      }
    ]
  }
}
```

### `GET /api/public/faq/{id}`

Returns a single FAQ item with the same item schema as above.  
If the ID does not exist, returns status `404` with:

```json
{
  "version": "v1",
  "data": {
    "error": "FAQ item not found"
  }
}
```

---

## FileSystemService

Responsible for scanning directories and managing Desktop folder access permissions.

### Class Declaration

```swift
class FileSystemService
```

### Properties

None (stateless service with internal bookmark management).

### Methods

#### scanDesktop()

Scans the Desktop folder and returns an array of FileItem objects.

**Signature:**
```swift
func scanDesktop() async throws -> [FileItem]
```

**Returns:** Array of `FileItem` objects representing files on Desktop.

**Throws:** `FileSystemError` if scanning fails or permission denied.

**Behavior:**
1. Retrieves Desktop URL from saved bookmark or requests access
2. Starts security-scoped resource access
3. Scans directory using FileManager
4. Creates FileItem models for each file
5. Stops security-scoped access
6. Returns file array

**Example:**
```swift
let fileSystemService = FileSystemService()

Task {
    do {
        let files = try await fileSystemService.scanDesktop()
        print("Found \(files.count) files")

        for file in files {
            print("\(file.name) - \(file.size)")
        }
    } catch let error as FileSystemService.FileSystemError {
        print("Scan failed: \(error.localizedDescription)")
    }
}
```

**Errors:**
- `.permissionDenied`: User did not grant access or bookmark invalid
- `.userCancelled`: User cancelled folder selection dialog
- `.scanFailed(String)`: File system error occurred

---

#### resetDesktopAccess()

Clears the saved Desktop folder bookmark, forcing re-authentication on next scan.

**Signature:**
```swift
func resetDesktopAccess()
```

**Returns:** Void

**Throws:** Never

**Use Case:** Troubleshooting permission issues or changing Desktop folder.

**Example:**
```swift
fileSystemService.resetDesktopAccess()
// Next scanDesktop() call will prompt for folder selection
```

---

### Internal Methods

#### getDesktopURL()

Private method that retrieves Desktop URL from bookmark or requests access.

```swift
private func getDesktopURL() async throws -> URL
```

#### requestDesktopAccess()

Private method that shows NSOpenPanel for folder selection.

```swift
private func requestDesktopAccess() async throws -> URL
```

#### scanDirectory(at:)

Private method that performs actual directory scan.

```swift
private func scanDirectory(at url: URL) async throws -> [FileItem]
```

#### formatFileSize(_:)

Private method that formats byte count as human-readable string.

```swift
private func formatFileSize(_ bytes: Int64) -> String
```

---

### Error Types

```swift
enum FileSystemError: LocalizedError {
    case permissionDenied
    case directoryNotFound
    case scanFailed(String)
    case userCancelled
}
```

---

## RuleEngine

Evaluates files against organizational rules and suggests destinations.

### Class Declaration

```swift
class RuleEngine
```

### Properties

None (stateless evaluation engine).

### Methods

#### evaluateFile(_:rules:)

Evaluates a single file against a list of rules and returns updated FileItem with suggestion.

**Signature:**
```swift
func evaluateFile(_ fileItem: FileItem, rules: [Rule]) -> FileItem
```

**Parameters:**
- `fileItem`: The file to evaluate
- `rules`: Array of Rule objects to check against

**Returns:** Updated `FileItem` with:
- `suggestedDestination` set if rule matched
- `status` set to `.ready` (matched) or `.pending` (no match)

**Behavior:**
1. Iterates through rules in order
2. Checks if file matches each rule's conditions
3. Returns on first match (subsequent rules ignored)
4. Returns pending status if no rules match

**Example:**
```swift
let ruleEngine = RuleEngine()

let file = FileItem(
    name: "Screenshot 2024-01-18.png",
    fileExtension: "png",
    // ... other properties
)

let rules = [
    Rule(
        name: "Screenshots",
        conditionType: .nameStartsWith,
        conditionValue: "Screenshot",
        actionType: .move,
        destination: .folder(bookmark: Data(), displayName: "Pictures/Screenshots")
    )
]

let evaluated = ruleEngine.evaluateFile(file, rules: rules)

print(evaluated.suggestedDestination)  // "Pictures/Screenshots"
print(evaluated.status)                // .ready
```

---

#### evaluateFiles(_:rules:)

Batch evaluation of multiple files against rules.

**Signature:**
```swift
func evaluateFiles(_ files: [FileItem], rules: [Rule]) -> [FileItem]
```

**Parameters:**
- `files`: Array of FileItem objects to evaluate
- `rules`: Array of Rule objects to check against

**Returns:** Array of FileItem objects with suggestions and statuses updated.

**Complexity:** O(n × m) where n = number of files, m = number of rules

**Example:**
```swift
let files = try await fileSystemService.scanDesktop()
let rules = try context.fetch(FetchDescriptor<Rule>())

let evaluatedFiles = ruleEngine.evaluateFiles(files, rules: rules)

let matched = evaluatedFiles.filter { $0.status == .ready }
let pending = evaluatedFiles.filter { $0.status == .pending }

print("\(matched.count) files have suggestions")
print("\(pending.count) files need manual review")
```

---

### Internal Methods

#### matches(file:rule:)

Private method that checks if a file matches a specific rule's conditions.

```swift
private func matches(file: FileItem, rule: Rule) -> Bool
```

**Behavior:**
- Checks rule.isEnabled flag
- Compares file attributes against rule conditions
- Case-insensitive matching
- Returns true if conditions met

---

## FileOperationsService

Handles file move operations with destination folder permission management.

### Class Declaration

```swift
class FileOperationsService
```

### Properties

None (stateless service with bookmark management).

### Methods

#### moveFile(_:)

Moves a single file to its suggested destination with permission handling.

**Signature:**
```swift
func moveFile(_ fileItem: FileItem) async throws -> MoveResult
```

**Parameters:**
- `fileItem`: FileItem with `suggestedDestination` set

**Returns:** `MoveResult` struct with operation details.

**Throws:** `FileOperationError` if move fails.

**Behavior:**
1. Validates source file exists
2. Parses destination path into top-level folder + subpath
3. Ensures permission for top-level folder (prompts if needed)
4. Validates folder selection
5. Starts security-scoped access
6. Creates destination directories
7. Moves file
8. Stops security-scoped access
9. Returns result

**Example:**
```swift
let fileOps = FileOperationsService()

let file = FileItem(
    name: "invoice.pdf",
    path: "/Users/username/Desktop/invoice.pdf",
    suggestedDestination: "Documents/Finance/Invoices"
)

Task {
    do {
        let result = try await fileOps.moveFile(file)

        if result.success {
            print("Moved to: \(result.destinationPath ?? "")")
        }
    } catch let error as FileOperationsService.FileOperationError {
        print("Move failed: \(error.localizedDescription)")
    }
}
```

**Permission Flow:**
```
First move to "Documents" → User selects ~/Documents → Bookmark saved
Next move to "Documents" → Uses saved bookmark → No prompt
```

---

#### moveFiles(_:)

Batch move operation for multiple files.

**Signature:**
```swift
func moveFiles(_ files: [FileItem]) async -> [MoveResult]
```

**Parameters:**
- `files`: Array of FileItem objects to move

**Returns:** Array of `MoveResult` objects, one per file.

**Throws:** Never (errors captured in MoveResult.error)

**Behavior:**
- Attempts to move each file independently
- Continues on error (doesn't stop batch)
- Collects results for all files
- Useful for "Organize All" operations

**Example:**
```swift
let filesToMove = files.filter { $0.suggestedDestination != nil }
let results = await fileOps.moveFiles(filesToMove)

let successCount = results.filter { $0.success }.count
let failureCount = results.count - successCount

print("Moved: \(successCount), Failed: \(failureCount)")

// Handle failures
for result in results where !result.success {
    if let error = result.error {
        print("Failed: \(result.originalPath) - \(error)")
    }
}
```

---

#### getDestinationPath(for:)

Resolves the full destination path for a file without moving it.

**Signature:**
```swift
func getDestinationPath(for fileItem: FileItem) -> String?
```

**Parameters:**
- `fileItem`: FileItem with `suggestedDestination` set

**Returns:** Full file path as string, or nil if no suggestion.

**Example:**
```swift
if let destPath = fileOps.getDestinationPath(for: file) {
    print("Will move to: \(destPath)")
}
// Output: "Will move to: /Users/username/Documents/Finance/Invoices/invoice.pdf"
```

---

#### resetDestinationAccess()

Clears all saved destination folder bookmarks.

**Signature:**
```swift
func resetDestinationAccess()
```

**Returns:** Void

**Use Case:** Troubleshooting permission issues.

**Example:**
```swift
fileOps.resetDestinationAccess()
// Next move will prompt for all destination folders again
```

---

### Internal Methods

#### ensureDestinationAccess(_:)

Private method that ensures permission for a destination folder.

```swift
private func ensureDestinationAccess(_ folderName: String) async throws -> URL
```

#### requestDestinationAccess(_:)

Private method that prompts user to select destination folder.

```swift
private func requestDestinationAccess(_ folderName: String) async throws -> URL
```

---

### Types

#### MoveResult

Result object returned by move operations.

```swift
struct MoveResult {
    let success: Bool
    let originalPath: String
    let destinationPath: String?
    let error: FileOperationError?
}
```

**Properties:**
- `success`: Whether move completed successfully
- `originalPath`: Source file path
- `destinationPath`: Destination path if successful, nil otherwise
- `error`: Error details if failed, nil otherwise

**Example:**
```swift
let result = try await fileOps.moveFile(file)

if result.success {
    print("✅ \(result.originalPath) → \(result.destinationPath!)")
} else {
    print("❌ \(result.originalPath): \(result.error!.localizedDescription)")
}
```

---

### Error Types

```swift
enum FileOperationError: LocalizedError {
    case sourceNotFound
    case destinationExists
    case permissionDenied
    case diskFull
    case fileInUse
    case userCancelled
    case systemPermissionDenied
    case operationFailed(String)
}
```

---

## ContextDetectionService

Service for detecting contextual clusters of related files using various AI-powered algorithms.

### Class Declaration

```swift
class ContextDetectionService
```

### Overview

ContextDetectionService analyzes file metadata (names, timestamps, paths) to identify groups of files that likely belong together and should be organized as a unit. Uses four detection algorithms: project codes, temporal proximity, name similarity, and date stamps.

### Configuration Constants

```swift
private static let temporalThresholdSeconds: TimeInterval = 300 // 5 minutes
private static let minClusterSize = 3
private static let minConfidenceThreshold = 0.5
private static let minNameSimilarityRatio = 0.6
```

### Methods

#### detectClusters(from:)

Detects all types of clusters from a list of files.

**Signature:**
```swift
func detectClusters(from files: [FileItem]) -> [ProjectCluster]
```

**Parameters:**
- `files`: Array of FileItem to analyze

**Returns:** Array of detected ProjectCluster objects filtered by confidence and size.

**Algorithms Used:**
1. **Project Code Detection** - Matches patterns like P-1024, JIRA-456, CLIENT_ABC
2. **Temporal Clustering** - Files modified within 5 minutes (same work session)
3. **Name Similarity** - Uses Levenshtein distance to find related files
4. **Date Stamp Clustering** - Groups files with matching dates in names

**Example:**
```swift
let contextService = ContextDetectionService()
let files = try await fileSystemService.scanDesktop()

let clusters = contextService.detectClusters(from: files)

for cluster in clusters {
    print("\(cluster.displayDescription)")
    print("Confidence: \(cluster.confidenceScore)")
    print("Suggested folder: \(cluster.suggestedFolderName)")
    print("---")
}
```

**Output:**
```
5 files related to "P-1024"
Confidence: 0.95
Suggested folder: Project P-1024
---
4 files from a recent work session
Confidence: 0.75
Suggested folder: Work Session - Dec 1, 2025 at 2:30 PM
---
```

---

#### detectProjectCodeClusters(from:)

Private method that detects clusters based on project codes in file names.

**Patterns Detected:**
- `P-1024`, `P-001` (Project numbers)
- `JIRA-456`, `ABC-123` (Issue tracking codes)
- `CLIENT_ABC`, `PROJ_XYZ` (Client/project prefixes)
- `2024-11-15` (Date formats at start of filename)

**Confidence Scoring:**
- Base: 0.8 (high for explicit codes)
- +0.1 if 5+ files
- +0.05 if 10+ files
- Max: 0.95

---

#### detectTemporalClusters(from:)

Private method that detects clusters based on temporal proximity (same work session).

**Behavior:**
- Files modified within 5 minutes are grouped together
- Sorts files by modification date
- Creates clusters with minimum 3 files

**Confidence Scoring:**
- Within 1 minute: 0.85
- Within 3 minutes: 0.75
- Within 5 minutes: 0.65

---

#### detectNameSimilarityClusters(from:)

Private method that uses Levenshtein distance to find files with similar names.

**Behavior:**
- Calculates similarity ratio (0.0-1.0) between file names
- Groups files with similarity ≥ 0.6
- Finds longest common prefix for suggested folder name

**Example Matches:**
- `report_draft.docx`, `report_final.docx`, `report_revised.docx`
- `design_v1.sketch`, `design_v2.sketch`, `design_v3.sketch`

---

#### detectDateStampClusters(from:)

Private method that groups files with matching date patterns in names.

**Date Patterns:**
- `2024-11-15` (ISO format)
- `20241115` (Compact format)
- `11-15-2024` (US format)

**Example:**
```swift
// Files with dates in names:
// Screenshot 2024-11-15 at 9.23 AM.png
// Report 2024-11-15.pdf
// Notes 2024-11-15.txt
// → Clustered as "Files from 2024-11-15"
```

---

### Helper Methods

#### levenshteinDistance(_:_:)

Calculates edit distance between two strings using dynamic programming.

```swift
private func levenshteinDistance(_ str1: String, _ str2: String) -> Int
```

#### calculateNameSimilarity(_:_:)

Returns similarity ratio (0.0-1.0) based on Levenshtein distance.

```swift
private func calculateNameSimilarity(_ str1: String, _ str2: String) -> Double
```

**Formula:**
```
similarity = 1.0 - (distance / maxLength)
```

#### findCommonPrefix(_:)

Finds the longest common prefix among a list of strings.

```swift
private func findCommonPrefix(_ strings: [String]) -> String
```

**Example:**
```swift
findCommonPrefix(["report_draft", "report_final", "report_v2"])
// Returns: "report_"
```

---

## LearningService

Service for learning from user behavior and suggesting automation rules.

### Class Declaration

```swift
class LearningService
```

### Overview

LearningService analyzes ActivityItem history to detect repeated file organization patterns and converts them into LearnedPattern objects that can be suggested to users or automatically converted into permanent rules.

### Methods

#### detectPatterns(from:)

Detects patterns from user's file organization activities.

**Signature:**
```swift
func detectPatterns(from activities: [ActivityItem]) -> [LearnedPattern]
```

**Parameters:**
- `activities`: Array of ActivityItem representing user actions

**Returns:** Array of LearnedPattern objects sorted by confidence score (highest first).

**Minimum Requirements:**
- At least 3 occurrences of same pattern
- Only analyzes `.fileOrganized` and `.fileMoved` activities

**Example:**
```swift
let learningService = LearningService()
let activities = try context.fetch(FetchDescriptor<ActivityItem>())

let patterns = learningService.detectPatterns(from: activities)

for pattern in patterns {
    print(pattern.patternDescription)
    print("Confidence: \(pattern.confidenceLevel)")
    print("Occurrences: \(pattern.occurrenceCount)")
}
```

**Output:**
```
You moved 5 PDF files to Documents/Finance
Confidence: High
Occurrences: 5
---
You moved 8 PNG files to Pictures/Screenshots
Confidence: High
Occurrences: 8
```

---

#### convertPatternToRule(_:)

Converts a learned pattern into a permanent Rule.

**Signature:**
```swift
func convertPatternToRule(_ pattern: LearnedPattern) -> Rule
```

**Parameters:**
- `pattern`: The LearnedPattern to convert

**Returns:** A new Rule object with conditions matching the pattern.

**Example:**
```swift
let pattern = patterns.first!  // "PDF → Documents/Finance"
let rule = learningService.convertPatternToRule(pattern)

context.insert(rule)
try context.save()

print("Created rule: \(rule.name)")
// Output: "Created rule: PDF → Finance"
```

---

#### shouldSuggestPattern(_:)

Determines if a pattern should be suggested to the user.

**Signature:**
```swift
func shouldSuggestPattern(_ pattern: LearnedPattern) -> Bool
```

**Returns:** Boolean indicating if pattern meets suggestion criteria.

**Criteria:**
- Confidence score ≥ 0.5
- Not already converted to rule
- Rejection count < 3

---

#### updatePatterns(existing:with:)

Updates existing patterns with new activities or creates new ones.

**Signature:**
```swift
func updatePatterns(
    existing existingPatterns: [LearnedPattern],
    with newActivities: [ActivityItem]
) -> [LearnedPattern]
```

**Returns:** Updated array of LearnedPattern objects with merged data.

**Behavior:**
- Detects new patterns from activities
- Merges with existing patterns (updates occurrence counts)
- Adds genuinely new patterns
- Preserves existing patterns not found in new data

---

### Private Methods

#### extractDestination(from:)

Extracts destination path from activity details string.

```swift
private func extractDestination(from details: String) -> String
```

**Patterns Recognized:**
- "Moved to Documents/Finance" → "Documents/Finance"
- "Organized to ~/Pictures/Screenshots" → "~/Pictures/Screenshots"

---

## PersonalMemoryService

Service for building user-specific organization memory from accepted, corrected, deferred, and undone file decisions.

### Class Declaration

```swift
@MainActor
final class PersonalMemoryService
```

### Overview

PersonalMemoryService persists structured decision history in `PersonalMemoryEvent` rows and rolls those events up into `PersonalMemoryPreference` records. The resulting preferences power three flows:

- personal-memory destination suggestions during scanning
- reusable rule suggestions derived from stable preferences
- summary and reset controls in Smart Features

The service is designed to compound from user behavior rather than generic classification alone. Feature entry points gate this layer behind `FeatureFlagService.shared.isEnabled(.patternLearning)`.

### Primary Methods

#### recordDecision(...)

Records a single organization decision and updates the matching personal-memory preference.

**Signature:**
```swift
func recordDecision(
    fileName: String,
    fileExtension: String,
    fileTypeCategory: FileTypeCategory,
    sourceLocation: FileLocationKind,
    scanRootPath: String?,
    relativeParentPath: String?,
    sourceSurface: PersonalMemorySourceSurface,
    suggestionSource: SuggestionSource? = nil,
    suggestedDestination: Destination?,
    chosenDestination: Destination?,
    confidenceScore: Double?,
    matchedRuleID: UUID?,
    eventKind: PersonalMemoryEventKind? = nil,
    priorDestination: Destination? = nil,
    relatedDecisionID: UUID? = nil,
    timestamp: Date = Date()
) throws -> PersonalMemoryEvent
```

**Behavior:**
- infers accepted, override, manual-selection, or deferred events when `eventKind` is omitted
- increments the chosen destination preference
- penalizes a suggested destination when the user overrides it
- penalizes the reverted destination on undo recovery without double-penalizing the original suggestion
- persists enough context for later analytics and replay-safe learning

#### suggestion(for:)

Returns the best user-specific destination suggestion for a scanned file.

**Signature:**
```swift
func suggestion(for file: FileMetadata) throws -> PredictedDestination?
```

**Returns:** `PredictedDestination` with `source == .personalMemory` when a stable preference exists; otherwise `nil`.

#### suggestedPatterns(minimumEvidence:)

Builds reusable rule suggestions from stable personal-memory preferences.

**Signature:**
```swift
func suggestedPatterns(minimumEvidence: Int = 3) throws -> [LearnedPattern]
```

**Behavior:**
- only returns stable, unsuppressed preferences
- only returns rule-convertible preferences whose context can be preserved as a rule condition
- preserves source-location context in derived patterns
- tags resulting patterns with `source == .personalMemory`
- keeps destination bookmark data when available

#### upsertSuggestedPatterns(minimumEvidence:)

Synchronizes the derived personal-memory pattern suggestions with persisted `LearnedPattern` rows.

**Signature:**
```swift
@discardableResult
func upsertSuggestedPatterns(minimumEvidence: Int = 3) throws -> Int
```

**Returns:** Count of active personal-memory-backed rule suggestions after the sync.

#### summary()

Returns the current memory summary shown in Smart Features.

**Signature:**
```swift
func summary() throws -> PersonalMemorySummary
```

#### resetAll()

Deletes all personal-memory events, preferences, and derived personal-memory pattern suggestions.

**Signature:**
```swift
func resetAll() throws
```

### Related Types

```swift
enum PersonalMemoryEventKind: String, Codable, Sendable {
    case acceptedSuggestion
    case acceptedWithOverride
    case manualSelection
    case suggestionDeferred
    case undoRecovery
    case manualCorrection
    case ruleSuggestionAccepted
    case ruleSuggestionDismissed
}

enum PersonalMemorySourceSurface: String, Codable, Sendable {
    case reviewFlow
    case inspector
    case bulkOrganize
    case ruleSuggestion
    case undoSurface
}

struct PersonalMemorySummary: Equatable, Sendable {
    let learnedDestinationCount: Int
    let reusablePatternCount: Int
    let lastUpdatedAt: Date?
}
```

---

## InsightsService

Service for generating contextual insights and suggestions about file organization.

### Class Declaration

```swift
class InsightsService
```

### Properties

```swift
static let shared: InsightsService
private let learningService: LearningService
private let contextDetectionService: ContextDetectionService
```

**Note:** Singleton pattern - use `InsightsService.shared`.

### Overview

InsightsService generates actionable insights from current file state, user activities, and rules. Provides pattern detection, storage alerts, rule suggestions, project cluster detection, and activity summaries.

### Methods

#### generateInsights(from:activities:rules:precomputedClusters:now:)

Generates insights from current state.

**Signature:**
```swift
func generateInsights(
    from files: [FileItem],
    activities: [ActivityItem],
    rules: [Rule],
    precomputedClusters: [ProjectCluster]? = nil,
    now: Date? = nil
) async -> [FileInsight]
```

**Parameters:**
- `files`: Current files being organized
- `activities`: User activity history
- `rules`: Active organizational rules
- `precomputedClusters`: Optional clusters from `AnalyticsDashboardViewModel` to avoid duplicate context-detection work
- `now`: Optional date override for deterministic testing/time-sensitive summaries

**Returns:** Array of `FileInsight` objects sorted by priority (highest first). IDs are stable across equivalent inputs so UI dismiss state remains consistent. If the task is cancelled mid-flight, the method returns an empty array and does not publish partial completion metadata.

**Insight Categories:**
1. **File Patterns** - Screenshot accumulation, downloads buildup, grouped file types
2. **Storage Issues** - Large files, potential duplicates
3. **Rule Opportunities** - Patterns detected from manual operations
4. **Project Clusters** - Related files that should be organized together
5. **Activity Summaries** - Weekly/daily organization statistics

**Example:**
```swift
let insightsService = InsightsService.shared
let insights = await insightsService.generateInsights(
    from: files,
    activities: activities,
    rules: rules,
    precomputedClusters: dashboardViewModel.detectedClusters
)

for insight in insights {
    print("\(insight.iconName) \(insight.message)")
    if let action = insight.actionLabel {
        print("   → \(action)")
    }
}
```

**Output:**
```
externaldrive.fill 3 large files taking up 450 MB
   → Review Files

wand.and.stars You moved 5 PDF files to Documents/Finance
   → Create Rule

camera.viewfinder You have 12 screenshots waiting - set up auto-organization?
   → Create Rule
```

---

#### detectLearnedPatterns(from:)

Detects learned patterns using the learning service.

**Signature:**
```swift
func detectLearnedPatterns(from activities: [ActivityItem]) -> [LearnedPattern]
```

**Returns:** Array of LearnedPattern objects that should be suggested.

**Filtering:**
Only returns patterns where `shouldSuggestPattern(_:)` is true.

---

#### detectContextClusters(from:)

Detects project clusters using the context detection service.

**Signature:**
```swift
func detectContextClusters(from files: [FileItem]) -> [ProjectCluster]
```

**Returns:** Array of ProjectCluster objects that should be shown.

**Filtering:**
Only returns clusters where `shouldShow` is true.

---

#### generateGreeting(fileCount:)

Generates a contextual greeting based on time of day.

**Signature:**
```swift
func generateGreeting(fileCount: Int) -> String?
```

**Returns:** Time-appropriate greeting with file count, or nil if late at night.

**Time Ranges:**
- 5 AM - 12 PM: "Good morning"
- 12 PM - 5 PM: "Good afternoon"
- 5 PM - 10 PM: "Good evening"
- 10 PM - 5 AM: nil (no greeting)

**Example:**
```swift
let greeting = insightsService.generateGreeting(fileCount: 15)
// "Good afternoon! 15 files need your attention"
```

---

### Private Methods

#### detectFilePatterns(_:)

Detects common file patterns that could benefit from organization.

**Patterns:**
- Screenshot accumulation (5+ screenshots)
- Downloads buildup (15+ unreviewed downloads)
- Unorganized files of same type (5+ files with same extension)

---

#### detectStorageIssues(_:)

Detects storage-related issues like large files.

**Checks:**
- Large files detection (>100MB, 3+ files)
- Duplicate name detection (3+ sets of files with identical names)

---

#### detectRuleOpportunities(from:files:)

Analyzes recent manual file moves to suggest automation rules.

**Priority Levels:**
- High confidence (≥0.7): Priority 10
- Medium confidence (≥0.5): Priority 8
- Low confidence (<0.5): Priority 6

---

#### detectProjectClusters(_:)

Detects project clusters using context detection algorithms.

**Priority Levels:**
- High confidence (≥0.8): Priority 9
- Medium confidence (≥0.6): Priority 7
- Low confidence (<0.6): Priority 5

---

#### generateActivitySummary(from:)

Generates a summary of recent activity.

**Returns:** FileInsight with weekly organization count, or nil if no activity.

**Example:**
```
"Organized 47 files this week, keep it up!"
```

---

### FileInsight Type

Represents a contextual insight.

```swift
struct FileInsight: Identifiable, Equatable {
    let id: UUID
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?
    let priority: Int
    let iconName: String
}
```

**Priority Range:** 0-10 (higher = more important)

---

## CustomFolderManager

Service responsible for managing custom folder locations and their security-scoped bookmarks. Enables multi-folder monitoring beyond default Desktop/Downloads.

### Class Declaration

```swift
@MainActor
class CustomFolderManager: ObservableObject
```

**Design Pattern:** ObservableObject for SwiftUI integration
**Thread Safety:** @MainActor ensures all UI updates happen on main thread
**Singleton:** Not a singleton - instantiate per use case

### Methods

#### selectFolder()

Requests user to select a single folder using NSOpenPanel and creates a security-scoped bookmark.

**Signature:**
```swift
func selectFolder() async throws -> (url: URL, bookmarkData: Data)
```

**Parameters:** None

**Returns:**
- Tuple containing:
  - `url`: The selected folder URL
  - `bookmarkData`: Security-scoped bookmark for persistent access

**Throws:**
- `CustomFolderError.userCancelled`: User dismissed the panel
- `CustomFolderError.bookmarkCreationFailed`: Couldn't create security bookmark

**Example:**
```swift
let manager = CustomFolderManager()

Task {
    do {
        let (url, bookmark) = try await manager.selectFolder()
        print("Selected: \(url.path)")
        // Save bookmark for future access
    } catch CustomFolderError.userCancelled {
        print("User cancelled selection")
    }
}
```

---

#### selectFolders(allowMultiple:)

Requests user to select one or more folders using NSOpenPanel with multi-select support.

**Signature:**
```swift
func selectFolders(allowMultiple: Bool = true) async throws -> [(url: URL, bookmarkData: Data)]
```

**Parameters:**
- `allowMultiple`: When true, allows ⌘-click to select multiple folders (default: true)

**Returns:**
- Array of tuples, each containing:
  - `url`: A selected folder URL
  - `bookmarkData`: Security-scoped bookmark for that folder

**Throws:**
- `CustomFolderError.userCancelled`: User dismissed the panel without selecting
- `CustomFolderError.bookmarkCreationFailed`: Couldn't create bookmarks for any folder

**Behavior:**
- If some bookmarks fail but others succeed, returns the successful ones
- Prints debug warnings for failed bookmarks in DEBUG builds
- Panel prompts vary based on `allowMultiple` setting

**Example:**
```swift
let manager = CustomFolderManager()

Task {
    do {
        let folders = try await manager.selectFolders(allowMultiple: true)
        print("Selected \(folders.count) folders:")
        for (url, _) in folders {
            print("  - \(url.lastPathComponent)")
        }
    } catch {
        print("Selection failed: \(error)")
    }
}
```

**Output:**
```
Selected 3 folders:
  - Projects
  - Documents
  - Archives
```

---

#### createCustomFolder(name:)

Creates a CustomFolder from user selection via file picker.

**Signature:**
```swift
func createCustomFolder(name: String? = nil) async throws -> CustomFolder
```

**Parameters:**
- `name`: Optional custom display name (default: uses folder's actual name)

**Returns:** `CustomFolder` model instance ready for SwiftData persistence

**Throws:**
- `CustomFolderError.userCancelled`
- `CustomFolderError.bookmarkCreationFailed`
- `CustomFolder.ValidationError` if name/path validation fails

**Example:**
```swift
let manager = CustomFolderManager()

Task {
    do {
        let folder = try await manager.createCustomFolder(name: "Work Projects")
        modelContext.insert(folder)
        try modelContext.save()
    } catch {
        print("Failed to create custom folder: \(error)")
    }
}
```

---

#### createCustomFolders()

Creates multiple CustomFolders from user multi-selection.

**Signature:**
```swift
func createCustomFolders() async throws -> [CustomFolder]
```

**Parameters:** None

**Returns:** Array of `CustomFolder` instances ready for persistence

**Throws:**
- `CustomFolderError.userCancelled`
- `CustomFolderError.bookmarkCreationFailed`
- `CustomFolder.ValidationError`

**Example:**
```swift
let manager = CustomFolderManager()

Task {
    do {
        let folders = try await manager.createCustomFolders()
        for folder in folders {
            modelContext.insert(folder)
        }
        try modelContext.save()
        print("Added \(folders.count) custom folders")
    } catch {
        print("Failed: \(error)")
    }
}
```

---

#### resolveBookmark(from:)

Resolves a URL from a security-scoped bookmark with validation.

**Signature:**
```swift
func resolveBookmark(from bookmarkData: Data) throws -> URL
```

**Parameters:**
- `bookmarkData`: Security-scoped bookmark data previously created

**Returns:** Resolved URL pointing to the folder

**Throws:**
- `CustomFolderError.bookmarkResolutionFailed`: Bookmark is stale or invalid
- `CustomFolderError.invalidFolder`: Resolved path is outside user's home directory (security check)

**Security:**
- Validates resolved path is within `FileManager.default.homeDirectoryForCurrentUser`
- Prevents accessing system directories or other users' files
- Checks if bookmark is stale and throws if so

**Example:**
```swift
let manager = CustomFolderManager()

do {
    let url = try manager.resolveBookmark(from: savedBookmarkData)
    // Must call startAccessingSecurityScopedResource() before use
    if url.startAccessingSecurityScopedResource() {
        defer { url.stopAccessingSecurityScopedResource() }
        // Access folder contents here
    }
} catch CustomFolderError.invalidFolder {
    print("Security: Bookmark points outside home directory")
}
```

---

#### validateFolder(at:)

Validates that a folder path exists and is accessible.

**Signature:**
```swift
func validateFolder(at path: String) -> Bool
```

**Parameters:**
- `path`: File system path to validate

**Returns:**
- `true`: Path exists, is a directory, and is readable
- `false`: Path doesn't exist, isn't a directory, or isn't readable

**Use Cases:**
- Pre-flight check before scanning
- Validating CustomFolder entries at app launch
- UI feedback for folder accessibility

**Example:**
```swift
let manager = CustomFolderManager()

if manager.validateFolder(at: "/Users/user/Documents") {
    print("✓ Folder is valid and accessible")
} else {
    print("✗ Folder is invalid or inaccessible")
}
```

---

#### getURL(for:)

Gets the resolved URL for a CustomFolder, handling bookmark resolution.

**Signature:**
```swift
func getURL(for customFolder: CustomFolder) throws -> URL
```

**Parameters:**
- `customFolder`: CustomFolder model instance

**Returns:** Resolved URL for the folder

**Throws:**
- `CustomFolderError.bookmarkResolutionFailed`: No bookmark data or resolution failed

**Example:**
```swift
let manager = CustomFolderManager()
let folder: CustomFolder = // ... from SwiftData

do {
    let url = try manager.getURL(for: folder)
    print("Folder URL: \(url.path)")
} catch {
    print("Can't access folder: \(error)")
}
```

---

### Error Types

#### CustomFolderError

```swift
enum CustomFolderError: LocalizedError {
    case userCancelled
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case invalidFolder
}
```

**Error Descriptions:**
- `userCancelled`: "Folder selection was cancelled."
- `bookmarkCreationFailed`: "Failed to create security bookmark for the folder."
- `bookmarkResolutionFailed`: "Failed to access the saved folder location."
- `invalidFolder`: "The selected folder is invalid or inaccessible."

---

### NSOpenPanel Configuration

When displaying the folder picker, CustomFolderManager configures NSOpenPanel with:

```swift
openPanel.message = "Select folders to monitor (⌘-click to select multiple)"
openPanel.prompt = "Add Folders"
openPanel.canChooseFiles = false           // Only directories
openPanel.canChooseDirectories = true
openPanel.allowsMultipleSelection = true   // If allowMultiple
openPanel.canCreateDirectories = false     // No new folder creation
```

---

## SecureBookmarkStore

Secure storage layer for security-scoped bookmarks using macOS Keychain. Provides encrypted persistence for folder access permissions.

### Class Declaration

```swift
struct SecureBookmarkStore
```

**Design Pattern:** Static utility struct (all methods are static)
**Storage Backend:** macOS Keychain (not UserDefaults)
**Security:** Encrypted storage via Security framework
**Thread Safety:** Thread-safe keychain operations

### Methods

#### saveBookmark(_:forKey:)

Saves security-scoped bookmark data to the keychain.

**Signature:**
```swift
static func saveBookmark(_ data: Data, forKey key: String) throws
```

**Parameters:**
- `data`: Security-scoped bookmark data from `URL.bookmarkData()`
- `key`: Unique identifier for this bookmark (e.g., folder UUID)

**Returns:** Void

**Throws:**
- `KeychainError.duplicateItem`: Item with this key already exists (use `updateBookmark` instead)
- `KeychainError.saveFailed(OSStatus)`: Keychain operation failed

**Keychain Attributes:**
- Service: `"com.forma.bookmarks"`
- Account: `key` parameter
- Access: First unlock (kSecAttrAccessibleAfterFirstUnlock)
- Class: Generic password (kSecClassGenericPassword)

**Example:**
```swift
let bookmarkData: Data = // ... from URL.bookmarkData()
let folderID = "custom-folder-123"

do {
    try SecureBookmarkStore.saveBookmark(bookmarkData, forKey: folderID)
    print("✓ Bookmark saved securely")
} catch KeychainError.duplicateItem {
    // Update existing bookmark instead
    try SecureBookmarkStore.updateBookmark(bookmarkData, forKey: folderID)
} catch {
    print("Failed to save: \(error)")
}
```

---

#### loadBookmark(forKey:)

Loads security-scoped bookmark data from the keychain.

**Signature:**
```swift
static func loadBookmark(forKey key: String) -> Data?
```

**Parameters:**
- `key`: Unique identifier used when saving the bookmark

**Returns:**
- `Data`: The bookmark data if found
- `nil`: No bookmark exists for this key

**Thread Safety:** Safe to call from any thread

**Example:**
```swift
let folderID = "custom-folder-123"

if let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: folderID) {
    // Resolve the bookmark to get URL
    var isStale = false
    if let url = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    ) {
        print("Loaded folder: \(url.path)")
    }
} else {
    print("No bookmark found for key: \(folderID)")
}
```

---

#### updateBookmark(_:forKey:)

Updates existing security-scoped bookmark data in the keychain.

**Signature:**
```swift
static func updateBookmark(_ data: Data, forKey key: String) throws
```

**Parameters:**
- `data`: New bookmark data to replace existing entry
- `key`: Identifier of the bookmark to update

**Returns:** Void

**Throws:**
- `KeychainError.itemNotFound`: No bookmark exists with this key (use `saveBookmark` instead)
- `KeychainError.updateFailed(OSStatus)`: Keychain update operation failed

**Use Cases:**
- Refreshing stale bookmarks
- Re-requesting permissions for moved folders
- Updating after bookmark resolution indicates staleness

**Example:**
```swift
let folderID = "custom-folder-123"
let newBookmarkData: Data = // ... from user re-selection

do {
    try SecureBookmarkStore.updateBookmark(newBookmarkData, forKey: folderID)
    print("✓ Bookmark updated")
} catch KeychainError.itemNotFound {
    // Create new bookmark instead
    try SecureBookmarkStore.saveBookmark(newBookmarkData, forKey: folderID)
}
```

---

#### deleteBookmark(forKey:)

Removes a security-scoped bookmark from the keychain.

**Signature:**
```swift
static func deleteBookmark(forKey key: String) throws
```

**Parameters:**
- `key`: Identifier of the bookmark to delete

**Returns:** Void

**Throws:**
- `KeychainError.itemNotFound`: No bookmark exists with this key
- `KeychainError.deleteFailed(OSStatus)`: Keychain deletion failed

**Side Effects:**
- Removes keychain entry permanently
- Does NOT revoke file system permissions (those persist until reboot or explicit revocation)

**Example:**
```swift
let folderID = "custom-folder-123"

do {
    try SecureBookmarkStore.deleteBookmark(forKey: folderID)
    print("✓ Bookmark deleted")
} catch KeychainError.itemNotFound {
    print("Bookmark already removed")
} catch {
    print("Failed to delete: \(error)")
}
```

---

#### listAllBookmarks()

Retrieves all security-scoped bookmarks stored by Forma.

**Signature:**
```swift
static func listAllBookmarks() -> [(key: String, data: Data)]
```

**Parameters:** None

**Returns:**
- Array of tuples containing:
  - `key`: The bookmark identifier
  - `data`: The bookmark data

**Use Cases:**
- App startup: Loading all monitored folders
- Settings UI: Displaying saved folder list
- Migration: Moving to new storage system
- Debugging: Auditing stored permissions

**Example:**
```swift
let allBookmarks = SecureBookmarkStore.listAllBookmarks()
print("Found \(allBookmarks.count) saved folders:")

for (key, data) in allBookmarks {
    if let url = try? URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: nil
    ) {
        print("  [\(key)] → \(url.path)")
    } else {
        print("  [\(key)] → ⚠️ Stale or invalid")
    }
}
```

**Output:**
```
Found 3 saved folders:
  [desktop] → /Users/user/Desktop
  [downloads] → /Users/user/Downloads
  [custom-folder-123] → /Users/user/Projects
```

---

#### migrateFromUserDefaults(keys:)

Migrates security-scoped bookmarks from UserDefaults to secure Keychain storage.

**Signature:**
```swift
static func migrateFromUserDefaults(keys: [String]) throws
```

**Parameters:**
- `keys`: Array of UserDefaults keys containing bookmark data to migrate

**Returns:** Void

**Throws:**
- `KeychainError.migrationFailed`: One or more migrations failed
- Individual keychain errors for each bookmark

**Behavior:**
- For each key:
  1. Loads bookmark from UserDefaults
  2. Saves to Keychain
  3. Removes from UserDefaults (cleanup)
- Logs migration progress in DEBUG builds
- Continues migrating other keys if one fails

**Example:**
```swift
let legacyKeys = ["desktopBookmark", "downloadsBookmark", "customFolderBookmark"]

do {
    try SecureBookmarkStore.migrateFromUserDefaults(keys: legacyKeys)
    print("✓ Migration complete")
} catch {
    print("⚠️ Migration had errors: \(error)")
    // Some bookmarks may have migrated successfully
}
```

**Migration Safety:**
- Idempotent: Safe to run multiple times
- Non-destructive: Only removes from UserDefaults after successful keychain save
- Gracefully handles missing keys

---

### Error Types

#### KeychainError

```swift
enum KeychainError: LocalizedError {
    case duplicateItem
    case itemNotFound
    case saveFailed(OSStatus)
    case updateFailed(OSStatus)
    case deleteFailed(OSStatus)
    case migrationFailed
    case unexpectedData
}
```

**Error Descriptions:**
- `duplicateItem`: "A bookmark with this key already exists in the keychain."
- `itemNotFound`: "No bookmark found for the specified key."
- `saveFailed(status)`: "Failed to save bookmark to keychain. Status: \(status)"
- `updateFailed(status)`: "Failed to update bookmark in keychain. Status: \(status)"
- `deleteFailed(status)`: "Failed to delete bookmark from keychain. Status: \(status)"
- `migrationFailed`: "Failed to migrate bookmarks from UserDefaults to Keychain."
- `unexpectedData`: "Unexpected data format when reading from keychain."

**Common OSStatus Codes:**
- `errSecDuplicateItem (-25299)`: Item already exists
- `errSecItemNotFound (-25300)`: Item not found
- `errSecAuthFailed (-25293)`: Authorization/authentication failed
- `errSecInteractionNotAllowed (-25308)`: User interaction required but not allowed

---

### Keychain Service Name

All bookmarks are stored under the service name:

```swift
private static let keychainService = "com.forma.bookmarks"
```

This isolates Forma's bookmarks from other keychain entries and enables bulk operations.

---

### Security Considerations

**Why Keychain Instead of UserDefaults?**
- UserDefaults stores data as plaintext plist files
- Any app can read `~/Library/Preferences/com.forma.plist`
- Security-scoped bookmarks contain cryptographic material
- Keychain provides encrypted storage with access controls

**Access Control:**
- `kSecAttrAccessibleAfterFirstUnlock`: Available after device unlock
- Survives app deletion (user must manually delete keychain items)
- Isolated per user account (no cross-user access)

**Best Practices:**
1. Always check for duplicates before saving
2. Handle stale bookmarks by re-requesting permissions
3. Clean up keychain entries when folders are removed from UI
4. Use unique, stable keys (UUIDs preferred over paths)

---

## NotificationService

System notification management using macOS UserNotifications framework. Provides user feedback for file organization operations.

### Class Declaration

```swift
class NotificationService
```

**Design Pattern:** Singleton (`NotificationService.shared`)
**Framework:** UserNotifications (macOS 10.14+)
**User Control:** Respects `UserDefaults.standard.bool(forKey: "showNotifications")`

### Singleton Access

```swift
static let shared = NotificationService()
```

Always use the shared instance to ensure consistent notification state.

### Methods

#### requestAuthorization()

Requests permission to display notifications. Must be called before any notifications can be shown.

**Signature:**
```swift
func requestAuthorization()
```

**Parameters:** None

**Returns:** Void (async operation)

**Behavior:**
- Requests alert, sound, and badge permissions
- Safe to call multiple times (won't re-prompt if already authorized)
- Logs authorization status in DEBUG builds

**Example:**
```swift
// Call at app launch
NotificationService.shared.requestAuthorization()
```

---

#### notifyFileOrganized(fileName:destination:)

Shows notification when a single file is successfully organized.

**Signature:**
```swift
func notifyFileOrganized(fileName: String, destination: String)
```

**Parameters:**
- `fileName`: Name of the organized file (e.g., "Report.pdf")
- `destination`: Destination folder name or path (e.g., "Documents/Work")

**Notification Content:**
- **Title:** "File Organized"
- **Body:** "\(fileName) moved to \(destination)"
- **Sound:** Default system sound

**Respects User Preferences:**
- Only shows if `UserDefaults.standard.bool(forKey: "showNotifications")` is true
- Silently returns if notifications are disabled

**Example:**
```swift
NotificationService.shared.notifyFileOrganized(
    fileName: "Project Brief.pdf",
    destination: "Documents/Work/2024"
)
```

**Displayed Notification:**
```
File Organized
Project Brief.pdf moved to Documents/Work/2024
```

---

#### notifyBatchOrganized(successCount:totalCount:)

Shows notification when a batch of files is organized, with success rate.

**Signature:**
```swift
func notifyBatchOrganized(successCount: Int, totalCount: Int)
```

**Parameters:**
- `successCount`: Number of successfully organized files
- `totalCount`: Total number of files attempted

**Notification Content:**
- **Title:** "Batch Organization Complete"
- **Body:** "Successfully organized \(successCount) of \(totalCount) files"
- **Sound:** Default system sound

**Example:**
```swift
NotificationService.shared.notifyBatchOrganized(
    successCount: 47,
    totalCount: 50
)
```

**Displayed Notification:**
```
Batch Organization Complete
Successfully organized 47 of 50 files
```

---

#### notifyError(message:)

Shows notification for errors that occur during file organization.

**Signature:**
```swift
func notifyError(message: String)
```

**Parameters:**
- `message`: Error description to display to user

**Notification Content:**
- **Title:** "Organization Error"
- **Body:** `message` parameter
- **Sound:** Default system sound

**Example:**
```swift
NotificationService.shared.notifyError(
    message: "Permission denied for Desktop folder"
)
```

**Displayed Notification:**
```
Organization Error
Permission denied for Desktop folder
```

---

### UserDefaults Integration

NotificationService checks the following preference:

```swift
UserDefaults.standard.bool(forKey: "showNotifications")
```

**Default Value:** `false` (notifications disabled until user enables)

**Enabling Notifications:**
```swift
UserDefaults.standard.set(true, forKey: "showNotifications")
```

**Disabling Notifications:**
```swift
UserDefaults.standard.set(false, forKey: "showNotifications")
```

This preference is typically controlled from SettingsView in the app.

---

### Authorization States

NotificationService handles these authorization states:

1. **Not Determined:** First time - will prompt user
2. **Authorized:** User granted permission - notifications will show
3. **Denied:** User denied permission - notifications silently fail
4. **Provisional:** Temporary permission - notifications show quietly

You don't need to check authorization state manually; the service handles this internally.

---

## RuleService

Service layer for Rule model CRUD operations and template-based rule generation.

### Class Declaration

```swift
@MainActor
class RuleService
```

**Thread Safety:** @MainActor ensures all operations occur on main thread
**Data Access:** Works with SwiftData ModelContext
**Responsibility:** Business logic for Rule management

### Initialization

```swift
private let context: ModelContext

init(context: ModelContext)
```

Each RuleService instance is tied to a specific SwiftData context.

### Methods

#### fetchRules()

Fetches all rules from the database, sorted by priority and name.

**Signature:**
```swift
func fetchRules() throws -> [Rule]
```

**Parameters:** None

**Returns:** Array of all Rule objects, sorted by:
1. Priority (descending: highest priority first)
2. Name (ascending: alphabetical)

**Throws:** SwiftData fetch errors

**Example:**
```swift
let service = RuleService(modelContext: modelContext)

do {
    let rules = try service.fetchRules()
    print("Loaded \(rules.count) rules:")
    for rule in rules {
        print("  [\(rule.priority)] \(rule.name)")
    }
} catch {
    print("Failed to fetch rules: \(error)")
}
```

---

#### createRule(_:source:save:)

Creates and saves a new rule to the database.

**Signature:**
```swift
func createRule(_ rule: Rule, source: RuleSource, save: Bool = true) throws
```

**Parameters:**
- `rule`: Rule instance to persist
- `source`: Creation context used for activity logging and analytics
- `save`: Whether to save the context immediately (default: `true`)

**Returns:** Void

**Throws:** SwiftData save errors

**Side Effects:**
- Inserts rule into ModelContext
- Logs the creation source to the activity timeline
- Saves context immediately when `save` is `true`

**Example:**
```swift
let service = RuleService(modelContext: modelContext)

let newRule = Rule(
    name: "PDFs to Documents",
    conditionType: .fileExtension,
    conditionValue: "pdf",
    actionType: .move,
    destination: .folder(bookmark: Data(), displayName: "Documents/PDFs")
)

try service.createRule(newRule, source: .ruleEditor)
```

---

#### updateRule(_:)

Updates an existing rule in the database.

**Signature:**
```swift
func updateRule(_ rule: Rule) throws
```

**Parameters:**
- `rule`: Modified Rule instance to save

**Returns:** Void

**Throws:** SwiftData save errors

**Note:** Rule must already exist in the ModelContext

**Example:**
```swift
let service = RuleService(modelContext: modelContext)
var rule: Rule = // ... fetched from database

rule.isEnabled = false
rule.priority = 1
try service.updateRule(rule)
```

---

#### deleteRule(_:)

Deletes a rule from the database.

**Signature:**
```swift
func deleteRule(_ rule: Rule) throws
```

**Parameters:**
- `rule`: Rule instance to delete

**Returns:** Void

**Throws:** SwiftData deletion errors

**Side Effects:**
- Removes rule from ModelContext
- Saves context immediately
- Cascading deletes any related data

**Example:**
```swift
let service = RuleService(modelContext: modelContext)
let rule: Rule = // ... fetched from database

try service.deleteRule(rule)
```

---

#### seedDefaultRules()

Seeds the database with default rules for common file types.

**Signature:**
```swift
func seedDefaultRules() throws
```

**Parameters:** None

**Returns:** Void

**Throws:** SwiftData save errors

**Behavior:**
- Only runs if database is empty (no existing rules)
- Creates rules for common extensions: .pdf, .jpg, .png, .mp4, .zip, .doc, .xls
- Sets supported default destinations within bookmark-backed roots such as `Documents`, `Pictures`, and `Music`

**Use Cases:**
- First app launch
- After database reset
- User requests "restore defaults"

**Example:**
```swift
let service = RuleService(modelContext: modelContext)

try service.seedDefaultRules()
print("Default rules seeded")
```

---

#### seedTemplateRules(template:clearExisting:)

Generates and saves rules based on an OrganizationTemplate.

**Signature:**
```swift
func seedTemplateRules(
    template: OrganizationTemplate,
    clearExisting: Bool = true
) throws
```

**Parameters:**
- `template`: OrganizationTemplate to generate rules from
- `clearExisting`: If true, deletes all existing rules first (default: true)

**Returns:** Void

**Throws:** SwiftData errors

**Behavior:**
1. If `clearExisting`, deletes all current rules
2. Calls `template.generateRules(baseDocumentsPath:)` to create canonical root-relative placeholder destinations (for example `Documents/Areas/Health`)
3. Inserts generated rules into database
4. Saves context

**Notes:**
- Template-generated rules stay non-destructive until their destinations are materialized by an explicit save flow or a bulk create action.
- Per-folder onboarding may call `generateRules(baseDocumentsPath:)` with roots like `Desktop`, `Downloads`, or `Documents` and then scope the rules to the selected category.

**Templates:**
- `.para`: PARA method (Projects, Areas, Resources, Archives)
- `.johnnyDecimal`: Johnny.Decimal system
- `.creativeProf`: Creative professional workflow
- `.minimal`: Minimal folder structure
- `.student`: Student-optimized organization
- `.chronological`: Date-based organization

**Example:**
```swift
let service = RuleService(modelContext: modelContext)

// Replace all rules with PARA template
try service.seedTemplateRules(
    template: .para,
    clearExisting: true
)

// Add Johnny.Decimal rules alongside existing
try service.seedTemplateRules(
    template: .johnnyDecimal,
    clearExisting: false
)
```

---

## ThumbnailService

Service for generating and caching file thumbnails using QuickLook with two-tier caching (memory + disk).

### Class Declaration

```swift
actor ThumbnailService
```

**Design Pattern:** Singleton actor (`ThumbnailService.shared`)
**Framework:** QuickLookThumbnailing (QLThumbnailGenerator)
**Thread Safety:** Actor isolation ensures all operations are thread-safe
**Caching:** Two-tier system with NSCache (memory) + disk persistence

### Singleton Access

```swift
static let shared: ThumbnailService
```

Always use the shared instance for consistent cache state across the app. The singleton is constructed first, then startup cache maintenance is scheduled asynchronously and retained so the task can be cancelled if the actor is torn down.

### Configuration Constants

```swift
private let maxDiskCacheSize: Int64 = 100_000_000  // 100 MB
private let maxCacheAgeDays: Int = 30
private let memoryCacheCountLimit = 200
private let memoryCacheTotalCostLimit = 50 * 1024 * 1024  // 50 MB
```

**Configuration Notes:**
- Disk cache is automatically cleaned up on app launch
- Old thumbnails (> 30 days) are evicted
- Cache size is capped at 100MB with LRU eviction

### Methods

#### thumbnail(for:size:)

Generates or retrieves a cached thumbnail for a file path.

**Signature:**
```swift
func thumbnail(for path: String, size: CGSize) async -> NSImage?
```

**Parameters:**
- `path`: Absolute file path to generate thumbnail for
- `size`: Desired thumbnail dimensions (e.g., `CGSize(width: 80, height: 80)`)

**Returns:**
- `NSImage`: Generated or cached thumbnail
- `nil`: If thumbnail generation failed (unsupported file type)

**Behavior:**
1. Check memory cache (fastest)
2. Check disk cache (loads and warms memory cache)
3. Generate via QLThumbnailGenerator
4. Fallback to Image I/O for basic images
5. Cache in both memory and disk layers

**Cache Invalidation:**
- Cache key includes file modification date
- If source file is modified, cached thumbnail is invalidated automatically

**Supported File Types:**
- Images: jpg, png, gif, heic, webp, svg, etc.
- Videos: mp4, mov, avi, mkv, etc.
- Documents: pdf, doc, docx, txt, rtf, etc.
- Spreadsheets: xls, xlsx, csv, etc.
- Presentations: ppt, pptx, key, etc.
- Archives: zip (icon fallback)
- Any type supported by QuickLook

**Example:**
```swift
let thumbnail = await ThumbnailService.shared.thumbnail(
    for: "/Users/user/Desktop/document.pdf",
    size: CGSize(width: 80, height: 80)
)

if let image = thumbnail {
    // Display thumbnail
} else {
    // Fall back to system icon
    let icon = NSWorkspace.shared.icon(forFile: path)
}
```

---

#### clearCache()

Clears both memory and disk thumbnail caches.

**Signature:**
```swift
func clearCache() async
```

**Parameters:** None

**Returns:** Void

**Side Effects:**
- Removes all objects from NSCache (memory)
- Deletes cache directory contents (disk)
- Recreates empty cache directory

**Use Cases:**
- User requests cache clear in Settings
- Debugging thumbnail issues
- Freeing disk space

**Example:**
```swift
Task {
    await ThumbnailService.shared.clearCache()
    print("Thumbnail cache cleared")
}
```

---

#### cacheStats()

Returns statistics about the current disk cache state.

**Signature:**
```swift
func cacheStats() async -> (diskFiles: Int, diskSizeBytes: Int64)
```

**Parameters:** None

**Returns:**
- `diskFiles`: Number of cached thumbnail files
- `diskSizeBytes`: Total size of disk cache in bytes

**Use Cases:**
- Displaying cache size in Settings
- Debugging cache behavior
- Monitoring storage usage

**Example:**
```swift
let stats = await ThumbnailService.shared.cacheStats()
let sizeMB = Double(stats.diskSizeBytes) / 1_000_000
print("Cache: \(stats.diskFiles) files, \(String(format: "%.1f", sizeMB)) MB")
```

**Output:**
```
Cache: 147 files, 23.4 MB
```

---

### Cache Architecture

#### Two-Tier Caching

```
Request thumbnail
      ↓
[Memory Cache] ← NSCache (50MB limit, 200 items)
      ↓ miss
[Disk Cache] ← ~/Library/Caches/[BundleID]/Thumbnails/ (100MB limit)
      ↓ miss
[Generate] ← QLThumbnailGenerator → ImageIO fallback
      ↓
Cache in both tiers
```

**Memory Cache (NSCache):**
- Fast access for recently viewed files
- Automatically evicts under memory pressure
- 200 item count limit
- 50MB total cost limit

**Disk Cache:**
- Persistent across app launches
- Sharded directories (first 2 chars of hash)
- PNG format for quality
- Location: `~/Library/Caches/com.forma.fileorganizing/Thumbnails/`

#### Cache Key Generation

Cache keys are generated using SHA256 hash of:
- File path
- Requested size (width × height)
- File modification date

```swift
let input = "\(path)|\(Int(size.width))x\(Int(size.height))|\(Int(modDate.timeIntervalSince1970))"
let hash = SHA256.hash(data: Data(input.utf8))
// Returns first 32 characters of hex string
```

**Benefits:**
- Automatic invalidation when file is modified
- Different sizes get different cache entries
- Stable keys across app launches

#### Directory Sharding

Disk cache uses subdirectory sharding to avoid filesystem bottlenecks:

```
Thumbnails/
├── a3/
│   ├── a3f2b9c8d4e1...png
│   └── a3e7f1a2b5c8...png
├── 7b/
│   └── 7b2c9d4e5f6a...png
└── f1/
    └── f1a2b3c4d5e6...png
```

First 2 characters of cache key become subdirectory name.

---

### Cache Maintenance

#### Startup Maintenance

After singleton construction, ThumbnailService schedules startup maintenance:
1. **Age-based cleanup**: Removes thumbnails older than 30 days
2. **Size-based eviction**: If cache > 100MB, evicts oldest entries (LRU)

```swift
private func performStartupMaintenance() async {
    await cleanupOldThumbnails()
    await evictIfOverSizeLimit()
}
```

**Logging:**
- Cleanup operations logged to `.filesystem` category
- Only logs when items are actually removed

---

### Error Types

#### ThumbnailCacheError

```swift
enum ThumbnailCacheError: Error {
    case cacheDirUnavailable
    case invalidPath
    case imageConversionFailed
    case imageEncodingFailed
}
```

**Error Descriptions:**
- `cacheDirUnavailable`: Cannot access ~/Library/Caches directory
- `invalidPath`: File path is invalid or file doesn't exist
- `imageConversionFailed`: CGImage conversion failed
- `imageEncodingFailed`: PNG encoding failed

**Note:** These errors are handled internally; `thumbnail(for:size:)` returns `nil` on failure rather than throwing.

---

### Integration with UI Components

#### FileThumbnailView

```swift
struct FileThumbnailView: View {
    let file: FileItem
    var size: CGFloat = 80
    @State private var thumbnail: NSImage?

    var body: some View {
        // Shows thumbnail or fallback icon
    }

    private func loadThumbnail() async {
        thumbnail = await ThumbnailService.shared.thumbnail(
            for: file.path,
            size: CGSize(width: size, height: size)
        )
    }
}
```

#### ThumbnailPreviewPopup

```swift
struct ThumbnailPreviewPopup: View {
    let file: FileItem
    @State private var largeThumbnail: NSImage?

    private func loadLargeThumbnail() async {
        largeThumbnail = await ThumbnailService.shared.thumbnail(
            for: file.path,
            size: CGSize(width: 300, height: 300)
        )
    }
}
```

#### FileRow (PremiumThumbnail)

```swift
// In FileRow, PremiumThumbnail loads thumbnails for ALL file types
.task(id: file.path) {
    await loadThumbnail()  // No category restriction
}
```

---

### Performance Considerations

**Memory Usage:**
- Memory cache limited to 50MB
- Each thumbnail costs ~4 bytes per pixel (RGBA)
- 80×80 thumbnail ≈ 25KB
- 300×300 preview ≈ 360KB

**Disk I/O:**
- Atomic writes prevent corruption
- PNG format balances quality and size
- Sharded directories reduce lookup time

**Generation Performance:**
- QLThumbnailGenerator runs asynchronously
- Respects `NSScreen.main?.backingScaleFactor` for Retina
- Image I/O fallback is synchronous but fast

**Best Practices:**
1. Use appropriate sizes (don't request 300×300 for list icons)
2. Batch thumbnail requests when possible
3. Show loading indicator for large previews
4. Always provide fallback to system icon

---

### Usage Examples

#### Basic Thumbnail Loading

```swift
Task {
    let thumbnail = await ThumbnailService.shared.thumbnail(
        for: filePath,
        size: CGSize(width: 80, height: 80)
    )

    await MainActor.run {
        if let image = thumbnail {
            imageView.image = image
        } else {
            imageView.image = NSWorkspace.shared.icon(forFile: filePath)
        }
    }
}
```

#### SwiftUI Integration

```swift
struct FileIconView: View {
    let path: String
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                let icon = NSWorkspace.shared.icon(forFile: path)
                Image(nsImage: icon)
                    .resizable()
            }
        }
        .frame(width: 60, height: 60)
        .task(id: path) {
            thumbnail = await ThumbnailService.shared.thumbnail(
                for: path,
                size: CGSize(width: 60, height: 60)
            )
        }
    }
}
```

#### Cache Management in Settings

```swift
struct SettingsView: View {
    @State private var cacheSize: String = "Calculating..."

    var body: some View {
        Form {
            Section("Cache") {
                LabeledContent("Thumbnail Cache", value: cacheSize)

                Button("Clear Cache") {
                    Task {
                        await ThumbnailService.shared.clearCache()
                        await updateCacheSize()
                    }
                }
            }
        }
        .task {
            await updateCacheSize()
        }
    }

    private func updateCacheSize() async {
        let stats = await ThumbnailService.shared.cacheStats()
        let sizeMB = Double(stats.diskSizeBytes) / 1_000_000
        await MainActor.run {
            cacheSize = "\(stats.diskFiles) files (\(String(format: "%.1f", sizeMB)) MB)"
        }
    }
}
```

---

## UndoCommand

Command pattern implementation for undoable file organization operations. Stores minimal data for memory efficiency.

### Protocol

#### UndoableCommand

Protocol defining the contract for all undoable commands.

**Signature:**
```swift
protocol UndoableCommand {
    var id: UUID { get }
    var timestamp: Date { get }
    var description: String { get }

    func execute(context: ModelContext?) async throws
    func undo(context: ModelContext?) throws
}
```

**Properties:**
- `id`: Unique identifier for the command
- `timestamp`: When the command was executed
- `description`: Human-readable description for UI

**Methods:**
- `execute()`: Performs the operation (for redo)
- `undo()`: Reverses the operation

**Context Requirement:**
- `MoveFileCommand` and `BulkMoveCommand` require a non-nil `ModelContext`; they throw `CommandError.noContext` if absent.
- `SkipFileCommand` can be applied in-memory when no context is available.

---

### Concrete Commands

#### MoveFileCommand

Command for moving a single file.

**Declaration:**
```swift
struct MoveFileCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let fileID: String
    let fromPath: String
    let toPath: String
    let originalStatus: FileItem.OrganizationStatus
    let originalDestination: Destination?
    let memorySnapshot: OrganizationMemorySnapshot?
}
```

**Storage:** Lightweight - only paths and deltas, not full FileItem objects

**Example:**
```swift
let moveCmd = MoveFileCommand(
    id: UUID(),
    timestamp: Date(),
    fileID: "/Users/user/Desktop/file.pdf",
    fromPath: "/Users/user/Desktop/file.pdf",
    toPath: "/Users/user/Documents/file.pdf",
    originalStatus: .pending,
    originalDestination: .folder(bookmark: Data(), displayName: "Documents"),
    memorySnapshot: nil
)

// Execute: Moves file to destination
try await moveCmd.execute(context: modelContext)

// Undo: Moves file back to original location
try moveCmd.undo(context: modelContext)
```

---

#### SkipFileCommand

Command for marking a file as skipped.

**Declaration:**
```swift
struct SkipFileCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let fileID: String
    let previousStatus: FileItem.OrganizationStatus
    let previousDestination: Destination?
}
```

**Example:**
```swift
let skipCmd = SkipFileCommand(
    id: UUID(),
    timestamp: Date(),
    fileID: "/Users/user/Desktop/temp.txt",
    previousStatus: .pending,
    previousDestination: .folder(bookmark: Data(), displayName: "Inbox")
)

// Execute: Marks file as skipped
try await skipCmd.execute(context: modelContext)

// Undo: Restores previous status
try skipCmd.undo(context: modelContext)
```

---

#### OrganizationMemorySnapshot

Lightweight context captured at organize time so undo recovery can feed accurate signals back into the personal-memory layer.

```swift
struct OrganizationMemorySnapshot: Sendable {
    let fileName: String
    let fileExtension: String
    let fileTypeCategory: FileTypeCategory
    let sourceLocation: FileLocationKind
    let scanRootPath: String?
    let relativeParentPath: String?
    let suggestionSource: SuggestionSource?
    let suggestedDestination: Destination?
    let chosenDestination: Destination?
    let confidenceScore: Double?
    let matchedRuleID: UUID?
}
```

#### BulkMoveOperation

Per-file payload stored inside `BulkMoveCommand`.

```swift
struct BulkMoveOperation: Sendable {
    let fileID: String
    let fromPath: String
    let toPath: String
    let originalStatus: FileItem.OrganizationStatus
    let memorySnapshot: OrganizationMemorySnapshot?
}
```

---

#### BulkMoveCommand

Command for moving multiple files in a single operation.

**Declaration:**
```swift
struct BulkMoveCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let origin: OrganizationRunOrigin
    let operations: [BulkMoveOperation]
}
```

**Example:**
```swift
let bulkCmd = BulkMoveCommand(
    id: UUID(),
    timestamp: Date(),
    origin: .reviewDriven,
    operations: [
        BulkMoveOperation(
            fileID: "file1.pdf",
            fromPath: "/Desktop/file1.pdf",
            toPath: "/Docs/file1.pdf",
            originalStatus: .pending,
            memorySnapshot: nil
        ),
        BulkMoveOperation(
            fileID: "file2.jpg",
            fromPath: "/Desktop/file2.jpg",
            toPath: "/Images/file2.jpg",
            originalStatus: .pending,
            memorySnapshot: nil
        )
    ]
)

// Execute: Moves all files
try await bulkCmd.execute(context: modelContext)

// Undo: Reverts all moves
try bulkCmd.undo(context: modelContext)
```

**Behavior:**
- Continues on individual file errors (won't abort entire batch)
- Updates FileItem status and path for each successful operation
- Logs failures in DEBUG builds

---

### Error Types

#### CommandError

```swift
enum CommandError: LocalizedError {
    case noContext
    case fileNotFound(String)
    case operationFailed(String)
}
```

**Error Descriptions:**
- `noContext`: "No SwiftData context available for undo operation"
- `fileNotFound`: "File not found: \(fileID)"
- `operationFailed`: "Operation failed: \(reason)"

---

### Usage Pattern

```swift
// 1. Create command from user action
let command = MoveFileCommand(/* ... */)

// 2. Execute the operation
try await command.execute(context: modelContext)

// 3. Store command in undo stack
undoStack.append(command)

// 4. Later, user requests undo
if let lastCommand = undoStack.popLast() {
    try lastCommand.undo(context: modelContext)
    redoStack.append(lastCommand)
}

// 5. User requests redo
if let lastUndo = redoStack.popLast() {
    try await lastUndo.execute(context: modelContext)
    undoStack.append(lastUndo)
}
```

---

### Design Rationale

**Why Command Pattern?**
- Enables undo/redo without storing full object state
- Separates operation logic from ViewModel
- Supports macro commands (bulk operations)
- Testable in isolation

**Why Lightweight Storage?**
- Storing full FileItem objects would consume significant memory
- Only deltas (paths, status changes) are needed for undo
- Fetches current state from SwiftData when executing

**Security:**
- All file operations use `FileOperationsService.secureMoveOnDisk()`
- Validates paths before moving
- Atomic operations (move succeeds or fails entirely)

---

## AutomationEngine

Coordinates background scans and automation workflows.

### FileScanResult

Returned by `FileScanProvider.scanFiles(context:)` to summarize a scan.

**Declaration:**
```swift
struct FileScanResult: Sendable {
    let totalScanned: Int
    let pendingCount: Int
    let readyCount: Int
    let organizedCount: Int
    let skippedCount: Int
    let oldestPendingAgeDays: Int?
    let errorSummary: String?
}
```

**Notes:**
- `errorSummary` is non-nil when a scan completes with partial failures (e.g., missing folder access).
- Callers should surface `errorSummary` to the user via toast or notification instead of silently logging.

---

## ReviewViewModel

Main ViewModel that orchestrates file scanning, rule evaluation, and organization.

### Class Declaration

```swift
@MainActor
class ReviewViewModel: ObservableObject
```

**Note:** All methods must be called on the main actor.

### Published Properties

```swift
@Published var files: [FileItem] = []
@Published var loadingState: LoadingState = .idle
@Published var errorMessage: String?
@Published var successMessage: String?
```

**Property Details:**

**files**
- Type: `[FileItem]`
- Description: Array of files currently in review
- Updates: Triggers UI refresh
- Filter: Only includes pending/ready files (not completed/skipped)

**loadingState**
- Type: `LoadingState`
- Description: Current scan/load state
- Values: `.idle`, `.loading`, `.loaded`, `.error`
- Usage: Drive loading spinner UI

**errorMessage**
- Type: `String?`
- Description: Current error to display
- Auto-clears: After user dismissal or timeout
- nil: No error

**successMessage**
- Type: `String?`
- Description: Success feedback message
- Auto-clears: After 2-4 seconds
- nil: No message

---

### Loading State

```swift
enum LoadingState {
    case idle      // Initial state, no scan started
    case loading   // Scan in progress
    case loaded    // Scan complete, files available
    case error     // Scan failed
}
```

---

### Methods

#### setModelContext(_:)

Initializes the ViewModel with SwiftData context and triggers initial scan.

**Signature:**
```swift
func setModelContext(_ context: ModelContext)
```

**Parameters:**
- `context`: SwiftData ModelContext for persistence

**Returns:** Void

**Side Effects:**
- Stores context reference
- Triggers `scanDesktop()` async

**Example:**
```swift
struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ReviewViewModel()

    var body: some View {
        VStack {
            // UI
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
}
```

---

#### scanDesktop()

Scans Desktop folder, evaluates files against rules, and updates UI.

**Signature:**
```swift
func scanDesktop() async
```

**Returns:** Void

**Side Effects:**
- Updates `loadingState`
- Updates `files` array
- Updates `errorMessage` on failure
- Saves FileItems to SwiftData

**Example:**
```swift
Button("Scan Desktop") {
    Task {
        await viewModel.scanDesktop()
    }
}
```

**Behavior:**
1. Set `loadingState = .loading`
2. Scan Desktop via FileSystemService
3. Fetch active rules from SwiftData
4. Evaluate files via RuleEngine
5. Update `files` array
6. Save to SwiftData
7. Set `loadingState = .loaded` (or `.error`)

---

#### moveFile(_:)

Moves a single file to its suggested destination.

**Signature:**
```swift
func moveFile(_ fileItem: FileItem) async
```

**Parameters:**
- `fileItem`: File to move (must have `suggestedDestination`)

**Returns:** Void

**Side Effects:**
- Removes file from `files` array on success
- Updates `successMessage` or `errorMessage`
- Updates file status in SwiftData

**Example:**
```swift
Button {
    Task {
        await viewModel.moveFile(file)
    }
} label: {
    Image(systemName: "checkmark")
}
```

**Animation:**
Files are removed with spring animation for smooth UI transition.

---

#### moveAllFiles()

Batch move operation for all files with suggestions.

**Signature:**
```swift
func moveAllFiles() async
```

**Returns:** Void

**Side Effects:**
- Removes successfully moved files from `files` array
- Shows summary message with counts
- Updates `successMessage` and/or `errorMessage`

**Example:**
```swift
Button("Organize All") {
    Task {
        await viewModel.moveAllFiles()
    }
}
```

**Summary Messages:**
```
All succeeded: "Successfully moved 47 files"
Partial success: "Moved 45 of 47 files" + error note
All failed: "No files were moved. Please grant folder permissions."
```

---

#### skipFile(_:)

Removes a file from the review list without moving it.

**Signature:**
```swift
func skipFile(_ fileItem: FileItem)
```

**Parameters:**
- `fileItem`: File to skip

**Returns:** Void

**Side Effects:**
- Sets file status to `.skipped`
- Removes from `files` array with animation

**Example:**
```swift
Button {
    viewModel.skipFile(file)
} label: {
    Image(systemName: "xmark")
}
```

---

#### refresh()

Re-scans Desktop folder (alias for scanDesktop).

**Signature:**
```swift
func refresh() async
```

**Returns:** Void

**Example:**
```swift
Button {
    Task {
        await viewModel.refresh()
    }
} label: {
    Image(systemName: "arrow.clockwise")
}
```

---

#### resetDesktopAccess()

Clears Desktop folder permission bookmark.

**Signature:**
```swift
func resetDesktopAccess()
```

**Returns:** Void

**Use Case:** Troubleshooting Desktop access issues.

---

#### resetAllPermissions()

Clears all saved permissions (Desktop + all destinations).

**Signature:**
```swift
func resetAllPermissions()
```

**Returns:** Void

**Side Effects:**
- Clears all bookmarks
- Sets `errorMessage` to instruct restart

**Use Case:** Complete permission reset.

---

#### clearError()

Dismisses current error message.

**Signature:**
```swift
func clearError()
```

**Returns:** Void

---

#### clearSuccess()

Dismisses current success message.

**Signature:**
```swift
func clearSuccess()
```

**Returns:** Void

---

## Models

### FileItem

Represents a file to be organized.

**Declaration:**
```swift
@Model
final class FileItem {
    @Attribute(.unique) var path: String
    var name: String
    var fileExtension: String
    var size: String
    var creationDate: Date
    var suggestedDestination: String?
    var status: FileStatus

    enum FileStatus: String, Codable {
        case pending
        case ready
        case completed
        case skipped
    }
}
```

**Initializer:**
```swift
init(
    name: String,
    fileExtension: String,
    size: String,
    creationDate: Date,
    path: String,
    suggestedDestination: String?,
    status: FileStatus
)
```

**Example:**
```swift
let file = FileItem(
    name: "invoice.pdf",
    fileExtension: "pdf",
    size: "1.2 MB",
    creationDate: Date(),
    path: "/Users/username/Desktop/invoice.pdf",
    suggestedDestination: "Documents/Finance/Invoices",
    status: .ready
)
```

---

### Rule

Defines an organizational rule with support for compound conditions, priority ordering, and exclusion patterns.

**Declaration:**
```swift
@Model
final class Rule: Ruleable {
    @Attribute(.unique) var id: UUID
    var name: String
    var isEnabled: Bool

    // Legacy single-condition (backward compatible)
    var conditionType: ConditionType
    var conditionValue: String

    // Compound conditions (preferred for new rules)
    var conditions: [RuleCondition]
    var logicalOperator: LogicalOperator

    // Exclusion conditions ("veto" patterns)
    var exclusionConditions: [RuleCondition]

    // Priority ordering (lower = higher priority)
    var sortOrder: Int

    var actionType: ActionType
    var destination: Destination?
    var creationDate: Date

    enum ConditionType: String, Codable, CaseIterable {
        case fileExtension       // Match by file extension
        case nameContains        // Name contains substring
        case nameStartsWith      // Name starts with prefix
        case nameEndsWith        // Name ends with suffix
        case dateOlderThan       // Creation date older than N days
        case sizeLargerThan      // File size larger than N bytes
        case dateModifiedOlderThan  // Modification date older than N days
        case dateAccessedOlderThan  // Access date older than N days
        case fileKind            // Match by category (image, video, document, etc.)
        case sourceLocation      // Match by source folder (downloads, desktop, etc.)
    }

    enum ActionType: String, Codable, CaseIterable {
        case move
        case copy
        case delete
    }

    enum LogicalOperator: String, Codable, CaseIterable {
        case and     // ALL conditions must match
        case or      // ANY condition must match
        case single  // Legacy single-condition mode
    }
}
```

**Initializer (Legacy Single-Condition):**
```swift
init(
    name: String,
    conditionType: ConditionType,
    conditionValue: String,
    actionType: ActionType,
    destination: Destination? = nil,
    isEnabled: Bool = true
)
```

**Initializer (Compound Conditions):**
```swift
init(
    name: String,
    conditions: [RuleCondition],
    logicalOperator: LogicalOperator,
    actionType: ActionType,
    destination: Destination? = nil,
    exclusionConditions: [RuleCondition] = [],
    isEnabled: Bool = true
)
```

**Example (Legacy):**
```swift
let rule = Rule(
    name: "Screenshots",
    conditionType: .nameStartsWith,
    conditionValue: "Screenshot",
    actionType: .move,
    destination: .folder(...)
)
context.insert(rule)
```

**Example (Compound AND with Exclusions):**
```swift
// Move old PDFs to archive, except drafts
let rule = Rule(
    name: "Archive Old PDFs",
    conditions: [
        .fileExtension("pdf"),
        .dateOlderThan(days: 30, extensionFilter: nil)
    ],
    logicalOperator: .and,
    actionType: .move,
    destination: .folder(...),
    exclusionConditions: [
        .nameContains("draft"),
        .nameContains("temp")
    ]
)
```

**Example (NOT Operator):**
```swift
// Move all images EXCEPT screenshots
let rule = Rule(
    name: "Non-Screenshot Images",
    conditions: [
        .fileKind("image"),
        .not(.nameContains("Screenshot"))
    ],
    logicalOperator: .and,
    actionType: .move,
    destination: .folder(...)
)
```

**Priority Ordering:**
```swift
// Rules are evaluated in sortOrder (ascending)
// Lower sortOrder = higher priority = evaluated first
let highPriorityRule = Rule(...)
highPriorityRule.sortOrder = 0  // Evaluated first

let lowPriorityRule = Rule(...)
lowPriorityRule.sortOrder = 10  // Evaluated later

// Use RuleService for bulk priority updates
try ruleService.updateRulePriorities(reorderedRules)
```

---

### RuleCondition

Type-safe enum representing a single condition for rule matching.

**Declaration:**
```swift
indirect enum RuleCondition: Codable, Hashable, Equatable {
    case fileExtension(String)          // Match by extension (e.g., "pdf")
    case nameContains(String)           // Filename contains substring
    case nameStartsWith(String)         // Filename starts with prefix
    case nameEndsWith(String)           // Filename ends with suffix
    case dateOlderThan(days: Int, extensionFilter: String?)  // Creation date older than N days
    case sizeLargerThan(Int64)          // File size in bytes
    case dateModifiedOlderThan(Int)     // Modification date older than N days
    case dateAccessedOlderThan(Int)     // Access date older than N days
    case fileKind(String)               // Category: "image", "video", "document", etc.
    case sourceLocation(LocationKind)   // Source folder type
    case not(RuleCondition)             // Negates the inner condition
}
```

**Creating Conditions:**
```swift
// Extension matching
let pdfCondition = RuleCondition.fileExtension("pdf")

// Name patterns
let screenshotCondition = RuleCondition.nameContains("Screenshot")

// Date-based (files older than 7 days)
let oldFilesCondition = RuleCondition.dateOlderThan(days: 7, extensionFilter: nil)

// Date-based with extension filter (old .dmg files)
let oldDmgCondition = RuleCondition.dateOlderThan(days: 7, extensionFilter: "dmg")

// Size-based (files larger than 100MB)
let largeFilesCondition = RuleCondition.sizeLargerThan(100 * 1024 * 1024)

// Category-based
let imageCondition = RuleCondition.fileKind("image")

// Negation
let notPdfCondition = RuleCondition.not(.fileExtension("pdf"))

// Nested negation
let notScreenshot = RuleCondition.not(.nameContains("Screenshot"))
```

**File Kind Categories:**
| Kind | Extensions |
|------|------------|
| image | jpg, jpeg, png, gif, heic, webp, svg, etc. |
| video | mp4, mov, avi, mkv, webm, etc. |
| audio | mp3, wav, aac, flac, m4a, etc. |
| document | pdf, doc, docx, txt, rtf, etc. |
| spreadsheet | xls, xlsx, csv, numbers, etc. |
| presentation | ppt, pptx, key, etc. |
| archive | zip, rar, 7z, dmg, pkg, etc. |
| code | swift, py, js, ts, html, css, etc. |

---

## Error Types

### FileSystemService.FileSystemError

```swift
enum FileSystemError: LocalizedError {
    case permissionDenied
    case directoryNotFound
    case scanFailed(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied. Please grant access to your Desktop folder."
        case .directoryNotFound:
            return "The specified directory was not found."
        case .scanFailed(let reason):
            return "Failed to scan directory: \(reason)"
        case .userCancelled:
            return "Folder selection was cancelled."
        }
    }
}
```

---

### FileOperationsService.FileOperationError

```swift
enum FileOperationError: LocalizedError {
    case sourceNotFound
    case destinationExists
    case permissionDenied
    case diskFull
    case fileInUse
    case userCancelled
    case systemPermissionDenied
    case operationFailed(String)

    var errorDescription: String? {
        // User-friendly error messages
    }
}
```

---

## Usage Examples

### Complete Scan & Move Workflow

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ReviewViewModel()

    var body: some View {
        VStack {
            if viewModel.loadingState == .loading {
                ProgressView("Scanning Desktop...")
            } else {
                List(viewModel.files) { file in
                    FileRow(file: file) {
                        Task {
                            await viewModel.moveFile(file)
                        }
                    }
                }

                Button("Organize All") {
                    Task {
                        await viewModel.moveAllFiles()
                    }
                }
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
}
```

---

### Custom Rule Creation

```swift
func createScreenshotRule(context: ModelContext) {
    let rule = Rule(
        name: "Screenshots",
        conditionType: .nameStartsWith,
        conditionValue: "Screenshot",
        actionType: .move,
        destination: .folder(bookmark: Data(), displayName: "Pictures/Screenshots")
    )

    context.insert(rule)

    do {
        try context.save()
        print("Rule created successfully")
    } catch {
        print("Failed to save rule: \(error)")
    }
}
```

---

### Error Handling Pattern

```swift
Task {
    do {
        let files = try await fileSystemService.scanDesktop()
        print("Found \(files.count) files")
    } catch let error as FileSystemService.FileSystemError {
        switch error {
        case .userCancelled:
            print("User cancelled - no action needed")
        case .permissionDenied:
            print("Show permission instructions")
        case .scanFailed(let reason):
            print("Error: \(reason)")
        case .directoryNotFound:
            print("Desktop folder not found")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}
```

---

### Batch Processing with Results

```swift
let filesToMove = viewModel.files.filter {
    $0.suggestedDestination != nil
}

let results = await fileOps.moveFiles(filesToMove)

// Separate successes and failures
let successes = results.filter { $0.success }
let failures = results.filter { !$0.success }

print("✅ Moved: \(successes.count)")
print("❌ Failed: \(failures.count)")

// Log failures for debugging
for failure in failures {
    print("Failed: \(failure.originalPath)")
    if let error = failure.error {
        print("  Reason: \(error.localizedDescription)")
    }
}
```

---

### SwiftData Queries

```swift
// Fetch all enabled rules
let descriptor = FetchDescriptor<Rule>(
    predicate: #Predicate { $0.isEnabled }
)
let activeRules = try context.fetch(descriptor)

// Fetch specific rule by name
let descriptor = FetchDescriptor<Rule>(
    predicate: #Predicate { $0.name == "Screenshots" }
)
if let rule = try context.fetch(descriptor).first {
    print("Found rule: \(rule.name)")
}

// Fetch pending files
let descriptor = FetchDescriptor<FileItem>(
    predicate: #Predicate { $0.status == .pending }
)
let pendingFiles = try context.fetch(descriptor)
```

---

## Thread Safety Notes

### Main Actor Requirements

**ViewModels:**
```swift
@MainActor
class ReviewViewModel: ObservableObject {
    // All methods run on main thread
}
```

**Usage:**
```swift
// ✅ Correct - already on main thread
Button("Scan") {
    Task {
        await viewModel.scanDesktop()
    }
}

// ❌ Wrong - would cause warning
Task.detached {
    await viewModel.scanDesktop()  // Warning: crossing actor boundary
}
```

### Service Methods

Services use `async/await` and can be called from any thread:

```swift
Task {
    // Service calls are thread-safe
    let files = try await fileSystemService.scanDesktop()

    // Update UI on main thread
    await MainActor.run {
        self.displayFiles(files)
    }
}
```

---

# Models

SwiftData models representing persistent data structures in Forma.

---

## OrganizationTemplate

Enumeration defining pre-built organization strategies with folder structures and rule generation.

### Declaration

```swift
enum OrganizationTemplate: String, Codable, CaseIterable {
    case para
    case johnnyDecimal
    case creativeProf
    case minimal
    case academic
    case chronological
    case student
    case custom
}
```

### Cases

**para**
- **Name:** "PARA Method"
- **Description:** Projects, Areas, Resources, Archives methodology
- **Folder Structure:**
  - Projects/
  - Areas/
  - Resources/
  - Archives/
- **Best For:** Productivity-focused professionals
- **Rule Count:** 12 rules

**johnnyDecimal**
- **Name:** "Johnny.Decimal"
- **Description:** Decimal-based hierarchical organization (10.00-99.99)
- **Folder Structure:**
  - 10-19_Projects/
  - 20-29_Administration/
  - 30-39_Finance/
  - 40-49_Media/
- **Best For:** Detail-oriented organizers
- **Rule Count:** 16 rules

**creativeProf**
- **Name:** "Creative Professional"
- **Description:** Creative workflow optimization
- **Folder Structure:**
  - Active_Projects/
  - Client_Work/
  - Portfolio/
  - Assets/
  - Raw_Files/
- **Best For:** Designers, photographers, video editors
- **Rule Count:** 14 rules

**minimal**
- **Name:** "Minimalist"
- **Description:** Simple, flat structure
- **Folder Structure:**
  - Documents/
  - Media/
  - Archives/
- **Best For:** Users preferring simplicity
- **Rule Count:** 6 rules

**academic**
- **Name:** "Academic"
- **Description:** Research and course organization
- **Folder Structure:**
  - Courses/
  - Research/
  - Papers/
  - References/
- **Best For:** Students and researchers
- **Rule Count:** 10 rules

**chronological**
- **Name:** "Chronological"
- **Description:** Date-based organization (YYYY/MM/)
- **Folder Structure:** Auto-generated by year/month
- **Best For:** Time-based thinkers
- **Rule Count:** Variable (date-based)

**student**
- **Name:** "Student"
- **Description:** Academic semester organization
- **Folder Structure:**
  - Courses/
  - Assignments/
  - Notes/
  - Projects/
- **Best For:** Students
- **Rule Count:** 8 rules

**custom**
- **Name:** "Custom"
- **Description:** User-defined organization
- **Folder Structure:** User-specified
- **Best For:** Power users
- **Rule Count:** 0 (user creates rules)

### Methods

#### generateRules(baseDocumentsPath:)

Generates Rule objects based on the template's organization strategy.

**Signature:**
```swift
func generateRules(baseDocumentsPath: String = FolderLocation.documents.displayName) -> [Rule]
```

**Parameters:**
- `baseDocumentsPath`: Canonical root-relative base path such as `Documents`, `Desktop`, or `Downloads`

**Returns:** Array of Rule objects configured for this template

**Example:**
```swift
let template = OrganizationTemplate.para
let rules = template.generateRules(baseDocumentsPath: "Documents")

print("Generated \(rules.count) rules:")
for rule in rules {
    print("  \(rule.name) → \(rule.destination)")
}
```

**Output (PARA):**
```
Generated 12 rules:
  Project Files → Documents/Projects
  Work Documents → Documents/Areas/Work
  Personal Resources → Documents/Resources
  Old Files → Documents/Archives
```

### Properties

#### displayName

Human-readable name for UI display.

```swift
var displayName: String { get }
```

#### folderStructure

Array of folder paths to create for this template.

```swift
var folderStructure: [String] { get }
```

#### description

Detailed description of the organization methodology.

```swift
var description: String { get }
```

---

## OrganizationPersonality

Model representing user's organizational style preferences, determined through onboarding quiz.

### Declaration

```swift
struct OrganizationPersonality: Codable {
    var organizationStyle: OrganizationStyle
    var thinkingStyle: ThinkingStyle
    var mentalModel: MentalModel
    var suggestedTemplate: OrganizationTemplate
}
```

**Persistence:** Stored in UserDefaults as JSON

### Personality Dimensions

#### OrganizationStyle

```swift
enum OrganizationStyle: String, Codable {
    case piler      // Prefers visible piles
    case filer      // Prefers organized folders
}
```

**piler**
- Likes visual reminders
- Keeps active items in sight
- Finds deep hierarchies frustrating
- **Suggested Templates:** minimal, chronological

**filer**
- Prefers systematic organization
- Comfortable with hierarchies
- Likes categorization
- **Suggested Templates:** para, johnnyDecimal, academic

#### ThinkingStyle

```swift
enum ThinkingStyle: String, Codable {
    case visual         // Thinks in images/projects
    case hierarchical   // Thinks in categories/structures
}
```

**visual**
- Project-oriented
- Spatial memory
- Prefers grid/card views
- **Suggested Templates:** creativeProf, student

**hierarchical**
- Category-oriented
- Logical memory
- Prefers list/tree views
- **Suggested Templates:** johnnyDecimal, academic

#### MentalModel

```swift
enum MentalModel: String, Codable {
    case projectBased   // Organizes by projects
    case timeBased      // Organizes by time periods
    case topicBased     // Organizes by topics/categories
}
```

**projectBased**
- Groups related files by project
- Prefers project-centric views
- **Suggested Templates:** para, creativeProf

**timeBased**
- Groups files by date/period
- Prefers chronological views
- **Suggested Templates:** chronological, student

**topicBased**
- Groups files by subject matter
- Prefers category-based views
- **Suggested Templates:** johnnyDecimal, academic

### Methods

#### save()

Saves personality to UserDefaults.

**Signature:**
```swift
func save()
```

**Storage Key:** `"organizationPersonality"`

**Example:**
```swift
var personality = OrganizationPersonality(
    organizationStyle: .filer,
    thinkingStyle: .hierarchical,
    mentalModel: .topicBased,
    suggestedTemplate: .johnnyDecimal
)

personality.save()
```

#### load()

Loads personality from UserDefaults.

**Signature:**
```swift
static func load() -> OrganizationPersonality?
```

**Returns:**
- `OrganizationPersonality`: If previously saved
- `nil`: If no saved personality exists

**Example:**
```swift
if let personality = OrganizationPersonality.load() {
    print("Suggested template: \(personality.suggestedTemplate.displayName)")
} else {
    print("No personality saved - show onboarding")
}
```

---

## ProjectCluster

Model representing detected groups of related files.

### Declaration

```swift
@Model
final class ProjectCluster {
    @Attribute(.unique) private(set) var id: UUID
    private(set) var clusterType: ClusterType
    private(set) var name: String
    private(set) var files: [String]              // File paths
    private(set) var confidenceScore: Double      // 0.0-1.0
    private(set) var detectedAt: Date
    var shouldShow: Bool                          // User can toggle visibility
}
```

### ClusterType

```swift
enum ClusterType: String, Codable {
    case projectCode        // Files with shared project code (e.g., "PRJ-123")
    case temporal           // Files modified within 5-minute window
    case nameSimilarity     // Files with similar names (Levenshtein distance)
    case dateStamp          // Files with date stamps (e.g., "2024-01-15")
}
```

### Properties

#### displayDescription

Human-readable description of the cluster.

```swift
var displayDescription: String { get }
```

**Examples:**
- "5 files from project PRJ-2024-Q1"
- "8 files modified together on Jan 15"
- "3 files with similar names: report_v1, report_v2, report_final"
- "12 files dated 2024-03"

#### confidenceScore

Confidence in cluster validity (0.0-1.0).

**Thresholds:**
- `0.9-1.0`: Very high confidence (clear project code match)
- `0.7-0.9`: High confidence (temporal proximity + name similarity)
- `0.5-0.7`: Medium confidence (name similarity only)
- `< 0.5`: Low confidence (don't show to user)

### Example

```swift
let cluster = ProjectCluster(
    clusterType: .projectCode,
    name: "Website Redesign",
    files: [
        "/Desktop/wireframe_v1.pdf",
        "/Desktop/wireframe_v2.pdf",
        "/Desktop/WEB-2024-001_mockup.png"
    ],
    confidenceScore: 0.95
)

if cluster.confidenceScore > 0.7 {
    print("Show cluster: \(cluster.displayDescription)")
}
```

---

## LearnedPattern

Model representing detected patterns from user file organization behavior.

### Declaration

```swift
@Model
final class LearnedPattern {
    @Attribute(.unique) private(set) var id: UUID
    private(set) var fileExtension: String
    private(set) var destinationPath: String
    private(set) var occurrenceCount: Int
    private(set) var sourceRaw: String
    private(set) var confidenceScore: Double     // 0.0-1.0
    private(set) var lastObserved: Date
    private(set) var rejectionCount: Int
    var shouldSuggest: Bool
    private(set) var convertedToRuleId: UUID?    // If converted to Rule
}
```

**Learning Algorithm:**
- Tracks user file move actions from ActivityItem history
- Requires minimum 3 occurrences to create pattern
- Confidence increases with more observations
- Decreases with rejections

### Source Tracking

```swift
enum LearnedPatternSource: String, Codable, Sendable {
    case activityHistory
    case personalMemory
}
```

`LearnedPattern.source` distinguishes patterns inferred from generic activity history from rule-suggestion candidates derived from the personal-memory layer.

### Methods

#### recordRejection()

Records that user rejected this pattern suggestion.

**Signature:**
```swift
func recordRejection()
```

**Side Effects:**
- Increments `rejectionCount`
- Decreases `confidenceScore` by 0.1
- Sets `shouldSuggest = false` if `rejectionCount >= 3`

**Example:**
```swift
let pattern: LearnedPattern = // ... from database

// User clicked "Don't suggest this"
pattern.recordRejection()
try modelContext.save()
```

#### markAsConverted(ruleId:)

Marks pattern as converted to a permanent Rule.

**Signature:**
```swift
func markAsConverted(ruleId: UUID)
```

**Parameters:**
- `ruleId`: UUID of the created Rule

**Side Effects:**
- Sets `convertedToRuleId`
- Sets `shouldSuggest = false` (no longer show as suggestion)

**Example:**
```swift
let pattern: LearnedPattern = // ... from database

// User clicked "Make this a rule"
let newRule = Rule(
    name: "PDFs to Documents",
    conditions: [.extensionIs(pattern.fileExtension)],
    destination: pattern.destinationPath
)
modelContext.insert(newRule)
try modelContext.save()

pattern.markAsConverted(ruleId: newRule.id)
try modelContext.save()
```

### Confidence Calculation

```swift
confidenceScore = min(1.0, (occurrenceCount / 10.0) - (rejectionCount * 0.1))
```

**Factors:**
- Each occurrence: +0.1 confidence (capped at 1.0)
- Each rejection: -0.1 confidence
- Minimum 3 occurrences required to suggest

**Examples:**
- 5 occurrences, 0 rejections: 0.5 confidence
- 10 occurrences, 0 rejections: 1.0 confidence
- 10 occurrences, 2 rejections: 0.8 confidence

---

## ActivityItem

Model representing a single file organization activity for tracking and undo.

### Declaration

```swift
@Model
final class ActivityItem {
    @Attribute(.unique) private(set) var id: UUID
    private(set) var activityType: ActivityType
    private(set) var fileName: String
    private(set) var fromPath: String?
    private(set) var toPath: String?
    private(set) var timestamp: Date
    private(set) var ruleName: String?
}
```

### ActivityType

```swift
enum ActivityType: String, Codable {
    case fileScanned        // File discovered during scan
    case fileOrganized      // File moved by rule
    case fileMoved          // File manually moved
    case fileSkipped        // File skipped by user
    case ruleApplied        // Rule evaluated (may not have moved file)
    case clusterDetected    // Project cluster identified
    case patternLearned     // New pattern detected
}
```

### Properties

#### relativeTimestamp

Human-readable relative time string.

```swift
var relativeTimestamp: String { get }
```

**Examples:**
- "Just now" (< 1 minute)
- "5 minutes ago"
- "1 hour ago"
- "Yesterday at 3:45 PM"
- "Jan 15 at 2:30 PM"

### Example Usage

```swift
// Creating activity
let activity = ActivityItem(
    activityType: .fileOrganized,
    fileName: "Report.pdf",
    fromPath: "/Desktop/Report.pdf",
    toPath: "/Documents/Work/Report.pdf",
    ruleName: "PDFs to Documents"
)
modelContext.insert(activity)
try modelContext.save()

// Displaying in activity feed
for activity in recentActivities {
    print("[\(activity.relativeTimestamp)] \(activity.fileName)")
    switch activity.activityType {
    case .fileOrganized:
        print("  Moved: \(activity.fromPath!) → \(activity.toPath!)")
    case .ruleApplied:
        print("  Rule: \(activity.ruleName ?? "Unknown")")
    default:
        break
    }
}
```

---

## CustomFolder

Model representing user-selected folder for monitoring, with security-scoped bookmark for persistent access.

### Declaration

```swift
@Model
final class CustomFolder {
    @Attribute(.unique) private(set) var id: UUID
    private(set) var name: String
    private(set) var path: String
    private(set) var bookmarkData: Data?
    private(set) var creationDate: Date
    var isEnabled: Bool                    // User can disable without deleting
}
```

**Validation:** Throws `ValidationError` if name/path are invalid

### Initialization

```swift
init(name: String, path: String, bookmarkData: Data? = nil) throws
```

**Throws:**
- `ValidationError.emptyName`: Name is empty after trimming
- `ValidationError.emptyPath`: Path is empty after trimming
- `ValidationError.invalidPath`: Path doesn't start with "/"

**Example:**
```swift
do {
    let folder = try CustomFolder(
        name: "Work Projects",
        path: "/Users/user/Projects/Work",
        bookmarkData: bookmarkData
    )
    modelContext.insert(folder)
} catch CustomFolder.ValidationError.emptyName {
    print("Folder name cannot be empty")
} catch {
    print("Invalid folder: \(error)")
}
```

### Methods

#### updateBookmarkData(_:)

Updates the security-scoped bookmark data.

**Signature:**
```swift
func updateBookmarkData(_ data: Data?)
```

**Use Cases:**
- Refreshing stale bookmark
- Setting bookmark after folder creation
- Clearing bookmark (pass nil)

**Example:**
```swift
let folder: CustomFolder = // ... from database
let newBookmark: Data = // ... from URL.bookmarkData()

folder.updateBookmarkData(newBookmark)
try modelContext.save()
```

#### updateName(_:)

Updates the folder's display name.

**Signature:**
```swift
func updateName(_ newName: String) throws
```

**Throws:**
- `ValidationError.emptyName`: Name is empty after trimming

**Example:**
```swift
let folder: CustomFolder = // ... from database

try folder.updateName("Client Projects")
try modelContext.save()
```

#### updatePath(_:)

Updates the folder's file system path.

**Signature:**
```swift
func updatePath(_ newPath: String) throws
```

**Throws:**
- `ValidationError.emptyPath`: Path is empty after trimming
- `ValidationError.invalidPath`: Path doesn't start with "/"

**Example:**
```swift
let folder: CustomFolder = // ... from database

try folder.updatePath("/Users/user/NewLocation")
try modelContext.save()
```

### Validation Errors

```swift
enum ValidationError: Error, LocalizedError {
    case emptyName
    case emptyPath
    case invalidPath
}
```

**Error Descriptions:**
- `emptyName`: "Folder name cannot be empty"
- `emptyPath`: "Folder path cannot be empty"
- `invalidPath`: "Folder path is invalid"

---

## Best Practices

### Error Handling

Always handle typed errors for better debugging:

```swift
do {
    try await fileOps.moveFile(file)
} catch let error as FileOperationsService.FileOperationError {
    handleFileOpError(error)
} catch let error as FileSystemService.FileSystemError {
    handleFileSystemError(error)
} catch {
    handleUnexpectedError(error)
}
```

### Async/Await

Use Task for async calls from sync contexts:

```swift
Button("Scan") {
    Task {
        await viewModel.scanDesktop()
    }
}
```

### SwiftData

Always handle fetch errors:

```swift
do {
    let rules = try context.fetch(descriptor)
} catch {
    print("Fetch failed: \(error)")
    // Provide fallback behavior
}
```

---

**Document Version:** 2.0
**Last Updated:** December 2025
**Next Review:** After API changes or new features
