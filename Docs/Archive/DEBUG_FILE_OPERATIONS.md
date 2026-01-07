# File Operation Debugging Guide

**Status:** Archived (historical)
**Archived:** 2025-01
**Superseded By:** [Docs/Getting-Started/SETUP.md](../Getting-Started/SETUP.md)

## Problem
Files appear to be "organized" in the UI but remain at their original location on disk. Activity logs show successful moves, but files don't actually move.

## What We've Added

### 1. Comprehensive Logging
Added detailed logging throughout `FileOperationsService.swift` to trace:
- Source file path and destination
- Bookmark resolution (which folder path is being used)
- Security-scoped access
- Pre and post-move verification
- Any errors that occur

### 2. Post-Move Verification
After `FileManager.moveItem()`, the code now checks:
- Does the source file still exist? (should be NO after move)
- Does the destination file exist? (should be YES after move)
- If either check fails, it logs a warning about sandboxing/permissions issues

### 3. Bookmark Diagnostics
Added `diagnoseBookmarks()` function that runs on app startup and shows:
- All saved destination folder bookmarks
- The actual paths they resolve to
- Whether bookmarks are valid or stale

## How to Use This

### Step 1: Run the App and Check Console
1. Open the project in Xcode
2. Run the app (Cmd+R)
3. Open the Console pane (Cmd+Shift+Y)
4. Look for the startup message:

```
🔍 === BOOKMARK DIAGNOSTICS ===
  Found X destination bookmark(s):
    Pictures: /Users/yourname/Pictures [✅ VALID]
    Documents: /Users/yourname/Documents [✅ VALID]
=== END DIAGNOSTICS ===
```

**KEY QUESTION:** Do the bookmark paths match your actual user folders?
- Expected: `/Users/yourname/Pictures`
- WRONG: `/Users/yourname/Library/CloudStorage/...` or any other path

### Step 2: Try to Organize a File
1. Select a file (e.g., a screenshot on Desktop)
2. Click "Organize" to move it to Pictures/Screenshots
3. Watch the console for detailed logs:

```
🔧 === FILE MOVE OPERATION START ===
📁 Source: /Users/yourname/Desktop/Screenshot.png
📍 Suggested Destination: Pictures/Screenshots

✅ Source file exists

🔐 BOOKMARK RESOLUTION for: Pictures
  Found saved bookmark for Pictures
  ✅ Bookmark resolved to: /Users/yourname/Pictures
  📂 Is this the correct path? Expected: ~/Pictures

📦 PATHS:
  Resolved Top-Level URL: /Users/yourname/Pictures
  Destination Folder: /Users/yourname/Pictures/Screenshots
  Final Destination: /Users/yourname/Pictures/Screenshots/Screenshot.png

🚀 Attempting to move:
  FROM: /Users/yourname/Desktop/Screenshot.png
  TO: /Users/yourname/Pictures/Screenshots/Screenshot.png

🔍 POST-MOVE VERIFICATION:
  Source still exists: ❌ YES (PROBLEM!)  <-- or --> ✅ NO (good)
  Destination exists: ❌ NO (PROBLEM!)    <-- or --> ✅ YES (good)

⚠️ WARNING: File move may have failed silently!
  This suggests a sandboxing or permissions issue.
```

### Step 3: Interpret the Results

#### Scenario A: Bookmark path is wrong
If the bookmark resolves to the wrong path (e.g., iCloud, container, etc.):
**Solution:** Reset destination bookmarks and grant permission again
```swift
// In Xcode Debug Console:
fileOperationsService.resetDestinationAccess()
// Then restart app and grant folder access again
```

#### Scenario B: Move succeeds but file doesn't actually move
If logs show:
- "Source still exists: ❌ YES (PROBLEM!)"
- "Destination exists: ❌ NO (PROBLEM!)"

This means FileManager.moveItem() didn't throw an error but also didn't move the file.
**Root Cause:** App Sandbox is blocking access despite security-scoped bookmarks.

**Solution:**
1. Check entitlements file for proper sandbox settings
2. Verify security-scoped bookmarks are being created correctly
3. May need to request Full Disk Access in System Settings

#### Scenario C: "File already exists" error
If you see an error about destination file existing:
**Solution:** The file is already there, just UI/database is out of sync

## Next Steps Based on Findings

### If bookmarks are pointing to wrong folders:
1. Run `fileOperationsService.resetDestinationAccess()`
2. Restart app
3. Manually select the correct folders when prompted

### If bookmarks are correct but files don't move:
This is likely a sandboxing issue. The app might need:
1. Different entitlements configuration
2. User to grant Full Disk Access via System Settings
3. Different bookmark creation approach (app-scoped vs document-scoped)

### If move verification shows success:
Then the issue is elsewhere (e.g., file scanning not picking up changes, UI not refreshing)

## Manual Test Command
You can test the file move operation manually in Terminal:
```bash
# Create a test file
touch ~/Desktop/test_move.txt

# Try to move it
mv ~/Desktop/test_move.txt ~/Pictures/test_move.txt

# Check if it moved
ls ~/Desktop/test_move.txt  # Should show "No such file"
ls ~/Pictures/test_move.txt  # Should show the file
```

If this works but the app doesn't, it confirms sandboxing is the issue.

## Common Fixes

### Reset All Bookmarks
```bash
# Run in Terminal
defaults delete com.yourteam.Forma-File-Organizing DestinationFolderBookmark_Pictures
defaults delete com.yourteam.Forma-File-Organizing DestinationFolderBookmark_Documents
# ... etc for each folder
```

### Check System Settings
System Settings > Privacy & Security > Files and Folders
- Ensure "Forma File Organizing" has access to Desktop, Downloads, etc.

System Settings > Privacy & Security > Full Disk Access
- If other methods fail, add Forma here

## Contact Points for Further Investigation
If logs show the file operation should work but doesn't:
1. Check if macOS is silently blocking the operation (check Console.app for system messages)
2. Verify the app's entitlements in Xcode (Signing & Capabilities)
3. Check if FileProvider or iCloud is interfering
4. Verify security-scoped bookmark options (.withSecurityScope)
