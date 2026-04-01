# Forma Website Hybrid A Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved Hybrid A homepage header so the page-top state stays quiet (`Forma + Get Forma`) and the compact split-nav state appears only after scroll.

**Architecture:** Add one small client-side header-mode unit to determine `top` vs `scrolled`, keep the mode contract centralized in the shared header layout file, and update the header shell styling so the top state is quieter while the scrolled state is clearly navigational. Cover the change with one new DOM scroll-state test plus targeted structural assertions, then sync the required docs after behavior is verified.

**Tech Stack:** Next.js App Router, React 19, TypeScript, Tailwind v4 utilities, Vitest, jsdom

---

## File Map

### Existing files to modify

- `forma-website/src/components/Header.tsx`
  - Add the two-state rendering contract, wire in the scroll-state unit, and apply distinct top/scrolled shell treatments without changing tracked CTA behavior or the mobile sheet IA.
- `forma-website/src/lib/header-shell-layout.ts`
  - Centralize the new top/scrolled shell geometry, scroll threshold, and any top-state/scrolled-state class contracts so the behavior is not scattered across the component.
- `forma-website/src/app/globals.css`
  - Add the warmer adaptive header shell tokens and any explicit transition/material helpers needed for the quieter top state and clearer scrolled state.
- `forma-website/tests/header-shell.test.tsx`
  - Tighten structural coverage so the header’s server-rendered contract matches the new Hybrid A shell expectations.
- `CHANGELOG.md`
  - Record the shipped marketing-site header behavior change.
- `TODO.md`
  - Mark the Hybrid A follow-up as completed if it is not already captured.
- `Docs/Getting-Started/TODO.md`
  - Keep the synced TODO copy aligned with the root TODO entry.
- `API_REFERENCE.md`
  - Document any new exported header mode hook/constants or shell contract details that become part of the website API surface.

### New files to create

- `forma-website/src/hooks/use-header-shell-mode.ts`
  - Encapsulate the `top`/`scrolled` state logic and scroll threshold detection so `Header.tsx` stays focused on rendering.
- `forma-website/tests/header-shell.dom.test.tsx`
  - jsdom regression coverage for scroll-driven mode changes and the desktop-nav visibility contract.

## Task 1: Lock the Two-State Contract With Failing Tests

**Files:**
- Modify: `forma-website/tests/header-shell.test.tsx`
- Create: `forma-website/tests/header-shell.dom.test.tsx`
- Reference: `forma-website/src/components/Header.tsx`
- Reference: `forma-website/src/lib/header-shell-layout.ts`

- [ ] **Step 1: Add a failing structural test for the Hybrid A server-rendered top state**

Add assertions to `forma-website/tests/header-shell.test.tsx` for the page-top shell contract. The first render should expose a quiet top-state marker and should not render the desktop nav as visible by default.

```tsx
expect(headerTag).toContain('data-header-shell-mode="top"')
expect(floatingShellClasses).toContain("data-[shell-mode=top]:bg-[var(--header-shell-surface-top)]")
expect(floatingShellClasses).toContain("data-[shell-mode=scrolled]:bg-[var(--header-shell-surface-scrolled)]")
```

- [ ] **Step 2: Run the structural test to verify it fails**

Run:

```bash
cd forma-website && npm test -- header-shell.test.tsx
```

Expected: FAIL because the current header does not expose the new mode contract yet.

- [ ] **Step 3: Add a failing DOM test for scroll-driven mode changes**

Create `forma-website/tests/header-shell.dom.test.tsx` with jsdom coverage modeled after `newsletter-section.dom.test.tsx`. Render `<Header />`, stub `window.matchMedia`, then simulate `window.scrollY` crossing the threshold and dispatch `scroll`.

```tsx
// @vitest-environment jsdom

it("switches from top mode to scrolled mode after the shell threshold", async () => {
  expect(header?.getAttribute("data-header-shell-mode")).toBe("top")

  Object.defineProperty(window, "scrollY", {
    configurable: true,
    value: HEADER_SHELL_LAYOUT.scrollThreshold + 1,
  })

  window.dispatchEvent(new Event("scroll"))

  expect(header?.getAttribute("data-header-shell-mode")).toBe("scrolled")
})
```

- [ ] **Step 4: Run the DOM test to verify it fails**

Run:

```bash
cd forma-website && npm test -- header-shell.dom.test.tsx
```

Expected: FAIL because no scroll-state unit exists yet.

- [ ] **Step 5: Commit the red tests**

```bash
git add forma-website/tests/header-shell.test.tsx forma-website/tests/header-shell.dom.test.tsx
git commit -m "test: define hybrid a header state contract"
```

## Task 2: Add the Header Shell Mode Unit

**Files:**
- Create: `forma-website/src/hooks/use-header-shell-mode.ts`
- Modify: `forma-website/src/lib/header-shell-layout.ts`
- Test: `forma-website/tests/header-shell.dom.test.tsx`

- [ ] **Step 1: Write the minimal hook and shared mode constants**

Create `forma-website/src/hooks/use-header-shell-mode.ts` with one focused responsibility: derive `"top"` or `"scrolled"` from the current scroll position.

Use a small, explicit API:

```ts
export type HeaderShellMode = "top" | "scrolled"

export function useHeaderShellMode(threshold: number): HeaderShellMode {
  const [mode, setMode] = useState<HeaderShellMode>(() =>
    getHeaderShellMode(window.scrollY, threshold)
  )

  useEffect(() => {
    const updateMode = () => {
      setMode(getHeaderShellMode(window.scrollY, threshold))
    }

    updateMode()
    window.addEventListener("scroll", updateMode, { passive: true })

    return () => {
      window.removeEventListener("scroll", updateMode)
    }
  }, [threshold])

  return mode
}
```

Also add a pure helper for testability:

```ts
export function getHeaderShellMode(scrollY: number, threshold: number): HeaderShellMode {
  return scrollY > threshold ? "scrolled" : "top"
}
```

- [ ] **Step 2: Extend `HEADER_SHELL_LAYOUT` with mode constants**

Add only the fields the header needs:

```ts
scrollThreshold: 24,
topMode: "top",
scrolledMode: "scrolled",
topStateShellClassName: "...",
scrolledStateShellClassName: "...",
```

Keep this DRY. The goal is one shared contract, not ad hoc class strings in `Header.tsx`.

- [ ] **Step 3: Run the DOM test to verify the mode unit passes**

Run:

```bash
cd forma-website && npm test -- header-shell.dom.test.tsx
```

Expected: PASS for the mode change behavior, even if the visual assertions are still failing.

- [ ] **Step 4: Commit the mode unit**

```bash
git add forma-website/src/hooks/use-header-shell-mode.ts forma-website/src/lib/header-shell-layout.ts forma-website/tests/header-shell.dom.test.tsx
git commit -m "feat: add header shell mode state"
```

## Task 3: Implement the Hybrid A Header UI

**Files:**
- Modify: `forma-website/src/components/Header.tsx`
- Modify: `forma-website/src/app/globals.css`
- Modify: `forma-website/src/lib/header-shell-layout.ts`
- Test: `forma-website/tests/header-shell.test.tsx`
- Test: `forma-website/tests/header-shell.dom.test.tsx`

- [ ] **Step 1: Update `Header.tsx` to render both states through one contract**

Use `useHeaderShellMode(HEADER_SHELL_LAYOUT.scrollThreshold)` inside `Header.tsx`. Add an explicit mode attribute to the outer header and the shell card:

```tsx
const shellMode = useHeaderShellMode(HEADER_SHELL_LAYOUT.scrollThreshold)

<header
  data-header-shell="floating"
  data-header-shell-mode={shellMode}
  ...
>
  <FormaShellCard
    variant="floating"
    data-shell-mode={shellMode}
    className={cn(
      HEADER_SHELL_LAYOUT.baseShellClassName,
      shellMode === HEADER_SHELL_LAYOUT.topMode
        ? HEADER_SHELL_LAYOUT.topStateShellClassName
        : HEADER_SHELL_LAYOUT.scrolledStateShellClassName
    )}
  >
```

Requirements:

- top state: render brand + CTA, keep desktop nav visually hidden
- scrolled state: reveal the desktop nav
- mobile trigger remains available and tappable
- tracked CTA remains unchanged

- [ ] **Step 2: Implement the visual shell token changes in `globals.css`**

Add distinct tokens for top vs scrolled states rather than trying to reuse one washed-out surface:

```css
--header-shell-surface-top: rgba(255, 252, 247, 0.78);
--header-shell-surface-top-border: rgba(60, 52, 43, 0.10);
--header-shell-surface-scrolled: rgba(255, 250, 244, 0.94);
--header-shell-surface-scrolled-border: rgba(60, 52, 43, 0.14);
```

Light-mode scrolled state should be denser than the top state. Keep the palette warm, not icy.

- [ ] **Step 3: Encode the nav reveal cleanly**

Use a simple opacity/translate transition for the desktop nav only when `shellMode === "scrolled"`.

Example target shape:

```tsx
<nav
  aria-label="Main navigation"
  className={cn(
    "hidden md:flex transition-[opacity,transform,width] duration-200 ease-out",
    shellMode === "scrolled"
      ? "pointer-events-auto translate-y-0 opacity-100"
      : "pointer-events-none -translate-y-1 opacity-0"
  )}
>
```

Do not animate shell height dramatically. The shift should feel like refinement, not transformation theater.

- [ ] **Step 4: Re-run the targeted tests until both pass**

Run:

```bash
cd forma-website && npm test -- header-shell.test.tsx
cd forma-website && npm test -- header-shell.dom.test.tsx
```

Expected: PASS for both files.

- [ ] **Step 5: Commit the UI implementation**

```bash
git add forma-website/src/components/Header.tsx forma-website/src/app/globals.css forma-website/src/lib/header-shell-layout.ts forma-website/tests/header-shell.test.tsx forma-website/tests/header-shell.dom.test.tsx
git commit -m "feat: implement hybrid a website header"
```

## Task 4: Full Verification and Docs Sync

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `TODO.md`
- Modify: `Docs/Getting-Started/TODO.md`
- Modify: `API_REFERENCE.md`
- Verify: `forma-website/tests/*.tsx`

- [ ] **Step 1: Sync the docs required by `codex-project.toml`**

Update:

- `CHANGELOG.md` with the two-state Hybrid A header behavior
- `TODO.md` and `Docs/Getting-Started/TODO.md` with the completed header follow-up note
- `API_REFERENCE.md` with the new exported hook or layout contract additions

Stage only the header-related doc changes. Do not absorb unrelated roadmap edits unless they are already intentionally part of the branch.

- [ ] **Step 2: Run the full website verification suite**

Run:

```bash
cd forma-website && npm run lint
cd forma-website && npm test
cd forma-website && npm run build
```

Expected:

- `eslint` exits `0`
- Vitest passes all website tests
- Next build exits `0`

- [ ] **Step 3: Check git status before the final commit**

Run:

```bash
git status --short
```

Expected: only the intended header/doc files are modified.

- [ ] **Step 4: Commit the docs + verification-ready state**

```bash
git add CHANGELOG.md TODO.md Docs/Getting-Started/TODO.md API_REFERENCE.md
git commit -m "docs: record hybrid a header behavior"
```

- [ ] **Step 5: Prepare for execution handoff**

At this point the branch should contain:

- red/green tests for the two-state contract
- the new header shell mode unit
- the Hybrid A UI implementation
- synced docs
- fresh verification evidence

If the user wants execution next, recommend subagent-driven execution for the implementation tasks because the test task and UI task can be reviewed cleanly between commits.
