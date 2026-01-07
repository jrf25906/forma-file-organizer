# Organization Templates Feature

**Version:** 1.0
**Last Updated:** December 2025
**Status:** Production-Ready

Organization Templates provide proven, pre-configured organization methodologies that users can apply instantly. Each template comes with a complete folder structure and intelligent rules tailored to specific workflows and user personas.

---

## Table of Contents

1. [Overview](#overview)
2. [Available Templates](#available-templates)
3. [Template Structure](#template-structure)
4. [Implementation Details](#implementation-details)
5. [Usage Examples](#usage-examples)
6. [Template Selection Flow](#template-selection-flow)
7. [Customization](#customization)

---

## Overview

### What Are Organization Templates?

Organization Templates are expert-designed filing systems that users can apply with a single click. Each template includes:

- **Folder Structure**: Pre-defined folder hierarchy
- **Smart Rules**: Automated file organization rules
- **Target Persona**: Recommended user type
- **Description**: Clear explanation of the methodology

### Why Templates Matter

**User Benefits:**
- Instant organization without configuration
- Proven methodologies from productivity experts
- Educational component (users learn organization systems)
- Reduces decision fatigue and analysis paralysis

**Competitive Advantage:**
- No competitor offers this feature
- Unique differentiator in the market
- Instant value proposition
- Builds user expertise over time

---

## Available Templates

### 1. PARA Method

**Best for:** Knowledge workers, general productivity

**Description:** Organize by actionability: Projects, Areas, Resources, and Archive

**Icon:** `square.grid.2x2`

**Folder Structure:**
```
Documents/
├── Projects/          # Active projects with deadlines
├── Areas/             # Ongoing responsibilities
│   ├── Finance/
│   │   └── Taxes/
│   └── Health/
├── Resources/         # Reference materials
│   ├── Documents/
│   ├── Books/
│   └── Templates/
└── Archive/           # Inactive content
```

**Rules (10 total):**
1. **Active Projects** - Files with "project" → Projects/
2. **Finance Documents** - "invoice" → Areas/Finance/
3. **Health Records** - "health" → Areas/Health/
4. **Tax Documents** - "tax" → Areas/Finance/Taxes/
5. **PDF References** - .pdf → Resources/Documents/
6. **E-books** - .epub → Resources/Books/
7. **Templates** - "template" → Resources/Templates/
8. **Archive Old Documents** - Modified 180+ days ago → Archive/
9. **Archive Completed** - "completed" → Archive/
10. **Archive Final** - "final" → Archive/

**Methodology:**
- Based on Tiago Forte's PARA system
- Four-category approach based on actionability
- Projects: Active work with deadlines
- Areas: Ongoing responsibilities (health, finance, etc.)
- Resources: Reference materials and knowledge
- Archive: Inactive content (completed projects)

---

### 2. Johnny Decimal

**Best for:** Systematic filers who want structure

**Description:** Numeric categorization system with 10 main categories (10-19, 20-29, etc.)

**Icon:** `number.square`

**Folder Structure:**
```
Documents/
├── 10-19 Finance/
│   ├── 11 Invoices/
│   ├── 12 Receipts/
│   └── 13 Banking/
├── 20-29 Work/
│   ├── 21 Presentations/
│   ├── 22 Data/
│   └── 23 Reports/
├── 30-39 Personal/
│   ├── 31 Photos/
│   └── 32 Videos/
├── 40-49 Creative/
│   ├── 41 Design/
│   └── 42 Vectors/
└── 50-59 Reference/
    ├── 51 Docs/
    └── 52 Archives/
```

**Rules (13 total):**

**10-19 Finance:**
1. "invoice" → 10-19 Finance/11 Invoices/
2. "receipt" → 10-19 Finance/12 Receipts/
3. "statement" → 10-19 Finance/13 Banking/

**20-29 Work:**
4. .key files → 20-29 Work/21 Presentations/
5. .xlsx files → 20-29 Work/22 Data/
6. "report" → 20-29 Work/23 Reports/

**30-39 Personal:**
7. .jpg files → 30-39 Personal/31 Photos/
8. .mp4 files → 30-39 Personal/32 Videos/

**40-49 Creative:**
9. .psd files → 40-49 Creative/41 Design/
10. .svg files → 40-49 Creative/42 Vectors/

**50-59 Reference:**
11. .pdf files → 50-59 Reference/51 Docs/
12. .zip files → 50-59 Reference/52 Archives/

**Methodology:**
- Created by Johnny Noble
- 10 area categories (10-19, 20-29, etc.)
- Each area has 9 subcategories (11, 12, 13, etc.)
- Decimal system provides structure and scalability
- Easy to reference: "That's in 23" (Reports)

---

### 3. Creative Professional

**Best for:** Designers, photographers, video editors

**Description:** Client and project-based structure for creative work

**Icon:** `paintbrush.pointed`

**Folder Structure:**
```
Documents/
├── Clients/           # Client-specific files
├── Projects/
│   ├── Active/
│   │   ├── Raw Imports/
│   │   ├── Working Files/
│   │   ├── Design/
│   │   └── Video/
│   └── Delivered/
└── Archive/           # Old projects (1+ year)
```

**Rules (11 total):**

**Raw Assets:**
1. .cr2 files (Canon RAW) → Projects/Active/Raw Imports/
2. .nef files (Nikon RAW) → Projects/Active/Raw Imports/

**Design Files:**
3. .psd files → Projects/Active/Working Files/
4. .ai files → Projects/Active/Working Files/
5. "figma" → Projects/Active/Design/

**Delivered Work:**
6. "final" → Projects/Delivered/
7. "approved" → Projects/Delivered/

**Video Production:**
8. .prproj files → Projects/Active/Video/
9. .mov files → Projects/Delivered/

**Archive:**
10. Modified 365+ days ago → Archive/
11. "client" → Clients/

**Workflow:**
- Raw imports go to staging area
- Working files stay in Active projects
- Delivered work separated from WIP
- Automatic archival after 1 year

---

### 4. Minimal

**Best for:** Casual users, pilers, simplicity seekers

**Description:** Simple three-folder system: Inbox, Keep, and Archive

**Icon:** `square.stack.3d.up`

**Folder Structure:**
```
Documents/
├── Inbox/     # Temporary landing zone
├── Keep/      # Important files
└── Archive/   # Old/inactive files
```

**Rules (7 total):**

**Auto-Archive:**
1. Inbox items modified 90+ days ago → Archive/

**Auto-File to Keep:**
2. "important" → Keep/
3. "contract" → Keep/
4. "invoice" → Keep/

**Auto-Delete:**
5. Files starting with "temp" → Delete
6. .dmg files → Delete
7. Archive items 730+ days old → Delete

**Philosophy:**
- Everything lands in Inbox
- Users manually decide what to Keep
- Old items auto-archive
- Very old items auto-delete
- Minimal decision-making required

---

### 5. Academic & Research

**Best for:** Researchers, academics, PhD students

**Description:** Research-focused: Literature, Research, Writing, and References

**Icon:** `book.closed`

**Folder Structure:**
```
Documents/
├── Literature/
│   ├── Papers/
│   ├── Books/
│   └── Notes/
├── Research/
│   ├── Data/
│   └── Analysis/
├── Writing/
│   ├── Drafts/
│   ├── LaTeX/
│   └── Published/
└── References/        # Citation management
```

**Rules (14 total):**

**Literature:**
1. .pdf files → Literature/Papers/
2. .epub files → Literature/Books/
3. "notes" → Literature/Notes/

**Research Data:**
4. .csv files → Research/Data/
5. .xlsx files → Research/Data/
6. .py files (Python) → Research/Analysis/
7. .r files (R) → Research/Analysis/

**Writing:**
8. "draft" → Writing/Drafts/
9. .tex files (LaTeX) → Writing/LaTeX/
10. "published" → Writing/Published/

**References:**
11. .bib files → References/
12. .ris files → References/

**Workflow:**
- Literature review → Papers & Notes
- Data collection → Research/Data
- Analysis scripts → Research/Analysis
- Writing process → Drafts → LaTeX → Published
- Citation management via References folder

---

### 6. Chronological

**Best for:** Legal, accounting, compliance professionals

**Description:** Date-based organization by Year/Month or Year/Quarter

**Icon:** `calendar`

**Folder Structure:**
```
Documents/
├── 2025/
│   ├── Q1/
│   │   ├── Financial/
│   │   ├── Legal/
│   │   └── Reports/
│   ├── Q2/
│   ├── Q3/
│   ├── Q4/
│   └── Tax/
├── 2024/
└── Archive/          # 2+ years old
```

**Rules (7 total):**

**Current Year (2025):**
1. "invoice" → 2025/Q[current]/Financial/
2. "contract" → 2025/Q[current]/Legal/
3. "report" → 2025/Q[current]/Reports/
4. "tax" → 2025/Tax/

**Last Year:**
5. Files containing "2024" → 2024/

**Archive:**
6. Modified 730+ days ago (2+ years) → Archive/
7. "financial" → [Current Year]/Financial/ (7-year retention)

**Compliance Features:**
- Quarterly organization for easy audits
- Tax documents separated
- 7-year financial retention (compliance)
- 2+ year automatic archival

---

### 7. Student

**Best for:** High school and undergraduate students

**Description:** Class-based organization for assignments, projects, and study materials

**Icon:** `graduationcap`

**Folder Structure:**
```
Documents/
├── Classes/
│   ├── Current/
│   │   ├── Assignments/
│   │   ├── Labs/
│   │   └── Exams/
│   └── Completed/
├── Projects/
│   ├── Current/
│   └── Completed/
└── Resources/
    ├── Textbooks/
    └── Study Guides/
```

**Rules (14 total):**

**Class Materials:**
1. "lecture" → Classes/Current/
2. "syllabus" → Classes/Current/

**Assignments:**
3. "homework" → Classes/Current/Assignments/
4. "assignment" → Classes/Current/Assignments/
5. "lab" → Classes/Current/Labs/

**Exams:**
6. "study guide" → Classes/Current/Exams/
7. "practice" → Classes/Current/Exams/

**Projects:**
8. "group" → Projects/Current/
9. "final project" → Projects/Current/
10. "completed" → Projects/Completed/

**Resources:**
11. "textbook" → Resources/Textbooks/
12. "study" → Resources/Study Guides/

**Archive:**
13. Modified 120+ days ago (old semester) → Classes/Completed/

**Workflow:**
- Active semester in Current/
- Completed work archived
- Resources separate for multi-semester use
- 4-month auto-archive (end of semester)

---

### 8. Custom

**Best for:** Users with unique workflows

**Description:** Create your own organization system

**Icon:** `gearshape`

**Folder Structure:**
```
Documents/
└── Custom Structure/
```

**Rules:** None (user creates their own)

**Philosophy:**
- Full flexibility for power users
- Start from scratch
- Build rules incrementally
- Best for users who already know their system

---

## Template Structure

### Code Structure

**File:** `Models/OrganizationTemplate.swift`

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

    // Display Properties
    var displayName: String { /* ... */ }
    var description: String { /* ... */ }
    var iconName: String { /* ... */ }
    var targetPersona: String { /* ... */ }
    var folderStructure: [String] { /* ... */ }

    // Rule Generation
    func generateRules(baseDocumentsPath: String) -> [Rule]
}
```

**Extension File:** `Models/OrganizationTemplate+Rules.swift`

Contains private rule generation methods:
- `generatePARARules(basePath:)`
- `generateJohnnyDecimalRules(basePath:)`
- `generateCreativeProfRules(basePath:)`
- `generateMinimalRules(basePath:)`
- `generateAcademicRules(basePath:)`
- `generateChronologicalRules(basePath:)`
- `generateStudentRules(basePath:)`

---

## Implementation Details

### Rule Generation

**How It Works:**

1. User selects template during onboarding or in settings
2. `RuleService.seedTemplateRules()` is called
3. Template's `generateRules()` creates rule objects
4. Rules are inserted into SwiftData database
5. RuleEngine begins evaluating files against rules

**Rule Properties:**

Each rule specifies:
- **Name**: Human-readable identifier
- **Condition Type**: Extension, name pattern, date, etc.
- **Condition Value**: Matching criteria
- **Action Type**: Move or Delete
- **Destination Folder**: Where to move files

**Example Rule:**
```swift
Rule(
    name: "Finance Documents",
    conditionType: .nameContains,
    conditionValue: "invoice",
    actionType: .move,
    destinationFolder: "\(basePath)/Areas/Finance"
)
```

### RuleService Integration

**File:** `Services/RuleService.swift`

#### seedTemplateRules(template:clearExisting:)

Generates and saves rules based on a template.

```swift
func seedTemplateRules(
    template: OrganizationTemplate,
    clearExisting: Bool = true
) throws {
    // 1. Optionally clear existing rules
    if clearExisting {
        let existingRules = try fetchRules()
        for rule in existingRules {
            modelContext.delete(rule)
        }
    }

    // 2. Generate template rules
    let templateRules = template.generateRules()

    // 3. Insert into database
    for rule in templateRules {
        modelContext.insert(rule)
    }

    // 4. Save
    try modelContext.save()
}
```

#### addTemplateRules(template:)

Adds template rules without clearing existing ones:

```swift
func addTemplateRules(template: OrganizationTemplate) throws {
    try seedTemplateRules(template: template, clearExisting: false)
}
```

**Use Cases:**
- **clearExisting: true** - Full template switch, replace all rules
- **clearExisting: false** - Hybrid approach, combine templates

---

## Usage Examples

### Onboarding Flow

**During first-time setup:**

```swift
// User selects PARA template
let template = OrganizationTemplate.para

// Seed rules
let ruleService = RuleService(context: modelContext)
try ruleService.seedTemplateRules(template: template)

// Store selection
@AppStorage("selectedTemplate") var selectedTemplate: String = template.rawValue

// Begin scanning with new rules
let fileSystemService = FileSystemService(context: modelContext)
try fileSystemService.scanFolder(folderURL)
```

### Switching Templates

**In Settings:**

```swift
Button("Switch to Johnny Decimal") {
    let newTemplate = OrganizationTemplate.johnnyDecimal

    // Clear existing and apply new template
    try? ruleService.seedTemplateRules(
        template: newTemplate,
        clearExisting: true
    )

    selectedTemplate = newTemplate.rawValue
}
```

### Hybrid Approach

**Combining templates:**

```swift
// Start with Minimal
try ruleService.seedTemplateRules(template: .minimal)

// Add PARA rules for specific areas
try ruleService.addTemplateRules(template: .para)

// Add custom user rules
let customRule = Rule(
    name: "My Custom Rule",
    conditionType: .nameContains,
    conditionValue: "myproject",
    actionType: .move,
    destinationFolder: "/Users/me/Documents/My Projects"
)
ruleService.createRule(customRule)
```

### Manual Rule Addition

**For power users:**

```swift
// Start with Custom (no rules)
try ruleService.seedTemplateRules(template: .custom)

// Build rules incrementally
let rule1 = Rule(/* ... */)
let rule2 = Rule(/* ... */)
let rule3 = Rule(/* ... */)

try ruleService.createRule(rule1)
try ruleService.createRule(rule2)
try ruleService.createRule(rule3)
```

---

## Template Selection Flow

### Onboarding

**Step 1: Choose Your Workflow**
```
┌─────────────────────────────────────┐
│  How do you prefer to organize?    │
│                                     │
│  ○ PARA Method                      │
│    For knowledge workers            │
│                                     │
│  ○ Creative Professional            │
│    For designers & photographers    │
│                                     │
│  ○ Student                          │
│    For class-based organization     │
│                                     │
│  ○ More Options...                  │
└─────────────────────────────────────┘
```

**Step 2: Preview Structure**
```
┌─────────────────────────────────────┐
│  PARA Method Preview                │
│                                     │
│  Folder Structure:                  │
│  • Projects                         │
│  • Areas (Finance, Health, etc.)    │
│  • Resources                        │
│  • Archive                          │
│                                     │
│  This template will create:         │
│  • 10 smart rules                   │
│  • 4 main folders                   │
│  • Auto-archival after 6 months     │
│                                     │
│  [Looks Good] [Choose Different]    │
└─────────────────────────────────────┘
```

**Step 3: Apply Template**
```
┌─────────────────────────────────────┐
│  ✓ Template Applied                 │
│                                     │
│  Your PARA system is ready!         │
│                                     │
│  Created:                           │
│  • 10 smart rules                   │
│  • 4 folder categories              │
│                                     │
│  [Start Organizing]                 │
└─────────────────────────────────────┘
```

### Settings

**Template Management:**
```
┌─────────────────────────────────────┐
│  Organization Template              │
│                                     │
│  Current: PARA Method               │
│                                     │
│  [Change Template]                  │
│  [View Rules]                       │
│  [Customize]                        │
│                                     │
│  ⚠️  Changing templates will        │
│     replace your existing rules     │
└─────────────────────────────────────┘
```

---

## Customization

### Editing Template Rules

**After applying a template, users can:**

1. **Add New Rules**
   - Create custom rules alongside template rules
   - Use Rule Builder UI

2. **Modify Existing Rules**
   - Edit destination folders
   - Adjust condition values
   - Change rule priority

3. **Disable Rules**
   - Turn off specific template rules
   - Keep template structure without all automations

4. **Switch Templates**
   - Choose different template
   - Option to preserve custom rules

### Template + Custom Rules

**Best Practice:**

```swift
// 1. Apply template for structure
try ruleService.seedTemplateRules(template: .para)

// 2. Add custom rules for specific needs
let projectRule = Rule(
    name: "MyProject Files",
    conditionType: .nameContains,
    conditionValue: "myproject",
    actionType: .move,
    destinationFolder: "/Users/me/Documents/Projects/MyProject"
)
try ruleService.createRule(projectRule)

// 3. User now has:
// - 10 PARA template rules
// - 1 custom rule
// - Total: 11 rules
```

---

## Best Practices

### Template Selection

**Recommend based on user answers:**

| User Type | Recommended Template | Reason |
|-----------|---------------------|---------|
| Knowledge worker | PARA | Actionability-based system |
| Designer/Creative | Creative Professional | Client/project workflow |
| Student | Student | Class-based organization |
| Lawyer/Accountant | Chronological | Compliance & date-based |
| Researcher | Academic | Literature & research focus |
| Casual user | Minimal | Simplicity, low cognitive load |
| Power user | Custom | Full control |

### Rule Count Guidelines

**Optimal rule counts:**
- Minimal: 7 rules (simplicity)
- PARA: 10 rules (balance)
- Johnny Decimal: 13 rules (structure)
- Academic: 14 rules (comprehensive)
- Student: 14 rules (semester coverage)

**Too Many Rules:**
- User confusion
- Slower rule evaluation
- Maintenance burden

**Too Few Rules:**
- Limited automation
- Requires manual filing

### Folder Structure Best Practices

**Depth Guidelines:**
- **Maximum depth**: 3-4 levels
- **PARA**: 3 levels (Area/Finance/Taxes)
- **Johnny Decimal**: 2 levels (10-19/11 Invoices)

**Naming Conventions:**
- Clear, descriptive names
- Avoid abbreviations
- Use title case
- Include categories in name (Johnny Decimal)

---

## Testing & Validation

### Template Validation

**File:** `Forma File OrganizingTests/OrganizationTemplateTests.swift`

**What to Test:**
1. All templates generate rules
2. Folder structures are valid
3. Rule count matches expectations
4. No duplicate rules
5. Destinations exist

**Example Test:**
```swift
func testPARATemplateGeneratesRules() {
    let template = OrganizationTemplate.para
    let rules = template.generateRules()

    XCTAssertEqual(rules.count, 10, "PARA should generate 10 rules")
    XCTAssert(rules.contains { $0.name == "Active Projects" })
    XCTAssert(rules.contains { $0.destinationFolder.contains("Projects") })
}
```

---

## Future Enhancements

### Planned Features

1. **Template Marketplace**
   - User-submitted templates
   - Industry-specific templates
   - Import/export templates

2. **Smart Template Recommendations**
   - ML-based template suggestions
   - Based on file types in Desktop/Downloads
   - Personality quiz integration

3. **Template Mixing**
   - UI for combining templates
   - Visual rule conflict resolution
   - Merge strategies

4. **Dynamic Templates**
   - Year/month auto-updating (Chronological)
   - Semester detection (Student)
   - Project-based folder creation

---

## Related Documentation

- [Personality System](PersonalitySystem.md) - Organization personality quiz that recommends templates
- [Onboarding Flow](../Design/Forma-Onboarding-Flow.md) - Template selection is Step 4 of onboarding
- [Rule Engine Architecture](../Architecture/RuleEngine-Architecture.md) - How templates generate rules
- [Dashboard Architecture](../Architecture/DASHBOARD.md) - Post-onboarding main interface
- [Design System](../Design/DesignSystem.md) - UI components for template cards

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| **1.0** | December 2025 | Initial comprehensive template documentation |

---

**Document Version:** 1.0
**Generated:** December 2025
**Maintained by:** Forma Product Team
