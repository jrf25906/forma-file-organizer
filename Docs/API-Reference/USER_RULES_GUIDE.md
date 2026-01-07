# Forma - User Rules Guide

**Version:** 1.1
**Last Updated:** December 2025
**Status:** Current Implementation (Custom Rules + Compound Conditions)

---

## Table of Contents

1. [Introduction](#introduction)
2. [Understanding Rules](#understanding-rules)
3. [Rule Anatomy](#rule-anatomy)
4. [Creating Custom Rules](#creating-custom-rules)
5. [Rule Conditions](#rule-conditions)
6. [Rule Actions](#rule-actions)
7. [Rule Examples](#rule-examples)
8. [Best Practices](#best-practices)
9. [Rule Library](#rule-library)
10. [Troubleshooting](#troubleshooting)

---

## Introduction

Forma organizes your files using **rules** - simple instructions that tell the app where to move files based on their characteristics. Think of rules as a personal filing assistant that automatically routes files to the right folders.

### What Rules Can Do

Rules match files based on:
- File extension (`.pdf`, `.png`, `.zip`)
- Filename patterns (starts with, contains, ends with)
- File metadata (size, modified/accessed date, age)
- File kind (image, video, document, archive, etc.)

Then they automatically:
- Move files to specific folders
- Organize by date/type/project
- Keep your Desktop and Downloads clean

### Current Status

**Built-in Rules (Available Now):**
- Screenshots → Pictures/Screenshots
- PDF Documents → Documents/PDF Archive
- ZIP Archives → Downloads/Archives

**Custom Rule Builder (Available Now):**
- Create, edit, enable/disable, and delete your own rules via `RuleEditorView`
- Accessed from Settings → Rules or the "+ Rule" entry points in the main UI
- Supports single-condition and compound (AND/OR) rules with date/size-based conditions

For the full implementation details and history, see:
- `Docs/Archive/CompletedWork/CUSTOM_RULES_IMPLEMENTATION.md`
- `Docs/Features/CompoundRuleConditions.md`

---

## Understanding Rules

### How Rules Work

```
IF [file matches condition]
THEN [perform action]
```

**Example:**
```
IF filename starts with "Screenshot" AND file type is PNG
THEN move to ~/Pictures/Screenshots
```

### Rule Evaluation Order

Forma evaluates rules **in order** from top to bottom:
1. First matching rule wins
2. Subsequent rules are skipped for that file
3. No match = file stays in review list

**Why Order Matters:**

```
Rule 1: File extension is .pdf → Documents/PDFs
Rule 2: Filename contains "invoice" → Documents/Finance/Invoices
```

With these rules, `invoice_2024.pdf` goes to `Documents/PDFs` (Rule 1 matches first).

To fix, reorder:
```
Rule 1: Filename contains "invoice" → Documents/Finance/Invoices  [More specific]
Rule 2: File extension is .pdf → Documents/PDFs                   [General catch-all]
```

Now `invoice_2024.pdf` correctly goes to `Documents/Finance/Invoices`.

---

## Rule Anatomy

Every rule has five components:

### 1. Name
Human-readable label for the rule.
```
Examples:
  - "Screenshots"
  - "Invoice PDFs"
  - "Client Work - Acme Corp"
```

### 2. Condition Type
What aspect of the file to check.
```
Available:
  - fileExtension     (e.g., "pdf", "png")
  - nameStartsWith    (e.g., "Screenshot")
  - nameContains      (e.g., "invoice")
  - nameEndsWith      (e.g., "_final")
```

### 3. Condition Value
The specific value to match.
```
Examples:
  - "pdf"                 (for fileExtension)
  - "Screenshot"          (for nameStartsWith)
  - "2024"               (for nameContains)
```

### 4. Action Type
What to do when the rule matches.
```
Current:
  - move              (move file to destination)
  - copy              (copy file, leave original)
  - delete            (send to trash, with preview/confirmation flows)

Planned (not yet implemented in UI):
  - rename            (change filename)
```

### 5. Destination Folder
Where to move the file (relative to home directory).
```
Format: TopLevelFolder/Subfolder/Nested
Examples:
  - "Pictures/Screenshots"
  - "Documents/Finance/Invoices/2024"
  - "Downloads/Archives"
```

---

## Creating Custom Rules

### Basic Rule Structure

You can create rules using this pattern (equivalent to what the RuleEditorView builds under the hood):

```swift
Rule(
  name: "My Rule Name",
  conditionType: .fileExtension,
  conditionValue: "pdf",
  actionType: .move,
  destinationFolder: "Documents/PDFs"
)
```

### Step-by-Step Creation

**1. Name Your Rule**
Choose a descriptive name:
- ✅ "Work PDFs"
- ✅ "Family Photos 2024"
- ❌ "Rule 1"
- ❌ "New Rule"

**2. Define the Condition**
Pick what to match:
```
If file extension is: pdf
If filename starts with: Screenshot
If filename contains: invoice
If filename ends with: _final
```

**3. Set the Condition Value**
Specify the exact match:
```
File extension: "pdf" (no period)
Starts with: "Screenshot" (case-insensitive)
Contains: "invoice" (anywhere in filename)
```

**4. Choose the Action**
Choose between:
- `move`   – Move the file to the destination
- `copy`   – Copy the file and keep the original
- `delete` – Move the file to Trash (requires extra confirmation and preview)

**5. Set the Destination**
Format: `TopLevelFolder/SubFolder/Nested`

**Important:**
- No leading slash (`Pictures/Screenshots`, not `/Pictures/Screenshots`)
- No trailing slash (`Documents/PDFs`, not `Documents/PDFs/`)
- Relative to home directory (`~`)

**6. Test Your Rule**
After creation, scan your Desktop to see what matches.

---

## Rule Conditions

### File Extension

**What it matches:** The file type/extension

**Syntax:**
```
Condition Type: fileExtension
Condition Value: "pdf" (no period)
```

**Examples:**
```
Extension: "pdf"      → matches: document.pdf
Extension: "png"      → matches: image.png
Extension: "zip"      → matches: archive.zip
Extension: "docx"     → matches: report.docx
```

**Tips:**
- Lowercase only (`"pdf"`, not `"PDF"`)
- No period (`"jpg"`, not `".jpg"`)
- Case-insensitive matching

---

### Name Starts With

**What it matches:** Files whose names begin with specific text

**Syntax:**
```
Condition Type: nameStartsWith
Condition Value: "Screenshot"
```

**Examples:**
```
Starts with: "Screenshot"     → matches: Screenshot 2024-01-18.png
Starts with: "Invoice"        → matches: Invoice_Dec2024.pdf
Starts with: "Project_"       → matches: Project_Final.zip
```

**Tips:**
- Case-insensitive (`"screenshot"` matches `"Screenshot"`)
- Spaces matter (`"Screen shot"` ≠ `"Screenshot"`)
- Partial matches don't work (`"Screen"` won't match `"Screenshot"`)

---

### Name Contains

**What it matches:** Files with specific text anywhere in the name

**Syntax:**
```
Condition Type: nameContains
Condition Value: "invoice"
```

**Examples:**
```
Contains: "invoice"     → matches: Dec_invoice_2024.pdf
Contains: "2024"        → matches: Report_2024_Q4.pdf
Contains: "client"      → matches: client_proposal_v2.docx
```

**Tips:**
- Most flexible condition type
- Case-insensitive
- Matches anywhere in filename
- Use specific terms to avoid false matches

**Watch Out:**
```
Contains: "2024"
  ✅ Matches: Report_2024.pdf
  ⚠️ Also matches: 20241231_data.csv (unintended)
```

---

### Name Ends With

**What it matches:** Files whose names end with specific text (before extension)

**Syntax:**
```
Condition Type: nameEndsWith
Condition Value: "_final"
```

**Examples:**
```
Ends with: "_final"     → matches: document_final.pdf
Ends with: "_v2"        → matches: design_v2.sketch
Ends with: "_backup"    → matches: database_backup.sql
```

**Tips:**
- Check text BEFORE the extension
- `"_final.pdf"` won't match (extension is added separately)
- Use for version control patterns

---

## Rule Actions

### Move (Current)

**What it does:** Moves file from source to destination folder

**Behavior:**
- Original file is removed from source
- File appears in destination folder
- Folders created if they don't exist
- Fails if file already exists at destination

**Example:**
```
Source: ~/Desktop/invoice.pdf
Destination: Documents/Finance/Invoices
Result: ~/Documents/Finance/Invoices/invoice.pdf
```

### Copy (Coming Soon)

**What it will do:** Copies file to destination, leaves original

**Use Cases:**
- Backup important files
- Share files across multiple projects
- Preserve originals while organizing

### Delete (Coming Soon)

**What it will do:** Sends file to Trash

**Use Cases:**
- Temporary downloads cleanup
- Duplicate removal
- Old file archiving

**Safety:** Files go to Trash, not permanent deletion.

---

## Rule Examples

### Common Use Cases

#### Screenshots Organization
```
Name: Screenshots
Condition Type: nameStartsWith
Condition Value: "Screenshot"
Action: move
Destination: Pictures/Screenshots
```

**Matches:**
- Screenshot 2024-01-18 at 9.23.45 AM.png
- Screenshot_Jan18.png

---

#### PDF Documents
```
Name: PDF Documents
Condition Type: fileExtension
Condition Value: "pdf"
Action: move
Destination: Documents/PDFs
```

**Matches:**
- Any file ending in .pdf
- report.pdf, invoice.pdf, manual.pdf

---

#### Invoices (Specific)
```
Name: Invoices
Condition Type: nameContains
Condition Value: "invoice"
Action: move
Destination: Documents/Finance/Invoices
```

**Matches:**
- invoice_2024.pdf
- Dec_invoice.pdf
- ClientName_Invoice_001.pdf

**Note:** Place this rule BEFORE general PDF rule to catch invoices specifically.

---

#### Design Files
```
Name: Design Files
Condition Type: fileExtension
Condition Value: "sketch"
Action: move
Destination: Documents/Design/Working
```

**Matches:**
- app_mockup.sketch
- logo_design.sketch

---

#### Archives
```
Name: ZIP Archives
Condition Type: fileExtension
Condition Value: "zip"
Action: move
Destination: Downloads/Archives
```

**Matches:**
- project.zip
- photos_2024.zip

---

### Advanced Patterns

#### Version Control
```
Name: Final Versions
Condition Type: nameEndsWith
Condition Value: "_final"
Action: move
Destination: Documents/Finals
```

**Matches:**
- report_final.pdf
- design_final.sketch

---

#### Client Work
```
Name: Client - Acme Corp
Condition Type: nameContains
Condition Value: "acme"
Action: move
Destination: Documents/Clients/Acme
```

**Matches:**
- acme_proposal.pdf
- Acme_Logo_v2.png

---

#### Year-Based Organization
```
Name: 2024 Documents
Condition Type: nameContains
Condition Value: "2024"
Action: move
Destination: Documents/Archive/2024
```

**Matches:**
- Report_2024_Q4.pdf
- budget_2024.xlsx

---

## Best Practices

### Rule Design

**1. Start Specific, End General**
```
✅ Good Order:
  1. Invoices (specific) → Documents/Finance/Invoices
  2. PDFs (general) → Documents/PDFs

❌ Bad Order:
  1. PDFs (general) → Documents/PDFs
  2. Invoices (specific) → Never reached!
```

**2. Use Descriptive Names**
```
✅ "Client Invoices - Acme Corp"
✅ "Design Files - 2024 Projects"
❌ "Rule 1"
❌ "Temp"
```

**3. Test Before Enabling**
- Create rule
- Scan to preview matches
- Adjust if too broad/narrow
- Enable when confident

**4. One Rule, One Job**
```
✅ Separate rules for:
  - Screenshots → Pictures/Screenshots
  - Photos → Pictures/Photos

❌ Single complex rule trying to handle all images
```

### Folder Organization

**1. Use Standard Mac Folders**
```
✅ Documents, Downloads, Pictures, Music
✅ Documents/Subfolder/Nested

❌ Random locations like Desktop/Stuff
❌ System folders like Applications
```

**2. Create Logical Hierarchies**
```
✅ Documents/Finance/Invoices/2024
✅ Pictures/Screenshots/Work
✅ Downloads/Archives/Projects

❌ Flat structure with everything in Documents
```

**3. Match Your Workflow**
```
If you organize by:
  - Client: Documents/Clients/ClientName
  - Date: Documents/2024/January
  - Project: Documents/Projects/ProjectName
  - Type: Documents/PDFs, Documents/Word
```

### Avoiding Common Mistakes

**1. Overly Broad Rules**
```
❌ Contains "2024" → Matches too many files
✅ Contains "invoice_2024" → More specific
```

**2. Conflicting Rules**
```
❌ Rule 1: Extension is .pdf → Documents/PDFs
   Rule 2: Extension is .pdf → Documents/Work
   (Which wins? Depends on order)

✅ Rule 1: Contains "work" + .pdf → Documents/Work
   Rule 2: Extension is .pdf → Documents/PDFs
```

**3. Typos in Destinations**
```
❌ "Documets/PDFs" (typo creates wrong folder)
✅ "Documents/PDFs"

Tip: Copy-paste folder names from Finder
```

**4. Case Sensitivity Confusion**
```
Condition values are case-insensitive:
  "screenshot" = "Screenshot" = "SCREENSHOT" ✅

But folder names are case-sensitive:
  "documents" ≠ "Documents" ❌
```

---

## Rule Library

### Personal Productivity

```
Screenshots
  Type: nameStartsWith
  Value: "Screenshot"
  Destination: Pictures/Screenshots

Screen Recordings
  Type: nameStartsWith
  Value: "Screen Recording"
  Destination: Movies/Screen Recordings

Downloads Cleanup
  Type: fileExtension
  Value: "dmg"
  Destination: Downloads/Installers
```

### Finance & Business

```
Invoices
  Type: nameContains
  Value: "invoice"
  Destination: Documents/Finance/Invoices

Receipts
  Type: nameContains
  Value: "receipt"
  Destination: Documents/Finance/Receipts

Bank Statements
  Type: nameContains
  Value: "statement"
  Destination: Documents/Finance/Statements
```

### Creative Work

```
Design Files
  Type: fileExtension
  Value: "sketch"
  Destination: Documents/Design/Sketch

Photoshop Files
  Type: fileExtension
  Value: "psd"
  Destination: Documents/Design/Photoshop

Final Exports
  Type: nameEndsWith
  Value: "_export"
  Destination: Documents/Design/Exports
```

### Development

```
Code Archives
  Type: fileExtension
  Value: "zip"
  Destination: Documents/Code/Archives

Documentation
  Type: fileExtension
  Value: "md"
  Destination: Documents/Code/Docs

Database Backups
  Type: nameContains
  Value: "backup"
  Destination: Documents/Databases/Backups
```

---

## Advanced Rule Cookbook (Implemented Features)

This section gives concrete, ready-to-use recipes that combine the rule features implemented today: compound conditions, date/size-based conditions, and delete/copy/move actions.

### 1. DMG Cleanup – Delete Old Installers

**Goal:** Keep Downloads tidy by deleting DMG installers older than 7 days.

**Rule Setup (Compound AND):**
```text
Name: Old DMG Installers
Mode: Multiple conditions (ALL conditions must match)

Conditions:
  1. Condition Type: fileExtension
     Condition Value: "dmg"
  2. Condition Type: dateOlderThan
     Condition Value: "7"         // days

Action: delete
Destination: (not required for delete)
```

**Notes:**
- Use the delete preview feature in RuleEditorView to see which files would match before enabling.
- Start with a larger threshold (e.g., 30 days) if you’re unsure.

### 2. Video Archive – Move Large Videos to an External Folder

**Goal:** Move large video files off Desktop/Downloads into a dedicated archive folder.

**Rule Setup (Compound AND):**
```text
Name: Large Video Archive
Mode: Multiple conditions (ALL conditions must match)

Conditions:
  1. Condition Type: fileKind
     Condition Value: "video"
  2. Condition Type: sizeLargerThan
     Condition Value: "500MB"     // human-readable threshold

Action: move
Destination: Movies/Video Archive
```

**Notes:**
- `fileKind` uses the app’s internal categorization (e.g., video, image, document).
- Make sure you grant access to `~/Movies` when prompted.

### 3. Project Cleanup – Move Old Project PDFs to Archive

**Goal:** Move older project PDFs into an archive folder while keeping recent ones handy.

**Rule Setup (Compound AND):**
```text
Name: Project PDFs Archive
Mode: Multiple conditions (ALL conditions must match)

Conditions:
  1. Condition Type: nameContains
     Condition Value: "ProjectX"   // or your project code
  2. Condition Type: fileExtension
     Condition Value: "pdf"
  3. Condition Type: dateModifiedOlderThan
     Condition Value: "60"         // days

Action: move
Destination: Documents/Projects/ProjectX/Archive
```

**Notes:**
- This is a safe way to keep current work nearby and older work organized but out of the way.
- You can duplicate this pattern for different project codes by changing `nameContains` and destination.

### 4. Document Triage – Copy Important Documents for Backup

**Goal:** Copy important documents with “statement” or “policy” in the name into a backup folder, while leaving the originals where they are.

**Rule Setup (Compound OR):**
```text
Name: Financial Docs Backup
Mode: Multiple conditions (ANY condition may match)

Conditions:
  1. Condition Type: nameContains
     Condition Value: "statement"
  2. Condition Type: nameContains
     Condition Value: "policy"

Action: copy
Destination: Documents/Finance/Backup
```

**Notes:**
- `copy` keeps the original file in place and writes a duplicate to the destination.
- Consider combining this with a date or size condition if the set is very large.

### 5. Stale Downloads – Sweep Old Non-Document Files

**Goal:** Clean out stale, non-document files from Downloads without touching recent work.

**Rule Setup (Compound AND):**
```text
Name: Stale Non-Documents in Downloads
Mode: Multiple conditions (ALL conditions must match)

Conditions:
  1. Condition Type: sourceLocation
     Condition Value: "downloads"     // Desktop, Downloads, Documents, etc.
  2. Condition Type: fileKind
     Condition Value: "archive"       // or "video", "audio" depending on your needs
  3. Condition Type: dateAccessedOlderThan
     Condition Value: "30"            // days

Action: delete
Destination: (not required for delete)
```

**Notes:**
- `sourceLocation` corresponds to the source folder (e.g., Desktop vs Downloads).
- Use the preview before enabling delete and start with a conservative age threshold.

### 6. Combined Invoice Rule – Specific vs General

**Goal:** Ensure invoices go to a dedicated folder, while other PDFs go to a generic PDF archive.

**Rules:**

1. **Invoices (Specific)**
   ```text
   Name: Invoices
   Condition Type: nameContains
   Condition Value: "invoice"
   Action: move
   Destination: Documents/Finance/Invoices
   ```

2. **All PDFs (General)**
   ```text
   Name: All PDFs
   Condition Type: fileExtension
   Condition Value: "pdf"
   Action: move
   Destination: Documents/PDFs
   ```

**Ordering:**
- Place **Invoices** above **All PDFs** in the rule list so that:
  - `invoice_2024.pdf` → `Documents/Finance/Invoices`
  - `manual.pdf` → `Documents/PDFs`

---

---

## Troubleshooting

### Rule Not Matching Files

**Problem:** Created a rule but files don't match

**Solutions:**

1. **Check Condition Type**
   - File extension: Use `fileExtension` not `nameContains`
   - Exact match: Use `nameStartsWith` not `nameContains`

2. **Verify Condition Value**
   ```
   ❌ Extension: ".pdf" (no period)
   ✅ Extension: "pdf"

   ❌ Starts with: "screen" (partial)
   ✅ Starts with: "Screenshot" (exact)
   ```

3. **Check Rule Order**
   - Earlier rule might be matching first
   - Move specific rules above general ones

4. **Scan Again**
   - Rules only apply to new scans
   - Click refresh (↻) to re-evaluate files

### Files Going to Wrong Folder

**Problem:** Files match but go to unexpected destination

**Solutions:**

1. **Check Destination Path**
   ```
   ❌ "Documents/PDFs/" (trailing slash)
   ✅ "Documents/PDFs"

   ❌ "/Documents/PDFs" (leading slash)
   ✅ "Documents/PDFs"
   ```

2. **Verify Folder Name**
   - Folder names are case-sensitive
   - `Documents` ≠ `documents`

3. **Check Rule Enabled**
   - Disabled rules don't match
   - Enable in Settings → Rules

### Permission Errors

**Problem:** "Permission denied" when moving files

**Solutions:**

1. **Grant Folder Access**
   - Forma will prompt for destination folder
   - Select the EXACT folder requested
   - Example: If prompted for "Documents", select ~/Documents

2. **Reset Permissions**
   - Settings → Reset All Permissions
   - Restart app
   - Grant permissions again carefully

3. **Verify Destination Exists**
   - Forma creates subdirectories automatically
   - But top-level folder must exist (Documents, Pictures, etc.)

### Too Many/Too Few Matches

**Problem:** Rule matches wrong number of files

**Solutions:**

1. **Too Many Matches (Too Broad)**
   ```
   ❌ Contains: "2024"
      Matches: Everything from 2024

   ✅ Contains: "invoice_2024"
      Matches: Only invoices from 2024
   ```

2. **Too Few Matches (Too Specific)**
   ```
   ❌ Starts with: "Screenshot 2024"
      Misses: "Screenshot 2023"

   ✅ Starts with: "Screenshot"
      Matches: All screenshots
   ```

3. **No Matches (Typo/Wrong Condition)**
   ```
   ❌ Extension: "PDF" (uppercase)
   ✅ Extension: "pdf" (lowercase)
   ```

---

## Advanced & Future Features

This section summarizes advanced functionality around rules and what is planned next.

### Advanced Features (Implemented)

**Multi-Condition Rules (AND/OR)**
```
IF filename contains "invoice"
AND file extension is "pdf"
AND file size > 1MB
THEN move to Documents/Finance/Invoices
```
- Implemented via `Rule.conditions` + `Rule.LogicalOperator`
- UI: "Multiple conditions" toggle and AND/OR selector in RuleEditorView
- See `Docs/Features/CompoundRuleConditions.md` for details.

**Date/Size/Kind-Based Conditions**
- Condition types such as:
  - `dateOlderThan`
  - `sizeLargerThan`
  - `dateModifiedOlderThan`
  - `dateAccessedOlderThan`
  - `fileKind`
- Allow rules like "delete DMG files older than 7 days" or "move large videos to an archive."

**AI-Suggested Rules**
```
Forma analyzes your files and suggests:
  "You have 23 files starting with 'Invoice' –
   create a rule to organize them?"
```
- Implemented via `LearningService` and conversion of `LearnedPattern` to `Rule`
- See `Docs/Features/AIFeatures.md` and `Docs/API-Reference/API_REFERENCE.md` (LearningService section).

### Planned Enhancements (Not Yet Implemented)

**Date-Based Destinations with Variables**
```
Destination: Documents/PDFs/[Year]/[Month]
Result: Documents/PDFs/2024/January/file.pdf
```

**Smart Destination Variables**
```
Destination: Documents/[FileType]/[Year]
For: photo.jpg → Documents/Images/2024
For: doc.pdf → Documents/PDFs/2024
```

**Rule Templates & Libraries**
```
Pre-built rule sets for:
  - Photographers
  - Developers
  - Writers
  - Students
  - Business professionals
```
- Currently tracked in `Docs/Getting-Started/TODO.md` under "Rule templates library."

---

## Appendix

### Quick Reference

**Condition Types:**
```
fileExtension      → "pdf", "png", "zip"
nameStartsWith     → "Screenshot", "Invoice"
nameContains       → "2024", "client"
nameEndsWith       → "_final", "_backup"
```

**Action Types:**
```
move               → Move file to destination
copy (soon)        → Copy file, keep original
delete (soon)      → Send to Trash
```

**Destination Format:**
```
Pattern: TopLevelFolder/SubFolder/Nested
Example: Documents/Finance/Invoices/2024

Rules:
  - No leading slash
  - No trailing slash
  - Relative to home (~)
  - Case-sensitive
```

### Getting Help

**Resources:**
- SETUP.md - Installation and permissions
- ARCHITECTURE.md - How Forma works
- Forma-Design-Doc.md - Product vision

**Debug Tips:**
1. Check console logs (View → Show Console in Xcode)
2. Verify file extensions match exactly
3. Test rules on small file set first
4. Reset permissions if persistent errors

---

**Document Version:** 1.1  
**Last Updated:** December 2025  
**Status:** Aligned with current custom rule builder and compound rule implementation
