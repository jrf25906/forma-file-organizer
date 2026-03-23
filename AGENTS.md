# Repository Guidelines

Global workflow lives in `~/.codex/AGENTS.md`.
Read `codex-project.toml` before planning, editing, or testing.

## Local Notes
- App source is in `Forma File Organizing/`; the marketing site is in `forma-website/`.
- Use `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` for filesystem-safe tests instead of ad hoc temp paths.
- Respect security-scoped bookmarks and update `Forma File Organizing/Forma_File_Organizing.entitlements` when capabilities change.
- AI/ML features must be gated at the entry point with `FeatureFlagService.shared.isEnabled(...)`.
- For file-level UI features, update card/list/grid surfaces together:
  - `Forma File Organizing/Views/Components/FileRow.swift`
  - `Forma File Organizing/Components/FileListRow.swift`
  - `Forma File Organizing/Components/FileGridItem.swift`
  - `Forma File Organizing/Views/MainContentView.swift`
