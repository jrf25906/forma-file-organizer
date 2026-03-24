# Website Dark-Mode Hero And Workflow Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the website hero and "How Forma Works" section read correctly in dark mode while preserving the existing composition.

**Architecture:** Centralize the hero-window palette behind semantic tokens, define those token values at the theme layer in global CSS, and then apply a smaller section-level polish pass to the workflow section. Keep changes scoped to the marketing site and preserve current light-mode visuals.

**Tech Stack:** Next.js 16, React 19, TypeScript, Tailwind v4, global CSS custom properties

---

### Task 1: Document shared hero-window theme tokens

**Files:**
- Create: `forma-website/src/lib/hero-window-theme.ts`
- Modify: `forma-website/src/app/globals.css`

- [ ] Add a semantic token map for hero-window surfaces, labels, outlines, pills, and shadows.
- [ ] Define matching CSS custom properties for dark mode in `:root`.
- [ ] Define light-mode overrides in `[data-theme="light"]`.

### Task 2: Refactor the hero to consume shared tokens

**Files:**
- Modify: `forma-website/src/components/sections/FormaHeroWindow.tsx`

- [ ] Replace hardcoded light-only colors with the shared semantic token map.
- [ ] Preserve structure, spacing, and existing composition.
- [ ] Keep status/category colors legible in both themes.

### Task 3: Fix the "How Forma Works" dark-mode surface and hierarchy

**Files:**
- Modify: `forma-website/src/app/page.tsx`
- Modify: `forma-website/src/app/globals.css`

- [ ] Replace the pale translucent section surface with theme-aware section tokens.
- [ ] Tighten dark-mode spacing and visual hierarchy without changing layout or copy.
- [ ] Ensure the section still reads correctly in light mode.

### Task 4: Update release notes and verify

**Files:**
- Modify: `CHANGELOG.md`

- [ ] Add an unreleased note for the website dark-mode hero/workflow polish.
- [ ] Run `npm run lint` in `forma-website`.
- [ ] Run `npm run build` in `forma-website`.
