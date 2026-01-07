# RuleEngine Protocol-Based Architecture

## Overview

The `RuleEngine` has been refactored to use protocol-based architecture instead of concrete SwiftData types. This document explains the design, rationale, and usage patterns.

## Problem Statement

Previously, `RuleEngine` directly depended on SwiftData models (`FileItem` and `Rule`). This created testing challenges:

- **MainActor Requirements**: SwiftData models require MainActor context
- **ModelContainer Setup**: Tests needed complex ModelContainer configuration
- **Async Complexity**: Many tests required `async` and `@MainActor` annotations
- **Slow Tests**: Database operations slowed down unit tests

## Solution: Protocol-Based Generics

### Architecture

```
┌─────────────────────────────────────────────────┐
│              RuleEngine                         │
│  (Uses Fileable & Ruleable protocols)          │
└──────────────┬──────────────────────┬───────────┘
               │                      │
         Production                 Testing
               │                      │
    ┌──────────▼──────────┐   ┌──────▼──────────┐
    │ FileItem : Fileable │   │ TestFileItem    │
    │ (SwiftData @Model)  │   │ : Fileable      │
    └─────────────────────┘   │ (Simple struct) │
                              └─────────────────┘
    ┌─────────────────────┐   ┌─────────────────┐
    │ Rule : Ruleable     │   │ TestRule        │
    │ (SwiftData @Model)  │   │ : Ruleable      │
    └─────────────────────┘   │ (Simple struct) │
                              └─────────────────┘
```

### Key Components

#### 1. Protocols

**`Fileable`** (`Models/FileProtocols.swift`)
```swift
protocol Fileable: AnyObject {
    var name: String { get set }
    var fileExtension: String { get }
    var path: String { get }
    var suggestedDestination: String? { get set }
    var status: FileItem.OrganizationStatus { get set }
}
```

**`Ruleable`** (`Models/RuleProtocols.swift`)
```swift
protocol Ruleable {
    var id: UUID { get }
    var conditions: [RuleCondition] { get }             // Source of truth for matching
    var logicalOperator: Rule.LogicalOperator { get }   // .and, .or, or .single
    var isEnabled: Bool { get }
    var destination: Destination? { get }
    var actionType: Rule.ActionType { get }
    var sortOrder: Int { get }                          // Priority ordering
    var exclusionConditions: [RuleCondition] { get }    // Exception handling
}
```

#### 2. Production Models

Both SwiftData models automatically conform to their respective protocols:

```swift
@Model
final class FileItem: Fileable { /* ... */ }

@Model
final class Rule: Ruleable { /* ... */ }
```

No additional code needed - the properties already exist!

#### 3. Test Models

Simple structs for testing (`Tests/TestModels.swift`):

```swift
final class TestFileItem: Fileable {
    var name: String
    var fileExtension: String
    var path: String
    var suggestedDestination: String?
    var status: FileItem.OrganizationStatus
    // Simple initializer, no SwiftData
}

struct TestRule: Ruleable {
    var id: UUID
    var conditions: [RuleCondition]
    var logicalOperator: Rule.LogicalOperator
    var isEnabled: Bool
    var destination: Destination?
    var actionType: Rule.ActionType
    var sortOrder: Int
    var exclusionConditions: [RuleCondition]
    // Simple struct, no SwiftData
}
```

#### 4. RuleEngine

Uses generic constraints to accept any conforming type:

```swift
class RuleEngine {
    func evaluateFile<F: Fileable, R: Ruleable>(_ fileItem: F, rules: [R]) -> F {
        // Implementation uses protocol methods only
    }
}
```

## Benefits

### 1. **Better Testability**
- No MainActor required in tests
- No ModelContainer setup
- No async complications
- Tests run faster

### 2. **Separation of Concerns**
- Business logic (RuleEngine) is decoupled from persistence (SwiftData)
- RuleEngine doesn't know or care about database details

### 3. **Flexibility**
- Easy to add new conforming types (e.g., temporary in-memory models)
- Could support other storage backends in the future

### 4. **Type Safety**
- Swift generics ensure compile-time type safety
- Same API works with production and test types

## Usage Examples

### Production Code

```swift
// In ViewModels, Services, etc.
let engine = RuleEngine()
let fileItem: FileItem = /* fetch from SwiftData */
let rules: [Rule] = /* fetch from SwiftData */

let result = engine.evaluateFile(fileItem, rules: rules)
// result is still a FileItem, can be saved back to SwiftData
```

### Test Code

```swift
// In unit tests
let engine = RuleEngine()
let testFile = TestFileItem(
    name: "document.pdf",
    fileExtension: "pdf",
    path: "/path/to/document.pdf"
)
let testRule = TestRule(
    conditions: [.fileExtension("pdf")],
    logicalOperator: .single,
    destination: .mockFolder("Documents")
)

let result = engine.evaluateFile(testFile, rules: [testRule])
XCTAssertEqual(result.destination?.displayName, "Documents")
```

## Migration Notes

### Breaking Changes

The RuleEngine API signature changed from:
```swift
// Old (concrete types)
func evaluateFile(_ file: FileItem, rules: [Rule]) -> FileItem

// New (protocol-based generics)
func evaluateFile<F: Fileable, R: Ruleable>(_ file: F, rules: [R]) -> F
```

### Impact

- **ViewModels/Services**: No code changes required (SwiftData models auto-conform)
- **Tests**: Must use `TestFileItem` and `TestRule` instead of SwiftData models

### Before (SwiftData Tests)

```swift
@MainActor
func testExample() async throws {
    let container = try ModelContainer(for: FileItem.self, Rule.self)
    let rule = Rule(name: "Test", conditions: [.fileExtension("pdf")], ...)
    let file = FileItem(name: "doc.pdf", ...)

    let result = engine.evaluateFile(file, rules: [rule])
}
```

### After (Protocol-Based Tests)

```swift
func testExample() {
    let rule = TestRule(conditions: [.fileExtension("pdf")], logicalOperator: .single, ...)
    let file = TestFileItem(name: "doc.pdf", fileExtension: "pdf", path: "/test/doc.pdf")

    let result = engine.evaluateFile(file, rules: [rule])
}
```

## File References

- **Protocols**:
  - `/Models/RuleProtocols.swift`
  - `/Models/FileProtocols.swift`
- **Production Models**:
  - `/Models/Rule.swift`
  - `/Models/FileItem.swift`
- **RuleEngine**: `/Services/RuleEngine.swift`
- **Test Models**: `/Tests/TestModels.swift`
- **Tests**: `/Tests/RuleEngineTests.swift`

## Advanced Rule Features

### Rule Priority Ordering (`sortOrder`)

Rules now have a `sortOrder` property that determines evaluation order. Lower values are evaluated first (higher priority).

**How it works:**
- `sortOrder: 0` = highest priority, evaluated first
- `sortOrder: 1` = evaluated second
- Rules with the same `sortOrder` use `creationDate` as a tiebreaker

**Fetching by priority:**
```swift
let ruleService = RuleService(modelContext: context)
let prioritizedRules = try ruleService.fetchRulesByPriority()
// Returns rules sorted by sortOrder (ascending), then creationDate (ascending)
```

**Updating priorities (e.g., after drag-to-reorder):**
```swift
try ruleService.updateRulePriorities(reorderedRules)
// Automatically assigns sortOrder 0, 1, 2... based on array position
```

### Exclusion Conditions

Rules can now have exclusion conditions that act as a "veto" mechanism. If a file matches any exclusion condition, the rule does not apply, even if primary conditions match.

**Use case:** "Move all PDFs to Documents, **except** temp files and drafts"

```swift
let rule = Rule(
    name: "PDF Organizer",
    conditions: [.fileExtension("pdf")],
    logicalOperator: .single,
    destination: .folder(bookmark: bookmarkData, displayName: "Documents"),
    exclusionConditions: [
        .nameContains("temp"),
        .nameContains("draft")
    ]
)
```

**Evaluation logic:**
1. Check if primary conditions match → if no, skip rule
2. Check exclusion conditions → if ANY exclusion matches, skip rule
3. Otherwise, rule matches

### NOT Operator

The `RuleCondition` enum now supports negation:

```swift
// Match files that are NOT PDFs
let notPdf = RuleCondition.not(.fileExtension("pdf"))

// Combined with AND: Match images that are NOT screenshots
let conditions = [
    .fileKind("image"),
    .not(.nameContains("Screenshot"))
]
let rule = Rule(conditions: conditions, logicalOperator: .and, ...)
```

**Testing the NOT operator:**
```swift
let rule = TestRule(
    conditions: [.not(.fileExtension("pdf"))],
    logicalOperator: .single,
    destination: .mockFolder("Others")
)

// doc.txt matches (NOT pdf)
// report.pdf does NOT match (IS pdf)
```

## Future Enhancements

This architecture enables:
- Mock implementations for integration tests
- Alternative storage backends
- Cached/temporary file representations
- Performance optimizations (e.g., value types where appropriate)
- **UI for rule priority reordering** (drag-and-drop in rules list)
- **UI for exclusion conditions** (add exceptions to rules)
- **NOT condition UI** (negate any condition type)

## Summary

The protocol-based architecture solves SwiftData testing complexity while maintaining type safety and flexibility. Production code remains unchanged, while tests become simpler, faster, and more maintainable.

---

## See Also

- [System Architecture](ARCHITECTURE.md) - Overall system design
- [Automation Architecture](Automation-Architecture.md) - Automation engine integration
- [RuleCondition Type Safety](RuleCondition-TypeSafety-Improvements.md) - Type-safe conditions
- [Compound Rule Conditions](../Features/CompoundRuleConditions.md) - Complex condition logic
- [Personality System](../Features/PersonalitySystem.md) - Rule recommendations from personality
- [Organization Templates](../Features/OrganizationTemplates.md) - Template-generated rules
- [Documentation Index](../INDEX.md) - Master navigation
