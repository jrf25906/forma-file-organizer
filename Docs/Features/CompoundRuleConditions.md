# Compound Rule Conditions

## Overview
Users can now create rules with multiple conditions combined using AND/OR logic. This enables powerful, precise file organization like "move .dmg files that are older than 7 days."

## Features

### Single Condition Mode
Rules can be created with a single condition:
- One condition (e.g., file extension = "pdf")
- Internally represented as a one-element `conditions` array

### Compound Condition Mode
Rules can now have multiple conditions:
- **AND logic**: All conditions must match for the rule to trigger
- **OR logic**: At least one condition must match for the rule to trigger
- Support for 2+ conditions in a single rule

## Using the UI

### Creating a Compound Rule

1. Open the **Rules** settings
2. Click **+ New Rule**
3. Enter a rule name (e.g., "Old DMG Cleanup")
4. Toggle **"Multiple conditions"** switch in the "When" section
5. Select **"ALL conditions (AND)"** or **"ANY condition (OR)"** from the dropdown
6. Configure your conditions:
   - Condition 1: Set type and value (e.g., "File extension is" → "dmg")
   - Click **"+ Add Condition"** to add more
   - Condition 2: Set type and value (e.g., "Date older than (days)" → "7")
7. Set the **Action** (Move, Copy, or Delete)
8. If Move/Copy, specify the **Destination Folder**
9. Click **"Create Rule"**

### Editing Existing Rules
- Single-condition rules can be converted to compound by toggling "Multiple conditions"
- Compound rules can be edited to add/remove conditions or change AND/OR logic
- Rules display their logic in natural language in the rules list

### Examples

#### Example 1: Old Installer Cleanup
**Rule**: Remove old .dmg files  
**Conditions** (AND):
1. File extension is `dmg`
2. Date older than `7` days

**Action**: Delete

**Description**: "Delete files when extension is .dmg AND older than 7 days"

#### Example 2: Document Consolidation  
**Rule**: Organize all document files  
**Conditions** (OR):
1. File extension is `pdf`
2. File extension is `docx`
3. File extension is `txt`

**Action**: Move to `Documents/All Docs`

**Description**: "Move files when extension is .pdf OR extension is .docx OR extension is .txt"

#### Example 3: Complex Invoice Archival
**Rule**: Archive old invoices  
**Conditions** (AND):
1. Name contains `Invoice`
2. File extension is `pdf`
3. Date older than `30` days

**Action**: Move to `Documents/Financial/Archive`

**Description**: "Move files when name contains 'Invoice' AND extension is .pdf AND older than 30 days"

## Technical Implementation

### Architecture
- **RuleCondition**: Type-safe enum with associated values for each condition type
- **LogicalOperator**: Enum with `.and`, `.or`, `.single` (for single-condition rules)
- **Rule model**: Uses `conditions` array as the source of truth for all matching logic
- **RuleEngine**: Single evaluation path via `matchesCompoundConditions()` for all rules
- **Ruleable protocol**: Enables testing with lightweight test doubles (e.g., `TestRule`)

### Supported Condition Types
All condition types work in compound rules:
- File extension
- Name contains/starts with/ends with
- Date older than
- Size larger than
- Date modified older than
- Date accessed older than
- File kind (image, video, document, etc.)
- Source location (Downloads, Desktop, etc.)
- **NOT operator** (negates any condition)

### NOT Operator

The NOT operator allows you to negate any condition. This is useful for exclusion patterns like "match all files that are NOT PDFs."

```swift
// Single negated condition
let notPdf = RuleCondition.not(.fileExtension("pdf"))

// Combined with AND: Images that are NOT screenshots
let conditions = [
    .fileKind("image"),
    .not(.nameContains("Screenshot"))
]
```

**UI Support**: The NOT operator can be applied to any condition in the Rule Editor by toggling the "NOT" switch.

### Exclusion Conditions

Rules now support **exclusion conditions** - a separate set of conditions that act as a "veto". If a file matches the primary conditions BUT also matches any exclusion condition, the rule does not apply.

**Use case**: "Move all PDFs to Documents, except temp files and drafts"

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

**Evaluation order**:
1. Primary conditions checked first
2. If primary matches, exclusion conditions are checked
3. If ANY exclusion matches, rule does NOT apply
4. If no exclusions match, rule applies normally

### Rule Priority Ordering

Rules are now evaluated in **priority order** based on the `sortOrder` property:

- Lower `sortOrder` = higher priority (evaluated first)
- Equal `sortOrder` rules use `creationDate` as tiebreaker
- Users can reorder rules via drag-and-drop in the Rules Management view

```swift
// Fetch rules by priority for evaluation
let rules = try ruleService.fetchRulesByPriority()

// Update priorities after reordering
try ruleService.updateRulePriorities(reorderedRules)
```

### Testing
Comprehensive test coverage includes:
- AND logic with all/partial matches
- OR logic with all/one/none matches
- Multiple conditions (3+)
- Single-condition rules (using `conditions` array with one element)
- Exclusion condition evaluation

Tests use `TestRule` and `TestFileItem` lightweight test doubles to avoid SwiftData/MainActor complexity. See `RuleEngineTests.swift` for full test suite.

## UI Components

### Toggle Switch
The "Multiple conditions" toggle switches between single and compound mode. When enabled:
- The single condition picker is replaced with a compound conditions panel
- Conditions are numbered (1, 2, 3...)
- Each condition has its own type picker and value field
- Remove buttons appear when 2+ conditions exist

### AND/OR Picker
Users select whether ALL conditions must match (AND) or ANY condition must match (OR). This determines the logical operator used when evaluating the rule.

### Condition Management
- **Add Condition**: Click "+ Add Condition" to append a new condition
- **Remove Condition**: Click the red minus icon to remove a condition (requires 2+ conditions)
- **Reorder**: Currently not supported (conditions evaluated in order added)

## API Usage

### Creating Compound Rules Programmatically

```swift
// Example: .dmg AND older than 7 days
// RuleCondition is a type-safe enum with associated values
let conditions: [RuleCondition] = [
    .fileExtension("dmg"),
    .dateOlderThan(days: 7, extension: nil)
]

let rule = Rule(
    name: "Old DMG Cleanup",
    conditions: conditions,
    logicalOperator: .and,
    actionType: .delete
)

modelContext.insert(rule)
try modelContext.save()
```

### Evaluating Rules
The RuleEngine automatically detects compound rules and evaluates them correctly:

```swift
let engine = RuleEngine()
let result = engine.evaluateFile(fileItem, rules: rules)

if result.status == .ready {
    print("File matched: \(result.suggestedDestination ?? "delete")")
}
```

## Architecture Notes
- All rules use the `conditions` array as the sole source of truth
- Single-condition rules use `logicalOperator = .single` with a one-element conditions array
- No legacy compatibility code exists - the `conditions` array is the only matching path
- SwiftData handles schema persistence automatically
