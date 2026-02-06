# Per-Folder Template Selection

## Overview

This document outlines the design for allowing users to assign different organization templates to different folders during onboarding. A photographer might want chronological organization for Pictures, but minimal organization for their Desktop.

## Current State

### Existing Flow (5 steps)
```
Welcome → Folders → Quiz → Template (global) → Preview
```

**Problem**: One template applies globally to all selected folders. This doesn't match how people actually think about their files—different spaces have different purposes.

### Existing Infrastructure

The codebase already has the building blocks for per-location organization:

| Component | Location | Purpose |
|-----------|----------|---------|
| `RuleCategory` | `Models/RuleCategory.swift` | Groups rules with optional folder scoping |
| `CategoryScope` | `Models/RuleCategory.swift` | Defines `.global` or `.folders([ScopedFolder])` |
| Scope matching | `RuleEngine.swift:105` | Checks if file's source URL matches category scope |

**Key insight**: We can create a `RuleCategory` per watched folder, each with its own template's rules.

---

## Proposed Design

### Updated Flow (Implemented)
```
Welcome → Folders → Quiz → Per-Folder Templates → Preview & Confirm
```

### Step 4: Per-Folder Template Selection

Users assign a template to each folder they selected in Step 2.

```
┌──────────────────────────────────────────────────────────────┐
│  [1 Folders] ─── [2 Style] ─── [3 Systems] ─── [4 Preview]   │
│                                    ●                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│               📂  Customize Each Space                       │
│                                                              │
│    Different folders deserve different organization.         │
│    Tell us how you'd like each one organized.               │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 📁 Pictures                              ▼ Chronological │ │
│  │    "Perfect for photographers - organize by date"       │ │
│  │    Preview: /2025/Q1/January, /2025/Q1/February...     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 📁 Desktop                               ▼ Minimal       │ │
│  │    "Keep it clean - just Inbox, Keep, Archive"         │ │
│  │    Preview: /Inbox, /Keep, /Archive                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 📁 Downloads                             ▼ PARA          │ │
│  │    "Project-based organization for productivity"       │ │
│  │    Preview: /Projects, /Areas, /Resources, /Archive    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 💡 Tip: You can change these anytime in Settings      │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌─────────┐                      ┌──────────────────────┐  │
│  │ ← Back  │                      │ Preview Your System → │  │
│  └─────────┘                      └──────────────────────┘  │
│                                                              │
│              Use same template for all folders               │
└──────────────────────────────────────────────────────────────┘
```

**UI Components**:
- Expandable card per selected folder
- Dropdown to select template (defaults to personality-suggested template)
- Inline preview of folder structure
- "Use same for all" shortcut for users who want simplicity

### Step 5: Preview & Confirm (Hybrid Approach)

Shows the complete folder structure that will emerge—**without creating empty folders**.

```
┌──────────────────────────────────────────────────────────────┐
│  [1 Folders] ─── [2 Style] ─── [3 Systems] ─── [4 Preview]   │
│                                                  ●           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│               ✨ Your Organization System                    │
│                                                              │
│    Here's how Forma will organize your files.               │
│    Folders are created automatically when files need them.   │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │  📂 Pictures (Chronological)                             ││
│  │  ├── 📁 2025                                             ││
│  │  │   ├── 📁 Q1                                           ││
│  │  │   │   ├── 📁 January                                  ││
│  │  │   │   ├── 📁 February                                 ││
│  │  │   │   └── 📁 March                                    ││
│  │  │   └── 📁 Q2                                           ││
│  │  └── 📁 Archive                                          ││
│  │      └── 📁 Older                                        ││
│  │                                                          ││
│  │  📂 Desktop (Minimal)                                    ││
│  │  ├── 📁 Inbox          ← New files land here            ││
│  │  ├── 📁 Keep           ← Important stuff                 ││
│  │  └── 📁 Archive        ← Older than 90 days             ││
│  │                                                          ││
│  │  📂 Downloads (PARA)                                     ││
│  │  ├── 📁 Projects       ← Active work                     ││
│  │  ├── 📁 Areas          ← Ongoing responsibilities        ││
│  │  ├── 📁 Resources      ← Reference materials             ││
│  │  └── 📁 Archive        ← Completed                       ││
│  └──────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 📝 These folders will be created as files are sorted   │  │
│  │    No empty folders - just what you need, when needed  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌─────────┐                      ┌──────────────────────┐  │
│  │ ← Back  │                      │ 🎉 Start Organizing  │  │
│  └─────────┘                      └──────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

**Key Points**:
- Visual tree shows the folder structure that will emerge
- Annotations explain what each folder is for
- Explicit messaging that folders are created on-demand (no empty folder clutter)
- This is purely visual—no folders are created until files need them

---

## Data Model

### New State: `FolderTemplateSelection`

Track per-folder template choices during onboarding:

```swift
struct FolderTemplateSelection: Codable, Equatable {
    var desktop: OrganizationTemplate?
    var downloads: OrganizationTemplate?
    var documents: OrganizationTemplate?
    var pictures: OrganizationTemplate?
    var music: OrganizationTemplate?

    /// Returns template for a given folder, using personality-suggested default
    func template(
        for folder: OnboardingFolder,
        personality: OrganizationPersonality?
    ) -> OrganizationTemplate {
        let explicit: OrganizationTemplate? = switch folder {
            case .desktop: desktop
            case .downloads: downloads
            case .documents: documents
            case .pictures: pictures
            case .music: music
        }
        return explicit ?? personality?.suggestedTemplate ?? .minimal
    }

    /// Storage key for persisting selections
    static let storageKey = "onboardingFolderTemplateSelection"

    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }

    static func load() -> FolderTemplateSelection {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let selection = try? JSONDecoder().decode(
                  FolderTemplateSelection.self,
                  from: data
              ) else {
            return FolderTemplateSelection()
        }
        return selection
    }
}
```

### What Gets Created on Completion

When onboarding completes, we create a `RuleCategory` for each selected folder:

```swift
// Example: User selected Pictures with Chronological, Desktop with Minimal

// 1. Pictures category, scoped to ~/Pictures
let picturesCategory = RuleCategory(
    name: "Pictures",
    colorHex: "#EC4899",  // Pink, matching OnboardingFolder.pictures.color
    iconName: "photo.fill",
    scope: .folders([picturesFolder]),  // Security-scoped bookmark
    isEnabled: true,
    sortOrder: 0
)
// Insert into SwiftData
modelContext.insert(picturesCategory)

// Apply Chronological template rules to this category
let chronologicalRules = OrganizationTemplate.chronological.generateRules()
for rule in chronologicalRules {
    rule.category = picturesCategory
    modelContext.insert(rule)
}

// 2. Desktop category, scoped to ~/Desktop
let desktopCategory = RuleCategory(
    name: "Desktop",
    colorHex: "#3B82F6",  // Blue, matching OnboardingFolder.desktop.color
    iconName: "desktopcomputer",
    scope: .folders([desktopFolder]),
    isEnabled: true,
    sortOrder: 1
)
modelContext.insert(desktopCategory)

// Apply Minimal template rules to this category
let minimalRules = OrganizationTemplate.minimal.generateRules()
for rule in minimalRules {
    rule.category = desktopCategory
    modelContext.insert(rule)
}
```

### Rule Evaluation Flow

With scoped categories, the `RuleEngine` automatically handles per-folder logic:

```
File from ~/Pictures/photo.jpg
    ↓
RuleEngine.evaluateFile()
    ↓
For each RuleCategory (sorted by sortOrder):
    ↓
    Does category.scope.matches(fileURL)?
        - Pictures category: scope = ~/Pictures → ✅ MATCH
        - Desktop category: scope = ~/Desktop → ❌ NO MATCH
    ↓
    Evaluate rules in Pictures category only
    ↓
    First matching rule determines destination
```

---

## Implementation Plan

### Phase 1: Add Preview Step (Hybrid Approach) ✅ COMPLETED
Add the folder structure preview step without per-folder selection. This provides visual confirmation with minimal changes.

**Files modified**:
- `Views/Onboarding/OnboardingFlowView.swift` - Added `OnboardingPreviewStepView` component
- `Views/Onboarding/OnboardingFlowView.swift` - Updated `OnboardingStep` enum with `.preview` case

### Phase 2: Add Per-Folder Template Selection ✅ COMPLETED
Replace the single template picker with per-folder selection.

**Files created/modified**:
- `Views/Components/PerFolderTemplateComponents.swift` - New file with `PerFolderTemplateStepView`, `FolderTemplateCard`, `TemplateDropdown`, `FolderStructurePreview`
- `Models/FolderTemplateSelection.swift` - New model for per-folder template state
- `Views/Onboarding/OnboardingFlowView.swift` - Updated to use new step and components
- Added `@State private var folderTemplateSelection: FolderTemplateSelection`

### Phase 3: Wire Up Category Creation ✅ COMPLETED
Create folder-scoped categories on onboarding completion.

**Files modified**:
- `DashboardViewModel.swift` - Added `applyPerFolderTemplates()` method
- `Views/Onboarding/OnboardingFlowView.swift` - Updated `completeOnboarding()` to call `applyPerFolderTemplates()`

**Implementation details**:
```swift
// DashboardViewModel.applyPerFolderTemplates() creates:
// 1. RuleCategory per selected folder with .folders([scopedFolder]) scope
// 2. Rules generated from the folder's assigned template
// 3. Each rule is linked to its category via rule.category = category
```

### Phase 4: Testing ✅ COMPLETED
Added comprehensive unit tests for the new functionality.

**Test files created**:
- `FolderTemplateSelectionTests.swift` - 21 tests for model behavior
- `PerFolderTemplateCategoryTests.swift` - 14 tests for category creation

---

## Design Decisions

### Why One Category Per Folder?

**Option A: One Category Per Watched Folder** ✅ Chosen
- Simple mental model: "folder = category = template"
- Easy to explain in UI
- Clean mapping from onboarding choices

**Option B: Shared Categories, Scoped Rules**
- More flexible (e.g., "Creative Work" spans Pictures + Documents)
- More complex UX
- Could add later for power users in Rules Management

**Option C: Location-aware templates (implicit)**
- Templates include `sourceLocation` conditions
- Zero additional UX but less user control
- Doesn't match mental model of "each folder is different"

### Why Lazy Folder Creation?

1. **No empty folder clutter** - Users don't see folders until they're used
2. **Sandbox compliance** - macOS sandboxing requires security-scoped bookmarks; pre-creating folders would need permissions upfront for paths that may never be used
3. **Template flexibility** - Users can change their mind without orphaned folders
4. **Cleaner user experience** - The preview shows intent; reality matches as files flow

### Why Show Preview?

The "hybrid approach" addresses user uncertainty without the downsides of pre-creation:
- **Visual confirmation** - "This is what my system will look like"
- **No commitment** - User can go back and change selections
- **Educational** - Explains what each folder is for
- **Manages expectations** - Clear that folders appear as needed

---

## UI Component Specifications

### FolderTemplateCard

```swift
struct FolderTemplateCard: View {
    let folder: OnboardingFolder
    @Binding var selectedTemplate: OrganizationTemplate
    let personality: OrganizationPersonality?

    // States
    @State private var isExpanded = false
    @State private var isHovered = false

    // Displays:
    // - Folder icon and name (colored by OnboardingFolder.color)
    // - Current template selection (dropdown)
    // - Template description
    // - Folder structure preview (collapsed by default, expandable)
}
```

### FolderStructurePreview

```swift
struct FolderStructurePreview: View {
    let rootFolderName: String
    let template: OrganizationTemplate
    let showAnnotations: Bool

    // Displays:
    // - Tree view of template.folderStructure
    // - Optional annotations explaining each folder's purpose
    // - Indentation to show hierarchy
}
```

### TemplateDropdown

```swift
struct TemplateDropdown: View {
    @Binding var selection: OrganizationTemplate
    let recommendedTemplate: OrganizationTemplate?

    // Displays:
    // - Current selection with icon
    // - Dropdown with all templates
    // - "Recommended" badge on personality-suggested template
}
```

---

## Future Considerations

### Post-Onboarding Management

Users should be able to change per-folder templates after onboarding:
- **Settings > Organization** could show folder → template mappings
- **Rules Management** already has category editing with scope

### Multiple Folders Per Category

Power users might want to group folders:
- "Creative Work" category scoped to `[~/Pictures, ~/Documents/Projects]`
- Already supported by `CategoryScope.folders([ScopedFolder])`
- Could expose in Rules Management for advanced users

### Template Inheritance

Some users might want a "base" template with folder-specific overrides:
- Not in initial scope
- Could be added via rule priority/category sort order

---

## References

### Core Models
- `Models/RuleCategory.swift` - Category model with scope support (`CategoryScope.global` and `.folders([ScopedFolder])`)
- `Models/Rule.swift` - Rule model with category relationship
- `Models/OrganizationTemplate.swift` - Template definitions and rule generation
- `Models/OrganizationPersonality.swift` - Personality struct with static properties (`.creative`, `.academic`, `.business`, `.default`)

### New Files (Per-Folder Templates)
- `Models/FolderTemplateSelection.swift` - Per-folder template state with persistence
- `Views/Components/PerFolderTemplateComponents.swift` - UI components for template selection step

### Integration Points
- `Views/Onboarding/OnboardingFlowView.swift` - Updated onboarding flow with new steps
- `ViewModels/DashboardViewModel.swift` - `applyPerFolderTemplates()` for category creation
- `Services/RuleEngine.swift` - Scope matching in rule evaluation

### Tests
- `FolderTemplateSelectionTests.swift` - Model behavior tests
- `PerFolderTemplateCategoryTests.swift` - Category creation and scoping tests
