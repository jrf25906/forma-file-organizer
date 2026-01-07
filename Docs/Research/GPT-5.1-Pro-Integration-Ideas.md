# GPT-5.1 Pro Integration Ideas

**Author:** GPT-5.1 Pro  
**Date:** December 2025  
**Status:** Concept / Future Work  

This document captures potential ways to integrate GPT-5.1 Pro into Forma while respecting the existing architecture, local‑first AI design, and feature‑flag pattern.

All cloud/LLM features should:
- Be clearly labeled as cloud-assisted (unlike current fully on-device AI).
- Respect the master AI feature flag plus individual flags (`FeatureFlagService`).
- Use conservative, opt-in UX, with users explicitly triggering LLM-powered actions.

---

## 1. AI Rule Author (LLM-Assisted Rule Creation)

**Goal:** Help users author and refine complex rules from natural language, layered on top of the existing deterministic `NaturalLanguageRuleParser`.

**Relevant Code:**
- `Services/NaturalLanguageRuleParser.swift`
- `Views/InlineRuleBuilderView.swift`
- `Views/Settings/SettingsView.swift` (Smart Features tab)
- `Models/Rule.swift`, `RuleCondition`, `Rule.LogicalOperator`

### Concept

1. **Fallback when local parser is unsure**
   - When `NaturalLanguageRuleParser` returns a partial or ambiguous `NLParsedRule`, offer:
   - “Ask AI to interpret this rule” – GPT proposes one or more candidate rules with:
     - Action (`Rule.ActionType`)
     - Conditions (`[RuleCondition]`)
     - Logical operator (`Rule.LogicalOperator`)
     - Destination path suggestion

2. **Rule refactoring / naming helper**
   - Given an existing `Rule`, GPT suggests:
     - A clearer, user-friendly name.
     - Optional refactors (e.g., splitting one broad rule into two safer, narrower rules).

3. **Rule templates from description**
   - From a short description (“I want invoices to go to Finance”), GPT proposes a small set of starter rules that map to the existing rule engine and condition types.

### Possible Implementation Shape

- New service: `LLMRuleAssistantService` in `Services/`.
  - Example APIs:
    ```swift
    struct RuleAuthoringContext {
        let existingRules: [RuleSummary]
        let commonDestinations: [String]
    }

    struct ProposedRule {
        let name: String
        let action: Rule.ActionType
        let conditions: [RuleCondition]
        let logicalOperator: Rule.LogicalOperator
        let destinationDisplayPath: String
        let explanation: String
    }

    final class LLMRuleAssistantService {
        func proposeRules(
            from text: String,
            context: RuleAuthoringContext
        ) async throws -> [ProposedRule] { /* GPT-backed */ }

        func suggestName(for rule: Rule) async throws -> String { /* GPT-backed */ }
    }
    ```
- `InlineRuleBuilderView`:
  - Continue to use `NaturalLanguageRuleParser` as the first step.
  - If the parse is incomplete and the new feature flag is enabled, show an “Ask AI” button that:
    - Calls `LLMRuleAssistantService.proposeRules`.
    - Lets the user select a proposal and maps it into `InlineRuleFormState`.

### Feature Flag & Settings

- Add a new feature under `FeatureFlagService.Feature`:
  - `.llmRuleAssistant = "feature.llmRuleAssistant"`
  - Default: `true` (but surface clear “cloud AI” language in the UI).
- In `SmartFeaturesView`:
  - Add a row under “Individual Features”:
    - **Name:** “AI Rule Author”
    - **Description:** “Use cloud AI to draft and refine organization rules based on your descriptions. Only your rule text and related rule metadata are sent.”

---

## 2. GPT-Powered Insights & Summaries

**Goal:** Turn existing structured insights (patterns, clusters, activity) into richer, human‑friendly summaries and explanations.

**Relevant Code:**
- `Services/InsightsService.swift` (`FileInsight`, `generateInsights`)
- `Services/LearningService.swift`, `LearnedPattern`
- `Services/ContextDetectionService.swift`, `ProjectCluster`
- `Views/AIInsightsView.swift` and related views (`ProjectClusterView`, etc.)

### Concept

1. **Cluster summaries**
   - For a `ProjectCluster`, GPT generates a short explanation:
     - “These files look like assets for your Q1 marketing launch project (presentations, images, and reports).”

2. **Insight rollups**
   - For a set of `FileInsight` values, GPT writes an overall “what to focus on” summary:
     - “You have many large video files and unorganized PDFs. Start by archiving old videos, then create a rule for invoices.”

3. **Deeper “why this suggestion?”**
   - For selected patterns or insights, GPT expands:
     - Tradeoffs (e.g., archival vs deletion).
     - Suggested next steps.

### Possible Implementation Shape

- New service: `LLMInsightsService` in `Services/`.
  - Example APIs:
    ```swift
    struct ClusterSummary {
        let shortSummary: String
        let suggestions: [String]
    }

    final class LLMInsightsService {
        func summarizeCluster(
            _ cluster: ProjectCluster,
            sampleFiles: [FileItem]
        ) async throws -> ClusterSummary { /* GPT-backed */ }

        func summarizeInsights(_ insights: [FileInsight]) async throws -> String { /* GPT-backed */ }
    }
    ```
- `AIInsightsView`:
  - Add an optional “Summarize with AI” button for:
    - The whole insights dashboard.
    - Individual project clusters.
  - Show GPT-generated text as an overlay or expandable section.

### Privacy & Data

- Prefer metadata over content:
  - File names, extensions, categories (`FileTypeCategory`), approximate counts and sizes.
  - Cluster names and template names; avoid raw paths when possible (normalize `~/Documents/Finance`).
- No file contents unless a future feature explicitly opts in to content analysis.

### Feature Flag & Settings

- New feature: `.llmInsights = "feature.llmInsights"`
  - “AI Explanations – Use cloud AI to summarize and explain your organization opportunities. Only filenames and folder paths are shared.”

---

## 3. Conflict Resolution & Bulk Review Helper

**Goal:** When the user is facing many decisions (duplicates, bulk moves, possible deletes), use GPT to propose safe, human‑readable resolution plans.

**Relevant Code:**
- `Services/DuplicateDetectionService.swift`
- `Views/DuplicateGroupsView.swift`
- `Services/FileOperationsService.swift`, `FileOperationCoordinator`
- `Views/ReviewView.swift`, `ReviewViewModel`
- Undo via `Services/UndoCommand.swift`

### Concept

1. **Duplicate conflict plans**
   - For each `DuplicateGroup`, GPT proposes a high‑level strategy:
     - “Keep the newest file in each group and archive older versions instead of deleting them.”

2. **Bulk review plan**
   - Given:
     - Pending operations (`FileItem` status `.pending` or `.ready` with suggestions),
     - `FileInsight`s from `InsightsService`,
   - GPT can output a prioritized plan:
     - “1) Clean up Downloads duplicates (saves ~3 GB). 2) Archive old PDFs from more than 180 days ago. 3) Create a rule for receipts.”

### Possible Implementation Shape

- New or extended service: `LLMReviewAssistantService` (could live alongside `LLMInsightsService`).
  - Example APIs:
    ```swift
    struct ConflictResolutionPlan {
        let summary: String
        let recommendedActions: [RecommendedAction]
    }

    struct RecommendedAction {
        let fileIDs: [UUID] // or paths
        let action: String  // e.g. "keepNewest", "archive", "delete"
        let rationale: String
    }

    final class LLMReviewAssistantService {
        func proposeResolution(for group: DuplicateGroup) async throws -> ConflictResolutionPlan
        func proposeReviewPlan(
            pendingFiles: [FileItem],
            insights: [FileInsight]
        ) async throws -> String
    }
    ```
- UI integration:
  - `DuplicateGroupsView`:
    - Button: “Get AI suggestions” → shows a list of recommended actions that the user can accept or override.
  - `ReviewView`:
    - Optional “Summarize review with AI” card that outlines where to start.

### Safety & UX

- GPT suggestions must always be **non‑binding**:
  - No destructive operations (delete/move) without an explicit user confirm.
- Prefer archival over deletion in suggestions.
- When GPT is unavailable (offline/failure), fall back to existing behavior.

### Feature Flag & Settings

- New feature: `.llmConflictAssistant = "feature.llmConflictAssistant"`
  - “AI Conflict Helper – Suggest safe ways to resolve duplicates and bulk operations. You approve all actions before anything changes.”

---

## 4. Organization Template Advisor

**Goal:** Help users choose and lightly customize `OrganizationTemplate`s based on a short description of their work and preferences.

**Relevant Code:**
- `Docs/Features/OrganizationTemplates.md`
- `Models/OrganizationTemplate.swift`, `OrganizationPersonality.swift`
- `Views/TemplateSelectionView.swift`

### Concept

1. **Template recommendation from description**
   - User input: “I’m a freelance photographer and YouTuber.”
   - GPT selects and ranks templates like:
     - “Creative Professional” (best fit).
     - “Minimal” (alt for simplified workflow).

2. **Light customizations**
   - GPT suggests small tweaks:
     - Renaming a folder (“Clients” → “Brands”).
     - Adding a single extra rule (e.g., for `.mp3` or `sfx`).

### Possible Implementation Shape

- New service: `LLMTemplateAdvisorService`.
  - Example API:
    ```swift
    struct TemplateRecommendation {
        let templateID: UUID
        let fitScore: Double
        let explanation: String
    }

    final class LLMTemplateAdvisorService {
        func recommendTemplates(
            from description: String,
            available: [OrganizationTemplate]
        ) async throws -> [TemplateRecommendation]
    }
    ```
- `TemplateSelectionView`:
  - Add a short text field: “Describe how you use your Mac…”
  - Button: “Get AI recommendation”.
  - Display badges like “Best for you” with GPT’s explanation.

### Feature Flag & Settings

- New feature: `.llmTemplateAdvisor = "feature.llmTemplateAdvisor"`
  - “AI Template Advisor – Use cloud AI to recommend an organization template based on how you work.”

---

## Cross-Cutting Considerations

### Feature Flag Pattern

All GPT/LLM features should:
- Use `FeatureFlagService.shared.isEnabled(.featureName)` at the service entry point.
- Respect the master AI toggle (`masterAIEnabled`) in `FeatureFlagService`.
- Add clear, user‑friendly descriptions to `SmartFeaturesView` under Settings → Smart Features.

### Privacy & Data Minimization

- Default to sharing **only**:
  - Filenames, extensions, categories, folder display names.
  - Aggregated statistics (counts, sizes, approximate ages).
  - Rule metadata (names, conditions, destinations) and template metadata.
- Avoid sending:
  - Raw file contents.
  - Full absolute paths when unnecessary (use normalized paths like `Documents/Finance`).
- If a future feature requires reading file contents for GPT:
  - Gate it behind a dedicated, opt‑in flag (e.g., `.cloudContentAnalysis`).
  - Clearly explain in Settings what is sent and why.

### Failure Modes & UX

- Treat GPT as “nice to have”:
  - If network/LLM calls fail, the app should behave exactly as today.
  - Show small, dismissible error messages rather than blocking flows.
- Avoid surprising automation:
  - GPT can propose rules, plans, and explanations.
  - Execution remains deterministic and implemented by existing services (RuleEngine, FileOperationsService, etc.).
