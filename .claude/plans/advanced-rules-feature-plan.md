# Advanced Rule Features Implementation Plan

## Executive Summary

This plan details the implementation of advanced rule features across three areas:
1. **Complex Conditions** - Content-based rules, richer combinations, UI polish
2. **Conditional Logic** - If-then-else branching, nested groups, rule chaining, exceptions
3. **Rule Management** - Priority ordering, drag-to-reorder, groups/categories, import/export, templates

The plan prioritizes features by user value and implementation complexity, building on existing patterns.

---

## Ambiguity Resolutions

Before detailing the plan, these architectural decisions resolve the ambiguities:

### Rule Priority: Explicit User-Controlled Order
**Decision**: Use explicit `sortOrder: Int` field rather than specificity-based priority.
**Rationale**:
- Users can understand "rule #1 runs before rule #2" intuitively
- Specificity-based ordering is complex to explain and debug
- Explicit ordering enables drag-to-reorder UI naturally
- Matches mental model of "first matching rule wins"

### Rule Chaining: Sequential Re-evaluation
**Decision**: Chained rules trigger a re-evaluation pass with the file's updated state.
**Rationale**:
- A file moved to folder X may match a rule that only applies to files in X
- Single-pass chaining would miss these context changes
- Re-evaluation is simpler to implement and test
- Performance is acceptable since chains are opt-in per-rule

### Content-Based Rules: Phased Approach
**Decision**: Implement in phases - start with extended file metadata before full content search.
**Phase 1**: Image EXIF, PDF page count, document word count (fast metadata reads)
**Phase 2**: Text file content search, PDF text extraction (requires more processing)
**Rationale**:
- Metadata is fast to read and doesn't require full file parsing
- Content search has performance/sandbox implications
- Phase 1 covers 80% of use cases (image camera, document length)

### Import/Export Format: JSON with Versioning
**Decision**: Use JSON with a schema version field for forward compatibility.
**Rationale**:
- JSON is human-readable and debuggable
- Version field allows migration logic for older exports
- Standard format - users can edit in text editors if needed
- Easy to share (paste, email, version control)

---

## Feature Area 1: Complex Conditions

### 1.1 Extended File Metadata Conditions (Phase 1)

#### Data Model Changes

**New RuleCondition cases in `Rule.swift`:**

```swift
enum RuleCondition: Codable, Equatable, Hashable {
    // ... existing cases ...

    // Extended metadata conditions
    case imageDimensions(minWidth: Int?, maxWidth: Int?, minHeight: Int?, maxHeight: Int?)
    case imageCamera(String)          // Camera make/model from EXIF
    case documentPageCount(min: Int?, max: Int?)
    case audioDuration(minSeconds: Int?, maxSeconds: Int?)
    case videoDuration(minSeconds: Int?, maxSeconds: Int?)
    case hasEmbeddedThumbnail(Bool)

    // Codable support requires adding these to ConditionTypeCode enum
}
```

**New ConditionType cases in `Rule.ConditionType`:**
```swift
enum ConditionType: String, Codable, CaseIterable {
    // ... existing cases ...
    case imageDimensions
    case imageCamera
    case documentPageCount
    case audioDuration
    case videoDuration
    case hasEmbeddedThumbnail
}
```

#### Engine Changes

**New method in `RuleEngine.swift`:**
```swift
private func matchesExtendedMetadata<F: Fileable>(file: F, condition: RuleCondition) -> Bool {
    // Lazy-load metadata only when needed for these conditions
    switch condition {
    case .imageDimensions(let minW, let maxW, let minH, let maxH):
        guard let dims = FileMetadataService.shared.getImageDimensions(path: file.path) else {
            return false
        }
        return (minW.map { dims.width >= $0 } ?? true) &&
               (maxW.map { dims.width <= $0 } ?? true) &&
               (minH.map { dims.height >= $0 } ?? true) &&
               (maxH.map { dims.height <= $0 } ?? true)
    // ... other cases
    }
}
```

**New service `FileMetadataService.swift`:**
- Provides lazy, cached access to extended file metadata
- Uses `CGImageSource` for image metadata (fast, no full decode)
- Uses `PDFDocument` for page count
- Caches results keyed by file path + modification date

#### Service Changes

None required for RuleService - the existing `createRule()`/`updateRule()` flow handles new condition types automatically through Codable.

#### UI Changes

**RuleEditorView.swift / InlineRuleBuilderView.swift:**
- Add new condition types to the picker
- Add specialized input fields:
  - Image dimensions: Min/max width/height number fields
  - Camera: Text field with autocomplete from recent EXIF values
  - Page count: Range picker (min/max)
  - Duration: Time picker or seconds input

**Condition hint text updates:**
```swift
case .imageDimensions: return "Width and height in pixels"
case .imageCamera: return "Camera make/model from photo EXIF"
case .documentPageCount: return "Number of pages in PDF/document"
```

#### Migration Strategy

- New enum cases are additive - existing rules continue to work
- Decoding unknown types falls back to `.fileExtension("")` (existing fallback logic)
- No database migration needed

#### Testing Approach

```swift
// In RuleEngineTests.swift
func testImageDimensionsCondition() {
    // Need to extend TestFileItem with metadata mock capability
    let file = TestFileItem(path: "/test.png")
    file.mockImageDimensions = (1920, 1080)

    let rule = TestRule(
        conditions: [.imageDimensions(minWidth: 1000, maxWidth: nil, minHeight: nil, maxHeight: nil)],
        logicalOperator: .and,
        destination: .mockFolder("Large Images")
    )

    let result = engine.evaluateFile(file, rules: [rule])
    XCTAssertEqual(result.destination?.displayName, "Large Images")
}
```

---

### 1.2 Content-Based Rules (Phase 2)

#### Data Model Changes

```swift
enum RuleCondition: Codable, Equatable, Hashable {
    // ... existing cases ...

    // Content search conditions (Phase 2)
    case textContains(String, caseSensitive: Bool)
    case pdfTextContains(String)
    case regexMatches(String)  // Regex pattern against text content
}
```

#### Engine Changes

**Content extraction service:**
```swift
class FileContentService {
    /// Extracts searchable text from a file (cached, lazy)
    func extractText(from path: String) async throws -> String?

    /// Checks if file content matches a pattern without full extraction
    func contentContains(_ pattern: String, in path: String, caseSensitive: Bool) async -> Bool
}
```

**Security considerations:**
- Requires security-scoped bookmark access to read file content
- Should run content extraction on background queue
- Consider size limits (skip files > 10MB for text search)

#### UI Changes

- Add "Contains text" condition type
- Add case-sensitivity toggle
- Add regex option with pattern validation
- Show warning about performance for large files

#### Migration Strategy

Same as 1.1 - additive enum cases, no migration needed.

---

### 1.3 Richer Condition Combinations

#### Data Model Changes

**Add NOT operator support:**

```swift
enum RuleCondition: Codable, Equatable, Hashable {
    // Wrap any condition in a NOT
    case not(RuleCondition)

    // ... existing cases ...
}
```

**Nested condition groups:**

```swift
enum RuleCondition: Codable, Equatable, Hashable {
    // Group of conditions with their own operator
    case group([RuleCondition], LogicalOperator)

    // ... existing cases ...
}
```

This enables expressions like:
- `(extension = pdf) AND NOT (name contains "draft")`
- `(extension = jpg OR extension = png) AND (size > 1MB)`

#### Engine Changes

```swift
private func matchesCondition<F: Fileable>(file: F, condition: RuleCondition) -> Bool {
    switch condition {
    case .not(let inner):
        return !matchesCondition(file: file, condition: inner)

    case .group(let conditions, let op):
        return matchesCompoundConditions(file: file, conditions: conditions, logicalOperator: op)

    // ... existing cases ...
    }
}
```

#### UI Changes

**Condition builder enhancements:**
- "Add exclusion" button that prefixes condition with NOT
- Visual grouping with indentation/borders
- Drag to reorder conditions within a rule
- Group conditions button (select multiple → wrap in group)

**Visual representation:**
```
When file matches ALL:
  ├─ extension is .pdf
  └─ NOT: name contains "draft"
     OR group:
       ├─ size > 1MB
       └─ older than 30 days
```

#### Migration Strategy

- Existing rules have no NOT/group conditions - they continue to work
- UI defaults to non-grouped mode unless user explicitly creates groups

---

## Feature Area 2: Conditional Logic

### 2.1 Exception Handling (NOT/Exclude Patterns)

This is the most practical conditional logic feature and should be implemented first.

#### Data Model Changes

**Add exclusion conditions to Rule:**

```swift
@Model
final class Rule: Ruleable {
    // ... existing properties ...

    /// Exclusion conditions - files matching these are excluded even if main conditions match
    var exclusionConditions: [RuleCondition] = []
}
```

**Update Ruleable protocol:**

```swift
protocol Ruleable {
    // ... existing properties ...

    /// Exclusion conditions - files matching these are excluded
    var exclusionConditions: [RuleCondition] { get }
}

// Default implementation for backward compatibility
extension Ruleable {
    var exclusionConditions: [RuleCondition] { [] }
}
```

#### Engine Changes

```swift
private func matches<F: Fileable, R: Ruleable>(file: F, rule: R) -> Bool {
    guard rule.isEnabled else { return false }

    // Check exclusions first (fail-fast)
    if !rule.exclusionConditions.isEmpty {
        let matchesExclusion = rule.exclusionConditions.contains { condition in
            matchesCondition(file: file, condition: condition)
        }
        if matchesExclusion {
            return false
        }
    }

    // Then check inclusion conditions
    if !rule.conditions.isEmpty {
        return matchesCompoundConditions(file: file, conditions: rule.conditions, logicalOperator: rule.logicalOperator)
    }

    return matchesCondition(file: file, conditionType: rule.conditionType, conditionValue: rule.conditionValue)
}
```

#### UI Changes

**Add "Exclude when..." section after "When file..." section:**

```swift
// New section in form state:
var exclusionConditions: [RuleCondition] = []
var showExclusions: Bool = false

// UI: Add toggle + exclusion builder
Toggle("Add exclusions", isOn: $formState.showExclusions)
if formState.showExclusions {
    VStack {
        Text("Exclude when...")
            .font(.system(size: 13, weight: .semibold))
        // Same condition builder UI as main conditions
        ForEach(formState.exclusionConditions) { ... }
        Button("Add Exclusion") { ... }
    }
}
```

#### Migration Strategy

- New field with empty default - existing rules work unchanged
- SwiftData handles the new property automatically

#### Testing Approach

```swift
func testExclusionConditions() {
    let file = TestFileItem(name: "draft_invoice.pdf", fileExtension: "pdf")

    var rule = TestRule(
        conditions: [.fileExtension("pdf")],
        logicalOperator: .and,
        destination: .mockFolder("PDFs")
    )
    rule.exclusionConditions = [.nameContains("draft")]

    let result = engine.evaluateFile(file, rules: [rule])
    XCTAssertNil(result.destination) // Excluded despite matching .pdf
}
```

---

### 2.2 If-Then-Else Rule Branching

#### Conceptual Design

Instead of complex branching within a single rule, implement as **conditional actions**:

```swift
enum RuleAction: Codable {
    case move(destination: Destination)
    case copy(destination: Destination)
    case delete
    case chain(toRuleId: UUID)  // Execute another rule on match
    case conditionalAction(ConditionalAction)
}

struct ConditionalAction: Codable {
    let condition: RuleCondition
    let ifTrue: RuleAction
    let ifFalse: RuleAction?
}
```

This allows:
- "Move PDFs to Documents, but if > 10MB, move to Archive instead"
- "Move images to Photos, unless they're screenshots, then move to Screenshots"

#### Data Model Changes

For simplicity, implement as **action modifiers** rather than full branching:

```swift
@Model
final class Rule: Ruleable {
    // ... existing properties ...

    /// Override destination based on additional conditions
    var conditionalDestinations: [ConditionalDestination] = []
}

struct ConditionalDestination: Codable {
    let condition: RuleCondition
    let destination: Destination
    let priority: Int  // Higher priority checked first
}
```

#### Engine Changes

```swift
func evaluateFile<F: Fileable, R: Ruleable>(_ fileItem: F, rules: [R]) -> F {
    // ... existing matching logic ...

    // After finding matching rule, check conditional destinations
    if !rule.conditionalDestinations.isEmpty {
        let sortedConditions = rule.conditionalDestinations.sorted { $0.priority > $1.priority }
        for conditional in sortedConditions {
            if matchesCondition(file: file, condition: conditional.condition) {
                file.destination = conditional.destination
                break
            }
        }
    }

    // ... rest of existing logic ...
}
```

#### UI Changes

Add "Advanced" section in rule editor:
- "Override destination when..."
- List of condition → destination pairs
- Each can have different destination
- Priority ordering within the list

---

### 2.3 Rule Chaining

#### Data Model Changes

```swift
@Model
final class Rule: Ruleable {
    // ... existing properties ...

    /// After this rule matches, also evaluate these rules on the file
    var chainedRuleIds: [UUID] = []

    /// Whether to stop chain if a chained rule doesn't match
    var chainStopsOnNoMatch: Bool = false
}
```

#### Engine Changes

```swift
/// Evaluates a file, following any rule chains
func evaluateFileWithChaining<F: Fileable, R: Ruleable>(_ file: F, rules: [R], maxChainDepth: Int = 5) -> F {
    var currentFile = file
    var visitedRuleIds: Set<UUID> = []
    var depth = 0

    while depth < maxChainDepth {
        let matchedRule = findMatchingRule(currentFile, rules: rules, excluding: visitedRuleIds)
        guard let rule = matchedRule else { break }

        visitedRuleIds.insert(rule.id)
        currentFile = applyRule(currentFile, rule: rule)

        // Check for chains
        if rule.chainedRuleIds.isEmpty { break }

        // Re-evaluate with updated file state
        depth += 1
    }

    return currentFile
}
```

#### UI Changes

- "Chain to rule..." picker after destination
- Shows list of other rules to chain to
- Visual indicator of chain relationships in rule list
- Warning if circular chain detected

---

## Feature Area 3: Rule Management

### 3.1 Rule Priority Ordering

#### Data Model Changes

```swift
@Model
final class Rule: Ruleable {
    // ... existing properties ...

    /// Explicit sort order for rule evaluation (lower = higher priority)
    var sortOrder: Int = 0
}
```

#### Service Changes

```swift
class RuleService {
    /// Fetches rules sorted by priority (sortOrder ascending)
    func fetchRulesByPriority() throws -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(
            sortBy: [SortDescriptor(\Rule.sortOrder), SortDescriptor(\Rule.creationDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Updates sort orders for a list of rules
    func updateRuleOrder(_ rules: [Rule]) throws {
        for (index, rule) in rules.enumerated() {
            rule.sortOrder = index
        }
        try modelContext.save()
        ruleChanges.send(.reordered)
    }
}
```

#### Migration Strategy

```swift
/// Migration to add sortOrder based on existing creationDate order
func migrateToSortOrder() throws {
    let rules = try fetchRules() // Already sorted by creationDate
    for (index, rule) in rules.enumerated() {
        rule.sortOrder = index
    }
    try modelContext.save()
}
```

#### UI Changes

**RulesManagementView:**
- Change `@Query` to sort by `sortOrder` instead of `creationDate`
- Add drag handles to `RuleManagementCard`
- Implement `onMove` handler

---

### 3.2 Drag-to-Reorder UI

#### UI Implementation

```swift
struct RulesManagementView: View {
    @Query(sort: \Rule.sortOrder) private var allRules: [Rule]
    @State private var draggedRule: Rule?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: FormaSpacing.standard) {
                ForEach(filteredRules) { rule in
                    RuleManagementCard(rule: rule, ...)
                        .draggable(rule) {
                            RuleDragPreview(rule: rule)
                        }
                        .dropDestination(for: Rule.self) { items, location in
                            handleDrop(items, onto: rule)
                        }
                }
            }
        }
    }

    private func handleDrop(_ items: [Rule], onto target: Rule) -> Bool {
        guard let draggedRule = items.first else { return false }

        var rules = filteredRules
        guard let fromIndex = rules.firstIndex(where: { $0.id == draggedRule.id }),
              let toIndex = rules.firstIndex(where: { $0.id == target.id }) else {
            return false
        }

        rules.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)

        do {
            try ruleService.updateRuleOrder(rules)
            return true
        } catch {
            return false
        }
    }
}
```

#### Accessibility

- VoiceOver: "Rule 3 of 10. Double-tap to edit. Use rotor to reorder."
- Keyboard: Arrow keys to move selected rule up/down

---

### 3.3 Rule Groups/Categories

#### Data Model Changes

**New RuleGroup model:**

```swift
@Model
final class RuleGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String  // Hex color for UI
    var sortOrder: Int
    var isExpanded: Bool = true

    init(name: String, color: String = "#6B7280") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.sortOrder = 0
    }
}
```

**Add group reference to Rule:**

```swift
@Model
final class Rule: Ruleable {
    // ... existing properties ...

    /// Optional group this rule belongs to
    var groupId: UUID?
}
```

#### UI Changes

**RulesManagementView with groups:**

```swift
var body: some View {
    ScrollView {
        // Ungrouped rules
        if !ungroupedRules.isEmpty {
            RuleGroupSection(title: "Ungrouped", rules: ungroupedRules)
        }

        // Grouped rules
        ForEach(groups) { group in
            RuleGroupSection(
                title: group.name,
                color: Color(hex: group.color),
                isExpanded: $group.isExpanded,
                rules: rulesForGroup(group)
            )
        }
    }
}
```

**Group management UI:**
- "New Group" button
- Drag rules between groups
- Group color picker
- Collapse/expand groups
- Rename/delete groups

---

### 3.4 Import/Export Rule Sets

#### Data Format

```json
{
    "version": "1.0",
    "exportedAt": "2024-01-15T10:30:00Z",
    "exportedFrom": "Forma 1.2.0",
    "groups": [
        {
            "id": "uuid",
            "name": "Cleanup Rules",
            "color": "#10B981"
        }
    ],
    "rules": [
        {
            "id": "uuid",
            "name": "Screenshot Sweeper",
            "conditions": [
                {"type": "nameStartsWith", "stringValue": "Screenshot"}
            ],
            "logicalOperator": "single",
            "actionType": "move",
            "destinationPath": "Pictures/Screenshots",
            "isEnabled": true,
            "groupId": "uuid",
            "sortOrder": 0
        }
    ]
}
```

**Note**: `destinationPath` is exported instead of bookmark data. On import, user must re-select folders to create new bookmarks.

#### Service Changes

```swift
class RuleImportExportService {
    struct ExportedRuleSet: Codable {
        let version: String
        let exportedAt: Date
        let exportedFrom: String
        let groups: [ExportedGroup]
        let rules: [ExportedRule]
    }

    /// Exports selected rules to JSON
    func exportRules(_ rules: [Rule], groups: [RuleGroup]) throws -> Data {
        let exported = ExportedRuleSet(
            version: "1.0",
            exportedAt: Date(),
            exportedFrom: Bundle.main.appVersion,
            groups: groups.map(ExportedGroup.init),
            rules: rules.map(ExportedRule.init)
        )
        return try JSONEncoder().encode(exported)
    }

    /// Imports rules from JSON, returns rules needing folder selection
    func importRules(from data: Data) throws -> ImportResult {
        let decoded = try JSONDecoder().decode(ExportedRuleSet.self, from: data)

        // Version migration if needed
        let migrated = migrateIfNeeded(decoded)

        // Create rules (destinations will be nil until user selects folders)
        var needsFolderSelection: [ImportedRule] = []
        for exportedRule in migrated.rules {
            if exportedRule.actionType != .delete && exportedRule.destinationPath != nil {
                needsFolderSelection.append(exportedRule)
            }
        }

        return ImportResult(rules: migrated.rules, needsFolderSelection: needsFolderSelection)
    }
}
```

#### UI Changes

**Export flow:**
1. Select rules to export (or "Export All")
2. Choose save location
3. Save JSON file

**Import flow:**
1. Open file picker for JSON
2. Show preview of rules to import
3. For each rule needing destination, show folder picker
4. Confirm import
5. Show success with count

---

### 3.5 Rule Templates Library

#### Data Model

**Template storage:**
- Ship built-in templates as bundled JSON files
- User-created templates stored in app support directory
- Templates are essentially exported rule sets with metadata

```swift
struct RuleTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: TemplateCategory
    let icon: String
    let rules: [ExportedRule]
    let isBuiltIn: Bool

    enum TemplateCategory: String, Codable {
        case cleanup, creative, developer, documents, productivity
    }
}
```

#### Service Changes

```swift
class TemplateService {
    /// All available templates (built-in + user-created)
    func availableTemplates() -> [RuleTemplate]

    /// Applies a template (creates rules, prompts for folder selection)
    func applyTemplate(_ template: RuleTemplate) async throws -> ApplyResult

    /// Saves current rules as a user template
    func saveAsTemplate(rules: [Rule], name: String, description: String) throws -> RuleTemplate
}
```

#### UI Changes

**New TemplateLibraryView:**
- Grid of template cards
- Category filtering
- Search
- Preview before applying
- "Save Current Rules as Template" button

**Template card:**
```swift
struct TemplateCard: View {
    let template: RuleTemplate

    var body: some View {
        VStack {
            Image(systemName: template.icon)
            Text(template.name)
            Text("\(template.rules.count) rules")
            Text(template.description)
        }
    }
}
```

---

## Implementation Order

Based on dependencies and user value, the recommended implementation order is:

### Phase 1: Foundation (Weeks 1-2)
1. **Rule Priority Ordering** (3.1) - Required for predictable behavior
2. **Drag-to-Reorder UI** (3.2) - Natural companion to ordering
3. **Exception Handling** (2.1) - High user value, builds on existing conditions

### Phase 2: Enhanced Conditions (Weeks 3-4)
4. **Extended File Metadata** (1.1) - Practical new matching capabilities
5. **NOT Operator** (1.3 partial) - Simple addition, high value
6. **Rule Groups/Categories** (3.3) - Organizational improvement

### Phase 3: Advanced Features (Weeks 5-6)
7. **Import/Export** (3.4) - Enables sharing and backup
8. **Templates Library** (3.5) - Builds on import/export
9. **Conditional Destinations** (2.2) - Power-user feature

### Phase 4: Future (Backlog)
10. **Content-Based Rules** (1.2) - Complex, sandbox considerations
11. **Rule Chaining** (2.3) - Edge case, complex testing
12. **Nested Condition Groups** (1.3 full) - Power-user, complex UI

---

## Testing Strategy

### Unit Tests (RuleEngineTests.swift)

Each new feature needs tests following existing patterns:

```swift
// Example: Exception conditions
func testExclusionBlocksMatch() {
    let file = TestFileItem(name: "draft.pdf", fileExtension: "pdf")
    var rule = TestRule(conditions: [.fileExtension("pdf")], ...)
    rule.exclusionConditions = [.nameStartsWith("draft")]

    let result = engine.evaluateFile(file, rules: [rule])
    XCTAssertNil(result.destination)
}

func testExclusionDoesNotBlockNonMatch() {
    let file = TestFileItem(name: "final.pdf", fileExtension: "pdf")
    var rule = TestRule(conditions: [.fileExtension("pdf")], ...)
    rule.exclusionConditions = [.nameStartsWith("draft")]

    let result = engine.evaluateFile(file, rules: [rule])
    XCTAssertNotNil(result.destination)
}
```

### Integration Tests

- Import/export round-trip
- Template apply with folder selection
- Drag-reorder persistence
- Group membership changes

### UI Tests

- Drag-to-reorder gesture
- Group collapse/expand
- Import flow with folder picker
- Template selection and preview

---

## Potential User Contributions

When implementing, these are good opportunities for learning-mode code contributions:

1. **Confidence scoring logic** (calculateConfidenceScore) - How should extended metadata conditions affect confidence?

2. **Template category logic** - What categories make sense? How to auto-categorize imported rules?

3. **Import conflict resolution** - When importing a rule with the same name, how to handle? (Skip, rename, replace)

4. **Rule validation** - What additional validations should prevent saving invalid rules?

---

## Summary

This plan provides a comprehensive roadmap for advanced rule features, organized by:
- **User value**: Exception handling and extended metadata first
- **Implementation complexity**: Build on existing patterns
- **Dependencies**: Priority ordering enables drag-to-reorder; import/export enables templates

The phased approach allows shipping valuable features incrementally while maintaining code quality and testability through the existing protocol-based architecture.
