# Forma Feature Roadmap

*Updated April 10, 2026*

## Product Posture

Forma is **preview-first by default**.

The product should help users move faster and make fewer decisions, but it should not default to opaque "AI moved your files somewhere" behavior. Autopilot can exist later as an **optional, scoped mode** for users who have already built trust in the system.

This keeps Forma aligned with its strongest positioning:

- Users can see what Forma is about to do
- Users can understand why it made the suggestion
- Users can undo changes safely
- Users stay in control of their file system

## Strategic Moat

Forma should optimize for features that are **hard to replicate with a prompt**:

1. **Trust infrastructure**: preview, explanation, simulation, rollback, auditability
2. **Persistent local memory**: long-lived knowledge of how this specific user organizes
3. **OS-level integration**: Finder, Spotlight, Services, menu bar, Shortcuts, app intents
4. **Workflow lock-in**: metadata, project views, recurring organization systems, repeatable automation

Forma should explicitly **de-prioritize generic AI surface area** that can be reproduced by a chatbot or thin wrapper:

- Broad AI categorization expansion
- "Chat with your files" style features
- Natural-language rule parsing as a flagship differentiator
- Cloud AI summaries that weaken the local-first trust story

## What Is Already Shipped

The roadmap should start from the current product, not from older planning assumptions.

- **Realtime monitoring exists** via background monitoring, `AutomationEngine`, and `FileMonitorService`
- **Preview and undo exist** via the review queue, activity logging, and undo flows
- **Learned patterns exist** via `LearningService`, `LearnedPattern`, and `RuleSuggestionView`
- **Reasoning exists** via match explanations in scan/rule/prediction flows
- **External macOS ingress exists** via Finder Services, Spotlight/App Intents, and `ExternalIngressCoordinator`

This means the next roadmap should not focus on "add basic intelligence" or "add monitoring." Those are foundations already in place.

---

## Now (0-8 Weeks)

### Critical-Path Optimization Program
**Goal:** Bring Forma's five most important user paths inside target budgets and keep them fast as rules, files, and history grow.

- Bring cold launch to a first meaningful file view inside the `<2s` target by deferring non-essential maintenance and keeping startup ownership singular.
- Make watched-folder organization feel immediate by replacing full-refresh behavior with touched-path updates that can land inside the `<500ms perceived` budget.
- Make inspector open, detail review, and close feel lightweight by eliminating global recomputation from a local inspection action.
- Make bulk action and undo feel transactional and reversible instead of `N` small operations stitched together on the hot path.
- Make rule create/apply/verify a single fast loop rather than a save-now, re-evaluate-everything workflow.
- Keep the optimization work centered on structural latency, bounded history growth, and predictable recovery rather than feature expansion.

### 1. Quick-Win Onboarding and First-Run Proof
**Goal:** Show value before asking the user to become a system designer.

- Detect obvious first-run batches such as screenshots, archives, invoices, and stale downloads
- Offer one-tap actions with visible before/after payoff
- Move from "set up Forma" to "Forma already found something useful"
- Carry the same quick-win flow into post-onboarding first launch if onboarding is skipped
- Reuse the existing external-ingress flow to promote one-time folder requests into persistent monitored folders when the review proves useful

**Why now:** This is the fastest path to better retention without changing the product thesis.

### 2. Batch UX That Hides Overwhelm
**Goal:** Make the review workflow feel finite and forgiving.

- Present files in manageable chunks instead of backlog walls
- Add a clear `Done for now` affordance
- Emphasize progress completed, not backlog remaining
- Keep card/list/grid surfaces aligned around the same chunked workflow semantics
- Reduce shame-inducing counts and all-or-nothing review framing

**Why now:** This improves the core product loop without giving up preview-first control.

### 3. Trust Infrastructure
**Goal:** Make Forma feel safer than any prompt-based organizer.

- Add rule simulation: "show what this rule would have done to the last 30/90 days"
- Add stronger preflight validation before automation runs
- Improve explanation surfaces: why this matched, why this destination, why this was skipped
- Add clearer scoped rollback and richer audit history for automated actions
- Surface confidence and safety thresholds in user-facing language, not just internal logic

**Why now:** Trust infrastructure is a moat, not polish.

### 4. Notification Tone Reset
**Goal:** Reinforce progress, not failure.

- Replace guilt-heavy backlog copy with progress-forward notifications
- Frame reminders as system health and momentum, not user neglect
- Highlight wins such as organized files, reduced clutter, or newly automated patterns
- Keep error and permission notifications explicit, but non-judgmental

**Why now:** The current automation messaging is functional but not yet aligned with the emotional product strategy.

### 5. Tighten the Preview-First Flagship Workflow
**Goal:** Make the main differentiated behavior look and feel like the main event.

- Keep improving the inline rule builder as a staged composer rather than a cramped form
- Push the review queue, rule creation, explanation, and undo sequence as one coherent flow
- Continue reducing "admin screen" energy in Smart Rules and Analytics

**Why now:** The flagship workflow should feel premium before Forma expands outward.

---

## Next (2-4 Months)

### Optimization Follow-Ons
**Goal:** Compress friction on the same critical paths once the structural latency floors are gone.

- Surface watched-folder setup from the same review and folder-entry surfaces where users first discover the feature's value.
- Turn learned-pattern promotion into a staged draft-and-verify flow instead of a one-click persist path.
- Simplify inspector close/reasoning affordances once the inspector open path is already fast.
- Compress onboarding only where it reduces time-to-value without reintroducing launch-path work.

### 6. Personal Organization Memory
**Goal:** Build compounding user-specific value that a prompt cannot fake.

- Store persistent local memory about preferred destinations, repeated exceptions, archive habits, project associations, and recovery behavior
- Learn from accepted changes, overridden suggestions, and later manual corrections
- Treat this as durable product memory, not disposable ML suggestions

**Why next:** This is where Forma starts becoming more valuable with age.

### 7. Progressive Automation Upgrades
**Goal:** Let automation earn trust instead of demanding it upfront.

- Suggest turning repeated patterns into rules with stronger confidence and clearer rationale
- Allow users to promote specific rules, folders, or categories into optional autopilot
- Keep preview-first as the default posture even as trusted areas become more automatic
- Add visible automation scopes so users know exactly where autopilot is active

**Why next:** Autopilot should be a reward for trust, not the opening move.

### 8. Metadata Layer v1
**Goal:** Give Forma durable memory beyond folder paths.

- Add lightweight local metadata such as tags, status, project association, and organization history
- Bias toward auto-applied metadata before manual tagging UX
- Use metadata to improve retrieval and cross-folder understanding
- Keep the implementation local-first and reversible

**Why next:** Metadata is a stronger moat than more classification prompts.

### 9. Cross-Folder Project Spaces
**Goal:** Answer "where did I put that?" without forcing rigid folder discipline.

- Build virtual project views that span folders
- Aggregate related files by project, client, or active context
- Use metadata and activity history to keep spaces accurate over time

**Why next:** This turns Forma from sorter into retrieval system.

---

## Later (4-8+ Months)

### 10. Workflow Chains With Simulation
**Goal:** Extend single-step organization into trustworthy multi-step systems.

- Support chains such as match -> rename -> tag -> move -> notify -> log
- Preserve simulation, audit, and rollback across the whole chain
- Ship opinionated templates before opening advanced custom workflow building

### 11. Deeper macOS Integration
**Goal:** Own more of the file workflow at the OS layer.

- Build on Finder Services, Spotlight, and App Intents with deeper integration
- Revisit a Finder extension once the core loop is tighter and more valuable
- Continue investing in menu bar, Shortcuts, and external-entry workflows

### 12. Backup, Sync, and Portability
**Goal:** Make Forma's system durable across machines.

- Back up and restore rules, settings, metadata, and organization memory
- Add sync only after the local model is strong and clearly worth preserving
- Treat cloud support as infrastructure, not the headline

### 13. Collaboration and Shared Conventions
**Goal:** Expand from solo cleanup to team file systems if demand appears.

- Shared naming conventions
- Shared folder policies
- Shared workflow templates for common folder types

---

## Not Now

These are intentionally deprioritized because they are easier to copy or weaken the product thesis.

- Generic AI categorization expansion
- Natural-language rule parsing as a primary marketing feature
- Cloud AI explanations and summaries
- "Chat with your files" interfaces
- Autopilot as the default product posture
- Broad cloud-storage expansion before local memory and trust infrastructure are stronger

---

## Sequencing Logic

1. **Improve first-run proof and reduce overwhelm**
2. **Make preview-first meaningfully safer than competitors**
3. **Build persistent local memory that compounds over time**
4. **Let optional automation emerge from earned trust**
5. **Deepen workflow lock-in through metadata, project views, and OS integration**

The core idea is simple:

> Forma should win because it becomes the trusted local system for how a person actually organizes files over time, not because it has the flashiest AI prompt surface.
