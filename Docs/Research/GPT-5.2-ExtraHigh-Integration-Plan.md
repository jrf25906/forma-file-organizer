# GPT-5.2 Extra High Integration Plan (Forma)

**Status:** Draft (implementation guide)  
**Primary Use Cases:** LLM-assisted rule authoring; optional AI insight summaries  
**Scope:** `Forma File Organizing/` macOS app (SwiftUI + SwiftData)

This document describes a safe, opt-in way to integrate GPT‑5.2 Extra High into Forma for the highest-leverage tasks in this codebase: turning ambiguous natural-language rule requests into concrete, testable `Rule` objects, and optionally summarizing already-structured `InsightsService` output.

## Why GPT‑5.2 Extra High Here

Forma already has:
- A deterministic, local-first parser: `Forma File Organizing/Services/NaturalLanguageRuleParser.swift`
- A concrete rule model + rule engine: `Models/Rule.swift`, `Services/RuleEngine.swift`
- A unified AI surface: `Forma File Organizing/Views/AIInsightsView.swift`
- A hierarchical feature-flag system: `Forma File Organizing/Services/FeatureFlagService.swift`

GPT‑5.2 Extra High is most valuable when the system must reason across multiple constraints simultaneously (user intent + existing rules + safe operations + destination selection + explainability). That’s exactly what “rule authoring from messy natural language” requires.

## Goals

1. **LLM-Assisted Rule Authoring (Primary)**
   - Use the local parser first; only call the LLM when the parse is incomplete or ambiguous.
   - Return structured “rule proposals” that map directly to `Rule.ActionType`, `RuleCondition`, `Rule.LogicalOperator`, and a destination selection.
   - Require explicit user confirmation before persisting a rule or moving files.

2. **LLM Insight Summaries (Optional)**
   - Summarize existing structured outputs (`FileInsight`, clusters, duplicates) into human-friendly text.
   - Never perform file operations; never require content access; no “automatic actions.”

## Non-Goals

- Replacing on-device ML (e.g., `DestinationPredictionService`) with a cloud model.
- Sending raw file contents to the cloud.
- Allowing the LLM to directly move/delete files without user confirmation.
- Bypassing security-scoped bookmarks or sandbox constraints.

## Constraints & Principles

- **Local-first**: keep deterministic parsing and rule evaluation as the default path.
- **Opt-in**: LLM calls must be user-triggered (button/explicit action), not automatic.
- **Feature flags**: respect master AI toggle + individual toggles (`FeatureFlagService`).
- **Safety**: suggestions are non-binding; destructive actions must be discouraged.
- **Privacy**: default to metadata-only; normalize or redact paths.

## Architecture Overview

### Data Flow (Rule Authoring)

1. User enters a rule description in the existing UI (e.g., `InlineRuleBuilderView` / natural-language rule flow).
2. `NaturalLanguageRuleParser.parse(...)` runs locally.
3. If parse is complete: proceed with existing behavior (build a `Rule`).
4. If parse is incomplete/ambiguous AND LLM feature is enabled:
   - UI offers **“Ask AI”**.
5. On “Ask AI”:
   - Build a minimal, privacy-preserving context payload.
   - Call `LLMRuleAssistantService.proposeRules(...)`.
6. Show 1–3 proposals with:
   - Explainability (“why this rule”)
   - A preview (which sample files would match)
   - Required confirmations (destination selection, action type)
7. User selects one proposal and confirms:
   - Convert to a concrete `Rule`.
   - Persist rule via existing services.

### Data Flow (Insight Summaries)

1. `AIInsightsView` renders local insights as usual.
2. User clicks **“Summarize with AI”** (global or per-section).
3. Build a metadata-only summary payload (counts, categories, sizes, normalized folder names).
4. Call `LLMInsightsService.summarizeInsights(...)`.
5. Display text as an expandable card; no automatic actions.

## New Feature Flags

Add new flags to `FeatureFlagService.Feature` (names are suggestions; align with your naming conventions):

- `feature.llmRuleAssistant` (default `true`, but requires explicit user click)
- `feature.llmInsightSummaries` (default `false` or `true` based on product posture)

Notes:
- These should still be controlled by the master AI toggle behavior implemented in `FeatureFlagService`.
- Settings UI should clearly label these as “Cloud AI.”

## New Services (Proposed)

### 1) `LLMClient` (Transport + Policies)

Purpose: isolate networking, auth, retry/backoff, timeouts, cancellation, and response decoding.

Responsibilities:
- Build HTTP requests (provider-specific).
- Enforce timeouts (short, e.g. 10–20s).
- Enforce max payload size (truncate + summarize inputs).
- Return typed results or typed errors.
- Support cancellation (Swift `Task` cancellation).

Suggested location:
- `Forma File Organizing/Services/LLM/LLMClient.swift` (or keep flat under `Services/` until grouping exists)

### 2) `LLMRuleAssistantService` (Rule Authoring)

Purpose: produce rule proposals that can be deterministically mapped to app models.

Suggested API:
```swift
struct RuleAuthoringContext {
    let existingRuleSummaries: [RuleSummary]
    let commonDestinationDisplayNames: [String]
    let recentExampleFiles: [FileSummary]
    let parserResult: NLParsedRule
}

struct ProposedRule {
    let name: String
    let action: Rule.ActionType
    let logicalOperator: Rule.LogicalOperator
    let conditions: [RuleCondition]
    let destinationDisplayPath: String?
    let explanation: String
    let confidence: Double
    let warnings: [String]
}

final class LLMRuleAssistantService {
    func proposeRules(from userText: String, context: RuleAuthoringContext) async throws -> [ProposedRule]
}
```

### 3) `LLMInsightsService` (Optional Summaries)

Purpose: take already-structured insights and turn them into friendly copy.

Suggested API:
```swift
struct InsightsSummaryInput {
    let insightMessages: [String]
    let countsByCategory: [String: Int]
    let topFolders: [String]          // normalized display names
    let topFileTypes: [String]        // extensions or categories
}

final class LLMInsightsService {
    func summarizeInsights(_ input: InsightsSummaryInput) async throws -> String
}
```

## Prompting Strategy (Deterministic Output)

### Rule Proposals: Require Strict JSON

To keep the system testable and safe, instruct the model to return **JSON only** with a fixed schema.

Recommended approach:
- Provide the app’s allowed enums/fields (action types, condition types, operators).
- Demand strictly valid JSON (no prose wrapper).
- Reject/repair invalid JSON before presenting anything to the user.

Example (high level; adapt to your exact model types):
```json
{
  "proposals": [
    {
      "name": "Move invoices to Finance",
      "action": "move",
      "logicalOperator": "and",
      "destinationDisplayPath": "Finance",
      "conditions": [
        { "type": "fileExtension", "value": ["pdf"] },
        { "type": "nameContains", "value": ["invoice", "receipt"] }
      ],
      "explanation": "…",
      "confidence": 0.82,
      "warnings": ["Avoid delete actions; review suggested matches first."]
    }
  ]
}
```

### Summaries: Allow Text, But Keep Inputs Tight

For insight summaries, plain text output is fine, but keep:
- Inputs metadata-only
- Output short (e.g., < 600 chars) and structured (bullets)

## Privacy & Data Minimization

Default input policy (recommended):
- Send **no file contents**.
- Prefer **counts**, **categories**, **extensions**, and **normalized destination names**.
- Avoid full absolute paths. Use:
  - `~/Downloads` → `"Downloads"`
  - `/Users/james/.../Clients/Acme` → `"Clients/Acme"` (or just `"Acme"`)
- Avoid sending unique identifiers (UUIDs, stable file IDs).
- Cap sample file lists (e.g., 20 items max).
- Consider optional user setting: “Share file names with Cloud AI” (default OFF) if you want stronger privacy.

## Safety & UX Requirements

### Hard Requirements

- The LLM must never trigger file operations directly.
- Any generated rule must be previewed and confirmed by the user.
- If the LLM suggests `delete`, the UI should:
  - warn clearly
  - default to safer alternatives (move/archive)
  - require an extra confirmation step

### Preview/Validation

Before enabling a proposed rule:
- Run the rule against a local sample set and show:
  - estimated matches count
  - a small list of matched files (local-only)
  - destination resolution outcome
- If destination is unclear/unavailable (no bookmark), force user to pick a destination via existing destination picker.

### Failure Modes

If the LLM call fails (offline, timeout, auth):
- show an inline error
- keep the local parser output and allow manual rule editing
- never block the core flow

## Model Selection Guidance

Use GPT‑5.2 Extra High only where it matters:
- **Use Extra High** for: ambiguous parsing fallback, “refactor existing rule” suggestions, conflict-aware proposals.
- **Use a cheaper model** (or skip LLM) for: routine summarization, simple rename suggestions, trivial transformations.

## Testing Plan (Must-Haves)

Add unit tests (XCTest) for:

1. **Gating**
   - LLM services are not called when master AI is OFF.
   - LLM services are not called when the specific feature is OFF.

2. **Redaction**
   - Path normalization removes absolute paths.
   - Payload size limits are enforced deterministically.

3. **Mapping**
   - Valid JSON proposals map into `RuleCondition` and `Rule` consistently.
   - Invalid/unknown condition types are rejected safely.

4. **UI behavior (logic-level)**
   - When local parse is complete, “Ask AI” does not appear.
   - When parse is incomplete/ambiguous, “Ask AI” appears (if enabled).

Where to place tests:
- `Forma File OrganizingTests/` (reuse existing test helper patterns).

## Implementation Checklist (Concrete Steps)

1. Add feature flags in `FeatureFlagService.Feature`:
   - `llmRuleAssistant`
   - `llmInsightSummaries`
2. Add Settings UI toggles (Smart Features) with “Cloud AI” labeling.
3. Create `LLMClient` with:
   - cancellation support
   - timeout
   - typed error model
4. Implement `LLMRuleAssistantService`:
   - build minimal `RuleAuthoringContext`
   - strict JSON decode + validation
   - produce `[ProposedRule]`
5. Integrate into rule creation UI:
   - local parse first
   - show “Ask AI” only when needed
   - preview + confirm + persist
6. (Optional) Implement `LLMInsightsService` and integrate into `AIInsightsView`.
7. Add tests for gating, redaction, mapping, and UI visibility rules.

## Open Questions

- Should cloud AI be disabled by default (enterprise privacy posture) or enabled but fully user-triggered?
- Should we offer “Share file names” as a separate opt-in setting?
- Should delete actions be disallowed entirely for LLM proposals (recommended for v1)?

