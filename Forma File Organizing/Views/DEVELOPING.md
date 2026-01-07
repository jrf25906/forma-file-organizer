// Developing

This document captures a few architectural notes and conventions to help contributors navigate the project.

## Design System Usage

### Typography
Always use `FormaTypography` tokens instead of hardcoded font sizes:

```swift
// ✅ Good
Text("Title").font(.formaH1)
Text("Body").font(.formaBody)
Text("Caption").font(.formaCaption)

// ❌ Bad
Text("Title").font(Font.system(size: N, weight: .semibold))
```

**Available tokens:**
- **Headers:** `.formaHero` (32pt), `.formaH1` (24pt), `.formaH2` (20pt), `.formaH3` (17pt)
- **Body:** `.formaBodyLarge` (15pt), `.formaBody` (13pt), `.formaCompact` (12pt), `.formaSmall` (11pt), `.formaCaption` (10pt), `.formaMicro` (9pt)
- **Weight variants:** Add `Medium`, `Semibold`, `Bold` suffix (e.g., `.formaBodySemibold`)
- **Icons:** `.formaIcon` (48pt), `.formaIconLarge` (64pt)

### Opacity
Use `Color.FormaOpacity` tokens instead of hardcoded values:

```swift
// ✅ Good
Color.formaSteelBlue.opacity(Color.FormaOpacity.light)

// ❌ Bad
Color.formaSteelBlue.opacity(0.xx)
```

**Available tokens:** `.ultraSubtle` (0.02), `.subtle` (0.05), `.light` (0.10), `.medium` (0.20), `.overlay` (0.30), `.strong` (0.50), `.high` (0.70), `.prominent` (0.80)

### Spacing
Use `FormaSpacing` tokens:

```swift
// ✅ Good
.padding(FormaSpacing.standard)
HStack(spacing: FormaSpacing.tight)

// ❌ Bad
.padding(<points>)
```

**Available tokens:** `.micro` (4), `.tight` (8), `.standard` (16), `.generous` (24), `.spacious` (32), `.expansive` (48)

**Layout constants:** `FormaSpacing.Toolbar.topOffset` (64), `FormaSpacing.Card.minHeight` (120), `FormaSpacing.Breakpoints.compactWidth` (600)

### Shared Components
Use existing components from `FormaComponents.swift`:

- **Buttons:** `PrimaryButton`, `SecondaryButton`, `TertiaryButton`, `GhostButton`
- **Badges:** `FormaBadge`, `FormaStatBadge`
- **Actions:** `FormaListButton`
- **Icons:** `FormaHeroIcon`
- **Empty states:** `FormaEmptyState`

### Intentional Deviations
When a design requires a non-standard value (e.g., optical alignment), document it inline:

```swift
.font(Font.system(size: N, weight: .bold))  // If truly needed, add a FormaTypography token for it
```

---

## Environment and Dependency Injection

- `NavigationViewModel` is injected once at the `NavigationStack` level. All descendants, including those pushed via `.navigationDestination`, inherit it automatically.

  Example (DashboardView):
  ```swift
  NavigationStack(path: $nav.path) {
      // ... content ...
  }
  .environmentObject(nav)
  ```

---

## Suggestions System Architecture

The right panel's "Suggestions" section provides a unified mental model for two distinct AI-powered features:

### Overview

```
┌─────────────────────────────────────┐
│  SUGGESTIONS (unified header)       │
├─────────────────────────────────────┤
│  🔮 Smart Rules                     │  ← Learned behavioral patterns
│     "Move .pdf → Documents"         │     (persistent, automated)
│                                     │
│  ⚡ Quick Actions                   │  ← File grouping insights
│     "Organize Together →"           │     (one-time actions)
└─────────────────────────────────────┘
```

### Components

| Component | Data Source | Purpose |
|-----------|-------------|---------|
| `RuleSuggestionView` | `LearnedPattern` (SwiftData) | Display patterns learned from user behavior that can become permanent rules |
| `QuickActionCard` | `FileInsight` (InsightsService) | Display one-time file organization suggestions like "10 files from a recent work session" |

### Key Design Decisions

1. **Progressive Disclosure**: The "SUGGESTIONS" section only appears when there's content to show. No empty states are displayed - the section grows organically as the app learns.

2. **Unified Terminology**: Both features live under "SUGGESTIONS" but have distinct sub-labels:
   - "Smart Rules" emphasizes these become persistent automated rules
   - "Quick Actions" emphasizes these are immediate, one-time actions

3. **Self-Hiding Subsections**: Each subsection (`smartRulesSection`, `quickActionsSection`) handles its own visibility. If `LearnedPattern` query returns no suggestable patterns, `RuleSuggestionView` returns empty. If no insights exist, Quick Actions section is not rendered.

### Files

- `DefaultPanelView.swift` - Unified suggestions section (`suggestionsSection`)
- `RuleSuggestionView.swift` - Smart Rules subsection and pattern cards
- `QuickActionCard` (in DefaultPanelView) - Quick Actions card component
