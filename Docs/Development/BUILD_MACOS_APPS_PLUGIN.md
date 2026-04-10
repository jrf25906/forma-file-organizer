# `build-macos-apps` Plugin Guide

**Status:** Current  
**Last Updated:** 2026-04-09  
**Audience:** Developers and coding agents

Use `build-macos-apps` as a strict workflow helper for the native Forma app. Do not let it invent build commands, testing commands, or release steps that disagree with this repository.

## Scope

- Use it for `Forma File Organizing/`.
- Do not use it for `forma-website/`; that project follows its own Next.js and Vercel workflow.
- Read `codex-project.toml` and `AGENTS.md` before planning, editing, testing, or shipping.

## How To Use It In Forma

The plugin is most useful for:

- debugging broken native app behavior
- adding or refining macOS app features
- running focused XCTest coverage
- performance and launch investigations
- release preparation for the macOS app

Treat the plugin as a workflow harness around Forma's existing build, test, verification, and release conventions.

## Repo Rules It Must Follow

- Use repo-declared `xcodebuild` commands from `codex-project.toml`.
- Keep app work inside `Forma File Organizing/` unless the task explicitly involves docs, tests, release assets, or the website.
- Respect security-scoped bookmark handling and keep `Forma File Organizing/Forma_File_Organizing.entitlements` in sync with capability changes.
- Gate AI or ML entry points with `FeatureFlagService.shared.isEnabled(...)`.
- For file-level UI work, update `FileRow`, `FileListRow`, `FileGridItem`, and `MainContentView` together.
- Reuse `fastlane/Fastfile` and the existing `Scripts/` helpers for screenshots, docs checks, and release preparation.
- Update `TODO.md`, `CHANGELOG.md`, and `API_REFERENCE.md` when workflow, behavior, or API expectations change.

## Reusable Prompt

Copy this prompt when you want Codex to use the plugin against Forma:

```text
Use build-macos-apps for the Forma macOS app only. Before any work, read codex-project.toml and AGENTS.md in the repo root and follow them exactly. Use the repo-declared xcodebuild commands instead of plugin defaults. Limit native app implementation to Forma File Organizing/ unless the task explicitly includes docs, tests, release assets, or related integration points.

If work touches file operations, bookmarks, undo flows, or entitlements, add targeted verification for those paths. If work touches a file-level UI feature, update FileRow.swift, FileListRow.swift, FileGridItem.swift, and MainContentView.swift together. Gate any AI/ML entry point with FeatureFlagService.shared.isEnabled(...). Reuse fastlane/ and Scripts/ for screenshots, docs checks, and release prep. Sync TODO.md, CHANGELOG.md, and API_REFERENCE.md when behavior, workflow, or API expectations change.
```

## Verification Expectations

Ask the plugin to prove outcomes with the repo's actual commands:

```bash
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS'
python3 Scripts/check_docs.py
```

If UI behavior changed, also launch and inspect the app manually in Xcode or by opening the built app bundle.

## What To Avoid

- Do not let the plugin treat the website and the macOS app as one workflow.
- Do not let it replace repo commands with guessed `xcodebuild` flags.
- Do not skip bookmark, entitlement, or undo verification on file-operation work.
- Do not add AI-powered entry points without the feature-flag gate.
