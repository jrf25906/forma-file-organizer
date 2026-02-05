# Forma Pre-Launch Checklist
**Last Updated:** February 4, 2026

Use this file as the canonical “pre-launch” TODO since the Codex plan panel isn’t available in this app build.

---

## 1) Priorities + Acceptance Criteria (fill in)
- [x] Target App Store submission date: **February 16, 2026** (12 days from Feb 4, 2026)
- [x] Target version/build number: **1.0 (1)** *(matches Xcode `MARKETING_VERSION=1.0`, `CURRENT_PROJECT_VERSION=1`)*
- [x] Storefront(s) / locales: **Mac App Store (Worldwide)** + **direct download via website**; launch locale **English (U.S.)** (localize later)
- [x] Minimum macOS version: **macOS 15.0+** *(Xcode target versions jump from 15.x → 26.x; “25.x” isn’t a valid deployment target in this toolchain)*
- [ ] Screenshot set plan (5–10) + ordering: **5–10 (target 8)**; **light + dark**; final selection/order TBD (see draft below)
- [x] Preview video (yes/no): **Yes** *(target ~20–30s; confirm scope + script)*

**Draft screenshot storyboard (8)**
1. Hero main window (mixed “inbox” files; 6–10 items)
2. Preview queue (proposed destinations visible)
3. Rule builder (natural-language rule)
4. Undo history / activity log (reversibility)
5. Templates / starter rules (quick-start)
6. Menu bar dropdown (always-available + status)
7. “Before → After” organization result (folder structure)
8. Settings: Smart Features / Privacy / Rules (trust + control)

**Demo content guidelines**
- Use fictional, non-sensitive filenames; include variety (PDFs, images, screenshots, video, audio, docs, zips).
- Include a mix of “consumer” + “pro” naming (e.g., `Invoice_2026-01.pdf`, `IMG_1042.jpg`, `Lecture Notes - Week 3.pdf`, `Podcast Episode 12.wav`, `Project Brief v3.docx`).

---

## 2) Final App Icon + Menu Bar Icon Polish
**Assets**
- `Forma File Organizing/Assets.xcassets/AppIcon.appiconset`
- `Forma File Organizing/Assets.xcassets/MenuBarIcon.imageset`

**Acceptance criteria**
- [ ] App icon is crisp at 16/32/128/256/512/1024 and looks correct in Finder, Dock, Spotlight, and the About window.
- [ ] Menu bar icon is a true template icon (monochrome tint; alpha-only details OK), readable at small sizes, and looks good in light + dark mode.
- [ ] No clipping, fuzz, or inconsistent padding/alignment across sizes.

**Tasks**
- [x] Confirm final source artwork (SVG or 1024+ PNG) and lock the design: `forma-marketing-site/public/app-icon-1024.svg`
- [x] Replace AppIcon PNGs in `AppIcon.appiconset` (ensure filenames match `Contents.json`). *(Script: `Scripts/generate_app_icons.swift`)*
- [x] Validate the menu bar SVG is pixel-aligned and uses template rendering. *(Reverted to 3×3 gradient in `MenuBarIcon.imageset/menubar-icon.svg`)*

---

## 3) App Store Connect Assets (Screenshots / Video / Copy)
**Draft metadata**
- `Docs/Marketing/APP-STORE-DESCRIPTION-V2.md`

**Screenshot requirements**
- `Docs/Marketing/Screenshots/SCREENSHOT-REQUIREMENTS.md`

**Acceptance criteria**
- [ ] App Store Connect listing fields are final: name, subtitle, description, keywords, promo text, what’s new.
- [ ] Screenshots (5–10) are App Store-ready, consistent, and exist for light + dark mode (if doing both).
- [ ] Optional preview video exported and meets App Store Connect requirements (if included).

**Tasks**
- [ ] Finalize keywords/copy and confirm URLs (marketing/support/privacy).
- [ ] Capture screenshots (or generate via UI tests) into `Docs/Marketing/Screenshots/`.
- [ ] Optional: record + edit preview video.

**App Store screenshot tooling**
- UI test driver: `Forma File OrganizingUITests/AppStoreScreenshotTests.swift`
- One-command capture: `bash Scripts/capture_app_store_screenshots.sh` → outputs to `Docs/Marketing/Screenshots/AppStore/`
  - Upload-ready 2880×1800 set: `Docs/Marketing/Screenshots/AppStore/Upload/`

**Current generated set (review + decide final order / selection)**
- `Docs/Marketing/Screenshots/AppStore/Light/forma-01-hero-main-window.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-02-all-files-list.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-03-rule-builder.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-04-smart-rules.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-05-analytics.png`
- `Docs/Marketing/Screenshots/AppStore/Light/forma-06-settings.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-01-hero-main-window.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-02-all-files-list.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-03-rule-builder.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-04-smart-rules.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-05-analytics.png`
- `Docs/Marketing/Screenshots/AppStore/Dark/forma-06-settings.png`

**Preview video (macOS App Preview) draft plan**
- [ ] Decide the story (target **~20–30s**, max **30s**, 1920×1080).
- [ ] Record screen capture (hide personal info; use seeded demo data).
- [ ] Edit to a single clean sequence (fast cuts, no cursor jitter).
- [ ] Export final as `.mov` (H.264) into `Docs/Marketing/PreviewVideo/` (create folder).

---

## 4) Domain + Hosting Verification (Privacy / Terms)
**In-app references**
- `Forma File Organizing/Views/Settings/AboutSection.swift`

**Acceptance criteria**
- [ ] `https://formafiles.com/privacy` is live (200 OK) and matches App Store Connect metadata.
- [ ] `https://formafiles.com/terms` is live (200 OK).
- [ ] Redirect behavior (www/non-www, trailing slash) is intentional and stable.

**Tasks**
- [ ] Verify both URLs in a browser and via `curl -I` (from a non-restricted network).
- [ ] If URLs change, update `AboutSection.swift` and `Docs/Marketing/APP-STORE-DESCRIPTION-V2.md`.

---

## 5) Large-File-Set (1000+) Performance Validation + Accessibility Audit
**Acceptance criteria**
- [ ] Scanning + rendering 1000+ files is responsive (no obvious UI jank / beachballing).
- [ ] No runaway memory growth during large scans.
- [ ] Accessibility basics pass: labels, focus order, keyboard nav, contrast, VoiceOver sanity.

**Tasks (performance)**
- [ ] Create a deterministic 1000+ file fixture set (non-sensitive names).
- [ ] Validate: initial load time, scrolling, selection, search/filter, and “organize” flow on the fixture set.
- [ ] Run performance suite (`Forma File Organizing - Performance.xctestplan`) if applicable.
- [ ] Optional: Instruments pass (Time Profiler + Allocations) on worst-case flows.

**Tasks (accessibility)**
- [ ] Run Accessibility Inspector + VoiceOver smoke test across main flows.
- [ ] Verify all key controls have labels and appropriate accessibility traits.
- [ ] Verify keyboard navigation + focus order in main window and settings.

---

## 6) (Optional) Automate an App Store Screenshot Set via UI Tests
**Goal**
Generate an App Store-ready screenshot set (light/dark) into `Docs/Marketing/Screenshots/` from existing UI screenshot tests.

**Acceptance criteria**
- [ ] One command (or one UI test plan) produces a complete, correctly named screenshot set.
- [ ] Demo data is deterministic so screenshots don’t drift.
- [ ] Captures cover the required screens in `SCREENSHOT-REQUIREMENTS.md`.

**Tasks**
- [ ] Confirm the final list of screens + window sizes per App Store requirements.
- [ ] Add deterministic “demo data” mode for UI tests (seeded fixtures).
- [ ] Extend UI screenshot tests to export files with a stable naming convention (e.g., `forma-{screen}-{mode}.png`).
