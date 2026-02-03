# Changelog

Canonical changelog: [Docs/Getting-Started/CHANGELOG.md](Docs/Getting-Started/CHANGELOG.md).

Use this short template to stage upcoming notes; add finalized entries to the canonical changelog as changes land.

## [Unreleased]
### Added
- Smart Insight actions now deep-link into relevant views (large files, downloads, screenshots) and can prefill the rule editor.
- Category scope editor now includes a folder picker for scoped categories.
- Bulk operation progress overlay now supports cancellation.
- Grid view now shows confidence indicators alongside destination badges, with tooltips that include match reasons when available.

### Changed
- Learned patterns persist unified Destinations for bookmark-aware suggestions.
- ML destination predictions incorporate project clusters, real training counts, and bookmark-backed destinations when possible.
- Auto-organize eligibility now respects per-folder automation exclusions.
- Rules list now flags destinations missing folder access with a review filter, and Rule Editor offers a quick picker to resolve them.

### Fixed
- Treemap taps now navigate to the corresponding category view.
- Reduced repeated rule-scan warnings for unresolvable placeholder destinations.

### Removed
- Deprecated API cleanup: removed legacy `FileItem`/`FileMetadata` initializers, `RuleService.addRule(_:)`, and deprecated error type aliases.
