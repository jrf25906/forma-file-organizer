# Quick Fix: Destination Folder Permissions

**Status:** Archived (historical)
**Archived:** 2025-01
**Superseded By:** [Docs/Getting-Started/SETUP.md](../Getting-Started/SETUP.md)

## 🔍 The Issue You Found

When you clicked the ✓ button to move a screenshot to `Pictures/Screenshots`, you got a **permission denied** error.

### Why?
- The app had permission to **read** Desktop (source folder)
- But it didn't have permission to **write** to Pictures/Screenshots (destination folder)
- Security-scoped bookmarks only grant access to the specific folder you selected

## ✅ The Fix

I've updated the app to automatically request permission for destination folders:

### How It Works Now:

1. **You click ✓ to move a file**
2. App checks: "Do I have permission for Pictures/Screenshots?"
3. **If NO:** Shows folder picker asking for access
4. **Message:** "Forma needs access to create/modify files in: ~/Pictures/Screenshots"
5. You click "Grant Access"
6. App saves that permission
7. File moves successfully!
8. **Next time:** No prompt needed - permission is saved

### Smart Features:

- ✅ **One-time setup per destination:** Once you grant access to Pictures, you won't be asked again
- ✅ **Auto-creates folders:** If ~/Pictures/Screenshots doesn't exist, it creates it
- ✅ **Clear messages:** Shows exactly which folder needs access
- ✅ **Pre-selects parent:** Opens picker at ~/Pictures so you can select Screenshots

## 🚀 Testing Now

1. Put a file named `Screenshot 2025-01-01.png` on Desktop
2. Run the app (⌘R)
3. Grant Desktop access (if first time)
4. See the screenshot in the list
5. Click ✓ to move it
6. **NEW:** Folder picker appears for Pictures folder
7. Select the Pictures folder (or create Screenshots inside it)
8. Click "Grant Access"
9. File moves to ~/Pictures/Screenshots/
10. Success! 🎉

**Next screenshot move:** No prompt - it remembers the permission!

## 📝 Code Changes

**FileOperationsService.swift:**
- Added `ensureDestinationAccess()` - checks for saved bookmark or requests it
- Added `requestDestinationAccess()` - shows folder picker for destinations
- Added `resetDestinationAccess()` - clears saved destination permissions
- Updated `moveFile()` - requests access before moving

**Flow:**
```
moveFile()
  → ensureDestinationAccess()
    → Load saved bookmark?
      → YES: Use it
      → NO: Show folder picker
        → Save new bookmark
  → Start security-scoped access
  → Create directory
  → Move file
  → Stop security-scoped access
```

## 🎯 Expected Behavior

### First Move to New Destination:
1. Click ✓ on screenshot
2. Picker: "Grant access to ~/Pictures/Screenshots"
3. Select folder
4. File moves
5. Success message

### Subsequent Moves to Same Destination:
1. Click ✓ on screenshot
2. File moves immediately (no picker!)
3. Success message

### Different Destinations:
- Each unique destination folder gets its own permission
- Documents/Finance → One permission
- Pictures/Screenshots → Another permission
- Downloads/Archive → Another permission
- Once granted, permissions persist

## 💡 User Experience

This is actually **better UX** than full disk access:

- **Transparent:** User sees exactly what folders the app can access
- **Gradual:** Only asks when needed, not all at once
- **Secure:** Minimal permissions - only what's necessary
- **Persistent:** Remembers permissions so you're not repeatedly asked

## 🐛 If Something Goes Wrong

If you get permission errors:
1. Make sure you're selecting the correct parent folder
2. For Pictures/Screenshots, select the **Pictures** folder (not Screenshots)
3. The app will create Screenshots inside Pictures automatically

To reset all permissions:
```swift
// In ReviewViewModel or add a button
viewModel.fileOperationsService.resetDestinationAccess()
```

---

**Build status:** ✅ Succeeded
**Ready to test:** Yes! The fix is live.
