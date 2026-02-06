# Menu Bar-First Compact Mode

**Date:** 2025-02-05
**Status:** Draft
**Mockup:** `mockups/menu-bar-dropdown.html`

## Problem

Forma is a full-window application (1200x800 minimum), but users don't need it open all the time. A file organizer that demands constant screen real estate fights its own purpose. Users need a way to let Forma run quietly and surface just enough UI to triage files without context-switching into the full app.

## Design Principles

- **The menu bar is the daily driver.** Most interactions happen from the dropdown.
- **The full window is for deep work.** Rules, analytics, bulk operations, settings.
- **Forma is patient.** It doesn't nag. Files can wait.
- **Predictable behavior.** The dropdown always looks the same when you click it. No smart mode-switching.

## App Lifecycle

### Window Close Behavior

When the user closes the main window:
- The app keeps running as a **menu bar icon** (no dock icon visible)
- Automation continues (scanning, auto-organizing high-confidence files)
- Implemented via `NSApplication.shared.setActivationPolicy(.accessory)` when the last window closes
- Activation policy returns to `.regular` when the main window reopens

### Reopening the Full App

- Click "Open Forma" in the dropdown footer
- Or use the menu bar dropdown's gear icon to access settings (opens full app to Settings)
- Spotlight / ⌘-Space search for "Forma" reopens the full window

## Enhanced Menu Bar Dropdown

The dropdown is anchored below the menu bar icon and displays on click. It is the primary interface when the full app is closed.

### Layout (top to bottom)

#### 1. Header
- "Forma" label (left)
- Automation status indicator (right): green dot + "Watching" / yellow "Paused" / gray "Off"

#### 2. Status Summary
- Prominent banner: "{N} files need review" (warm accent background when N > 0)
- Secondary stats: "{X} organized today / {Y} this week"
- When no files need review: "All clear" with checkmark

#### 3. File Review Card (centerpiece)
A single-file-at-a-time review experience:
- File type icon + file name (bold, truncated if long)
- Suggested destination path (muted)
- Matched rule name (small pill badge)
- **Skip** button (secondary/ghost) and **Organize** button (primary, coral accent)
- Pagination: "1 of {N}" with left/right arrows

This card only appears when files need review. When the queue is empty, section 2 shows the "All clear" state.

#### 4. Quick Actions
- "Organize All ({N} high confidence)" -- one-tap to auto-organize files above the confidence threshold
- Only visible when high-confidence files exist

#### 5. Monitored Folders
- List of watched folders with file counts
- Accent dot on folders with pending files
- Collapsible

#### 6. Footer
- "Open Forma" link (opens/reopens the full main window)
- Settings gear icon

### Interactions
- Clicking outside the dropdown dismisses it
- After organizing/skipping a file, the next file in the queue slides in
- When the last file is acted on, the card transitions to "All clear"
- "Organize All" shows a brief confirmation, then clears the queue

## Notification Model

### Default Behavior
- Notify **at most once per day**
- Only if files have been waiting **5 or more days**
- Tapping the notification **opens the menu bar dropdown**

### User Configuration (Settings)
- **Frequency:** Once per day / Every few hours / Never
- **Waiting threshold:** After 1 day / 3 days / 5 days (default) / 7 days
- Respects macOS notification permissions and Do Not Disturb

### What Notifications Don't Do
- No badge on the menu bar icon
- No sound by default (uses macOS default notification sound if user enables it)
- No repeated notifications for the same batch of files within the frequency window

## What Stays in the Full App

These features require the main window and are not accessible from the dropdown:
- Creating and editing rules
- Analytics and productivity reports
- Bulk selection and multi-file operations
- Settings and preferences
- Folder management (adding/removing watched folders)
- Onboarding

## Technical Notes

### Activation Policy Toggling
```swift
// When last window closes
NSApplication.shared.setActivationPolicy(.accessory)

// When main window reopens
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
```

### Notification Implementation
- Use `UNUserNotificationCenter` (already initialized in app startup)
- Schedule a daily check via `AutomationEngine` that evaluates the oldest pending file timestamp
- Notification category with "Review" action that opens the dropdown

### Menu Bar Dropdown
- Existing `MenuBarExtra` with `.window` style already supports custom SwiftUI content
- Enhance `MenuBarView.swift` and `MenuBarViewModel.swift` with:
  - File review queue (paginated single-file view)
  - Organize/Skip actions wired to `FileOperationsService`
  - Status summary from `DashboardViewModel` data

### State Sync
- `MenuBarViewModel` already refreshes on a timer
- Add file review queue as a published property
- Actions taken from the dropdown should reflect immediately in the full app if it's open

## Out of Scope (for now)
- Floating mini-window / PiP mode
- macOS Notification Center widget
- Menu bar icon badge
- Keyboard shortcuts from the dropdown
- Drag-and-drop from the dropdown
