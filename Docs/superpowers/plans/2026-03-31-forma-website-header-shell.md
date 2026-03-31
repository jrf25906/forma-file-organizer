# Forma Website Header Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the marketing-site header float over the hero as one composed first viewport instead of rendering as a full-width bar above it.

**Architecture:** Keep the existing header information architecture and mobile sheet behavior, but move the visual weight into the inner shell card and make the outer header wrapper non-segmenting. Pair that header change with a hero spacing adjustment in `page.tsx` so the fixed or sticky floating shell does not collide with the headline or push the product window out of balance.

**Tech Stack:** Next.js 16, React 19, TypeScript, Tailwind v4, shadcn/ui sheet primitives, Vitest

---

## File Map

- `forma-website/src/components/Header.tsx`
  - owns the header wrapper, shell positioning, nav pill, CTA, and mobile sheet trigger
- `forma-website/src/app/page.tsx`
  - owns the hero section spacing and first-viewport composition
- `forma-website/tests/header-shell.test.tsx`
  - new regression coverage for the floating-header contract
- `forma-website/tests/home-page-shell-boundary.test.tsx`
  - existing homepage shell-boundary regression seam; extend it for hero/header spacing
- `CHANGELOG.md`
  - note the floating header-shell behavior change
- `API_REFERENCE.md`
  - keep the website-shell behavior summary aligned with the new header treatment
- `TODO.md`
  - only update if verification reveals a concrete follow-up rather than speculative polish

### Task 1: Lock the floating-header regression seam before changing layout

**Files:**
- Create: `forma-website/tests/header-shell.test.tsx`
- Modify: `forma-website/src/components/Header.tsx`
- Reuse: `forma-website/tests/home-page-shell-boundary.test.tsx`

- [ ] **Step 1: Write the failing header-shell regression test**

Create `forma-website/tests/header-shell.test.tsx` with a narrow static-markup contract for the header:

```tsx
import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import { Header } from "../src/components/Header"

describe("Header", () => {
  it("renders as a floating shell instead of a full-width top bar", () => {
    const html = renderToStaticMarkup(<Header />)

    expect(html).toContain('data-header-shell="floating"')
    expect(html).toContain("pointer-events-none")
    expect(html).toContain("pointer-events-auto")
    expect(html).not.toContain("border-b border-[var(--shell-border)] bg-[var(--bg-primary)]")
  })
})
```

- [ ] **Step 2: Extend the existing homepage boundary test with hero-offset coverage**

Add one assertion to `forma-website/tests/home-page-shell-boundary.test.tsx` so the hero section advertises the new overlay relationship:

```tsx
expect(heroSection).toContain('data-hero-layout="header-overlay"')
```

- [ ] **Step 3: Run the targeted tests to verify they fail**

Run:

```bash
cd forma-website && npm test -- tests/header-shell.test.tsx tests/home-page-shell-boundary.test.tsx
```

Expected:

- `header-shell.test.tsx` fails because `Header.tsx` does not yet expose a floating-shell marker and still includes the full-width bar treatment
- `home-page-shell-boundary.test.tsx` fails because the hero does not yet expose the overlay marker

- [ ] **Step 4: Commit the failing-test checkpoint**

```bash
git add "forma-website/tests/header-shell.test.tsx" "forma-website/tests/home-page-shell-boundary.test.tsx"
git commit -m "test: capture floating header shell contract"
```

### Task 2: Convert the header from a top bar into a floating shell

**Files:**
- Modify: `forma-website/src/components/Header.tsx`
- Reuse: `forma-website/src/components/ui/forma-shell-card.tsx`
- Reuse: `forma-website/src/components/ui/forma-shell-cta.tsx`

- [ ] **Step 1: Make the outer header wrapper transparent and overlay-oriented**

Update `Header.tsx` so the top-level wrapper becomes a non-segmenting shell host instead of a page band. The implementation should end up shaped like this:

```tsx
<header
  role="banner"
  data-header-shell="floating"
  className="pointer-events-none fixed inset-x-0 top-0 z-50"
>
  <div className="site-container pointer-events-auto pt-4 md:pt-5">
    <FormaShellCard className="flex h-[72px] items-center justify-between gap-3 px-4 md:px-5">
      ...
    </FormaShellCard>
  </div>
</header>
```

Constraints:

- do not reintroduce a full-width background or bottom border on the outer wrapper
- keep the existing logo, nav links, CTA, and sheet trigger structure intact
- preserve `role="banner"` and current accessible names

- [ ] **Step 2: Keep the shell light instead of scroll-reactive-heavy**

Use shell-surface, highlight, blur, and border treatment on the `FormaShellCard` itself rather than introducing a second scroll-state system. Small polish additions are acceptable if they remain subtle, for example:

```tsx
className="... bg-[color-mix(in_srgb,var(--shell-surface)_88%,transparent)] backdrop-blur-xl supports-[backdrop-filter]:bg-[color-mix(in_srgb,var(--shell-surface)_82%,transparent)]"
```

Do not add:

- color-flip on scroll
- dramatic height shrink
- solid opaque header fallback as the default state

- [ ] **Step 3: Re-run the targeted header tests**

Run:

```bash
cd forma-website && npm test -- tests/header-shell.test.tsx tests/home-page-shell-boundary.test.tsx
```

Expected: the new header-shell test passes, while the home-page shell test may still fail until the hero offset lands.

- [ ] **Step 4: Commit the header-shell layout change**

```bash
git add "forma-website/src/components/Header.tsx" "forma-website/tests/header-shell.test.tsx"
git commit -m "feat: float website header shell"
```

### Task 3: Retune the hero so the floating shell and first viewport read as one composition

**Files:**
- Modify: `forma-website/src/app/page.tsx`
- Modify: `forma-website/tests/home-page-shell-boundary.test.tsx`

- [ ] **Step 1: Change the hero section to declare the overlay layout**

Add a stable marker on the hero section:

```tsx
<section
  id="top"
  data-hero-layout="header-overlay"
  className="relative overflow-hidden border-b border-[var(--shell-border)] bg-transparent"
>
```

- [ ] **Step 2: Increase hero top spacing to pay for the overlaid shell**

Change the `HeroEntrance` spacing in `page.tsx` so the headline and product window start below the floating header while still fitting within common laptop viewports. The final class list should follow this shape:

```tsx
<HeroEntrance className="site-container relative z-10 pt-32 pb-12 md:pt-36 md:pb-16 lg:pt-40 lg:pb-24">
```

Tune the exact values if needed, but keep these invariants:

- headline is still visible in the first viewport on common desktop widths
- the product window remains the dominant visual object
- mobile does not start with excessive dead space

- [ ] **Step 3: Extend the homepage boundary test to verify the new spacing contract**

Add one assertion that the rendered hero contains the new top-padding class fragment:

```tsx
expect(heroSection).toContain("pt-32")
```

If the final tuned value differs, assert the exact class string actually used.

- [ ] **Step 4: Run the targeted tests again**

Run:

```bash
cd forma-website && npm test -- tests/header-shell.test.tsx tests/home-page-shell-boundary.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Do a quick visual pass in the browser**

Run:

```bash
cd forma-website && npm run dev
```

Verify manually at:

- desktop width around 1440px
- a narrower laptop width around 1280px
- one mobile width in responsive mode

Look for:

- no full-width top bar
- the shell hovering as one crisp object above the hero
- the headline not colliding with the shell
- the hero window still dominating the right side

- [ ] **Step 6: Commit the hero-spacing pass**

```bash
git add "forma-website/src/app/page.tsx" "forma-website/tests/home-page-shell-boundary.test.tsx"
git commit -m "feat: retune hero for floating header shell"
```

### Task 4: Sync docs and run full website verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`
- Modify: `TODO.md` (only if a concrete follow-up remains after verification)

- [ ] **Step 1: Update the unreleased changelog**

Add a short note under `## [Unreleased]` describing the website header change, for example:

```md
- `forma-website` homepage header now renders as a floating translucent shell over the hero instead of a full-width top bar, giving the first viewport a cleaner single-composition layout.
```

- [ ] **Step 2: Update the website-shell reference note**

Add a matching note to `API_REFERENCE.md` near the existing website shell entries so the docs stay aligned with the current shell behavior.

- [ ] **Step 3: Update TODO only if verification reveals a real follow-up**

If no concrete issue remains, leave `TODO.md` unchanged. If a real issue appears during mobile or browser verification, add one narrowly scoped checkbox item rather than a vague polish note.

- [ ] **Step 4: Run the full website verification suite**

Run:

```bash
cd forma-website && npm run lint
cd forma-website && npm test
cd forma-website && npm run build
```

Expected:

- `npm run lint` passes
- `npm test` passes with the new header coverage included
- `npm run build` passes

- [ ] **Step 5: Commit docs and verification-safe cleanup**

```bash
git add CHANGELOG.md API_REFERENCE.md TODO.md
git commit -m "docs: record floating website header shell"
```

If `TODO.md` was not changed, omit it from `git add`.
