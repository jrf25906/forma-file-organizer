# Organization Personality System

**Version:** 1.0
**Last Updated:** 2026-01-06

## Overview

The Organization Personality System is Forma's adaptive intelligence layer that personalizes the file organization experience based on how users naturally think about and manage their files. Instead of forcing users into rigid organizational systems, Forma adapts to their cognitive style through a brief personality assessment.

## Core Concept

The system recognizes that people organize files in fundamentally different ways:
- **Pilers** prefer visual, surface-level organization (files visible on Desktop)
- **Filers** prefer structured, hierarchical organization (deep folder structures)

The personality assessment captures three dimensions of organizational behavior and translates them into concrete system preferences.

---

## Personality Dimensions

### 1. Organization Style

How users prefer to organize files physically.

| Style | Description | Characteristics |
|-------|-------------|-----------------|
| **Piler** | Visual organizer | Prefers to see files on the surface (Desktop, Downloads), uses spatial memory, shallow hierarchies |
| **Filer** | Structured organizer | Prefers hidden, deep hierarchies, systematic filing, out of sight organization |

**Icon Representations:**
- Piler: `square.stack.3d.up`
- Filer: `folder.fill`

---

### 2. Thinking Style

How users mentally visualize their file structure.

| Style | Description | Characteristics |
|-------|-------------|-----------------|
| **Visual** | Needs to see everything | Everything visible at a glance, flat or moderate hierarchies, visual cues important |
| **Hierarchical** | Comfortable with nesting | Comfortable with nested structures, deep folder trees, logical categorization |

**Icon Representations:**
- Visual: `eye.fill`
- Hierarchical: `list.bullet.indent`

---

### 3. Mental Model

How users conceptually categorize their work.

| Model | Description | Use Cases |
|-------|-------------|-----------|
| **Project-Based** | Thinks in projects/clients | "This belongs to the Website Redesign project", "Client X files" |
| **Time-Based** | Organizes by time periods | "Last week's work", "Q4 2024 reports", chronological archives |
| **Topic-Based** | Categorizes by subject/type | "Marketing materials", "Financial documents", "Design assets" |

**Icon Representations:**
- Project-Based: `folder.badge.person.crop`
- Time-Based: `calendar`
- Topic-Based: `square.grid.2x2`

---

## Personality Assessment Quiz

### Quiz Flow

The personality quiz consists of **3 scenario-based questions** designed to reveal natural organizational behavior without requiring organizational theory knowledge.

#### Question 1: File Finding Behavior
**Prompt:** "When you can't find a file, what do you do?"

| Answer | Reveals | Mapping |
|--------|---------|---------|
| "Scan Desktop or Downloads visually" | Visual/surface organization | OrganizationStyle: **Piler**, ThinkingStyle: **Visual** |
| "Check Recent Files or use Search" | Tool-based approach | OrganizationStyle: **Filer**, ThinkingStyle: **Visual** |
| "Navigate through my folder structure" | Systematic organization | OrganizationStyle: **Filer**, ThinkingStyle: **Hierarchical** |

#### Question 2: Desktop State
**Prompt:** "Your Desktop right now is..."

| Answer | Reveals | Mapping |
|--------|---------|---------|
| "Covered with files I'm working on" | Surface-level organization | OrganizationStyle: **Piler** (confirmed) |
| "Has a few shortcuts, rest in folders" | Moderate organization | OrganizationStyle: **Filer** (moderate) |
| "Empty, everything is organized away" | Systematic filing | OrganizationStyle: **Filer** (strong) |

**Purpose:** Refines and confirms the OrganizationStyle from Q1.

#### Question 3: Work Conceptualization
**Prompt:** "When you organize work, you think in terms of..."

| Answer | Reveals | Mapping |
|--------|---------|---------|
| "Projects and clients" | Project-oriented thinking | MentalModel: **ProjectBased** |
| "Weeks, months, quarters" | Time-oriented thinking | MentalModel: **TimeBased** |
| "Categories and topics" | Topic-oriented thinking | MentalModel: **TopicBased** |

---

### Quiz UI Components

#### Answer Cards
- **Icon** (24px SF Symbol)
- **Primary text** (main answer)
- **Description** (subtle explanation)
- **Selection indicator** (checkmark.circle.fill)
- **Hover effect** (1.01 scale, border highlight)
- **Selection effect** (Steel Blue tint, background fill)

#### Progress Bar
- Gradient fill (Steel Blue → Sage)
- 6pt height, 4pt corner radius
- Smooth spring animation (response: 0.4, damping: 0.8)
- Shows "Question X of 3"

#### Result View
- Large emoji (72pt): ✨
- Personality title (32pt, bold)
- Template recommendation card
- Continue button (Sage green)

---

## Computed Personality Properties

Based on the 3 dimensions, Forma derives actionable preferences:

### 1. Suggested Template

Maps personality to the most appropriate organization template.

```swift
var suggestedTemplate: OrganizationTemplate {
    // Pilers prefer minimal systems
    if organizationStyle == .piler {
        return .minimal
    }

    // Filers with project thinking
    if organizationStyle == .filer && mentalModel == .projectBased {
        return .creativeProf
    }

    // Filers with time-based thinking
    if organizationStyle == .filer && mentalModel == .timeBased {
        return .chronological
    }

    // Filers with topic-based + hierarchical thinking
    if organizationStyle == .filer && mentalModel == .topicBased && thinkingStyle == .hierarchical {
        return .johnnyDecimal
    }

    // Default to PARA - good general-purpose system
    return .para
}
```

**Mapping Table:**

| Personality Combination | Suggested Template | Rationale |
|------------------------|-------------------|-----------|
| Piler + Any | **Minimal** | Shallow hierarchies, visual organization |
| Filer + ProjectBased | **Creative Professional** | Project-centric folders, client organization |
| Filer + TimeBased | **Chronological** | Date-based archives, temporal organization |
| Filer + TopicBased + Hierarchical | **Johnny Decimal** | Deep categorization, decimal system |
| Default | **PARA** | Balanced, general-purpose system |

---

### 2. Suggested Folder Depth

Controls how many nested levels are recommended.

| OrganizationStyle | ThinkingStyle | Depth | Example Structure |
|------------------|---------------|-------|-------------------|
| Piler | Any | **2** | `Desktop/Screenshots` |
| Filer | Visual | **3** | `Documents/Work/Reports` |
| Filer | Hierarchical | **5** | `Projects/Client/2024/Active/Documents` |

**Purpose:** Prevents overwhelming pilers with deep hierarchies, allows filers to create complex structures.

---

### 3. Preferred View Mode

Sets the initial file list view.

| OrganizationStyle | View Mode | Rationale |
|------------------|-----------|-----------|
| Piler | **Grid** | Visual thinkers prefer spatial layout, thumbnails |
| Filer | **List** | Detail-oriented, metadata-focused, efficient scanning |

**Implementation:**
```swift
// DashboardViewModel.swift:423
let preferredMode: ViewMode = personality.preferredViewMode == "grid" ? .grid : .list
```

---

### 4. Suggestions Frequency

Controls how often Forma shows rule suggestions.

| Personality | Frequency | Behavior |
|-------------|-----------|----------|
| Piler | **Frequent** | More guidance needed, less systematic |
| Hierarchical Filer | **Occasional** | Systematic users need less help |
| Default | **Moderate** | Balanced approach |

**Purpose:** Pilers benefit from more proactive suggestions, while systematic filers prefer minimal interruptions.

---

## Preset Personalities

Forma includes 4 common personality presets for testing and examples:

### 1. Default (Balanced)
```swift
OrganizationPersonality(
    organizationStyle: .filer,
    thinkingStyle: .visual,
    mentalModel: .projectBased
)
```
- **Suggested Template:** Creative Professional
- **View Mode:** List
- **Folder Depth:** 3

---

### 2. Creative
```swift
OrganizationPersonality(
    organizationStyle: .piler,
    thinkingStyle: .visual,
    mentalModel: .projectBased
)
```
- **Suggested Template:** Minimal
- **View Mode:** Grid
- **Folder Depth:** 2
- **Target User:** Designers, artists, visual thinkers

---

### 3. Academic
```swift
OrganizationPersonality(
    organizationStyle: .filer,
    thinkingStyle: .hierarchical,
    mentalModel: .topicBased
)
```
- **Suggested Template:** Johnny Decimal
- **View Mode:** List
- **Folder Depth:** 5
- **Target User:** Researchers, students, librarians

---

### 4. Business
```swift
OrganizationPersonality(
    organizationStyle: .filer,
    thinkingStyle: .hierarchical,
    mentalModel: .timeBased
)
```
- **Suggested Template:** Chronological
- **View Mode:** List
- **Folder Depth:** 3
- **Target User:** Executives, accountants, compliance professionals

---

## Personality Titles

The result view displays a human-friendly personality title:

| OrganizationStyle | ThinkingStyle | Title |
|------------------|---------------|-------|
| Piler | Visual | **Visual Organizer** |
| Piler | Hierarchical | **Flexible Organizer** |
| Filer | Visual | **Structured Organizer** |
| Filer | Hierarchical | **Systematic Organizer** |

---

## Storage & Persistence

### AppStorage Integration

Personality data is persisted using `UserDefaults` with JSON encoding:

```swift
// Storage key
static let storageKey = "userOrganizationPersonality"

// Save personality
func save() {
    if let encoded = try? JSONEncoder().encode(self) {
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }
}

// Load personality
static func load() -> OrganizationPersonality? {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let personality = try? JSONDecoder().decode(OrganizationPersonality.self, from: data) else {
        return nil
    }
    return personality
}

// Clear saved personality
static func clear() {
    UserDefaults.standard.removeObject(forKey: storageKey)
}
```

**When Saved:**
- After quiz completion in `Views/PersonalityQuizView.swift`
- When onboarding applies the selected template

**When Loaded:**
- `Views/TemplateSelectionView.swift` - Pre-selects suggested template
- `ViewModels/FilterViewModel.swift` - Applies preferred view modes
- Any view that needs personality context

---

## Integration with Onboarding

The personality quiz is **Step 3 of 5** in the onboarding flow:

### Onboarding Flow
1. **Welcome** - Value proposition
2. **Folders** - Select folders to organize (Desktop, Downloads, etc.)
3. **Quiz** ← Personality assessment
4. **Template** - Apply organization system (personality-aware)
5. **Preview** - Confirm folder structure before completion

### QuizStepView Integration

```swift
// Views/Onboarding/PersonalityQuizStepView.swift
struct PersonalityQuizStepView: View {
    let onComplete: (OrganizationPersonality) -> Void
    let onBack: () -> Void

    var body: some View {
        PersonalityQuizView(
            onComplete: onComplete,
            onBack: onBack,
            showStepIndicator: false
        )
    }
}
```

**Flow:**
1. User completes personality quiz
2. `onComplete` callback receives `OrganizationPersonality`
3. `selectedTemplate` is automatically set to `personality.suggestedTemplate`
4. Flow advances to Template Selection step
5. Template view shows "Based on your style, we recommend..." message

---

## Integration with Template Selection

### Pre-Selection Logic

```swift
// TemplateSelectionView.swift:20
init(selectedTemplate: Binding<OrganizationTemplate>, onSelect: @escaping (OrganizationTemplate) -> Void) {
    self._selectedTemplate = selectedTemplate
    self.onSelect = onSelect

    // Pre-select template based on personality if available
    if let personality = OrganizationPersonality.load() {
        // Only apply personality preference if user hasn't explicitly chosen yet
        if selectedTemplate.wrappedValue == .minimal {
            selectedTemplate.wrappedValue = personality.suggestedTemplate
        }
    }
}
```

### Recommendation Display

```swift
// TemplateSelectionView.swift:119
private var headerSubtitle: String {
    if let personality = OrganizationPersonality.load() {
        return "Based on your preferences, we recommend \(personality.suggestedTemplate.displayName).
                You can choose any system below or change it later."
    }
    return "Select a proven organization method that matches your workflow.
            You can always change this later or create custom rules."
}
```

**Visual Indicator:**
- Recommended template shows "Recommended" badge (Sage green capsule)
- Template card is pre-selected (Steel Blue border)
- User can still choose any other template

---

## Integration with Dashboard

### View Mode Initialization

```swift
// DashboardViewModel.swift:423
let preferredMode: ViewMode = personality.preferredViewMode == "grid" ? .grid : .list
```

**Effect:**
- Pilers see **Grid View** by default (visual, spatial layout)
- Filers see **List View** by default (detailed, metadata-focused)
- User can manually toggle view mode anytime

### Future Adaptive Behaviors

The personality system is designed to support future intelligent features:

| Planned Feature | How Personality Adapts |
|----------------|------------------------|
| **Rule Suggestions** | Pilers get more frequent prompts, Filers get occasional suggestions |
| **Folder Depth Warnings** | Warn Pilers when creating deep hierarchies, allow Filers deeper structures |
| **Automation Level** | Pilers get "Review First" mode by default, Filers can use auto-organize |
| **Visual Complexity** | Pilers see simplified UI, Filers see detailed metadata |
| **Tutorial Content** | Personalized onboarding tips based on style |

---

## User Experience Design

### Quiz Design Principles

1. **Scenario-Based Questions**
   - Ask about real behavior, not abstract preferences
   - "What do you do?" instead of "What do you prefer?"
   - Example: "Your Desktop right now is..." (observable) vs. "How organized are you?" (subjective)

2. **Visual Clarity**
   - Large emoji for emotional connection (48-72pt)
   - Icon + Text + Description for each answer
   - Progress bar with gradient (Steel Blue → Sage)

3. **No Wrong Answers**
   - All personality types are valid and supported
   - Positive framing: "Visual Organizer" not "Disorganized User"
   - Celebrate result with ✨ emoji and encouraging copy

4. **Transparent Mapping**
   - Show recommended template immediately
   - Explain "Based on your style, we recommend..."
   - Allow users to override recommendation

5. **Reduce Motion Support**
   - Animations respect `accessibilityReduceMotion`
   - Scale effects disabled for motion-sensitive users
   - Smooth, gentle animations (0.4s spring, 0.8 damping)

---

## Testing

### Unit Tests

**File:** `Forma File OrganizingTests/OrganizationPersonalityTests.swift`

Key test scenarios:
1. **Piler Personality**
   - Expects minimal template, grid view, depth 2
   ```swift
   XCTAssertEqual(personality.suggestedTemplate, .minimal)
   XCTAssertEqual(personality.preferredViewMode, "grid")
   XCTAssertEqual(personality.suggestedFolderDepth, 2)
   ```

2. **Hierarchical Filer Personality**
   - Expects Johnny Decimal template, list view, depth 5
   ```swift
   XCTAssertEqual(personality.suggestedTemplate, .johnnyDecimal)
   XCTAssertEqual(personality.preferredViewMode, "list")
   XCTAssertEqual(personality.suggestedFolderDepth, 5)
   ```

3. **Time-Based Filer Personality**
   - Expects Chronological template
   ```swift
   XCTAssertEqual(personality.suggestedTemplate, .chronological)
   ```

### Manual Testing Checklist

- [ ] Quiz displays all 3 questions correctly
- [ ] Answer cards respond to hover states
- [ ] Progress bar animates smoothly
- [ ] Quiz calculation maps to correct personality
- [ ] Result view shows correct personality title
- [ ] Result view shows correct recommended template
- [ ] Template selection pre-selects recommended template
- [ ] Template selection shows "Based on your style..." message
- [ ] Dashboard respects preferredViewMode
- [ ] Personality persists after app restart
- [ ] Back button works on all quiz steps
- [ ] Reduce Motion setting disables animations

---

## Implementation Files

| File | Purpose |
|------|---------|
| `Models/OrganizationPersonality.swift` | Core personality model with enums and computed properties |
| `Views/PersonalityQuizView.swift` | Interactive quiz UI with 3 questions and result view |
| `Views/Onboarding/OnboardingFlowView.swift` | Onboarding integration (5-step flow) |
| `Views/Onboarding/PersonalityQuizStepView.swift` | Quiz step wrapper for onboarding |
| `Views/TemplateSelectionView.swift` | Personality-aware template selection |
| `ViewModels/FilterViewModel.swift` | View mode preference application |
| `Forma File OrganizingTests/OrganizationPersonalityTests.swift` | Unit tests |

---

## API Reference

### OrganizationPersonality

```swift
struct OrganizationPersonality: Codable, Equatable {
    // Personality dimensions
    var organizationStyle: OrganizationStyle   // Piler or Filer
    var thinkingStyle: ThinkingStyle           // Visual or Hierarchical
    var mentalModel: MentalModel               // ProjectBased, TimeBased, or TopicBased

    // Computed properties
    var suggestedTemplate: OrganizationTemplate
    var suggestedFolderDepth: Int
    var preferredViewMode: String              // "grid" or "list"
    var suggestionsFrequency: SuggestionsFrequency

    // Persistence
    static let storageKey: String
    func save()
    static func load() -> OrganizationPersonality?
    static func clear()

    // Presets
    static let `default`: OrganizationPersonality
    static let creative: OrganizationPersonality
    static let academic: OrganizationPersonality
    static let business: OrganizationPersonality
}
```

### OrganizationStyle

```swift
enum OrganizationStyle: String, Codable, CaseIterable {
    case piler = "Piler"
    case filer = "Filer"

    var description: String
    var icon: String
}
```

### ThinkingStyle

```swift
enum ThinkingStyle: String, Codable, CaseIterable {
    case visual = "Visual"
    case hierarchical = "Hierarchical"

    var description: String
    var icon: String
}
```

### MentalModel

```swift
enum MentalModel: String, Codable, CaseIterable {
    case projectBased = "Project-Based"
    case timeBased = "Time-Based"
    case topicBased = "Topic-Based"

    var description: String
    var icon: String
}
```

### PersonalityQuizView

```swift
struct PersonalityQuizView: View {
    let onComplete: (OrganizationPersonality) -> Void
    var onBack: (() -> Void)?
    var showStepIndicator: Bool = true
}
```

---

## Future Enhancements

### Planned Features

1. **Adaptive Rule Suggestions**
   - Frequency based on `suggestionsFrequency` property
   - Pilers get more proactive rule creation prompts
   - Filers get minimal, high-value suggestions

2. **Personality Evolution**
   - Track user behavior over time (manual overrides, rule creation patterns)
   - Optionally update personality based on usage
   - "We noticed you prefer deeper folders now. Update your style?"

3. **Multi-Personality Profiles**
   - Work vs Personal organization styles
   - Switch contexts: "I'm organizing work files" vs "I'm organizing photos"
   - Different templates per folder/context

4. **Advanced Quiz Questions** (Optional)
   - "How do you name files?" (descriptive vs dates vs codes)
   - "How often do you archive?" (frequency → timeBased affinity)
   - "Do you duplicate files or use references?" (structure preference)

5. **Personality Analytics**
   - Show users their organization patterns over time
   - "You've created 12 rules, mostly project-based. Consider PARA template?"
   - Insights dashboard based on personality

---

## Design Philosophy

The Personality System embodies Forma's core principle: **Adapt to the user, not the other way around.**

### Key Insights

1. **Cognitive Load Reduction**
   - Users shouldn't need to understand organizational theory
   - Quiz asks about behavior, not abstract preferences
   - System translates behavior into optimal configuration

2. **Respectful Intelligence**
   - All personality types are equally valid
   - No "correct" way to organize files
   - Recommendations, not mandates

3. **Progressive Enhancement**
   - Works without personality data (sensible defaults)
   - Improves experience when personality is known
   - Doesn't block core functionality

4. **Transparent Adaptation**
   - Users see "Based on your style, we recommend..."
   - Can always override personality-based suggestions
   - Clear cause-and-effect relationship

---

## Accessibility

### VoiceOver Support

- All quiz questions have proper labels
- Answer cards announce selection state
- Progress bar reads "Question 2 of 3, 66% complete"
- Result view announces personality title and template

### Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.scaleEffect(isHovered && !reduceMotion ? 1.01 : 1.0)
.animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
```

### Keyboard Navigation

- Tab through answer options
- Enter/Space to select answer
- Arrow keys to navigate between questions (future)

---

## Related Documentation

- [Organization Templates](OrganizationTemplates.md) - 8 pre-built organization systems
- [Onboarding Flow](../Design/Forma-Onboarding-Flow.md) - Full 5-step onboarding (personality quiz is Step 3)
- [Rule Engine](../Architecture/RuleEngine-Architecture.md) - How personality affects rule suggestions
- [Design System](../Design/DesignSystem.md) - UI components used in quiz
- [Dashboard Architecture](../Architecture/DASHBOARD.md) - Post-onboarding main interface

---

*This document describes the Personality System as of 2026-01-06. The system is designed to evolve with user feedback and behavioral data.*
