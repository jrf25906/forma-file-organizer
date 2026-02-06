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
- Documentation navigation was cleaned up by archiving superseded audits/plans/refactor summaries under `Docs/Archive` and updating internal cross-links.
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
- Improved dark-mode contrast across analytics, insights, and right-panel labels.
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

### Fixed
- Treemap taps now navigate to the corresponding category view.
- Reduced repeated rule-scan warnings for unresolvable placeholder destinations.

### Removed
- Deprecated API cleanup: removed legacy `FileItem`/`FileMetadata` initializers, `RuleService.addRule(_:)`, and deprecated error type aliases.
