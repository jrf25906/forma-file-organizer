# Forma UX/UI Analysis & Improvement Plan

> **Document Purpose**: Deep analysis of UX/UI confusion points in the Forma file organizing app, with multiple solution options and recommended prototypes for each issue.

---

## Changelog

| Date | Changes |
|------|---------|
| 2024-12-03 | **Sprint 3 Complete** - Added context-aware rule editor headers: "Quick Rule" for file context, "New Rule" / "Rule Editor" for from-scratch, "Edit Rule" for editing |
| 2024-12-03 | **Sprint 2 Complete** - Added right panel mode header with back navigation, mode icons, and contextual titles |
| 2024-12-03 | **Sprint 1 Complete** - Implemented quick wins: StatusPill component, unified button labels, fixed "in queue" terminology, added explicit counts to bulk actions |
| 2024-12-03 | Initial analysis document created |

---

## Implementation Status

| Problem | Status | Notes |
|---------|--------|-------|
| 1. Review/Organize terminology | ✅ **DONE** | Unified to "Organize" / "Set Destination" |
| 2. Too Many Rule Creation Paths | ✅ **DONE** | Context-aware headers: "Quick Rule", "New Rule", "Rule Editor", "Edit Rule" |
| 3. Invisible File Status | ✅ **DONE** | Added `FormaStatusPill` component |
| 4. Right Panel Mode Ambiguity | ✅ **DONE** | Added mode header with back navigation & contextual titles |
| 5. Bulk Action Scope Unclear | ✅ **DONE** | Explicit counts: "Organize 3 Selected" |
| 6. "In Queue" Terminology | ✅ **DONE** | Changed to "ready to organize" |

---

## Table of Contents

1. [Problem 1: "Review" vs "Organize" Terminology Confusion](#problem-1-review-vs-organize-terminology-confusion) ✅
2. [Problem 2: Too Many Rule Creation Paths](#problem-2-too-many-rule-creation-paths) ✅
3. [Problem 3: Invisible File Status](#problem-3-invisible-file-status) ✅
4. [Problem 4: Right Panel Mode Ambiguity](#problem-4-right-panel-mode-ambiguity) ✅
5. [Problem 5: Bulk Action Scope Unclear](#problem-5-bulk-action-scope-unclear) ✅
6. [Problem 6: "In Queue" Terminology](#problem-6-in-queue-terminology) ✅
7. [Implementation Priority Matrix](#implementation-priority-matrix)

---

## Problem 1: "Review" vs "Organize" Terminology Confusion

### The Problem

In `FileRow.swift:33-58`, the primary action button dynamically changes its label based on internal file state that users never see:

```swift
private var primaryActionConfig: (label: String, icon: String, color: Color, action: () -> Void) {
    if file.suggestedDestination != nil {
        if file.status == .ready {
            return ("Organize", "checkmark.circle.fill", .formaSage, { onOrganize(file) })
        } else {
            return ("Review", "arrow.right.circle.fill", .formaSteelBlue, { onEditDestination?(file) })
        }
    } else {
        return ("Create Rule", "wand.and.stars", .formaSteelBlue, { onCreateRule?(file) })
    }
}
```

**User Experience Issue:**
- A file shows "Review" one moment, then "Organize" the next
- Users don't know what triggers this change (it's the `.ready` status)
- "Review" implies reading/checking, but it actually opens a destination editor
- The underlying state machine (`pending` -> `ready` -> `completed` -> `skipped`) is invisible

### Solution Options

#### Option A: Unify to Single Action ("Organize")
Always show "Organize" and handle the destination check internally. If no destination exists, prompt inline.

**Pros:** Simple mental model, one verb to learn
**Cons:** Loses the nuance that some files need more attention

#### Option B: Use Descriptive Labels Based on What Happens
- "Move to Documents" (when destination is set and ready)
- "Set Destination" (when destination is missing)
- "Confirm Move" (when destination exists but needs approval)

**Pros:** Clear about what will happen
**Cons:** Labels get long, less visual consistency

#### Option C: Show Status Badge + Consistent Action (Recommended)
Add a visible status indicator to the file row, keep "Organize" as the primary action, but show a confirmation step for non-ready files.

**Pros:** Users understand file state, action is predictable
**Cons:** Slightly more visual complexity

### Recommended Solution: Option C

Add a status badge and use consistent "Organize" terminology with smart behavior.

```swift
// PROTOTYPE: Add to FileRow.swift

// MARK: - Status Badge (add near line 143, after destination badge)
private var statusBadge: some View {
    Group {
        switch file.status {
        case .pending:
            StatusPill(
                text: "Needs Destination",
                icon: "questionmark.circle",
                color: .formaWarmOrange
            )
        case .ready:
            StatusPill(
                text: "Ready",
                icon: "checkmark.circle",
                color: .formaSage
            )
        case .completed:
            StatusPill(
                text: "Organized",
                icon: "checkmark.seal.fill",
                color: .formaSage.opacity(0.7)
            )
        case .skipped:
            StatusPill(
                text: "Skipped",
                icon: "forward.fill",
                color: .formaSecondaryLabel
            )
        }
    }
}

// New component to add:
struct StatusPill: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// UPDATED primaryActionConfig - unified "Organize" with smart behavior
private var primaryActionConfig: (label: String, icon: String, color: Color, action: () -> Void) {
    if file.suggestedDestination != nil {
        // Always say "Organize" - the status badge explains the state
        return (
            "Organize",
            "checkmark.circle.fill",
            file.status == .ready ? .formaSage : .formaSteelBlue,
            {
                if file.status == .ready {
                    onOrganize(file)
                } else {
                    // Opens destination editor for confirmation
                    onEditDestination?(file)
                }
            }
        )
    } else {
        return (
            "Set Destination",  // More specific than "Create Rule"
            "folder.badge.plus",
            .formaSteelBlue,
            { onCreateRule?(file) }
        )
    }
}
```

### Files to Modify
- `Forma File Organizing/Views/Components/FileRow.swift`
- `Forma File Organizing/DesignSystem/` (add StatusPill component)

---

## Problem 2: Too Many Rule Creation Paths

### The Problem

Users can create rules from 5+ different locations:

| Location | File | UI Element |
|----------|------|------------|
| Right Panel (inline) | `InlineRuleBuilderView.swift` | Embedded form |
| Modal (full editor) | `RuleEditorView.swift` | Centered modal |
| Natural Language | `NaturalLanguageRuleView.swift` | Text input |
| Quick Creation Sheet | `QuickRuleCreationSheet.swift` | Popup sheet |
| File Row Context | `FileRow.swift` | "Create Rule" button |
| Default Panel | `DefaultPanelView.swift:202` | "Create Rule" button |
| Sidebar | `SidebarView.swift` | "+" button |

**User Experience Issue:**
- No guidance on which method to use
- Inline and modal editors can expand/collapse into each other (suggesting they're the same, but architecturally separate)
- Natural language is hidden away, not discoverable
- Users don't know capabilities differ between methods

### Solution Options

#### Option A: Reduce to Two Entry Points
1. **Quick Create** (from file context) - pre-fills from file
2. **Full Editor** (from sidebar/rules view) - starts empty

**Pros:** Clear when to use each
**Cons:** Loses natural language discoverability

#### Option B: Single Entry Point with Progressive Disclosure
One "Create Rule" button everywhere that opens a unified modal with tabs: Quick / Natural Language / Advanced

**Pros:** Consistent experience, all features discoverable
**Cons:** More complex modal, loses inline convenience

#### Option C: Smart Context + Unified Modal (Recommended)
Keep inline for file-context quick creation, but all other entry points go to a unified modal. Add clear labeling.

**Pros:** Context-appropriate UX, reduces confusion
**Cons:** Two codepaths to maintain

### Recommended Solution: Option C

```swift
// PROTOTYPE: Update entry points to use consistent routing

// In DashboardViewModel.swift - add unified rule creation router
enum RuleCreationContext {
    case fromFile(FileItem)      // Opens inline builder in right panel
    case fromScratch             // Opens full modal
    case editing(Rule)           // Opens full modal with rule data
}

extension DashboardViewModel {
    func createRule(context: RuleCreationContext) {
        switch context {
        case .fromFile(let file):
            // Inline in right panel - quick, contextual
            showRuleBuilderPanel(editingRule: nil, fileContext: file)

        case .fromScratch:
            // Full modal - comprehensive, all features
            showFullRuleEditor(rule: nil)

        case .editing(let rule):
            // Full modal - need all editing capabilities
            showFullRuleEditor(rule: rule)
        }
    }

    private func showFullRuleEditor(rule: Rule?) {
        // Set state to show the modal
        self.editingRuleForModal = rule
        self.showRuleEditorModal = true
    }
}

// Update DefaultPanelView.swift:202 - "Create Rule" button
Button(action: {
    dashboardViewModel.createRule(context: .fromScratch)
}) {
    HStack(spacing: 8) {
        Image(systemName: "plus.circle")
        Text("Create Rule")
    }
    // ... existing styling
}

// Update FileRow.swift - "Create Rule" / "Set Destination" action
{ onCreateRule?(file) }  // This already passes file context

// In MainContentView, handle the callback:
onCreateRule: { file in
    dashboardViewModel.createRule(context: .fromFile(file))
}
```

### Add Clear Labels to Each Editor

```swift
// InlineRuleBuilderView.swift - update header (line 130)
HStack {
    Image(systemName: "bolt.fill")  // Quick icon
        .foregroundColor(.formaSage)
    VStack(alignment: .leading, spacing: 2) {
        Text("Quick Rule")
            .font(.system(size: 15, weight: .semibold))
        Text("From this file's pattern")
            .font(.system(size: 11))
            .foregroundColor(.formaSecondaryLabel)
    }
    Spacer()
    // ... expand button
}

// RuleEditorView.swift - update header
HStack {
    Image(systemName: "slider.horizontal.3")
        .foregroundColor(.formaSteelBlue)
    VStack(alignment: .leading, spacing: 2) {
        Text("Rule Editor")
            .font(.system(size: 17, weight: .semibold))
        Text("Advanced conditions & actions")
            .font(.system(size: 12))
            .foregroundColor(.formaSecondaryLabel)
    }
    Spacer()
}
```

### Files to Modify
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- `Forma File Organizing/Views/InlineRuleBuilderView.swift`
- `Forma File Organizing/Views/RuleEditorView.swift`
- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Views/MainContentView.swift`

---

## Problem 3: Invisible File Status

### The Problem

`FileItem.swift` defines `OrganizationStatus`:

```swift
enum OrganizationStatus: String, Codable {
    case pending    // File needs a destination
    case ready      // Destination set, ready to organize
    case completed  // Already organized
    case skipped    // User chose to skip
}
```

But this status is **never shown to users**. The only hint is the button label changing between "Review"/"Organize"/"Create Rule".

**User Experience Issue:**
- Users can't understand why files behave differently
- No way to filter/sort by status
- No visual progress indicator for individual files

### Solution Options

#### Option A: Add Status Badge to File Row (See Problem 1)
Already covered in Problem 1 solution - add `StatusPill` component.

#### Option B: Add Status Column in List View
For power users who want to see status at a glance.

**Pros:** Familiar table column pattern
**Cons:** Forma uses card layout, not table

#### Option C: Status Indicator in Thumbnail Corner (Recommended)
Add a small icon/dot overlay on the thumbnail to indicate status without adding UI clutter.

### Recommended Solution: Combine A + C

```swift
// PROTOTYPE: Add status indicator to PremiumThumbnail

// In FileRow.swift, update PremiumThumbnail call (around line 81)
PremiumThumbnail(
    file: file,
    size: 84,
    showQuickLook: showQuickLookHint,
    isSelected: isSelected,
    showStatusIndicator: true,  // NEW
    onQuickLook: { onQuickLook?(file) },
    onHoverChange: { hovering in /* ... */ }
)

// In PremiumThumbnail struct, add overlay:
struct PremiumThumbnail: View {
    // ... existing properties
    var showStatusIndicator: Bool = false

    var body: some View {
        Button(action: onQuickLook) {
            ZStack {
                // ... existing thumbnail content

                // Status indicator overlay (bottom-right corner)
                if showStatusIndicator {
                    statusIndicatorOverlay
                }
            }
        }
        // ... rest of view
    }

    @ViewBuilder
    private var statusIndicatorOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    // Background circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 20, height: 20)

                    // Status icon
                    Image(systemName: statusIconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(statusColor)
                }
                .offset(x: 4, y: 4)
            }
        }
        .frame(width: size, height: size)
    }

    private var statusIconName: String {
        switch file.status {
        case .pending: return "questionmark"
        case .ready: return "checkmark"
        case .completed: return "checkmark.seal.fill"
        case .skipped: return "forward.fill"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case .pending: return .formaWarmOrange
        case .ready: return .formaSage
        case .completed: return .formaSage.opacity(0.7)
        case .skipped: return .formaSecondaryLabel
        }
    }
}
```

### Files to Modify
- `Forma File Organizing/Views/Components/FileRow.swift` (PremiumThumbnail)
- Consider adding status filter chips to toolbar

---

## Problem 4: Right Panel Mode Ambiguity

### The Problem

The right panel switches between 4 modes automatically:

```swift
// PanelStateManager.swift:10-14
enum RightPanelMode: Equatable {
    case `default`              // DefaultPanelView - suggestions, actions
    case inspector([FileItem])  // FileInspectorView - file details
    case ruleBuilder(...)       // InlineRuleBuilderView - create/edit rule
    case celebration(String)    // CelebrationView - success animation
}
```

From `RightPanelView.swift`:
```swift
switch dashboardViewModel.rightPanelMode {
case .default:
    DefaultPanelView()
case .inspector(let files):
    FileInspectorView(files: files)
case .celebration(let message):
    CelebrationView(message: message)
case .ruleBuilder(let editingRule, let fileContext):
    InlineRuleBuilderView(editingRule: editingRule, fileContext: fileContext)
}
```

**User Experience Issue:**
- No visual indication of which mode is active
- Mode switches automatically when selecting files (inspector takes over)
- Users can't manually return to default panel
- "Default" isn't a meaningful name to users

### Solution Options

#### Option A: Add Mode Header/Tab Bar
Show a persistent header indicating current mode with back button.

**Pros:** Always clear where you are
**Cons:** Takes vertical space

#### Option B: Add Breadcrumb Trail
Small breadcrumb at top: "Dashboard > File Details"

**Pros:** Light, shows navigation path
**Cons:** Might feel like over-engineering

#### Option C: Mode Indicator + Close Button (Recommended)
Add a subtle mode indicator with ability to return to dashboard.

### Recommended Solution: Option C

```swift
// PROTOTYPE: Add to RightPanelView.swift

struct RightPanelView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    // ... existing properties

    var body: some View {
        VStack(spacing: 0) {
            // NEW: Mode indicator header
            panelModeHeader

            Divider()
                .opacity(showModeHeader ? 1 : 0)

            // Existing panel content
            Group {
                switch dashboardViewModel.rightPanelMode {
                // ... existing cases
                }
            }
        }
        .background(.regularMaterial)
        // ... existing overlay
    }

    private var showModeHeader: Bool {
        // Show header for all modes except default
        if case .default = dashboardViewModel.rightPanelMode {
            return false
        }
        return true
    }

    @ViewBuilder
    private var panelModeHeader: some View {
        if showModeHeader {
            HStack(spacing: 12) {
                // Back to dashboard button
                Button(action: {
                    dashboardViewModel.returnToDefaultPanel()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.formaSteelBlue)
                }
                .buttonStyle(.plain)

                // Mode label
                HStack(spacing: 6) {
                    Image(systemName: modeIcon)
                        .font(.system(size: 12))
                    Text(modeTitle)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.formaSecondaryLabel)

                Spacer()
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, 10)
            .background(Color.formaObsidian.opacity(0.02))
        }
    }

    private var modeIcon: String {
        switch dashboardViewModel.rightPanelMode {
        case .default: return "house"
        case .inspector: return "doc.text.magnifyingglass"
        case .ruleBuilder: return "wand.and.stars"
        case .celebration: return "party.popper"
        }
    }

    private var modeTitle: String {
        switch dashboardViewModel.rightPanelMode {
        case .default: return "Dashboard"
        case .inspector(let files):
            return files.count == 1 ? "File Details" : "\(files.count) Files"
        case .ruleBuilder(let rule, _):
            return rule == nil ? "New Rule" : "Edit Rule"
        case .celebration: return "Success!"
        }
    }
}
```

### Files to Modify
- `Forma File Organizing/Views/RightPanelView.swift`

---

## Problem 5: Bulk Action Scope Unclear

### The Problem

From `FloatingActionBar.swift`:
```swift
private var primaryButtonLabel: String {
    switch mode {
    case .selection:
        return "Organize All"
    case .review:
        return "Organize"
    }
}
```

And from `DefaultPanelView.swift:179`:
```swift
Text("Organize \(readyFiles.count) Files")
```

**User Experience Issue:**
- "Organize All" could mean: all selected, all in view, all ready files, or all files period
- Different contexts show different counts with no explanation
- No preview of what will actually happen

### Solution Options

#### Option A: Always Show Explicit Count
"Organize 5 Selected Files" or "Organize 12 Ready Files"

**Pros:** Clear exactly what will happen
**Cons:** Longer button labels

#### Option B: Add Confirmation Step with Preview
Show a brief confirmation with file list before executing.

**Pros:** Users can verify before acting
**Cons:** Extra step for power users

#### Option C: Explicit Labels + Hover Preview (Recommended)
Clear labels with optional hover to see file list.

### Recommended Solution: Option C

```swift
// PROTOTYPE: Update FloatingActionBar.swift

struct FloatingActionBar: View {
    // ... existing properties
    @State private var showOrganizePreview = false

    private var primaryButtonLabel: String {
        switch mode {
        case .selection:
            return "Organize \(count) Selected"
        case .review:
            return "Organize \(count) Ready"
        }
    }

    private var statusText: String {
        switch mode {
        case .selection:
            return "file\(count == 1 ? "" : "s") selected"
        case .review:
            return "ready to organize"  // Clearer than "in queue"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // ... left section (count display)

            Spacer()

            // Center: Action buttons with hover preview
            HStack(spacing: 10) {
                // Skip button
                // ... existing code

                // Primary action with hover state
                if canOrganizeAll {
                    Button(action: onOrganize) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text(primaryButtonLabel)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.formaSteelBlue)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(organizeHelpText)  // Tooltip with details
                }
            }

            // ... right section
        }
    }

    private var organizeHelpText: String {
        switch mode {
        case .selection:
            return "Move \(count) selected file\(count == 1 ? "" : "s") to their suggested destinations"
        case .review:
            return "Move \(count) file\(count == 1 ? "" : "s") that are ready to organize"
        }
    }
}
```

### Confirmation Sheet for Bulk Actions

```swift
// PROTOTYPE: Add BulkOrganizeConfirmationView.swift

struct BulkOrganizeConfirmationView: View {
    let files: [FileItem]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: FormaSpacing.large) {
            // Header
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.formaSteelBlue)
                VStack(alignment: .leading) {
                    Text("Organize \(files.count) Files")
                        .font(.system(size: 17, weight: .semibold))
                    Text("The following files will be moved:")
                        .font(.system(size: 13))
                        .foregroundColor(.formaSecondaryLabel)
                }
                Spacer()
            }

            // File list preview (scrollable, max 5 visible)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(files, id: \.path) { file in
                        HStack {
                            Text(file.name)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(.formaSecondaryLabel)
                            Text(truncatedDestination(file.suggestedDestination ?? ""))
                                .font(.system(size: 12))
                                .foregroundColor(.formaSteelBlue)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 200)

            // Actions
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Spacer()

                Button("Organize All", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .tint(.formaSage)
            }
        }
        .padding(FormaSpacing.generous)
        .frame(width: 400)
    }

    private func truncatedDestination(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        return ".../" + components.suffix(2).joined(separator: "/")
    }
}
```

### Files to Modify
- `Forma File Organizing/Components/FloatingActionBar.swift`
- Create `Forma File Organizing/Views/Components/BulkOrganizeConfirmationView.swift`
- Update `DashboardViewModel` to show confirmation for bulk actions

---

## Problem 6: "In Queue" Terminology

### The Problem

From `FloatingActionBar.swift:54-62`:
```swift
private var statusText: String {
    switch mode {
    case .selection:
        return "file\(count == 1 ? "" : "s") selected"
    case .review:
        return "file\(count == 1 ? "" : "s") in queue"
    }
}
```

**User Experience Issue:**
- "In queue" is vague - queue for what?
- Doesn't match terminology elsewhere (no "queue" concept in the app)
- Should align with status terminology (ready, pending, etc.)

### Recommended Solution

Already addressed in Problem 5 - change to "ready to organize":

```swift
private var statusText: String {
    switch mode {
    case .selection:
        return "file\(count == 1 ? "" : "s") selected"
    case .review:
        return "ready to organize"
    }
}
```

---

## Implementation Priority Matrix

| Problem | Impact | Effort | Priority | Dependencies |
|---------|--------|--------|----------|--------------|
| 1. Review/Organize terminology | High | Low | **P0** | None |
| 3. Invisible file status | High | Low | **P0** | Problem 1 |
| 5. Bulk action scope | High | Medium | **P1** | None |
| 6. "In queue" terminology | Low | Trivial | **P1** | Part of Problem 5 |
| 4. Right panel mode | Medium | Low | **P2** | None |
| 2. Rule creation paths | Medium | High | **P3** | None |

### Recommended Implementation Order

1. **Sprint 1 (Quick Wins)**
   - Add `StatusPill` component
   - Add status indicator to file rows
   - Unify button labels to "Organize" / "Set Destination"
   - Fix "in queue" terminology

2. **Sprint 2 (Clarity)**
   - Add right panel mode header
   - Update bulk action button labels with explicit counts
   - Add tooltips for bulk actions

3. **Sprint 3 (Architecture)**
   - Consolidate rule creation entry points
   - Add confirmation view for bulk operations
   - Update InlineRuleBuilderView header to show "Quick Rule"

---

## Component Library Additions

Based on this analysis, the following components should be added to the design system:

```swift
// Add to DesignSystem/Components/

/// Status indicator pill for file organization state
struct StatusPill: View { /* see Problem 1 */ }

/// Mode header for right panel navigation
struct PanelModeHeader: View { /* see Problem 4 */ }

/// Confirmation dialog for bulk operations
struct BulkActionConfirmation: View { /* see Problem 5 */ }
```

---

## Metrics to Track

After implementing these changes, track:

1. **Time to first organize** - Should decrease as users understand status
2. **Rule creation completion rate** - Should increase with clearer paths
3. **Bulk action usage** - Should increase with clearer labels
4. **Support requests about "Review" button** - Should decrease to zero

---

## Related Documentation

### Audits & Analysis
- [Codebase Audit](CODEBASE_AUDIT.md) - Full codebase review
- [Performance Audit](PERFORMANCE_AUDIT.md) - Performance analysis

### Design
- [Design System](Design/DesignSystem.md) - Design tokens and patterns
- [UI Guidelines](Design/UI-GUIDELINES.md) - UI implementation patterns
- [Design README](Design/README.md) - Design documentation index

### Architecture
- [Dashboard Architecture](Architecture/DASHBOARD.md) - Main interface design
- [Right Panel Architecture](Architecture/RIGHT_PANEL.md) - Contextual panel design
- [Component Architecture](Architecture/ComponentArchitecture.md) - UI component catalog

### Features
- [Onboarding Flow](Design/Forma-Onboarding-Flow.md) - Onboarding UX design
- [Empty States](Design/Forma-Empty-States.md) - Empty state designs

### Navigation
- [Documentation Index](INDEX.md) - Master navigation

---

*Document created: December 2024*
*Last updated: December 2025*
