# Forma - Onboarding Flow & Wireframes

**Document Purpose:** Complete onboarding flow with all screens and navigation paths
**Status:** Design Phase
**Date Created:** November 10, 2025
**Updated:** November 17, 2025 (Rebrand to Forma)

---

## Table of Contents

1. [Flow Overview](#flow-overview)
2. [Complete User Journeys](#complete-user-journeys)
3. [Screen-by-Screen Wireframes](#screen-by-screen-wireframes)
4. [Edge Cases & Error States](#edge-cases--error-states)
5. [Technical Implementation Notes](#technical-implementation-notes)

---

## Flow Overview

### High-Level Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ONBOARDING FLOW                             │
└─────────────────────────────────────────────────────────────────────┘

                            START
                              │
                              ▼
                    ┌──────────────────┐
                    │   1. WELCOME     │
                    │   (Value Prop)   │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  2. PERMISSIONS  │
                    │   (Request)      │
                    └──────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
              GRANTED                DENIED
                    │                   │
                    ▼                   ▼
          ┌──────────────────┐   ┌──────────────────┐
          │   3. SCANNING    │   │ 2b. PERMISSION   │
          │   (Discovery)    │   │    DENIED        │
          └──────────────────┘   └──────────────────┘
                    │                   │
                    ▼                   │
          ┌──────────────────┐         │
          │ 4. SCAN RESULTS  │◄────────┘
          │   (What We Found)│    (after fix)
          └──────────────────┘
                    │
          ┌─────────┴──────────┐
          │                    │
    SUGGEST PATH          MANUAL PATH
          │                    │
          ▼                    ▼
┌──────────────────┐   ┌──────────────────┐
│ 5a. SMART        │   │ 5b. CREATE       │
│     DEFAULTS     │   │     RULES        │
│  (Auto-suggest)  │   │   (Guided)       │
└──────────────────┘   └──────────────────┘
          │                    │
          └─────────┬──────────┘
                    │
                    ▼
          ┌──────────────────┐
          │  6. PREVIEW      │
          │  (What Will      │
          │   Happen)        │
          └──────────────────┘
                    │
          ┌─────────┴──────────┐
          │                    │
     AUTO MODE           REVIEW MODE
          │                    │
          ▼                    ▼
┌──────────────────┐   ┌──────────────────┐
│ 7a. PROCESSING   │   │ 7b. REVIEW UI    │
│  (Batch Move)    │   │ (Manual Review)  │
└──────────────────┘   └──────────────────┘
          │                    │
          └─────────┬──────────┘
                    │
                    ▼
          ┌──────────────────┐
          │   8. SUCCESS     │
          │   (Celebration)  │
          └──────────────────┘
                    │
                    ▼
                   END
            (App Ready to Use)
```

### Flow Timing

**Fast Path:** ~45 seconds to first value
- Welcome → Permission → Scan → Accept Defaults → Auto-organize → Success

**Careful Path:** 3-6 minutes with confidence
- Welcome → Permission → Scan → Review Results → Create/Edit Rules → Review Each File → Success

---

## Complete User Journeys

### Journey 1: Trust & Speed User

**Persona:** Wants it done fast, trusts smart defaults

**Flow:**
1. **Welcome** → Click "Let's Get Started"
2. **Permissions** → Grant access immediately
3. **Scanning** → Wait ~5-10 seconds
4. **Scan Results** → Click "🤖 Suggest Organization"
5. **Smart Defaults** → Quick review, click "Looks Good"
6. **Preview** → Click "⚡️ Auto-Organize All"
7. **Processing** → Watch progress bar
8. **Success** → Click "Start Using"
9. **Result:** 102 files organized in ~45 seconds

---

### Journey 2: Control & Careful User

**Persona:** Wants to understand and control everything

**Flow:**
1. **Welcome** → Click "Let's Get Started"
2. **Permissions** → Reads carefully, grants access
3. **Scanning** → Watches progress
4. **Scan Results** → Studies breakdown, clicks "✏️ I'll Create Rules"
5. **Create Rules** → Creates first rule manually, saves
6. **Preview** → Reads carefully, clicks "👀 Review Each File First"
7. **Review Interface** → Reviews each file suggestion
   - Accepts most with ⌘A
   - Changes some with ⌘D
   - Skips uncertain ones
8. **Processing** → Clicks "Process All" after review
9. **Success** → Feels confident, clicks "Start Using"
10. **Result:** 102 files organized in 3-6 minutes, feels good

---

### Journey 3: Permission Denied User

**Persona:** Accidentally denied or skeptical about permissions

**Flow:**
1. **Welcome** → Click "Let's Get Started"
2. **Permissions** → Clicks "Grant Access"
3. **System Dialog** → Clicks "Don't Allow" (oops!)
4. **Permission Denied** → Sees instructions
5. **Opens System Settings** → Enables Full Disk Access
6. **Returns** → Clicks "Try Again"
7. **Scanning** → Now works!
8. **Continues** → Normal flow from here

---

## Screen-by-Screen Wireframes

### Screen 1: Welcome

**Screen ID:** `welcome`  
**Previous:** None (entry point)  
**Next:** `permission_request`

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                         🗂️                                  │
│                                                             │
│                  Welcome to Forma                 │
│                                                             │
│              Your personal file organization assistant      │
│                                                             │
│    We'll help you tame the chaos on your Desktop and       │
│    Downloads folder - no more "I'll organize this later"   │
│                                                             │
│                                                             │
│    • Learn your filing patterns                            │
│    • Suggest smart destinations                            │
│    • Save you hours of manual sorting                      │
│                                                             │
│                                                             │
│                      [Let's Get Started]                    │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Icon:** 🗂️ (large, centered)
- **Title:** "Welcome to Forma" (24pt, bold)
- **Subtitle:** "Your personal file organization assistant" (16pt, gray)
- **Value props:** Bullet list with icons
- **CTA Button:** "Let's Get Started" (primary, blue)

**Interactions:**
- Button click → Navigate to `permission_request`

**Copy Notes:**
- Friendly but professional
- Focus on benefits, not features
- No technical jargon

---

### Screen 2: Permission Request

**Screen ID:** `permission_request`  
**Previous:** `welcome`  
**Next:** `scanning` (if granted) or `permission_denied` (if denied)

```
┌─────────────────────────────────────────────────────────────┐
│                         [← Back]                            │
│                                                             │
│                         🔐                                  │
│                                                             │
│                  One Quick Permission                       │
│                                                             │
│    To organize your files, we need access to your          │
│    Desktop and Downloads folders.                          │
│                                                             │
│    ┌─────────────────────────────────────────────────────┐ │
│    │                                                     │ │
│    │  ✓ Your files never leave your Mac                 │ │
│    │  ✓ We don't send anything to the internet          │ │
│    │  ✓ You can revoke access anytime in Settings       │ │
│    │                                                     │ │
│    └─────────────────────────────────────────────────────┘ │
│                                                             │
│    macOS will show a system prompt on the next screen.     │
│    Click "OK" to continue.                                 │
│                                                             │
│                      [Grant Access]                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Back button:** Top left (gray, subtle)
- **Icon:** 🔐 (lock, security)
- **Title:** "One Quick Permission" (20pt)
- **Explanation:** Clear, benefit-focused
- **Privacy assurances:** Checkboxed list in subtle box
- **Warning:** About system dialog
- **CTA Button:** "Grant Access" (primary)

**Interactions:**
- Back button → Return to `welcome`
- "Grant Access" button → Request system permission
  - If granted → Navigate to `scanning`
  - If denied → Navigate to `permission_denied`

**Technical Notes:**
```swift
// Request Full Disk Access
let openPanel = NSOpenPanel()
openPanel.canChooseDirectories = true
openPanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
openPanel.prompt = "Grant Access"
```

---

### Screen 2b: Permission Denied

**Screen ID:** `permission_denied`  
**Previous:** `permission_request`  
**Next:** `scanning` (after fix)

```
┌─────────────────────────────────────────────────────────────┐
│                         ⚠️                                  │
│                                                             │
│                  Permission Required                        │
│                                                             │
│    Forma needs Full Disk Access to               │
│    organize your files.                                    │
│                                                             │
│    To enable it:                                           │
│                                                             │
│    1. Open System Settings                                 │
│    2. Go to Privacy & Security → Full Disk Access          │
│    3. Toggle on "Forma"                          │
│                                                             │
│                [Open System Settings]  [Try Again]          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Icon:** ⚠️ (warning, but not scary)
- **Title:** "Permission Required" (20pt)
- **Instructions:** Numbered steps, clear
- **Buttons:** 
  - "Open System Settings" (primary, opens Settings)
  - "Try Again" (secondary, retries permission check)

**Interactions:**
- "Open System Settings" → Opens macOS System Settings to Privacy panel
- "Try Again" → Checks permission status again
  - If now granted → Navigate to `scanning`
  - If still denied → Stay on this screen

**Technical Notes:**
```swift
// Open System Settings to Privacy pane
NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)

// Check permission status
func hasFullDiskAccess() -> Bool {
    let testPath = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
    return FileManager.default.isReadableFile(atPath: testPath)
}
```

---

### Screen 3: Scanning

**Screen ID:** `scanning`  
**Previous:** `permission_request`  
**Next:** `scan_results`

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                         🔍                                  │
│                                                             │
│                  Scanning your files...                     │
│                                                             │
│    [████████████████░░░░░░] 73%                            │
│                                                             │
│    Found 156 files so far...                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Icon:** 🔍 (magnifying glass, animated if possible)
- **Title:** "Scanning your files..." (20pt)
- **Progress bar:** Visual indicator of completion
- **Status text:** "Found X files so far..." (updates live)

**Duration:** 5-10 seconds typically (varies by file count)

**Interactions:**
- Automatic transition to `scan_results` when complete
- Optional: Cancel button if scan takes >10 seconds

**Technical Notes:**
```swift
// Async file scanning
Task {
    let files = await scanFolders([
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Downloads"
    ])
    
    await MainActor.run {
        navigateToScanResults(with: files)
    }
}
```

---

### Screen 4: Scan Results

**Screen ID:** `scan_results`  
**Previous:** `scanning`  
**Next:** `smart_defaults` or `manual_rules`

```
┌─────────────────────────────────────────────────────────────┐
│                         [← Back]                            │
│                                                             │
│                         📊                                  │
│                                                             │
│                  Here's What We Found                       │
│                                                             │
│    ┌───────────────────────────────────────────────────┐   │
│    │                                                   │   │
│    │   📁 Desktop: 47 files                            │   │
│    │   📥 Downloads: 109 files                         │   │
│    │                                                   │   │
│    │   Most common types:                              │   │
│    │   📄 PDFs (43)                                    │   │
│    │   🖼️ Screenshots (28)                             │   │
│    │   📦 Archives (19)                                │   │
│    │   📝 Documents (15)                               │   │
│    │   🎨 Images (12)                                  │   │
│    │                                                   │   │
│    └───────────────────────────────────────────────────┘   │
│                                                             │
│    Good news: We can help organize all of these!           │
│                                                             │
│    How would you like to set this up?                      │
│                                                             │
│    [🤖 Suggest Organization]  [✏️ I'll Create Rules]       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Back button:** Returns to welcome (rare use)
- **Icon:** 📊 (chart/stats)
- **Title:** "Here's What We Found" (20pt)
- **Stats box:** 
  - Location breakdown
  - File type breakdown with counts
- **Reassuring message:** "Good news..."
- **Question:** "How would you like to set this up?"
- **Two paths:**
  - "🤖 Suggest Organization" (primary)
  - "✏️ I'll Create Rules" (secondary)

**Interactions:**
- Back button → Return to `welcome` (will rescan)
- "Suggest Organization" → Navigate to `smart_defaults`
- "I'll Create Rules" → Navigate to `manual_rules`

**Technical Notes:**
```swift
struct ScanResults {
    let desktopFiles: [File]
    let downloadsFiles: [File]
    let fileTypeBreakdown: [FileType: Int]
    
    var totalFiles: Int {
        desktopFiles.count + downloadsFiles.count
    }
    
    var topFileTypes: [(FileType, Int)] {
        fileTypeBreakdown
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }
    }
}
```

---

### Screen 5a: Smart Defaults (Suggest Path)

**Screen ID:** `smart_defaults`  
**Previous:** `scan_results`  
**Next:** `preview`

```
┌─────────────────────────────────────────────────────────────┐
│                         [← Back]                            │
│                                                             │
│                  Based on your files, we suggest            │
│                  organizing them like this:                 │
│                                                             │
│    ┌─────────────────────────────────────────────────────┐ │
│    │                                                     │ │
│    │  Rule 1: Screenshots                                │ │
│    │  📸 28 files → ~/Pictures/Screenshots/2024-11       │ │
│    │  [✓] Enabled                                        │ │
│    │                                                     │ │
│    │  Rule 2: PDF Documents                              │ │
│    │  📄 43 files → ~/Documents/PDFs                     │ │
│    │  [✓] Enabled                                        │ │
│    │                                                     │ │
│    │  Rule 3: ZIP Archives                               │ │
│    │  📦 19 files → ~/Downloads/Archives                 │ │
│    │  [✓] Enabled                                        │ │
│    │                                                     │ │
│    │  Rule 4: Images                                     │ │
│    │  🎨 12 files → ~/Pictures/Imported                  │ │
│    │  [✓] Enabled                                        │ │
│    │                                                     │ │
│    └─────────────────────────────────────────────────────┘ │
│                                                             │
│    These rules will organize 102 of your 156 files.        │
│    You can customize or add more rules anytime.            │
│                                                             │
│                    [Looks Good]  [Customize]                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Back button:** Return to `scan_results`
- **Explanation:** "Based on your files..."
- **Rules list:**
  - Each rule shows icon, count, destination
  - Checkbox to enable/disable
  - Max 4-5 suggested rules
- **Summary:** "These rules will organize X of Y files"
- **Note:** Can customize later
- **Buttons:**
  - "Looks Good" (primary, accept all enabled)
  - "Customize" (secondary, opens rule editor)

**Interactions:**
- Back button → Return to `scan_results`
- Checkboxes → Toggle rule on/off
- "Looks Good" → Navigate to `preview` with selected rules
- "Customize" → Opens detailed rule editor (future feature)

**Smart Default Logic:**

```
Screenshot Rule:
  IF: Filename starts with "Screenshot"
  AND: File type is PNG
  THEN: ~/Pictures/Screenshots/[Year-Month]
  CONDITION: >5 screenshot files found

PDF Rule:
  IF: File type is PDF
  THEN: ~/Documents/PDFs
  CONDITION: >10 PDF files found
  
Archive Rule:
  IF: File type is .zip, .rar, .7z, .tar.gz
  THEN: ~/Downloads/Archives
  CONDITION: >5 archive files found

Image Rule:
  IF: File type is .jpg, .jpeg, .png, .gif (but not screenshot)
  THEN: ~/Pictures/Imported
  CONDITION: >10 image files found
```

---

### Screen 5b: Manual Rules (Manual Path)

**Screen ID:** `manual_rules`  
**Previous:** `scan_results`  
**Next:** `preview`

```
┌─────────────────────────────────────────────────────────────┐
│                         [← Back]                            │
│                                                             │
│                  Let's Create Your First Rule               │
│                                                             │
│    We noticed you have 28 screenshots. Where should         │
│    these go?                                               │
│                                                             │
│    ┌─────────────────────────────────────────────────────┐ │
│    │  Rule Name:                                         │ │
│    │  [Screenshots                              ]        │ │
│    │                                                     │ │
│    │  When a file:                                       │ │
│    │  • Filename [starts with ▾] [Screenshot        ]   │ │
│    │  • File type [is ▾] [PNG ▾]                        │ │
│    │                                                     │ │
│    │  Move it to:                                        │ │
│    │  [~/Pictures/Screenshots/[Year-Month]          ]    │ │
│    │  [📂 Browse Folders]                                │ │
│    │                                                     │ │
│    │  This will match 28 files                          │ │
│    │                                                     │ │
│    └─────────────────────────────────────────────────────┘ │
│                                                             │
│                    [Save Rule]  [Skip for Now]              │
│                                                             │
│    💡 Tip: You can add more rules anytime from Settings    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Back button:** Return to `scan_results`
- **Context:** "We noticed you have 28 screenshots..."
- **Rule builder form:**
  - Rule name input
  - Conditions (dropdowns + text inputs)
  - Destination path
  - Browse button for folder picker
  - Live match count
- **Buttons:**
  - "Save Rule" (primary)
  - "Skip for Now" (secondary)
- **Tip:** Reassurance about adding rules later

**Interactions:**
- Back button → Return to `scan_results`
- Form inputs → Update match count in real-time
- "Browse Folders" → Open folder picker dialog
- "Save Rule" → Save rule, navigate to `preview`
- "Skip for Now" → Navigate to `preview` with no rules

**Pre-filled Suggestions:**
- Screenshots rule if >5 screenshots found
- PDF rule if >10 PDFs found
- User can accept, modify, or start from scratch

---

### Screen 6: Preview

**Screen ID:** `preview`  
**Previous:** `smart_defaults` or `manual_rules`  
**Next:** `processing` or `review_interface`

```
┌─────────────────────────────────────────────────────────────┐
│                         [← Back]                            │
│                                                             │
│                  Ready to Organize!                         │
│                                                             │
│    102 files are ready to be organized with your rules.    │
│                                                             │
│    ┌─────────────────────────────────────────────────────┐ │
│    │                                                     │ │
│    │  📸 Screenshots → Pictures/Screenshots (28)         │ │
│    │  📄 PDFs → Documents/PDFs (43)                      │ │
│    │  📦 Archives → Downloads/Archives (19)              │ │
│    │  🎨 Images → Pictures/Imported (12)                 │ │
│    │                                                     │ │
│    └─────────────────────────────────────────────────────┘ │
│                                                             │
│    What would you like to do?                              │
│                                                             │
│    ┌───────────────────────────────────────────────────┐   │
│    │                                                   │   │
│    │           [👀 Review Each File First]            │   │
│    │                                                   │   │
│    │          Recommended for first time               │   │
│    │                                                   │   │
│    └───────────────────────────────────────────────────┘   │
│                                                             │
│                   [⚡️ Auto-Organize All]                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Back button:** Return to previous screen
- **Title:** "Ready to Organize!" (20pt)
- **Summary:** Total files count
- **Preview box:** Shows what will happen
  - File type → Destination (count)
- **Question:** "What would you like to do?"
- **Two options:**
  - "👀 Review Each File First" (large, prominent, recommended)
  - "⚡️ Auto-Organize All" (smaller, faster path)

**Interactions:**
- Back button → Return to rule setup
- "Review Each File First" → Navigate to main Review Interface
- "Auto-Organize All" → Navigate to `processing`

**Technical Notes:**
```swift
struct OrganizationPreview {
    let totalFiles: Int
    let matchedFiles: Int
    let unmatchedFiles: Int
    let ruleBreakdown: [(Rule, Int)]
}
```

---

### Screen 7a: Processing (Auto Mode)

**Screen ID:** `processing`  
**Previous:** `preview` (auto-organize path)  
**Next:** `success`

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                         ✨                                  │
│                                                             │
│                  Organizing your files...                   │
│                                                             │
│    [████████████████████░░] 82%                            │
│                                                             │
│    Moving screenshots to Pictures...                        │
│    84 of 102 files organized                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Icon:** ✨ (sparkles, magic happening)
- **Title:** "Organizing your files..." (20pt)
- **Progress bar:** Visual indicator (0-100%)
- **Status text:** Current action + count
  - "Moving screenshots to Pictures..."
  - "84 of 102 files organized"

**Duration:** 5-15 seconds (varies by file count)

**Interactions:**
- Automatic transition to `success` when complete
- No cancel button (files already moving)

**Technical Notes:**
```swift
// Move files with progress updates
Task {
    let total = filesToMove.count
    for (index, file) in filesToMove.enumerated() {
        try await moveFile(file)
        
        await MainActor.run {
            progress = Double(index + 1) / Double(total)
            statusText = "Moving \(file.category)..."
        }
    }
    
    navigateToSuccess()
}
```

---

### Screen 7b: Review Interface (Manual Mode)

**Screen ID:** `review_interface`  
**Previous:** `preview` (review mode path)  
**Next:** `success` (after processing)

```
┌─────────────────────────────────────────────────────────────┐
│  Forma                                 [×] Close  │
├─────────────────────────────────────────────────────────────┤
│  Found 102 files with matching rules                        │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐│
│  │  💡 First Time Tip:                                    ││
│  │                                                        ││
│  │  • Review suggestions for each file                   ││
│  │  • Press ⌘A to accept, ⌘D to choose different        ││
│  │  • Files with ✓ have matching rules                   ││
│  │  • Click "Process All" when ready                     ││
│  │                                                        ││
│  │                                    [Got It]            ││
│  └────────────────────────────────────────────────────────┘│
│                                                             │
│  📄 Invoice_BestBuy_Oct2024.pdf                    ✓ Rule  │
│     Current: ~/Desktop                                      │
│     Suggested: ~/Documents/PDFs                            │
│     [✓ Accept]  [📂 Different]  [⏭️ Skip]                  │
│  ─────────────────────────────────────────────────────────│
│                                                             │
│  🖼️ Screenshot 2024-11-01 at 9.23.45 AM.png       ✓ Rule  │
│     Current: ~/Desktop                                      │
│     Suggested: ~/Pictures/Screenshots/2024-11              │
│     [✓ Accept]  [📂 Different]  [⏭️ Skip]                  │
│  ─────────────────────────────────────────────────────────│
│                                                             │
│  [More files below...]                                      │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Accepted: 47/102  │  [Select All with Rules] [Process All]│
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Tooltip:** First-time user guide (can be dismissed)
- **File list:** All files with suggestions
  - Filename with icon
  - Current location
  - Suggested destination
  - Rule match indicator (✓ or ⚠️)
  - Action buttons per file
- **Bottom bar:**
  - Progress counter
  - Batch actions
  - "Process All" button (primary)

**Interactions:**
- "Got It" on tooltip → Dismiss tooltip, save preference
- Per-file actions:
  - "Accept" → Mark for moving
  - "Different" → Open folder picker
  - "Skip" → Ignore this file
- Keyboard shortcuts:
  - `⌘A` = Accept
  - `⌘D` = Choose different
  - `Delete` = Skip
  - `↓`/`↑` = Navigate
  - `Space` = Preview (Quick Look)
- "Select All with Rules" → Auto-accept all files with rule matches
- "Process All" → Move all accepted files → Navigate to `success`

**Note:** This is the main Review Interface from the original design document, integrated into onboarding flow

---

### Screen 8: Success

**Screen ID:** `success`  
**Previous:** `processing` or `review_interface`  
**Next:** App ready to use (exit onboarding)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                         ✅                                  │
│                                                             │
│                  All Done!                                  │
│                                                             │
│              Successfully organized 102 files               │
│                                                             │
│    ┌─────────────────────────────────────────────────────┐ │
│    │                                                     │ │
│    │  📸 28 files → Pictures/Screenshots                 │ │
│    │  📄 43 files → Documents/PDFs                       │ │
│    │  📦 19 files → Downloads/Archives                   │ │
│    │  🎨 12 files → Pictures/Imported                    │ │
│    │                                                     │ │
│    │  ⏭️ 54 files skipped (no matching rules)            │ │
│    │                                                     │ │
│    └─────────────────────────────────────────────────────┘ │
│                                                             │
│                                                             │
│              Your Desktop and Downloads are clean! 🎉      │
│                                                             │
│    Forma will keep watching. When files pile     │
│    up again, just click the icon in your menu bar.        │
│                                                             │
│                        [Start Using]                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Icon:** ✅ (checkmark, success)
- **Title:** "All Done!" (24pt, bold)
- **Summary:** Total files organized
- **Results box:** Breakdown by category/rule
  - What moved where
  - What was skipped
- **Celebration:** "Your Desktop and Downloads are clean! 🎉"
- **Next steps:** Explanation of menu bar icon
- **CTA:** "Start Using" (primary, large)

**Interactions:**
- "Start Using" button → Close window, show menu bar icon
  - Menu bar badge shows count of unprocessed files (if any)
  - First-run flag set to complete
  - Window closes

**After Click:**
- Onboarding complete
- Main app interface available via menu bar
- User can scan again anytime

---

## Edge Cases & Error States

### Edge Case 1: No Files Found

**Scenario:** Desktop and Downloads are already clean

```
┌─────────────────────────────────────────────────────────────┐
│                         [← Back]                            │
│                                                             │
│                         ✨                                  │
│                                                             │
│                  Already Clean!                             │
│                                                             │
│    Your Desktop and Downloads folders are empty.           │
│    Nice work keeping things organized!                     │
│                                                             │
│    Forma will watch these folders and            │
│    notify you when files start piling up.                  │
│                                                             │
│                        [Got It]                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Next:** Click "Got It" → Skip to success screen → Exit onboarding

---

### Edge Case 2: Extremely Large File Count

**Scenario:** User has 1000+ files

```
┌─────────────────────────────────────────────────────────────┐
│                         [← Back]                            │
│                                                             │
│                         📊                                  │
│                                                             │
│                  Wow, That's a Lot of Files!                │
│                                                             │
│    Found 1,847 files across Desktop and Downloads.         │
│                                                             │
│    This might take a few minutes to organize.              │
│    We recommend starting with suggested rules to           │
│    process these quickly.                                  │
│                                                             │
│    Most common types:                                      │
│    📄 PDFs (543)                                            │
│    🖼️ Screenshots (312)                                     │
│    📦 Archives (198)                                        │
│    [... and 794 others]                                    │
│                                                             │
│    [🤖 Use Smart Defaults]  [✏️ Create Rules Anyway]       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Recommendation:** Steer toward smart defaults for large file counts

---

### Edge Case 3: No Rules Created

**Scenario:** User skips rule creation

```
┌─────────────────────────────────────────────────────────────┐
│                         [← Back]                            │
│                                                             │
│                         ⚠️                                  │
│                                                             │
│                  No Rules Yet                               │
│                                                             │
│    You haven't created any organization rules.             │
│                                                             │
│    Without rules, Forma won't know               │
│    where to move your files.                               │
│                                                             │
│    What would you like to do?                              │
│                                                             │
│    [🤖 Get Smart Suggestions]                              │
│    [✏️ Create My First Rule]                                │
│    [⏭️ I'll Do This Later]                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Options:**
- Smart suggestions → Navigate to `smart_defaults`
- Create rule → Navigate to `manual_rules`
- Later → Exit onboarding (mark as incomplete, show reminder later)

---

### Error State: Move Failed

**Scenario:** File move operation fails (permissions, disk full, etc.)

```
┌─────────────────────────────────────────────────────────────┐
│                         ⚠️                                  │
│                                                             │
│                  Couldn't Move Some Files                   │
│                                                             │
│    Successfully moved 98 files, but 4 couldn't be moved:   │
│                                                             │
│    • document.pdf (File in use)                            │
│    • image.png (Insufficient permissions)                  │
│    • archive.zip (Disk full)                               │
│    • screenshot.png (File already exists)                  │
│                                                             │
│    These files were left in their original location.       │
│                                                             │
│                    [View Details]  [Continue]               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Interactions:**
- "View Details" → Show detailed error log
- "Continue" → Proceed to success screen with partial results

---

### Error State: Destination Doesn't Exist

**Scenario:** Target folder doesn't exist

```
┌─────────────────────────────────────────────────────────────┐
│                         💡                                  │
│                                                             │
│                  Create New Folders?                        │
│                                                             │
│    Some destination folders don't exist yet:               │
│                                                             │
│    • ~/Pictures/Screenshots/2024-11                        │
│    • ~/Downloads/Archives                                  │
│    • ~/Documents/PDFs                                      │
│                                                             │
│    Should we create these folders for you?                 │
│                                                             │
│              [Yes, Create Them]  [Cancel]                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Default behavior:** Auto-create folders without asking (better UX)  
**Show this only if:** User preference is set to "Ask before creating folders"

---

## Technical Implementation Notes

### State Management

```swift
enum OnboardingState {
    case welcome
    case permissionRequest
    case permissionDenied
    case scanning
    case scanResults(ScanResults)
    case smartDefaults([Rule])
    case manualRules(suggestedRule: Rule?)
    case preview(OrganizationPlan)
    case processing(progress: Double)
    case reviewInterface([FileWithSuggestion])
    case success(MoveResults)
}

class OnboardingViewModel: ObservableObject {
    @Published var currentState: OnboardingState = .welcome
    
    func advance(to newState: OnboardingState) {
        withAnimation {
            currentState = newState
        }
    }
}
```

### Persistence

```swift
// Track onboarding completion
@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

// Save first-run rules
struct OnboardingPreferences: Codable {
    let completedDate: Date
    let createdRules: [Rule]
    let filesOrganized: Int
    let toolTipsSeen: Set<String>
}
```

### Analytics (Optional)

```swift
// Track onboarding funnel
enum OnboardingEvent {
    case started
    case permissionGranted
    case permissionDenied
    case scanCompleted(fileCount: Int)
    case choseSmartDefaults
    case choseManualRules
    case reviewedFiles
    case autoOrganized
    case completed(filesOrganized: Int)
    case abandoned(atStep: OnboardingState)
}
```

### Screen Transitions

```swift
// Smooth transitions between screens
struct OnboardingTransition: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
    }
}
```

---

## Copy Guidelines for Onboarding

### Voice & Tone

**Professional and confident:**
- ✅ "Found 28 files to organize"
- ❌ "OMG look at this mess!"

**Precise and clear:**
- ✅ "28 files → Pictures/Screenshots"
- ❌ "We'll magically organize your screenshots!"

**Direct on permissions:**
- ✅ "Your files stay on your Mac"
- ❌ "Don't worry, we're totally safe and secure!"

**Celebrate with restraint:**
- ✅ "Organized 102 files"
- ❌ "YOU'RE AMAZING! WOW! SO CLEAN!"

### Key Phrases to Use

- "Let's get started" (not "Get started now!")
- "Here's what we found" (not "Look what we discovered!")
- "Would you like to..." (not "Want to...")
- "Successfully organized" (not "Cleaned up")
- "Ready to organize" (not "Ready to clean")

### Words to Avoid

- "Mess" / "Messy" (judgmental)
- "Chaos" / "Chaotic" (too dramatic)
- "Clean up" (sounds like a chore)
- "Fix" (implies something's broken)
- "Problem" (negative framing)
- "Amazing" / "Awesome" (too casual)
- Emojis in primary UI (use sparingly)

---

## Interaction Patterns

### Navigation

**Back button behavior:**
- Always visible in top-left (except welcome screen)
- Returns to previous screen in flow
- Preserves any entered data
- Confirms before discarding work

**Progress indication:**
- No explicit progress bar for onboarding
- User always knows where they are by screen content
- Can go back but encouraged to move forward

### Button Hierarchy

**Primary actions:**
- Blue/accent color
- Larger, more prominent
- Right-aligned or centered

**Secondary actions:**
- Gray or subtle
- Smaller
- Left-aligned or below primary

**Destructive actions:**
- Red tint
- Require confirmation
- Rarely used in onboarding

### Keyboard Shortcuts

**Onboarding screens:**
- `Return/Enter` → Primary action
- `Esc` → Back/Cancel
- `⌘W` → Close window (if allowed)

**Review interface:**
- `⌘A` → Accept suggestion
- `⌘D` → Choose different
- `Delete` → Skip file
- `↓` / `↑` → Navigate
- `Space` → Preview (Quick Look)
- `⌘ Return` → Process all

---

## Testing Checklist

### Functional Testing

- [ ] Welcome screen displays correctly
- [ ] Permission request triggers system dialog
- [ ] Permission denied shows recovery instructions
- [ ] Scanning finds all files in Desktop/Downloads
- [ ] Scan results show accurate counts
- [ ] Smart defaults generate appropriate rules
- [ ] Manual rule creation works
- [ ] Preview shows correct file counts
- [ ] Auto-organize moves files correctly
- [ ] Review interface allows file-by-file approval
- [ ] Success screen shows accurate results
- [ ] Menu bar icon appears after onboarding
- [ ] Back navigation preserves state
- [ ] Keyboard shortcuts work

### Edge Cases

- [ ] 0 files found (empty folders)
- [ ] 1 file found
- [ ] 1000+ files found
- [ ] No rules created
- [ ] All rules disabled
- [ ] Permission denied then granted
- [ ] Destination folders don't exist
- [ ] Disk full error
- [ ] File in use error
- [ ] File name conflicts

### User Experience

- [ ] Flows feel natural and logical
- [ ] Copy is clear and friendly
- [ ] Buttons are easy to identify
- [ ] Loading states are clear
- [ ] Errors are helpful not scary
- [ ] Success feels celebratory
- [ ] Can complete in <1 minute (fast path)
- [ ] Never feels lost or confused

---

## Future Enhancements

### Phase 2 Additions

**AI-Powered Suggestions:**
- Analyze file contents (OCR, metadata)
- Learn from user's organization patterns
- Suggest new rules based on behavior

**Onboarding Variations:**
- Short path for power users
- Extended tutorial for beginners
- Interactive demo mode

**Better Previews:**
- Thumbnail previews in scan results
- Before/after folder visualization
- Simulated file system tree

**Social Proof:**
- "Users typically organize 85% of files on first run"
- Success stories or testimonials
- Popular rule templates

---

## Design Assets Needed

### Icons
- App icon (1024x1024)
- Menu bar icon (22x22, template)
- All emoji replacements if going custom
- State icons (scanning, success, error)

### Illustrations (Optional)
- Welcome screen hero image
- Empty state illustrations
- Success celebration graphic

### Colors
- Primary action color
- Secondary action color
- Error/warning color
- Success color
- Background colors (light/dark mode)

### Typography
- System font (SF Pro)
- Font sizes defined (see wireframes)
- Weight hierarchy (Regular, Medium, Bold)

---

## Onboarding Success Metrics

### Completion Rate
- **Goal:** 80%+ complete onboarding
- **Measure:** % who reach success screen

### Time to Value
- **Goal:** <2 minutes average
- **Measure:** Welcome → Success screen time

### Path Distribution
- **Smart defaults:** Expected 60-70%
- **Manual rules:** Expected 30-40%
- **Review mode:** Expected 70%+
- **Auto-organize:** Expected 30%

### Drop-off Points
- Monitor where users abandon
- Common: Permission denial, rule creation
- Optimize highest drop-off screens

### Files Organized
- **Goal:** 50+ files on first run
- **Measure:** Average files moved
- **Success indicator:** User returns to use again

---

---

## Related Documentation

- [PersonalitySystem.md](../Features/PersonalitySystem.md) - Organization personality quiz (Step 3 of onboarding)
- [OrganizationTemplates.md](../Features/OrganizationTemplates.md) - Template selection (Step 4 of onboarding)
- [DesignSystem.md](./DesignSystem.md) - Design tokens and UI patterns
- [UI-GUIDELINES.md](./UI-GUIDELINES.md) - UI implementation guidelines
- [../Architecture/DASHBOARD.md](../Architecture/DASHBOARD.md) - Main dashboard (post-onboarding)

---

**Document Version:** 1.0
**Last Updated:** November 10, 2025
**Status:** Ready for prototyping
**Next Step:** Create interactive prototype in Figma or SwiftUI
