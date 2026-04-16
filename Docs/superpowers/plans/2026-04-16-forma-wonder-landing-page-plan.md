# Forma Wonder Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a full Wonder landing-page artboard for Forma that drives direct Mac App Store download from skeptical, overwhelmed Mac users.

**Architecture:** Implement the approved spec as one new desktop Wonder artboard built top-down. Start with a 1440x900 skeleton artboard, then apply sequential, section-scoped `update_elements` calls for header/hero, proof, trust flow, feature proof, FAQ, and the closing CTA. Verify at natural milestones with Wonder screenshots, then finalize the artboard and session only after visual polish is complete.

**Tech Stack:** Wonder MCP tools (`get_behavior_skills`, `get_basic_info`, `get_artboards`, `create_artboard`, `update_elements`, `get_element_tree`, `take_screenshot`, `finish_artboard`, `finish_session`), JSX + Tailwind utility classes, `div` / `span` / `img` / `svg` only, flex-only layout.

---

## Implementation Rules

- Core implementation happens in Wonder, not in `forma-website/`.
- Use the approved spec as the source of truth: `Docs/superpowers/specs/2026-04-16-forma-wonder-landing-page-design.md`.
- Use one Wonder session ID for the entire implementation pass.
- Load `create-design` behavior before building anything.
- Create a new artboard rather than modifying unrelated existing artboards.
- Build top-down in small sequential edits. Never issue concurrent `update_elements` calls to the same artboard.
- For every section-replacement or polish step, use:
  `update_elements(artboardId="<artboardId>", pageId="<pageId>", sessionId="<session>", edit="<anchored JSX>", instruction="<brief merge hint>")`
  with the smallest possible existing `data-node-id` anchor.
- Use at most three Wonder screenshots for the artboard:
  1. after skeleton creation
  2. after the mid-build pass
  3. after final polish
- Do not call `finish_artboard` until all updates and verifications are done.
- Do not call `finish_session` until the very end.

## File Structure

- **Reference:** `Docs/superpowers/specs/2026-04-16-forma-wonder-landing-page-design.md` — approved landing-page design spec.
- **Create:** Wonder artboard `Forma Landing Page` on the active Wonder page from `get_basic_info`.
- **Modify:** The new Wonder artboard only, via localized `update_elements` calls.
- **Verify:** Wonder screenshots captured with `take_screenshot`.
- **Finalize:** Wonder artboard and session via `finish_artboard` and `finish_session`.

No repository code files are required for the artboard implementation itself. The only repo artifact in this plan is this plan document.

## Task 1: Capture Wonder Context and Create the Skeleton Artboard

**Files:**
- Reference: `Docs/superpowers/specs/2026-04-16-forma-wonder-landing-page-design.md`
- Create: Wonder artboard `Forma Landing Page`

- [ ] **Step 1: Load the Wonder design workflow and capture the active context**

Run:
```text
get_behavior_skills(skill="create-design", sessionId="<session>")
get_basic_info(sessionId="<session>")
```

Expected:
- Wonder returns the `create-design` behavior instructions.
- `get_basic_info` returns a valid `pageId`.
- If `selectedElementIds` is non-empty, treat them as context only. Do not reuse them unless the user explicitly asks.

- [ ] **Step 2: List existing artboards on the active page so the new work stays isolated**

Run:
```text
get_artboards(pageId="<pageId>", sessionId="<session>")
```

Expected:
- A list of current top-level artboards is returned.
- The engineer confirms the new landing page will be created as a separate artboard, not layered into someone else's work.

- [ ] **Step 3: Create a 1440x900 landing-page skeleton artboard**

Run:
```text
create_artboard(
  pageId="<pageId>",
  sessionId="<session>",
  code='
<div data-node-label="Landing Page" data-component-width="1440" data-component-height="900" className="flex flex-col">
  <div data-node-label="Header Skeleton" className="h-[72px] flex flex-row gap-[20px]">
    <div data-node-label="Logo Placeholder" className="w-[120px] h-[40px]"></div>
    <div data-node-label="Nav Placeholder" className="flex-1 h-[40px]"></div>
    <div data-node-label="Cta Placeholder" className="w-[180px] h-[40px]"></div>
  </div>
  <div data-node-label="Hero Skeleton" className="h-[520px] flex flex-row gap-[32px]">
    <div data-node-label="Hero Copy Skeleton" className="w-[620px] flex flex-col gap-[16px]">
      <div data-node-label="Eyebrow Placeholder" className="w-[180px] h-[16px]"></div>
      <div data-node-label="Headline Placeholder" className="w-[540px] h-[96px]"></div>
      <div data-node-label="Subcopy Placeholder" className="w-[460px] h-[72px]"></div>
      <div data-node-label="Meta Placeholder" className="w-[320px] h-[20px]"></div>
      <div data-node-label="Hero Cta Placeholder" className="w-[220px] h-[48px]"></div>
    </div>
    <div data-node-label="Hero Window Skeleton" className="flex-1 flex flex-col gap-[16px]">
      <div data-node-label="Window Toolbar Placeholder" className="w-full h-[28px]"></div>
      <div data-node-label="Window Body Placeholder" className="w-full h-[340px]"></div>
    </div>
  </div>
  <div data-node-label="Proof Skeleton" className="h-[220px] flex flex-row gap-[20px]">
    <div data-node-label="Before Placeholder" className="flex-1 h-[180px]"></div>
    <div data-node-label="Arrow Placeholder" className="w-[60px] h-[180px]"></div>
    <div data-node-label="After Placeholder" className="flex-1 h-[180px]"></div>
  </div>
  <div data-node-label="Process Skeleton" className="h-[260px] flex flex-col gap-[16px]">
    <div data-node-label="Process Intro Placeholder" className="w-[220px] h-[20px]"></div>
    <div data-node-label="Process Cards Placeholder" className="h-[180px] flex flex-row gap-[16px]">
      <div data-node-label="Step Placeholder" className="flex-1 h-[180px]"></div>
      <div data-node-label="Step Placeholder" className="flex-1 h-[180px]"></div>
      <div data-node-label="Step Placeholder" className="flex-1 h-[180px]"></div>
    </div>
  </div>
  <div data-node-label="Features Skeleton" className="h-[360px] flex flex-col gap-[16px]">
    <div data-node-label="Features Intro Placeholder" className="w-[220px] h-[20px]"></div>
    <div data-node-label="Features Grid Placeholder" className="h-[300px] flex flex-row gap-[16px] flex-wrap">
      <div data-node-label="Feature Placeholder" className="w-[680px] h-[140px]"></div>
      <div data-node-label="Feature Placeholder" className="w-[680px] h-[140px]"></div>
      <div data-node-label="Feature Placeholder" className="w-[680px] h-[140px]"></div>
      <div data-node-label="Feature Placeholder" className="w-[680px] h-[140px]"></div>
    </div>
  </div>
  <div data-node-label="Faq Skeleton" className="h-[260px] flex flex-col gap-[16px]">
    <div data-node-label="Faq Intro Placeholder" className="w-[180px] h-[20px]"></div>
    <div data-node-label="Faq Rows Placeholder" className="h-[200px] flex flex-col gap-[12px]">
      <div data-node-label="Faq Row Placeholder" className="w-full h-[40px]"></div>
      <div data-node-label="Faq Row Placeholder" className="w-full h-[40px]"></div>
      <div data-node-label="Faq Row Placeholder" className="w-full h-[40px]"></div>
      <div data-node-label="Faq Row Placeholder" className="w-full h-[40px]"></div>
    </div>
  </div>
  <div data-node-label="Closing Skeleton" className="h-[220px] flex flex-row gap-[20px]">
    <div data-node-label="Closing Copy Placeholder" className="flex-1 h-[160px]"></div>
    <div data-node-label="Closing Cta Placeholder" className="w-[360px] h-[160px]"></div>
  </div>
</div>'
)
```

Expected:
- Wonder returns `resolvedCode` with a new root `data-node-id`.
- Save that root ID as the implementation `artboardId`.

- [ ] **Step 4: Verify the skeleton structure before adding design detail**

Run:
```text
take_screenshot(elementId="<artboardId>", pageId="<pageId>", sessionId="<session>")
```

Expected:
- Screenshot 1 shows the correct top-down section order.
- No placeholder block is missing.
- The artboard grows vertically from the initial 900px viewport shell.

## Task 2: Build the Header, Hero, and Product Window

**Files:**
- Modify: Wonder artboard `Forma Landing Page`
- Verify: Wonder screenshot 2 will include this work later in the same pass

- [ ] **Step 1: Pull the current artboard tree and anchor on the smallest section roots**

Run:
```text
get_element_tree(rootElementId="<artboardId>", pageId="<pageId>", sessionId="<session>")
```

Expected:
- The returned code includes stable `data-node-id` anchors for the header and hero skeleton blocks.
- Use those inner section IDs, not the entire artboard root, for subsequent hero edits when possible.

- [ ] **Step 2: Replace the header skeleton with a restrained top bar**

Update the header area so it contains:
- Forma wordmark / brand mark on the left
- minimal utility text or small trust cue in the middle if spacing supports it
- a single Mac App Store CTA on the right

The header should feel light and integrated with the hero rather than like a boxed navigation bar.

Representative edit shape:
```jsx
<div data-node-id="<header-id>" data-node-label="Header Section" className="flex items-center justify-between px-[28px] py-[18px]">
  <div data-node-label="Brand Row" className="flex items-center gap-[10px]">
    <div data-node-label="Brand Mark" className="w-[30px] h-[30px] rounded-[10px] bg-[#1f1b17]"></div>
    <span data-node-label="Brand Text" className="text-[18px] tracking-[-0.04em] text-[#1f1b17]">Forma</span>
  </div>
  <span data-node-label="Header Note" className="text-[11px] uppercase tracking-[0.14em] text-[#6c7686]">For the perpetually messy</span>
  <div data-node-label="Header Cta" className="flex items-center rounded-full bg-[#1f1b17] px-[18px] py-[12px]">
    <span data-node-label="Header Cta Text" className="text-[11px] uppercase tracking-[0.1em] text-[#f8f2ea]">Get Forma for Mac</span>
  </div>
</div>
```

- [ ] **Step 3: Replace the hero copy skeleton with the approved trust-first copy hierarchy**

Update the hero copy column to include:
- eyebrow: `For the perpetually messy`
- headline: `A file organizer for people who gave up on file organizers.`
- subcopy that mentions plain-English rules, preview, and undo
- price/meta pills: `$29 once`, `No account`, `Undo built in`
- one primary CTA and a quiet one-time-price note

Representative copy block:
```jsx
<div data-node-id="<hero-copy-id>" data-node-label="Hero Copy" className="flex w-[620px] flex-col gap-[16px]">
  <span data-node-label="Eyebrow Text" className="text-[11px] uppercase tracking-[0.14em] text-[#6c7686]">For the perpetually messy</span>
  <span data-node-label="Headline Text" className="max-w-[10ch] text-[50px] leading-[0.92] tracking-[-0.06em] text-[#1f1b17]">A file organizer for people who gave up on file organizers.</span>
  <span data-node-label="Subcopy Text" className="max-w-[34ch] text-[15px] leading-[1.58] text-[rgba(31,27,23,0.72)]">Tell Forma where your files should go in plain English. Preview the batch before anything moves. Undo the recent batch if something was wrong.</span>
  <div data-node-label="Meta Row" className="flex flex-wrap gap-[10px]">
    {["$29 once", "No account", "Undo built in"].map((item) => (
      <div key={item} data-node-label="Meta Pill" className="flex items-center rounded-full border border-[rgba(31,27,23,0.1)] bg-[rgba(255,255,255,0.48)] px-[12px] py-[8px]">
        <span data-node-label="Meta Text" className="text-[11px] uppercase tracking-[0.08em] text-[#1f1b17]">{item}</span>
      </div>
    ))}
  </div>
  <div data-node-label="Hero Cta Group" className="flex flex-col gap-[10px]">
    <div data-node-label="Primary Cta" className="flex w-fit items-center rounded-full bg-[#1f1b17] px-[18px] py-[13px]">
      <span data-node-label="Primary Cta Text" className="text-[11px] uppercase tracking-[0.1em] text-[#f8f2ea]">Get Forma for Mac</span>
    </div>
    <span data-node-label="Price Note" className="text-[13px] text-[rgba(31,27,23,0.56)]">$29 once. No subscription. No account. Just a Mac app.</span>
  </div>
</div>
```

- [ ] **Step 4: Turn the hero window skeleton into a calm product-proof surface**

The hero window should:
- sit on the right side as the dominant visual object
- imply a real product state rather than a fake marketing illustration
- visually show rule entry plus previewed file movement rows

Representative structure:
```jsx
<div data-node-id="<hero-window-id>" data-node-label="Hero Window" className="flex flex-1 flex-col rounded-[24px] border border-[rgba(31,27,23,0.08)] bg-[rgba(255,255,255,0.7)] shadow-[0_24px_60px_rgba(0,0,0,0.08)]">
  <div data-node-label="Window Top" className="flex h-[24px] items-center gap-[6px] border-b border-[rgba(31,27,23,0.06)] bg-[rgba(31,27,23,0.05)] px-[12px]">
    <div data-node-label="Window Dot" className="h-[8px] w-[8px] rounded-full bg-[rgba(31,27,23,0.25)]"></div>
    <div data-node-label="Window Dot" className="h-[8px] w-[8px] rounded-full bg-[rgba(31,27,23,0.25)]"></div>
    <div data-node-label="Window Dot" className="h-[8px] w-[8px] rounded-full bg-[rgba(31,27,23,0.25)]"></div>
  </div>
  <div data-node-label="Window Body" className="flex flex-col gap-[14px] p-[16px]">
    <div data-node-label="Toolbar Row" className="flex h-[28px] rounded-[16px] border border-[rgba(31,27,23,0.06)] bg-[rgba(31,27,23,0.04)]"></div>
    <div data-node-label="Rule Row" className="flex h-[42px] rounded-[16px] border border-[rgba(31,27,23,0.06)] bg-[rgba(31,27,23,0.04)]"></div>
    <div data-node-label="Preview Panel" className="flex flex-col gap-[8px] rounded-[18px] border border-[rgba(122,157,126,0.12)] bg-[rgba(122,157,126,0.08)] p-[12px]">
      <div data-node-label="Preview Row" className="h-[12px] rounded-full bg-[#dca28d]"></div>
      <div data-node-label="Preview Row" className="h-[12px] rounded-full bg-[#6e89a2]"></div>
      <div data-node-label="Preview Row" className="h-[12px] rounded-full bg-[#8aa184]"></div>
      <div data-node-label="Preview Row" className="h-[12px] rounded-full bg-[#b8aa96]"></div>
    </div>
  </div>
</div>
```

- [ ] **Step 5: Make one localized hero polish pass before moving down-page**

Refine only hero-level details:
- spacing between copy and window
- CTA dominance
- headline line breaks
- meta-pill density
- hero surface contrast

Expected:
- The hero reads clearly without depending on later sections.
- The CTA is unmistakably primary.

## Task 3: Build the Mess-to-Order Proof and the Three-Step Trust Flow

**Files:**
- Modify: Wonder artboard `Forma Landing Page`
- Verify: Wonder screenshot 2

- [ ] **Step 1: Replace the proof skeleton with a visible before/after transformation**

The proof section must read emotionally before it reads technically.

Implement:
- left panel with messy-file cues
- center arrow / directional hinge
- right panel with categorized after-state

Representative structure:
```jsx
<div data-node-id="<proof-id>" data-node-label="Proof Section" className="flex items-center gap-[12px] rounded-[24px] border border-[rgba(31,27,23,0.08)] bg-[rgba(255,255,255,0.46)] p-[22px]">
  <div data-node-label="Before Card" className="flex flex-1 flex-col gap-[9px] rounded-[20px] border border-[rgba(31,27,23,0.08)] bg-[rgba(255,255,255,0.5)] p-[16px]">
    <span data-node-label="Before Label" className="text-[12px] uppercase tracking-[0.12em] text-[#1f1b17]">Mess Before</span>
    {["Screenshot 2026-04-12 at 9.41.18 AM.png", "invoice-final-final.pdf", "Downloads copy 7.zip", "IMG_8421.PNG"].map((item) => (
      <span key={item} data-node-label="Before File" className="rounded-full bg-[#d79b87] px-[12px] py-[8px] text-[12px] text-[#1f1b17]">{item}</span>
    ))}
  </div>
  <div data-node-label="Arrow Wrap" className="flex w-[44px] items-center justify-center">
    <span data-node-label="Arrow Text" className="text-[30px] text-[rgba(31,27,23,0.4)]">→</span>
  </div>
  <div data-node-label="After Card" className="flex flex-1 flex-col gap-[9px] rounded-[20px] border border-[rgba(31,27,23,0.08)] bg-[rgba(255,255,255,0.5)] p-[16px]">
    <span data-node-label="After Label" className="text-[12px] uppercase tracking-[0.12em] text-[#1f1b17]">Clear After</span>
    {["Screenshots / 24 files", "Invoices / 12 files", "Installs / 6 files", "Photos / 118 files"].map((item) => (
      <span key={item} data-node-label="After Folder" className="rounded-full bg-[#7e9573] px-[12px] py-[8px] text-[12px] text-[#f8f2ea]">{item}</span>
    ))}
  </div>
</div>
```

- [ ] **Step 2: Replace the process skeleton with the approved trust flow**

Use the exact three-step model:
1. `Write a rule`
2. `Preview the batch`
3. `Undo the batch`

Representative structure:
```jsx
<div data-node-id="<process-id>" data-node-label="Process Section" className="flex flex-col gap-[16px] rounded-[24px] border border-[rgba(31,27,23,0.08)] bg-[rgba(255,255,255,0.42)] p-[22px]">
  <span data-node-label="Process Label" className="text-[12px] uppercase tracking-[0.12em] text-[#1f1b17]">Trust Flow</span>
  <div data-node-label="Steps Row" className="flex gap-[12px]">
    {[
      { number: "1", title: "Write a rule", body: "Plain English, not regex or settings-panel gymnastics." },
      { number: "2", title: "Preview the batch", body: "See every move before anything happens." },
      { number: "3", title: "Undo the batch", body: "Reverse the recent batch if something was wrong." }
    ].map((step) => (
      <div key={step.number} data-node-label="Step Card" className="flex flex-1 flex-col gap-[8px] rounded-[18px] border border-[rgba(31,27,23,0.08)] bg-[rgba(255,255,255,0.62)] p-[16px]">
        <span data-node-label="Step Number" className="text-[28px] tracking-[-0.04em] text-[#1f1b17]">{step.number}</span>
        <span data-node-label="Step Title" className="text-[11px] uppercase tracking-[0.08em] text-[#6c7686]">{step.title}</span>
        <span data-node-label="Step Body" className="text-[13px] leading-[1.45] text-[rgba(31,27,23,0.75)]">{step.body}</span>
      </div>
    ))}
  </div>
</div>
```

- [ ] **Step 3: Add the nearby trust-pill row without turning it into badge clutter**

Add a simple row for:
- `Everything stays on your Mac`
- `No account required`
- `No silent background surprises`

Expected:
- The pills support the process section rather than competing with it.

- [ ] **Step 4: Verify the top and middle of the page together**

Run:
```text
take_screenshot(elementId="<artboardId>", pageId="<pageId>", sessionId="<session>")
```

Expected:
- Screenshot 2 includes the hero, proof, and process sections.
- The page still feels editorial and light.
- The proof section reads instantly.

## Task 4: Build the Feature Proof Grid

**Files:**
- Modify: Wonder artboard `Forma Landing Page`

- [ ] **Step 1: Replace the features skeleton with a two-column, four-card proof grid**

The four approved feature themes are:
- `Tell it what to do in plain English`
- `See every move before it happens`
- `Undo the recent batch if something was wrong`
- `Everything stays on your Mac`

Representative structure:
```jsx
<div data-node-id="<features-id>" data-node-label="Features Section" className="flex flex-col gap-[16px]">
  <span data-node-label="Features Label" className="text-[12px] uppercase tracking-[0.12em] text-[#1f1b17]">Feature Proof</span>
  <div data-node-label="Features Grid" className="flex flex-wrap gap-[12px]">
    {[
      {
        title: "Tell it what to do in plain English",
        body: "Use real examples, not abstract settings. ‘PDFs with invoice in the name go to Finances’ should feel native to the page."
      },
      {
        title: "See every move before it happens",
        body: "Preview is part of the product promise, not a buried safety toggle."
      },
      {
        title: "Undo the recent batch if something was wrong",
        body: "Undo should feel central and reassuring, not like a hidden recovery tool."
      },
      {
        title: "Everything stays on your Mac",
        body: "Privacy is a concrete trust signal, not a soft marketing footer note."
      }
    ].map((feature) => (
      <div key={feature.title} data-node-label="Feature Card" className="flex w-[694px] flex-col gap-[8px] rounded-[20px] border border-[rgba(31,27,23,0.08)] bg-[rgba(255,255,255,0.56)] p-[18px]">
        <span data-node-label="Feature Title" className="text-[17px] tracking-[-0.03em] text-[#1f1b17]">{feature.title}</span>
        <span data-node-label="Feature Body" className="text-[13px] leading-[1.5] text-[rgba(31,27,23,0.74)]">{feature.body}</span>
      </div>
    ))}
  </div>
</div>
```

- [ ] **Step 2: Add small section-level nuance instead of more cards**

Refine only within the features section:
- slight accent shifts between cards
- clearer differentiation between safety and capability cards
- careful whitespace so the section does not become a feature wall

Expected:
- Each feature card feels concrete.
- The grid stays calm and scannable.

## Task 5: Build the FAQ and the Closing CTA Band

**Files:**
- Modify: Wonder artboard `Forma Landing Page`

- [ ] **Step 1: Replace the FAQ skeleton with four objection-led rows**

Use these exact question directions:
- `Will it delete my files?`
- `Does anything leave my Mac?`
- `Do I need to keep it running in the background?`
- `Why would I trust this over other file organizers?`

Representative structure:
```jsx
<div data-node-id="<faq-id>" data-node-label="Faq Section" className="flex flex-col gap-[10px] rounded-[22px] border border-[rgba(31,27,23,0.08)] bg-[rgba(255,255,255,0.44)] p-[20px]">
  <span data-node-label="Faq Label" className="text-[12px] uppercase tracking-[0.12em] text-[#1f1b17]">FAQ</span>
  {[
    "Will it delete my files?",
    "Does anything leave my Mac?",
    "Do I need to keep it running in the background?",
    "Why would I trust this over other file organizers?"
  ].map((item) => (
    <div key={item} data-node-label="Faq Row" className="flex items-center justify-between border-t border-[rgba(31,27,23,0.08)] py-[14px] first:border-t-0 first:pt-0">
      <span data-node-label="Faq Question" className="text-[14px] text-[#1f1b17]">{item}</span>
      <span data-node-label="Faq Mark" className="text-[18px] text-[rgba(31,27,23,0.46)]">+</span>
    </div>
  ))}
</div>
```

- [ ] **Step 2: Replace the closing skeleton with a calm dark CTA band**

The closing band should:
- repeat the download action
- keep one-time pricing visible
- feel like a confident conclusion, not a second hero

Representative structure:
```jsx
<div data-node-id="<closing-id>" data-node-label="Closing Section" className="flex gap-[18px] rounded-[24px] border border-[rgba(31,27,23,0.08)] bg-[#1f1b17] p-[24px]">
  <div data-node-label="Closing Copy" className="flex flex-1 flex-col gap-[10px]">
    <span data-node-label="Closing Label" className="text-[12px] uppercase tracking-[0.12em] text-[rgba(248,242,234,0.72)]">Final CTA</span>
    <span data-node-label="Closing Headline" className="max-w-[20ch] text-[28px] tracking-[-0.04em] text-[#f8f2ea]">Your files are not going to organize themselves. Forma can help.</span>
    <span data-node-label="Closing Body" className="max-w-[38ch] text-[14px] leading-[1.55] text-[rgba(248,242,234,0.76)]">$29 once. No subscription. No account. Just a Mac app.</span>
  </div>
  <div data-node-label="Closing Cta Card" className="flex w-[320px] flex-col justify-center rounded-[18px] border border-[rgba(255,255,255,0.12)] bg-[rgba(255,255,255,0.06)] p-[18px]">
    <div data-node-label="Store Button" className="flex items-center justify-center rounded-[16px] bg-[#f5efe8] px-[16px] py-[12px]">
      <span data-node-label="Store Button Text" className="text-[11px] uppercase tracking-[0.1em] text-[#1f1b17]">Download on the Mac App Store</span>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Make a localized lower-page polish pass**

Refine only:
- FAQ row spacing and line weight
- CTA band proportion
- closing copy density
- balance between the closing copy block and the CTA card

Expected:
- The bottom of the page feels deliberate and resolved.

## Task 6: Final Polish, Verification, and Wonder Finalization

**Files:**
- Modify: Wonder artboard `Forma Landing Page`
- Finalize: Wonder artboard + Wonder session

- [ ] **Step 1: Pull the full artboard tree one last time and inspect for localized polish anchors**

Run:
```text
get_element_tree(rootElementId="<artboardId>", pageId="<pageId>", sessionId="<session>")
```

Expected:
- Confirm section ordering is still:
  header/hero -> proof -> process -> features -> faq -> closing CTA
- Identify only the smallest anchors needed for final refinements.

- [ ] **Step 2: Make the last polish pass without rewriting whole sections**

Refine only the details that affect conversion and clarity:
- hero headline wrap
- CTA weight and contrast
- proof-section readability
- process-card spacing
- feature-grid rhythm
- FAQ clarity
- closing-band proportion

Expected:
- No new sections are introduced.
- The page stays specific to Forma and free of generic SaaS patterns.

- [ ] **Step 3: Capture the final artboard screenshot**

Run:
```text
take_screenshot(elementId="<artboardId>", pageId="<pageId>", sessionId="<session>")
```

Expected:
- Screenshot 3 shows the finished artboard.
- The first screen immediately communicates audience, trust model, and download action.
- The page scans cleanly from top to bottom.

- [ ] **Step 4: Finalize the artboard**

Run:
```text
finish_artboard(artboardId="<artboardId>", sessionId="<session>")
```

Expected:
- Wonder marks the landing-page artboard as finalized.

- [ ] **Step 5: Finalize the Wonder session**

Run:
```text
finish_session(sessionId="<session>")
```

Expected:
- All Wonder edits are saved and no draft state is left open.

## Validation Checklist

Implementation is complete only when all of the following are true:

- [ ] The hero immediately identifies the audience with the approved headline.
- [ ] The App Store CTA is the clearest action on the page.
- [ ] The before/after section communicates relief at a glance.
- [ ] The three-step trust flow uses the approved `Write / Preview / Undo` sequence.
- [ ] The feature section stays concrete and trust-oriented.
- [ ] The FAQ answers anxious objections rather than generic product questions.
- [ ] The closing CTA band repeats the download action without adding a second funnel.
- [ ] The palette remains warm, light, and deliberate.
- [ ] The page feels specific to Forma rather than interchangeable with a generic SaaS brand.
- [ ] `finish_artboard` and `finish_session` have both been called exactly once at the end.
