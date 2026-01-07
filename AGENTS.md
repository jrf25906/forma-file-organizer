# Repository Guidelines

## Project Structure & Modules
- App source lives in `Forma File Organizing/` with `Models/`, `ViewModels/`, `Views/`, `Services/`, `Components/`, `DesignSystem/`, and `Coordinators/`. Static assets sit in `Resources/` and `Assets.xcassets`.
- Tests are under `Forma File OrganizingTests/` with helpers in `TestHelpers/` (e.g., `TemporaryDirectory.swift` for filesystem-safe cases). UI/UI automation live in `Forma File OrganizingUITests/`.
- Configuration and entitlements are in `Configuration/` and `Forma_File_Organizing.entitlements`; adjust permissions there instead of embedding ad-hoc checks.

## Build, Test, and Development Commands
- Build (Debug): `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build`
- Run in Xcode: `open "Forma File Organizing.xcodeproj"` then `⌘R` on the `Forma File Organizing` scheme.
- Tests (macOS destination): `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS'`
- Clean: `xcodebuild clean -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing"` (deep clean: remove DerivedData if build artifacts misbehave).

## Coding Style & Naming Conventions
- Language: Swift 5.9, SwiftUI-first; prefer structs and protocol-oriented patterns in services and models.
- Indentation: 4 spaces; keep braces on the same line; favor `private`/`fileprivate` for helpers.
- Naming: `PascalCase` for types, `camelCase` for vars/functions, `enum` cases in `camelCase`, async functions prefixed with verbs (`load`, `scan`, `move`).
- UI: use tokens from `DesignSystem/` (`FormaColors`, `FormaTypography`, `FormaSpacing`) instead of hard-coded values; keep new components reusable in `Components/`.

## Testing Guidelines
- Framework: XCTest. Default to mock-based unit tests for ViewModels/RuleEngine; use real filesystem integration tests only when needed.
- Helper: `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` provides disposable directories, file creation, and cleanup—use it instead of `/tmp` manually.
- Naming: `test<Subject>_<Behavior>()`; cover both success and failure paths. Keep MainActor in mind when testing UI-bound models.
- Run full suite before PRs (`xcodebuild test ...`). Add targeted integration tests for file moves, bookmark handling, and undo flows when touching `Services/`.

## Commit & Pull Request Guidelines
- Commits: concise, imperative subjects (e.g., “Add rule engine batching”), group related changes only. Reference tickets/issues when available.
- PRs: include a short summary, testing notes (commands run), and screenshots/screencasts for UI changes. Call out risk areas (file I/O, security-scoped bookmarks) and any follow-ups.

## Documentation Guidelines (Documentation-as-Code)
Keep documentation synchronized with code changes. When implementing features:

- **TODO.md**: Update roadmap items (mark complete, add new items) when features ship or scope changes.
- **CHANGELOG.md**: Add entries under `[Unreleased]` for user-facing changes; follow Keep a Changelog format.
- **API_REFERENCE.md**: Update when adding/changing public APIs, model properties, or service methods.
- **Feature docs** (`Docs/Features/`): Create or update when implementing significant features.
- **Architecture docs** (`Docs/Architecture/`): Update when changing system design or adding new patterns.

Docs live in the repo, not external wikis—changes to code and docs should ship together. Prefer updating existing docs over creating new ones; archive (don't delete) obsolete content.

## Security & Configuration Tips
- Respect sandboxing: file access flows through security-scoped bookmarks; do not bypass by using absolute paths outside granted scopes.
- Update entitlements in `Forma_File_Organizing.entitlements` when adding capabilities; keep code signing configs in sync with Xcode project settings.
- When handling user files, prefer non-destructive operations and ensure undo support via `UndoCommand` or activity tracking where applicable.

## Feature Flags Pattern
All AI/ML features and significant new capabilities must support user opt-out via feature flags:

- **Hierarchical toggles**: Master "AI Features" toggle + individual feature toggles. When master is OFF, all child features are disabled regardless of individual settings.
- **Default ON**: Features default to enabled for discoverability; users opt out if desired.
- **Implementation**: Use `FeatureFlagService.shared.isEnabled(.featureName)` guard at the entry point of the feature's logic.
- **Settings UI**: Add toggles under Settings → Smart Features section with clear descriptions of what each feature does.
- **New features**: When building any AI/ML feature (pattern learning, predictions, content scanning, suggestions, context detection), include the feature flag from the start—not as an afterthought.

Example pattern:
```swift
func recordFileMove(file: FileItem, destination: URL) {
    guard FeatureFlagService.shared.isEnabled(.patternLearning) else { return }
    // Feature logic here
}
```

## Multi-View Mode Development
When implementing features that span multiple view modes (card/list/grid), create a checklist of all components that need updating. It's easy to implement a feature in one view and forget the others.

**View mode components to update:**
- `FileRow.swift` - Card view (single-column, rich detail)
- `FileListRow.swift` - List view (compact rows)
- `FileGridItem.swift` - Grid view (tile layout, 2+ per row)

**Checklist for new file-level features:**
1. Add property/parameter to all three components
2. Update call sites in `MainContentView.swift` (`cardView`, `listView`, `gridView`)
3. Ensure SwiftUI reactivity with `.id()` modifiers if feature depends on async state
4. Test all three view modes visually
