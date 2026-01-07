# Forma Feature Development Plan

> Comprehensive analysis of 6 feature opportunities based on competitive analysis and codebase evaluation.
>
> **Created:** November 30, 2025
> **Status:** Planning Complete - Ready for Implementation

---

## Executive Summary

Based on deep analysis of the Forma codebase and the competitive analysis document, this plan evaluates 6 feature opportunities that would differentiate Forma from competitors like Hazel, Sparkle, and Sorted.

**Key Finding:** The Forma codebase is **well-architected for extension**—the protocol-based design, type-safe `RuleCondition` enum, and existing `InsightsService` provide strong foundations for all proposed features.

---

## Feature Analysis Matrix

| Feature | Difficulty | Time Estimate | Differentiation | Dependencies | Priority |
|---------|------------|---------------|-----------------|--------------|----------|
| **1. Explanation of Reasoning** | Low | 1-2 days | Medium | None | **#1** |
| **2. Organization Templates** | Medium | 3-5 days | High | None | **#2** |
| **3. Learning from User Corrections** | Medium | 4-6 days | High | ActivityItem | **#3** |
| **4. Personality Onboarding Quiz** | Medium | 3-4 days | High | Templates (#2) | **#4** |
| **5. Enhanced Review/Approval** | Medium | 4-5 days | High | Explanations (#1) | **#5** |
| **6. Smart Context Detection** | High | 6-8 days | High | Learning (#3) | **#6** |

**Total Estimated Time:** 25-34 days for all features

---

## Detailed Feature Specifications

---

### Feature 1: Explanation of Reasoning

**Priority:** #1 (Start Here)
**Difficulty:** Low
**Time Estimate:** 1-2 days
**Dependencies:** None

#### Overview

Show users *why* a file was matched to a rule, building trust and helping them refine their organization system.

#### Current State

| Aspect | Status |
|--------|--------|
| `naturalLanguageDescription` on Rule | ✅ Exists |
| `conditionDescription(for:)` method | ✅ Exists |
| UI showing which attribute matched which condition | ❌ Missing |
| Explanation shown in review workflow | ❌ Missing |

#### Technical Notes

The `Rule` model already has `naturalLanguageDescription` (Rule.swift:615-647) which generates human-readable explanations. The `RuleCondition` enum provides structured data to explain exactly what matched. **This feature is ~70% built already.**

#### Implementation Plan

1. Add `matchReason: String?` computed property to `FileItem` model
2. Extend `RuleEngine.evaluateFile()` to return reason when matched
3. Display reason in `FileRow` component (tooltip or expandable section)
4. Show detailed explanation in `FileInspectorView` when file selected

#### Files to Modify

- `Services/RuleEngine.swift` - Add reason generation
- `Views/Components/FileRow.swift` - Display reason
- `Views/FileInspectorView.swift` - Show in detail view

#### Differentiation

- AI File Sorter has basic "category" labels but no detailed reasoning
- Sparkle has no explanation at all
- **Builds trust and enables user refinement**

---

### Feature 2: Organization System Templates

**Priority:** #2
**Difficulty:** Medium
**Time Estimate:** 3-5 days
**Dependencies:** None

#### Overview

Offer pre-built rule sets based on proven organization methods (PARA, Johnny Decimal, Creative Professional, Minimal).

#### Current State

| Aspect | Status |
|--------|--------|
| `RuleService.seedDefaultRules()` pattern | ✅ Exists |
| Research defining template systems | ✅ Complete (File-Organization-Research.md) |
| 30+ rules documented | ✅ Complete (Forma-Rule-Library.md) |
| UI for template selection | ❌ Missing |
| Multiple template options | ❌ Only Creative Professional |

#### Technical Notes

The `RuleService.seedDefaultRules()` pattern (RuleService.swift:42-82) already creates 18 default rules. The architecture is ready—just need multiple "template packs" and a selection UI.

#### Template Definitions

##### PARA Method
```
Projects/       → Active work with deadlines
Areas/          → Ongoing responsibilities
Resources/      → Reference materials
Archive/        → Completed/inactive items
```
**Rules:** Auto-archive after 6 months inactive, project detection by naming

##### Johnny Decimal Lite
```
10-19 Finance/
20-29 Work/
30-39 Personal/
40-49 Creative/
50-59 Reference/
```
**Rules:** Numeric prefix detection, category-based routing

##### Creative Professional
```
Clients/
  └── {Client}/
      └── {Project}/
          ├── Active/
          ├── Delivered/
          └── Archive/
```
**Rules:** Client/project detection, status-based organization

##### Minimal
```
Inbox/          → Temporary landing zone
Keep/           → Permanent storage
Archive/        → Old items
```
**Rules:** Age-based archiving, simple categorization

#### Implementation Plan

1. Create `OrganizationTemplate` enum with cases: `.para`, `.creativeProf`, `.johnnyDecimal`, `.minimal`, `.custom`
2. Add `seedTemplateRules(template:)` method to `RuleService`
3. Create `TemplateSelectionView` for onboarding and settings
4. Add folder structure creation for each template
5. Store user's selected template in `AppStorage`

#### Files to Create/Modify

- `Models/OrganizationTemplate.swift` - New enum + rule definitions
- `Services/RuleService.swift` - Add template seeding
- `Views/TemplateSelectionView.swift` - New selection UI
- `Views/PermissionsOnboardingView.swift` - Add template step
- `Views/Settings/SettingsView.swift` - Add template management

#### Differentiation

- **No competitor offers this** - unique differentiator
- Instant value without configuration
- Educational component builds user expertise

---

### Feature 3: Learning from User Corrections

**Priority:** #3
**Difficulty:** Medium
**Time Estimate:** 4-6 days
**Dependencies:** Existing `ActivityItem` system

#### Overview

When users manually move files or reject suggestions, convert those actions into permanent rules automatically.

#### Current State

| Aspect | Status |
|--------|--------|
| `ActivityItem` tracks moves with extension + destination | ✅ Exists |
| `InsightsService` detects patterns | ✅ Basic (3+ files → same destination) |
| "Create Rule" button in insights | ✅ Exists |
| Auto-rule creation from patterns | ❌ Missing |
| Tracking of rejected suggestions | ❌ Missing |
| Confidence scoring | ❌ Missing |

#### Technical Notes

The `InsightsService.detectRuleOpportunities()` (InsightsService.swift:153-179) already analyzes `ActivityItem` history and detects when 3+ files of the same extension were moved to the same destination. **The learning infrastructure exists—need to close the loop.**

#### Learning Algorithm

```
Pattern Detection:
1. Group activities by file extension
2. For each extension group:
   - Find destination patterns
   - Calculate frequency (occurrences / total)
   - If frequency > 70% AND count >= 3: HIGH confidence
   - If frequency > 50% AND count >= 3: MEDIUM confidence

Rule Suggestion:
- "You moved 5 PDF files to Documents/Finance"
- "Create a rule to automate this?"
- One-click conversion to permanent rule

Rejection Learning:
- Track when user rejects a suggestion
- Lower confidence for that pattern
- If rejected 3+ times, suppress suggestion
```

#### Implementation Plan

1. Add `rejectedDestination: String?` to `FileItem` to track rejects
2. Create `LearnedPattern` model to store detected patterns with confidence
3. Enhance `InsightsService` to generate rule suggestions with confidence %
4. Add `RuleSuggestionView` that shows learned patterns
5. Implement one-click conversion: pattern → rule
6. Track rejection rate per suggestion to improve over time

#### Files to Create/Modify

- `Models/LearnedPattern.swift` - New pattern model
- `Models/FileItem.swift` - Add rejection tracking
- `Services/InsightsService.swift` - Enhanced pattern detection
- `Services/LearningService.swift` - New service for rule inference
- `Views/RuleSuggestionView.swift` - UI for learned patterns

#### Differentiation

- **No competitor learns from user behavior**
- Reduces repeated manual work
- System gets smarter without user effort
- More efficient than continuous AI calls

---

### Feature 4: Personality Onboarding Quiz

**Priority:** #4
**Difficulty:** Medium
**Time Estimate:** 3-4 days
**Dependencies:** Templates (#2) for full impact

#### Overview

Ask users about their working style during onboarding to customize the experience (piler vs filer, visual vs hierarchical).

#### Current State

| Aspect | Status |
|--------|--------|
| Research on personality dimensions | ✅ Complete (File-Organization-Research.md) |
| `PermissionsOnboardingView` as flow model | ✅ Exists |
| `AppStorage` pattern for preferences | ✅ Exists |
| Personality questions in onboarding | ❌ Missing |
| Preference-based customization | ❌ Missing |

#### Personality Dimensions

Based on research in `File-Organization-Research.md`:

| Dimension | Option A | Option B |
|-----------|----------|----------|
| Organization Style | Piler (visual, flat) | Filer (hidden, deep) |
| Thinking Style | Visual (see everything) | Hierarchical (structured) |
| Mental Model | Project-based | Time-based | Topic-based |

#### Quiz Questions

```
Question 1: "When you can't find a file, do you..."
  A) Scan visually through recent items (Piler)
  B) Navigate through your folder structure (Filer)

Question 2: "Do you prefer files..."
  A) Visible on your desktop where you can see them (Piler)
  B) Tucked away in organized folders (Filer)

Question 3: "How do you think about your work?"
  A) By project or client
  B) By topic or file type
  C) By time period (this week, last month)
```

#### Preference Application

| Preference | Effect |
|------------|--------|
| Piler | Suggest Minimal template, shallow folders, grid view default |
| Filer | Suggest PARA/Johnny Decimal, deep hierarchy, list view default |
| Project-based | Emphasize client/project folder structure |
| Time-based | Emphasize date-based organization |
| Topic-based | Emphasize file-type organization |

#### Implementation Plan

1. Create `OrganizationPersonality` model with dimensions
2. Add `PersonalityQuizView` with 3-4 questions
3. Store preferences in `AppStorage`/`UserDefaults`
4. Use preferences to:
   - Auto-select default template
   - Customize folder depth suggestions
   - Set default UI preferences (grid vs list)

#### Files to Create/Modify

- `Models/OrganizationPersonality.swift` - New preference model
- `Views/PersonalityQuizView.swift` - Quiz UI
- `Views/PermissionsOnboardingView.swift` - Integrate into flow
- `ViewModels/DashboardViewModel.swift` - Apply preferences

#### Differentiation

- **Unique to Forma** - no competitor personalizes
- Creates emotional connection during onboarding
- Reduces setup friction
- Demonstrates product intelligence

---

### Feature 5: Enhanced Review/Approval Workflow

**Priority:** #5
**Difficulty:** Medium
**Time Estimate:** 4-5 days
**Dependencies:** Explanations (#1) for full impact

#### Overview

Improve the file review experience with confidence indicators, explanations, batch actions, and inline rule creation.

#### Current State

| Aspect | Status |
|--------|--------|
| Basic review workflow (scan, suggest, approve, skip) | ✅ Exists |
| Batch "Organize All" action | ✅ Exists |
| File selection with multi-select | ✅ Exists |
| Explanation of why files matched | ❌ Missing |
| Inline rule creation from review | ❌ Missing |
| Confidence indicators | ❌ Missing |

#### Enhanced Review UI Design

```
┌─────────────────────────────────────────────────────┐
│ invoice_march_2024.pdf                              │
│ → Documents/Finance/Invoices                        │
│                                                     │
│ 🎯 High confidence                                  │
│ "Name contains 'invoice' AND Extension is 'pdf'"   │
│                                                     │
│ [✓ Accept] [✗ Skip] [⚡ Create Rule] [✎ Change]    │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ random_file_v2.docx                                 │
│ → Documents/Work (suggested)                        │
│                                                     │
│ ⚠️ Low confidence                                   │
│ "Extension is 'docx' (generic match)"              │
│                                                     │
│ [✓ Accept] [✗ Skip] [📁 Choose Folder]             │
└─────────────────────────────────────────────────────┘
```

#### Confidence Scoring

| Confidence | Criteria |
|------------|----------|
| High (90%+) | Multiple conditions matched, user has confirmed similar before |
| Medium (60-89%) | Single strong condition (extension + keyword) |
| Low (<60%) | Generic match (extension only), no prior confirmation |

#### Implementation Plan

1. Add confidence calculation to `RuleEngine.evaluateFile()`
2. Return confidence score alongside suggestion
3. Show confidence indicator in `FileRow` component
4. Add reasoning tooltip (builds on Feature #1)
5. Add "Create rule from this" quick action
6. Group files by suggested destination for batch review
7. Add "Similar files" preview before bulk confirm

#### Files to Modify

- `Services/RuleEngine.swift` - Add confidence calculation
- `Views/ReviewView.swift` - Enhanced layout with grouping
- `Views/Components/FileRow.swift` - Add confidence indicator
- `ViewModels/ReviewViewModel.swift` - Support confidence data
- `Views/Components/ConfidenceIndicator.swift` - New component

#### Differentiation

- AI File Sorter has review but poor UX
- Sparkle has no review (fully automatic)
- **Trust through transparency**
- Empowers informed decision-making

---

### Feature 6: Smart Context Detection

**Priority:** #6
**Difficulty:** High
**Time Estimate:** 6-8 days
**Dependencies:** Learning (#3) for pattern infrastructure

#### Overview

Proactively detect project-related files and suggest groupings based on naming patterns, temporal relationships, and semantic connections.

#### Current State

| Aspect | Status |
|--------|--------|
| `InsightsService` pattern detection | ✅ Basic |
| `FileItem` metadata (dates, size, extension) | ✅ Exists |
| Project code detection | ❌ Missing |
| "Modified together" tracking | ❌ Missing |
| Semantic grouping | ❌ Missing |

#### Detection Algorithms

##### 1. Project Code Detection
```swift
// Regex patterns for common project naming
let patterns = [
    "P-\\d{4}",           // P-1024
    "CLIENT_[A-Z]+",       // CLIENT_ABC
    "\\d{4}-\\d{2}-\\d{2}", // 2024-03-15 (date-based)
    "[A-Z]{3}-\\d{3}",     // ABC-123 (ticket numbers)
]

// Example matches:
"P-1024_design_v2.psd"     → Project "P-1024"
"CLIENT_ABC_invoice.pdf"   → Client "ABC"
"JIRA-456_bugfix.swift"    → Ticket "JIRA-456"
```

##### 2. Temporal Clustering
```swift
// Files edited within 5 minutes of each other
// likely belong to same work session

struct TemporalCluster {
    let files: [FileItem]
    let sessionStart: Date
    let sessionEnd: Date
}

// Detection:
// - Sort files by modification date
// - Group files where gap < 5 minutes
// - Clusters with 3+ files are significant
```

##### 3. Name Similarity Detection
```swift
// Levenshtein distance or common prefix detection

"proposal_draft.docx"   ─┐
"proposal_final.docx"   ─┼── Same document, different versions
"proposal_v2.docx"      ─┘

"screenshot_1.png"      ─┐
"screenshot_2.png"      ─┼── Related screenshots
"screenshot_3.png"      ─┘
```

#### Implementation Plan

1. Create `ProjectCluster` model to represent detected groupings
2. Implement `ContextDetectionService` with:
   - Regex-based project code detection
   - Temporal clustering algorithm
   - Name similarity analysis
3. Integrate clusters into `InsightsService`
4. Create `ProjectClusterView` UI component
5. Add one-click action: "Create project folder + move all"
6. Surface in dashboard: "12 files seem related to Project ABC"

#### Files to Create/Modify

- `Models/ProjectCluster.swift` - New grouping model
- `Services/ContextDetectionService.swift` - New detection service
- `Services/InsightsService.swift` - Integrate cluster insights
- `Views/ProjectClusterView.swift` - UI for cluster management
- `Views/Components/ClusterCard.swift` - Cluster display component

#### Differentiation

- **No competitor has this capability**
- Moves beyond file-by-file to project-level thinking
- High perceived intelligence
- Significant time savings for users

---

## Implementation Roadmap

### Phase 1: Quick Wins (Week 1)

```
Day 1-2: Feature #1 - Explanation of Reasoning
         └── Foundation for trust and transparency

Day 3-7: Feature #2 - Organization Templates
         └── Unique differentiator, high impact
```

**Milestone:** Users can select organization system + see why files match rules

### Phase 2: Personalization (Week 2)

```
Day 8-11: Feature #4 - Personality Quiz
          └── Uses templates, creates connection

Day 12-16: Feature #5 - Enhanced Review
           └── Uses explanations, improves core workflow
```

**Milestone:** Personalized onboarding + transparent review workflow

### Phase 3: Intelligence (Week 3-4)

```
Day 17-22: Feature #3 - Learning from Corrections
           └── Enables smart features, foundational

Day 23-30: Feature #6 - Smart Context Detection
           └── Most advanced, uses learning infrastructure
```

**Milestone:** Self-improving system with project-level intelligence

---

## Architecture Considerations

### Existing Strengths to Leverage

| Component | How It Helps |
|-----------|--------------|
| `RuleCondition` enum | Type-safe foundation for explanations |
| `ActivityItem` model | History tracking for learning |
| `InsightsService` | Pattern detection infrastructure |
| Protocol-based design | Easy to extend without breaking changes |
| `AppStorage` pattern | Simple preference storage |

### New Components Required

| Component | Features Using It |
|-----------|-------------------|
| `OrganizationTemplate` | #2 Templates, #4 Personality |
| `LearnedPattern` | #3 Learning |
| `OrganizationPersonality` | #4 Personality |
| `ProjectCluster` | #6 Context Detection |
| `ContextDetectionService` | #6 Context Detection |
| `LearningService` | #3 Learning |

### Data Model Extensions

```swift
// FileItem additions
extension FileItem {
    var matchReason: String?        // Feature #1
    var rejectedDestination: String? // Feature #3
    var confidenceScore: Double?    // Feature #5
}

// New models
struct LearnedPattern { }           // Feature #3
struct ProjectCluster { }           // Feature #6
enum OrganizationTemplate { }       // Feature #2
struct OrganizationPersonality { }  // Feature #4
```

---

## Success Metrics

### Feature #1: Explanation of Reasoning
- User engagement with explanation tooltips
- Reduction in "skip" actions (users understand suggestions better)

### Feature #2: Organization Templates
- Template selection rate during onboarding
- Template completion rate (users keep using selected system)

### Feature #3: Learning from Corrections
- Rules created from suggestions vs manual creation
- Reduction in repeated manual moves

### Feature #4: Personality Quiz
- Quiz completion rate
- Correlation between personality + template selection

### Feature #5: Enhanced Review
- Time spent in review (should decrease)
- Batch action usage rate
- User confidence in accepting suggestions

### Feature #6: Smart Context Detection
- Project clusters detected per user
- Cluster acceptance rate
- Files organized via cluster suggestions

---

## Risk Assessment

| Feature | Risk | Mitigation |
|---------|------|------------|
| #1 Explanations | Low | Leverages existing code |
| #2 Templates | Medium - User confusion | Clear descriptions, preview |
| #3 Learning | Medium - False positives | Confidence thresholds, user confirmation |
| #4 Personality | Low - Optional feature | Skip option, change later |
| #5 Review | Medium - UI complexity | Progressive disclosure |
| #6 Context | High - Algorithm accuracy | Conservative thresholds, easy dismiss |

---

## Appendix: Competitive Positioning

### Feature Gap Analysis vs Competitors

| Feature | Hazel | Sparkle | Sorted | AI File Sorter | **Forma** |
|---------|-------|---------|--------|----------------|-----------|
| Explanations | ❌ | ❌ | ❌ | Basic | ✅ Full |
| Templates | ❌ | ❌ | ❌ | ❌ | ✅ |
| Learning | ❌ | ❌ | ❌ | ❌ | ✅ |
| Personality Quiz | ❌ | ❌ | ❌ | ❌ | ✅ |
| Review Workflow | Manual only | None (auto) | None | Basic | ✅ Enhanced |
| Context Detection | ❌ | ❌ | ❌ | ❌ | ✅ |

### Unique Value Proposition

> "Forma is the intelligent file organizer that learns your style, suggests proven systems, and lets you stay in control."

**Key Differentiators:**
1. **Adaptive Intelligence** - Learns from your behavior
2. **Template-Based** - Pre-configured proven systems
3. **Conversational UX** - Suggestions + explanations
4. **Hybrid Learning** - AI suggestions become permanent rules
5. **Review-First** - Always ask before moving
6. **Context-Aware** - Understands projects, not just files

---

## Next Steps

1. [ ] Review and approve this plan
2. [ ] Prioritize Phase 1 features for immediate implementation
3. [ ] Create detailed technical specs for Feature #1
4. [ ] Begin implementation

---

## Future Roadmap

After completing the v1.x features above, see the **v2.0 Cloud Storage Integration** roadmap for the next major release:

| Version | Focus | Documentation |
|---------|-------|---------------|
| v1.x | Local file organization, templates, learning | This document |
| **v2.0** | **iCloud Drive integration** | [V2-Cloud-Storage-Integration.md](../Roadmap/V2-Cloud-Storage-Integration.md) |
| v2.1 | Dropbox + Google Drive | [V2-Cloud-Storage-Integration.md](../Roadmap/V2-Cloud-Storage-Integration.md) |
| v2.2 | OneDrive + cross-cloud moves | [V2-Cloud-Storage-Integration.md](../Roadmap/V2-Cloud-Storage-Integration.md) |

The v2.0 roadmap covers:
- CloudStorageProtocol abstraction layer
- iCloud Drive via NSFileCoordinator
- OAuth flows for third-party clouds
- Cross-cloud file operations
- Sync conflict resolution

---

*Document generated from codebase analysis and competitive research.*
