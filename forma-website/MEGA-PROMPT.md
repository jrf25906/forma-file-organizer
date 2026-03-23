Refine and polish the Forma marketing website to best-in-class quality using every design and development tool available. This is a full design refinement pipeline: research, audit, polish, and perfect.

## PROJECT CONTEXT

- **Product**: Forma -- a file organizer for people who gave up on file organizers. macOS utility, $29 one-time purchase.
- **Target audience**: People who accumulate files faster than any system can contain — especially those with ADHD or executive function challenges. Also: Mac users who've tried and abandoned other file organizers, and anyone who periodically rage-cleans their desktop. The hero eyebrow ("For the perpetually messy") names this audience directly.
- **Brand tone**: Warm, self-aware, lightly funny. Humor comes from recognition ("Your desktop has 400 screenshots on it right now. Don't look."), not jokes. The product knows it's entering a graveyard of failed file organizers and leads with that honesty. Each section advances one argument — no repeating the same benefit across multiple sections.
- **SEO keywords**: ADHD-related terms (adhd file organization, adhd desktop clutter, file organizer for adhd, adhd productivity mac, executive function file management) are in meta keywords, llms.txt, product API, and schema markup — but not in visible copy.
- **CTA strategy**: Differentiated by context — "Get Forma" (header), "Get Forma for Mac" (hero), "Get Forma — $29" (pricing).
- **Existing site**: Next.js 16 + React 19 + TailwindCSS v4 + GSAP animations, deployed on Vercel at formafiles.com
- **What exists**: Full marketing homepage (9 sections), blog system, get-forma page, support page, privacy/terms pages, AI-consumable routes. This is already a polished site -- the goal is to take it from good to exceptional.
- **Design tokens**: Custom Forma palette (obsidian, bone white, steel blue, sage, warm orange, soft green, muted blue) defined in forma-design-tokens.ts and globals.css

## WHAT TO IMPROVE

- Elevate the homepage from "well-built marketing site" to "this feels like a premium Mac app's website" -- think Linear, Raycast, Arc Browser, CleanShot X quality
- Refine typography, spacing, and visual hierarchy across all pages
- Polish animations and transitions -- GSAP is already integrated, make every motion feel intentional and native-Mac-quality
- Fix the SocialProofSection (currently has placeholder design principles instead of real testimonials)
- Ensure the before/after demo section (FormaBeforeAfter) is compelling and clear
- Tighten the hero section -- the FormaHeroWindow component (1,128 lines) is a faithful HTML replica of the app; make sure it serves the marketing story
- Verify responsive behavior at all breakpoints
- Ensure dark/light mode both look premium (dark-mode-first design)
- Blog pages should feel editorial and polished, not generic

## YOUR CREATIVE AUTHORITY

You have full creative authority on this project. Do not be precious about my existing choices. Specifically:

- **If something I built looks mediocre, say so and replace it.** Don't preserve bad design decisions out of politeness. I'd rather you rip out a section and rebuild it than gently polish something that was wrong from the start.
- **Challenge the existing layout, hierarchy, and section order.** If sections are in the wrong order for the marketing story, reorder them. If a section doesn't earn its place, cut it. If the hero approach isn't the strongest lead, try something different.
- **The FormaHeroWindow is not sacred.** It's 1,128 lines of app replica. If the research shows that a simpler, more editorial hero converts better, replace it. Don't keep it just because it was a lot of work.
- **Replace copy that isn't sharp enough.** Headlines, CTAs, section intros -- if they're generic or soft, rewrite them to match the best-in-class references you find.
- **Change the visual system if needed.** If the current color balance, spacing rhythm, or typography hierarchy isn't working at the level of Linear/Raycast/Arc, adjust it. The design tokens are a starting point, not a constraint.
- **Delete sections that are filler.** Fewer strong sections beats more mediocre ones. If SocialProofSection has placeholder content and you can't make it compelling, remove it entirely rather than leaving it weak.
- **Be opinionated about animations.** If GSAP animations are gratuitous or don't serve the story, remove them. If new ones would help, add them. Motion should feel Mac-native and purposeful.

The goal is the best possible result, not preserving my ego. Treat this like you're the lead designer and I hired you to make it exceptional. I will not be offended by bold changes.

## EXECUTION PHASES

Work through these phases IN ORDER. Do not skip ahead.

### Phase 0: Design Context Setup
Run `/teach-impeccable` to establish design context for this project. Use these inputs:
- Audience: Mac power users, professionals, and creatives who care about their tools
- Brand personality: Conversational, honest, premium-but-approachable. Think Raycast or Linear's tone -- confident, developer-friendly, no corporate fluff
- Visual direction: Dark-mode-first, obsidian backgrounds, bone white text, steel blue accents. Clean, spacious, typographically driven. The site should feel like a native Mac app in the browser.
- Anti-patterns to avoid: Generic SaaS gradients, stock photo energy, "revolutionary" language, bouncy playful animations, oversized rounded corners, Framer template energy

### Phase 1: Research (Refero MCP + Refero Skill)
The Refero skill should auto-trigger here. Research:
- How premium macOS utility apps present their marketing sites (Linear, Raycast, Arc Browser, CleanShot X, Craft, Things 3, Bear)
- Landing page patterns from developer-tool and productivity-tool companies
- Before/after demonstration patterns from utility software
- Pricing presentation for one-time-purchase Mac apps
- Dark-mode-first marketing site design patterns

Search Refero for screens from: developer tools, macOS utilities, productivity apps, premium software landing pages. Study at least 30 screens. Extract: layout approaches, typography choices, how they present app UI in the browser, animation philosophy, CTA placement.

### Phase 2: Design Exploration (Paper MCP)
Using research findings, explore refinement directions in Paper. Focus on:
- Hero section: Is the current FormaHeroWindow approach (full app replica) the strongest lead, or should the hero be more editorial?
- Typography refinement: Is the current type hierarchy doing enough work?
- Spacing and rhythm: Does the page breathe properly between sections?
- Dark/light mode: Are both modes getting equal design attention?
- Motion philosophy: What should animate, and how? Mac-native feel = subtle, purposeful, no bounce.

### Phase 3: Implementation
Apply the refinements to the existing codebase. Rules:
- Use existing design tokens from `src/lib/forma-design-tokens.ts` and CSS custom properties in `globals.css`. Extend if needed, don't bypass.
- GSAP is the animation library -- use it consistently, no mixing with CSS keyframes for interactive animations
- TailwindCSS v4 for utility classes -- follow existing patterns in the codebase
- Components live in `src/components/` -- maintain the existing organization (sections/, animations/, features/, ui/)
- TypeScript strict -- no `any`, no unused variables
- Run `npm run build` after major changes to catch errors immediately
- Run `npm run lint` to verify code quality

### Phase 4: Design Refinement (Impeccable Pipeline)
Run these IN ORDER after implementation is functional:

1. `/audit` -- Find anti-patterns (template energy, inconsistent spacing, weak hierarchy, animation issues)
2. Fix everything flagged
3. `/polish` -- Refine spacing, alignment, visual hierarchy
4. Fix everything flagged
5. `/typeset` -- Fix typography (sizing, line height, font pairing, hierarchy)
6. Fix everything flagged
7. `/delight` -- Review micro-interactions, hover states, transitions. Ensure they feel Mac-native, not web-generic
8. Fix everything flagged
9. `/harden` -- Accessibility pass (contrast, keyboard nav, screen readers, ARIA). Dark mode contrast is critical.
10. Fix everything flagged
11. `/adapt` -- Responsive design across breakpoints. Mobile experience should feel intentional, not just "scaled down"
12. Fix everything flagged

After each Impeccable command, fix ALL flagged issues before moving to the next command.

### Phase 5: Animation Review (Emil Skill)
Review all GSAP animations and CSS transitions for:
- Appropriateness: Does each animation serve a purpose?
- Timing: Are easing curves and durations consistent?
- Performance: No janky or dropped-frame animations
- Mac-native feel: Subtle, confident motion. No bounce, no wobble, no playful spring physics unless justified.
- Scroll-triggered animations: Are they enhancing or distracting?

### Phase 6: Final Verification
- Run `npm run build` -- must succeed with zero errors
- Run `npm run lint` -- no lint errors
- Run `/audit` one final time -- zero critical issues
- Verify dark mode looks premium (not an afterthought)
- Verify light mode looks equally polished
- Verify responsive behavior at 320px, 768px, 1024px, 1440px widths
- Verify the FormaHeroWindow renders correctly at all sizes
- Check that all links work (App Store, support, blog, etc.)

## QUALITY GATES (enforce these throughout)

- Zero TypeScript errors (`npm run build` passes)
- No lint errors
- No `any` types anywhere
- Design tokens used consistently -- no hardcoded colors
- Tailwind classes follow existing patterns
- GSAP animations are performant (no layout thrash, use transforms)
- WCAG AA contrast ratios minimum (especially in dark mode)
- All images have alt text
- No AI-slop: no generic gradients, no "Get Started Free" energy, no Framer-template feel, no stock-photo aesthetics
- The site should feel like it was designed by someone who uses a Mac, for people who use a Mac
