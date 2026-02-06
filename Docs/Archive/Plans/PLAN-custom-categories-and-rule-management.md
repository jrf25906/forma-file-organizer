# Custom Categories & Rule Management

## Overview

This document outlines the plan for implementing custom rule categories and duplicate detection in Forma. Categories allow users to organize rules by context (e.g., Work, Personal) with optional folder scoping, so rules only apply to files from specific source locations.

---

## Feature 1: Custom Categories

### Concept

Categories are organizational containers for rules with an optional **scope**:

- **Global scope**: Rules apply to files from any location (default behavior)
- **Folder scope**: Rules only evaluate files originating from specified folders

This enables use cases like:
- "Work Rules" that only apply to files in `~/Work` or `~/Downloads/Work`
- "Personal Rules" that only apply to files in `~/Personal`
- Rules that never conflict because they watch different locations

### Data Model

```swift
// New SwiftData model
@Model
final class RuleCategory {
    @Attribute(.unique) var id: UUID
    var name: String                    // "Work", "Personal", etc.
    var colorHex: String                // For UI badge/tab coloring
    var iconName: String                // SF Symbol name
    var scope: CategoryScope            // Global or folder-scoped
    var isEnabled: Bool                 // Bulk enable/disable toggle
    var sortOrder: Int                  // Priority when scopes overlap
    var creationDate: Date
    var isDefault: Bool                 // True for "General" only

    // Inverse relationship
    @Relationship(deleteRule: .nullify, inverse: \Rule.category)
    var rules: [Rule] = []
}

// Scope definition (stored as Codable JSON in SwiftData)
enum CategoryScope: Codable, Equatable {
    case global
    case folders([Data])  // Security-scoped bookmarks
}
```

```swift
// Additions to existing Rule model
@Model
final class Rule {
    // ... existing properties ...

    // New: category relationship
    @Relationship var category: RuleCategory?
}
```

### Default Category

- A "General" category is created on first launch
- `isDefault = true`, `scope = .global`
- Cannot be deleted or renamed
- All existing rules migrate to "General" automatically

### Category-Rule Relationship

- **One category per rule** (not tags/multiple)
- Rules with `category == nil` are treated as belonging to "General"
- Deleting a category moves its rules to "General" (not deleted)

### Evaluation Logic Changes

When a file is scanned, the `RuleEngine` evaluation changes:

```
1. Determine file's source location (URL)

2. Find matching categories:
   - All categories where scope == .global
   - All categories where scope.folders contains the file's source

3. Collect enabled rules from matching categories

4. Sort rules by:
   - Category sortOrder (ascending, lower = higher priority)
   - Rule sortOrder within category (ascending)

5. First-match-wins (existing behavior)
```

**Edge case**: If a file's source matches multiple scoped categories, category `sortOrder` determines priority.

### UI Design

#### Rules View (Main Content)

Categories appear as a tab bar at the top of the rules list:

```
┌──────────────────────────────────────────────────────────┐
│ My Rules                                                 │
│                                                          │
│ ┌─────┬─────────┬───────────────────┐                   │
│ │ All │ General │ + New Category... │                   │
│ └─────┴─────────┴───────────────────┘                   │
│                                                          │
│ [+ New Rule]                      [⚙️ Manage Categories] │
│                                                          │
│ ┌──────────────────────────────────────────────────────┐│
│ │ ☑️ Screenshot Sweeper                        General ││
│ │    .png files from Desktop → Screenshots folder      ││
│ ├──────────────────────────────────────────────────────┤│
│ │ ☑️ PDF Parking                               General ││
│ │    .pdf files → Documents/PDFs                       ││
│ ├──────────────────────────────────────────────────────┤│
│ │ ☐ Old Downloads Cleanup                      General ││
│ │    Files older than 30 days → Trash                  ││
│ └──────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
```

#### Tab Behavior

| Tab | Shows |
|-----|-------|
| All | Every rule across all categories (flat view) |
| General | Only rules in the General category |
| [Custom] | Only rules in that category |
| + New Category... | Opens category creation flow |

#### Category Badge on Rules

Each rule row shows its category as a subtle badge (right-aligned or below the rule description).

#### Manage Categories Panel

Accessed via "Manage Categories" button. Allows:

- Reorder categories (drag & drop) — affects priority
- Edit category (name, color, icon, scope)
- Delete category (moves rules to General)
- Toggle category enabled/disabled

```
┌─────────────────────────────────────────────────────────┐
│ Manage Categories                                    ✕  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ≡ 🌐 General (default)                    12 rules     │
│     Scope: All locations                               │
│                                                         │
│ ≡ 💼 Work                          [Edit] [Delete]     │
│     Scope: ~/Work, ~/Downloads/Work        5 rules     │
│                                                         │
│ ≡ 🏠 Personal                      [Edit] [Delete]     │
│     Scope: ~/Personal                      3 rules     │
│                                                         │
│ [+ Add Category]                                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

#### New Category Flow

```
┌─────────────────────────────────────────────────────────┐
│ New Category                                         ✕  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Quick Start:                                            │
│ [💼 Work]  [🏠 Personal]  [📦 Archive]  [📸 Photos]    │
│                                                         │
│ ─────────────── or create your own ───────────────     │
│                                                         │
│ Name:  [________________________]                       │
│                                                         │
│ Icon:  [💼 ▼]     Color: [🔵 ▼]                        │
│                                                         │
│ Scope:                                                  │
│ ○ Global (rules apply to files from any location)      │
│ ● Specific folders:                                     │
│   ┌───────────────────────────────────────────────┐    │
│   │ 📁 ~/Work                              [✕]    │    │
│   │ 📁 ~/Downloads/Work                    [✕]    │    │
│   │ [+ Add Folder...]                             │    │
│   └───────────────────────────────────────────────┘    │
│                                                         │
│                              [Cancel]  [Create Category]│
└─────────────────────────────────────────────────────────┘
```

#### Rule Editor Changes

Add category picker to rule creation/editing:

```
Category: [General ▼]
          ├─ General
          ├─ Work
          ├─ Personal
          └─ + New Category...
```

### Migration Strategy

On app update:

1. Create "General" category with `isDefault = true`, `scope = .global`
2. Set all existing rules' `category` to General
3. No user action required — seamless upgrade

---

## Feature 2: Duplicate Rule Detection

### Concept

Warn users when creating or editing a rule that overlaps with existing rules. This prevents confusion when multiple rules could match the same files.

### Detection Types

| Type | Description | Severity |
|------|-------------|----------|
| **Exact duplicate** | Same conditions AND same destination | High |
| **Conflicting overlap** | Conditions match same files, different destinations | Medium |
| **Subset/superset** | One rule's conditions are broader/narrower than another | Low |

### Detection Algorithm

```swift
struct RuleOverlap {
    let existingRule: Rule
    let overlapType: OverlapType
    let explanation: String
}

enum OverlapType {
    case exactDuplicate
    case conflictingDestination
    case subset
    case superset
}

func detectOverlaps(newRule: Rule, existingRules: [Rule]) -> [RuleOverlap] {
    // 1. Filter to rules in same category (or global if categories overlap)
    // 2. Compare conditions for overlap
    // 3. Return list of overlapping rules with explanations
}
```

### Condition Overlap Logic

Two conditions overlap if they could match the same file:

| Condition A | Condition B | Overlaps? |
|-------------|-------------|-----------|
| `.pdf` extension | `.pdf` extension | Yes (exact) |
| `.pdf` extension | `name contains "invoice"` | Yes (partial) |
| `.pdf` extension | `.docx` extension | No |
| `size > 10MB` | `size > 5MB` | Yes (superset) |
| `older than 30 days` | `older than 7 days` | Yes (superset) |

For compound conditions (AND/OR), overlap detection gets more complex:
- AND conditions: overlap if ALL sub-conditions could overlap
- OR conditions: overlap if ANY sub-condition could overlap

### UI: Warning Dialog

Shown when user tries to save a rule with overlaps:

```
┌─────────────────────────────────────────────────────────┐
│ ⚠️ Similar Rule Detected                                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Your rule "Move Work PDFs" may overlap with:            │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📋 PDF Parking (General)                            │ │
│ │    Condition: .pdf files                            │ │
│ │    Destination: ~/Documents/PDFs                    │ │
│ │                                                     │ │
│ │    ⚡ Conflict: Both rules match .pdf files but     │ │
│ │    send them to different destinations.             │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ The higher-priority rule will take precedence.          │
│ Your rule is currently priority #3.                     │
│                                                         │
│               [Cancel]  [Edit Rule]  [Save Anyway]      │
└─────────────────────────────────────────────────────────┘
```

### Behavior

- **Warn but allow**: User can acknowledge and save anyway
- Detection runs on:
  - Rule creation (before save)
  - Rule editing (before save)
- Does NOT block — user has final say

---

## Implementation Phases

### Phase 1: Data Model & Migration
- [ ] Create `RuleCategory` SwiftData model
- [ ] Add `category` relationship to `Rule` model
- [ ] Implement `CategoryScope` enum with Codable support
- [ ] Write migration to create "General" and assign existing rules
- [ ] Add `CategoryService` for CRUD operations

### Phase 2: Category Management UI
- [ ] Build "Manage Categories" sheet/panel
- [ ] Implement category creation flow with quick-start presets
- [ ] Add folder picker for scoped categories
- [ ] Enable drag-to-reorder for priority
- [ ] Add delete with "move rules to General" behavior

### Phase 3: Rules View Integration
- [ ] Add category tab bar to `RulesManagementView`
- [ ] Implement tab filtering logic
- [ ] Add category badge to rule rows
- [ ] Add category picker to rule editor
- [ ] Support drag-drop rules between category tabs

### Phase 4: Scoped Evaluation
- [ ] Update `RuleEngine` to filter rules by category scope
- [ ] Implement source-location matching for folder scopes
- [ ] Add category priority to rule sorting
- [ ] Write tests for scoped evaluation edge cases

### Phase 5: Duplicate Detection
- [ ] Implement `RuleOverlapDetector` service
- [ ] Build condition overlap comparison logic
- [ ] Create warning dialog UI
- [ ] Integrate into rule editor save flow
- [ ] Add "View Conflicts" detail expansion

### Phase 6: Polish & Discoverability
- [ ] Add first-time hint when user has 5+ rules
- [ ] Implement bulk enable/disable for categories
- [ ] Add category to activity logging
- [ ] Write user-facing documentation/tooltips

---

## Edge Cases & Decisions

| Scenario | Decision |
|----------|----------|
| User deletes a category | Rules move to "General", not deleted |
| User tries to delete "General" | Blocked — General is permanent |
| File matches rules in multiple scoped categories | Category `sortOrder` determines which category's rules evaluate first |
| Rule has no category (legacy/nil) | Treated as "General" |
| User disables a category | All rules in category are skipped during evaluation |
| Two categories watch the same folder | Allowed — sortOrder determines priority |
| Duplicate detection for rules in different categories | Still detect if categories have overlapping scopes |

---

## Open Questions

1. **Category colors**: Use predefined palette or full color picker?
   - Recommendation: Predefined palette (8-10 colors) for consistency

2. **Category icons**: Full SF Symbol picker or curated list?
   - Recommendation: Curated list of ~20 relevant icons

3. **Max categories**: Should we limit the number of categories?
   - Recommendation: No hard limit, but UI may get crowded beyond 6-8

4. **Category in sidebar**: Should categories appear in sidebar as sub-items under "My Rules"?
   - Decision: No — keep sidebar clean, categories live in the Rules view

---

## Success Metrics

- Users create at least one custom category (adoption)
- Reduction in "why did this file go there?" support questions
- Users with 10+ rules use categories to organize
- Duplicate detection prevents accidental rule conflicts

