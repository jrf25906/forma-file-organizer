# Forma Beta Test Scenarios

A set of realistic, high-stress scenarios to validate Forma's performance and reliability before v1.0.

## 🌪 Scenario 1: The "Downloads Disaster" (Volume & Variety)
**Persona**: The Hoarder
**Context**: User hasn't cleaned their Downloads folder in 2 years.
**Dataset**: 2,500 files mixed (PDFs, DMGs, JPGs, Zips, loose folders).

**Test Steps**:
1.  **Initial Scan**: Measure time to scan 2,500 files. (Target: < 3 seconds)
2.  **Preview Generation**: Scroll rapidly through the list. Are thumbnails lagging?
3.  **Bulk Action**: Select "All Installers" (e.g., 50 DMGs) and move to Trash.
    *   *Check*: Does the UI freeze? Does the progress bar update accurately?
4.  **Undo**: Immediately press Cmd+Z.
    *   *Check*: Do all 50 files return to the exact same location?

## 🕸 Scenario 2: The "Developer's Nightmare" (Depth & Permissions)
**Persona**: The Full-Stack Dev
**Context**: Desktop is full of project folders with `node_modules`, `.git` directories, and system files.

**Test Steps**:
1.  **Deep Scan**: Point Forma at a folder with 10 levels of nesting.
2.  **Permission Block**: Try to move a file owned by `root` or another user.
    *   *Check*: Does Forma crash? Does it show a helpful "Permission Denied" error?
3.  **Ignored Files**: Ensure `.git` folders and `.DS_Store` files are NOT suggested for moving unless explicitly asked.
4.  **Symlink Safety**: Try to move a symlink that points to a system folder (e.g., `/bin`).
    *   *Check*: Does it move the link or the target? (Should be the link).

## ☁️ Scenario 3: The "Cloud Conflict" (Sync & Network)
**Persona**: The Nomad
**Context**: User is on spotty Wi-Fi, using iCloud Drive and Dropbox.

**Test Steps**:
1.  **Sync Status**: Try to move a file that has a "cloud" icon (not downloaded locally).
    *   *Check*: Does it trigger a download? Does it timeout gracefully?
2.  **Race Condition**: Delete a file in Finder while Forma is scanning it.
    *   *Check*: Does Forma handle the "File not found" error without crashing?
3.  **Locked Files**: Open a Word doc, then try to move it with Forma.
    *   *Check*: Does it fail safely with a "File in use" message?

## 👶 Scenario 4: The "Zero-State" User (Onboarding)
**Persona**: The Skeptic
**Context**: First-time launch, empty Desktop, cautious about privacy.

**Test Steps**:
1.  **Permission Denied**: Deny "Full Disk Access" on first prompt.
    *   *Check*: Does the app explain *why* it's needed and how to fix it?
2.  **Empty State**: Run scan on an empty folder.
    *   *Check*: Is the empty state illustration visible? Is the copy encouraging?
3.  **Uninstallation**: Delete the app.
    *   *Check*: Does it leave any background agents or daemons running?

## 🧪 Edge Cases Checklist

- [ ] **Filename Extremes**: Files with 255 characters, Emojis (📄.txt), and leading dots (.config).
- [ ] **Duplicate Names**: Moving `image.jpg` to a folder that already has `image.jpg`.
- [ ] **Zero-Byte Files**: Handling files with 0 KB size.
- [ ] **Case Sensitivity**: `Test.txt` vs `test.txt` on APFS (usually case-insensitive but worth checking).
- [ ] **Date Anomalies**: Files with "Created Date" in the future or 1970.
