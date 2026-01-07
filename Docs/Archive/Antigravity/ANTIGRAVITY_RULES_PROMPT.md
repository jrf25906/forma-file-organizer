# Forma - User-Specific Rules Implementation Prompt

**For:** Google Antigravity with Gemini 3 Pro
**Task:** Implement custom rule builder functionality
**Date:** January 18, 2025

---

## Context & Current State

You are implementing the **user-specific rules builder** feature for **Forma**, a macOS file organization app built with SwiftUI. This is the next critical feature after completing the MVP with hardcoded rules.

### What Already Exists

**Core Functionality (Working):**
- ✅ Desktop scanning with security-scoped bookmarks
- ✅ File matching against rules
- ✅ File moving with permission management
- ✅ Review interface (list and card views)
- ✅ State management with MVVM architecture
- ✅ Three hardcoded rules (Screenshots, PDFs, ZIPs)

**Documentation (Reference These):**
- `Docs/API-Reference/USER_RULES_GUIDE.md` - Complete rule system specification
- `Docs/Architecture/ARCHITECTURE.md` - System architecture and component relationships
- `Docs/API-Reference/API_REFERENCE.md` - Service and ViewModel APIs
- `Docs/Design/Forma-Brand-Guidelines.md` - Visual language and brand system
- `Docs/Getting-Started/SETUP.md` - Technical setup and permissions

**Current Architecture:**
```
Services/
  ├── FileSystemService.swift      (Desktop scanning)
  ├── RuleEngine.swift              (Rule matching - needs extension)
  └── FileOperationsService.swift  (File moves)

ViewModels/
  └── ReviewViewModel.swift        (State management)

Views/
  └── ReviewView.swift             (File review UI)

Models/
  └── FileItem.swift               (Data models)
```

**Current Rule Model (In RuleEngine.swift):**
```swift
struct Rule {
    let name: String
    let condition: (FileItem) -> Bool
    let destination: URL
}
```

---

## Your Task: Implement Custom Rule Builder

Build a complete user-facing rule creation and management system that allows users to create, edit, delete, and reorder organizational rules without coding.

---

## Feature Requirements

### 1. Data Model Enhancement

**Extend the Rule model to support user-defined rules:**

```swift
// NEW persistent rule model
struct CustomRule: Codable, Identifiable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var conditionType: ConditionType
    var conditionValue: String
    var destinationPath: String
    var order: Int  // For rule priority
    var createdDate: Date
    var lastModifiedDate: Date
}

enum ConditionType: String, Codable, CaseIterable {
    case fileExtension = "File extension is"
    case nameStartsWith = "Name starts with"
    case nameContains = "Name contains"
    case nameEndsWith = "Name ends with"
    // Future: dateCreated, fileSize, etc.
}
```

**Requirements:**
- Use SwiftData for persistence (modern, native to SwiftUI)
- Store rules in user's Library/Application Support directory
- Support import/export for backup/sharing

### 2. Rule Management Service

**Create `RuleManagerService.swift`:**

```swift
@Observable
class RuleManagerService {
    // CRUD operations
    func createRule(_ rule: CustomRule) async throws
    func updateRule(_ rule: CustomRule) async throws
    func deleteRule(id: UUID) async throws
    func reorderRules(_ rules: [CustomRule]) async throws

    // Queries
    func getAllRules() async -> [CustomRule]
    func getEnabledRules() async -> [CustomRule]
    func getRuleById(_ id: UUID) async -> CustomRule?

    // Validation
    func validateRule(_ rule: CustomRule) -> ValidationResult
    func testRule(_ rule: CustomRule, against files: [FileItem]) -> [FileItem]

    // Import/Export
    func exportRules() async throws -> Data
    func importRules(_ data: Data) async throws
}
```

**Integration with RuleEngine:**
- Modify `RuleEngine.swift` to load custom rules from RuleManagerService
- Evaluate custom rules AFTER built-in rules (built-in rules have priority)
- Support rule priority ordering (higher priority = evaluated first)

### 3. User Interface - Rule Builder

**Create new Views directory structure:**
```
Views/
  ├── ReviewView.swift              (existing)
  └── Rules/
      ├── RuleListView.swift        (main rules management screen)
      ├── RuleEditorView.swift      (create/edit rule form)
      ├── RuleTesterView.swift      (test rule against files)
      └── Components/
          ├── RuleRowView.swift     (individual rule in list)
          └── ConditionBuilderView.swift (condition type selector)
```

#### A. Rule List View (Main Screen)

**Purpose:** Manage all organizational rules

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│  Rules                                    [+ New Rule]  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Built-in Rules                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  📸 Screenshots                           [✓]     │ │
│  │  Name starts with "Screenshot" → Pictures/...     │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  Custom Rules                              [Reorder]   │
│  ┌───────────────────────────────────────────────────┐ │
│  │  📄 Invoices                    [✓]  [Edit] [×]   │ │
│  │  Name contains "Invoice" → Documents/Financial    │ │
│  └───────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────┐ │
│  │  🎨 Design Files                [ ]  [Edit] [×]   │ │
│  │  File extension is .psd → Creative/Working        │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  [Import Rules]  [Export Rules]                        │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- List all rules (built-in shown as disabled/non-editable)
- Toggle rules on/off with checkbox
- Drag to reorder custom rules
- Edit/delete actions per rule
- Import/export rules as JSON

#### B. Rule Editor View (Create/Edit)

**Purpose:** Create or modify a custom rule

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│  [← Back]              New Rule                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Rule Name                                              │
│  [Invoices & Receipts                              ]   │
│                                                         │
│  When a file:                                           │
│  [Name contains ▾] [Invoice                        ]   │
│                                                         │
│  Move it to:                                            │
│  [~/Documents/Financial/Invoices               ]       │
│  [📂 Browse Folders]                                    │
│                                                         │
│  ──────────────────────────────────────────────────     │
│  Preview                                                │
│  This rule will match 3 files currently on Desktop     │
│  • Invoice_BestBuy_2025.pdf                            │
│  • Receipt_Invoice_Jan.pdf                             │
│  • Company_Invoice_Final.pdf                           │
│                                                         │
│  [Test Against Desktop Files]                          │
│                                                         │
│              [Cancel]              [Save Rule]          │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- Rule name input (required)
- Condition type dropdown (fileExtension, nameStartsWith, nameContains, nameEndsWith)
- Condition value input (with validation)
- Destination path input with folder picker
- Live preview showing matching files from current Desktop scan
- Test button to see which files would match
- Validation with clear error messages

**Validation Rules:**
- Name: 1-50 characters, no special characters
- Condition value: Not empty, appropriate for condition type
- Destination: Valid path, user has permission (request if needed)

#### C. Rule Tester View (Optional but Recommended)

**Purpose:** Test a rule before saving

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│  Testing: "Invoices & Receipts"                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Condition: Name contains "Invoice"                     │
│  Destination: ~/Documents/Financial/Invoices           │
│                                                         │
│  ──────────────────────────────────────────────────     │
│  Matching Files (3)                                     │
│                                                         │
│  ✓ Invoice_BestBuy_2025.pdf                            │
│  ✓ Receipt_Invoice_Jan.pdf                             │
│  ✓ Company_Invoice_Final.pdf                           │
│                                                         │
│  Non-Matching Files (12)                               │
│  × Screenshot 2025-01-18.png  (doesn't match)          │
│  × project-files.zip  (doesn't match)                  │
│  [Show all...]                                          │
│                                                         │
│              [Back to Editor]              [Save]       │
└─────────────────────────────────────────────────────────┘
```

---

## Technical Specifications

### Data Persistence

**Use SwiftData (not UserDefaults):**

```swift
import SwiftData

@Model
final class CustomRule {
    @Attribute(.unique) var id: UUID
    var name: String
    var isEnabled: Bool
    var conditionType: String  // Stored as rawValue
    var conditionValue: String
    var destinationPath: String
    var order: Int
    var createdDate: Date
    var lastModifiedDate: Date

    init(name: String, conditionType: ConditionType,
         conditionValue: String, destinationPath: String) {
        self.id = UUID()
        self.name = name
        self.isEnabled = true
        self.conditionType = conditionType.rawValue
        self.conditionValue = conditionValue
        self.destinationPath = destinationPath
        self.order = 0
        self.createdDate = Date()
        self.lastModifiedDate = Date()
    }
}
```

**ModelContainer setup in App:**

```swift
@main
struct FormaApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: CustomRule.self)
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

### Rule Evaluation Logic

**Update RuleEngine.swift:**

```swift
class RuleEngine {
    private let ruleManager: RuleManagerService

    // Existing built-in rules
    private var builtInRules: [Rule] = [
        // Screenshots, PDFs, ZIPs
    ]

    func evaluateFile(_ file: FileItem) async -> URL? {
        // 1. Try built-in rules first (higher priority)
        for rule in builtInRules {
            if rule.condition(file) {
                return rule.destination
            }
        }

        // 2. Try custom rules (ordered by priority)
        let customRules = await ruleManager.getEnabledRules()
        for customRule in customRules.sorted(by: { $0.order < $1.order }) {
            if evaluateCustomRule(customRule, against: file) {
                return URL(fileURLWithPath: customRule.destinationPath)
            }
        }

        return nil
    }

    private func evaluateCustomRule(_ rule: CustomRule, against file: FileItem) -> Bool {
        guard let conditionType = ConditionType(rawValue: rule.conditionType) else {
            return false
        }

        switch conditionType {
        case .fileExtension:
            return file.url.pathExtension.lowercased() == rule.conditionValue.lowercased()
        case .nameStartsWith:
            return file.name.lowercased().hasPrefix(rule.conditionValue.lowercased())
        case .nameContains:
            return file.name.lowercased().contains(rule.conditionValue.lowercased())
        case .nameEndsWith:
            return file.name.lowercased().hasSuffix(rule.conditionValue.lowercased())
        }
    }
}
```

### Navigation Integration

**Add Rules menu item to ReviewView:**

```swift
// In ReviewView menu bar or toolbar
Button("Rules...") {
    // Show RuleListView as sheet or new window
    showingRulesSheet = true
}
.keyboardShortcut(",", modifiers: .command)  // ⌘,
```

---

## Brand Guidelines Compliance

### Visual Design

**Colors (from DesignSystem.swift):**
- Primary actions: Steel Blue (#5B7C99)
- Success states: Sage (#7A9D7E)
- Text: Obsidian (#1A1A1A) / Bone White (#FAFAF8)
- System colors for semantic states

**Typography:**
- SF Pro throughout
- Headers: 20-24pt Semibold
- Body: 13pt Regular
- Form labels: 11pt Regular
- Sentence case for all copy

**Spacing:**
- 8pt grid system
- Standard padding: 16px
- Section gaps: 24px
- Form field spacing: 12px

**UI Components:**
- Buttons: 2px corner radius (sharp, precise)
- Cards: 10px corner radius
- Input fields: 6px corner radius
- Subtle shadows: 0px 2px 8px at 5% black

### Copy & Voice

**Tone: Precise, Refined, Confident**

✅ **Good Examples:**
- "Create rule"
- "Name contains 'Invoice'"
- "3 files match this rule"
- "Rule saved"

❌ **Avoid:**
- "Create awesome rule!"
- "Wow, found some matching files!"
- "Rule saved successfully!" (no exclamation points)
- "Oops, something went wrong" (no casual language)

**Error Messages:**
- Clear, specific, actionable
- "Rule name cannot be empty"
- "Destination folder does not exist"
- "No files match this rule"

---

## User Experience Requirements

### Progressive Disclosure

**First-Time Experience:**
1. User clicks "+ New Rule"
2. Shows simple form with smart defaults
3. Condition type pre-selected to most common (nameContains)
4. Live preview updates as they type
5. Validates on blur, shows errors inline

**Advanced Features:**
- Hidden initially: Import/Export, Reorder
- Revealed when user has 3+ rules
- Tooltips for power user features

### Keyboard Shortcuts

**Essential:**
- `⌘,` - Open Rules settings
- `⌘N` - New rule (when in Rules view)
- `⌘S` - Save rule (when in editor)
- `Esc` - Cancel/close
- `Return` - Save (when in editor)

### Empty States

**No Custom Rules Yet:**
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                         📋                              │
│                                                         │
│                  No custom rules yet                    │
│                                                         │
│        Create your first rule to start organizing      │
│        files automatically based on your patterns      │
│                                                         │
│                    [Create Rule]                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Confirmation Dialogs

**Delete Rule:**
```
Delete "Invoices & Receipts"?

This rule will no longer organize files matching
"Name contains 'Invoice'". This cannot be undone.

[Cancel]  [Delete Rule]
```

**Import Rules (Conflicts):**
```
Import 5 rules?

2 rules have the same name as existing rules:
• "Screenshots" (built-in - will be skipped)
• "Invoices" (custom - will replace existing)

[Cancel]  [Import]
```

---

## Error Handling

### Validation Errors (Inline)

Show validation errors below the relevant field:

```
Rule Name
[                                              ]
⚠️ Rule name cannot be empty
```

### Runtime Errors (Alerts)

Use native alerts for serious errors:

```swift
.alert("Could Not Save Rule", isPresented: $showError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(errorMessage)
}
```

### Permission Errors

Integrate with existing FileOperationsService permission flow:
- Request destination folder access when saving rule
- Validate permission when testing rule
- Show clear error if permission denied

---

## Testing Requirements

### Unit Tests

**Create `RuleManagerServiceTests.swift`:**
- Test CRUD operations
- Test rule validation
- Test rule evaluation
- Test import/export

**Create `CustomRuleTests.swift`:**
- Test model encoding/decoding
- Test condition type matching
- Test rule ordering

### UI Tests

**Create `RuleBuilderUITests.swift`:**
- Test creating a rule
- Test editing a rule
- Test deleting a rule
- Test reordering rules
- Test rule validation feedback

### Integration Tests

**Test with ReviewViewModel:**
- Custom rules integrate with file matching
- Rules persist across app restarts
- Rule changes update UI immediately

---

## Implementation Phases

### Phase 1: Data Layer (Foundation)
1. Create CustomRule model with SwiftData
2. Implement RuleManagerService with CRUD operations
3. Add ModelContainer to app
4. Unit test data persistence

### Phase 2: Rule Evaluation (Logic)
1. Extend RuleEngine to load custom rules
2. Implement condition type evaluation
3. Add rule priority ordering
4. Test rule matching with custom rules

### Phase 3: UI - Rule List (Management)
1. Create RuleListView with built-in + custom rules
2. Implement toggle on/off
3. Add delete action
4. Add reorder capability
5. Style according to brand guidelines

### Phase 4: UI - Rule Editor (Creation)
1. Create RuleEditorView form
2. Implement condition type selector
3. Add destination folder picker
4. Add live preview of matching files
5. Implement validation
6. Style according to brand guidelines

### Phase 5: Integration (Connection)
1. Connect Rules menu to RuleListView
2. Integrate with ReviewViewModel
3. Test end-to-end workflow
4. Polish transitions and animations

### Phase 6: Advanced Features (Enhancement)
1. Add rule testing view
2. Implement import/export
3. Add keyboard shortcuts
4. Create empty states

---

## Success Criteria

**Functional:**
- ✅ User can create, edit, delete, and reorder rules
- ✅ Rules persist across app restarts
- ✅ Custom rules correctly match and organize files
- ✅ Validation prevents invalid rules
- ✅ UI updates immediately when rules change

**Brand Alignment:**
- ✅ Follows Forma visual language (colors, typography, spacing)
- ✅ Copy uses Precise, Refined, Confident voice
- ✅ Feels native to macOS
- ✅ Minimal, focused UI without clutter
- ✅ Professional and polished

**User Experience:**
- ✅ Creating a rule takes <2 minutes
- ✅ Live preview helps users understand rules
- ✅ Clear validation prevents errors
- ✅ Keyboard shortcuts for power users
- ✅ Empty states guide new users

---

## Deliverables

Please provide:

1. **Complete implementation** of all phases above
2. **Code files** organized according to existing structure
3. **Brief implementation notes** explaining key decisions
4. **Known limitations** or future enhancements identified
5. **Testing notes** - what was tested and what needs manual testing

---

## Reference Architecture

**Current File Structure:**
```
Forma File Organizing/
├── Services/
│   ├── FileSystemService.swift
│   ├── RuleEngine.swift
│   ├── FileOperationsService.swift
│   └── RuleManagerService.swift         ← NEW
│
├── ViewModels/
│   ├── ReviewViewModel.swift
│   └── RuleListViewModel.swift          ← NEW
│
├── Views/
│   ├── ReviewView.swift
│   └── Rules/                            ← NEW
│       ├── RuleListView.swift
│       ├── RuleEditorView.swift
│       ├── RuleTesterView.swift
│       └── Components/
│           ├── RuleRowView.swift
│           └── ConditionBuilderView.swift
│
├── Models/
│   ├── FileItem.swift
│   └── CustomRule.swift                  ← NEW (SwiftData model)
│
└── Resources/
    └── DesignSystem.swift
```

---

## Final Notes

**Philosophy:**
This feature is about **empowering users** to teach Forma their organizational patterns. The UI should feel like a conversation, not a configuration file. Every decision should maintain the Precise, Refined, Confident brand.

**Constraints:**
- macOS only (no iOS/iPadOS considerations)
- SwiftUI only (no UIKit/AppKit mixing)
- SwiftData for persistence (modern, native approach)
- Security-scoped bookmarks for folder access (existing pattern)

**Success Looks Like:**
A creative professional opens the Rules screen, creates a rule for their project files in 90 seconds, and watches their Desktop organize itself automatically. The UI feels like it was designed by Apple. The feature "just works" without friction.

**Begin when ready. Make Forma even better.**
