# Forma - Setup & Installation Guide

**Last Updated:** December 2025
**Status:** Full-featured file organization app with dashboard, templates, personality-based organization, and intelligent automation

---

## 📋 Overview

Forma is a premium macOS file organization app that intelligently organizes files using personality-based templates, smart rules, and AI-powered context detection. This guide covers installation, permissions, onboarding, and troubleshooting.

### What's Implemented

✅ **Dashboard & Interface**
- Three-panel layout (Sidebar, Main Content, Right Panel)
- Multiple view modes (Card, List, Grid)
- Keyboard navigation and shortcuts
- Activity feed with real-time updates
- File preview with Quick Look integration
- Contextual right panel (Inspector, Analytics, Activity)

✅ **Organization Templates**
- 7 pre-built templates (Minimalist, Creative Professional, Student, Business, Digital Nomad, Academic, Family)
- Personality-based template recommendations
- Custom folder structures for each template
- Template preview during onboarding

✅ **Personality System**
- Interactive 3-question onboarding quiz
- 3 personality dimensions (OrganizationStyle, ThinkingStyle, MentalModel)
- Adaptive organization suggestions
- Personalized view modes and folder depth
- 4 personality presets (Default, Creative, Academic, Business)

✅ **Smart Rules**
- Visual rule builder interface
- Multiple condition types (extension, name pattern, size, date, content)
- Boolean operators (AND/OR)
- Template-based rule suggestions
- Rule library management
- Inline rule creation from file context

✅ **Project Clustering**
- AI-powered project detection
- Related file grouping
- Confidence scoring
- Project timeline tracking
- Cluster visualization

✅ **File Operations**
- Secure file moves with validation
- Batch operations
- Undo/Redo support (Command pattern)
- Auto-create destination directories
- Comprehensive error handling
- Activity tracking

✅ **Insights & Analytics**
- Storage breakdown by category
- Organization pattern analysis
- Productivity insights
- File type distribution
- Timeline views
- Visual charts and graphs

✅ **Multi-Folder Support**
- Custom folder management
- Security-scoped bookmarks
- Multiple source folder scanning
- Destination folder validation
- Persistent folder permissions

✅ **Context Detection**
- AI-powered content analysis
- File relationship detection
- Smart tagging
- Contextual suggestions

✅ **Onboarding Flow**
- 5-step guided setup (Welcome → Folders → Quiz → Template → Preview)
- Permission requests with clear explanations
- Personality quiz integration
- Template selection with previews
- Celebration screen on completion

---

## 🚀 Installation

### Prerequisites

- macOS (tested on latest versions)
- Xcode (for development)

### Steps

1. **Clone/Open the project**
   ```bash
   git clone <repo-url>
   cd <repo-root>
   open "Forma File Organizing.xcodeproj"
   ```

2. **Verify entitlements are linked**
   - In Xcode, select the project (blue icon)
   - Select "Forma File Organizing" target
   - Go to "Build Settings" tab
   - Search for "Code Signing Entitlements"
   - Verify value is: `Forma File Organizing/Forma_File_Organizing.entitlements`

3. **Build and run**
   - Press ⌘R in Xcode
   - Or use terminal:
     ```bash
     xcodebuild -project "Forma File Organizing.xcodeproj" \
                -scheme "Forma File Organizing" \
                -configuration Debug
     ```

---

## 🔐 Permission System

Forma uses **Security-Scoped Bookmarks** for folder access - a secure, user-friendly approach that works perfectly from Xcode.

### Why Security-Scoped Bookmarks?

| Feature | Full Disk Access | Security-Scoped Bookmarks |
|---------|-----------------|---------------------------|
| Works from Xcode | ❌ No | ✅ Yes |
| User Experience | ❌ Complex | ✅ Simple folder picker |
| Security | ⚠️ Entire disk | ✅ Only selected folders |
| Setup | ❌ System Settings | ✅ In-app picker |
| Revocation | ❌ Manual | ✅ Easy reset |

### How It Works

**Source Folders (Desktop/Downloads):**
1. App requests access via folder picker
2. You select the folder once
3. App saves a security-scoped bookmark
4. Future access is automatic

**Destination Folders (Pictures, Documents, etc):**
1. App requests access when first moving files there
2. Folder name validation ensures correct selection
3. Bookmark saved for future moves
4. No prompts on subsequent moves

---

## 🎯 First Launch

### 4-Step Onboarding Flow

Forma provides a guided onboarding experience that adapts to your organizational style:

#### Step 1: Welcome
- Introduction to Forma's capabilities
- Overview of personality-based organization
- "Get Started" button to begin

#### Step 2: Folder Setup
- **Grant Desktop Access**
  - Folder picker appears: "Grant Forma access to your Desktop folder"
  - Select ~/Desktop folder
  - Click **"Grant Access"**
  - Permission saved permanently via security-scoped bookmark
- **Optional: Add More Folders**
  - Add Downloads, Documents, or custom folders
  - Each folder requires separate permission grant
  - "Continue" button appears after Desktop is granted

#### Step 3: Personality Quiz
- **Interactive 3-question quiz** to determine your organization style:
  - Q1: "How do you typically find files?" → Determines OrganizationStyle + ThinkingStyle
  - Q2: "What does your desktop look like?" → Refines OrganizationStyle
  - Q3: "How do you think about your work?" → Determines MentalModel
- **Answer Cards** with visual icons and descriptions
- **Progress Indicator** shows quiz completion
- **Results View** displays your personality profile:
  - Personality title (e.g., "Visual Organizer", "Systematic Organizer")
  - Recommended template based on personality
  - Personality dimension breakdown

#### Step 4: Template Selection
- **Pre-selected template** based on quiz results
- **7 available templates:**
  - Minimalist (for Pilers)
  - Creative Professional (for Project-based Filers)
  - Student (for Time-based Learners)
  - Business Professional (for Structured Organizers)
  - Digital Nomad (for Flexible Workers)
  - Academic Researcher (for Topic-based Thinkers)
  - Family Organizer (for Household Management)
- **Template Preview Cards** show folder structure
- "Get Started" completes onboarding

#### Step 5: Celebration
- Success screen with confetti animation
- "Start Organizing" button launches main dashboard

### Post-Onboarding: Dashboard Launch

After onboarding, you land on the main dashboard:

1. **Sidebar (Left Panel)**
   - Navigation: Overview, All Files, Rules, Projects, Settings
   - Filter tabs: All, Documents, Images, Videos, Archives
   - Quick stats overview

2. **Main Content (Center Panel)**
   - File review list with your selected view mode (Card/List/Grid)
   - Files matched against template rules
   - Action buttons for each file (Move, Skip, View)
   - Floating action bar for bulk operations

3. **Right Panel (Context-Aware)**
   - **Inspector:** File metadata when file selected
   - **Analytics:** Storage charts and insights
   - **Activity:** Real-time activity feed with undo buttons

### Moving Your First File

1. **Find a file with a matching rule**
   - Rules are pre-loaded from your selected template
   - Files with matches show ✓ indicator and suggested destination

2. **Click the Move button** (✓ or checkmark)

3. **Grant Destination Access** (first time only)
   - Folder picker: "Please select your [FolderName] folder"
   - **Important:** Select the EXACT folder requested
   - App validates your selection
   - If wrong folder: Error message + retry option
   - If correct: Bookmark saved, file moves

4. **Success!**
   - File moved to destination
   - Activity feed shows the move
   - Undo button available in activity feed
   - File removed from review list

### Folder Validation

The app now validates folder selections:

✅ **Correct:**
- Prompted for "Documents" → Select ~/Documents → Accepted
- Prompted for "Pictures" → Select ~/Pictures → Accepted

❌ **Incorrect:**
- Prompted for "Documents" → Select ~/Downloads → **Rejected**
- Error: "Wrong folder selected. You selected 'Downloads' but Forma needs access to 'Documents'"

---

## 📁 Rules System

Forma uses template-based rules that are customized based on your selected organization template and personality.

### Template-Based Rules

Each template comes with pre-configured rules tailored to its organizational strategy:

**Example: Creative Professional Template**
- Screenshots → `~/Pictures/Screenshots`
- Project files (.psd, .ai, .sketch) → `~/Work/Projects/{ProjectName}`
- Design assets (.png, .jpg) → `~/Work/Assets/Images`
- PDFs → `~/Documents/Resources`
- Archives → `~/Downloads/Archives`

**Example: Student Template**
- Lecture notes (.pdf) → `~/Documents/Classes/{Semester}`
- Assignments (.docx, .pages) → `~/Documents/Assignments/{Course}`
- Research papers → `~/Documents/Research`
- Study materials → `~/Documents/Study Materials`

**Example: Minimalist Template**
- All documents → `~/Documents`
- All images → `~/Pictures`
- All archives → `~/Downloads/Archives`

### Custom Rules

You can create custom rules via the **Rules Management** interface:

1. Navigate to **Rules** in the sidebar
2. Click **"Create New Rule"** button
3. Configure conditions:
   - **File Extension:** .pdf, .docx, .jpg, etc.
   - **Name Pattern:** Contains/starts with/ends with text
   - **File Size:** Greater than/less than threshold
   - **Date Modified:** Within date range
   - **Content Type:** Document, image, video, audio, archive
4. Combine conditions with AND/OR operators
5. Set destination folder
6. Save and activate

### Inline Rule Creation

Create rules directly from file context:
- Right-click any file in the review list
- Select "Create Rule for Similar Files"
- Rule builder pre-fills with file's properties
- Adjust and save

### Rule Priority

Rules are evaluated in order of specificity:
1. **User-created rules** (highest priority)
2. **Template rules** (medium priority)
3. **Default fallback rules** (lowest priority)

---

## 🧪 Testing

### Complete Onboarding Test

1. **Create test files:**
   ```bash
   touch ~/Desktop/Screenshot\ 2025-12-01.png
   touch ~/Desktop/project-proposal.pdf
   touch ~/Desktop/design-assets.zip
   touch ~/Desktop/meeting-notes.docx
   ```

2. **Launch the app** (⌘R in Xcode)

3. **Complete onboarding flow:**
   - Welcome screen → Click "Get Started"
   - Folder setup → Grant Desktop access
   - Personality quiz → Answer all 3 questions
   - Template selection → Review suggested template or choose different one
   - Celebration screen → Click "Start Organizing"

4. **Verify dashboard loads:**
   - Sidebar shows navigation items
   - Main content shows test files
   - Right panel shows analytics
   - Filter tabs work (All, Documents, Images, etc.)

### File Operations Test

1. **Single file move:**
   - Select a file with a matching rule (shows ✓ indicator)
   - Click Move button
   - Grant destination folder access (first time)
   - Verify file moved to correct location
   - Check activity feed shows the move
   - Click Undo in activity feed
   - Verify file returns to original location

2. **Batch operations:**
   - Select multiple files (Cmd+Click)
   - Floating action bar appears
   - Click "Move All" button
   - Verify all files moved
   - Check activity feed shows batch operation
   - Test batch undo

3. **Skip operations:**
   - Click Skip button (X) on a file
   - Verify file removed from review list
   - Check activity feed shows skip action
   - Test undo skip

### View Modes Test

1. **Switch between views:**
   - Card view (default): Large cards with previews
   - List view: Compact rows with metadata
   - Grid view: Dense grid layout

2. **Test keyboard navigation:**
   - Arrow keys to navigate files
   - Space to preview
   - Enter to move selected file
   - Cmd+A to select all

### Rules Management Test

1. **Navigate to Rules view** (sidebar)

2. **Create a new rule:**
   - Click "Create New Rule"
   - Set condition: Extension is .txt
   - Set destination: ~/Documents/Text Files
   - Save rule

3. **Create test file:**
   ```bash
   touch ~/Desktop/test-note.txt
   ```

4. **Verify rule matches:**
   - Refresh file list
   - test-note.txt shows matching rule
   - Move file to verify rule works

### Project Clustering Test

1. **Create related files:**
   ```bash
   touch ~/Desktop/project-proposal.pdf
   touch ~/Desktop/project-budget.xlsx
   touch ~/Desktop/project-timeline.png
   ```

2. **Navigate to Projects view** (sidebar)

3. **Verify project detection:**
   - Related files grouped into cluster
   - Confidence score shown
   - Project timeline visible

### Analytics Test

1. **Click Analytics tab** in right panel

2. **Verify displays:**
   - Storage breakdown chart
   - File type distribution
   - Organization patterns
   - Recent activity timeline

### Settings Test

1. **Navigate to Settings** (sidebar)

2. **Test preferences:**
   - Change default view mode
   - Adjust folder depth preference
   - Test permission reset
   - Verify changes persist after restart

### Advanced Testing

- **Multiple folders:** Add Downloads folder, verify scanning both Desktop and Downloads
- **Undo/Redo:** Perform operations and use activity feed undo buttons
- **Quick Look:** Press Space on file to preview
- **Search:** Test file search functionality
- **Filters:** Test category filters (Documents, Images, Videos)
- **Keyboard shortcuts:** Test all keyboard commands

---

## 🐛 Troubleshooting

### "Permission denied" Errors

**Cause:** Wrong folders were selected previously, or bookmarks are corrupted.

**Solution:**
1. Look for the error banner in the app
2. Click **"Reset All Permissions"** button
3. Restart the app
4. Grant permissions again **carefully**:
   - Desktop → Select ~/Desktop
   - Documents → Select ~/Documents (NOT Downloads!)
   - Downloads → Select ~/Downloads
   - Pictures → Select ~/Pictures

**Verification:**
- Check console for: `✅ Folder validation passed: [FolderName] matches [FolderName]`
- If you see: `⚠️ User selected wrong folder:` → Try again with correct folder

### Files Not Appearing

**Cause:** Desktop access not granted or Desktop is empty.

**Solutions:**
- Click the refresh button (↻)
- Verify Desktop has files
- Check console for scanning errors
- Try granting Desktop access again via "Try Again" button

### "Wrong Folder Selected" Error

**Cause:** You selected a different folder than requested.

**Example:**
- App requested "Documents"
- You selected "Downloads" instead

**Solution:**
- Read the folder picker message carefully
- Select the EXACT folder name shown
- Click "Try Again" if you made a mistake

### Permission Prompts Keep Appearing

**Cause:** Bookmarks not being saved or security-scoped access failing.

**Solutions:**
1. Check entitlements include:
   - `com.apple.security.files.user-selected.read-write`
   - `com.apple.security.files.bookmarks.app-scope`
2. Verify running from Xcode (not a built .app in random location)
3. Check console for bookmark save errors
4. Reset all permissions and try again

### Resetting Permissions Manually

If the UI reset button doesn't work:

```bash
# Clear all saved bookmarks
defaults delete com.yourteam.Forma-File-Organizing
```

Then restart the app.

---

## 📊 Console Logging

Forma provides detailed console output for debugging:

### Permission Flow

```
📂 Requesting access to: Documents
✅ Access granted to: /Users/username/Documents
✅ Folder validation passed: Documents matches Documents
✅ Bookmark saved for Documents
```

### Move Operations

```
📁 Moving file: test.pdf
📂 From: /Users/username/Desktop
📂 To: /Users/username/Documents/PDF Archive
✅ File moved successfully
```

### Errors

```
❌ Permission denied for: /Users/username/Documents/PDF Archive
⚠️ User selected wrong folder: Downloads instead of Documents
❌ Move failed: File not found
```

---

## 🔧 Advanced Topics

### How Bookmarks Are Stored

Bookmarks are saved in UserDefaults:
- **Desktop:** `desktopBookmark`
- **Destinations:** `destinationBookmarks` (dictionary keyed by folder name)

### Security-Scoped Resource Access

```swift
// Start accessing the resource
let accessing = url.startAccessingSecurityScopedResource()

// Do file operations
try FileManager.default.moveItem(at: source, to: destination)

// Stop accessing
if accessing {
    url.stopAccessingSecurityScopedResource()
}
```

### Creating Destination Folders

Forma auto-creates destination directories:

```swift
let destinationDir = destinationURL.deletingLastPathComponent()
try FileManager.default.createDirectory(
    at: destinationDir,
    withIntermediateDirectories: true
)
```

### Bookmark Validation

Each destination folder selection is validated:

```swift
let selectedFolder = selectedURL.lastPathComponent
let requestedFolder = folderName
if selectedFolder.lowercased() != requestedFolder.lowercased() {
    // Reject and show error
}
```

---

## 🎨 Brand Alignment

The permission system maintains Forma's brand attributes:

- **Precise:** Exact folder permissions, validated selections
- **Refined:** Smooth folder picker UI, no complex setup
- **Confident:** Direct approach, clear error messages

---

## 🚦 Current Limitations

While Forma has a comprehensive feature set, there are some known limitations:

### Feature Limitations

- **Context Detection:** AI-powered content analysis is implemented but may require external AI service integration for full functionality
- **Learning Service:** Pattern learning framework exists but requires usage data accumulation to provide meaningful suggestions
- **Automation/Scheduling:** No background automation or scheduled organization runs (manual trigger only)
- **Cloud Sync:** No iCloud or cross-device synchronization
- **Export/Import:** No rule export/import functionality for sharing configurations

### Technical Limitations

- **macOS 14.0+ Only:** Requires modern macOS for SwiftData and modern SwiftUI features
- **Single User:** No multi-user support or user switching
- **File Types:** Optimized for common file types (documents, images, videos); exotic formats may not categorize correctly
- **Large Files:** Very large files (>1GB) may take longer to process
- **Network Drives:** Not optimized for network-attached storage or cloud drives

### Known Issues

- **Project Clustering:** Confidence scores may need tuning based on real-world usage patterns
- **Template Customization:** Templates cannot be edited after selection (workaround: create custom rules)
- **Personality Re-assessment:** No UI to retake personality quiz (workaround: reset app data)
- **Rule Conflicts:** Multiple matching rules may cause ambiguity (first match wins)

### Performance Considerations

- **Large Folders:** Scanning folders with 1000+ files may take several seconds
- **Real-time Scanning:** No automatic folder monitoring (manual refresh required)
- **Memory Usage:** Large file lists kept in memory may impact performance on older Macs

---

## 🔜 What's Next

### Near-term Enhancements (Next Release)

1. **Automation & Scheduling**
   - Background file monitoring
   - Scheduled organization runs
   - Auto-organize on file creation
   - Configurable automation rules

2. **Advanced Context Detection**
   - Local LLM integration for content analysis
   - Enhanced project relationship detection
   - Smart file tagging
   - Content-based organization

3. **Template Customization**
   - Edit existing templates
   - Create custom templates from scratch
   - Template marketplace/sharing
   - Template versioning

4. **Enhanced Analytics**
   - Productivity insights
   - Organization trends over time
   - Storage optimization recommendations
   - File lifecycle tracking

5. **Rule Management Improvements**
   - Rule conflict detection
   - Rule testing/simulation
   - Rule performance analytics
   - Import/export rule sets

### Medium-term Features

- **Cloud Integration**
  - iCloud Drive support
  - Cross-device sync
  - Backup and restore

- **Advanced File Operations**
  - File renaming rules
  - Duplicate detection
  - Bulk file editing
  - Smart cleanup suggestions

- **Collaboration Features**
  - Shared templates
  - Team organization strategies
  - Rule recommendations from community

### Long-term Vision

- **AI-Powered Automation**
  - Full content understanding
  - Predictive organization
  - Natural language rule creation
  - Adaptive learning from user corrections

- **Platform Expansion**
  - iOS companion app
  - Watch notifications
  - Browser extension for downloads

- **Enterprise Features**
  - Multi-user management
  - Compliance policies
  - Advanced security controls
  - Audit logging

---

## 📞 Getting Help

### Quick Diagnostics

1. **Check console output** for detailed logs
2. **Verify entitlements** are properly configured
3. **Reset permissions** if issues persist
4. **Test with fresh files** to isolate problems

### Common Issues

- Permission errors → Reset permissions
- Files not appearing → Check Desktop access
- Wrong destinations → Verify folder selections
- Repeated prompts → Check bookmark saves

### Debug Checklist

- [ ] Entitlements properly linked?
- [ ] Running from Xcode (not standalone build)?
- [ ] Console shows permission grants?
- [ ] Correct folders selected when prompted?
- [ ] Bookmarks being saved (check UserDefaults)?
- [ ] Security-scoped access started/stopped?

---

## 📚 Documentation & Resources

### User Documentation
- **[README.md](../../README.md)** - Quick start and project overview
- **[SETUP.md](SETUP.md)** - This document: Installation and setup
- **[USER-GUIDE.md](USER-GUIDE.md)** - End-user guide and everyday workflows
- **[USER_RULES_GUIDE.md](../API-Reference/USER_RULES_GUIDE.md)** - Guide for creating and managing rules

### Feature Documentation
- **[PersonalitySystem.md](../Features/PersonalitySystem.md)** - Personality-based organization system
- **[OrganizationTemplates.md](../Features/OrganizationTemplates.md)** - Template system and customization
- **[ComponentArchitecture.md](../Architecture/ComponentArchitecture.md)** - UI component architecture
- **[DesignSystem.md](../Design/DesignSystem.md)** - Design tokens and patterns

### Developer Documentation
- **[ARCHITECTURE.md](../Architecture/ARCHITECTURE.md)** - System architecture and data flow
- **[DEVELOPER-ONBOARDING.md](../Development/DEVELOPER-ONBOARDING.md)** - Onboarding for new contributors
- **[DEVELOPMENT.md](../Development/DEVELOPMENT.md)** - Development workflow and patterns
- **[TESTING.md](../Development/TESTING.md)** - Testing guide and best practices
- **[API_REFERENCE.md](../API-Reference/API_REFERENCE.md)** - Complete API reference

### Key Source Files
- **Services Layer:**
  - `Services/FileSystemService.swift` - File scanning and metadata
  - `Services/RuleEngine.swift` - Rule matching and evaluation
  - `Services/FileOperationsService.swift` - File moves and permissions
  - `Services/ContextDetectionService.swift` - AI-powered content analysis
  - `Services/InsightsService.swift` - Analytics and insights
  - `Services/LearningService.swift` - Pattern learning
  - `Services/CustomFolderManager.swift` - Multi-folder management

- **ViewModels:**
  - `ViewModels/DashboardViewModel.swift` - Main dashboard state
  - `ViewModels/ReviewViewModel.swift` - File review state
  - `ViewModels/NavigationViewModel.swift` - Navigation state

- **Views:**
  - `Views/DashboardView.swift` - Main three-panel interface
  - `Views/Onboarding/OnboardingFlowView.swift` - 5-step onboarding
  - `Views/PersonalityQuizView.swift` - Personality assessment
  - `Views/RulesManagementView.swift` - Rule creation and editing
  - `Views/Settings/SettingsView.swift` - App preferences

- **Models:**
  - `Models/FileItem.swift` - File representation
  - `Models/Rule.swift` - Organization rules
  - `Models/OrganizationTemplate.swift` - Template system
  - `Models/OrganizationPersonality.swift` - Personality model
  - `Models/ProjectCluster.swift` - Project detection
  - `Models/ActivityItem.swift` - Activity tracking

---

**Last Updated:** 2026-01-06 | **Version:** 2.0
