# Forma - Development Guide

**Version:** 2.0
**Last Updated:** 2026-01-06
**Status:** Full-Featured Application

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Environment](#development-environment)
3. [Building from Source](#building-from-source)
4. [Project Structure](#project-structure)
5. [Running Tests](#running-tests)
6. [Debugging](#debugging)
7. [Architecture Patterns](#architecture-patterns)
8. [Component Development](#component-development)
9. [Design System Usage](#design-system-usage)
10. [Common Development Tasks](#common-development-tasks)
11. [Working with Models](#working-with-models)
12. [Extending Features](#extending-features)
13. [Common Issues](#common-issues)
14. [Contributing Guidelines](#contributing-guidelines)
15. [Release Process](#release-process)

---

## Getting Started

### Prerequisites

**Required:**
- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Apple Developer account (for code signing)

**Recommended:**
- Familiarity with Swift and SwiftUI
- Understanding of macOS file system permissions
- Git for version control

### Quick Start

```bash
# 1. Clone the repository
git clone <repo-url>
cd <repo-root>

# 2. Open in Xcode
open "Forma File Organizing.xcodeproj"

# 3. Build and run
# Press ⌘R in Xcode
# Or build from the command line:
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build
```

---

## Development Environment

### Xcode Configuration

**Project Settings:**
```
Project: Forma File Organizing
Target: Forma File Organizing
Bundle ID: com.yourteam.Forma-File-Organizing
Deployment Target: macOS 14.0
Swift Version: 5.9
```

**Build Configuration:**
```
Debug:   Development builds with logging
Release: Optimized builds for distribution
```

### Entitlements Setup

The project requires specific entitlements for file access:

**Location:** `Forma File Organizing/Forma_File_Organizing.entitlements`

**Required Entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
</dict>
</plist>
```

**Verification:**
1. Select project in Navigator
2. Select "Forma File Organizing" target
3. Go to "Build Settings" tab
4. Search for "Code Signing Entitlements"
5. Verify value: `Forma File Organizing/Forma_File_Organizing.entitlements`

### Code Signing

**Development:**
```
Signing: Automatically manage signing
Team: [Your Team]
Signing Certificate: Apple Development
```

**Distribution:**
```
Signing: Manually manage signing
Team: [Your Team]
Signing Certificate: Developer ID Application
```

---

## Building from Source

### Debug Build

**Via Xcode:**
1. Open project in Xcode
2. Select scheme: "Forma File Organizing"
3. Select destination: "My Mac"
4. Press ⌘R (or Product → Run)

**Via Command Line:**
```bash
xcodebuild \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -configuration Debug \
  -derivedDataPath ./build
```

### Release Build

**Via Xcode:**
1. Product → Archive
2. Organizer window opens
3. Select archive
4. Click "Distribute App"
5. Choose distribution method

**Via Command Line:**
```bash
xcodebuild \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -configuration Release \
  -derivedDataPath ./build \
  archive \
  -archivePath ./build/Forma.xcarchive
```

### Build Outputs

**Debug:**
```
Location: ~/Library/Developer/Xcode/DerivedData/Forma.../Build/Products/Debug/
File: Forma File Organizing.app
```

**Release:**
```
Location: ./build/Forma.xcarchive
Contents: Forma File Organizing.app + dSYMs
```

### Clean Build

**Via Xcode:**
- Shift+⌘K (Product → Clean Build Folder)

**Via Command Line:**
```bash
xcodebuild clean \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing"

# Deep clean
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Onboarding Debugging

During onboarding development it's often useful to force the onboarding flow and clear all
saved folder permissions on every run.

**Launch argument (DEBUG only):**

```text
--force-onboarding
```

**Behavior:**
- Calls `FileSystemService.resetAllAccess()` at `DashboardViewModel` initialization.
- Clears Desktop, Downloads, Documents, Pictures, and Music bookmarks from Keychain/UserDefaults.
- Causes `DashboardViewModel.checkPermissions()` to set `showOnboarding = true`, so
  the `OnboardingFlowView` sheet is shown on startup.

**How to use in Xcode:**
1. Edit the *Forma File Organizing* **Run** scheme.
2. Under **Arguments Passed On Launch**, add `--force-onboarding`.
3. Run the app; onboarding appears every launch until you remove the flag.

### Onboarding-to-Sidebar Integration

The onboarding flow automatically populates the sidebar's **LOCATIONS** section. This "two birds, one stone" design means users only grant folder permissions once—during onboarding—and those same folders immediately appear in the sidebar for navigation.

**Data Flow:**

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 1. ONBOARDING: User grants folder access via NSOpenPanel                     │
│    └── OnboardingFlowView → FileSystemService.requestAccess()                │
│                                                                              │
│ 2. STORAGE: Security-scoped bookmark saved to Keychain                       │
│    └── SecureBookmarkStore.saveBookmark(data, forKey: "DesktopBookmark")     │
│                                                                              │
│ 3. MIGRATION: Bookmarks converted to CustomFolder SwiftData entries          │
│    └── DashboardViewModel.migrateBookmarksToCustomFolders()                  │
│        - Loads bookmarks from SecureBookmarkStore                            │
│        - Creates CustomFolder for each                                       │
│        - Persists to SwiftData                                               │
│                                                                              │
│ 4. LOADING: CustomFolders loaded into ViewModel for sidebar display          │
│    └── DashboardViewModel.loadCustomFolders(from: context)                   │
│        - Called automatically inside scanFiles()                             │
│        - Populates @Published customFolders array                            │
│                                                                              │
│ 5. DISPLAY: SidebarView observes customFolders and renders locations         │
│    └── ForEach(dashboardViewModel.customFolders) { folder in ... }           │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Key Implementation Details:**

- **Migration happens on startup**: `migrateBookmarksToCustomFolders()` runs inside `scanFiles()`, ensuring existing users who granted permissions before this feature get their folders migrated automatically.

- **`loadCustomFolders()` must be called**: The critical call `loadCustomFolders(from: context)` in `scanFiles()` populates the ViewModel's `customFolders` array. Without this call, the sidebar would remain empty even with valid SwiftData entries.

- **Sandbox home directory workaround**: macOS sandboxed apps see `FileManager.default.homeDirectoryForCurrentUser` as the sandbox container path (e.g., `~/Library/Containers/app.bundle.id/Data`). Both `CustomFolderManager.swift` and `DashboardViewModel.swift` use a `realHomeDirectory()` function with POSIX `getpwuid(getuid())` to get the actual user home path:

  ```swift
  private func realHomeDirectory() -> URL {
      if let pw = getpwuid(getuid()) {
          let homeDir = String(cString: pw.pointee.pw_dir)
          return URL(fileURLWithPath: homeDir)
      }
      return FileManager.default.homeDirectoryForCurrentUser
  }
  ```

**Files Involved:**

| File | Role |
|------|------|
| `Views/Onboarding/OnboardingFlowView.swift` | Collects folder permissions from user |
| `SecureBookmarkStore.swift` | Stores bookmarks in Keychain |
| `DashboardViewModel.swift` | Migration logic + `loadCustomFolders()` |
| `CustomFolderManager.swift` | Bookmark resolution with `realHomeDirectory()` |
| `CustomFolder.swift` | SwiftData model for folder entries |
| `SidebarView.swift` | Displays `customFolders` under LOCATIONS |

**Debugging Tips:**

- If sidebar locations are empty after onboarding:
  1. Check that `loadCustomFolders(from: context)` is being called (add print statement in `scanFiles()`)
  2. Verify CustomFolder entries exist in SwiftData (inspect with `context.fetch(FetchDescriptor<CustomFolder>())`)
  3. Check bookmark resolution isn't failing due to home directory path mismatch

- Use `--force-onboarding` to reset and test the full flow from scratch

---

## Project Structure

```
Forma File Organizing/
├── Forma File Organizing/           # Main app target
│   ├── Forma_File_OrganizingApp.swift   # App entry point (@main)
│   │
│   ├── Models/                      # SwiftData models + protocols (19 files)
│   │   ├── FileItem.swift           # File representation with metadata
│   │   ├── Rule.swift               # Organization rules
│   │   ├── OrganizationTemplate.swift    # Template system
│   │   ├── OrganizationPersonality.swift # Personality model
│   │   ├── ProjectCluster.swift     # Project detection
│   │   ├── LearnedPattern.swift     # ML-based patterns
│   │   ├── ActivityItem.swift       # Activity tracking
│   │   ├── CustomFolder.swift       # Multi-folder support
│   │   └── ...                      # Error handling, protocols, types
│   │
│   ├── ViewModels/                  # State management (@MainActor classes)
│   │   ├── DashboardViewModel.swift # Main dashboard state
│   │   ├── ReviewViewModel.swift    # File review state
│   │   └── NavigationViewModel.swift # App navigation
│   │
│   ├── Views/                       # UI screens
│   │   ├── DashboardView.swift      # Three-panel main interface
│   │   ├── SidebarView.swift        # Left navigation panel
│   │   ├── MainContentView.swift    # Center content area
│   │   ├── RightPanelView.swift     # Context-aware right panel
│   │   ├── Onboarding/              # 5-step onboarding flow (coordinator + steps)
│   │   ├── PersonalityQuizView.swift # Organization style quiz
│   │   ├── TemplateSelectionView.swift # Template chooser
│   │   ├── RulesManagementView.swift # Rule configuration
│   │   ├── RuleEditorView.swift     # Rule creation/editing
│   │   ├── ProjectClusterView.swift # Project visualization
│   │   ├── Settings/                # App preferences and sections
│   │   ├── FileInspectorView.swift  # File details
│   │   ├── ReviewView.swift         # File review (legacy)
│   │   └── ...                      # Additional screens
│   │
│   ├── Components/                  # Reusable UI
│   │   ├── FloatingActionBar.swift  # Bulk operation bar
│   │   ├── FilterTabBar.swift       # File filtering tabs
│   │   ├── FileGridItem.swift       # Grid view cards
│   │   ├── FileListRow.swift        # List view rows
│   │   ├── ActivityFeed.swift       # Activity timeline
│   │   ├── StorageChart.swift       # Storage visualization
│   │   ├── CategoryTag.swift        # File category badges
│   │   ├── ProgressRing.swift       # Circular progress
│   │   └── ...                      # See ComponentArchitecture.md
│   │
│   ├── Services/                    # Business logic layer
│   │   ├── FileSystemService.swift  # File scanning & access
│   │   ├── RuleEngine.swift         # Rule evaluation
│   │   ├── FileOperationsService.swift # File moves & operations
│   │   ├── ContextDetectionService.swift # AI context analysis
│   │   ├── LearningService.swift    # Pattern learning
│   │   ├── InsightsService.swift    # Analytics generation
│   │   ├── CustomFolderManager.swift # Multi-folder management
│   │   ├── SecureBookmarkStore.swift # Permission management
│   │   ├── UndoCommand.swift        # Undo/redo system
│   │   ├── ProjectDetectionService.swift # Project clustering
│   │   ├── NotificationService.swift # User notifications
│   │   └── ...                      # Additional services
│   │
│   ├── DesignSystem/                # Visual design system
│   │   ├── FormaColors.swift        # Color palette & tokens
│   │   ├── FormaTypography.swift    # Type scale & styles
│   │   ├── FormaSpacing.swift       # Spacing system
│   │   ├── FormaComponents.swift    # Reusable UI patterns
│   │   ├── FormaMicroanimations.swift # Delightful interactions
│   │   ├── LiquidGlassComponents.swift # Glass morphism
│   │   └── FormaAnimation.swift     # Animation utilities
│   │
│   ├── Coordinators/                # Navigation coordination
│   │   └── NavigationCoordinator.swift
│   │
│   ├── Configuration/               # App configuration
│   │   └── AppConfiguration.swift
│   │
│   ├── Utilities/                   # Helper functions
│   │   ├── FileExtensions.swift
│   │   ├── DateExtensions.swift
│   │   └── StringExtensions.swift
│   │
│   ├── Resources/                   # Static resources
│   ├── KeyboardCommands.swift       # Keyboard shortcuts
│   ├── OpenSettingsEnvironment.swift # Settings integration
│   ├── Forma_File_Organizing.entitlements # Permissions
│   └── Assets.xcassets              # Images, icons, brand assets
│       ├── AppIcon.appiconset       # App icons
│       ├── logo-mark.imageset       # Brand mark
│       └── ...
│
├── Forma File OrganizingTests/     # Unit tests
│   ├── RuleEngineTests.swift
│   ├── FileSystemServiceTests.swift
│   ├── DashboardViewModelTests.swift
│   ├── OrganizationPersonalityTests.swift
│   └── ...
│
├── Forma File OrganizingUITests/   # UI tests
│   ├── FileRowUITests.swift
│   ├── MicroInteractionsUITests.swift
│   └── ...
│
└── Docs/                            # Documentation
    ├── Getting-Started/
    │   └── SETUP.md
    ├── Architecture/
    │   ├── ARCHITECTURE.md
    │   ├── RuleEngine-Architecture.md
    │   └── ComponentArchitecture.md
    ├── Features/
    │   ├── PersonalitySystem.md
    │   └── OrganizationTemplates.md
    ├── Design/
    │   ├── DesignSystem.md
    │   ├── Forma-Design-Doc.md
    │   └── Forma-Brand-Guidelines.md
    ├── Development/
    │   ├── DEVELOPMENT.md (this file)
    │   └── TESTING.md
    └── API-Reference/
        ├── API_REFERENCE.md
        └── USER_RULES_GUIDE.md
```

### Key Files by Layer

**App Entry:**
- `Forma_File_OrganizingApp.swift` - SwiftUI app lifecycle, SwiftData container setup

**Presentation Layer (Views):**
- `DashboardView.swift` - Main three-panel interface
- `SidebarView.swift` - Navigation sidebar
- `MainContentView.swift` - File review center panel
- `RightPanelView.swift` - Contextual right panel
- `Views/Onboarding/OnboardingFlowView.swift` - First-time setup flow
- `PersonalityQuizView.swift` - Personality assessment

**ViewModel Layer:**
- `DashboardViewModel.swift` - Main app state, file operations
- `ReviewViewModel.swift` - File review state (legacy, being phased out)
- `NavigationViewModel.swift` - App navigation state

**Service Layer:**
- `FileSystemService.swift` - File scanning, metadata, permissions
- `RuleEngine.swift` - Rule matching and evaluation
- `FileOperationsService.swift` - Secure file moves
- `ContextDetectionService.swift` - AI-powered context analysis
- `InsightsService.swift` - Analytics and insights generation
- `LearningService.swift` - Pattern learning and adaptation
- `CustomFolderManager.swift` - Multi-folder management
- `SecureBookmarkStore.swift` - Security-scoped bookmarks

**Model Layer:**
- `FileItem.swift` - File representation with metadata
- `Rule.swift` - Organization rules with conditions
- `OrganizationTemplate.swift` - Template definitions
- `OrganizationPersonality.swift` - Personality dimensions
- `ProjectCluster.swift` - Project detection results
- `ActivityItem.swift` - Activity tracking

**Design System:**
- `FormaColors.swift` - Color tokens (Obsidian, Bone White, Steel Blue, etc.)
- `FormaTypography.swift` - Type scale (.formaH1, .formaH2, etc.)
- `FormaSpacing.swift` - Spacing tokens (.micro, .tight, .standard, etc.)
- `FormaComponents.swift` - Reusable component patterns
- `FormaMicroanimations.swift` - Spring animations and transitions

---

## Running Tests

### Unit Tests

**Via Xcode:**
1. Press ⌘U (Product → Test)
2. Or click test diamond in gutter next to test function

**Via Command Line:**
```bash
xcodebuild test \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -destination "platform=macOS"
```

**Specific Test:**
```bash
xcodebuild test \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -only-testing:Forma_File_OrganizingTests/RuleEngineTests
```

### UI Tests

**Via Xcode:**
1. Select scheme: "Forma File Organizing"
2. Choose destination: "My Mac"
3. Press ⌘U

**Via Command Line:**
```bash
xcodebuild test \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -destination "platform=macOS" \
  -only-testing:Forma_File_OrganizingUITests
```

### Test Coverage

**Enable Coverage:**
1. Edit Scheme (Product → Scheme → Edit Scheme)
2. Test action
3. Options tab
4. Check "Code Coverage"

**View Coverage:**
1. Run tests with coverage
2. Report Navigator (⌘9)
3. Coverage tab
4. Expand to see file-by-file coverage

---

## Debugging

### Xcode Console

**View Console:**
- ⌘⇧Y (View → Debug Area → Show Debug Area)

**Console Output Levels:**
```swift
print("ℹ️ Info message")     // General info
print("✅ Success")           // Operation succeeded
print("⚠️ Warning")           // Potential issue
print("❌ Error")             // Operation failed
```

### Breakpoints

**Set Breakpoint:**
- Click line number gutter
- Or ⌘\ on current line

**Conditional Breakpoint:**
1. Right-click breakpoint
2. Edit Breakpoint
3. Add condition: `file.name == "invoice.pdf"`

**Symbolic Breakpoint:**
1. Breakpoint Navigator (⌘8)
2. Click + → Swift Error Breakpoint
3. Catches all thrown errors

### LLDB Commands

**Print Variable:**
```lldb
po file
po file.suggestedDestination
```

**Expression:**
```lldb
expr file.status = .completed
```

**Backtrace:**
```lldb
bt
```

### Logging Best Practices

**FileSystemService:**
```swift
print("📂 Requesting access to: \(folderName)")
print("✅ Access granted to: \(url.path)")
print("❌ Permission denied for: \(url.path)")
```

**FileOperationsService:**
```swift
print("📁 Moving file: \(fileItem.name)")
print("📂 From: \(sourceURL.path)")
print("📂 To: \(destinationURL.path)")
print("✅ File moved successfully")
```

**RuleEngine:**
```swift
print("🔍 Evaluating \(files.count) files against \(rules.count) rules")
print("✓ Rule matched: \(rule.name) for \(file.name)")
```

---

## Architecture Patterns

### MVVM with Service Layer

Forma uses a clean MVVM architecture with a service layer for business logic:

```
View → ViewModel → Service → Model
  ↑        ↓          ↓        ↓
  └─────────────────────────────┘
       (ObservableObject)
```

**Example Flow:**
```swift
// 1. View triggers action
Button("Organize") {
    viewModel.organizeFile(file)
}

// 2. ViewModel coordinates
@MainActor
class DashboardViewModel: ObservableObject {
    func organizeFile(_ file: FileItem) {
        Task {
            try await fileOperations.moveFile(file, to: destination)
            await fetchFiles()  // Refresh
        }
    }
}

// 3. Service performs operation
class FileOperationsService {
    func moveFile(_ file: FileItem, to: URL) async throws {
        try secureMoveOnDisk(from: file.path, to: destination)
        updateModel(file, newPath: destination)
    }
}

// 4. Model updates
@Model class FileItem {
    var path: String
    var status: OrganizationStatus
}
```

### State Management Patterns

**1. @MainActor for ViewModels:**
```swift
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var selectedFile: FileItem?
    @Published var isLoading = false

    // All methods automatically run on main thread
    func fetchFiles() async {
        isLoading = true
        defer { isLoading = false }
        // Async work...
    }
}
```

**2. Environment for Cross-View State:**
```swift
// Define environment value
private struct SelectedFileKey: EnvironmentKey {
    static let defaultValue: FileItem? = nil
}

extension EnvironmentValues {
    var selectedFile: FileItem? {
        get { self[SelectedFileKey.self] }
        set { self[SelectedFileKey.self] = newValue }
    }
}

// Use in views
struct ParentView: View {
    @State private var selectedFile: FileItem?

    var body: some View {
        ChildView()
            .environment(\.selectedFile, selectedFile)
    }
}
```

**3. SwiftData Querying:**
```swift
// In view
@Query(
    filter: #Predicate<FileItem> { $0.status == .pending },
    sort: \FileItem.modifiedDate,
    order: .reverse
) var pendingFiles: [FileItem]

// In ViewModel/Service
func fetchRules() throws -> [Rule] {
    let descriptor = FetchDescriptor<Rule>(
        predicate: #Predicate { $0.isEnabled },
        sortBy: [SortDescriptor(\.priority)]
    )
    return try context.fetch(descriptor)
}
```

### Command Pattern for Undo/Redo

Forma uses the Command pattern for undoable operations:

```swift
// 1. Define command
struct MoveFileCommand: UndoableCommand {
    let fileID: String
    let fromPath: String
    let toPath: String

    func execute(context: ModelContext?) async throws {
        // Perform move
    }

    func undo(context: ModelContext?) throws {
        // Reverse move
    }
}

// 2. Execute and store
let command = MoveFileCommand(...)
try await command.execute(context: context)
activityItems.append(ActivityItem(command: command))

// 3. Undo from UI
Button("Undo") {
    try command.undo(context: context)
}
```

---

## Component Development

### Creating a New Component

**1. Component Structure:**
```swift
// Components/MyNewComponent.swift
import SwiftUI

/// Brief description of component purpose
struct MyNewComponent: View {
    // MARK: - Properties
    let title: String
    var action: () -> Void

    // MARK: - State
    @State private var isHovered = false

    // MARK: - Body
    var body: some View {
        Button(action: action) {
            Text(title)
                .formaBody()  // Use design system
                .padding(.standard)  // Use spacing tokens
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FormaColors.steelBlue)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .formaMicroAnimation()  // Add spring animation
    }
}

// MARK: - Preview
#Preview {
    MyNewComponent(title: "Click Me") {
        print("Clicked")
    }
}
```

**2. Component Categories:**

**Display Components (Non-Interactive):**
```swift
// CategoryTag.swift - Shows file category
struct CategoryTag: View {
    let category: FileCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
            Text(category.rawValue)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.color.opacity(0.1))
        .foregroundColor(category.color)
        .cornerRadius(6)
    }
}
```

**Interactive Components:**
```swift
// ActionButton.swift - Reusable action button
struct ActionButton: View {
    let icon: String
    let label: String
    var style: ButtonStyle = .primary
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
            }
            .padding()
            .background(backgroundFor(style))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
```

**Layout Components:**
```swift
// ThreePanelLayout.swift - Dashboard layout
struct ThreePanelLayout<Sidebar: View, Content: View, Detail: View>: View {
    let sidebar: Sidebar
    let content: Content
    let detail: Detail

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                sidebar
                    .frame(width: geometry.size.width * 0.2)
                Divider()
                content
                    .frame(maxWidth: .infinity)
                Divider()
                detail
                    .frame(width: geometry.size.width * 0.25)
            }
        }
    }
}
```

### Component Best Practices

**1. Use Design Tokens:**
```swift
// ❌ Bad - Hardcoded values
Text("Hello")
    .font(.system(size: 16))
    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
    .padding(12)

// ✅ Good - Design system tokens
Text("Hello")
    .formaBody()  // Typography token
    .foregroundColor(FormaColors.obsidian)  // Color token
    .padding(.standard)  // Spacing token
```

**2. Composable Components:**
```swift
// Build complex components from simple ones
struct FileRow: View {
    let file: FileItem

    var body: some View {
        HStack {
            FileIcon(fileType: file.fileType)  // ✅ Reusable
            VStack(alignment: .leading) {
                Text(file.name)
                    .formaBody()
                CategoryTag(category: file.category)  // ✅ Reusable
            }
            Spacer()
            ActionButtons(file: file)  // ✅ Reusable
        }
    }
}
```

**3. Preview Multiple States:**
```swift
#Preview("Default") {
    FileRow(file: .mock)
}

#Preview("Selected") {
    FileRow(file: .mock)
        .environment(\.selectedFile, .mock)
}

#Preview("Loading") {
    FileRow(file: .mockLoading)
}

#Preview("Error") {
    FileRow(file: .mockError)
}
```

**4. Accessibility:**
```swift
Button(action: moveFile) {
    Image(systemName: "checkmark.circle.fill")
}
.accessibilityLabel("Move file to suggested destination")
.accessibilityHint("Double-tap to organize this file")
```

---

## Design System Usage

### Color System

**Primary Palette:**
```swift
import SwiftUI

// Use semantic color names from FormaColors
Text("Title")
    .foregroundColor(FormaColors.obsidian)  // Primary text

Rectangle()
    .fill(FormaColors.boneWhite)  // Background

Button("Action") { }
    .foregroundColor(FormaColors.steelBlue)  // Interactive

Text("Success")
    .foregroundColor(FormaColors.sage)  // Success state

Text("Warning")
    .foregroundColor(FormaColors.clay)  // Warning state
```

**Category Colors:**
```swift
// Defined in FileCategory enum
enum FileCategory: String {
    case document, image, video, audio, archive

    var color: Color {
        switch self {
        case .document: return FormaColors.steelBlue
        case .image: return FormaColors.sage
        case .video: return FormaColors.terracotta
        case .audio: return FormaColors.amber
        case .archive: return FormaColors.clay
        }
    }
}

// Usage
Circle()
    .fill(file.category.color)
```

### Typography Scale

**Text Styles:**
```swift
// Headings
Text("Dashboard")
    .formaH1()  // 32pt, semibold

Text("Recent Files")
    .formaH2()  // 24pt, semibold

Text("Section")
    .formaH3()  // 18pt, medium

// Body text
Text("Description")
    .formaBody()  // 14pt, regular

Text("Metadata")
    .formaSmall()  // 12pt, regular

Text("Label")
    .formaCaption()  // 11pt, medium
```

### Spacing System

**Spacing Tokens:**
```swift
// Use .padding() with spacing tokens
VStack(spacing: .tight) {  // 8pt
    Text("Title")
    Text("Subtitle")
}
.padding(.standard)  // 12pt

HStack(spacing: .micro) {  // 4pt
    Image(systemName: "doc")
    Text("Document")
}
.padding(.generous)  // 24pt

Section {
    // Content
}
.padding(.xl)  // 32pt
```

**Layout Extensions:**
```swift
extension CGFloat {
    static let micro: CGFloat = 4
    static let tight: CGFloat = 8
    static let standard: CGFloat = 12
    static let cozy: CGFloat = 16
    static let generous: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

### Animations

**Micro-animations:**
```swift
// Apply to any view for spring animation
Button("Click") { }
    .formaMicroAnimation()  // Spring response: 0.3, damping: 0.7

// Custom animations
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
    isExpanded.toggle()
}

// Gesture animations
DragGesture()
    .onChanged { value in
        withAnimation(.interactiveSpring()) {
            offset = value.translation
        }
    }
```

**State Transitions:**
```swift
// Smooth state changes
@State private var isShowing = false

var body: some View {
    VStack {
        if isShowing {
            DetailView()
                .transition(.scale.combined(with: .opacity))
        }
    }
    .animation(.spring(), value: isShowing)
}
```

### Glass Morphism Effects

**Liquid Glass Component:**
```swift
// Apply frosted glass effect
VStack {
    Text("Content")
}
.liquidGlassBackground()  // Frosted glass with border

// Custom glass effects
Rectangle()
    .fill(.ultraThinMaterial)
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
    )
```

---

## Common Development Tasks

### Adding a New Rule Condition Type

**1. Update Rule Model:**
```swift
// Models/Rule.swift
enum ConditionType: String, Codable, CaseIterable {
    case fileExtension
    case nameContains
    case nameStartsWith
    case nameEndsWith
    case fileSize      // New!
}
```

**2. Update RuleCondition enum:**
```swift
// Models/RuleCondition.swift
enum RuleCondition: Codable, Equatable {
    // ... existing cases
    case fileSizeLargerThan(bytes: Int64)

    // Add matching logic in matchesFile() method
    func matchesFile(_ file: some Fileable) -> Bool {
        switch self {
        case .fileSizeLargerThan(let bytes):
            return file.sizeInBytes > bytes
        // ... existing cases
        }
    }
}
```

**3. Update UI (when rule builder launches):**
```swift
// Views/Settings/RulesManagerSection.swift (future)
Picker("Condition Type", selection: $conditionType) {
    ForEach(Rule.ConditionType.allCases, id: \.self) { type in
        Text(type.rawValue)
    }
}
```

---

### Adding a New Built-in Rule

**1. Create Rule Function:**
```swift
// Services/RuleService.swift
static func createDefaultRules(context: ModelContext) {
    // ... existing rules

    // New rule using conditions array
    let videoRule = Rule(
        name: "Video Files",
        conditions: [.fileExtension("mp4")],
        logicalOperator: .single,
        actionType: .move,
        destination: .folder(bookmark: bookmarkData, displayName: "Movies/Videos")
    )
    context.insert(videoRule)
}
```

**2. Call on First Launch:**
```swift
// Forma_File_OrganizingApp.swift
.onAppear {
    if isFirstLaunch {
        RuleService.createDefaultRules(context: modelContext)
    }
}
```

---

### Modifying File Scan Logic

**Example: Add file size filtering**

```swift
// Services/FileSystemService.swift
private func scanDirectory(at url: URL) async throws -> [FileItem] {
    // ... existing code

    for fileURL in contents {
        // Skip large files
        let fileSize = attributes[.size] as? Int64 ?? 0
        if fileSize > 100_000_000 { // 100MB
            print("⏭️ Skipping large file: \(fileURL.lastPathComponent)")
            continue
        }

        // ... create FileItem
    }
}
```

---

### Adding New Destination Validation

**Example: Prevent system folder selection**

```swift
// Services/FileOperationsService.swift
private func requestDestinationAccess(_ folderName: String) async throws -> URL {
    // ... existing code

    if response == .OK, let selectedURL = openPanel.url {
        // New validation
        let forbiddenPaths = ["/System", "/Library", "/Applications"]
        if forbiddenPaths.contains(selectedURL.path) {
            let alert = NSAlert()
            alert.messageText = "System Folder Not Allowed"
            alert.informativeText = "Please select a user folder like Documents or Pictures"
            alert.runModal()
            throw FileOperationError.operationFailed("System folder selected")
        }

        // ... existing validation
    }
}
```

---

### Implementing Custom UI Component

**Example: File type badge**

```swift
// Components/FileViews.swift
struct FileTypeBadge: View {
    let fileExtension: String

    var body: some View {
        Text(fileExtension.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DesignSystem.Colors.steelBlue.opacity(0.1))
            .foregroundColor(DesignSystem.Colors.steelBlue)
            .cornerRadius(4)
    }
}

// Usage:
HStack {
    Image(systemName: "doc.fill")
    Text(file.name)
    FileTypeBadge(fileExtension: file.fileExtension)
}
```

---

## Working with Models

### SwiftData Model Basics

**Model Definition:**
```swift
import SwiftData

@Model
class FileItem {
    // MARK: - Stored Properties
    @Attribute(.unique) var id: UUID
    var path: String
    var name: String
    var fileExtension: String
    var sizeInBytes: Int64
    var modifiedDate: Date
    var status: OrganizationStatus

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify) var suggestedRule: Rule?
    @Relationship(deleteRule: .nullify) var cluster: ProjectCluster?

    // MARK: - Initialization
    init(path: String, name: String, ...) {
        self.id = UUID()
        self.path = path
        self.name = name
        // ...
    }
}
```

**Enums in Models:**
```swift
// Codable enum for SwiftData
enum OrganizationStatus: String, Codable {
    case pending
    case completed
    case skipped
    case failed
}

@Model
class FileItem {
    var status: OrganizationStatus = .pending  // ✅ Works
}
```

### Creating and Persisting Models

**Insert New Model:**
```swift
// In view with @Environment(\.modelContext)
@Environment(\.modelContext) private var context

Button("Add Rule") {
    let newRule = Rule(
        name: "Screenshots",
        conditions: [.nameStartsWith("Screenshot")],
        logicalOperator: .single,
        destination: .folder(bookmark: bookmarkData, displayName: "Pictures/Screenshots")
    )
    context.insert(newRule)
    try? context.save()
}
```

**Update Existing Model:**
```swift
// SwiftData automatically tracks changes
func updateFileStatus(file: FileItem, status: OrganizationStatus) {
    file.status = status  // Change tracked
    try? context.save()   // Persist
}
```

**Delete Model:**
```swift
func deleteRule(_ rule: Rule) {
    context.delete(rule)
    try? context.save()
}
```

### Querying Models

**Simple Query:**
```swift
// In view
@Query var files: [FileItem]  // All files

@Query(sort: \FileItem.modifiedDate, order: .reverse)
var recentFiles: [FileItem]
```

**Filtered Query:**
```swift
@Query(filter: #Predicate<FileItem> { file in
    file.status == .pending
}) var pendingFiles: [FileItem]
```

**Complex Query:**
```swift
@Query(filter: #Predicate<FileItem> { file in
    file.status == .pending &&
    file.fileExtension == "pdf" &&
    file.sizeInBytes < 10_000_000
}, sort: \FileItem.modifiedDate, order: .reverse)
var smallPendingPDFs: [FileItem]
```

**Dynamic Query in Service:**
```swift
func fetchFiles(matching status: OrganizationStatus) throws -> [FileItem] {
    var descriptor = FetchDescriptor<FileItem>(
        predicate: #Predicate { $0.status == status },
        sortBy: [SortDescriptor(\.modifiedDate, order: .reverse)]
    )
    descriptor.fetchLimit = 100
    return try context.fetch(descriptor)
}
```

### Model Relationships

**One-to-Many:**
```swift
@Model
class ProjectCluster {
    var name: String
    @Relationship(deleteRule: .cascade) var files: [FileItem] = []
}

@Model
class FileItem {
    @Relationship(deleteRule: .nullify) var cluster: ProjectCluster?
}

// Usage
let cluster = ProjectCluster(name: "Q4 Report")
file.cluster = cluster  // Establishes relationship
cluster.files.append(file)  // Bidirectional
```

**Many-to-Many:**
```swift
@Model
class Rule {
    @Relationship(deleteRule: .nullify) var matchedFiles: [FileItem] = []
}

@Model
class FileItem {
    @Relationship(deleteRule: .nullify) var matchingRules: [Rule] = []
}
```

### Model Best Practices

**1. Use Computed Properties for Derived Data:**
```swift
@Model
class FileItem {
    var sizeInBytes: Int64

    // Don't store this - compute it
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    var category: FileCategory {
        FileCategory.fromExtension(fileExtension)
    }
}
```

**2. Validation in Init:**
```swift
@Model
class Rule {
    var conditions: [RuleCondition]

    init(name: String, conditions: [RuleCondition], ...) {
        guard !conditions.isEmpty else {
            fatalError("Rule must have at least one condition")
        }
        self.conditions = conditions
    }
}
```

**3. Use @Transient for Non-Persisted State:**
```swift
@Model
class FileItem {
    var path: String

    @Transient var isLoading: Bool = false  // Not saved to database
    @Transient var thumbnail: NSImage?      // Don't persist images
}
```

**4. Batch Operations:**
```swift
// Efficient batch insert
func importFiles(_ urls: [URL]) throws {
    context.autosaveEnabled = false  // Disable auto-save
    defer { context.autosaveEnabled = true }

    for url in urls {
        let file = FileItem(from: url)
        context.insert(file)
    }

    try context.save()  // Single save at end
}
```

---

## Extending Features

### Adding a New Organization Template

**1. Define Template in Model:**
```swift
// Models/OrganizationTemplate.swift
extension OrganizationTemplate {
    static let musicProducer = OrganizationTemplate(
        name: "Music Producer",
        icon: "music.note",
        description: "Organize audio projects, samples, and stems",
        folderStructure: [
            "Music/Projects/Active",
            "Music/Projects/Archive",
            "Music/Samples/Drums",
            "Music/Samples/Synths",
            "Music/Stems/Vocal",
            "Music/Stems/Instrumental",
            "Music/Final Mixes"
        ],
        preferredViewMode: "grid",
        suggestedDepth: 3
    )
}
```

**2. Add Template Rules:**
```swift
// Services/TemplateRuleGenerator.swift
func rulesFor(_ template: OrganizationTemplate) -> [Rule] {
    switch template.name {
    case "Music Producer":
        return [
            Rule(
                name: "Audio Projects",
                conditions: [.fileExtension("als")],  // Ableton Live
                logicalOperator: .single,
                destination: .folder(bookmark: bookmarkData, displayName: "Music/Projects/Active")
            ),
            Rule(
                name: "Audio Samples",
                conditions: [.fileExtension("wav")],
                logicalOperator: .single,
                destination: .folder(bookmark: bookmarkData, displayName: "Music/Samples")
            ),
            // ... more rules
        ]
    // ... other templates
    }
}
```

**3. Add to Template List:**
```swift
// Views/TemplateSelectionView.swift
let templates: [OrganizationTemplate] = [
    .minimal,
    .creativeProf,
    .student,
    .business,
    .digitalNomad,
    .academic,
    .family,
    .musicProducer  // ✅ New template
]
```

### Adding a Personality Preset

**1. Define Preset:**
```swift
// Models/OrganizationPersonality.swift
extension OrganizationPersonality {
    static let musicProducer = OrganizationPersonality(
        organizationStyle: .filer,
        thinkingStyle: .projectBased,
        mentalModel: .projectBased,
        preferredViewMode: "grid",
        suggestedFolderDepth: 3
    )

    static var allPresets: [OrganizationPersonality] {
        [.default, .creative, .academic, .business, .musicProducer]
    }
}
```

**2. Map to Template:**
```swift
extension OrganizationPersonality {
    var suggestedTemplate: OrganizationTemplate {
        switch (organizationStyle, mentalModel) {
        case (.filer, .projectBased) where thinkingStyle == .visual:
            return .musicProducer
        // ... existing mappings
        }
    }
}
```

### Adding a New Service

**1. Create Service File:**
```swift
// Services/MyNewService.swift
import Foundation
import SwiftData

/// Service for [specific functionality]
class MyNewService {
    // MARK: - Properties
    private let context: ModelContext?

    // MARK: - Initialization
    init(context: ModelContext? = nil) {
        self.context = context
    }

    // MARK: - Public Methods
    func performTask() async throws -> Result {
        // Implementation
    }
}
```

**2. Inject into ViewModel:**
```swift
// ViewModels/DashboardViewModel.swift
@MainActor
class DashboardViewModel: ObservableObject {
    private let myNewService: MyNewService

    init(context: ModelContext) {
        self.myNewService = MyNewService(context: context)
    }

    func useNewFeature() async {
        try? await myNewService.performTask()
    }
}
```

### Adding Activity Feed Integration

**1. Create ActivityItem:**
```swift
// When performing operation
let activityItem = ActivityItem(
    type: .fileMove,
    timestamp: Date(),
    description: "Moved \(file.name) to \(destination)",
    undoCommand: command  // Optional undo support
)
context.insert(activityItem)
```

**2. Display in Activity Feed:**
```swift
// Components/ActivityFeed.swift already handles this
@Query(sort: \ActivityItem.timestamp, order: .reverse)
var activities: [ActivityItem]

ForEach(activities) { activity in
    ActivityRow(activity: activity)
}
```

### Adding Keyboard Shortcuts

**1. Define Command:**
```swift
// KeyboardCommands.swift
extension KeyboardCommands {
    static let organizeSelected = KeyboardCommand(
        title: "Organize Selected File",
        key: "o",
        modifiers: [.command]
    )
}
```

**2. Implement Handler:**
```swift
// Views/DashboardView.swift
.commands {
    CommandGroup(replacing: .newItem) {
        Button("Organize Selected") {
            viewModel.organizeSelectedFile()
        }
        .keyboardShortcut("o", modifiers: .command)
    }
}
```

### Adding Analytics/Insights

**1. Define Insight Type:**
```swift
// Models/InsightType.swift
enum InsightType {
    case storageBreakdown
    case organizationTrend
    case productivityMetric
    case fileTypeDistribution
    case newInsightType  // ✅ Add new type
}
```

**2. Implement Calculation:**
```swift
// Services/InsightsService.swift
extension InsightsService {
    func calculateNewInsight() -> InsightData {
        // Query files, calculate metrics
        let data = // ... calculation
        return InsightData(
            type: .newInsightType,
            value: data,
            visualization: .chart
        )
    }
}
```

**3. Add Visualization:**
```swift
// Components/InsightCard.swift
switch insight.type {
case .newInsightType:
    NewInsightChart(data: insight.value)
default:
    // Existing visualizations
}
```

---

## Common Issues

### Issue: "Permission Denied" Errors

**Symptoms:**
- Files won't move
- "Permission denied" error message
- Repeated permission prompts

**Causes:**
- Wrong folder selected during permission grant
- Bookmark became stale
- Entitlements not properly configured

**Solutions:**

1. **Reset Permissions:**
```swift
// In ReviewView or via UI button
Button("Reset Permissions") {
    viewModel.resetAllPermissions()
}
```

2. **Verify Entitlements:**
```bash
# Check entitlements in built app
codesign -d --entitlements - "path/to/Forma File Organizing.app"

# Should show:
# <key>com.apple.security.files.user-selected.read-write</key>
# <true/>
```

3. **Check Build Settings:**
- Xcode → Project → Build Settings
- Search: "Code Signing Entitlements"
- Verify path: `Forma File Organizing/Forma_File_Organizing.entitlements`

---

### Issue: Files Not Appearing After Scan

**Symptoms:**
- Scan completes but file list is empty
- "All clean!" message when Desktop has files

**Causes:**
- Desktop folder access not granted
- Hidden files being filtered
- Desktop folder empty
- Wrong folder selected

**Debug Steps:**

1. **Check Console Output:**
```
📂 Requesting access to: Desktop
✅ Access granted to: /Users/username/Desktop
Found X files
```

2. **Verify Desktop Location:**
```bash
ls -la ~/Desktop
# Should list files
```

3. **Check File Filter:**
```swift
// FileSystemService.swift
// Ensure .skipsHiddenFiles is appropriate
let contents = try fileManager.contentsOfDirectory(
    at: url,
    // ...
    options: [.skipsHiddenFiles]  // ← Check this
)
```

---

### Issue: Rules Not Matching Files

**Symptoms:**
- Files show as "No rule" even though rule exists
- Expected rule doesn't trigger

**Debug:**

1. **Print Rule Evaluation:**
```swift
// RuleEngine.swift
private func evaluateConditions(file: some Fileable, rule: some Ruleable) -> Bool {
    print("🔍 Checking \(file.name) against rule \(rule.id)")
    print("   Conditions: \(rule.conditions)")
    print("   Operator: \(rule.logicalOperator)")
    print("   File ext: \(file.fileExtension)")
    // ... evaluation logic
}
```

2. **Check Rule Status:**
```swift
// Verify rule is enabled
let descriptor = FetchDescriptor<Rule>(
    predicate: #Predicate { $0.isEnabled }
)
let rules = try? context.fetch(descriptor)
print("Active rules: \(rules?.count ?? 0)")
```

3. **Verify Condition Logic:**
```swift
// Check individual condition matching
for condition in rule.conditions {
    print("Condition \(condition) matches: \(condition.matchesFile(file))")
}
```

---

### Issue: Build Fails with SwiftData Errors

**Symptoms:**
- Build errors related to @Model macro
- "Cannot find type 'ModelContext'" errors

**Solutions:**

1. **Import SwiftData:**
```swift
import SwiftData  // Add to top of file
```

2. **Clean Build:**
```bash
# Xcode
Shift+⌘K

# Terminal
rm -rf ~/Library/Developer/Xcode/DerivedData
```

3. **Check Deployment Target:**
- SwiftData requires macOS 14.0+
- Project → Build Settings → macOS Deployment Target

---

### Issue: UI Not Updating After State Change

**Symptoms:**
- File list doesn't refresh after move
- Loading spinner stuck
- Error/success messages don't appear

**Causes:**
- State update not on main thread
- @Published property not changing
- View not observing ViewModel

**Solutions:**

1. **Verify MainActor:**
```swift
@MainActor
class ReviewViewModel: ObservableObject {
    // All methods run on main thread
}
```

2. **Check @Published:**
```swift
@Published var files: [FileItem] = []

// Update triggers view refresh
self.files = newFiles
```

3. **Verify ObservedObject:**
```swift
struct ReviewView: View {
    @ObservedObject var viewModel: ReviewViewModel  // ✅
    // NOT @State, NOT bare property
}
```

---

### Issue: App Crashes on Launch

**Common Crashes:**

1. **ModelContext Not Available:**
```swift
// Fix: Check context exists before using
guard let context = modelContext else { return }
```

2. **Force Unwrap Crashes:**
```swift
// ❌ Crash if nil
let dest = file.suggestedDestination!

// ✅ Safe
guard let dest = file.suggestedDestination else { return }
```

3. **Thread Safety:**
```swift
// ❌ May crash - wrong thread
Task.detached {
    viewModel.files = []  // Crash!
}

// ✅ Safe - main thread
Task { @MainActor in
    viewModel.files = []
}
```

---

### Issue: Slow Performance

**Symptoms:**
- UI lag when scrolling file list
- Slow scan times
- Delayed UI updates

**Optimizations:**

1. **Async File Operations:**
```swift
// Don't block main thread
Task {
    let files = try await fileSystemService.scanDesktop()
}
```

2. **Lazy Loading:**
```swift
// Use LazyVStack for large lists
LazyVStack {
    ForEach(viewModel.files) { file in
        FileRow(file: file)
    }
}
```

3. **Reduce Fetch Calls:**
```swift
// Cache rules instead of fetching every scan
private var cachedRules: [Rule]?
```

---

## Contributing Guidelines

### Code Style

**Swift:**
- 4 spaces for indentation
- Meaningful variable names
- Document public APIs with `///` comments

**Example:**
```swift
/// Scans the Desktop folder and returns FileItem objects
/// - Returns: Array of FileItem representing files found
/// - Throws: FileSystemError if scan fails or permission denied
func scanDesktop() async throws -> [FileItem] {
    // Implementation
}
```

### Git Workflow

**Branch Naming:**
```
feature/custom-rule-builder
bugfix/permission-reset
hotfix/crash-on-launch
refactor/service-layer
```

**Commit Messages:**
```
feat: Add custom rule builder UI
fix: Resolve permission bookmark corruption
docs: Update API reference for RuleEngine
refactor: Extract file validation logic
test: Add unit tests for RuleEngine
```

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Added unit tests
- [ ] Manual testing completed
- [ ] UI testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings
```

---

## Release Process

### Version Numbering

Format: **MAJOR.MINOR.PATCH**

- **MAJOR**: Breaking changes, major features
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, minor improvements

**Examples:**
- 0.1.0 - MVP release
- 0.2.0 - Custom rule builder added
- 0.2.1 - Bug fixes
- 1.0.0 - First public release

### Pre-Release Checklist

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version number bumped
- [ ] Build succeeds in Release configuration
- [ ] Manual testing completed
- [ ] No console warnings/errors

### Documentation Checks

Run this before merging doc-heavy changes to catch broken links and legacy onboarding/settings paths:

```bash
python3 Scripts/check_docs.py
```

### Build for Distribution

**1. Update Version:**
```
Target → General → Identity
Version: 0.1.0
Build: 1
```

**2. Archive:**
```
Product → Archive
Wait for completion
```

**3. Organizer:**
```
Window → Organizer
Select archive
Distribute App
```

**4. Export Options:**
- **Developer ID:** For direct distribution
- **Mac App Store:** For App Store submission

---

## Development Resources

### Documentation

- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)

### Internal Docs

- `ARCHITECTURE.md` - System design and data flow
- `API_REFERENCE.md` - Service and API details
- `USER_RULES_GUIDE.md` - Rule system documentation

### Community

- Apple Developer Forums
- Swift Forums
- Stack Overflow (tag: swiftui, macos)

---

**Document Version:** 2.0
**Last Updated:** 2026-01-06
**Next Review:** After major feature additions

---

## Additional Resources

### Documentation
- [SETUP.md](../Getting-Started/SETUP.md) - Installation and first-time setup
- [ARCHITECTURE.md](../Architecture/ARCHITECTURE.md) - System architecture and design
- [ComponentArchitecture.md](../Architecture/ComponentArchitecture.md) - UI component patterns
- [DesignSystem.md](../Design/DesignSystem.md) - Design tokens and guidelines
- [PersonalitySystem.md](../Features/PersonalitySystem.md) - Personality-based organization
- [OrganizationTemplates.md](../Features/OrganizationTemplates.md) - Template system
- [API_REFERENCE.md](../API-Reference/API_REFERENCE.md) - Complete API documentation
- [TESTING.md](../Development/TESTING.md) - Testing strategies and best practices

### Key Development Files
- `DesignSystem/FormaColors.swift` - Color palette reference
- `DesignSystem/FormaTypography.swift` - Typography scale
- `DesignSystem/FormaSpacing.swift` - Spacing tokens
- `Services/RuleEngine.swift` - Rule matching logic
- `Services/FileOperationsService.swift` - File operation patterns
- `ViewModels/DashboardViewModel.swift` - State management example
- `Components/` - 33 reusable UI components
