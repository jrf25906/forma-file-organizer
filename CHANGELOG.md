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
- Learned patterns persist unified Destinations for bookmark-aware suggestions.
- ML destination predictions incorporate project clusters, real training counts, and bookmark-backed destinations when possible.
- Auto-organize eligibility now respects per-folder automation exclusions.
- Rules list now flags destinations missing folder access with a review filter, and Rule Editor offers a quick picker to resolve them.
- Improved dark-mode contrast across analytics, insights, and right-panel labels.
- Smart Rules cards, tabs, and access warning banners now use adaptive dark-mode surfaces and higher-contrast typography.
- Smart Rules and right-panel spacing now follow tighter 8pt rhythm for row height, section gaps, and panel density consistency.
- App Store screenshot UI tests now enforce Smart Rules/right-panel spacing rhythm and minimum contrast thresholds to prevent visual regressions.
- Settings tabs (Rules, Folders, Smart Features, About) now use adaptive dark-mode surfaces, text, and card borders for consistent readability with the rest of the app.
- Settings dark mode polish now includes improved disabled-state contrast in Smart Features and a subtler About logo container treatment.
- Analytics dashboard now loads productivity report data through a single consolidated background pass and avoids redundant reloads on repeat view appearances, reducing main-thread fetch pressure and improving load performance.

### Fixed
- Treemap taps now navigate to the corresponding category view.
- Reduced repeated rule-scan warnings for unresolvable placeholder destinations.

### Removed
- Deprecated API cleanup: removed legacy `FileItem`/`FileMetadata` initializers, `RuleService.addRule(_:)`, and deprecated error type aliases.
