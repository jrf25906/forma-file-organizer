# Personal Memory V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start Forma's personal-organization-memory layer with structured local decision capture, memory-aware review suggestions, memory-backed rule suggestions, and a light Settings summary/reset surface.

**Architecture:** Keep `ActivityItem` as the audit feed, but add a dedicated personal-memory subsystem beside it. Capture organize/override/undo/rule-suggestion signals close to successful operations, derive stable preferences from those events, then consume those preferences in `FileScanPipeline` before learned-pattern/ML fallback and in rule-suggestion generation via `LearnedPattern`.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, macOS app services, security-scoped bookmarks

---

## File structure

### New files

- `Forma File Organizing/Models/PersonalMemoryEvent.swift`
- `Forma File Organizing/Models/PersonalMemoryPreference.swift`
- `Forma File Organizing/Services/PersonalMemoryService.swift`
- `Forma File OrganizingTests/PersonalMemoryServiceTests.swift`

### Existing files to modify

- `Forma File Organizing/Forma_File_OrganizingApp.swift`
- `Forma File Organizing/Models/DestinationPredictionTypes.swift`
- `Forma File Organizing/Models/FileItem.swift`
- `Forma File Organizing/Models/FileMetadata.swift`
- `Forma File Organizing/Services/FileScanPipeline.swift`
- `Forma File Organizing/Services/LearningService.swift`
- `Forma File Organizing/Services/RuleService.swift`
- `Forma File Organizing/Services/ActivityLoggingService.swift`
- `Forma File Organizing/Coordinators/FileOrganizationCoordinator.swift`
- `Forma File Organizing/Views/RuleSuggestionView.swift`
- `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- `Forma File Organizing/Components/Shared/FileMetaStrip.swift`
- `Forma File OrganizingTests/FileScanPipelinePrecedenceTests.swift`
- `Forma File OrganizingTests/SuggestionSourcePersistenceTests.swift`
- `TODO.md`
- `Docs/Getting-Started/TODO.md`
- `Docs/Getting-Started/CHANGELOG.md`
- `Docs/API-Reference/API_REFERENCE.md`

## Task 1: Add personal-memory persistence and aggregation

**Files:**
- Create: `Forma File Organizing/Models/PersonalMemoryEvent.swift`
- Create: `Forma File Organizing/Models/PersonalMemoryPreference.swift`
- Create: `Forma File Organizing/Services/PersonalMemoryService.swift`
- Modify: `Forma File Organizing/Forma_File_OrganizingApp.swift`
- Test: `Forma File OrganizingTests/PersonalMemoryServiceTests.swift`

- [ ] **Step 1: Write a failing test for recording an accepted suggestion**

Create a service test that records one accepted decision and expects:
- one `PersonalMemoryEvent`
- one `PersonalMemoryPreference`
- accept count `1`
- override/correction/undo counts `0`

- [ ] **Step 2: Run the new service test and verify it fails for the expected reason**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/PersonalMemoryServiceTests/testRecordAcceptedSuggestionCreatesEventAndPreference"`

Expected: FAIL because the new memory types/service do not exist yet.

- [ ] **Step 3: Implement the smallest persistence layer that makes the first test pass**

Implement:
- `PersonalMemoryEvent` with event kind, source surface, suggestion source, file context, suggested/chosen destination payloads, and optional related event ID
- `PersonalMemoryPreference` with context key, preferred destination payload, counts, stability score, rule-readiness score, and timestamps
- `PersonalMemoryService.recordDecision(...)`
- `PersonalMemoryService.resetAllMemory()`
- app schema registration in `Forma_File_OrganizingApp.swift`

- [ ] **Step 4: Add a failing test for overrides and undo-weighting**

Add tests that expect:
- override events increment override count
- undo events increment undo count
- stability/rule-readiness drop after undo

- [ ] **Step 5: Run the service test target again and verify RED, then GREEN**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/PersonalMemoryServiceTests"`

Expected after implementation: PASS

## Task 2: Capture real decision signals at organize, undo, and rule-suggestion boundaries

**Files:**
- Modify: `Forma File Organizing/Models/FileItem.swift`
- Modify: `Forma File Organizing/Models/FileMetadata.swift`
- Modify: `Forma File Organizing/Coordinators/FileOrganizationCoordinator.swift`
- Modify: `Forma File Organizing/Services/RuleService.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Modify: `Forma File Organizing/Views/RuleSuggestionView.swift`
- Test: `Forma File OrganizingTests/PersonalMemoryServiceTests.swift`

- [ ] **Step 1: Write a failing test for chosen destination overriding the original suggestion**

Add a service-level test that records:
- suggested destination `A`
- chosen destination `B`

Expect:
- event kind is override
- preference points to `B`
- override count increments

- [ ] **Step 2: Add storage for original suggested destination on file models**

Modify `FileItem` and `FileMetadata` to keep the original suggested destination separate from the editable current destination.

- [ ] **Step 3: Wire organize and undo paths to personal-memory recording**

In `FileOrganizationCoordinator`:
- on successful single-file and bulk organize, record accept vs override using original suggestion vs chosen destination
- on bulk undo, record undo events for the affected operations

In `RuleSuggestionView` / `RuleService`:
- record accepted rule suggestions when a learned pattern becomes a rule
- record dismissed rule suggestions when the user rejects a pattern card

- [ ] **Step 4: Re-run the service tests**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/PersonalMemoryServiceTests"`

Expected: PASS

## Task 3: Insert personal memory into scan precedence and explanation copy

**Files:**
- Modify: `Forma File Organizing/Models/DestinationPredictionTypes.swift`
- Modify: `Forma File Organizing/Models/FileItem.swift`
- Modify: `Forma File Organizing/Models/FileMetadata.swift`
- Modify: `Forma File Organizing/Services/FileScanPipeline.swift`
- Modify: `Forma File Organizing/Components/Shared/FileMetaStrip.swift`
- Test: `Forma File OrganizingTests/FileScanPipelinePrecedenceTests.swift`
- Test: `Forma File OrganizingTests/SuggestionSourcePersistenceTests.swift`

- [ ] **Step 1: Write a failing precedence test for personal memory beating learned patterns**

Add a test that seeds:
- one stable personal-memory preference for `pdf + desktop`
- one conflicting `LearnedPattern`

Expect:
- resulting file uses the memory destination
- source is `SuggestionSource.personalMemory`
- explanation cites user behavior

- [ ] **Step 2: Add a new suggestion source and presentation labels**

Implement:
- `SuggestionSource.personalMemory`
- UI labels/icons/help text in `FileMetaStrip`
- persistence test update in `SuggestionSourcePersistenceTests`

- [ ] **Step 3: Add a memory-evaluation stage before learned patterns**

In `FileScanPipeline`:
- fetch personal-memory preferences
- apply them only to pending files
- keep explicit rules first
- leave learned patterns and ML as fallbacks

- [ ] **Step 4: Preserve original suggestion payload when the pipeline assigns a destination**

When the pipeline applies a memory/pattern/ML suggestion:
- set current destination
- set original suggested destination
- set `matchReason`, `confidenceScore`, and source

- [ ] **Step 5: Run the precedence tests**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/FileScanPipelinePrecedenceTests" -only-testing:"Forma File OrganizingTests/SuggestionSourcePersistenceTests"`

Expected: PASS

## Task 4: Generate memory-backed rule suggestions and add light settings transparency

**Files:**
- Modify: `Forma File Organizing/Services/PersonalMemoryService.swift`
- Modify: `Forma File Organizing/Services/LearningService.swift`
- Modify: `Forma File Organizing/Views/RuleSuggestionView.swift`
- Modify: `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- Test: `Forma File OrganizingTests/PersonalMemoryServiceTests.swift`

- [ ] **Step 1: Write a failing test for stable preferences becoming a suggestable learned pattern**

Expect:
- repeated low-correction behavior produces or updates a `LearnedPattern`
- unstable/high-correction behavior does not

- [ ] **Step 2: Upsert learned-pattern suggestions from personal-memory preferences**

Implement in `PersonalMemoryService` or a tightly scoped helper:
- stability threshold for reusable suggestions
- pattern description shaped for current `RuleSuggestionView`
- de-duplication/update behavior for existing `LearnedPattern` rows

- [ ] **Step 3: Add a small memory summary/reset surface in settings**

In `SmartFeaturesSection`:
- show memory count summary
- show last-updated text
- provide reset action

- [ ] **Step 4: Run the service tests again**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/PersonalMemoryServiceTests"`

Expected: PASS

## Task 5: Sync roadmap/docs and run targeted verification

**Files:**
- Modify: `TODO.md`
- Modify: `Docs/Getting-Started/TODO.md`
- Modify: `Docs/Getting-Started/CHANGELOG.md`
- Modify: `Docs/API-Reference/API_REFERENCE.md`

- [ ] **Step 1: Update roadmap/docs to reflect shipped memory-layer start**

Check off the roadmap item only if the implementation scope above is complete.

- [ ] **Step 2: Run the targeted verification suite**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/PersonalMemoryServiceTests" -only-testing:"Forma File OrganizingTests/FileScanPipelinePrecedenceTests" -only-testing:"Forma File OrganizingTests/SuggestionSourcePersistenceTests"`

Expected: PASS

- [ ] **Step 3: Run the repo preferred non-UI suite**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`

Expected: PASS
