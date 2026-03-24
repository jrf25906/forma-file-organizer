# Forma Feature Roadmap

*Generated March 23, 2026*

## Strategic Frame

Forma's durable moat is **reliable file infrastructure**, not smart file assistance. AI agents will handle classification and suggestions better than any on-device model. Forma should be the trustworthy, always-on system that either works independently or that AI agents plug into.

All features below are naturally local/on-device — the privacy-first positioning holds without compromise.

**Primary design constraint:** executive functioning support. Every feature is evaluated against how well it reduces decision fatigue, eliminates task initiation barriers, and prevents the shame/overwhelm spiral that causes people with ADHD (and similar profiles) to give up on file organization entirely.

---

## Now (Months 1–2)

### 1. File System Watching + Aggressive Auto-Organize
**Effort:** Moderate · **Moat:** High · **Impact:** Foundational

The single most important feature for executive functioning: prevent the pile from ever forming. If files are handled as they arrive, users never face a 400-file backlog. They never need to "decide to organize." The mess never reaches the point where it triggers overwhelm and avoidance.

- Feature flag already stubbed: `Performance.enableFileSystemWatching`
- FSEvents/DispatchSource for real-time folder monitoring
- Existing `FileScanPipeline` can consume events without major refactoring
- **Promote auto-organize from cautious opt-in to the default path.** The current gating (`autoOrganize` flag, conservative thresholds) makes sense for control-oriented users but is the wrong default for ADHD users. The safety net is undo, not pre-approval.
- Key risk: battery/performance overhead — needs configurable throttling
- Design goal: after onboarding, the user should be able to forget Forma exists and still have organized files

### 2. Quick-Win Onboarding with Instant Results
**Effort:** Low–Moderate · **Moat:** Moderate · **Impact:** Critical for retention

The first 60 seconds after install must deliver visible results. Not "set up your rules" — that's homework. ADHD brains need immediate payoff to build trust and momentum.

- On first scan, present one-tap batch actions: "Forma found 47 screenshots on your Desktop. Move them all to ~/Screenshots?"
- Show a single, specific, achievable action — not the full scope of the mess
- One tap → instant visible result → dopamine hit → trust established
- Templates already exist but the gap between "installed" and "seeing results" is too long
- Celebrate the win: brief positive feedback ("Done — 47 files organized") before presenting the next batch

### 3. Positive-Reinforcement Notifications
**Effort:** Low · **Moat:** Moderate · **Impact:** Retention / emotional safety

Redesign the notification system around celebration, not guilt. "You have 47 unorganized files" triggers shame and avoidance. "Forma organized 23 files this week" builds confidence.

- Replace backlog-count alerts with progress-focused messaging
- Weekly summary: "Forma handled X files this week. Your Downloads folder is 40% lighter."
- Stale rule detection stays, but framed as system health ("Forma cleaned up a rule that wasn't matching anything") not user failure
- Folder size alerts framed as actionable: "Your Downloads hit 10 GB — want Forma to archive files older than 90 days?"
- Never surface the full scope of disorganization unprompted

---

## Next (Months 2–4)

### 4. Zero-Decision Mode
**Effort:** Moderate · **Moat:** High · **Impact:** Core differentiator for ADHD users

A dedicated mode where Forma handles everything with zero user input post-onboarding. The interaction model flips from "Forma suggests, user approves" to "Forma acts, user can undo."

- Combines aggressive auto-organize + generous undo history (already built via `ActivityLoggingService`)
- Every decision the app asks the user to make is a potential drop-off point for executive dysfunction — minimize them
- When Forma notices repeated manual organization patterns, auto-create the rule and notify: "Forma noticed you keep moving invoices to Finance. It'll handle that from now on."
- Configurable escape hatch: users can switch to review mode anytime
- This is the philosophical shift from "tool" to "system that works for you"

### 5. Batch-Based UI That Hides Overwhelm
**Effort:** Moderate · **Moat:** Moderate · **Impact:** Reduces abandonment

Never show the full scope of the mess. Present small, achievable chunks instead of a wall of 400 files.

- Category-scoped batches: "Here are your 12 PDFs that look like invoices" is manageable. "Here are your 400 unsorted files" triggers shutdown.
- One-action-at-a-time flow: present → confirm → celebrate → next batch
- Progress indicator shows what's been handled, not what remains ("34 files organized today" not "366 files remaining")
- "Done for now" option that's respected — no guilt if user stops mid-batch
- Revisit `MainContentView` and all file surfaces (FileRow, FileListRow, FileGridItem) to support chunked presentation

### 6. Progressive Auto-Rule Creation
**Effort:** Moderate · **Moat:** High · **Impact:** Compounding automation

The existing pattern learning system (`LearningService`, `LearnedPattern`) observes behavior and suggests rules. For ADHD users, flip this: don't suggest, just act.

- When confidence is high enough, auto-create the rule and inform the user after the fact
- "Forma created a new rule: PDFs from Downloads → Documents/Finance. Undo?"
- Rejection handling already exists (3+ rejections suppress a pattern) — reuse this
- The user's organizational system grows automatically from their behavior
- Reduces the "I need to set up rules" barrier that prevents adoption

---

## Later (Months 4–6+)

### 7. Multi-Step Workflow Chains
**Effort:** Moderate · **Moat:** High · **Impact:** Power user retention

Extend the rule system from single-action (match → move) to multi-step workflows.

- Chain steps: match → rename → tag (xattr) → move → notify → log
- Deterministic, auditable, with guaranteed rollback via existing undo system
- **For ADHD users, these should be pre-built templates, not DIY configuration.** Offer "Invoice Processing," "Screenshot Cleanup," "Project Archival" as one-tap installs.
- Lightweight xattr-based tagging as first pass validates metadata demand
- Power users can build custom chains; everyone else gets templates

### 8. Finder Extension
**Effort:** High · **Moat:** Very High · **Impact:** Reduces friction for remaining manual decisions

Embed organization directly into Finder — context menus, inline badges, sidebar integration.

- Separate Xcode target, XPC communication, limited Finder extension APIs
- Wait until core product loop (watching → auto-organize → notifications) is tight
- For ADHD users: right-click → "Organize with Forma" removes the friction of switching apps for the few files that need manual routing
- macOS 27 may expand Finder extension APIs — waiting gives a better canvas

### 9. Persistent Metadata Layer
**Effort:** High · **Moat:** Very High · **Impact:** Lock-in (if validated)

A lightweight database overlay on the file system — tags, custom fields, project associations, status — that persists across moves and renames.

- Start with xattr-based tagging in workflow chains (#7) to validate demand
- If users actually use tags, invest in full metadata: custom fields, cross-folder queries, project spaces
- If they don't, you saved months of infrastructure work
- **For ADHD users, auto-tagging matters more than manual tagging.** The metadata layer is only valuable if it fills itself.
- Implementation options: macOS extended attributes (xattr) or local SQLite sidecar

### 10. Cross-Folder Project Spaces
**Effort:** High · **Moat:** High · **Impact:** Depends on metadata adoption

First-class "project" entities spanning multiple folders — virtual views that aggregate related files regardless of location.

- Depends on metadata layer (#9) being validated and built
- Extends existing project clustering from read-only detection to user-managed spaces
- For ADHD users: "Where did I put that file?" is a constant struggle. Project spaces answer it without requiring the user to remember their own organizational system.

---

## Deprioritize / Hold Steady

| Feature | Rationale |
|---|---|
| ML prediction expansion | Will be commoditized by general-purpose AI agents within 1–2 years |
| Content scanning (`contentScanning` flag) | LLMs will read file contents better than any on-device model |
| NL rule parser improvements | Useful but not a differentiator — AI agents do this natively |
| Personality quiz deepening | One-time experience, doesn't compound over time |
| Pattern learning R&D | Table stakes, not moat — redirect into auto-rule creation (#6) |
| Audit trail & export | Still valuable but niche; revisit after core ADHD loop is proven |
| Complex rule builder UX | Power user feature; ADHD users need fewer decisions, not more options |

---

## Sequencing Logic

Make the product **invisible** first (file system watching + auto-organize), then make the first experience **rewarding** (quick-win onboarding + positive notifications), then **eliminate remaining decisions** (zero-decision mode + auto-rule creation), then add **depth for power users** (workflows, Finder, metadata).

Each phase should be independently shippable and valuable. Don't gate early phases on later ones.

## Executive Function Design Principles

These should guide implementation decisions across all features:

1. **Every user decision is a cost.** Minimize required choices. Default aggressively. Let undo be the safety net.
2. **Never show the full scope of the mess.** Present small, achievable batches. Progress over backlog.
3. **Celebrate action, don't punish inaction.** Notifications frame progress positively. No guilt-based alerts.
4. **The system should work if the user forgets it exists.** Forma's success state is invisibility.
5. **Forgiveness by default.** Everything is undoable. Nothing is permanent. Reduce fear of making mistakes.
6. **Momentum over perfection.** A 70% correct auto-organize that runs silently beats a 95% correct system that requires approval on every file.

## On-Device / Privacy Note

All features above are inherently local. No cloud component needed. If intelligence features (smart rename, auto-tag from content) become desirable later, Apple's on-device Foundation Models (macOS 26+) preserve the privacy story. Build the infrastructure first, add intelligence later.
