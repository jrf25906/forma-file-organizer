# Advanced Rule Features Implementation Plan

## Executive Summary

This plan covers three feature areas for the Forma file organization app:
1. **Complex Conditions** - Content-based rules and richer condition combinations
2. **Conditional Logic** - Branching, nesting, chaining, and exceptions
3. **Rule Management** - Priority ordering, groups, import/export, templates

**Implementation Order (by priority):**
1. Rule Priority & Ordering (high user value, foundation for other features)
2. Exception Patterns / NOT conditions (fills gap in current logic)
3. Rule Groups/Categories (organizational UX improvement)
4. Import/Export (enables sharing, backup)
5. Content-Based Conditions (high value but high complexity)
6. Rule Chaining (enables advanced workflows)
7. If-Then-Else Branching (complex, lower priority)

---

## Part 1: Rule Priority & Ordering

### Current State
- Rules are fetched sorted by `creationDate` (forward order)
- First matching rule wins (`evaluateFile()` returns on first match)
- No explicit priority field exists
- Users cannot reorder rules

### Design Decision: Explicit Priority

**Recommendation:** Use explicit user-controlled priority (not implicit specificity-based).

**Rationale:**
- Predictable behavior - user controls which rule wins
- Simpler implementation than specificity calculation
- Matches user mental model of "first rule wins"
- Specificity scoring is error-prone (is extension+name more specific than size+date?)

### Data Model Changes

#### Rule.swift

```swift
// Add to Rule @Model class:

/// Priority order for rule evaluation (lower = higher priority)
/// Rules with lower priority values are evaluated first.
/// Default is 1000 to allow insertion before existing rules.
var priority: Int = 1000

/// Group this rule belongs to (for organizational UI)
var groupId: UUID?
```

**SwiftData Migration:** Priority defaults to 1000, so existing rules maintain relative order by creationDate within that priority level.

### Engine Changes

#### RuleEngine.swift

No changes needed to `evaluateFile()` - it already uses first-match-wins. The change is in how rules are passed to the engine.

**Alternative considered:** Add priority-aware sorting inside engine. Rejected because it couples engine to persistence concerns.

### Service Changes

#### RuleService.swift

```swift
// Replace current fetchRules() implementation:

func fetchRules() throws -> [Rule] {
    let descriptor = FetchDescriptor<Rule>(
        sortBy: [
            SortDescriptor(\.priority, order: .forward),  // Primary: priority
            SortDescriptor(\.creationDate, order: .forward)  // Secondary: creation date
        ]
    )
    return try modelContext.fetch(descriptor)
}

// Add priority management methods:

/// Moves a rule to a new priority position
/// - Parameters:
///   - rule: The rule to move
///   - newPriority: The target priority value
/// - Note: Other rules are NOT automatically renumbered. Use `normalizeRulePriorities()`
///         periodically to clean up gaps.
func setRulePriority(_ rule: Rule, to newPriority: Int) throws {
    rule.priority = newPriority
    try modelContext.save()
    ruleChanges.send(.updated(rule))
}

/// Reorders a rule relative to another rule
/// - Parameters:
///   - rule: The rule to move
///   - target: The rule to position before/after
///   - position: .before or .after
func moveRule(_ rule: Rule, relativeTo target: Rule, position: RelativePosition) throws {
    // Calculate new priority based on target and adjacent rules
    // ...
}

enum RelativePosition {
    case before
    case after
}

/// Normalizes priority values to remove gaps (e.g., after deletions)
/// Renumbers rules to 100, 200, 300... maintaining relative order.
func normalizeRulePriorities() throws {
    let rules = try fetchRules()
    for (index, rule) in rules.enumerated() {
        rule.priority = (index + 1) * 100
    }
    try modelContext.save()
}
```

### UI Changes

#### RulesManagementView.swift

```swift
// Change @Query to respect priority order:
@Query(sort: [SortDescriptor(\Rule.priority), SortDescriptor(\Rule.creationDate)])
private var allRules: [Rule]

// Add drag-to-reorder support:
// 1. Use List with .onMove() modifier
// 2. Or implement custom drag gesture with DragGesture

// Add priority badges or numbering in the UI
```

#### New Component: ReorderableRuleList.swift

```swift
/// A reorderable list of rules with drag-and-drop support
struct ReorderableRuleList: View {
    @Binding var rules: [Rule]
    let onReorder: (IndexSet, Int) -> Void
    let onEdit: (Rule) -> Void
    let onDelete: (Rule) -> Void
    let onToggle: (Rule) -> Void

    var body: some View {
        List {
            ForEach(rules) { rule in
                RuleManagementCard(rule: rule, ...)
            }
            .onMove(perform: handleMove)
        }
        .listStyle(.plain)
    }

    private func handleMove(from source: IndexSet, to destination: Int) {
        onReorder(source, destination)
    }
}
```

### Migration Strategy

1. Add `priority` field with default value 1000
2. Run one-time migration on app launch to assign sequential priorities based on current creationDate order
3. Existing rules keep their relative order

```swift
// In RuleService or AppDelegate:
func migrateRulePriorities() throws {
    let rules = try fetchRules() // Currently sorted by creationDate
    for (index, rule) in rules.enumerated() {
        if rule.priority == 1000 { // Only migrate unmigrated rules
            rule.priority = (index + 1) * 100
        }
    }
    try modelContext.save()
}
```

### Testing Approach

#### RuleEngineTests.swift additions:

```swift
func testRulesEvaluatedInPriorityOrder() {
    // Two rules that both match the same file
    let highPriorityRule = TestRule(conditionType: .fileExtension, conditionValue: "pdf",
                                      destination: .mockFolder("HighPriority"))
    let lowPriorityRule = TestRule(conditionType: .fileExtension, conditionValue: "pdf",
                                     destination: .mockFolder("LowPriority"))

    // Pass rules in priority order (engine assumes pre-sorted)
    let file = TestFileItem(name: "doc.pdf", fileExtension: "pdf", path: "/doc.pdf")
    let result = ruleEngine.evaluateFile(file, rules: [highPriorityRule, lowPriorityRule])

    XCTAssertEqual(result.destination?.displayName, "HighPriority")
}
```

---

## Part 2: Exception Patterns (NOT Conditions)

### Current State
- LearnedPattern already has `isNegativePattern` concept for suppressing suggestions
- No way to express "NOT" in RuleCondition
- Users cannot exclude files matching certain patterns

### Design Decision: Exclusion Conditions vs. Exception Rules

**Option A: Add `.not()` wrapper to RuleCondition**
```swift
case not(RuleCondition)  // Inverts any condition
```

**Option B: Separate exclusion conditions array on Rule**
```swift
var exclusionConditions: [RuleCondition]  // Files matching these are excluded
```

**Recommendation:** Option B (separate array)

**Rationale:**
- Clearer mental model: "Match these conditions UNLESS these are true"
- Simpler UI: separate "Exclude when..." section
- No recursive enum complexity
- Matches LearnedPattern's existing negative pattern concept

### Data Model Changes

#### RuleCondition enum (Rule.swift)

No changes to RuleCondition itself.

#### Rule.swift

```swift
// Add to Rule @Model class:

/// Exclusion conditions - files matching ANY of these are excluded from the rule
/// Uses OR logic: if file matches any exclusion condition, rule does not apply.
var exclusionConditions: [RuleCondition] = []
```

### Engine Changes

#### RuleEngine.swift

```swift
private func matches<F: Fileable, R: Ruleable>(file: F, rule: R) -> Bool {
    guard rule.isEnabled else { return false }

    // NEW: Check exclusions first (fail-fast)
    if matchesAnyExclusion(file: file, rule: rule) {
        return false
    }

    // Existing compound/single condition logic
    if !rule.conditions.isEmpty {
        return matchesCompoundConditions(...)
    }
    return matchesCondition(...)
}

/// Check if file matches any exclusion condition
private func matchesAnyExclusion<F: Fileable, R: Ruleable>(file: F, rule: R) -> Bool {
    // Exclusions use OR logic - if ANY match, file is excluded
    return rule.exclusionConditions.contains { condition in
        matchesCondition(file: file, condition: condition)
    }
}
```

### Protocol Changes

#### RuleProtocols.swift

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

### UI Changes

#### InlineRuleBuilderView.swift / RuleEditorView.swift

Add "Exclude when..." section after the "When file..." section:

```swift
// New section in form state:
var exclusionConditions: [RuleCondition] = []

// UI: collapsible "Exclude when..." section
DisclosureGroup("Exclude when...") {
    ForEach(formState.exclusionConditions.indices, id: \.self) { index in
        exclusionConditionRow(condition: formState.exclusionConditions[index], index: index)
    }

    Button("Add exclusion") {
        // Add new exclusion condition
    }
}
```

### Testing Approach

```swift
func testExclusionConditionPreventsMatch() {
    // Rule: Match .pdf files, EXCEPT those containing "draft"
    var rule = TestRule(conditionType: .fileExtension, conditionValue: "pdf",
                        destination: .mockFolder("PDFs"))
    rule.exclusionConditions = [.nameContains("draft")]

    let normalPdf = TestFileItem(name: "report.pdf", fileExtension: "pdf", path: "/report.pdf")
    let draftPdf = TestFileItem(name: "draft_report.pdf", fileExtension: "pdf", path: "/draft.pdf")

    let normalResult = ruleEngine.evaluateFile(normalPdf, rules: [rule])
    XCTAssertEqual(normalResult.status, .ready) // Matches

    let draftResult = ruleEngine.evaluateFile(draftPdf, rules: [rule])
    XCTAssertEqual(draftResult.status, .pending) // Excluded
}
```

---

## Part 3: Rule Groups/Categories

### Current State
- Rules are displayed in a flat list
- No organizational structure
- Hard to manage many rules

### Data Model Changes

#### New Model: RuleGroup.swift

```swift
import SwiftData

/// A group/category for organizing rules
@Model
final class RuleGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String  // SF Symbol name
    var colorHex: String  // Hex color for group badge
    var sortOrder: Int  // For ordering groups in sidebar
    var isExpanded: Bool = true  // UI state - whether group is expanded in list

    init(name: String, icon: String = "folder", colorHex: String = "#4A90A4", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }
}
```

#### Rule.swift changes

```swift
// Already planned:
var groupId: UUID?  // nil = ungrouped

// Convenience computed property:
var isGrouped: Bool { groupId != nil }
```

### Service Changes

#### RuleService.swift

```swift
// Add group management methods:

func createGroup(_ group: RuleGroup) throws { ... }
func updateGroup(_ group: RuleGroup) throws { ... }
func deleteGroup(_ group: RuleGroup, deleteRules: Bool = false) throws { ... }
func fetchGroups() throws -> [RuleGroup] { ... }

func assignRuleToGroup(_ rule: Rule, group: RuleGroup?) throws {
    rule.groupId = group?.id
    try modelContext.save()
}

func fetchRulesInGroup(_ group: RuleGroup?) throws -> [Rule] {
    let groupId = group?.id
    let descriptor = FetchDescriptor<Rule>(
        predicate: #Predicate<Rule> { $0.groupId == groupId },
        sortBy: [SortDescriptor(\.priority)]
    )
    return try modelContext.fetch(descriptor)
}
```

### UI Changes

#### RulesManagementView.swift

Transform from flat list to grouped list:

```swift
// Option 1: Sidebar with groups + main list
// Option 2: Collapsible sections in list

// Grouped display structure:
struct GroupedRulesView: View {
    @Query private var groups: [RuleGroup]
    @Query private var rules: [Rule]

    var ungroupedRules: [Rule] {
        rules.filter { $0.groupId == nil }
    }

    func rulesInGroup(_ group: RuleGroup) -> [Rule] {
        rules.filter { $0.groupId == group.id }
    }

    var body: some View {
        List {
            // Ungrouped rules section
            if !ungroupedRules.isEmpty {
                Section("Ungrouped") {
                    ForEach(ungroupedRules) { rule in
                        RuleManagementCard(rule: rule, ...)
                    }
                }
            }

            // Grouped rules
            ForEach(groups) { group in
                Section(header: GroupHeaderView(group: group)) {
                    ForEach(rulesInGroup(group)) { rule in
                        RuleManagementCard(rule: rule, ...)
                    }
                }
            }
        }
    }
}
```

#### New Component: GroupEditorSheet.swift

```swift
/// Sheet for creating/editing rule groups
struct GroupEditorSheet: View {
    @State var name: String = ""
    @State var icon: String = "folder"
    @State var color: Color = .formaSteelBlue

    // Icon picker grid
    // Color picker
    // Save/Cancel buttons
}
```

### Testing Approach

```swift
// Test that groups don't affect rule evaluation (just organization)
func testRuleGroupingDoesNotAffectEvaluation() {
    let rule1 = TestRule(conditionType: .fileExtension, conditionValue: "pdf", ...)
    rule1.groupId = UUID() // Some group

    let rule2 = TestRule(conditionType: .fileExtension, conditionValue: "pdf", ...)
    rule2.groupId = nil // Ungrouped

    // Both should evaluate identically based on priority, not grouping
}
```

---

## Part 4: Import/Export Rule Sets

### Design Decision: Export Format

**Format:** JSON with schema version

**Rationale:**
- Human-readable and debuggable
- Standard format, wide tooling support
- Easy to version for backward compatibility
- Can include groups and rules together

### Data Model: Export Format

```swift
/// Represents an exportable rule set
struct RuleSetExport: Codable {
    let schemaVersion: Int = 1
    let exportDate: Date
    let appVersion: String
    let groups: [ExportedGroup]
    let rules: [ExportedRule]
}

struct ExportedGroup: Codable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
    let sortOrder: Int
}

struct ExportedRule: Codable {
    // Flattened representation (no SwiftData dependencies)
    let id: UUID
    let name: String
    let priority: Int
    let isEnabled: Bool
    let groupId: UUID?

    let conditionType: String  // Raw value
    let conditionValue: String
    let conditions: [ExportedCondition]
    let logicalOperator: String
    let exclusionConditions: [ExportedCondition]

    let actionType: String
    let destinationDisplayName: String?
    // NOTE: Do NOT export bookmark data - security-scoped bookmarks
    // are machine-specific and cannot be transferred
}

struct ExportedCondition: Codable {
    let type: String
    let value: String
    // Type-specific fields handled during encode/decode
}
```

### Service Changes

#### New Service: RuleExportService.swift

```swift
class RuleExportService {

    /// Exports rules (and optionally groups) to JSON data
    func exportRules(_ rules: [Rule], groups: [RuleGroup]? = nil) throws -> Data {
        let export = RuleSetExport(
            exportDate: Date(),
            appVersion: Bundle.main.appVersion,
            groups: groups?.map { $0.toExported() } ?? [],
            rules: rules.map { $0.toExported() }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    /// Imports rules from JSON data
    /// - Returns: Tuple of (imported rules count, imported groups count, warnings)
    func importRules(from data: Data, into context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(RuleSetExport.self, from: data)

        // Validate schema version
        guard export.schemaVersion == 1 else {
            throw ImportError.unsupportedSchemaVersion(export.schemaVersion)
        }

        var warnings: [String] = []

        // Import groups first (rules reference them)
        var groupIdMap: [UUID: UUID] = [:]  // old -> new
        for exportedGroup in export.groups {
            let group = RuleGroup(
                name: exportedGroup.name,
                icon: exportedGroup.icon,
                colorHex: exportedGroup.colorHex,
                sortOrder: exportedGroup.sortOrder
            )
            context.insert(group)
            groupIdMap[exportedGroup.id] = group.id
        }

        // Import rules
        for exportedRule in export.rules {
            let rule = try exportedRule.toRule()

            // Remap group ID
            if let oldGroupId = exportedRule.groupId,
               let newGroupId = groupIdMap[oldGroupId] {
                rule.groupId = newGroupId
            }

            // WARNING: Destination bookmark must be re-established by user
            if exportedRule.destinationDisplayName != nil && exportedRule.actionType != "delete" {
                warnings.append("Rule '\(rule.name)' needs destination folder re-selected")
                rule.destination = nil  // Clear until user picks folder
            }

            context.insert(rule)
        }

        try context.save()

        return ImportResult(
            rulesImported: export.rules.count,
            groupsImported: export.groups.count,
            warnings: warnings
        )
    }

    struct ImportResult {
        let rulesImported: Int
        let groupsImported: Int
        let warnings: [String]
    }

    enum ImportError: LocalizedError {
        case unsupportedSchemaVersion(Int)
        case invalidData(String)
    }
}
```

### UI Changes

#### RulesManagementView.swift

Add import/export buttons to toolbar:

```swift
.toolbar {
    ToolbarItem {
        Menu {
            Button("Export All Rules...") { exportRules() }
            Button("Export Selected Group...") { ... }
            Divider()
            Button("Import Rules...") { importRules() }
        } label: {
            Image(systemName: "square.and.arrow.up.on.square")
        }
    }
}

private func exportRules() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "forma-rules.json"
    // ...
}

private func importRules() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    // ...
}
```

#### New View: ImportWarningsSheet.swift

```swift
/// Shows warnings after import (e.g., destinations needing re-selection)
struct ImportWarningsSheet: View {
    let result: RuleExportService.ImportResult
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Import Complete")
            Text("\(result.rulesImported) rules, \(result.groupsImported) groups imported")

            if !result.warnings.isEmpty {
                Text("Some rules need attention:")
                ForEach(result.warnings, id: \.self) { warning in
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(warning)
                    }
                }
            }
        }
    }
}
```

### Security Consideration

**Important:** Security-scoped bookmarks MUST NOT be exported. They are:
- Machine-specific (won't work on another Mac)
- Security-sensitive (could provide unauthorized access)
- Tied to the specific app sandbox

Exported rules will have `destination: nil` until user re-selects the folder via picker.

---

## Part 5: Content-Based Conditions

### Design Decision: Supported Content Types

**Phase 1 (MVP):**
- Text file content search (txt, md, source code)
- File extended attributes (Finder comments, tags)

**Phase 2 (Future):**
- PDF text extraction
- Image EXIF metadata (date, camera, location)
- Document metadata (author, title)

### Data Model Changes

#### RuleCondition enum (Rule.swift)

```swift
// Add new condition types:
enum RuleCondition: Codable, Equatable, Hashable {
    // ... existing cases ...

    /// Matches if file content contains the specified text (for text files)
    /// Only works for text-based files under a size limit (default 1MB)
    case contentContains(String)

    /// Matches if file has a specific Finder tag
    case hasFinderTag(String)

    /// Matches if file has a specific extended attribute value
    case extendedAttribute(name: String, contains: String)

    // Phase 2:
    // case imageMetadata(key: String, value: String)
    // case pdfContains(String)
    // case documentAuthor(String)
}
```

#### Rule.ConditionType enum

```swift
enum ConditionType: String, Codable, CaseIterable {
    // ... existing cases ...
    case contentContains
    case hasFinderTag
    case extendedAttribute
}
```

### Engine Changes

#### RuleEngine.swift

```swift
private func matchesCondition<F: Fileable>(file: F, condition: RuleCondition) -> Bool {
    switch condition {
    // ... existing cases ...

    case .contentContains(let searchText):
        return matchesContentContains(file: file, searchText: searchText)

    case .hasFinderTag(let tag):
        return matchesFinderTag(file: file, tag: tag)

    case .extendedAttribute(let name, let contains):
        return matchesExtendedAttribute(file: file, attrName: name, contains: contains)
    }
}

/// Check if text file content contains search text
/// - Note: Only reads first 1MB of file for performance
private func matchesContentContains<F: Fileable>(file: F, searchText: String) -> Bool {
    let url = URL(fileURLWithPath: file.path)

    // Only check text-based files
    guard isTextBasedFile(extension: file.fileExtension) else { return false }

    // Size limit for performance (1MB)
    guard file.sizeInBytes < 1_000_000 else { return false }

    // Read content (requires security-scoped access in sandboxed app)
    // This is a performance concern - see optimization notes below
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }

    return content.localizedCaseInsensitiveContains(searchText)
}

private func isTextBasedFile(extension ext: String) -> Bool {
    let textExtensions = ["txt", "md", "swift", "py", "js", "ts", "json", "xml",
                          "html", "css", "yml", "yaml", "sh", "rb", "go", "rs"]
    return textExtensions.contains(ext.lowercased())
}

/// Check if file has a specific Finder tag
private func matchesFinderTag<F: Fileable>(file: F, tag: String) -> Bool {
    let url = URL(fileURLWithPath: file.path)

    do {
        let resourceValues = try url.resourceValues(forKeys: [.tagNamesKey])
        let tags = resourceValues.tagNames ?? []
        return tags.contains { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }
    } catch {
        return false
    }
}

/// Check extended attribute
private func matchesExtendedAttribute<F: Fileable>(file: F, attrName: String, contains: String) -> Bool {
    let url = URL(fileURLWithPath: file.path)

    // Use xattr to read extended attribute
    // This requires FileManager extension or direct xattr calls
    // ...
}
```

### Performance Optimization

Content-based conditions are expensive. Optimization strategies:

1. **Lazy evaluation:** Only check content conditions if simpler conditions pass
2. **Size limits:** Skip files over 1MB for content search
3. **Caching:** Cache content search results with file modification date
4. **Background evaluation:** Don't block UI during content scanning

```swift
// Optimized condition ordering in matchesCompoundConditions:
private func matchesCompoundConditions(...) -> Bool {
    // Sort conditions: cheap first, expensive last
    let sortedConditions = conditions.sorted { c1, c2 in
        conditionCost(c1) < conditionCost(c2)
    }

    switch logicalOperator {
    case .and:
        // Short-circuit on first failure
        return sortedConditions.allSatisfy { ... }
    // ...
    }
}

private func conditionCost(_ condition: RuleCondition) -> Int {
    switch condition {
    case .fileExtension, .nameContains, .nameStartsWith, .nameEndsWith:
        return 1  // Cheap - in-memory string ops
    case .dateOlderThan, .sizeLargerThan, .dateModifiedOlderThan, .dateAccessedOlderThan:
        return 2  // Cheap - metadata already loaded
    case .hasFinderTag, .extendedAttribute:
        return 3  // Medium - file system calls
    case .contentContains:
        return 10  // Expensive - file I/O
    default:
        return 5
    }
}
```

### Sandbox Considerations

Content reading requires file access:
- For scanned files (Desktop/Downloads), we already have access
- For arbitrary paths, need security-scoped bookmark
- Consider caching content hashes to avoid repeated reads

### Testing Approach

```swift
func testContentContainsCondition() {
    // Create temp file with known content
    let tempPath = createTempTextFile(content: "This is a test with keyword INVOICE inside")

    let rule = TestRule(conditionType: .contentContains, conditionValue: "invoice",
                        destination: .mockFolder("Invoices"))
    let file = TestFileItem(path: tempPath)

    let result = ruleEngine.evaluateFile(file, rules: [rule])

    XCTAssertEqual(result.status, .ready)

    // Cleanup
    try? FileManager.default.removeItem(atPath: tempPath)
}

func testFinderTagCondition() {
    // This test requires actual file system with tags set
    // May need to be an integration test, not unit test
}
```

---

## Part 6: Rule Chaining

### Design Decision: Chaining Model

**Option A: Explicit chain links (rule references another rule)**
```swift
var nextRuleId: UUID?  // If match, also evaluate this rule
```

**Option B: Tagged pipelines (rules belong to named pipelines)**
```swift
var pipelineTag: String?  // Rules with same tag form a pipeline
```

**Option C: Re-evaluation trigger (matched rule triggers full re-eval)**
```swift
var triggersReEvaluation: Bool  // After action, re-evaluate with all rules
```

**Recommendation:** Option C (re-evaluation trigger) for simplicity, with Option A as future enhancement.

**Rationale:**
- Simplest mental model: "After this rule acts, check other rules"
- Handles file transformations (e.g., unzip creates new files → evaluate new files)
- Avoids complex dependency graphs
- Option A can be added later for explicit chaining

### Data Model Changes

#### Rule.swift

```swift
// Add to Rule @Model class:

/// If true, after this rule's action completes, the file is re-evaluated against all rules
/// Useful for: unpacking archives (new files appear), transforming files (extension changes)
/// Default false to prevent infinite loops
var triggersReEvaluation: Bool = false

/// Maximum re-evaluation depth to prevent infinite loops
/// Only relevant when triggersReEvaluation is true
static let maxReEvaluationDepth = 3
```

### Engine Changes

The engine itself doesn't change - it evaluates a single pass. The re-evaluation happens at the orchestration layer.

#### FileOrganizationCoordinator changes

```swift
/// Execute a rule's action and optionally trigger re-evaluation
func executeRule(on file: FileItem, rule: Rule, depth: Int = 0) async throws {
    // Execute the action (move/copy/delete)
    try await executeAction(file: file, rule: rule)

    // Check for re-evaluation trigger
    if rule.triggersReEvaluation && depth < Rule.maxReEvaluationDepth {
        // Re-fetch file state (path may have changed)
        guard let updatedFile = try? await refreshFileState(file) else { return }

        // Re-evaluate against all rules
        let rules = try ruleService.fetchRules()
        let result = ruleEngine.evaluateFile(updatedFile, rules: rules)

        if result.status == .ready, let matchedRule = findMatchingRule(result, in: rules) {
            // Recursively execute (with incremented depth)
            try await executeRule(on: result, rule: matchedRule, depth: depth + 1)
        }
    }
}
```

### UI Changes

Add toggle in RuleEditorView:

```swift
// In advanced options section:
Toggle("Re-evaluate after action", isOn: $formState.triggersReEvaluation)
    .help("After this rule acts, the file will be re-evaluated against all other rules. " +
          "Useful for rules that transform files (e.g., unzipping archives).")
```

### Testing Approach

```swift
func testReEvaluationTrigger() {
    // Rule 1: Move .zip to /Archives, triggers re-eval
    // Rule 2: Move files in /Archives older than 7 days to /OldArchives

    // Simulate: .zip file moved to Archives, then (after mock time) to OldArchives
}

func testReEvaluationDepthLimit() {
    // Create circular rules that would loop infinitely
    // Verify max depth prevents infinite loop
}
```

---

## Part 7: If-Then-Else Branching (Future)

This is the most complex feature and should be deferred until the simpler features are stable.

### Concept

Allow rules to have conditional branches:
- IF condition A THEN action X
- ELSE IF condition B THEN action Y
- ELSE action Z

### Data Model (Sketch)

```swift
/// A rule with conditional branching
struct BranchingRule {
    let id: UUID
    let name: String

    /// The branches, evaluated in order
    let branches: [RuleBranch]

    /// Default action if no branch matches
    let defaultAction: RuleAction?
}

struct RuleBranch {
    let conditions: [RuleCondition]
    let logicalOperator: Rule.LogicalOperator
    let action: RuleAction
}

struct RuleAction {
    let type: Rule.ActionType
    let destination: Destination?
}
```

This would require significant engine changes and a new UI paradigm. Recommend deferring to v2.0.

---

## Implementation Order Summary

| Priority | Feature | Effort | Dependencies |
|----------|---------|--------|--------------|
| 1 | Rule Priority & Ordering | Medium | None |
| 2 | Exception Patterns (NOT) | Low | None |
| 3 | Rule Groups/Categories | Medium | Priority (for group-aware sorting) |
| 4 | Import/Export | Medium | Groups (to export together) |
| 5 | Content-Based Conditions | High | Performance optimization |
| 6 | Rule Chaining | Medium | Stable action execution |
| 7 | If-Then-Else Branching | High | All above |

### Sprint Suggestions

**Sprint 1: Foundation (2 weeks)**
- Rule priority field + migration
- Drag-to-reorder in UI
- Exception conditions

**Sprint 2: Organization (2 weeks)**
- Rule groups model + service
- Grouped list view
- Group editor UI

**Sprint 3: Portability (1 week)**
- Export/import service
- File dialogs
- Import warnings UI

**Sprint 4: Advanced Matching (2 weeks)**
- Content-based conditions
- Finder tags condition
- Performance optimization

**Sprint 5: Workflows (2 weeks)**
- Rule chaining/re-evaluation
- Testing edge cases

---

## Appendix: Protocol Updates for Testability

### TestRule (TestModels.swift) additions

```swift
struct TestRule: Ruleable {
    // ... existing properties ...

    // New properties for enhanced features:
    var priority: Int = 1000
    var groupId: UUID? = nil
    var exclusionConditions: [RuleCondition] = []
    var triggersReEvaluation: Bool = false
}
```

### TestFileItem additions (if needed for content testing)

```swift
final class TestFileItem: Fileable {
    // ... existing properties ...

    /// For testing content-based conditions without actual file I/O
    var mockContent: String? = nil

    /// For testing Finder tag conditions
    var mockTags: [String] = []
}
```

---

## Decisions Made

1. **Priority display:** Implied by list position (no visible numbers) ✓

2. **Group behavior:** When group is disabled, all rules in it are disabled. However, users can manually re-enable individual rules within a disabled group. ✓

3. **Import conflicts:** TBD - Feature may be deferred. Key concern: security-scoped bookmarks cannot be exported, requiring users to re-select all destination folders on import. Need to validate use case before investing.

4. **Content search scope:** Per-rule opt-in with safeguards ✓
   - 1MB file size limit (skip larger files silently)
   - Text files only initially (no binary/PDF)
   - Warning icon on rules with content conditions
   - Global "Content scanning" toggle in Settings as kill switch
   - Performance logging to detect slow rules

---

## Related Workstream: Feature Flags (Separate)

A separate workstream will implement user-controllable feature toggles for AI/ML features:

- **Master toggle**: "AI Features" ON/OFF
- **Individual toggles**: Pattern Learning, Rule Suggestions, Destination Prediction, Content Scanning, Context Detection
- **Default**: ON (opt-out model)
- **Location**: Settings → Smart Features

This pattern is documented in `AGENTS.md` and should be applied to all new AI/ML features.

**Note**: Content Scanning (Part 5 of this plan) should integrate with the Feature Flags system when implemented.
