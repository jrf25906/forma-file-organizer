# Primary Screen Design Review - Blue Slate Direction

**Date:** 2026-04-27  
**Status:** Working brief, pre-implementation  
**Scope:** Native macOS app primary screens only  
**Out of scope:** `forma-website/`, marketing pages, feature behavior, API behavior

This document captures the design review baseline for Forma's primary macOS app screens. It is a durable design brief to work back from before writing implementation plans, agent assignments, or code changes.

Read this before opening any implementation plan that touches surfaces, type, ambient material, accent color, right rail hierarchy, file rows, Rule Builder, Analytics, Smart Rules, or Settings.

## Context

The review used the `gpt-taste` critique lens translated for a native macOS SwiftUI app: hierarchy, contrast, breathing room, state clarity, restrained motion, and a confident visual system. Web-only recommendations such as GSAP, landing-page structure, and website motion patterns do not apply.

The strongest pattern across the reviewed screenshots is not missing polish. The app is coherent and native-feeling, but too many panes, cards, rows, controls, and secondary labels live in the same tonal range. The result is a calm interface that sometimes feels washed together instead of clearly staged.

The selected direction remains Blue Slate: darker slate anchors, clearer surface steps, stronger title jumps, darker text, and a more committed blue accent used sparingly.

## Goal

Establish Blue Slate as the design baseline for Forma's primary app screens so later implementation plans have a single source of truth.

- Codify hierarchy, contrast, breathing room, state clarity, and accent-use targets.
- Map each design issue to the token or component layer where it should be addressed.
- Preserve macOS-native ergonomics while sharpening the product's visual confidence.
- Keep this brief stable and qualitative; implementation details belong in follow-on plans.

## Non-Goals

- This is not an implementation plan.
- This does not authorize file diffs, PR scope, or workstream sequencing by itself.
- This is not a redesign of information architecture or feature behavior.
- This is not website or marketing work.
- This is not a token rename pass.
- This does not require `TODO.md`, `CHANGELOG.md`, or `API_REFERENCE.md` updates because no behavior changes are made here.
- This does not block unrelated in-flight work unless that work conflicts with the principles below.

## Decision Principles

1. **Hierarchy through structure, not weight inflation.** Prefer clearer surface steps and type-size jumps before adding heavier borders, shadows, or font weights.
2. **Contrast as a budget.** Spend contrast on titles, primary actions, active selection, current-state indicators, and focus. Do not spend it equally on every card outline.
3. **Breathing room is a layout primitive.** Dense data screens can be compact, but rhythm must remain intentional. Cramped and spacious are separate decisions.
4. **State and motion telegraph causality.** Hover, focus, selection, loading, and transition states should explain what changed. Motion should not exist only as decoration.
5. **Restrained but committed.** The blue accent should be confident and predictable, not spread thin across many quiet tints.

## Direction: Blue Slate

Blue Slate keeps Forma in a trust-and-utility lane while giving the app a stronger operating hierarchy.

### Surface Intent

The app needs a more legible surface ladder:

- Sidebar and major anchors should read cooler and darker than the work area.
- Primary work surfaces should lift clearly above app chrome.
- Floating surfaces should be reserved for modals, command surfaces, key cards, and high-priority controls.
- Borders should follow the ladder: fewer decorative hairlines, stronger borders only where state or elevation requires them.

Primary anchors:

- `Forma File Organizing/DesignSystem/FormaColors.swift`
- `Forma File Organizing/Views/Components/PrimaryBackgroundView.swift`
- `Forma File Organizing/Views/SidebarView.swift`
- `Forma File Organizing/Views/DefaultPanelView.swift`

### Type Intent

The current type scale is native and readable, but compressed for a large desktop window. Titles should become easier to identify at a glance, and secondary text should recede without washing out.

Primary anchors:

- `Forma File Organizing/DesignSystem/FormaTypography.swift`
- `Forma File Organizing/Views/Components/UnifiedToolbar.swift`
- `Forma File Organizing/Components/ImpactMetricCard.swift`

### Accent Intent

The blue accent should be more committed and used in fewer places.

Allowed emphasis targets:

- Primary action
- Active selected row or selected segment
- Focus ring or focused field outline
- Current-state indicator

Tints, badges, links, and secondary buttons should stay more neutral unless they communicate state.

Primary anchors:

- `Forma File Organizing/DesignSystem/FormaColors.swift`
- `Forma File Organizing/DesignSystem/Components/FormaButtons.swift`
- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Views/RuleEditorView.swift`

### Material Intent

Ambient gradients and material effects should support hierarchy, not compete with data.

- On dense screens such as Files, Analytics, Rule Builder, and Settings, ambient material should be reduced or scoped.
- On onboarding, empty states, and selected hero surfaces, ambient material can remain more expressive.
- Grain and sheen should stay subtle enough that rows, titles, and controls remain the first read.

Primary anchor:

- `Forma File Organizing/Views/Components/PrimaryBackgroundView.swift`

## Visual Baseline Reviewed

The review used current app screenshot artifacts as the baseline:

- `Docs/Marketing/Screenshots/AppStore/Light/forma-01-hero-main-window.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-02-all-files-list.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-03-rule-builder.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-04-smart-rules.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-05-analytics.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-06-settings.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-01-hero-main-window.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-03-rule-builder.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-05-analytics.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-06-settings.png`

## Evidence

| # | Observation | Surface | Anchor files | Principle |
|---|-------------|---------|--------------|-----------|
| 1 | Surface ladder is too narrow across sidebar, content, right rail, cards, and controls. | Global | `Forma File Organizing/DesignSystem/FormaColors.swift`, `Forma File Organizing/Views/Components/PrimaryBackgroundView.swift`, `Forma File Organizing/Views/SidebarView.swift`, `Forma File Organizing/Views/DefaultPanelView.swift` | 1, 2 |
| 2 | Ambient gradient and material effects are too loud on dense data screens. | Files, Analytics, Rule Builder, Settings | `Forma File Organizing/Views/Components/PrimaryBackgroundView.swift` | 2, 3 |
| 3 | Type hierarchy is compressed; secondary text and uppercase labels either compete or wash out. | Global | `Forma File Organizing/DesignSystem/FormaTypography.swift`, `Forma File Organizing/Views/Components/UnifiedToolbar.swift`, `Forma File Organizing/Components/ImpactMetricCard.swift` | 1, 2 |
| 4 | The right rail does not yet read as the command center for the active workflow. | Main window, right rail | `Forma File Organizing/Views/DefaultPanelView.swift`, `Forma File Organizing/Views/RightPanelView.swift` | 1, 5 |
| 5 | File row actions, completion checks, and category indicators can overpower filenames and destinations. | File list, file grid, file cards | `Forma File Organizing/Components/FileListRow.swift`, `Forma File Organizing/Components/FileGridItem.swift`, `Forma File Organizing/Views/Components/FileRow.swift`, `Forma File Organizing/Components/Shared/FileSurfaceComponents.swift` | 2, 4 |
| 6 | Rule Builder is fragmented across too many equally strong cards, badges, validation regions, and footer controls. | Rule Builder | `Forma File Organizing/Views/RuleEditorView.swift`, `Forma File Organizing/Views/Components/RuleConditionBuilder.swift`, `Forma File Organizing/Views/Components/RuleDestinationPicker.swift` | 1, 3 |
| 7 | Smart Rules empty state has too much vertical air before starter templates become useful. | Smart Rules | `Forma File Organizing/Views/RulesManagementView.swift`, `Forma File Organizing/Components/RuleManagementCard.swift` | 3 |
| 8 | Analytics cards need clearer role hierarchy between KPIs, chart containers, and zero states. | Analytics | `Forma File Organizing/Views/ProductivityReportView.swift`, `Forma File Organizing/Components/ImpactMetricCard.swift` | 1, 2 |
| 9 | Settings is readable but visually disconnected from the main app system. | Settings | `Forma File Organizing/Views/Settings/SettingsView.swift`, `Forma File Organizing/Views/Settings/SettingsComponents.swift` | 5 |
| 10 | The blue accent is hesitant and spread across too many quiet treatments. | Global | `Forma File Organizing/DesignSystem/FormaColors.swift`, `Forma File Organizing/DesignSystem/Components/FormaButtons.swift`, `Forma File Organizing/Views/DefaultPanelView.swift`, `Forma File Organizing/Views/RuleEditorView.swift` | 2, 5 |

## Prioritized Workstreams

These are design workstreams, not implementation tickets. Later agent plans should split them into bounded, independently verifiable slices.

### 1. Surface Ladder and Material Quieting

**Absorbs:** Observations 1, 2, 4, 10  
**Intent:** Make the app architecture legible before tuning individual screens.

Primary anchor files:

- `Forma File Organizing/DesignSystem/FormaColors.swift`
- `Forma File Organizing/Views/Components/PrimaryBackgroundView.swift`
- `Forma File Organizing/Views/SidebarView.swift`
- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Views/RightPanelView.swift`

Mac-native constraints to preserve:

- Keep native split-view behavior.
- Keep vibrancy where macOS expects it, especially sidebar and window chrome.
- Respect Reduce Transparency.
- Do not make the app feel like a website or dashboard shell.

Design target:

The user should immediately understand sidebar, work surface, right rail, cards, and floating controls as distinct layers.

### 2. Type Ramp Recommitment

**Absorbs:** Observation 3, supports Observations 4 and 8  
**Intent:** Make headings and body copy easier to scan without abandoning SF Pro or native macOS sizing expectations.

Primary anchor files:

- `Forma File Organizing/DesignSystem/FormaTypography.swift`
- `Forma File Organizing/Views/Components/UnifiedToolbar.swift`
- `Forma File Organizing/Components/ImpactMetricCard.swift`
- `Forma File Organizing/Views/ProductivityReportView.swift`

Mac-native constraints to preserve:

- Keep SF Pro as the app font.
- Maintain accessibility scaling.
- Preserve compact toolbar legibility.
- Avoid theatrical display typography in operational panels.

Design target:

Primary screen titles should be the first read; section labels should clarify, not compete.

### 3. File Surface Quieting

**Absorbs:** Observation 5  
**Intent:** Restore filenames, destinations, and scan status as the dominant row read.

Primary anchor files:

- `Forma File Organizing/Components/FileListRow.swift`
- `Forma File Organizing/Components/FileGridItem.swift`
- `Forma File Organizing/Views/Components/FileRow.swift`
- `Forma File Organizing/Components/Shared/FileSurfaceComponents.swift`
- `Forma File Organizing/DesignSystem/FileSurfaceStyle.swift`
- `Forma File Organizing/Views/MainContentView.swift`

Mac-native constraints to preserve:

- Keep keyboard focus visible.
- Keep hover and selection affordances.
- Keep card, list, and grid parity.
- Preserve Quick Look and context menu affordances.

Design target:

At rest, rows should scan as file identity first and action surface second. Action emphasis should rise on hover, focus, selection, or review intent.

### 4. Right Rail Command Center

**Absorbs:** Observation 4, depends on Workstream 1  
**Intent:** Make the right rail feel like the active workflow owner.

Primary anchor files:

- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Views/RightPanelView.swift`
- `Forma File Organizing/Components/AutomationStatusWidget.swift`
- `Forma File Organizing/Components/TrustedAutomationScopesSection.swift`

Mac-native constraints to preserve:

- Keep the panel responsive to compact right-rail widths.
- Preserve existing mode transitions.
- Do not add new module types unless a later plan justifies it.

Design target:

The current task card should own the workflow. Automation and suggestions should support it without matching its visual weight.

### 5. Rule Builder Cohesion

**Absorbs:** Observation 6  
**Intent:** Make Rule Builder read as one guided form rather than several equal cards.

Primary anchor files:

- `Forma File Organizing/Views/RuleEditorView.swift`
- `Forma File Organizing/Views/Components/RuleConditionBuilder.swift`
- `Forma File Organizing/Views/Components/RuleDestinationPicker.swift`
- `Forma File Organizing/Views/NaturalLanguageRuleView.swift`

Mac-native constraints to preserve:

- Keep form ergonomics.
- Keep keyboard navigation and focus order.
- Preserve validation clarity.
- Preserve modal and inline-panel presentation modes.

Design target:

Rule name, `When`, and `Then` should form the main path. Category, impact, validation, and footer controls should support that path rather than becoming separate focal points.

### 6. Smart Rules Empty-State Density

**Absorbs:** Observation 7  
**Intent:** Make the empty state feel ready to use instead of blank.

Primary anchor files:

- `Forma File Organizing/Views/RulesManagementView.swift`
- `Forma File Organizing/Components/RuleManagementCard.swift`

Mac-native constraints to preserve:

- Keep the empty state direct and accessible.
- Keep starter templates actionable.
- Avoid marketing-card treatment.

Design target:

Starter templates should be visible in the first viewport at normal window sizes, and the screen should read as "quick starts are available" rather than "there is nothing here."

### 7. Analytics Role Hierarchy

**Absorbs:** Observation 8  
**Intent:** Separate KPI hero cards, chart containers, and low-data states.

Primary anchor files:

- `Forma File Organizing/Views/ProductivityReportView.swift`
- `Forma File Organizing/Components/ImpactMetricCard.swift`
- `Forma File Organizing/Components/TreemapChart.swift`
- `Forma File Organizing/Components/StackedAreaChart.swift`
- `Forma File Organizing/Components/CalendarHeatmap.swift`

Mac-native constraints to preserve:

- Keep charts legible at default window size.
- Preserve period selector behavior.
- Keep no-data guidance actionable.

Design target:

The screen should scan in this order: headline, KPI row, chart explanation, details. Empty metrics should explain what will appear once the user has real data.

### 8. Settings Reunion and Accent Discipline

**Absorbs:** Observations 9 and 10  
**Intent:** Make Settings feel like Forma, not a separate utility shell.

Primary anchor files:

- `Forma File Organizing/Views/Settings/SettingsView.swift`
- `Forma File Organizing/Views/Settings/SettingsComponents.swift`
- `Forma File Organizing/Views/Settings/GeneralSettingsSection.swift`
- `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- `Forma File Organizing/DesignSystem/FormaColors.swift`

Mac-native constraints to preserve:

- Keep Settings scene conventions.
- Preserve tabbed preferences behavior.
- Keep controls standard where native controls are clearer than custom controls.

Design target:

Settings should share the same surface ladder, type rhythm, and accent discipline as the primary app window.

## Token and Component Anchors

Later implementation plans should start from these existing anchors instead of inventing parallel styling.

### Tokens

- Color and surface ladder: `Forma File Organizing/DesignSystem/FormaColors.swift`
- Typography: `Forma File Organizing/DesignSystem/FormaTypography.swift`
- Spacing and layout: `Forma File Organizing/DesignSystem/FormaSpacing.swift`, `Forma File Organizing/DesignSystem/FormaLayout.swift`
- Borders and shadows: `Forma File Organizing/DesignSystem/FormaBorders.swift`, `Forma File Organizing/DesignSystem/FormaShadows.swift`
- Motion: `Forma File Organizing/DesignSystem/FormaAnimation.swift`, `Forma File Organizing/DesignSystem/FormaEasing.swift`, `Forma File Organizing/DesignSystem/FormaMicroanimations.swift`

### Components

- Toolbar: `Forma File Organizing/Views/Components/UnifiedToolbar.swift`
- File surfaces: `Forma File Organizing/Views/Components/FileRow.swift`, `Forma File Organizing/Components/FileListRow.swift`, `Forma File Organizing/Components/FileGridItem.swift`
- File surface primitives: `Forma File Organizing/Components/Shared/FileSurfaceComponents.swift`, `Forma File Organizing/DesignSystem/FileSurfaceStyle.swift`
- Right rail: `Forma File Organizing/Views/DefaultPanelView.swift`, `Forma File Organizing/Views/RightPanelView.swift`
- Rule Builder: `Forma File Organizing/Views/RuleEditorView.swift`
- Smart Rules: `Forma File Organizing/Views/RulesManagementView.swift`, `Forma File Organizing/Components/RuleManagementCard.swift`
- Analytics: `Forma File Organizing/Views/ProductivityReportView.swift`, `Forma File Organizing/Components/ImpactMetricCard.swift`
- Settings: `Forma File Organizing/Views/Settings/SettingsView.swift`, `Forma File Organizing/Views/Settings/SettingsComponents.swift`

No token rename is implied by this brief. A later implementation plan may propose new tokens or changed values, but must justify them against this anchor list.

## Success Criteria

The following criteria are intentionally observable rather than numeric. Quantitative thresholds belong in the implementation plans.

- A user can identify sidebar, work surface, right rail, cards, and floating controls as separate layers at a glance.
- Primary screen titles are the first read on each screen.
- Secondary metadata recedes without disappearing.
- Blue accent appears predictably on primary actions, active selections, focus, and current-state indicators.
- Dense data screens feel calmer because ambient material is reduced or scoped.
- The right rail reads as the active command center for review work.
- File rows scan as filenames and destinations first, actions second.
- Rule Builder reads as one guided composition with clear `When` and `Then` anchors.
- Smart Rules empty state exposes starter templates without requiring the user to search for them.
- Analytics distinguishes KPI cards, chart containers, and zero-state guidance.
- Settings feels visually connected to the main app.

## Validation Checklist

Run this checklist against both light and dark mode after any implementation work based on this brief.

### Per-Screen Pass

For each primary screen, answer these questions:

- Does hierarchy read in the first two seconds?
- Is contrast spent on the right things?
- Does density feel intentional rather than cramped or empty?
- Are hover, focus, selection, loading, and disabled states legible?

Screens:

- Main review screen
- All Files list
- All Files grid
- Right rail default task panel
- Rule Builder
- Smart Rules empty state and populated state
- Analytics
- Settings: Rules, Folders, Smart Features, General, About
- Onboarding welcome, only if token changes affect it

### Global Pass

- Light mode and dark mode preserve the same hierarchy.
- Increased Contrast remains legible.
- Reduce Motion remains respected.
- Reduce Transparency has an acceptable fallback.
- Keyboard focus rings remain visible on every interactive element.
- Sidebar collapsed and expanded states preserve the surface ladder.
- Window resize does not collapse headings, buttons, or row metadata.
- Card, list, and grid file surfaces remain visually related.
- Primary CTAs remain unmistakable without shouting over data.

## Open Questions For The Agent Plan

These questions should be answered before implementation plans become executable.

1. Does the surface ladder add a new semantic token, or retune existing `formaSurface*` tokens?
2. Is committed blue a new accent value, or a re-spec of `formaSteelBlue`?
3. Does ambient material survive only on onboarding and empty states, or stay on dense screens at lower intensity?
4. Does the right rail current-task card become a distinct surface step, or stay flush with the rail while surrounding modules demote?
5. Does Rule Builder keep all current sections but restyle them, or collapse Category and Impact into lower-emphasis rows?
6. Does Smart Rules lead with the empty state or lead with starter templates?
7. Does Settings receive a full visual alignment pass or only targeted token/padding updates?
8. Should typography changes be global token changes or screen-specific overrides first?

## Agent Planning Handoff

The next artifact should be an implementation plan under `Docs/superpowers/specs/` or another explicitly approved planning location. It should not bundle every workstream into one branch.

Recommended plan shape:

- Start with Workstream 1 and Workstream 2 because surface and type changes affect everything else.
- Split file-surface work into card, list, grid, and shared primitives only if ownership remains clear.
- Keep Rule Builder, Analytics, Smart Rules, and Settings as separate follow-on plans unless token work makes them trivial.
- Assign each agent or subagent a disjoint write set.
- Require visual verification with current screenshots or live app captures for every workstream.
- Do not touch `forma-website/`.

## Out Of Brief

The following belong in later artifacts:

- Concrete token values
- Exact type sizes
- File-by-file patch plans
- Branch sequence
- Test commands
- Screenshots of proposed alternatives
- Acceptance screenshots
- Release notes

