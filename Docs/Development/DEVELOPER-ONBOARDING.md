# Forma - Developer Onboarding

**Version:** 1.0  
**Last Updated:** 2026-01-06  
**Audience:** New contributors and maintainers

---

## 1. Onboarding Checklist

Use this as your “first day” checklist:

1. **Set up your environment**
   - Install Xcode 15+ on macOS 14+ (Sonoma)
   - Clone/open the repo
   - Build and run the app
2. **Learn the product**
   - Skim `README.md` and `Docs/Getting-Started/USER-GUIDE.md`
   - Run through the full onboarding flow in the app
3. **Understand the architecture**
   - Read `Docs/Architecture/ARCHITECTURE.md`
   - Skim `Docs/Development/DEVELOPMENT.md` (project structure + patterns)
4. **Run tests**
   - Execute the unit tests and UI tests once
5. **Make a small change**
   - Pick a low‑risk task (copy tweak, small UI cleanup, or test addition)
   - Follow the contribution workflow (branch → commit → PR)

Once you’ve done the above, you’re ready to work on real features.

---

## 2. Environment & Setup (Developer View)

This is a developer‑focused summary. For a more user‑oriented setup guide, see `Docs/Getting-Started/SETUP.md`.

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9
- Apple Developer account (for code signing)

### Clone & Open

```bash
git clone <repo-url>
cd <repo-root>
open "Forma File Organizing.xcodeproj"
```

In Xcode:
- Select the **“Forma File Organizing”** scheme
- Set destination to **“My Mac”**
- Press `⌘R` to build and run

### Entitlements & Permissions

- Entitlements file: `Forma File Organizing/Forma_File_Organizing.entitlements`
- Required keys:
  - `com.apple.security.files.user-selected.read-write`
  - `com.apple.security.files.bookmarks.app-scope`
- In the target’s **Build Settings**, `Code Signing Entitlements` must point to:
  - `Forma File Organizing/Forma_File_Organizing.entitlements`

For more detail, see the **Entitlements Setup** section in `Docs/Development/DEVELOPMENT.md`.

### Forcing Onboarding During Development

To repeatedly test the onboarding flow:

1. Edit the **Run** scheme for *Forma File Organizing*.
2. Under **Arguments Passed On Launch**, add:
   ```text
   --force-onboarding
   ```
3. Run the app; onboarding will appear every launch until you remove the flag.

Behavior is described in the **Onboarding Debugging** section of `DEVELOPMENT.md`.

---

## 3. Codebase Tour (10-Minute Overview)

This section gives you a quick mental model; `DEVELOPMENT.md` and `ARCHITECTURE.md` provide the deep dive.

### App Target

**Location:** `Forma File Organizing/`

- `Forma_File_OrganizingApp.swift` – SwiftUI app entry point, SwiftData container, global configuration
- `Configuration/AppConfiguration.swift` – Feature flags, environment configuration

### Layers

**Models (`Models/`):**
- SwiftData models (`@Model`) such as `FileItem`, `Rule`, `OrganizationTemplate`, `OrganizationPersonality`, `ProjectCluster`, `ActivityItem`
- Encapsulate data and relationships; keep business logic in services where possible

**Services (`Services/`):**
- `FileSystemService` – scanning, metadata, permissions
- `RuleEngine` – rule evaluation and matching
- `FileOperationsService` – secure file moves, undoable commands
- `ContextDetectionService`, `LearningService`, `InsightsService` – AI/ML and analytics features
- `CustomFolderManager`, `SecureBookmarkStore` – multi‑folder and permission management
- Services are where **business logic** lives; keep them testable and free of UI concerns.

**ViewModels (`ViewModels/`):**
- `DashboardViewModel` – main app state and flows
- `ReviewViewModel` – legacy review flow
- `NavigationViewModel` – navigation state
- All are `@MainActor` and use services to perform work.

**Views (`Views/` + `Components/`):**
- Screen‑level views: `DashboardView`, `SidebarView`, `MainContentView`, `RightPanelView`, `Onboarding/OnboardingFlowView`, `PersonalityQuizView`, `Settings/SettingsView`, etc.
- Reusable components live in `Components/` and should use `FormaColors`, `FormaTypography`, and `FormaSpacing`.

**Tests (`Forma File OrganizingTests/`):**
- Unit tests for services and view models
- Helpers in `TestHelpers/TemporaryDirectory.swift` for filesystem‑safe integration tests

For a visual architecture diagram and data flow, see `Docs/Architecture/ARCHITECTURE.md` and `Docs/Architecture/ComponentArchitecture.md`.

---

## 4. Development Patterns (How to Fit In)

Forma uses a **SwiftUI + MVVM + Service Layer** architecture with protocol‑oriented patterns.

### 4.1 MVVM + Services

Typical flow:

1. **View** (SwiftUI)
   - Declares UI and binds to `@ObservedObject` or `@StateObject` view models
2. **ViewModel** (`@MainActor`)
   - Holds published state
   - Coordinates calls to services
3. **Service**
   - Performs IO or business logic
   - Returns models or throws errors
4. **Models**
   - Store state in SwiftData

When you add new behavior:
- Prefer **extending services** (or adding new ones) rather than pushing logic into views or view models.
- Keep view models thin: orchestration and state, not heavy logic.

See **Architecture Patterns** in `Docs/Development/DEVELOPMENT.md` for concrete examples.

### 4.2 Design System Usage

All new UI should:

- Use **design tokens** from:
  - `DesignSystem/FormaColors.swift`
  - `DesignSystem/FormaTypography.swift`
  - `DesignSystem/FormaSpacing.swift`
- Avoid hard‑coded colors and fonts
- Prefer reusable components in `Components/` where possible

For details, see `Docs/Design/DesignSystem.md` and `Docs/Design/UI-GUIDELINES.md`.

### 4.3 Feature Flags

All AI/ML and major new capabilities must be behind feature flags:

- Use `FeatureFlagService.shared.isEnabled(.featureName)` guards at feature entry points.
- Respect the master “AI Features” toggle and individual feature toggles.
- When adding a new AI feature:
  - Define a new feature flag
  - Gate logic in services and UI
  - Update Settings → Smart Features to include the toggle

This pattern is described in the repo’s `AGENTS.md` and reflected in services like `LearningService` and `ContextDetectionService`.

---

## 5. Architecture Deep-Dive Path

If you want a structured learning path for the architecture:

### Level 1 – Big Picture

1. `README.md` – Product overview and main folders
2. `Docs/Getting-Started/USER-GUIDE.md` – How users experience the app
3. `Docs/Architecture/ARCHITECTURE.md` – High-level architecture: modules, flows, and key diagrams

### Level 2 – Feature-Specific

1. `Docs/Features/PersonalitySystem.md` – Personality quiz and template mapping
2. `Docs/Features/OrganizationTemplates.md` – Template definitions and folder structures
3. `Docs/Features/AIFeatures.md` – Pattern learning, duplicates, and AI‑driven components

### Level 3 – Implementation Details

1. `Docs/Development/DEVELOPMENT.md` – Project structure, patterns, common tasks
2. `Docs/API-Reference/API_REFERENCE.md` – Service and model APIs
3. `Docs/API-Reference/USER_RULES_GUIDE.md` – Rule system from a user perspective
4. `Docs/Security/SECURITY_CONFIGURATION.md` and `Docs/Security/SECURITY_CHECKLIST.md` – Security and permissions

You don’t have to read everything at once; the goal is to know **where** to look when you’re implementing or debugging a feature.

---

## 6. Working with Tests

### 6.1 Running Tests

From the command line:

```bash
xcodebuild test \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -destination "platform=macOS"
```

In Xcode:

- Press `⌘U` to run all tests
- Use the Test navigator (`⌘6`) to run specific suites or tests

For more, see `Docs/Development/TESTING.md` and `Docs/Testing/Comprehensive-Feature-Testing-Guide.md`.

### 6.2 What to Test

- **Services**: RuleEngine, FileOperationsService, FileSystemService, LearningService, etc.
  - Use **mock services** for fast unit tests
  - Use `TemporaryDirectory` for safe filesystem integration tests
- **ViewModels**: DashboardViewModel, NavigationViewModel
  - Inject mocks to avoid filesystem and UI dependencies
- **UI**: critical workflows (onboarding, permission flows, basic organizing)
  - Use UI tests where they provide real value

When you add a feature:

- Prefer **unit tests** for logic
- Add integration tests when touching file IO, bookmarks, or undo logic
- Update or add **manual test scenarios** if UI flows change

### 6.3 Getting Started for QA (Manual Testing)

For QA and manual testers, here is a standard path to get productive quickly:

1. **Read the user guide**  
   - Skim `Docs/Getting-Started/USER-GUIDE.md` to understand the product from a user’s perspective.

2. **Set up a clean environment**  
   - Build and run the app from Xcode.
   - Use the `--force-onboarding` launch argument (see Section 2) to reliably trigger the onboarding flow on each run when needed.

3. **Run the core smoke flow once per build**  
   - Complete onboarding (grant Desktop, answer quiz, accept template).
   - Scan Desktop, accept a few safe suggestions (screenshots/archives), and verify:
     - Files move to the expected destinations.
     - Activity feed shows the operations and supports Undo.
   - Open Downloads, apply at least one rule‑driven move, and verify the destination.

4. **Verify key edge cases regularly**  
   - Purposefully select the wrong folder during a permission prompt and confirm that the app:
     - Shows a clear error.
     - Offers a way to retry with the correct folder.
   - Toggle AI features in Settings → Smart Features:
     - With AI off, ensure suggestions/insights behave as expected for non‑AI flows.
     - With AI on, verify predictions and duplicate detection appear where documented.

5. **Use dedicated testing docs for deeper passes**  
   - `Docs/Testing/Comprehensive-Feature-Testing-Guide.md` – full feature coverage.
   - `Docs/Testing/Personality-Quiz-Testing-Guide.md` – detailed quiz and onboarding scenarios.
   - `Docs/Development/TESTING.md` – guidance on when to add automated coverage for issues found manually.

---

## 7. Contribution Workflow

### Branching

Recommended naming:

- `feature/<short-description>` – new features
- `bugfix/<short-description>` – bug fixes
- `refactor/<short-description>` – internal changes
- `docs/<short-description>` – documentation updates

### Commits

Use concise, imperative messages. Some teams use prefixes like:

- `feat: Add rule conflict detection`
- `fix: Handle stale bookmarks on launch`
- `docs: Add developer onboarding guide`
- `test: Cover FileOperationsService error paths`

Commit related changes together; avoid large, mixed commits.

### Pull Requests

Include in your PR:

- **Summary:** What changed and why
- **Type:** Bug fix, feature, refactor, docs
- **Testing:** Commands run (e.g., `xcodebuild test …`, manual flows)
- **Screenshots:** For UI changes, especially onboarding/settings/dashboard
- **Risks:** File IO, security-scoped bookmarks, undo behavior, or data migrations

Follow the **Contributing Guidelines** section in `Docs/Development/DEVELOPMENT.md` for more detail.

---

## 8. Good First Tasks

If you’re new and looking for a first contribution, consider:

- Documentation:
  - Add or refine sections in `USER-GUIDE.md`
  - Expand examples in `USER_RULES_GUIDE.md`
- Testing:
  - Add tests around existing `RuleEngine` behaviors
  - Improve coverage in `FileOperationsServiceTests`
- UI polish:
  - Improve empty states (see `Docs/Design/Forma-Empty-States.md`)
  - Add keyboard shortcuts to match `Docs/Design/Forma-Keyboard-Shortcuts.md`
- Architecture:
  - Help extract logic from views into services where TODOs call this out

Check `Docs/Getting-Started/TODO.md` for current priorities and open documentation tasks.

---

## 9. Getting Help

If you’re stuck:

- Start with the **Documentation Index** in `Docs/README.md`
- Use the **Codebase Audit** (`Docs/CODEBASE_AUDIT.md`) to find hot spots and TODOs
- Look at existing patterns in:
  - `DashboardViewModel.swift`
  - `FileSystemService.swift`
  - `FileOperationsService.swift`
  - `RuleEngine.swift`
- Ask for guidance in code review; this codebase is designed to be approachable and consistently structured.

---

**Document Status:** Initial developer onboarding guide completed.  
**Next Steps:** Add screenshots/diagrams for architecture and example flows as they stabilize.
