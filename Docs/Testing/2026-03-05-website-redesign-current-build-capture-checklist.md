# Forma Website Redesign Current-Build Capture Checklist

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Marketing

Use this checklist to capture baseline evidence for the current marketing site before redesign implementation changes the page structure. This is the operational companion to the validation plan in `Docs/Testing/2026-03-05-website-redesign-validation-plan.md`.

## 1. Scope

- Base URL: `http://localhost:3000`
- App to run: `forma-website`
- Validation mode: light mode only
- Required routes:
  - `/`
  - `/blog`
  - `/blog/organize-mac-files`
  - `/support`
  - `/get-forma`
  - `/for-agents`

### Why `/blog/organize-mac-files`

- It is the broadest evergreen guide in `forma-website/src/content/blog/`.
- It is linked from the homepage and support page.
- It is a better canonical article route for baseline capture than a narrower post.

## 2. Preflight

- Start the site from `forma-website` with `npm run dev`.
- Use one browser for the full pass.
- Set browser zoom to `100%`.
- Use light mode only.
- Close extension sidebars and anything that changes page width.
- Record the branch name and commit SHA before capture.
- If the dev server hot reloads mid-capture, restart the pass for that route.

## 3. Viewport Set

| Label | Width | Height | Purpose |
| --- | --- | --- | --- |
| Mobile | `390` | `844` | Small-screen first impression and CTA visibility |
| Tablet | `768` | `1024` | Mid-width layout integrity |
| Laptop | `1280` | `900` | Common desktop browsing size |
| Desktop | `1440` | `900` | Primary review width for the homepage scroll |

## 4. Artifact Naming and Storage

Use one evidence root for the baseline pass:

- Suggested root: `Docs/Testing/Artifacts/website-redesign/2026-03-05-current-build/`

Use these file-name patterns:

- Screenshots: `{route}--{surface}--{width}.png`
- Desktop scroll recording: `home--scroll--desktop-1440.mp4`
- Mobile scroll recording: `home--scroll--mobile-390.mp4`
- Findings log: `website-redesign--first-pass-findings.md`

### Route labels

- Homepage: `home`
- Blog index: `blog-index`
- Blog article: `blog-organize-mac-files`
- Support: `support`
- Get Forma: `get-forma`
- For agents: `for-agents`

## 5. Homepage Still Captures

All homepage screenshots should be taken from `/`.

| Capture ID | Surface | Widths | File stem | What must be visible | Source reference |
| --- | --- | --- | --- | --- | --- |
| `HOME-01` | Header + hero | `390`, `768`, `1280`, `1440` | `home--hero` | Global header, eyebrow, headline, both hero CTAs, price meta, and enough of the Mac preview to show context | `forma-website/src/app/layout.tsx`, `forma-website/src/components/Header.tsx`, `forma-website/src/app/page.tsx` |
| `HOME-02` | Trust line | `390`, `768`, `1280`, `1440` | `home--trust-line` | Entire trust strip directly after the hero | `forma-website/src/app/page.tsx` |
| `HOME-03` | Features intro / rules block | `390`, `768`, `1280`, `1440` | `home--features-rules` | `Features` section label, rules headline, and example rule rows | `forma-website/src/app/page.tsx` |
| `HOME-04` | Grouping + preview cards | `390`, `768`, `1280`, `1440` | `home--features-proof-cards` | Grouping card and preview card together if possible; otherwise capture the preview card cleanly | `forma-website/src/app/page.tsx` |
| `HOME-05` | Undo strip | `390`, `768`, `1280`, `1440` | `home--undo-strip` | Undo headline, supporting copy, and chips | `forma-website/src/app/page.tsx` |
| `HOME-06` | Before / after + mid-page CTA | `390`, `768`, `1280`, `1440` | `home--before-after` | Before card, after card, and the `Ready to clean up?` CTA block | `forma-website/src/app/page.tsx` |
| `HOME-07` | Pricing | `390`, `768`, `1280`, `1440` | `home--pricing` | Pricing label, `$29`, pricing body, primary CTA, and macOS requirement text | `forma-website/src/app/page.tsx` |
| `HOME-08` | Footer | `390`, `768`, `1280`, `1440` | `home--footer` | Footer brand lockup, product links, guide links, legal links, and support email | `forma-website/src/app/page.tsx` |
| `HOME-09` | Header after scroll | `390`, `768`, `1280`, `1440` | `home--header-after-scroll` | Whatever the header does after the page has scrolled | `forma-website/src/components/Header.tsx` |

### Note on `HOME-09`

- The current build does not implement a distinct compact or sticky header state.
- If the header scrolls out of view or remains unchanged, mark the capture `N/A` and note that explicitly in the findings log.

## 6. Route Snapshot Captures

| Capture ID | Route | Widths | File stem | What must be visible | Source reference |
| --- | --- | --- | --- | --- | --- |
| `ROUTE-01` | `/blog` | `390`, `768`, `1280`, `1440` | `blog-index--hero-and-list` | Header, page intro, first visible cards, and inline CTA block if visible | `forma-website/src/app/blog/page.tsx` |
| `ROUTE-02` | `/blog/organize-mac-files` | `390`, `768`, `1280`, `1440` | `blog-organize-mac-files--hero-and-cta` | Header, article title block, and inline CTA block if it fits in one frame; otherwise prioritize the title block | `forma-website/src/app/blog/[slug]/page.tsx` |
| `ROUTE-03` | `/support` | `390`, `768`, `1280`, `1440` | `support--hero-and-actions` | Header, support intro, contact section, and quick-fix block opening | `forma-website/src/app/support/page.tsx` |
| `ROUTE-04` | `/get-forma` | `390`, `768`, `1280`, `1440` | `get-forma--hero-and-actions` | Header, page intro, App Store CTA, and support CTA | `forma-website/src/app/get-forma/page.tsx` |
| `ROUTE-05` | `/for-agents` | `390`, `768`, `1280`, `1440` | `for-agents--hero-and-table` | Header, page intro, and top of endpoint catalog table | `forma-website/src/app/for-agents/page.tsx` |

## 7. Scroll Recordings

### Desktop

- Route: `/`
- Viewport: `1440 x 900`
- File name: `home--scroll--desktop-1440.mp4`
- Recording steps:
  - Open the homepage at the top.
  - Pause for 2 seconds on the header + hero.
  - Scroll to the footer in 15-20 seconds.
  - Pause briefly on features, before / after, and pricing.
  - If any hover treatment materially changes comprehension, include one hover.

### Mobile

- Route: `/`
- Viewport: `390 x 844`
- File name: `home--scroll--mobile-390.mp4`
- Recording steps:
  - Open the homepage at the top.
  - Pause for 2 seconds on the header + hero.
  - Scroll to the footer in 18-25 seconds.
  - Pause briefly on features, before / after, and pricing.

## 8. Current-Build Watchpoints

These are not findings yet. They are the high-risk areas to verify while capturing the current build.

- The hero uses a real screenshot, but the screenshot is not annotated and may require too much interpretation.
- The trust line is present, but it may not count as real proof.
- The homepage features section uses stylized fragments instead of a real workflow sequence.
- The before / after section is text-only and may not prove transformation strongly enough.
- `/support` and `/get-forma` use hard-coded color values rather than the tokenized route treatment seen on `/blog` and `/for-agents`.
- `/support` and `/get-forma` are structurally simpler than the homepage and may feel like a different product shell.
- `/for-agents` needs explicit small-screen table usability review at `390`.

## 9. Completion Checklist

- [ ] Branch name and commit SHA recorded
- [ ] All homepage still captures completed at `390`, `768`, `1280`, `1440`
- [ ] All route captures completed at `390`, `768`, `1280`, `1440`
- [ ] Desktop homepage scroll recording captured
- [ ] Mobile homepage scroll recording captured
- [ ] `HOME-09` marked captured or `N/A` with reason
- [ ] Evidence root populated with consistent file names
- [ ] Findings log initialized from the first-pass template
