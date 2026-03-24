# Window Presentation Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Forma open in a more focused, adaptive default window posture, persist the user’s preferred window/panel state after first launch, and keep the right panel contextual instead of always consuming width.

**Architecture:** Add a small window presentation policy layer that owns first-launch defaults, large-screen breakpoints, and persisted inspector visibility. Keep AppKit window behavior in the app/scene layer, while `DashboardViewModel` consumes a simple persisted “should the right panel start visible?” decision so panel behavior remains testable and does not spread across unrelated dashboard logic.

**Tech Stack:** SwiftUI, AppKit (`NSWindow` autosave + window configuration), Combine, XCTest, macOS UI tests

---

### Task 1: Define launch policy and persistence seams

**Files:**
- Create: `Forma File Organizing/Utilities/WindowPresentationPolicy.swift`
- Create: `Forma File Organizing/Utilities/WindowPresentationStore.swift`
- Test: `Forma File OrganizingTests/WindowPresentationPolicyTests.swift`

- [ ] **Step 1: Write the failing policy tests**

Create `Forma File OrganizingTests/WindowPresentationPolicyTests.swift` with focused tests for:

```swift
func test_firstLaunchUsesFocusedDefaultWindowSize() {
    let policy = WindowPresentationPolicy()
    let result = policy.initialLayout(
        hasSavedWindowFrame: false,
        screenVisibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        hasMeaningfulDefaultPanelContent: false,
        savedInspectorVisibility: nil
    )

    XCTAssertEqual(result.initialSize.width, 1340)
    XCTAssertEqual(result.initialSize.height, 900)
    XCTAssertFalse(result.shouldShowInspector)
}

func test_largeScreenCanShowInspectorWhenContentIsMeaningful() {
    let policy = WindowPresentationPolicy()
    let result = policy.initialLayout(
        hasSavedWindowFrame: false,
        screenVisibleFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
        hasMeaningfulDefaultPanelContent: true,
        savedInspectorVisibility: nil
    )

    XCTAssertTrue(result.shouldShowInspector)
}

func test_savedInspectorPreferenceOverridesAdaptiveDefault() {
    let policy = WindowPresentationPolicy()
    let result = policy.initialLayout(
        hasSavedWindowFrame: true,
        screenVisibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        hasMeaningfulDefaultPanelContent: true,
        savedInspectorVisibility: false
    )

    XCTAssertFalse(result.shouldShowInspector)
}
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WindowPresentationPolicyTests"
```

Expected: FAIL because the new policy/store types do not exist yet.

- [ ] **Step 3: Implement the minimal policy and storage types**

Create `Forma File Organizing/Utilities/WindowPresentationPolicy.swift` with:

```swift
import CoreGraphics

struct WindowPresentationPolicy {
    struct LaunchLayout: Equatable {
        let initialSize: CGSize
        let shouldShowInspector: Bool
    }

    private let focusedDefaultSize = CGSize(width: 1340, height: 900)
    private let inspectorEligibleWidth: CGFloat = 1500

    func initialLayout(
        hasSavedWindowFrame: Bool,
        screenVisibleFrame: CGRect,
        hasMeaningfulDefaultPanelContent: Bool,
        savedInspectorVisibility: Bool?
    ) -> LaunchLayout {
        let inspectorPreference = savedInspectorVisibility ?? (
            screenVisibleFrame.width >= inspectorEligibleWidth && hasMeaningfulDefaultPanelContent
        )

        return LaunchLayout(
            initialSize: focusedDefaultSize,
            shouldShowInspector: inspectorPreference
        )
    }
}
```

Create `Forma File Organizing/Utilities/WindowPresentationStore.swift` with a narrow persistence API:

```swift
import Foundation

@MainActor
final class WindowPresentationStore {
    enum Keys {
        static let inspectorVisible = "windowPresentation.inspectorVisible"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var savedInspectorVisibility: Bool? {
        guard defaults.object(forKey: Keys.inspectorVisible) != nil else { return nil }
        return defaults.bool(forKey: Keys.inspectorVisible)
    }

    func setInspectorVisible(_ isVisible: Bool) {
        defaults.set(isVisible, forKey: Keys.inspectorVisible)
    }
}
```

- [ ] **Step 4: Run the policy tests to verify they pass**

Run the same command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit the policy layer**

```bash
git add "Forma File Organizing/Utilities/WindowPresentationPolicy.swift" "Forma File Organizing/Utilities/WindowPresentationStore.swift" "Forma File OrganizingTests/WindowPresentationPolicyTests.swift"
git commit -m "feat: add window presentation policy"
```

### Task 2: Move first-launch sizing and native frame persistence into the app window layer

**Files:**
- Modify: `Forma File Organizing/Forma_File_OrganizingApp.swift`
- Modify: `Forma File Organizing/DesignSystem/FormaSpacing.swift`
- Test: `Forma File OrganizingTests/WindowPresentationPolicyTests.swift`

- [ ] **Step 1: Write the failing test for the focused default size constants**

Extend `Forma File OrganizingTests/WindowPresentationPolicyTests.swift` with:

```swift
func test_focusedDefaultWindowSizeMatchesDesignTokens() {
    XCTAssertEqual(FormaSpacing.Window.preferredWidth, 1340)
    XCTAssertEqual(FormaSpacing.Window.preferredHeight, 900)
}
```

- [ ] **Step 2: Run the focused size test to verify it fails**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WindowPresentationPolicyTests/test_focusedDefaultWindowSizeMatchesDesignTokens"
```

Expected: FAIL because the design tokens still use the older larger default.

- [ ] **Step 3: Implement native window-size defaults and frame autosave**

Update `Forma File Organizing/DesignSystem/FormaSpacing.swift`:

```swift
struct Window {
    static let minWidth: CGFloat = 1040
    static let minHeight: CGFloat = 720
    static let preferredWidth: CGFloat = 1340
    static let preferredHeight: CGFloat = 900
}
```

Update `Forma File Organizing/Forma_File_OrganizingApp.swift` so the main window scene:
- keeps `.windowStyle(.hiddenTitleBar)`
- uses the focused default size tokens
- configures the `NSWindow` with a stable autosave name so macOS restores size/position after the first launch
- only applies the centered default size when there is no saved frame yet

Implementation shape:

```swift
private enum WindowPresentationConstants {
    static let autosaveName = "FormaMainWindow"
}

private func configure(_ window: NSWindow) {
    window.setFrameAutosaveName(WindowPresentationConstants.autosaveName)
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask.insert(.fullSizeContentView)
}
```

- [ ] **Step 4: Re-run the focused size test**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 5: Build the app**

Run:

```bash
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit the window-size update**

```bash
git add "Forma File Organizing/Forma_File_OrganizingApp.swift" "Forma File Organizing/DesignSystem/FormaSpacing.swift" "Forma File OrganizingTests/WindowPresentationPolicyTests.swift"
git commit -m "feat: adopt focused default window sizing"
```

### Task 3: Make right-panel launch behavior contextual and persistent

**Files:**
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Coordinators/PanelStateManager.swift`
- Modify: `Forma File Organizing/Views/DashboardView.swift`
- Modify: `Forma File Organizing/Views/RightPanelView.swift`
- Modify: `Forma File Organizing/Views/Components/UnifiedToolbar.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Write the failing view-model tests**

Add targeted tests to `Forma File OrganizingTests/DashboardViewModelTests.swift`:

```swift
func test_dashboardStartsWithInspectorHiddenWhenPresentationStoreSaysHidden() async {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    let presentationStore = WindowPresentationStore(defaults: defaults)
    presentationStore.setInspectorVisible(false)

    let viewModel = DashboardViewModel(
        services: AppServices(),
        fileSystemService: MockFileSystemService(),
        fileScanPipeline: FileScanPipeline(),
        contentSearchService: ContentSearchService.shared,
        windowPresentationStore: presentationStore
    )

    XCTAssertFalse(viewModel.isRightPanelVisible)
}

func test_togglingInspectorPersistsLatestPreference() async {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    let presentationStore = WindowPresentationStore(defaults: defaults)
    let viewModel = DashboardViewModel(
        services: AppServices(),
        fileSystemService: MockFileSystemService(),
        fileScanPipeline: FileScanPipeline(),
        contentSearchService: ContentSearchService.shared,
        windowPresentationStore: presentationStore
    )

    viewModel.isRightPanelVisible = false
    XCTAssertEqual(presentationStore.savedInspectorVisibility, false)
}
```

- [ ] **Step 2: Run the new view-model tests to verify they fail**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"
```

Expected: FAIL because `DashboardViewModel` does not yet accept the store or persist the flag.

- [ ] **Step 3: Implement inspector persistence and contextual defaults**

Update `Forma File Organizing/ViewModels/DashboardViewModel.swift`:
- inject `WindowPresentationStore`
- seed `isRightPanelVisible` from the store during init
- persist every user-driven inspector visibility change back into the store

Implementation shape:

```swift
private let windowPresentationStore: WindowPresentationStore

init(
    services: AppServices,
    fileSystemService: FileSystemServiceProtocol,
    fileScanPipeline: FileScanPipelineProtocol,
    contentSearchService: ContentSearchServing = ContentSearchService.shared,
    windowPresentationStore: WindowPresentationStore = WindowPresentationStore()
) {
    self.windowPresentationStore = windowPresentationStore
    self.isRightPanelVisible = windowPresentationStore.savedInspectorVisibility ?? true
    ...
}
```

Add a narrow helper instead of sprinkling writes:

```swift
func setRightPanelVisible(_ isVisible: Bool) {
    isRightPanelVisible = isVisible
    windowPresentationStore.setInspectorVisible(isVisible)
}
```

Update `Forma File Organizing/Views/Components/UnifiedToolbar.swift` so the inspector toggle uses `viewModel.setRightPanelVisible(...)` instead of mutating the published property directly.

Update `Forma File Organizing/Views/DashboardView.swift` and `Forma File Organizing/Views/RightPanelView.swift` only as needed so:
- the center surface remains complete when the right panel is hidden
- the three-column layout appears only when the persisted/adaptive state says it should

Update `Forma File Organizing/Coordinators/PanelStateManager.swift` only if needed to expose a simple “default panel has meaningful content” decision for the launch policy. Do not move general panel state into the app scene.

- [ ] **Step 4: Re-run the dashboard view-model tests**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 5: Build the app**

Run:

```bash
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit the contextual inspector behavior**

```bash
git add "Forma File Organizing/ViewModels/DashboardViewModel.swift" "Forma File Organizing/Coordinators/PanelStateManager.swift" "Forma File Organizing/Views/DashboardView.swift" "Forma File Organizing/Views/RightPanelView.swift" "Forma File Organizing/Views/Components/UnifiedToolbar.swift" "Forma File OrganizingTests/DashboardViewModelTests.swift"
git commit -m "feat: persist contextual inspector visibility"
```

### Task 4: Add launch-width coverage and document the new behavior

**Files:**
- Modify: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`
- Modify: `Forma File OrganizingUITests/FileSurfaceToolbarValidationTests.swift`
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Write the failing UI assertions for adaptive launch posture**

Add UI coverage to `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift` for:
- medium launch width defaults to `twoColumn`
- large launch width can default to `threeColumn` when the inspector is meaningful or persisted visible
- toggling the inspector persists across relaunches

Harness shape:

```swift
func test_mediumWindowLaunchDefaultsToTwoColumnLayout() {
    let app = XCUIApplication()
    app.launchArguments += ["--uitesting"]
    app.launchEnvironment["FORMA_WINDOW_SIZE"] = "1340x900"
    app.launch()

    let splitProbe = app.otherElements["dashboardSplitLayoutProbe"]
    XCTAssertTrue(splitProbe.waitForExistence(timeout: 4))
    XCTAssertEqual(splitProbe.label, "twoColumn")
}
```

- [ ] **Step 2: Run the targeted UI tests to verify they fail**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests"
```

Expected: FAIL because launch posture persistence and adaptive defaults are not fully wired yet.

- [ ] **Step 3: Update UI probes and screenshot coverage if needed**

Adjust `Forma File OrganizingUITests/FileSurfaceToolbarValidationTests.swift` only if the new default launch size changes the stable screenshot baseline or requires explicit window sizes per scenario. Keep the toolbar assertions intact.

- [ ] **Step 4: Re-run the targeted UI tests**

Run the command from Step 2.

Expected: PASS, or if the macOS UI runner remains flaky locally, capture the exact stall point and keep the assertions/test code in place.

- [ ] **Step 5: Update docs**

Update:
- `TODO.md` with any follow-up polish items for window restoration edge cases
- `CHANGELOG.md` with the new default window behavior and inspector persistence
- `API_REFERENCE.md` if the app’s launch behavior or configurable environment variables (`FORMA_WINDOW_SIZE`) need documentation for QA/UI testing

- [ ] **Step 6: Run the no-UI suite plus a final build**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build
```

Expected:
- unit/integration tests PASS
- final build shows `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit docs and verification updates**

```bash
git add "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift" "Forma File OrganizingUITests/FileSurfaceToolbarValidationTests.swift" "TODO.md" "CHANGELOG.md" "API_REFERENCE.md"
git commit -m "test: cover adaptive window launch behavior"
```

### Notes for the Implementer

- Use native macOS window restoration (`setFrameAutosaveName`) for frame persistence instead of inventing a custom frame serializer unless native restoration proves insufficient.
- Keep adaptive launch logic out of `RightPanelView` rendering code; it belongs in policy plus the view model’s launch state.
- Preserve analytics behavior: analytics still owns the right panel and may force a two-column layout as it does today.
- Do not regress the existing toolbar/top-line alignment work while changing default inspector visibility.
- If screenshot/UI tests remain flaky, land the test code with clear comments and rely on unit-test coverage plus manual QA until the runner issue is resolved.
