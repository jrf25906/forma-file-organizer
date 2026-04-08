# Post Workflow Engine V1 Roadmap Sequencing Design

Date: 2026-04-07
Branch: `main`
Status: Draft for spec review

## Summary

`Workflow engine backbone v1` is effectively complete. The remaining open items in that area are intentionally later-slice work: broader multi-step execution, deeper audit exploration, richer notify behavior, and project-space-triggered workflow actions.

The next roadmap decision should optimize for user-visible releases rather than taking another mostly-foundational branch. The recommended three-branch sequence is:

1. `cross-folder-project-spaces-v2`
2. `progressive-automation-upgrades`
3. `workflow-engine-v2`

This order keeps Forma aligned with the repo's stated product posture:

- preview-first remains the default
- local memory compounds before automation expands
- automation earns trust instead of demanding it
- broader workflow power arrives only after the retrieval and trust story is stronger

## Current State

The repo already shipped the core prerequisites that earlier roadmap wording treated as future work:

- metadata foundation v1
- durable workflow status v1
- auto-applied project association v1
- auto-applied content tags v1
- cross-folder project spaces v1 as a read-only retrieval slice
- workflow engine simulation and audit backbone v1

That means the next sequence should not restart from "build metadata." The correct posture is:

- metadata exists
- project spaces exist in a narrow read-only form
- trusted automation scopes exist in a narrow promotion form
- workflow engine exists as a backbone with `move` as the only live executor

The next work should productize those foundations in the order that creates the clearest user value.

## Goals

- Choose the next three branches after `workflow-engine` v1.
- Optimize for user-visible releases, not invisible infrastructure passes.
- Deepen Forma's retrieval and memory moat before broadening automation power.
- Keep the roadmap consistent with preview-first and local-first trust.
- Make later workflow expansion land on top of surfaces users already understand.

## Non-Goals

- No default-on autopilot posture.
- No broad cloud sync or collaboration push in this sequence.
- No "chat with your files" or generic AI-surface expansion.
- No blank-canvas workflow builder before opinionated templates prove useful.
- No new project system that replaces the current metadata-derived posture.

## Options Considered

### Option A: `cross-folder-project-spaces-v2` -> `progressive-automation-upgrades` -> `workflow-engine-v2`

This is the recommended order.

Benefits:

- turns existing metadata into a more obvious retrieval and memory win first
- gives automation a stronger evidence base and clearer trust narrative
- lets workflow v2 use stabilized project and trust surfaces instead of inventing them mid-branch

Tradeoffs:

- visible autopilot expansion lands one branch later
- some workflow-engine later items remain deferred a bit longer

### Option B: `progressive-automation-upgrades` -> `cross-folder-project-spaces-v2` -> `workflow-engine-v2`

Benefits:

- faster visible automation story
- makes the existing trust-scope work feel more immediately expanded

Tradeoffs:

- pushes retrieval and memory value behind more automation work
- risks making Forma feel more like an aggressive sorter before it feels like a durable memory system
- leaves project-space-triggered actions without a richer project-space surface to attach to

### Option C: `workflow-engine-v2` -> `cross-folder-project-spaces-v2` -> `progressive-automation-upgrades`

Benefits:

- cleanest engine-first layering
- resolves later workflow open questions earlier

Tradeoffs:

- weakest release story
- too much internal power lands before user-facing context surfaces catch up
- increases the risk of building engine capability in search of a product surface

## Recommended Sequence

### Branch 1: `cross-folder-project-spaces-v2`

**Release goal:** turn project spaces from a read-only retrieval slice into a useful workflow-memory surface.

**Why first:**

- project spaces are the most direct way to make the new metadata layer feel real to users
- this is the strongest "where did I put that?" and "what belongs to this project?" release
- it deepens lock-in through retrieval and memory before asking users to trust more automation

**User-visible promise:**

Project spaces should stop feeling like a passive list of related files and start feeling like a durable cross-folder project context.

**In scope:**

- show richer project context derived from metadata and history, such as recent activity, preferred destinations, and active folders
- make project-space summaries and detail views feel like an owned retrieval surface rather than a thin dashboard subsection
- allow lightweight correction of project association for existing files from the project-space flow
- introduce the first explicit workflow-memory layer at the project level, using existing local metadata and organization history
- feed project-memory signals back into scan/review suggestions where the evidence is strong

**Out of scope:**

- no project-space-triggered workflow execution yet
- no broad manual metadata editing system
- no cloud/shared project model
- no chatbot-style project assistant

**Exit criteria:**

- users can open a project space and understand not only which files belong there, but how that project has recently behaved
- project association can be corrected from the surfaced project context without dropping into a separate admin flow
- project-memory signals are visible enough that this release clearly improves retrieval and future suggestions

### Branch 2: `progressive-automation-upgrades`

**Release goal:** make automation feel explicitly earned, scoped, explainable, and reversible.

**Why second:**

- the trust-scope foundation already exists, but it still needs a more complete lifecycle and clearer user-facing posture
- after project spaces v2, Forma has stronger evidence to explain why a scope deserves more automation
- this keeps preview-first as the center while making trusted autopilot feel like a reward

**User-visible promise:**

Users should be able to see exactly where autopilot is active, why it was earned, what it recently did, and how to pause or revoke it.

**In scope:**

- promote trusted scopes into first-class UI with clear boundaries and status
- expand lifecycle controls for active scopes, including pause, revoke, and health states
- improve simulation, preflight, audit, and notification behavior around promoted scopes
- strengthen the evidence model that recommends when a folder, rule, or category should graduate into optional autopilot
- keep review-earned trust as the gate for broader automation

**Out of scope:**

- no default-on autopilot
- no open-ended workflow authoring
- no project-space-triggered actions yet
- no broad cloud sync or collaboration dependency

**Exit criteria:**

- users can identify active automation scopes at a glance
- every scope has understandable lifecycle controls and recent-run context
- richer notification and audit behavior supports confidence instead of vague "automation happened" messaging

### Branch 3: `workflow-engine-v2`

**Release goal:** expand from trusted single-action execution into opinionated multi-step workflows.

**Why third:**

- by this point project spaces are richer and trusted automation scopes are visible and stable
- the workflow engine can now expand into product surfaces users already recognize
- this is the right moment to add broader chain capability without jumping straight to a builder

**User-visible promise:**

Forma can now run broader, still-trustworthy workflow templates that go beyond `match -> move` while preserving simulation, audit, and rollback.

**In scope:**

- ship opinionated multi-step templates before any generic builder
- expand beyond `move` into broader step support such as `rename`, `tag`, `notify`, and `log`
- deepen audit exploration at run, step, and file levels
- support chain-level rollback rules and clearer failure reporting
- add project-space-triggered workflow actions after the project-space and trust models are mature enough to support them

**Out of scope:**

- no blank-canvas workflow composer in the first v2 slice
- no broad backup/sync initiative folded into the workflow branch
- no collaboration/shared workflow conventions yet

**Exit criteria:**

- at least one real multi-step workflow template ships with end-to-end simulation, execution, audit, and rollback behavior
- audit exploration is materially deeper than the v1 backbone surfaces
- project-space-triggered workflow actions feel like a natural extension of project memory, not a bolted-on shortcut

## Cross-Cutting Constraints

The sequence should preserve the same posture across all three branches:

- preview-first remains the default entry point
- any increased automation must stay scoped, visible, and reversible
- metadata remains local-first and explainable
- AI/ML entry points must stay feature-flagged through `FeatureFlagService.shared.isEnabled(...)`
- file operations must continue to respect security-scoped bookmarks and existing safety boundaries

## Explicit Deferrals

The following roadmap items stay out of this three-branch sequence unless a small enabling piece is unavoidable:

- deeper macOS integration beyond the current Finder Services, Spotlight, App Intents, and menu bar surfaces
- backup, sync, and portability for rules, settings, metadata, and organization memory
- collaboration and shared conventions

These are valid later branches, but they should not interrupt the immediate sequence above.

## Roadmap Sync Notes

Before implementation planning begins, the roadmap docs should be cleaned up to reflect the real current state:

- mark the metadata foundation as shipped in the active roadmap ordering instead of implying metadata v1 is still unplanned
- keep project spaces v1 and workflow engine backbone v1 described as shipped foundations
- describe the next branch as `project spaces v2` rather than a generic metadata continuation

This keeps the execution docs aligned with what the product already has.

## Recommendation

Proceed with:

1. `cross-folder-project-spaces-v2`
2. `progressive-automation-upgrades`
3. `workflow-engine-v2`

This is the strongest user-visible sequence because it first turns existing metadata into obvious retrieval value, then turns earned trust into clearer scoped automation, and only then expands into broader workflow power.
