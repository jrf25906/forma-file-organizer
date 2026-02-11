# Forma Marketing Website -- UX/Design Review

**Reviewer:** UI/UX Design Audit
**Date:** 2026-02-07
**Scope:** Full codebase review of `/forma-website/src/` -- all pages, sections, components, styles, animations, and infrastructure
**Site:** formafiles.com (Next.js 16 / React 19 / Tailwind v4 / GSAP)

---

## Executive Summary

The Forma website is a well-crafted, technically sophisticated single-page marketing site for a $29 macOS file organizer. The design language is restrained, confident, and appropriately Mac-native in feel. The information architecture follows a logical persuasion arc, the copy is sharp and personality-driven, and the accessibility foundations are stronger than most indie app sites.

That said, there are meaningful gaps between the site's current state and its conversion potential. Several animation systems are built but disabled. The CTA strategy has a critical fallback issue. The Before/After section undersells the product. And the page flow has a pacing problem in the middle that risks losing visitors before they reach pricing.

This review covers ten dimensions, each with specific findings and prioritized recommendations.

---

## Table of Contents

1. [Information Architecture](#1-information-architecture)
2. [User Journey & Conversion Path](#2-user-journey--conversion-path)
3. [Value Proposition Clarity](#3-value-proposition-clarity)
4. [Visual Hierarchy](#4-visual-hierarchy)
5. [Call-to-Action Strategy](#5-call-to-action-strategy)
6. [Content Strategy & Copy](#6-content-strategy--copy)
7. [Trust Signals & Social Proof](#7-trust-signals--social-proof)
8. [Interaction Design & Animation](#8-interaction-design--animation)
9. [Competitive Positioning](#9-competitive-positioning)
10. [Mobile Experience](#10-mobile-experience)

Appendix: [Priority Matrix](#priority-matrix)

---

## 1. Information Architecture

### Current Section Order

```
Header (sticky)
  Hero
  CredibilityStrip
  FeaturesSection
  BeforeAfterSection
  PricingSection
  FAQSection
  NewsletterSection
Footer
```

### What Works

- **The persuasion arc is sound.** Hero (problem + promise) -> Credibility (quick trust) -> Features (how it works) -> Before/After (empathy) -> Pricing (decision) -> FAQ (objection handling) -> Newsletter (retention). This follows established SaaS landing page patterns.
- **Anchor links in the header** (Features, Pricing, FAQ) let power users jump directly to the content they care about. This respects scanning behavior.
- **Legal pages** (Privacy, Terms, Support) are properly separated into their own routes rather than cluttering the main page.

### Issues & Recommendations

**[IA-1] Before/After is positioned too late (Medium Impact)**
The Before/After section creates emotional resonance ("Sound familiar?") but arrives *after* the features deep-dive. By the time visitors reach it, they have already waded through four detailed feature cards. Empathy-driven content is most effective before rational feature breakdowns.

*Recommendation:* Move BeforeAfterSection above FeaturesSection. The flow becomes: Hero (promise) -> Credibility (trust) -> Before/After (empathy, "this is you") -> Features (the solution) -> Pricing (commit). This mirrors the problem-agitation-solution framework more cleanly.

**[IA-2] No "How it works" anchor exists for the hero CTA (Low Impact)**
The hero has a "See how it works" button linking to `#features`, but the features section heading says "How it actually works." The anchor could benefit from its own visible label or landing point so the scroll destination feels intentional rather than landing mid-section.

**[IA-3] Newsletter section feels disconnected from the conversion flow (Low Impact)**
After FAQ, the user has either decided to buy or not. The newsletter section ("Stay in the loop") does not reinforce the purchase decision and introduces a new ask without clear value differentiation from the download CTA.

*Recommendation:* Consider reframing the newsletter as a post-purchase relationship builder ("Get tips for your new Forma setup") or moving it into the footer as a compact inline form. The current full-section treatment gives it equal visual weight to pricing, which dilutes the conversion focus.

---

## 2. User Journey & Conversion Path

### Primary User Flow

```
Land on page
  -> Read headline (understand what this is)
  -> Scan credibility badges (quick trust)
  -> Scroll through features (understand value)
  -> See Before/After (feel understood)
  -> Reach pricing (make decision)
  -> Click "Download for Mac" -> Mac App Store (or /support fallback)
```

### What Works

- **Two clear paths from the hero:** "Download for Mac" (ready to buy) and "See how it works" (need more info). This is textbook dual-CTA placement.
- **The pricing CTA is a full Mac App Store badge** with the familiar two-line "Download on the / Mac App Store" pattern. Users recognize this instantly.
- **Smooth scroll behavior** with 100px offset keeps the sticky header from occluding content when jumping to anchors.

### Issues & Recommendations

**[UJ-1] CRITICAL: CTA fallback goes to /support, not an informative landing (High Impact)**
In `links.ts`, when `NEXT_PUBLIC_MAC_APP_STORE_URL` is not configured (or is the placeholder), all "Download for Mac" buttons link to `/support`. The support page is a minimal troubleshooting page with an email address. A visitor who clicks the primary CTA and lands on a support page will be confused and likely bounce.

*Recommendation:* Create a dedicated pre-launch or waitlist page (e.g., `/get-forma`) that explains the app is coming to the Mac App Store, captures email interest, and sets expectations. Alternatively, link to the newsletter signup anchor (`#newsletter`) as the fallback, which at least captures the lead.

**[UJ-2] No pricing is visible until deep scroll (Medium Impact)**
The hero mentions no price. The credibility strip mentions no price. A visitor has to scroll through approximately four screen heights of content before learning the app costs $29. Many competitive landing pages surface price early (even in the hero subtext) to pre-qualify visitors and reduce "what's the catch" anxiety.

*Recommendation:* Add a subtle price mention in the hero area. The meta description already does this well: "A file organizer for people who gave up on file organizers... $29 once, forever." That same line could appear as a small badge or subtext near the CTA buttons.

**[UJ-3] No free trial or freemium mention anywhere (Medium Impact)**
There is no mention of a free trial, demo, or freemium tier. For a $29 utility, some users will want to try before buying. If a trial exists (even via the Mac App Store), this should be mentioned prominently. If not, the FAQ should address why ("Why no free trial?").

---

## 3. Value Proposition Clarity

### Hero Copy Analysis

> **A file organizer for people who gave up on file organizers.**
>
> Your desktop is a dumping ground. Your Downloads folder is worse. You've tried to fix it before.
>
> You make rules. Forma follows them. Preview what's about to happen, approve it, and it's done. If you don't like it, undo it.

### What Works

- **The headline is outstanding.** It immediately communicates the target audience (frustrated people who have tried and failed) and positions Forma as different from everything that came before. This is the single strongest element on the page.
- **The two-paragraph structure** works well: first paragraph is empathy (problem), second is mechanism (solution). The rhythm of short sentences creates urgency.
- **The tagline in metadata** ("Give your files form") is clever branding but wisely not used as the hero headline, which prioritizes clarity over cleverness.

### Issues & Recommendations

**[VP-1] The solution paragraph buries the differentiator (Medium Impact)**
"You make rules. Forma follows them." is the core value proposition, but it reads as one detail among several. The preview-and-approve workflow and the undo capability are equally important differentiators, but they run together in a single paragraph.

*Recommendation:* Consider giving the preview/approve/undo workflow its own visual emphasis -- perhaps as three short inline items with subtle separators, or as a brief animated sequence. The mechanism is what makes Forma different from "just another auto-organizer," and it deserves more visual weight.

**[VP-2] "Built for messy desktops" badge is too narrow (Low Impact)**
The pill badge above the headline says "Built for messy desktops." While it is catchy, it scopes the product's utility to desktop cleanup specifically. Many users likely also need Downloads, Documents, and project folder organization. The badge could be broader.

*Recommendation:* Consider alternatives like "For the chronically disorganized" or "File organization, finally" that do not limit the perceived use case.

---

## 4. Visual Hierarchy

### What Works

- **Typography system is excellent.** Instrument Serif for display/headings, DM Sans for body, JetBrains Mono for code/file names. The serif display font gives the site an editorial quality that feels premium and distinct from typical SaaS sites.
- **Color palette is restrained and purposeful.** Steel Blue, Sage, and Warm Orange are used consistently for accent coding (features, states, actions). The Obsidian/Bone base provides high contrast.
- **The site container** (`max-width: 1160px`, fluid padding via `clamp()`) keeps content comfortably readable across all viewport widths.
- **Section spacing** is generous without being wasteful. The `py-24 md:py-32` rhythm creates clear content separation.

### Issues & Recommendations

**[VH-1] Feature cards lack visual differentiation between them (Medium Impact)**
All four feature cards in `FeaturesSection` share identical visual treatment: same border, same background, same shadow, same layout. The interactive previews inside them are the only visual differentiators, but they are small and secondary to the text. On a long scroll, these cards blur together.

*Recommendation:* Use the existing accent color system more aggressively. Each feature already has an `accentBg` and `accentText` -- consider extending this to a subtle left border stripe, a tinted top edge, or a colored icon background that is more visually prominent. Even a slight background tint difference between cards would help scanning.

**[VH-2] The hero screenshot is strong but lacks annotation (Medium Impact)**
The MacWindowFrame with the app screenshot is the visual anchor of the hero section. However, the screenshot alone requires the user to parse a complex UI to understand what they are looking at. There are no callouts, labels, or highlighted regions.

*Recommendation:* Consider overlaying two or three minimal callout labels (e.g., "Your rules," "Preview before moving," "Undo anything") on or near the screenshot. These reinforce the value proposition while giving the image educational context.

**[VH-3] Credibility badges are visually lightweight (Low Impact)**
The three credibility badges (Mac-Native, Privacy-First, Always Reversible) use a subtle rounded-rectangle style with small icons. They are easy to scroll past without registering. These are important trust signals that deserve slightly more visual presence.

*Recommendation:* Increase badge prominence slightly -- either through a subtle background band behind them, slightly larger icons, or a brief separator line above/below the strip to create a visual "pause point."

---

## 5. Call-to-Action Strategy

### CTA Inventory

| Location | CTA Text | Style | Target |
|----------|----------|-------|--------|
| Header (desktop) | "Download for Mac" | Dark pill button | Mac App Store (or /support) |
| Header (mobile menu) | "Download for Mac" | Dark full-width button | Mac App Store (or /support) |
| Hero | "Download for Mac" + Apple logo | Dark rounded button | Mac App Store (or /support) |
| Hero | "See how it works" | Light outlined button | #features |
| Pricing | "Download on the / Mac App Store" | Dark badge-style button | Mac App Store (or /support) |
| Newsletter | "Subscribe" | Dark button | Newsletter API |
| Footer | "hello@formafiles.com" | Text link | Email |

### What Works

- **The primary CTA ("Download for Mac") is consistent** across all placements -- same copy, same visual weight. Users never have to wonder what the main action is.
- **The hero dual-CTA pattern** (primary action + softer exploration) is well-executed. The visual hierarchy between the dark primary and light secondary button is clear.
- **The pricing section CTA** uses the recognizable Mac App Store badge pattern with the Apple logo, which adds platform trust.

### Issues & Recommendations

**[CTA-1] No CTA exists between Features and Pricing (High Impact)**
After scrolling through four detailed feature cards and the Before/After section, there is no intermediate "Download" or "Try it" prompt. This is a significant conversion gap. Visitors who are convinced after the Features section have to keep scrolling to find a CTA.

*Recommendation:* Add a compact CTA row after the Features section (or after Before/After). This can be a simple centered line: "Ready to get organized?" with a "Download for Mac" button. Keep it lightweight -- a full section is not needed, just a prompt.

**[CTA-2] The header CTA disappears on mobile until the menu is opened (Medium Impact)**
On mobile (`md:hidden`), the "Download for Mac" button only appears inside the hamburger menu. Once the hero scrolls out of view, there is no persistent CTA visible. The sticky header on mobile shows only the logo and hamburger icon.

*Recommendation:* Show the "Download for Mac" button in the sticky header on mobile as well, even if it needs to be more compact (icon-only or shortened text). Alternatively, add a floating CTA button that appears after the user scrolls past the hero.

**[CTA-3] "See how it works" anchor does not have a visual landing indicator (Low Impact)**
Clicking "See how it works" smooth-scrolls to `#features`, but the scroll destination does not have a visual "you are here" indicator. Users who click this CTA may not immediately realize they have arrived at the target content.

---

## 6. Content Strategy & Copy

### What Works

- **The voice is distinctive and human.** Lines like "A file organizer for people who gave up on file organizers" and "use it until your Mac turns to dust" have personality without trying too hard. This is a clear competitive advantage over enterprise-toned competitors.
- **The FAQ answers are direct and honest.** "No. Forma only moves files -- it never deletes anything" directly addresses the scariest concern first. The answers are short and do not over-explain.
- **Feature descriptions avoid jargon.** "Tell it what to do in plain English" is much more effective than "NLP-powered rule engine" for the target audience.
- **The footer bio** ("Built by someone who got tired of seeing `Screenshot 2024-01-15 at 3.42.17 PM.png` fifty times on their desktop") is a perfect founder-voice moment that builds authenticity.

### Issues & Recommendations

**[CS-1] Feature section heading "How it actually works" sets an explanatory expectation it only partially fulfills (Medium Impact)**
The heading implies a walkthrough or workflow demonstration, but the section delivers four feature cards with static previews. The previews are labeled "Live preview" but they are not interactive or animated -- they are static mockups. This creates a subtle expectation mismatch.

*Recommendation:* Either rename the section heading to something like "What makes it different" or "Four things that matter," or make the previews genuinely interactive (e.g., clicking the undo buttons, toggling checkboxes in the control preview). If neither is feasible, remove the "Live preview" label and replace it with "Example" or drop it entirely.

**[CS-2] Before/After section is too abstract (Medium Impact)**
The "Before" card shows six filenames. The "After" card shows three folder names with file counts. While the concept is clear, the transformation is too minimal to create an emotional reaction. The file names are realistic, but the "After" state does not show *where* those specific files went. The connection between the two states is implicit.

*Recommendation:* Make the mapping explicit. Show arrows, color coding, or a transition that visually connects "Screenshot 2024-01-15 at 3.42.17 PM.png" from the Before list to "Screenshots/ 3 files" in the After list. The Before/After pattern is most powerful when the transformation is visually traceable.

**[CS-3] Newsletter copy does not offer enough value (Low Impact)**
"Updates on new features, tips, and the occasional file organization joke" is pleasant but generic. It does not communicate what the reader gets that they cannot get elsewhere.

*Recommendation:* Be more specific: "Workflow ideas, new rules to try, and updates when features ship. One email a month, max." This sets frequency expectations and implies practical value.

---

## 7. Trust Signals & Social Proof

### Current Trust Elements

- Three credibility badges (Mac-Native, Privacy-First, Always Reversible)
- Privacy messaging in FAQ ("Everything runs locally on your Mac")
- "Mac App Store" association (implies Apple review/approval)
- Structured data with schema.org SoftwareApplication markup
- Dedicated Privacy Policy and Terms pages
- "No subscription" anti-pattern messaging

### What Works

- **The privacy story is woven throughout**, not isolated to a single section. It appears in the credibility strip, the FAQ, the feature descriptions, and the pricing section. This repetition across contexts builds genuine trust.
- **The "No subscription" positioning** is smart counterprogramming against the current SaaS fatigue. "$29. Once. Forever." is a memorable pricing statement.
- **The Mac App Store distribution** is itself a trust signal that many indie apps lack.

### Issues & Recommendations

**[TS-1] No social proof exists anywhere on the page (High Impact)**
There are zero testimonials, zero review counts, zero download numbers, zero press mentions, and zero "as seen in" badges. For a paid product, this is a significant trust gap. Even a single honest testimonial from a beta tester would help.

*Recommendation:* This is the single highest-impact addition the site could make. Options in order of feasibility:
  1. **Beta tester quotes** -- even 2-3 short quotes with first names are effective.
  2. **Mac App Store rating** -- once available, surface the star rating and review count.
  3. **"Built by" founder section** -- a brief personal introduction with a photo humanizes the product. The footer already hints at this voice.
  4. **Specific usage stats** -- "X files organized" or similar, if tracked.

**[TS-2] No app screenshots beyond the hero (Medium Impact)**
The hero has one screenshot inside a MacWindowFrame. The rest of the page uses text descriptions and small static previews. For a visual product (file organization is inherently spatial), more screenshots showing different app states would significantly build confidence.

*Recommendation:* Add 1-2 additional screenshots in context. The Features section or Before/After section are natural placement points. Show the rule editor, the preview panel, or the undo history timeline as real app screenshots rather than abstract mockups.

**[TS-3] Privacy Policy and Terms feel like dark-theme content on a light-theme site (Low Impact)**
The legal pages use `text-forma-bone` (the light text color) and `glass-card` styling that assumes a dark background. However, the site ships in light-only mode (`ThemeProvider` always returns `"light"`). This means the legal pages may have readability issues with light text on light backgrounds.

*Recommendation:* Verify the legal pages render correctly in the light theme. The `[data-theme="light"] .text-forma-bone` override in `globals.css` should handle this, but the glass-card backgrounds and orb decorations may also need verification.

---

## 8. Interaction Design & Animation

### Animation Systems Inventory

The site has an extensive animation toolkit built but largely **disabled**:

| System | Built | Active |
|--------|-------|--------|
| GSAP ScrollTrigger reveals | Yes | **No** (`enableScrollAnimations = false` in every section) |
| Lenis smooth scroll | Yes | **Not wired** (LenisGSAPProvider is defined but not used in layout) |
| TiltCard (3D hover) | Yes | **Yes** (BeforeAfterSection only) |
| SpotlightCursor | Yes | **Not used** on any page |
| MagneticButton | Yes | **Not used** on any page |
| AuroraBackground | Yes | **Not used** on any page |
| HoverScale | Yes | **Not used** on any page |
| RevealText | Yes | **Not used** on any page |
| ScrollReveal | Yes | **Not used** on any page |
| LottieAnimation | Yes | **Not used** on any page |
| CSS stagger animations | Yes | **Not used** (requires `.visible` class toggle) |

### What Works

- **The decision to ship with animations disabled was probably wise** for initial launch -- it ensures content is visible, accessible, and performant without debugging animation timing issues.
- **`prefers-reduced-motion` is respected** both in CSS (`@media` block in globals.css) and in JavaScript (every hook/component checks). This is exemplary accessibility practice.
- **Touch device detection** disables tilt effects on mobile, which is correct behavior.
- **The TiltCard on Before/After cards** is a nice touch that adds physicality without overwhelming.

### Issues & Recommendations

**[ID-1] The site currently ships with almost no motion, creating a flat static feel (High Impact)**
With `enableScrollAnimations = false` in every section component, the page loads with all content immediately visible and static. There is no scroll-driven reveal, no staggered entrance, no parallax -- just a long static page. For a product that emphasizes being "modern" and "Mac-native," the site feels surprisingly inert.

*Recommendation:* Enable scroll animations selectively. The GSAP ScrollTrigger infrastructure is already built and well-tested. Start with:
  1. Staggered fade-up on the CredibilityStrip badges
  2. Headline reveals on FeaturesSection and PricingSection
  3. Left/right slide-in on the Before/After cards

Keep animation durations short (the existing `formaDuration.fast = 0.4s` is appropriate) and ensure all animations have `once: true` behavior so they do not reverse on scroll-back, which can feel disorienting.

**[ID-2] Button hover states rely solely on color change (Low Impact)**
The hero CTA and pricing CTA have `hover:bg-forma-obsidian/90` -- a 10% opacity reduction. This is extremely subtle and may not register as interactive feedback on many displays. The CSS `btn-primary` class has a `translateY(-2px)` on hover, but this class is not used on the actual CTA buttons.

*Recommendation:* Add a subtle `translateY(-1px)` and `shadow` increase on hover to the primary CTA buttons. The existing `hover:scale-[1.02]` on the pricing CTA is good -- extend this treatment to the hero CTA for consistency.

**[ID-3] FAQ accordion animation is smooth but could have a focus indicator (Low Impact)**
The FAQ uses GSAP `height` animation for open/close, which is well-implemented. However, the toggle button does not have an `id` attribute matching the `aria-labelledby` on the answer region, which means the ARIA relationship is incomplete.

*Recommendation:* Add `id={`faq-question-${index}`}` to the question `<button>` or its text `<span>` to complete the ARIA pattern.

---

## 9. Competitive Positioning

### Market Context

Forma competes in the macOS file organization space alongside:
- **Hazel** (Noodlesoft) -- the established incumbent, rule-based, $42
- **Default Folder X** -- Finder enhancement, $34.95
- **Clean My Mac** (MacPaw) -- broader cleanup utility, subscription
- **Built-in Finder Smart Folders / Automator** -- free but limited

### What Works

- **"For people who gave up on file organizers"** is brilliant positioning that directly calls out the target segment (people who tried Hazel or Automator and gave up because it was too complex). This is a challenger brand move.
- **$29 one-time pricing** undercuts Hazel ($42) and avoids the subscription fatigue of CleanMyMac. The "no subscription" messaging is repeated three times across the page.
- **"Natural language rules"** is a clear differentiator against Hazel's condition-based UI, which has a learning curve. Forma positions itself as the simpler alternative.
- **"Preview before moving"** addresses a real fear that automated file movers generate -- "what if it messes up my files?" The preview-and-approve workflow is a genuine UX innovation worth highlighting more.

### Issues & Recommendations

**[CP-1] The site never mentions competitors by name or category (Medium Impact)**
The headline implies competitive awareness ("gave up on file organizers"), but the page never explicitly positions against alternatives. A user comparing Forma to Hazel has no on-site comparison to reference.

*Recommendation:* This does not need to be aggressive. A single FAQ entry like "How is this different from Hazel / other file organizers?" with a concise, respectful answer would help users who are actively comparing. Frame it around Forma's strengths (simplicity, plain-English rules, preview, price) rather than competitor weaknesses.

**[CP-2] The "Mac-native Swift" credential is mentioned but not demonstrated (Low Impact)**
The credibility strip says "Mac-Native: Built with Swift for macOS" and the pricing section says "Mac-native Swift -- not another Electron wrapper." This is a meaningful differentiator, but it is stated rather than shown.

*Recommendation:* Reinforce this with visual cues. The MacWindowFrame in the hero helps. Additional touches could include showing macOS system integration (menu bar, notifications, Finder integration) in screenshots or feature previews.

---

## 10. Mobile Experience

### Responsive Architecture

- **Breakpoints:** Tailwind defaults + custom `tablet: 900px` and `3xl: 1920px`
- **Layout strategy:** Single-column mobile, expanding to multi-column at `md` (768px) or `tablet` (900px)
- **Touch accommodations:** `@media (pointer: coarse)` enforces 44px minimum touch targets; TiltCard disables on touch devices
- **Mobile navigation:** Hamburger menu with slide-down panel, overlay backdrop, proper `aria-expanded` state

### What Works

- **The 44px touch target rule** in CSS is a strong accessibility baseline that many sites miss.
- **The mobile menu** is well-implemented with proper backdrop, smooth animation, and closes on link click.
- **Content reflow** is handled sensibly: feature cards stack vertically, Before/After cards stack to single column, pricing feature grid goes to single column.
- **Hero text sizing** scales appropriately: `text-[2.45rem]` -> `sm:text-[2.95rem]` -> `lg:text-[3.45rem]`. This avoids the common problem of oversized hero text on small screens.

### Issues & Recommendations

**[ME-1] No mobile-specific CTA visibility after scrolling past the hero (High Impact)**
As noted in CTA-2, once a mobile user scrolls past the hero, there is no visible download button until they reach the pricing section (approximately 5+ screen heights away) or open the hamburger menu. Mobile users are especially unlikely to open navigation menus just to find a buy button.

*Recommendation:* Implement one of:
  1. A compact download button in the mobile sticky header
  2. A floating action button (FAB) that appears after scrolling 1 viewport height
  3. An interim CTA row between the Features and Before/After sections

**[ME-2] Feature card previews may be difficult to read on small screens (Medium Impact)**
The feature preview components (`RulePreview`, `ConnectionPreview`, `ControlPreview`, `UndoPreview`) use very small text sizes (`text-[10px]`, `text-[11px]`, `text-[12px]`). On mobile, these render at their literal pixel sizes. The `font-mono` text at 10px may be below the comfortable reading threshold for many users.

*Recommendation:* Set a mobile-specific minimum of 12px for preview text. Consider using `text-xs` (12px) as the floor instead of custom 10px sizes. Alternatively, simplify the mobile preview to show fewer items.

**[ME-3] Before/After cards are tall and similar-looking on mobile (Low Impact)**
When stacked vertically on mobile, both cards use the same white background and rounded border. The "Before" and "After" labels are small uppercase text that is easy to miss. On a small screen, a user may not immediately grasp the comparison structure.

*Recommendation:* Add a visual connector between the cards on mobile -- a centered arrow or "Forma transforms this" interstitial -- so the Before->After relationship is explicit even when the cards are not side by side.

---

## Priority Matrix

### High Impact (Do First)

| ID | Finding | Effort |
|----|---------|--------|
| UJ-1 | CTA fallback links to /support instead of a meaningful page | Low |
| TS-1 | No social proof anywhere on the page | Medium |
| CTA-1 | No CTA between Features and Pricing | Low |
| ME-1 | No mobile CTA visible after scrolling past hero | Medium |
| ID-1 | All scroll animations are disabled, creating a flat static feel | Low (infrastructure is built) |

### Medium Impact (Do Next)

| ID | Finding | Effort |
|----|---------|--------|
| IA-1 | Before/After positioned too late in the page flow | Low |
| UJ-2 | Price not visible until deep scroll | Low |
| UJ-3 | No free trial mention or explanation of absence | Low |
| VH-1 | Feature cards lack visual differentiation | Low |
| VH-2 | Hero screenshot lacks annotation callouts | Medium |
| CS-1 | "How it actually works" heading sets unmet expectations | Low |
| CS-2 | Before/After transformation is too abstract | Medium |
| TS-2 | Only one app screenshot on the entire page | Medium |
| CP-1 | No competitive positioning in FAQ | Low |
| CTA-2 | Header CTA hidden on mobile | Medium |
| ME-2 | Feature preview text too small on mobile | Low |

### Low Impact (Polish)

| ID | Finding | Effort |
|----|---------|--------|
| IA-2 | "See how it works" anchor lacks visual landing indicator | Low |
| IA-3 | Newsletter section dilutes conversion focus | Medium |
| VP-2 | "Built for messy desktops" badge is too narrow | Low |
| VH-3 | Credibility badges are visually lightweight | Low |
| CS-3 | Newsletter copy lacks specific value | Low |
| TS-3 | Legal pages may have light-on-light readability issues | Low |
| CTA-3 | No visual arrival indicator for anchor scrolls | Low |
| ID-2 | Button hover states are too subtle | Low |
| ID-3 | FAQ ARIA pattern is incomplete | Low |
| CP-2 | Mac-native claim is stated but not demonstrated | Medium |
| ME-3 | Before/After lacks visual connector on mobile | Low |

---

## Technical Notes

**Infrastructure quality is high.** The codebase is well-organized with clean separation of concerns (sections, UI components, animation components, hooks, lib). TypeScript is used throughout with proper typing. The animation system architecture (GSAP config, ease curves, Lenis scroll, component wrappers) is professional-grade and ready to enable incrementally.

**SEO foundations are solid.** Structured data, sitemap, robots.txt, Open Graph, Twitter cards, and proper meta descriptions are all in place. The semantic HTML uses proper heading hierarchy, landmark roles, and ARIA attributes.

**Performance considerations are thoughtful.** Font loading uses `display: swap` with `adjustFontFallback`, images use Next.js `Image` with `priority` for above-the-fold content, and CSS animations are GPU-accelerated via transforms.

**Dark mode is built but disabled.** The CSS has extensive dark mode overrides via `[data-theme="dark"]`, but the `ThemeProvider` always returns `"light"`. This is a deliberate choice for the marketing site, which is appropriate -- dark mode on marketing pages is a distraction from conversion optimization unless the product itself is dark-themed.

---

*End of review.*
