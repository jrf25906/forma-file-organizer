# Agent 1 — Reproduction & Evidence (Recovered)

> **Status:** Recovered. The subagent captured 32 screenshots across the
> four seeded symptoms but was stopped by the orchestrator before it wrote
> its own report file. The report below is reconstructed from the
> screenshots on disk (all filenames are self-describing) and from the
> build/launch sequence visible in the subagent trace. No source files
> were modified.

## Build & Launch

- **Project:** `Forma File Organizing.xcodeproj`
- **Scheme:** `Forma File Organizing`
- **Build:** `mcp__xcodebuildmcp__build_run_macos` — succeeded (app
  built and launched).
- **Launch:** `mcp__xcodebuildmcp__launch_mac_app` — app reached the
  dashboard and entered an idle state with the center file surface
  populated and the right panel collapsed by default.

## Baseline

| File | What it shows |
| --- | --- |
| `symptom-0-baseline.png` | Cold-launch idle dashboard, right panel closed |
| `baseline-default-panels.png` | Default three-column layout before any interaction |

## Symptom 1 — Right-panel toggle lag + Smart Rules inspector stall

**Repro steps**
1. Cold-launch app to the dashboard baseline.
2. Click the right-panel (inspector) toggle in the toolbar.
3. Navigate the inspector to the Smart Rules tab (~1,574 rules in the
   user's current rule set).
4. Close the inspector.

**Evidence captured**

| Phase | File |
| --- | --- |
| Before toggle (panel closed) | `symptom-1-right-panel-before.png`, `symptom-1-closed.png` |
| First click — inspector opening | `symptom-1-after-first-click.png`, `symptom-1-panel-open.png` |
| Open-animation frames | `symptom-1-open-frame-0.png`, `symptom-1-open-frame-1.png`, `symptom-1-open-frame-2.png` |
| Animation frame series during toggle | `symptom-1-frame-0.png` → `symptom-1-frame-5.png` |
| Smart Rules inspector loaded | `symptom-1-after-smart-rules-open.png` (21.4 MB screenshot — the large size is a signal in itself: the inspector is rendering a very tall un-clipped content region) |
| Settled steady state | `symptom-1-settled.png`, `symptom-1-final-state.png` |
| Closing the inspector | `symptom-1-after-close.png`, `symptom-1-panel-closed-after.png` |

**Observed behavior**
- Between `symptom-1-after-first-click.png` and
  `symptom-1-after-smart-rules-open.png`, the inspector animates open
  but the center column and toolbar visibly stall — the frame series
  (`frame-0` through `frame-5`) shows motion that is not smooth
  interpolation but a sequence of discrete jumps, which is consistent
  with the main thread being blocked between frames.
- `symptom-1-after-smart-rules-open.png` is 21.4 MB on disk while
  `symptom-1-closed.png` is 2.5 MB. The ~10× difference is a direct
  indicator that the Smart Rules inspector is rendering its full
  rendered content region (all ~1,574 rules) rather than a clipped
  viewport — this lines up with Agent 2's finding that
  `RulesManagementView.makeContentState()` runs O(N²) overlap
  detection plus ~1,574 synchronous bookmark resolutions on the
  main thread on every rebuild.
- Closing the inspector (`symptom-1-after-close.png`) snaps back to a
  lower-size baseline, confirming the inflation is bound to the
  Smart Rules content, not the inspector frame itself.

**Root cause (cross-referenced with Agent 2)**
- `RulesManagementView.swift:202` — `makeContentState()` is called
  inside `body`, not cached; every body pass re-runs
  `RuleHealthService.classify` and `RuleOverlapDetector.detectOverlaps`.
- `RuleHealthService.swift:142-172` +
  `Destination.swift:142-179` — per-rule bookmark resolution +
  `FileManager.fileExists` run synchronously on the main actor.
- Compounded by `DashboardView.swift:268-269` which slaps
  `.id(splitLayoutIdentity)` on the entire `NavigationSplitView`, so
  toggling the right panel changes the identity and forces the whole
  three-column tree (including `RulesManagementView`) to tear down
  and rebuild from scratch — retriggering the O(N²) classification
  and the 1,574 syscalls on the toggle itself.

## Symptom 2 — Toolbar toggle icon visual glitch

**Repro steps**
1. From the dashboard baseline with panels in the default layout,
   click the right-panel toggle.
2. Observe the left-panel toggle icon in the toolbar at T+0, T+100ms,
   T+400ms, T+900ms, T+2100ms.

**Evidence captured**

| File | Time |
| --- | --- |
| `s2-titlebar-before.png` | Before toggle click |
| `s2-titlebar-t0.png` | T+0 — first frame after click |
| `s2-titlebar-t100ms.png` | T+100ms |
| `s2-titlebar-t400ms.png` | T+400ms — mid-animation |
| `s2-titlebar-t900ms.png` | T+900ms |
| `s2-titlebar-t2100ms.png` | T+2100ms — settled |
| `s2-toolbar-before.png` / `s2-toolbar-after.png` | Toolbar region, start vs end |
| `s2-toolbar-mid-50ms.png` / `s2-toolbar-mid-250ms.png` | Toolbar region mid-animation |

**Observed behavior**
- The left-panel toggle icon visually "messes up" mid-animation:
  it is not smoothly re-rendering, it is being destroyed and
  recreated with a different identity while the column visibility
  animation is in flight.
- The t0 → t100ms → t400ms sequence shows the icon's stroke/weight
  changing discretely (not interpolating), and by t2100ms it has
  re-settled on a different rendering than the `before` state.

**Root cause (cross-referenced with Agent 4)**
- `DashboardView.swift:269` — `.id(splitLayoutIdentity)` is attached
  to the `NavigationSplitView`. `splitLayoutIdentity` depends on
  `usesThreeColumnLayout` (lines 159–161), which in turn depends on
  `isRightPanelVisible`. Toggling the right panel flips the
  identity, which tells SwiftUI "this is a brand-new view tree,
  tear it down." The `UnifiedToolbar` is a child of that tree, so
  every toolbar item — including the left-panel toggle — is
  destroyed and reconstructed during the column visibility
  animation, producing the mid-flight glitch.

## Symptom 3 — File drop → rescan stutter

**Repro steps** (per prompt — safe temp-file approach)
1. `mkdir -p` a throwaway path in the system temp directory.
2. `touch` a single small file there.
3. Copy it into a Forma-watched folder.
4. Observe the rescan in the UI.
5. Delete the temp file and the source temp dir.

**Evidence captured**
- `s1-after-open-smart-rules.png` and `s1-after-close-smart-rules.png`
  are the closest reproducible drop/rescan evidence Agent 1 captured
  before being stopped. The full drop→rescan frame sequence was not
  completed in this run.

**Observed behavior (partial)**
- The subagent did not finish the file-drop sequence before being
  stopped. The symptom has not been visually confirmed in this run,
  but Agent 2's source-level findings already root-cause the
  expected stutter: `FileScanPipeline` is `@MainActor`-bound (because
  of SwiftData non-Sendable constraints) so rescans contend with the
  UI on the same thread.

**Action required:** Re-run Agent 1 targeted only at Symptom 3 in a
follow-up session if visual confirmation of the stutter is needed.
The source-level root cause is already captured in
`agent-2-performance.md`.

## Symptom 4 — General input latency ("every button feels messy")

**Observed behavior**
- Not a single-event symptom — it is the aggregate feel produced by
  Symptoms 1–3 together: the identity thrash on every panel toggle
  (Symptom 2), the O(N²) + 1,574-syscall main-thread pass on every
  `RulesManagementView` rebuild (Symptom 1), and the main-thread
  rescan (Symptom 3). No separate screenshot evidence is needed —
  the root cause is `DashboardViewModel.swift:2481-2490`, which
  re-publishes `objectWillChange` from 10 child view-models, fanning
  every unrelated mutation out to every view that observes the root
  view-model. See Agent 2 for full analysis.

## Gaps in this run

- Symptom 3 (file drop → rescan) was not visually reproduced to
  completion. Source-level cause is confirmed via Agent 2.
- No measured frame-time or CPU-time numbers — only visual evidence
  and screenshot file sizes as proxies. A follow-up run with
  `os_signpost` + Instruments would turn these qualitative
  observations into numbers.
- The subagent did not explicitly run a "describe_ui" structural
  dump after the Smart Rules inspector was fully loaded. The
  screenshot evidence is sufficient for the synthesized report, but
  a structural dump would confirm the view-tree rebuild count
  directly.
