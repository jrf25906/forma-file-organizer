# Changelog

Canonical changelog: [Docs/Getting-Started/CHANGELOG.md](Docs/Getting-Started/CHANGELOG.md).

Use this short template to stage upcoming notes; add finalized entries to the canonical changelog as changes land.

## [Unreleased]
### Added
- Added launch/legal documentation and marketing-site pages for Privacy Policy and Terms.
- Added a formal `LICENSE` file for the repository.
- Smart Insight actions now deep-link into relevant views (large files, downloads, screenshots) and can prefill the rule editor.
- Category scope editor now includes a folder picker for scoped categories.
- Bulk operation progress overlay now supports cancellation.
- Grid view now shows confidence indicators alongside destination badges, with tooltips that include match reasons when available.

### Changed
- Consolidated marketing web code to `forma-website/` and removed legacy `website/` + `forma-marketing-site/` directories.
- `forma-website` now uses normal in-flow footer layout (no fixed negative-z reveal), and web metadata/sitemap/robots now target `https://formafiles.com`.
- `forma-website` hero/header spacing and anchor offsets were refined to prevent top overlap, and light-mode feature demos now use readable high-contrast surfaces.
- `forma-website` light-mode typography contrast and feature-demo default visibility were corrected, and hero spacing/scale were further tuned for cleaner first paint.
- Documentation navigation was cleaned up by archiving superseded audits/plans/refactor summaries under `Docs/Archive` and updating internal cross-links.
- Dashboard file card/list/grid views now use a readability-first layout with stronger filename hierarchy, a single primary status chip, human-readable metadata summaries, and cleaner hover-only secondary actions.
- Dashboard file presentations now use the spacious density treatment across card/list/grid with expanded spacing and larger visual targets.
- Toolbar view-mode controls now use a native segmented capsule style with shared glass surface, divider rails, and a sliding active state for grid/list/tile switching.
- Pending/All Files toolbar toggle now uses the same segmented capsule treatment, and both segmented controls now include a subtle native-style hover highlight.
- Toolbar grouping controls, inspector toggle, Smart Rules category tabs, and menu-bar automation On/Off toggle now use the same Stocks-style segmented chrome with divider spacing and hover states.
- Toolbar inspector toggle now renders as a standalone control without an outer capsule shell, and keyboard-help access moved to the sidebar’s bottom-right corner.
- Sidebar top-edge chrome above search was removed, inspector toggle moved to the native top-right window toolbar, and sidebar rows/actions now use the same compact native hover treatment as the Settings/Help footer controls.
- Sidebar controls were tuned to a slightly larger native text size and row height for closer parity with desktop app sidebars.
- Inspector toggle now uses a persistent native-sized rounded shell and tighter top-right corner anchoring to better match macOS window controls.
- Sidebar chrome now restores a subtle nested shell stroke/shadow and adjusted top inset so traffic-light alignment feels integrated with the window frame.
- Inspector toggle sizing and corner offset were further tuned to a larger Xcode-like footprint with stronger rounded shell presence.
- Window traffic-light controls now use explicit Xcode-like insets, and the inspector toggle baseline was realigned to that same top toolbar row.
- Titlebar control alignment was further tuned to deeper 24pt insets so traffic lights and inspector control share the same nested-card geometry as Xcode.
- Dark-mode control and text-input surfaces now use deeper charcoal tokens, and checkbox chrome has stronger contrast for clearer affordance.
- Learned patterns persist unified Destinations for bookmark-aware suggestions.
- ML destination predictions incorporate project clusters, real training counts, and bookmark-backed destinations when possible.
- Auto-organize eligibility now respects per-folder automation exclusions.
- Rules list now flags destinations missing folder access with a review filter, and Rule Editor offers a quick picker to resolve them.
- Bulk-review mode now prioritizes the floating action bar by hiding the right-panel primary organize CTA and de-emphasizing always-on row-level organize buttons.
- Inline Rule Builder now uses explicit "When" and "Then" sections with inline validation hints, a disabled-until-valid save action, and an always-visible impact preview.
- Smart Rules empty state now removes duplicate top-level actions and adds starter templates that open the editor with prefilled natural-language prompts.
- Analytics view now runs in a focus mode by hiding the right panel while the Analytics screen is active.
- Productivity Health now includes explicit no-data onboarding guidance with quick actions (scan folders, open pending queue, and create a first rule).
- Settings tabs now render inside a shared shell with unified spacing, surfaces, and background chrome to match the main app.
- File status language is now more consistent across card/list/grid, with compact status indicators and simplified rule-state labeling.
- List/grid interaction targets were increased and secondary text/chip contrast was raised for better accessibility in light and dark themes.
- Dashboard list rows now use a cleaner two-line hierarchy with consolidated metadata for faster scanning.
- Card/list/grid now share the same premium checkbox treatment for consistent selection affordance.
- Improved dark-mode contrast across analytics, insights, and right-panel labels.
- Right-panel hero/inspector secondary text and quick-action surfaces now use stronger dark-mode contrast.
- Quick Action cards now use the same surface treatment as the Automation card for cohesive right-panel styling.
- File Inspector now uses a transparent panel background so content cards float with the same visual language as adjacent UI.
- Smart Rules cards, tabs, and access warning banners now use adaptive dark-mode surfaces and higher-contrast typography.
- Smart Rules and right-panel spacing now follow tighter 8pt rhythm for row height, section gaps, and panel density consistency.
- App Store screenshot UI tests now enforce Smart Rules/right-panel spacing rhythm and minimum contrast thresholds to prevent visual regressions.
- Settings tabs (Rules, Folders, Smart Features, About) now use adaptive dark-mode surfaces, text, and card borders for consistent readability with the rest of the app.
- Settings dark mode polish now includes improved disabled-state contrast in Smart Features and a subtler About logo container treatment.
- Analytics dashboard now loads productivity report data through a single consolidated background pass and avoids redundant reloads on repeat view appearances, reducing main-thread fetch pressure and improving load performance.
- Content search now runs its heavy scan work off the main actor and uses indexed path lookups in `DashboardViewModel` to avoid per-row linear searches.
- Folder scans now use prefetched URL resource keys and parallelized standard-folder scan tasks to reduce filesystem syscall overhead.
- Thumbnail loading now checks memory/disk caches before opening security scopes and skips redundant stale-metadata checks on disk-cache hits.
- Duplicate detection now reuses compiled regexes, streams file hashing in chunks, and uses bucketed near-name matching to reduce memory and comparison cost.
- Settings "Launch at Login" now syncs with macOS Login Items (`SMAppService`) and reports failures instead of failing silently.
- Dashboard startup scans now respect the "Auto-scan on Launch" setting, including post-onboarding auto-scan behavior.
- Menu bar Settings now uses the shared app settings opener instead of synthetic keyboard events.
- Dashboard window chrome now uses native `NavigationSplitView` columns (sidebar/content/inspector) instead of floating overlay panes.
- Restored layered vibrancy in the native split-view shell via pane-specific materials and a gradient-backed window surface.

### Fixed
- Treemap taps now navigate to the corresponding category view.
- Reduced repeated rule-scan warnings for unresolvable placeholder destinations.
- File selection checkboxes now keep a stable position and larger click target across card/list/grid views for more reliable selection.
- Toolbar controls now use explicit sizing to avoid ambiguous AppKit toolbar layout warnings.
- Scroll views now reserve deterministic bottom space for the floating action bar to prevent content overlap in all view modes.
- Shift-click range selection now works consistently across card/list/grid file views by using a shared selection anchor.
- Removed oversized translucent "lens" artifacts from split-view panes by avoiding full-bleed `glassEffect` and using pane-safe native material fallback while retaining layered vibrancy.

### Removed
- Deprecated API cleanup: removed legacy `FileItem`/`FileMetadata` initializers, `RuleService.addRule(_:)`, and deprecated error type aliases.
