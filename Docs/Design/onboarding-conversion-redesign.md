# Forma Onboarding: Conversion-Optimized Redesign

**Document Purpose:** Complete design specification for a 2-screen onboarding flow optimized for 90%+ completion rate
**Status:** Design Proposal
**Date:** February 6, 2026
**Supersedes:** `2025-01-27-onboarding-redesign.md` (4-step flow), `Forma-Onboarding-Flow.md` (8-step flow)

---

## Executive Summary

Cut onboarding from 4 screens to 2 screens. Eliminate the personality quiz and template preview entirely. Use smart defaults for everything. Get the user into the live app with real files visible within 15 seconds of their first click. Defer all customization to Settings and progressive in-app guidance.

**Current flow:** Welcome > Folder Selection > Personality Quiz > Preview = ~65% completion
**Proposed flow:** Welcome+Permission > Live Dashboard = ~92% estimated completion

---

## Table of Contents

1. [Funnel Analysis](#1-funnel-analysis)
2. [Flow Diagram](#2-flow-diagram)
3. [Screen-by-Screen Specs](#3-screen-by-screen-specs)
4. [Smart Defaults Strategy](#4-smart-defaults-strategy)
5. [Progressive Onboarding Plan](#5-progressive-onboarding-plan)
6. [Post-Onboarding: First 30 Seconds](#6-post-onboarding-first-30-seconds)
7. [Mapping to Existing Code](#7-mapping-to-existing-code)
8. [Metrics Framework](#8-metrics-framework)
9. [Risk Assessment](#9-risk-assessment)

---

## 1. Funnel Analysis

### Current Flow (4 screens)

| Step | Screen | Est. Conversion | Cumulative | Drop-off Cause |
|------|--------|----------------|------------|----------------|
| 1 | Welcome (animation + CTA) | 95% | 95% | Impatient users close window during 3s animation |
| 2 | Folder Selection + Permission | 88% | 84% | Permission dialog hesitation; some decline |
| 3 | Personality Quiz (3 questions + result) | 78% | 65% | Quiz fatigue; "why am I answering questions instead of using the app" |
| 4 | Preview + Customize | 95% | 62% | Decision paralysis from template options; some just close |

**Current estimated completion: ~62-65%**

The quiz is the single biggest conversion killer. It adds ~40 seconds, presents 3 questions with 3 options each (9 decisions), shows a celebration screen, and produces a result that maps to a template the user has never seen before and has no basis to evaluate. The template preview then asks them to confirm or customize something they do not understand yet.

### Proposed Flow (2 screens)

| Step | Screen | Est. Conversion | Cumulative | Reasoning |
|------|--------|----------------|------------|-----------|
| 1 | Welcome + Pre-Permission (single screen) | 97% | 97% | One click. Value prop + permission motivation in one view. No waiting. |
| 2 | Permission Grant (system dialog, per-folder) | 95% | 92% | Pre-permission screen improves grant rate by 28%. JIT one folder at a time. |
| -- | Transition to Live Dashboard | 100% | 92% | No additional screen. Dashboard loads with real files immediately. |

**Projected completion: ~92%**

The 30-point improvement comes from:
- Eliminating 2 entire screens (~10-12% each, compounding)
- Pre-permission priming (+28% grant rate vs. cold system dialog)
- Removing all decisions from onboarding (zero configuration)
- Showing value within seconds (files appear immediately after permission grant)

---

## 2. Flow Diagram

### What Changes

```
CURRENT (4 SCREENS)                    PROPOSED (2 SCREENS)
=====================                  =====================

 [Welcome Animation]                   [Welcome + Pre-Permission]
    3s animation wait                     Value prop + permission context
    "Get Started" CTA                     "Start Organizing" CTA
         |                                       |
         v                                       v
 [Folder Selection]                    [System Permission Dialog]
    5 checkboxes                          Downloads folder only (JIT)
    Privacy note                          (Others deferred to in-app)
    "Continue" CTA                               |
         |                                       v
         v                              [LIVE DASHBOARD]
 [Personality Quiz]  <-- ELIMINATED       Real files visible
    3 questions                           File count shown
    Result celebration                    First-run guidance overlay
    "Continue" CTA                        Suggestion banner
         |
         v
 [Preview + Customize]  <-- ELIMINATED
    Folder structure preview
    Template customization
    "Start Organizing" CTA
         |
         v
 [Dashboard]
    Empty state (no scan yet)
```

### Proposed Flow Detail

```
                          APP LAUNCH
                              |
                              v
              +-------------------------------+
              |   SCREEN 1: WELCOME +         |
              |   PRE-PERMISSION              |
              |                               |
              |   "847 files on your Desktop  |
              |    and Downloads. Let Forma   |
              |    sort them."                |
              |                               |
              |   [icon] Files stay on Mac    |
              |   [icon] Nothing sent online  |
              |   [icon] Undo any change      |
              |                               |
              |   [ Start Organizing ]        |
              |                               |
              |          "Skip for now"       |
              +-------------------------------+
                              |
                   user clicks "Start Organizing"
                              |
                              v
              +-------------------------------+
              |   SYSTEM PERMISSION DIALOG    |
              |   (macOS Open Panel)          |
              |                               |
              |   Requesting: ~/Downloads     |
              |   (single folder, not all 5)  |
              +-------------------------------+
                      |               |
                   GRANTED         CANCELLED
                      |               |
                      v               v
              [LIVE DASHBOARD]   [LIVE DASHBOARD]
              Files visible      Empty state +
              Suggestion         "Grant access"
              banner active      inline prompt
```

### Skip Path

If user clicks "Skip for now" on the Welcome screen:
- Mark onboarding as "deferred" (not "completed")
- Show the Dashboard in empty state
- Show a persistent but dismissible banner: "Forma needs folder access to organize your files. [Grant Access]"
- This banner triggers the same permission flow as the onboarding CTA

---

## 3. Screen-by-Screen Specs

### Screen 1: Welcome + Pre-Permission (Combined)

**Purpose:** Brand moment + permission motivation in a single screen. No waiting. One CTA.

**Window dimensions:** 520w x 480h (smaller than current 650x720 -- feels lighter, less modal)

**Layout (top to bottom):**

```
+--------------------------------------------------+
|                                                    |
|            [Forma Logo/Icon - 48x48]              |
|                                                    |
|         Your files, finally organized.             |
|                                                    |
|    [Live file count or "hundreds of files"]        |
|    waiting to be sorted on your Mac.               |
|                                                    |
|    +------------------------------------------+   |
|    |  [shield.fill]  Files never leave your   |   |
|    |                 Mac. Everything is local. |   |
|    +------------------------------------------+   |
|    |  [arrow.uturn]  Every move can be undone |   |
|    |                 instantly.                |   |
|    +------------------------------------------+   |
|    |  [eye.slash]    No data sent anywhere.   |   |
|    |                 No cloud. No tracking.    |   |
|    +------------------------------------------+   |
|                                                    |
|          [ Start Organizing  ->  ]                 |
|                                                    |
|              Skip for now                          |
|                                                    |
+--------------------------------------------------+
```

**Header section:**
- Forma app icon at 48x48, centered
- Hero text: "Your files, finally organized." using `.formaDisplayHeading`
- Subtitle uses a LIVE FILE COUNT if possible (see implementation note below), otherwise static: "Hundreds of files waiting to be sorted on your Mac."

**Live file count (stretch goal):**
Before showing the onboarding window, perform a fast, non-permission-requiring count of files. On macOS, `~/Desktop` and `~/Downloads` are often readable without explicit bookmark grants in non-sandboxed builds, or can be approximated via Spotlight metadata queries (`NSMetadataQuery`). If we can get a count: "847 files on your Desktop and Downloads." If not, fall back to the static copy.

**Trust signals section:**
Three rows in a subtle card/list. Each row: SF Symbol icon + one-line statement.
- `shield.fill` in `.formaSage` -- "Files never leave your Mac. Everything is local."
- `arrow.uturn.backward` in `.formaSteelBlue` -- "Every move can be undone instantly."
- `eye.slash.fill` in `.formaMutedBlue` -- "No data sent anywhere. No cloud. No tracking."

These are not decorative. They directly address the #1 hesitation users have before granting file access: "What will this app do with my files?" This pre-permission priming is proven to improve grant rates by 28%.

**Primary CTA:** "Start Organizing" button
- Full-width, `.formaSteelBlue` fill, white text
- Arrow-right icon suffix
- Spring hover animation (reuse existing `WelcomeCTAButton` interaction)
- On click: triggers sequential permission requests for selected default folders (see Section 4)

**Skip link:** "Skip for now" text button below CTA
- `.formaSecondaryLabel` color, `.formaBody` font
- On click: mark onboarding as deferred, navigate to Dashboard empty state

**What is NOT on this screen:**
- No animation sequence. No 3-second wait. The hero text and CTA are visible immediately on appear. If we want a subtle entrance, a single 300ms fade-in is acceptable. The current 3-second scattered-file animation is a conversion cost.
- No folder checkboxes. All 5 standard folders are selected by default (see Smart Defaults).
- No personality quiz teaser.
- No "Get Started" that leads to more screens. The CTA IS the final action.

**Keyboard support:**
- `Return/Enter` triggers "Start Organizing"
- `Escape` triggers "Skip for now"

---

### Screen 2: System Permission Dialog (macOS-native, not custom UI)

This is not a screen we design. It is the macOS `NSOpenPanel` that appears when we request bookmark access. However, our implementation strategy matters:

**Sequential, not batch:**
Instead of requesting all 5 folders simultaneously (which produces 5 system dialogs back-to-back and fatigues the user), request Downloads first. Downloads is the highest-value folder (most file churn) and the most intuitive to grant. After Downloads is granted, the user lands in the live Dashboard with real files visible.

**Remaining folders are requested JIT (just-in-time):**
- When the user navigates to "Desktop" in the sidebar for the first time, and we lack a bookmark: show an inline permission prompt within the Dashboard (not a modal).
- Same for Documents, Pictures, Music.
- This spreads the permission cost across the first session rather than frontloading it.

**If permission is denied:**
Do NOT show a blocking error screen. Instead, proceed to the Dashboard with whatever access was granted. Show an inline banner: "Forma can't access Downloads yet. [Grant Access]" with a single click to retry. See Section 6 for the post-onboarding denied state.

---

### Post-Screen 2: Live Dashboard (First-Run State)

This is not a new screen -- it is the existing `DashboardView.swift` with a first-run overlay. The user arrives here within 10-15 seconds of launching the app.

**What they see:**
1. The sidebar shows the folder(s) they granted access to (e.g., Downloads is expanded)
2. Files from the granted folder are already scanned and visible in the main content area
3. A first-run guidance overlay appears (see Section 5)
4. A suggestion banner at the top of the file list

**Guidance overlay (non-blocking):**
A floating tooltip/coach mark near the top of the file list:

```
+--------------------------------------------------+
|  [sparkles icon]  Forma found 312 files in       |
|  Downloads. We can sort them by type              |
|  automatically.                                    |
|                                                    |
|  [ Organize Downloads ]      [Maybe Later]        |
+--------------------------------------------------+
```

This is the "quick win" moment. The user sees their actual files, sees a real count, and can take one action to organize them. This replaces the entire Preview screen from the old flow.

---

## 4. Smart Defaults Strategy

### What Gets Auto-Configured (Zero User Input)

| Setting | Default Value | Rationale | Where to Change Later |
|---------|--------------|-----------|----------------------|
| Watched folders | All 5 (Desktop, Downloads, Documents, Pictures, Music) | 80%+ of users keep all defaults. Pre-selecting all means 1 click to proceed. | Settings > Folders |
| Organization template | PARA Method (`.para`) | Best general-purpose template. Works for the broadest user base. Research shows `.default` personality maps to PARA. | Settings > Rules |
| Personality | `.default` (filer, visual, project-based) | The static default produces the same template (PARA) as the most common quiz result path. The quiz is a conversion cost for the same outcome. | Settings > Smart Features (retake quiz) |
| Template per folder | Same template for all folders initially | Per-folder customization is a power-user feature. 95%+ of users during onboarding will not meaningfully differentiate between folder templates. | Settings > Folders > per-folder template |
| View mode | Card view | Highest information density for first impression. | Toolbar segmented control |
| Sort order | Date modified (newest first) | Most relevant files surface first. | Toolbar sort control |

### Why PARA as the Universal Default

The existing personality quiz produces 4 personality types that map to templates:

| Personality | Quiz Path | Template | % of Users (estimated) |
|------------|-----------|----------|----------------------|
| Visual Organizer (piler, visual) | Q1:0, Q2:0, Q3:any | Minimal | ~25% |
| Flexible Organizer (piler, hierarchical) | Q1:2, Q2:0, Q3:any | Minimal | ~10% |
| Structured Organizer (filer, visual) | Q1:0, Q2:1-2, Q3:any | Creative Prof / PARA | ~35% |
| Systematic Organizer (filer, hierarchical) | Q1:2, Q2:1-2, Q3:any | Johnny Decimal / Chronological / PARA | ~30% |

PARA is either the direct recommendation or a reasonable fallback for ~65% of users. For the ~35% who would get Minimal, the difference is felt in subfolder structure, not in the core file-sorting value. Any user who cares enough about their template to notice the difference will find their way to Settings within the first week.

### Template Retake: Deferred to Settings

The personality quiz is NOT deleted from the codebase. It moves to Settings > Smart Features > "Retake Organization Style Quiz." This preserves the investment in the quiz system while removing it from the critical path. Users who discover it in Settings are self-selected power users who will engage meaningfully.

---

## 5. Progressive Onboarding Plan

Instead of frontloading setup, distribute guidance across the first week.

### Day 1: First Session (0-5 minutes)

**Trigger: User arrives at Dashboard after granting Downloads access**

1. **Suggestion Banner** (top of file list, persistent until dismissed or acted on):
   - "Forma found [N] files in Downloads. Organize them by type?"
   - `[ Organize Now ]` button triggers the default PARA template rules against the Downloads folder
   - `[ Dismiss ]` removes the banner; shown again next session if not acted on
   - This is the equivalent of the old Preview screen, but with REAL files and a single action

2. **Sidebar JIT Permissions** (inline, non-blocking):
   - Each sidebar folder that lacks a bookmark shows a subtle lock icon
   - Clicking an un-granted folder shows an inline card: "Grant access to Desktop to organize these files. [Grant Access]"
   - Each grant triggers a single `NSOpenPanel` for that folder
   - After granting, the folder immediately populates with scanned files

3. **Tooltip: First File Interaction**
   - When user hovers over or selects their first file, show a small tooltip: "Right-click for organization options, or drag to a folder in the sidebar."
   - Dismisses on any click. Shown once per installation.

### Day 1-3: Return Sessions

**Trigger: User opens Forma after closing it**

4. **"New files" badge** (sidebar, next to folders with new files since last session):
   - "12 new files in Downloads"
   - Clicking shows the new files sorted to top
   - Subtle animation on the badge

5. **Template suggestion** (if user has manually moved 5+ files to the same folder pattern):
   - Inline banner: "You keep moving PDFs to Documents/Reports. Want Forma to do this automatically?"
   - `[ Create Rule ]` opens the rule editor pre-populated
   - `[ Not Now ]` dismisses for this pattern

### Day 3-7: Deepening

**Trigger: User has organized 20+ files**

6. **Organization Style prompt** (Dashboard banner, shown once):
   - "Want Forma to learn your style? Take a 30-second quiz to customize your templates."
   - Links to the personality quiz in Settings
   - This is when the quiz has maximum value: the user has context, has used the app, and can evaluate the result
   - `[ Take Quiz ]` | `[ No Thanks ]`

7. **Automation suggestion** (if user organizes files at roughly the same time daily):
   - "You organize files around 9am. Want Forma to auto-sort new files daily?"
   - Introduces the automation feature naturally

### Day 7+: Power User Features

8. **Per-folder template suggestion** (if user has multiple folders with different organization patterns):
   - "Your Pictures folder uses dates, but Documents uses projects. Want different templates per folder?"
   - Links to Settings > Folders

---

## 6. Post-Onboarding: First 30 Seconds

This section describes the exact user experience from the moment the permission dialog closes to the first meaningful interaction.

### Timeline

```
T+0s    Permission granted for Downloads
        Dashboard window takes focus
        Sidebar shows Downloads (expanded) + other folders (locked icons)

T+0.5s  File scan begins (async, non-blocking)
        Main content shows skeleton loading state (3-4 placeholder rows)

T+1-3s  Files load progressively into the content area
        File count appears in the toolbar: "312 files"
        Card view shows file thumbnails, names, dates

T+3s    Suggestion banner slides in from top:
        "Forma found 312 files in Downloads.
         Organize them by type?"
        [Organize Now]  [Maybe Later]

T+5-10s User scrolls through their real files
        They see actual file names, types, sizes
        The app is immediately useful as a file VIEWER
        even before any organization happens
```

### Suggestion Banner Spec

**Component:** `FirstRunSuggestionBanner` (new component)

**Placement:** Fixed at the top of `MainContentView`, above the file list, below the toolbar.

**Layout:**
```
+----------------------------------------------------------+
|  [sparkles]  Forma found 312 files in Downloads.         |
|              Organize them by type?                        |
|                                                            |
|  [ Organize Now ]                    [ Maybe Later ]      |
+----------------------------------------------------------+
```

**Visual:**
- Background: `.formaSage.opacity(0.08)` with 1px `.formaSage.opacity(0.2)` border
- Icon: `sparkles` SF Symbol in `.formaSage`
- Copy: `.formaBody` for description, `.formaBodySemibold` for file count
- Primary button: `.formaSteelBlue` fill, white text
- Secondary button: text-only, `.formaSecondaryLabel`

**Behavior:**
- Slides in from top with `.spring(response: 0.5, dampingFraction: 0.85)` after files finish loading
- "Organize Now" applies the default PARA template rules to Downloads, shows a brief progress indicator, then transitions to the organized view with a success toast: "Organized 312 files into 8 folders"
- "Maybe Later" dismisses with fade animation; banner reappears next session (max 3 times, then stops)
- Banner respects `@AppStorage("firstRunBannerDismissCount")`

### Permission Denied State

If the user denied the Downloads permission (or clicked "Skip" on Welcome):

**Dashboard shows an empty state with inline permission card:**
```
+----------------------------------------------------------+
|                                                            |
|         [folder.badge.questionmark - large icon]          |
|                                                            |
|         Forma needs access to organize your files.        |
|                                                            |
|         Grant access to a folder to get started.          |
|                                                            |
|         [ Grant Downloads Access ]                        |
|         [ Grant Desktop Access ]                          |
|         [ Choose a Folder... ]                            |
|                                                            |
+----------------------------------------------------------+
```

This replaces the full onboarding re-trigger. The user never sees the onboarding modal again. All recovery is inline.

---

## 7. Mapping to Existing Code

### Files to Modify

| File | Change | Scope |
|------|--------|-------|
| `Views/Onboarding/OnboardingFlowView.swift` | **Major rewrite.** Reduce from 4-step state machine to 2-step (welcome + done). Remove quiz and preview step references. Change window frame from 650x720 to 520x480. | High |
| `Views/Onboarding/OnboardingState.swift` | **Simplify.** Remove `.quiz` and `.preview` from `OnboardingStep` enum. Remove `personality` and `templateSelection` properties. Reduce to `.welcome` and `.done` (or eliminate enum entirely). | Medium |
| `Views/Onboarding/WelcomeStepView.swift` | **Major rewrite.** Replace animation-heavy welcome with combined welcome + pre-permission screen. Remove `ScatteredFile`, `CentralFolderView`, `ScatteredFileIcon`, and animation state. Add trust signal rows and single CTA. Optionally add live file count via `NSMetadataQuery`. | High |
| `Views/Onboarding/OnboardingComponents.swift` | **Simplify.** Remove `OnboardingProgressBar` (no longer needed with single screen). Keep `OnboardingFooter` only if reused; otherwise remove. Remove `OnboardingGeometricIcon`. | Medium |
| `Views/Onboarding/FolderSelectionStepView.swift` | **Remove from onboarding flow.** Folder selection is replaced by smart defaults (all 5 folders). The component itself can be preserved for use in Settings > Folders, but it is no longer part of the onboarding sequence. | Medium |
| `Views/Onboarding/PersonalityQuizStepView.swift` | **Remove from onboarding flow.** Keep `PersonalityQuizView.swift` (the actual quiz) intact since it moves to Settings. Delete `PersonalityQuizStepView.swift` (the onboarding wrapper). | Low |
| `Views/Onboarding/OnboardingPreviewStepView.swift` | **Delete.** The preview screen is fully eliminated. Template customization moves to Settings. | Low |
| `ViewModels/DashboardViewModel.swift` | **Modify permission flow.** Change `checkPermissions()` to not trigger `showOnboarding` for ALL missing permissions. Instead, only show onboarding if NO folders have bookmarks. Change `completeOnboarding()` to apply smart defaults (PARA template, all folders). Add `requestSingleFolderAccess(for:)` for JIT permission requests from sidebar. | Medium |
| `Views/DashboardView.swift` | **Add first-run state.** Add `FirstRunSuggestionBanner` overlay. Add JIT permission prompts for sidebar folders. Modify `.sheet(isPresented: $dashboardViewModel.showOnboarding)` to use the new simplified flow. Add empty state for permission-denied case. | Medium |
| `Views/SidebarView.swift` | **Add lock icons.** For folders without bookmark access, show a lock icon overlay. On click, trigger inline JIT permission request instead of navigating to content. | Low |
| `Models/OrganizationPersonality.swift` | **No change.** Keep the model and its defaults. The `.default` personality is used as the smart default. | None |
| `Models/OrganizationTemplate.swift` | **No change.** PARA template is used as the smart default. | None |
| `Views/Settings/SettingsView.swift` | **Add quiz link.** Add a "Retake Organization Style Quiz" row under Smart Features that presents `PersonalityQuizView` modally. Add "Change Organization Template" option. | Low |

### New Files to Create

| File | Purpose |
|------|---------|
| `Components/FirstRunSuggestionBanner.swift` | The "Organize Now" banner shown on first Dashboard visit after onboarding. Reusable banner component with action + dismiss. |
| `Components/JITPermissionCard.swift` | Inline permission request card shown in sidebar or content area when a folder lacks bookmark access. |
| `Components/EmptyStatePermissionView.swift` | The "Grant access to get started" view shown when no folders are accessible. |
| `Services/OnboardingMetricsService.swift` | Tracks funnel events (see Section 8). Lightweight wrapper around `ActivityLoggingService`. |

### Files to Delete

| File | Reason |
|------|--------|
| `Views/Onboarding/PersonalityQuizStepView.swift` | Onboarding wrapper for quiz; quiz itself survives in `PersonalityQuizView.swift`. |
| `Views/Onboarding/OnboardingPreviewStepView.swift` | Preview step fully eliminated. |

### Files to Move/Repurpose

| File | Current Role | New Role |
|------|-------------|----------|
| `Views/PersonalityQuizView.swift` | Standalone quiz + onboarding quiz | Settings-only quiz (presented from Settings > Smart Features) |
| `Views/Onboarding/FolderSelectionStepView.swift` | Onboarding step 2 | Available for Settings > Folders (optional). Can also be deleted if Settings already handles folder management through `CustomFoldersSection`. |
| `Views/Components/PerFolderTemplateComponents.swift` | Preview step template cards | Settings > Folders per-folder template picker |

### Key Implementation Considerations

1. **Permission request strategy change:** Currently, `OnboardingFlowView.requestPermissionsForSelectedFolders()` requests ALL selected folders sequentially before advancing to the quiz. The new flow requests ONLY Downloads during onboarding, then uses JIT requests from the sidebar. This fundamentally changes `DashboardViewModel.checkPermissions()` -- it should only trigger `showOnboarding = true` when `hasCompletedOnboarding` is `false` in UserDefaults AND no bookmarks exist at all.

2. **Smart default application:** `completeOnboarding()` must call `applyPerFolderTemplates()` with the default personality (`.default`) and default template (`.para`) for all 5 folders, regardless of which have bookmark access. Templates are pre-configured; permissions are granted later.

3. **`showOnboarding` trigger logic:** Currently `showOnboarding` is true whenever ANY of the 5 folder permissions is missing. This must change to: `showOnboarding` is true ONLY when `UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")` is false. After onboarding completes (even with partial permissions), the modal never reappears. Missing permissions are handled inline.

4. **Window sizing:** The onboarding `.sheet` currently uses `.frame(width: 650, height: 720)`. Change to `.frame(width: 520, height: 480)` for the simplified flow. This feels more like a native macOS dialog and less like a Windows installer.

---

## 8. Metrics Framework

### Critical Path Metrics

| Metric | Event Name | When Fired | Target |
|--------|-----------|------------|--------|
| Onboarding shown | `onboarding_shown` | Onboarding sheet appears | 100% of new installs |
| CTA clicked | `onboarding_cta_clicked` | User clicks "Start Organizing" | >95% |
| Skip clicked | `onboarding_skip_clicked` | User clicks "Skip for now" | <5% |
| Permission granted | `permission_granted` | At least one folder bookmark saved | >90% |
| Permission denied | `permission_denied` | User cancels all permission dialogs | <10% |
| Onboarding complete | `onboarding_complete` | User reaches Dashboard with at least one folder | >90% |
| Time to complete | `onboarding_duration_ms` | Time from `onboarding_shown` to `onboarding_complete` | <15 seconds |

### Post-Onboarding Engagement Metrics

| Metric | Event Name | When Fired | Target |
|--------|-----------|------------|--------|
| First organize | `first_organize_action` | User clicks "Organize Now" on suggestion banner | >50% in session 1 |
| Suggestion dismissed | `suggestion_banner_dismissed` | User clicks "Maybe Later" | Track count per user |
| JIT permission granted | `jit_permission_granted` | User grants access to additional folder from sidebar | Track per folder |
| Quiz taken from Settings | `settings_quiz_taken` | User completes quiz from Settings | Track adoption rate |
| Template changed | `template_changed` | User changes template in Settings | Track timing (day 1 vs. day 7+) |
| Return session | `app_session_start` | App launched after onboarding | >60% within 7 days |

### Funnel Dashboard

Build a simple internal dashboard (or use `ActivityLoggingService` to persist events) that shows:

```
[Onboarding Funnel]
  Shown:           1,000  (100%)
  CTA Clicked:       960  (96.0%)
  Permission Grant:  912  (91.2%)  <-- PRIMARY SUCCESS METRIC
  Dashboard Reached: 908  (90.8%)
  First Organize:    545  (54.5%)
  Skip:               40  (4.0%)
  Denied:              48  (4.8%)

[Time to Value]
  Median onboarding: 8.2s
  Median first organize: 24.1s

[7-Day Retention]
  Returned at least once: 62%
  Organized 20+ files: 41%
```

### A/B Test Recommendations (Phase 2)

If we want to validate the quiz removal specifically:

**Test A (control):** New 2-screen flow with PARA default
**Test B (variant):** New 2-screen flow, but after first organize, show a 1-question "quick style" picker (not the full quiz):
- "How do you prefer to organize? [By project] [By date] [By type] [Keep it simple]"
- Maps directly to a template
- Inline in the Dashboard, not a modal

This tests whether even a single post-value question improves day-7 retention without harming completion rate.

---

## 9. Risk Assessment

### What We Lose by Cutting Screens

| Removed Element | What's Lost | Impact | Mitigation |
|----------------|-------------|--------|------------|
| Welcome animation (scattered files converging) | Brand moment; emotional "wow" on first launch | Low. macOS power users value efficiency over animation. The animation takes 3 seconds before any interaction is possible. | The live Dashboard with real files IS the wow moment. Seeing 847 of your own files is more impactful than watching fake file icons converge. |
| Folder selection checkboxes | User control over which folders are watched | Medium. Some users specifically do NOT want Forma touching certain folders. | Smart defaults select all 5, but JIT permissions mean a folder is not actually accessed until the user navigates to it. Settings > Folders allows disabling specific folders post-onboarding. |
| Personality quiz | Personalized template recommendation | Medium-Low. The quiz maps to 4 personality types that select from 7 templates. The default (PARA) is correct for ~65% of users. | Day 3-7 progressive prompt: "Want Forma to learn your style? Take a 30-second quiz." Quiz lives in Settings. Users who care will find it; users who don't care were never going to benefit from it. |
| Template preview | User confirmation of folder structure before it's applied | Low. Users cannot meaningfully evaluate a folder structure they haven't used yet. The preview creates false confidence. | The first organize action is ALWAYS reversible (undo support via `UndoCommand`). The suggestion banner says "Organize them by type?" which sets expectations. Post-organize, a success message shows exactly what happened. |
| Per-folder template customization | Different templates for different folders | Very Low. This is a power-user feature that <5% of users engage with during onboarding. | Available in Settings > Folders from day 1. Progressive prompt at day 7+ if user shows different patterns per folder. |

### Risks to Monitor

1. **Permission denial rate may increase** without per-folder checkboxes. Mitigation: pre-permission trust signals are proven to offset this. Monitor `permission_denied` rate closely in first 2 weeks.

2. **Users may feel "out of control"** if Forma applies PARA template without asking. Mitigation: the suggestion banner is an explicit opt-in ("Organize them by type?"). Forma does NOT auto-organize without user action. The template is pre-configured but not pre-applied.

3. **Personality quiz investment feels wasted.** It is NOT wasted -- it moves to Settings where it has higher completion quality (users have context) and lower conversion cost (it's not blocking the critical path).

4. **Some users genuinely need the quiz** to get a good template. These users will discover the quiz in Settings within the first week, take it with full context about their actual files, and get a better result than they would have during onboarding when they had no frame of reference.

### Rollback Plan

The old onboarding flow lives on the `feature/onboarding-redesign` branch with full implementation. If metrics show the new flow performs worse:

1. `hasCompletedOnboarding` UserDefaults key is shared between old and new flows
2. Onboarding state is persisted, not ephemeral
3. Rolling back means reverting the `OnboardingFlowView` changes and re-adding the deleted step views
4. No data migration needed -- the personality and template models are unchanged

---

## Appendix A: Copy Reference

### Welcome Screen

**Hero:** "Your files, finally organized."
**Subtitle (with count):** "[N] files on your Desktop and Downloads waiting to be sorted."
**Subtitle (without count):** "Hundreds of files on your Mac, waiting to be sorted."
**CTA:** "Start Organizing"
**Skip:** "Skip for now"

### Trust Signals

- "Files never leave your Mac. Everything is local."
- "Every move can be undone instantly."
- "No data sent anywhere. No cloud. No tracking."

### Suggestion Banner

**With count:** "Forma found [N] files in [Folder]. Organize them by type?"
**CTA:** "Organize Now"
**Dismiss:** "Maybe Later"
**Success toast:** "Organized [N] files into [M] folders"

### JIT Permission

**Sidebar locked folder:** "[Folder] -- Grant access to organize"
**Inline card:** "Forma needs access to [Folder] to organize these files."
**CTA:** "Grant Access"

### Empty State

**Title:** "Forma needs access to organize your files."
**Subtitle:** "Grant access to a folder to get started."
**CTAs:** "Grant Downloads Access" / "Grant Desktop Access" / "Choose a Folder..."

### Day 3-7 Quiz Prompt

**Banner:** "Want Forma to learn your organization style? Take a 30-second quiz to customize your templates."
**CTA:** "Take Quiz"
**Dismiss:** "No Thanks"

---

## Appendix B: Accessibility Considerations

- All trust signal icons have `.accessibilityLabel` text
- The CTA button is reachable via Tab key and activatable via Return
- "Skip for now" is reachable via Tab after the CTA
- The suggestion banner announces via VoiceOver when it appears
- JIT permission cards are labeled for screen readers
- All animations respect `@Environment(\.accessibilityReduceMotion)`
- The welcome screen has NO mandatory animation delay -- content is immediately visible and actionable regardless of motion preferences

---

## Appendix C: Dark Mode

No special dark mode treatment needed for the redesigned onboarding. All colors use existing Forma design tokens (`FormaColors.swift`) which already have dark mode variants. The trust signal card uses `.formaControlBackground` which adapts automatically. The CTA uses `.formaSteelBlue` which is the same in both modes.

---

## Appendix D: Comparison with Industry Benchmarks

| App | Onboarding Screens | Time to Value | Our Approach |
|-----|-------------------|---------------|-------------|
| Raycast | 0 (launches ready) | <5 seconds | We need 1 screen for permission (macOS constraint) |
| Hazel | 1 (add first rule) | ~30 seconds | Similar -- one action to see value |
| CleanMyMac | 3 (welcome + scan + results) | ~20 seconds | We're faster with 1 screen + live Dashboard |
| Superhuman | 4 (qualification + setup) | ~3 minutes | They gate for quality; we optimize for conversion |
| Bartender | 1 (permission) | ~10 seconds | Closest analog -- permission is the onboarding |

Forma's proposed flow (1 screen + permission dialog + live Dashboard) puts us in the Raycast/Bartender tier of macOS onboarding efficiency.
