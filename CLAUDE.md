# Forma File Organizing — macOS App

## Build & Test
```
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit"
```

## Architecture
- **Pattern**: MVVM with Service Layer + Coordinator
- **Stack**: SwiftUI, SwiftData, AppKit (macOS 15.0+, Swift 5.9+)
- **No external dependencies** — pure Apple frameworks
- App source in `Forma File Organizing/`; marketing site in `forma-website/`

### Layer Responsibilities
- **Models/** — SwiftData `@Model` classes (FileItem, Rule, LearnedPattern, etc.)
- **Services/** — Business logic, stateless where possible. Protocol-based for testability
- **ViewModels/** — `@MainActor @Observable` state management. DashboardViewModel coordinates child VMs
- **Views/** — Pure SwiftUI rendering. No business logic in views
- **Components/** — Reusable UI elements prefixed with `Forma` (FormaCheckbox, FormaThumbnail, etc.)
- **Coordinators/** — Navigation, lifecycle, and operation orchestration
- **DesignSystem/** — Tokens: FormaColors, FormaTypography, FormaSpacing, FormaMicroanimations
- **Configuration/** — App-wide settings and feature flags

### Key Patterns
- Services use protocols (FileSystemServiceProtocol, etc.) — always program to the protocol
- DashboardViewModel is the root coordinator composing FileScanVM, FilterVM, SelectionVM, etc.
- File access uses security-scoped bookmarks (sandboxed app)
- ML features gated via FeatureFlagService — always gate at entry point with `FeatureFlagService.shared.isEnabled(...)`
- Undo/redo via command pattern in ActivityLoggingService

## Conventions
- All ViewModels must be `@MainActor`
- Use design system tokens (FormaColors, FormaSpacing, FormaTypography) — never hardcode colors/spacing
- Component naming: prefix reusable components with `Forma`
- File operations must go through FileOperationsService (handles atomic ops + rollback)
- New services need a protocol + mock for testing
- Tests use TemporaryDirectory and InMemoryBookmarkStore helpers from TestHelpers/
- For file-level UI features, update all surfaces together:
  - `Forma File Organizing/Views/Components/FileRow.swift`
  - `Forma File Organizing/Components/FileListRow.swift`
  - `Forma File Organizing/Components/FileGridItem.swift`
  - `Forma File Organizing/Views/MainContentView.swift`

## Path Focus
- Start with the SwiftUI views and models — not config/build files
- Source lives under `Sources/`, `Forma/`, and the test directories
- Skip build artifacts (`DerivedData/`, `.build/`, `Build/`, `*.xcresult`), caches (`.swiftpm/`, `Pods/`, `Carthage/`, `*.dSYM`), generated files (`*.pbxproj` internals, `Package.resolved`, `Podfile.lock`), and Xcode state (`*.xcuserstate`, `xcuserdata/`, `IDEWorkspaceChecks.plist`)

## Watch Out For
- Security-scoped bookmarks: always startAccessingSecurityScopedResource/stop properly
- Update entitlements file when capabilities change
- FileItem paths must be unique — SwiftData enforces this
- PredictionEngine confidence threshold: don't show suggestions below configured minimum
- Rule precedence matters — FileScanPipeline evaluates rules in order
- Automation policies control whether operations auto-execute or require user review
