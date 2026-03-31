# Website Luma-Inspired Marketing Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the marketing shell of `forma-website` with a Forma-specific shadcn-inspired design foundation while preserving bespoke product-demo sections.

**Architecture:** Introduce a local shadcn-compatible component foundation and shared shell tokens, then refit commodity marketing surfaces to use those primitives. Keep custom product-demo components like the hero app replica and before/after demos outside the generic component layer, and harmonize them visually after the shell shift.

**Tech Stack:** Next.js 16, React 19, TypeScript, Tailwind v4, shadcn/ui component source, CSS custom properties

---

### Task 1: Bootstrap the website component foundation

**Files:**
- Create: `forma-website/components.json`
- Modify: `forma-website/package.json`
- Reuse: `forma-website/src/lib/utils.ts`

- [ ] Initialize shadcn non-interactively with `npx shadcn@latest init -d --base radix` from `forma-website/`.
- [ ] Add only the primitive components needed for this pass: `button`, `input`, `card`, `accordion`, `sheet`, and `dialog`.
- [ ] Confirm the generated config and dependencies fit the current Tailwind v4 setup and keep `src/lib/utils.ts` as the shared `cn()` utility.

### Task 2: Define Forma's reusable marketing-shell tokens and primitives

**Files:**
- Modify: `forma-website/src/app/globals.css`
- Create: `forma-website/src/components/ui/forma-shell-card.tsx`
- Create: `forma-website/src/components/ui/forma-shell-section-heading.tsx`
- Create: `forma-website/src/components/ui/forma-shell-cta.tsx`
- Reuse: `forma-website/src/components/ui/button.tsx`
- Reuse: `forma-website/src/components/ui/input.tsx`
- Reuse: `forma-website/src/components/ui/card.tsx`

- [ ] Introduce a token layer for shell surfaces, shell borders, shell highlights, shell shadows, and CTA variants in `globals.css`.
- [ ] Build thin Forma wrappers around shadcn primitives so the design language stays centralized instead of spreading one-off class strings through page sections.
- [ ] Keep the wrappers scoped to commodity marketing UI and avoid pulling bespoke product-demo styling into the generic component layer.

### Task 3: Refit shared shell chrome in the global layout

**Files:**
- Modify: `forma-website/src/components/Header.tsx`
- Modify: `forma-website/src/components/Footer.tsx`
- Modify: `forma-website/src/app/layout.tsx`
- Reuse: `forma-website/src/components/ui/sheet.tsx`
- Reuse: `forma-website/src/components/ui/button.tsx`

- [ ] Replace the mobile menu implementation with a sheet-style navigation pattern that still preserves current accessibility behavior.
- [ ] Rework desktop header and footer styling to use the new shell tokens and CTA primitives.
- [ ] Keep the current information architecture and link structure intact.

### Task 4: Migrate homepage commodity sections to the new shell

**Files:**
- Modify: `forma-website/src/components/sections/PricingSection.tsx`
- Modify: `forma-website/src/components/sections/FAQSection.tsx`
- Modify: `forma-website/src/components/sections/NewsletterSection.tsx`
- Reuse: `forma-website/src/components/ui/accordion.tsx`
- Reuse: `forma-website/src/components/ui/card.tsx`
- Reuse: `forma-website/src/components/ui/input.tsx`
- Reuse: `forma-website/src/components/ui/button.tsx`

- [ ] Convert the pricing shell to shared card and CTA primitives while preserving the section's content and structure.
- [ ] Refactor FAQ to use a shared accordion primitive and align spacing, borders, and disclosure behavior with the new shell language.
- [ ] Refactor the newsletter form to shared input and button primitives and preserve current validation and success/error states.

### Task 5: Extend the shell to support and secondary marketing surfaces

**Files:**
- Modify: `forma-website/src/app/support/page.tsx`
- Modify: `forma-website/src/app/page.tsx`
- Reuse: `forma-website/src/components/ui/forma-shell-card.tsx`
- Reuse: `forma-website/src/components/ui/forma-shell-section-heading.tsx`

- [ ] Refit the support page cards and headings so they feel part of the same upgraded shell as the homepage.
- [ ] Audit the homepage sections around the bespoke hero and demos to ensure the new shell tokens do not clash with existing custom product surfaces.
- [ ] Preserve the custom hero app replica and product-demo compositions as bespoke implementations.

### Task 6: Update docs and verify the website pass

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `TODO.md`

- [ ] Add a note for the website shell refresh to `CHANGELOG.md`.
- [ ] Update `TODO.md` if any website design follow-up work remains after the first pass.
- [ ] Run `npm run lint` in `forma-website`.
- [ ] Run `npm run build` in `forma-website`.
