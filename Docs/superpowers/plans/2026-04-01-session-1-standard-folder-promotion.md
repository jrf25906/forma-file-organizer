# Session 1 Standard Folder Promotion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote eligible external folder-review sessions into existing standard monitored folders without introducing arbitrary custom-folder persistence.

**Architecture:** Reuse the current external-ingress session state and bookmark-backed folder model. Only offer promotion when the scanned external root resolves cleanly to one standard `BookmarkFolder.FolderType`, then persist through `BookmarkFolderService` so Sidebar, Settings, and automation consume the same source of truth.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest, macOS security-scoped bookmarks

---

### Task 1: Add Promotion Eligibility and Persistence Tests

**Files:**
- Modify: `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- Modify: `Forma File OrganizingTests/DashboardViewModelTests.swift`
- Create: `Forma File OrganizingTests/BookmarkFolderServiceTests.swift`

- [ ] **Step 1: Write a failing coordinator test for standard-folder-based external review promotion eligibility**
- [ ] **Step 2: Run the focused coordinator test to verify it fails**
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests"`
- [ ] **Step 3: Write a failing dashboard test for offering promotion only after an eligible folder-based external review session**
- [ ] **Step 4: Run the focused dashboard test to verify it fails**
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"`
- [ ] **Step 5: Write failing bookmark-folder persistence tests for enabling or preserving a standard monitored folder through the shared service**
- [ ] **Step 6: Run the focused bookmark-folder tests to verify they fail**
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/BookmarkFolderServiceTests"`

### Task 2: Implement Standard Folder Promotion

**Files:**
- Modify: `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Services/BookmarkFolderService.swift`
- Modify: `Forma File Organizing/Models/BookmarkFolder.swift`

- [ ] **Step 1: Extend external review session state with the minimum metadata needed to determine whether promotion is eligible**
- [ ] **Step 2: Add a narrow standard-folder resolver that only maps cleanly supported monitored roots**
- [ ] **Step 3: Add a shared BookmarkFolderService API for promoting or enabling an existing standard monitored folder**
- [ ] **Step 4: Re-run the focused tests until the new behavior passes**
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/BookmarkFolderServiceTests"`

### Task 3: Add the Post-Review Affordance

**Files:**
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Modify: `Forma File Organizing/Views/Settings/CustomFoldersSection.swift`
- Modify: `Forma File Organizing/Views/SidebarView.swift`

- [ ] **Step 1: Add a user-visible post-review promotion affordance tied to the eligible external session state**
- [ ] **Step 2: Keep the affordance hidden for arbitrary folders, stale bookmarks, and already-monitored folders**
- [ ] **Step 3: Verify the affordance drives the shared bookmark-folder state used by Sidebar and Settings**
- [ ] **Step 4: Re-run the focused tests and add any small UI-state tests needed for regressions**
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/BookmarkFolderServiceTests"`

### Task 4: Verify and Sync Docs

**Files:**
- Modify: `TODO.md`
- Modify: `Docs/Getting-Started/TODO.md`
- Modify: `Docs/Getting-Started/CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Run the full non-UI verification command**
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`
- [ ] **Step 2: Update synced docs only for the shipped Session 1 behavior**
- [ ] **Step 3: Check git status and summarize the delivered slice**
