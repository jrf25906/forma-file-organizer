# Fix for File Operations Not Working

**Status:** Archived (historical)
**Archived:** 2025-01
**Superseded By:** [Docs/Getting-Started/SETUP.md](../Getting-Started/SETUP.md)

## What's Wrong

Your console logs revealed the **root cause**:

```
couldn't issue sandbox extension com.apple.app-sandbox.read for 
'/Users/username/Desktop/Screenshot...': Operation not permitted
```

**The app doesn't have permission to access Desktop!**

Your bookmark diagnostic showed:
- ✅ Documents bookmark exists
- ✅ Downloads bookmark exists  
- ✅ Pictures bookmark exists
- ❌ **Desktop bookmark is MISSING**

## Why This Breaks File Operations

When you try to move a screenshot from Desktop to Pictures:
1. App tries to read the file on Desktop
2. macOS blocks it: "Operation not permitted"
3. `FileManager.moveItem()` fails silently
4. File never moves, but UI shows "organized"

## The Fix - Grant Desktop Access

### Option 1: Via Onboarding (Easiest)

1. **Delete the app's preferences** to reset onboarding:
   ```bash
   defaults delete com.yourteam.Forma-File-Organizing
   ```

2. **Restart the app** - the onboarding screen will appear

3. **Click "Grant Access" for Desktop** (and all other folders)

4. **Select your Desktop folder** when prompted

5. Click "Continue" when all permissions are granted

### Option 2: Via System Settings

If onboarding doesn't appear:

1. Open **System Settings**
2. Go to **Privacy & Security** → **Files and Folders**
3. Find **"Forma File Organizing"** in the list
4. Make sure these are enabled:
   - ✅ Desktop Folder
   - ✅ Downloads Folder
   - ✅ Documents Folder
   - ✅ Pictures Folder
   - ✅ Music Folder

**Note:** This might not work perfectly because the app uses security-scoped bookmarks, not just standard permissions.

### Option 3: Manual Bookmark Fix (Advanced)

If the above don't work, you can manually request Desktop access:

1. Run the app from Xcode
2. When you see the dashboard, press **Cmd+Shift+2** or go to Settings
3. Look for a "Re-grant Folder Access" or similar button
4. Grant Desktop access when prompted

## Verify the Fix

After granting Desktop access, run this script:
```bash
./check_bookmarks.sh
```

You should see:
```
✅ Found destination folder bookmarks:
  📁 Desktop
  📁 Documents
  📁 Downloads
  📁 Pictures
```

## Test the Fix

1. **Scan for files** in the app
2. **Select a screenshot** on your Desktop
3. **Click "Organize"**
4. **Watch the console** - you should now see:

```
🔐 Checking source folder access: Desktop
✅ Source folder bookmark exists for Desktop

🚀 Attempting to move:
  FROM: /Users/username/Desktop/Screenshot.png
  TO: /Users/username/Pictures/Screenshots/Screenshot.png

🔍 POST-MOVE VERIFICATION:
  Source still exists: ✅ NO (good)
  Destination exists: ✅ YES (good)

✅ File move verified successfully!
🎉 === FILE MOVE OPERATION COMPLETE ===
```

5. **Check your Desktop** - the file should be gone
6. **Check Pictures/Screenshots** - the file should be there!

## What I Changed in the Code

1. **Added Desktop Access Check** - Before moving any file, the app now checks if it has a bookmark for the source folder

2. **Better Error Messages** - If Desktop access is missing, you get a clear error: "Missing folder access. Please grant permission..."

3. **Auto Re-prompt** - When a permission error occurs, the onboarding screen automatically reopens

4. **Comprehensive Logging** - Every step of file operations is now logged for debugging

## Why This Happened

During onboarding, you either:
- Clicked "Skip for now" without granting Desktop access
- Granted access to Documents/Downloads/Pictures but skipped Desktop
- The Desktop permission dialog was dismissed or cancelled

The app can **scan** and **list** files without full access (it sees filenames), but it can't actually **read or move** them without security-scoped bookmarks.

## Prevention

In the future:
- Always grant ALL folder permissions during onboarding
- Don't skip any permission requests
- If you see a file picker dialog, make sure to select the correct folder

## Still Not Working?

If files still don't move after granting Desktop access:

1. **Check Console for new errors:**
   ```bash
   # Run app from Xcode and look for any red ❌ messages
   ```

2. **Reset ALL app data:**
   ```bash
   defaults delete com.yourteam.Forma-File-Organizing
   rm -rf ~/Library/Containers/com.yourteam.Forma-File-Organizing/
   ```

3. **Check System Console** (Console.app) for sandbox violation messages

4. Share the console output with me for further diagnosis
