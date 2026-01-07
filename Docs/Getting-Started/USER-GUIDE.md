# Forma - User Guide

**Version:** 1.0  
**Last Updated:** December 2025  
**Audience:** Everyday users of Forma (no code required)

---

## 1. What Forma Does

Forma is a macOS app that keeps your Desktop, Downloads, and other folders organized using:

- **Personality-based templates** – folder structures tailored to how you think and work
- **Smart rules** – automatic moves based on file type, name, or patterns
- **AI-powered context detection** – understands related files and suggests destinations
- **Project clustering** – groups related files into projects
- **Insights & analytics** – shows how organized you are and where clutter is building up

You stay in control at every step: Forma suggests, previews, and lets you confirm changes before files move.

For installation, permissions, and advanced diagnostics, see `SETUP.md`. This guide focuses on **how to use** Forma day to day once it’s installed.

---

## 2. Key Concepts

### Sources vs Destinations

- **Source folders**: Where clutter tends to accumulate (Desktop, Downloads, etc.)
- **Destination folders**: Where organized files should live (Documents, Pictures, Project folders)
- Forma asks you once for access to each folder via a standard macOS folder picker
- Permissions are stored securely via **security-scoped bookmarks** so you don't have to keep re‑granting access

### Sidebar Locations (Auto-Populated)

When you grant folder permissions during onboarding, those folders automatically appear in the sidebar under **LOCATIONS**. This "two birds, one stone" design means:

- You only grant permissions once (during onboarding)
- The folders you granted access to are immediately visible for navigation
- No need to separately "add" locations after onboarding

You can still add more locations later using the **+ Add Location** button in the sidebar.

### Dashboard Layout

Forma’s main window uses a three-panel layout:

- **Left sidebar** – sources, views, and filters
- **Center** – file list/grid where you review and act, or **Analytics Dashboard**
- **Right panel** – context: file details, suggestions, and recommendations

You can switch between **card, list, or grid** views to match your preference.

### Personality & Templates

- On first launch, a short **personality quiz** learns how you think about files
- Based on your answers, Forma recommends an **organization template**
- Templates define:
  - Default folder structure (e.g., “Documents/Work/Clients/…”, “Pictures/Screenshots”)
  - Preferred view modes
  - Suggested depth of nesting

You can change templates later in **Settings → Templates** without losing existing files.

### Rules & Suggestions

- **Rules** are “if this, then that” instructions, for example:
  - `IF extension is "pdf" THEN move to Documents/PDF Archive`
  - `IF name starts with "Screenshot" THEN move to Pictures/Screenshots`
- Forma provides:
  - **Built-in rules** for common file types
  - A **visual rule builder** for custom rules
  - **Inline suggestions** based on your behavior over time

You always see a preview before files are moved.

### Project Clusters

- Forma can detect **related files** (by name, dates, and content signals)
- Related files are grouped into **project clusters**
- Clusters appear in the dashboard and right panel, so you can jump into a project quickly

### Insights & Activity

- **Insights**: charts and summaries (storage breakdown, trends) are now in the **Center Panel**
- **Recommendations**: actionable advice ("Opportunities") is in the **Right Panel**
- **Activity feed**: chronological view of what Forma did (moves, skips, errors)
- Most actions are **undoable** from the activity feed

---

## 3. First Session Walkthrough

If you just installed Forma, follow this high-level path:

1. **Launch Forma**
   - If prompted by Gatekeeper, choose “Open”

2. **Complete onboarding**
   - **Step 1 – Welcome:** Overview of what Forma will do
   - **Step 2 – Folder Setup:** Grant access to Desktop and optionally Downloads/Documents/Pictures (these folders will automatically appear in the sidebar under LOCATIONS)
   - **Step 3 – Personality Quiz:** Answer three questions about how you usually find files
   - **Step 4 – Template Selection:** Confirm or change the suggested template

3. **Land on the Dashboard**
   - Left: your sources (Desktop, Downloads, etc.)
   - Center: files needing review
   - Right: active file details / suggestions

4. **Run your first scan**
   - Select **Desktop** (or another source) in the sidebar
   - Click **Scan** or the refresh button (↻)
   - Forma analyzes files and shows which rules/suggestions apply

5. **Review suggested moves**
   - Use filters (e.g., “Suggested”, “Needs rule”, “Already organized”)
   - Hover or select files to see details in the right panel
   - Accept suggestions in batches, starting with low-risk items (screenshots, downloads, archives)

6. **Commit your first organization**
   - Click **Organize** or the bulk action bar when you’re comfortable
   - Watch the activity feed to see what moved
   - Use **Undo** if something isn’t where you expect

For detailed screenshots and onboarding flow diagrams, see `Docs/Design/Forma-Onboarding-Flow.md`.

---

## 4. Everyday Workflows

### 4.1 Keep Your Desktop Clean

**Goal:** Turn your Desktop from a pile into a workspace.

Typical setup:
- Source: `Desktop`
- Destinations: `Documents`, `Pictures`, `Downloads/Archives`, project folders

Suggested routine:
1. Open Forma and select **Desktop** in the sidebar.
2. Use the **“Unorganized”** or **“Needs attention”** filter.
3. Accept safe, obvious suggestions first:
   - Screenshots → Pictures/Screenshots
   - PDFs → Documents/PDF Archive
   - ZIPs → Downloads/Archives
4. For files without rules:
   - Manually choose a destination once
   - Let Forma suggest similar moves next time

Tip: Do a quick 2–5 minute Desktop review at the end of each day instead of a giant cleanup once a month.

### 4.2 Tame Your Downloads Folder

**Goal:** Prevent Downloads from becoming a permanent archive.

1. Select **Downloads** as the source.
2. Sort by **recent first** to see what you just grabbed.
3. Use rules and suggestions for:
   - DMGs / installers → delete or move to a dedicated “Installers” folder
   - Invoices / receipts → Documents/Finance
   - Zips → Downloads/Archives or project folders
4. Use **batch selection**:
   - Filter by type (e.g., PDFs)
   - Confirm the suggested destination for all selected files

Tip: Treat Downloads as “inbox”, not “storage”. If it’s older than a few weeks, it probably needs a permanent home or the trash.

### 4.3 Use Templates for New Projects

**Goal:** Start new work with a clean, consistent folder structure.

1. Open **Settings → Templates**.
2. Choose a template that matches your work style (e.g., “Creative Professional”, “Student”, “Business Professional”).
3. When you start a new project:
   - Create a **project folder** using the template as a base
   - Optionally create a **cluster** for that project
4. As files land on Desktop or Downloads:
   - Use rules or suggestions to move them into the project folders

Over time, your project folders will mirror how you actually work, not just where files happened to land.

### 4.4 Build Your Own Rules

**Goal:** Automate repetitive moves you keep doing manually.

1. Open the **Rules** view or **Settings → Rules**.
2. Click **“+ Rule”**.
3. Choose:
   - Condition type (extension, name contains, etc.)
   - Condition value (e.g., `pdf`, `Screenshot`, `invoice`)
   - Destination folder (e.g., `Documents/Finance/Invoices`)
4. Save the rule and run a scan.
5. Review the **“Matched by rule X”** indicator in the file list.
6. If the rule is too broad:
   - Make the condition more specific
   - Adjust the rule order (specific rules before general catch‑alls)

For deeper details and examples, including advanced recipes (compound conditions, date/size rules, delete/copy actions), see `Docs/API-Reference/USER_RULES_GUIDE.md` (Rule Examples and Advanced Rule Cookbook sections).

### 4.5 Work with Project Clusters

**Goal:** See all files for a project at once.

1. Open the **Projects** section in the sidebar.
2. Select a project cluster:
   - Forma groups related files by names, dates, and activity
3. From the cluster view you can:
   - Jump directly to files on disk
   - See suggested destinations
   - Spot files that still live on Desktop/Downloads
4. Use rules and manual moves to keep project clusters tidy over time.

---

## 5. Smart Features & AI Behavior

Forma uses local intelligence and optional AI-powered features to make smarter suggestions. All AI/ML features follow the app’s feature flag pattern:

- There is a master **“AI Features”** toggle in Settings.
- Each individual AI feature (pattern learning, context detection, suggestions) has its own toggle.
- Turning off the master toggle disables all AI features, even if individual toggles are on.

### Pattern Learning

- Watches which files you move where, and how often
- Learns “when I see files like this, send them there”
- Feeds into **DestinationPredictionService** and suggestions in the UI

### Context Detection

- Looks at file names, extensions, and metadata to infer relationships
- Helps with:
  - Project clustering
  - “Related files” suggestions in the right panel
  - Smart filters (e.g., “project‑related PDFs”)

### Duplicate Detection

- Groups likely duplicates together so you can:
  - Keep the canonical copy
  - Move or archive older versions
  - Avoid accidental deletions

You always review suggestions before changes are applied. AI is there to assist, not override your decisions.

---

## 6. Keyboard Shortcuts & Power Tips

Forma supports rich keyboard navigation. Some common shortcuts:

- `⌘R` – Run or re‑scan the current source (from Xcode)
- Arrow keys / `⌥` + arrows – Move within the file list (varies by layout)
- Space – Quick Look preview (standard macOS behavior)
- `⌘A` – Select all files in the current view
- `⌘Z` – Undo last action

For the full, up‑to‑date list of shortcuts and gestures, see `Docs/Design/Forma-Keyboard-Shortcuts.md`.

Power tips:

- Use **filters + bulk actions** instead of moving files one by one
- Keep the **activity feed** visible when you’re trying new rules
- Start with narrow rules and widen them as you gain confidence

---

## 7. Troubleshooting & FAQs

For deep troubleshooting and developer‑level diagnostics, see the dedicated section in `SETUP.md`. This section focuses on quick fixes for common user issues.

### Files Aren’t Appearing in Forma

**Check:**
- Did you grant access to the correct folder during onboarding?
- Are you looking at the right source in the sidebar?

**Try:**
1. Click the **refresh** button (↻).
2. Use the **“All files”** filter to make sure nothing is hidden.
3. If still empty:
   - Reset permissions from within the app (or follow the reset steps in `SETUP.md`).

### I Moved Files but Can’t Find Them

**Check:**
- Open the **activity feed** and look at the last moves.
- Note the destination paths shown there.

**Try:**
1. Click on a file in the activity feed to reveal it in Finder (if available).
2. Use Spotlight (`⌘Space`) to search by filename.
3. If a rule sent files to an unexpected folder:
   - Adjust or disable that rule
   - Use **Undo** from the activity feed where possible

### I Keep Seeing “Wrong Folder Selected”

This usually means the folder you chose doesn’t match what Forma asked for.

**Fix:**
1. Read the dialog carefully (e.g., “Grant access to Documents”).
2. In the folder picker, select **that exact folder**:
   - Desktop → `~/Desktop`
   - Documents → `~/Documents`
   - Downloads → `~/Downloads`
   - Pictures → `~/Pictures`

If you selected the wrong folder previously, reset permissions and try again.

### Do I Have to Use AI Features?

No. You can:

- Turn off the **master AI toggle** in Settings to disable all AI‑driven suggestions.
- Keep using templates and rules manually without pattern learning or context detection.

Forma’s core rule engine and folder structure remain fully usable without AI.

---

## 8. Where to Go Next

If you want to:

- **Fine‑tune rules and automation**  
  → Read `Docs/API-Reference/USER_RULES_GUIDE.md`

- **Understand how the system is built**  
  → Read `Docs/Architecture/ARCHITECTURE.md`

- **Install, debug, or reset everything**  
  → Read `Docs/Getting-Started/SETUP.md`

- **Contribute to the project**  
  → Read `Docs/Development/DEVELOPER-ONBOARDING.md` and `Docs/Development/DEVELOPMENT.md`

---

## 9. Visual Assets: Recommended Screenshots & GIFs

To support this guide with visuals, capture the following assets and reference them from the relevant sections above.

### Onboarding Flow

- **Welcome Screen** – Initial “Welcome to Forma” view with key value props (Section 3).
- **Folder Setup** – Folder picker requesting Desktop and optional additional folders; highlight the “Grant Access” action and correct folder names.
- **Personality Quiz** – At least one screenshot per question plus the results view showing personality dimensions and recommended template.
- **Template Selection** – Template cards with one template pre‑selected based on quiz results.
- **Celebration Screen** – Final “You’re ready” / confetti screen with “Start Organizing” CTA.

### Dashboard & Everyday Use

- **Initial Dashboard After Onboarding** – Three‑panel layout with empty or lightly populated state.
- **Desktop Cleanup Workflow** – Before/after of Desktop source:
  - Files in “Unorganized” / “Needs attention” filter
  - Same view after applying suggestions/organize.
- **Downloads Workflow** – Filtered view of common downloads (PDFs, ZIPs, DMGs) with suggested destinations visible.
- **Rule Builder** – “Create rule” screen showing condition, destination, and example rule (e.g., invoice PDFs).
- **Project Cluster View** – A project cluster selected with related files listed and cluster details in the right panel.
- **Activity Feed** – Activity panel showing recent moves plus an available Undo action.

### Smart Features & Settings

- **Analytics Dashboard (Center)** – Storage breakdown, trends, and usage stats in the main view.
- **Opportunities Panel (Right)** – Recommendations list or "All optimized" state.
- **Settings → Smart Features** – Master AI toggle and per‑feature toggles to illustrate the feature flag hierarchy.
- **Settings → Templates** – Template management view, showing selection/edit options.

### Error States & Troubleshooting

- **Permission Error Banner** – “Permission denied” or “Wrong folder selected” UI state with guidance text.
- **Folder Picker Error Example** – Dialog where the user selected the wrong folder and Forma prompts to try again.

### Recommended GIFs

- **Full Onboarding Flow** – Welcome → Folder Setup → Quiz → Template → Celebration.
- **Desktop Cleanup Session** – Scan Desktop, review suggestions, run Organize, and show before/after.
- **Rule Creation & Application** – Create a rule, re‑scan, and apply moves based on that rule.
- **Project Cluster Exploration** – Open a cluster, view related files, and jump into destinations.

---

**Document Status:** First complete version of the end‑user guide.  
**Next Steps:** Capture and embed the screenshots/GIFs listed above into this guide and related design docs as they become available.
