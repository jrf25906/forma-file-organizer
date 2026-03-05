# Forma Product Redesign Master Brief

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Designers | Developers | Marketing | QA

This document is the canonical redesign brief for the next Forma product polish cycle. It replaces the earlier website-only planning state and locks the chosen direction before implementation begins.

## 1. Reviewed Inputs

- Local app review using the March 5, 2026 screen recording of the macOS app, sampled across the dashboard, Smart Rules, Analytics, and inline rule-builder flows.
- Local website review using the March 5, 2026 screen recording of the marketing site, sampled across the homepage, pricing/footer, blog index, and blog article flow.
- Website implementation review across:
  - `forma-website/src/app/page.tsx`
  - `forma-website/src/app/layout.tsx`
  - `forma-website/src/app/globals.css`
  - `forma-website/src/components/Header.tsx`
  - `forma-website/src/components/Footer.tsx`
  - `forma-website/src/components/sections/*`
  - `forma-website/src/app/blog/[slug]/page.tsx`
- App implementation review across:
  - `Forma File Organizing/Views/DashboardView.swift`
  - `Forma File Organizing/Views/MainContentView.swift`
  - `Forma File Organizing/Views/SidebarView.swift`
  - `Forma File Organizing/Views/RightPanelView.swift`
  - `Forma File Organizing/Views/InlineRuleBuilderView.swift`
  - `Forma File Organizing/Views/RulesManagementView.swift`
  - `Forma File Organizing/Views/ProductivityReportView.swift`
  - `Forma File Organizing/Views/Components/FileRow.swift`
  - `Forma File Organizing/Components/FileListRow.swift`
  - `Forma File Organizing/Components/FileGridItem.swift`
  - `Forma File Organizing/Views/Components/PrimaryBackgroundView.swift`
  - `Forma File Organizing/Views/Components/UnifiedToolbar.swift`
- Existing planning and review references:
  - `Docs/plans/2026-02-27-website-redesign-design.md`
  - `forma-website/REVIEW_VISUAL.md`
  - `forma-website/REVIEW_UX.md`

## 2. Direct Observations vs Inference

### Direct observations

- The website hero is clean and readable, but it is too calm and too generic for the product it is trying to sell.
- The current homepage loses momentum after the hero. The feature area feels pale and static, and the page reaches pricing/footer before the product story has earned the sale.
- The homepage is relying on fake UI fragments and lightweight demo styling where it should be using real product proof.
- The app has a stronger core product experience than the website communicates. The split-view shell, review queue, and keyboard-first workflow are credible.
- The app is visually over-filtered. Too much tint, material, sheen, and low-contrast chrome makes operational surfaces feel softer than the product logic.
- The inline rule builder is useful, but it reads like a sidebar form instead of the flagship workflow.
- Smart Rules and Analytics are structurally functional, but both feel more administrative than decisive.

### Inference from code and system shape

- The website currently carries two competing design directions: a static brochure-style homepage in `src/app/page.tsx` and a more ambitious componentized section system under `src/components/sections/`. That split is contributing to the brand hesitation.
- The website, onboarding flow, and main app are not speaking with one voice. The onboarding is soft and trust-heavy, the app is operational, and the website is currently neutral utility marketing.
- File presentation parity is drifting across `FileRow`, `FileListRow`, and `FileGridItem`. Core cues such as confidence, destination, rule context, and next action are not consistently exposed across view modes.

## 3. Creative Verdict

Forma is a better product than its public face.

The app already contains the beginnings of a premium, opinionated Mac tool: it is native, structured, and centered on review-before-action. The website does not project that. Right now the brand reads as "nice file organizer" instead of "the first file organizer that respects control." The redesign must sharpen that gap immediately.

### What is strong

- The core headline: "A file organizer for people who gave up on file organizers."
- The product thesis: write rules, preview changes, undo mistakes.
- The one-time price.
- The native macOS split-view shell and review queue architecture.

### What is weak

- Website distinctiveness, visual force, and narrative pacing.
- Screenshot/demo strategy.
- Website-to-app brand continuity.
- Rule builder authority and Smart Rules/Analytics triage.
- Contrast discipline inside the app's task surfaces.

## 4. Highest-Leverage Problems

### 1. The website looks like a tasteful utility brochure, not a defining product

- Surface: Homepage and marketing route shell.
- Why it hurts: Visitors can understand the category without feeling any urgency, conviction, or differentiation.
- Decision: Increase contrast, lead with real product proof, and remove neutral filler sections.

### 2. The narrative collapses after the hero

- Surface: Homepage section flow.
- Why it hurts: Pricing arrives before the product has demonstrated why it is safer or more effective than other organizers.
- Decision: Rebuild the flow around proof: thesis, trust, workflow, transformation, pricing/FAQ.

### 3. The screenshot strategy is underpowered

- Surface: Homepage, blog CTA blocks, and supporting routes.
- Why it hurts: Screenshots are not teaching the product. They decorate the page instead of explaining behavior.
- Decision: Replace fake UI fragments and passive screenshot framing with real review queue, preview, and undo sequences.

### 4. The website, onboarding, and app do not feel like the same product

- Surface: Cross-surface brand system.
- Why it hurts: The product feels indecisive. Trust, operational clarity, and premium polish are distributed unevenly instead of reinforcing each other.
- Decision: Unify on one voice: precise, local-first, native, anti-chaos, and preview-first.

### 5. The app shell is too washed out by material effects

- Surface: Dashboard, sidebar, content pane, inspector pane.
- Why it hurts: Work surfaces lose hierarchy, and important actions do not stand apart clearly enough.
- Decision: Keep material in the window shell; increase solidity and contrast on task surfaces.

### 6. The rule builder does not feel like the flagship feature

- Surface: Inline rule builder in the inspector.
- Why it hurts: The most differentiated behavior in the product is currently presented as a cramped side form.
- Decision: Turn the rule builder into a staged composer with stronger "When / Then / Impact" hierarchy and always-visible consequences.

### 7. Smart Rules and Analytics feel like admin screens

- Surface: `RulesManagementView` and `ProductivityReportView`.
- Why it hurts: They communicate maintenance and empty metrics instead of leverage and payoff.
- Decision: Reframe both around action and triage, not flat lists or low-signal dashboards.

### 8. File-view parity is not strict enough

- Surface: Card, list, and grid file presentation.
- Why it hurts: Users switching modes lose cues, and file-level features are at risk of being implemented unevenly.
- Decision: Standardize one shared metadata/action story across `FileRow`, `FileListRow`, and `FileGridItem`, and keep `MainContentView` wiring aligned.

## 5. Chosen Brand / Design Direction

### Product thesis

Forma is not selling "organization." It is selling controlled automation for people who do not trust file organizers anymore.

### Brand adjectives

- Exacting
- Native
- Premium
- Anti-chaos
- Trustworthy
- Surgical

### Visual direction

- Use stronger obsidian anchors and darker structural moments on the website instead of washing the entire experience in bone and pale gray.
- Keep the palette restrained: obsidian, bone, steel blue, sage, and warm orange. Use color to signal product meaning, not decoration.
- On marketing pages, body and UI copy should use a native-feeling sans stack tuned toward SF Pro / Inter. Add one restrained display face for short high-emphasis moments only. Do not build the whole site on editorial typography.
- In the app, keep SF Pro and native component behavior. Do not introduce a second visual personality inside product workflows.

### Layout philosophy

- Fewer sections, larger ideas.
- One strong idea per block.
- Real asymmetry and contrast, not stacked equal-weight cards.
- Product proof must appear before pricing.

### Motion philosophy

- Use one meaningful workflow demonstration rather than many ornamental reveals.
- Marketing motion must show files sorting, preview decisions, and undo reversal.
- App motion should reinforce action and state change, not atmosphere.

### Screenshot and demo strategy

- Homepage hero: real app screenshot or short loop with 2-3 annotations.
- Mid-page workflow: real sequence showing rule creation, preview, and undo.
- Before/after: real transformation case, not text-only filename lists.
- Supporting routes: screenshots must explain the product or route purpose; remove decorative empty chrome.

### CTA strategy

- Primary CTA stays `Download for Mac`.
- Hero, post-proof, and pricing CTA positions are mandatory.
- Price and trust context must sit near the first CTA.
- Remove competing low-value CTAs from the hero.

### Explicit remove / replace / amplify decisions

#### Remove

- Neutral trust-dot strips that do not carry real proof.
- Placeholder social-proof sections that do not contain actual credibility.
- Newsletter as a primary homepage conversion step.
- Text-only before/after filename blocks.
- Decorative screenshot shells that hide the product instead of revealing it.

#### Replace

- Replace passive feature cards with a real workflow story.
- Replace "website calmness" with sharper, more deliberate contrast.
- Replace admin-like Smart Rules grouping with action-oriented triage.
- Replace partial-empty analytics dashboards with coached states until the data is meaningful.

#### Amplify

- Preview-before-action as the signature behavior.
- Undo as a core product promise, not a footnote.
- One-time price, no account, local-only privacy.
- Native macOS feel across both the site and the app.

### Cross-surface alignment rules

- Use one core message everywhere: "write the rule, review the result, undo if needed."
- Use one action vocabulary everywhere: `Review`, `Organize`, `Undo`, `Rules`, `Download`.
- Use the same status logic and color meaning across site and app.
- Marketing pages should borrow the app's precision; the app should borrow the website's contrast discipline.

## 6. Website Structural Rewrite

The homepage becomes a shorter, harder-working funnel. Supporting routes keep the same shell, spacing rhythm, and proof-first copy discipline.

| Section | Purpose | Recommended layout | Cut | Add |
| --- | --- | --- | --- | --- |
| Hero | Establish thesis fast | Left: headline, sharp subhead, CTA + price/trust context. Right: real app proof with annotations. | Current passive brochure hero, extra neutral breathing room, low-value secondary CTA. | Real review-queue proof and visible price context. |
| Proof rail | Remove anxiety early | Four strong proof chips under hero: local-only, preview-first, undo built in, one-time purchase. | Generic trust-dot strip. | Short, high-contrast proof items with icons and one-line explanations. |
| Workflow demo | Show mechanism, not promises | Three-step sequence: write rule, review batch, undo reversal. Desktop can be horizontal; mobile stacks. | Static feature-card filler and fake fragments. | Real screenshots or short inline motion demonstrating state changes. |
| Before / After case study | Create identification and payoff | Real messy state vs organized result, with one concise narration line and files/time affected. | Text-only filename lists. | Real case visuals and a short "one rule did this" explanation. |
| Use cases | Prove range without feature dumping | Three or four use-case cards: screenshots, PDFs, imports, project files. | Repetitive explanatory paragraphs. | Specific examples of recurring clutter with one-line rules. |
| Pricing + FAQ | Close decisively | One price block with one-time purchase message beside an FAQ column or stacked FAQ immediately below. | Isolated pricing field with too much empty space. | Strong close, objection handling, and repeated CTA. |
| Footer + Guides | Support, SEO, and utility | Tighter footer with support/legal/guides; guides are no longer a homepage decision block. | Footer dead air and soft link presentation. | A tighter utility footer and route-consistent guide presentation. |

### Supporting route rules

- `/blog` and `/blog/[slug]` should feel like the same brand system, but quieter than the homepage.
- `/support` and `/get-forma` should be simple, direct, and operational.
- `/for-agents` should stay factual but must still look like it belongs to Forma.
- All routes must use the same typography, spacing, CTA logic, and surface contrast rules.

## 7. Website Copy Rewrites

### Core hero copy

- Eyebrow: `Preview-first file organization for Mac`
- Headline: `A file organizer for people who gave up on file organizers.`
- Subhead: `Write the rule in plain English. Review every move before it happens. Undo the whole batch if it's wrong.`
- Primary CTA: `Download for Mac`
- Secondary proof link: `Watch a real cleanup`
- Hero meta: `$29 once. Local-only. No account.`

### Proof rail copy

- `Local-only` - `Files stay on your Mac.`
- `Preview-first` - `Nothing moves until you approve it.`
- `Undo built in` - `Reverse a bad batch without damage control.`
- `One-time purchase` - `Pay once. Use it for years.`

### Workflow section copy

- Section label: `How Forma works`
- Headline: `Automation without blind trust.`
- Step 1: `Write the rule.`
- Step 1 body: `Describe the file pattern and destination in plain language.`
- Step 2: `Review the batch.`
- Step 2 body: `See every move before it happens. Keep files in or leave them out.`
- Step 3: `Undo if needed.`
- Step 3 body: `If the batch was wrong, reverse it. No archaeology. No panic.`

### Before / After copy

- Headline: `From pile to system.`
- Body: `One useful rule turns recurring clutter into something you can maintain.`

### Pricing copy

- Headline: `$29 once. Not another subscription.`
- Body: `No premium tier maze. No cloud tax. Just a native Mac utility you own.`
- CTA helper: `Requires macOS 15 or later.`

### Supporting route copy

- Blog index headline: `Guides for taming recurring file clutter on Mac`
- Blog post CTA heading: `Apply this workflow in Forma`
- Support headline: `Support without a ticket maze`
- Support body: `Send the problem, your macOS version, and what you expected. We will help you get unstuck.`
- Get Forma body: `Download the Mac app, then start with one rule and one folder.`
- For agents lead: `Public machine-readable endpoints for crawlers, agents, and integrations.`

## 8. App UX/UI Direction

### Keep

- Native `NavigationSplitView` shell and keyboard-first interactions.
- Review queue as the center of the product.
- The right panel as the place for focused secondary work.
- One-time, trust-heavy onboarding logic.

### Change

#### Window shell and pane hierarchy

- Reduce active-window blur, tint, sheen, and texture intensity in the dashboard panes.
- Keep visual richness in the outer shell, not inside task surfaces.
- Make content and inspector surfaces more solid so rows, forms, and calls to action separate clearly.

#### Center toolbar

- Keep the control set compact, but make mode changes feel more important.
- `Pending` vs `All Files` should read as a workflow mode, not a tiny control strip.
- Retain native macOS interaction models and keyboard shortcuts.

#### Review queue

- Push filename, destination, status, and confidence/rule provenance into one consistent visual order.
- Keep action hierarchy obvious: the next action should be visible without hovering, while secondary actions stay secondary.
- Preserve card/list/grid parity. Any file-level redesign must update:
  - `Views/Components/FileRow.swift`
  - `Components/FileListRow.swift`
  - `Components/FileGridItem.swift`
  - `Views/MainContentView.swift`

#### Right panel and rule builder

- Turn the rule builder into a staged composer with three zones: `When`, `Then`, and `Impact`.
- Make impact visible throughout editing: match count, sample files, risk note, and save readiness.
- Make the right panel feel like a task cockpit, not a settings drawer.

#### Smart Rules

- Group rules by action state: `Needs Attention`, `Recently Triggered`, `Stable`, `Disabled`.
- Surface access failures, last-triggered recency, and value delivered more clearly than flat ordering alone.

#### Analytics

- Treat analytics as proof of payoff, not dashboard theater.
- If data is weak or sparse, switch to setup coaching and action prompts instead of half-empty charts.

#### Onboarding

- Keep trust and clarity, but align voice with the sharper main product message.
- Onboarding should introduce controlled automation, not a separate "soft productivity" persona.

## 9. Implementation Guidance and Sequencing

### Phase 0 - Documentation and baseline capture

- Land this master brief and the first website validation plan.
- Capture baseline website screenshots and homepage scroll recordings before redesign implementation begins.

### Phase 1 - Website foundation

- Choose one marketing system and remove the competing homepage implementation pattern.
- Consolidate the website shell across `src/app/page.tsx`, `src/app/layout.tsx`, `src/components/Header.tsx`, `src/components/Footer.tsx`, and `src/app/globals.css`.
- Establish the stronger contrast, typography roles, and CTA pattern before refining sections.

### Phase 2 - Website story and proof

- Rebuild the homepage around the structural rewrite above.
- Replace fake fragments with real screenshots or short, meaningful product motion.
- Align blog/support/get-forma/for-agents pages to the same shell and copy discipline.

### Phase 3 - App shell polish

- Reduce pane material intensity in `Views/Components/PrimaryBackgroundView.swift`.
- Tighten hierarchy in `Views/Components/UnifiedToolbar.swift`, `Views/RightPanelView.swift`, and `Views/DefaultPanelView.swift`.
- Make the right panel and queue surfaces read as firmer work areas.

### Phase 4 - App workflow polish

- Rework `Views/InlineRuleBuilderView.swift`, `Views/RulesManagementView.swift`, and `Views/ProductivityReportView.swift` toward the direction in Section 8.
- Standardize file-level parity across card/list/grid and keep `Views/MainContentView.swift` wiring synchronized.

### Phase 5 - Validation and fix loop

- Run the website validation pass first.
- Fix website issues before starting app validation.
- Document the app validation pass after website direction is underway and product surfaces are stabilized.

### Implementation constraints for this cycle

- No public API, schema, or model contract changes are part of this documentation phase.
- The first execution sequence is website first, app second.
- Documentation, roadmap, and testing guidance must stay synchronized as implementation lands.

## 10. Validation Strategy Overview

The first validation pass is website-only and is documented in `Docs/Testing/2026-03-05-website-redesign-validation-plan.md`.

### Website-first validation goals

- Confirm first-screen comprehension.
- Confirm narrative continuity from hero to pricing.
- Confirm CTA visibility and repetition.
- Confirm screenshots explain the product instead of decorating it.
- Confirm route consistency across `/`, `/blog`, `/blog/[slug]`, `/support`, `/get-forma`, and `/for-agents`.
- Confirm responsive behavior at `390`, `768`, `1280`, and `1440` in light mode first.

### Required evidence

- Before/after screenshot pairs for required website surfaces.
- One desktop homepage scroll recording.
- One mobile homepage scroll recording.
- Route snapshots for all marketing pages.
- A short findings log with severity, evidence, and required fix.

### App validation sequencing

- The app validation plan is intentionally deferred.
- App validation will be documented after the website redesign direction is underway and the first website fix loop is complete.

## 11. Decisions Locked / Assumptions

- This is the single source-of-truth redesign brief for the current cycle.
- The website is the primary redesign surface. The app is the secondary surface, but the brief intentionally closes the brand gap between them.
- The first validation pass is website-only.
- The old February 27 website redesign plan is preserved for history but is no longer active.
- Newsletter and placeholder social-proof sections are removed from the primary homepage conversion path.
- Product proof must appear before pricing.
- Marketing pages use a native-feeling sans system for UI/body, one restrained display face for emphasis, and JetBrains Mono only where technical language adds clarity.
- The app keeps native macOS interactions and keyboard-first workflows; the redesign should sharpen them, not replace them.
- File-level UX changes must maintain parity across card/list/grid and their `MainContentView` call sites.
- `CHANGELOG.md` and `API_REFERENCE.md` remain untouched in this documentation phase because no shipped behavior or public interface changes are landing yet.
