# Forma - Brand Overview

**Last Updated:** February 2026
**Status:** Design System Implemented, Visual Identity Finalized
**Strategic Foundation:** See [BRAND-POSITIONING.md](BRAND-POSITIONING.md) for messaging source of truth

---

## Quick Reference

**Brand Name:** Forma
**Brand Tagline:** "Give your files form" *(brand-level; used in app, packaging, brand contexts)*
**Website Tagline:** "A file organizer that actually sticks" *(website `SITE_TAGLINE`; see rationale below)*
**Website OG Headline:** "A file organizer for people who gave up on file organizers" *(OG title, metadata, social cards)*
**Positioning:** A structural system layer for macOS files — not a replacement for Finder, but an executor of your intent
**Target Behavior:** People whose files outgrow folders — where screenshots, documents, assets, and ideas pile up faster than folders can handle

> **Note (Feb 2026):** The website now uses a distinct tagline from the brand-level tagline. "Give your files form" is elegant but doesn't communicate the product's value proposition to cold traffic. The website headline targets people who've already tried and failed with other organizers — a higher-intent audience. The brand tagline remains appropriate for in-app, packaging, and contexts where the user already knows Forma.

---

## The Core Reframe

**Forma is STRUCTURAL, not INTELLIGENT.**

Users don't ask: "Is this smart?"
They ask: "Where does this sit in my system?"

**Forma is:**
- A **system layer** on top of Finder, not a replacement
- An **executor of intent**, not an autonomous actor
- A **bounded tool**, not a magical one

**Winning Posture:**
> You give the orders. Forma executes them — and only after you approve.

---

## Trust Hierarchy (Messaging Order)

Lead with control. Follow with capability.

1. **You approve. It executes.** — Nothing moves without explicit approval
2. **Undo everything. Always.** — Full reversibility, complete action history
3. **Declarative rules.** — You define the logic in plain language
4. **Context awareness.** — Forma infers structure but never assumes

---

## Brand Attributes

### Core Personality Traits
- ✨ **Design-forward** - Proudly visual, confident in its aesthetics
- 🎯 **Confident** - Opinionated defaults, no hedging or uncertainty
- 💎 **Sophisticated** - Layered depth, thoughtful materials, refined details
- 🔧 **Precise** - Pattern-matched suggestions, inspectable logic
- ⚡ **Capable** - Powerful features accessible through elegant UI

### Emotional Journey
1. **Trusted** → Preview before commit, undo available, no surprises
2. **Impressed** → The app looks and feels premium from first launch
3. **Empowered** → Powerful tools feel accessible, not overwhelming
4. **Satisfied** → Organization feels good, progress is visible

---

## Language Guidelines

### Avoid "Ghost of AI" Language

| Avoid | Use Instead |
|-------|-------------|
| "Talk to it like a human" | "Declarative rules" or "Intent-based commands" |
| "AI-powered organization" | "Rule-based organization" |
| "Smart suggestions" | "Pattern-matched suggestions" |
| "Learns your preferences" | "Adapts to your corrections" |
| "Understands your files" | "Infers structure from patterns" |

### Replace Absolutes with Capabilities

| Avoid | Use Instead |
|-------|-------------|
| "Never lose anything again" | "Full action history with one-click rollback" |
| "Zero files lost. Ever." | "Preview every change before it happens" |
| "Always organizes perfectly" | "Suggests destinations based on your rules" |

### Voice Principles
- **Clear, not clever** - Function over wordplay
- **Specific, not vague** - "Move to Documents" not "Organize"
- **Active voice** - Imperative mood ("Move file" not "File will be moved")
- **Sentence case** - No Title Case, No ALL CAPS
- **Confident tone** - No hedging ("will" not "should")

---

## Design System (Implemented)

### Visual Language
**Code Location:** `/Forma File Organizing/DesignSystem/`

Forma uses a **layered material design** approach:
- Frosted glass backgrounds (`.thickMaterial`, `.ultraThinMaterial`)
- Subtle depth through shadows and borders
- Translucent overlays for modals and panels
- Native macOS vibrancy effects

### Colors
| Color | Value | Usage |
|-------|-------|-------|
| Obsidian | `#1A1A1A` | Primary text, dark elements |
| Bone White | `#FAFAF8` | Light backgrounds, text on dark |
| Steel Blue | `#5B7C99` | Interactive elements, primary actions |
| Sage | `#7A9D7E` | Success states, confirmations |
| Muted Blue | `#6B8CA8` | Documents category |
| Warm Orange | `#C97E66` | Media/Images category |
| Soft Green | `#8BA688` | Downloads/Archives category |

### Typography

#### macOS App
**Font:** SF Pro (system font)

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Hero | 32pt | Bold | Headlines |
| H1 | 24pt | Semibold | Section headers |
| H2 | 20pt | Semibold | Subsection headers |
| H3 | 17pt | Medium | Card titles |
| Body | 13pt | Regular | Body text, UI |
| Small | 11pt | Regular | Metadata, captions |

#### Website
**Display Font:** Libre Baskerville (serif) — Headlines, hero text, marketing emphasis
**Body Font:** Inter (sans-serif) — Body text, UI labels, descriptions

| Style | Font | Weight | Usage |
|-------|------|--------|-------|
| Hero | Libre Baskerville | Bold | Page headlines, hero sections |
| H1-H3 | Libre Baskerville | Regular/Bold | Section headers |
| Body | Inter | Regular | Body text, descriptions |
| UI Text | Inter | Medium/Semibold | Buttons, labels, navigation |

### Spacing
**System:** 8pt grid (FormaSpacing)

| Name | Value | Usage |
|------|-------|-------|
| Micro | 4px | Tight spacing |
| Tight | 8px | Related elements |
| Standard | 12px | Default spacing |
| Generous | 16px | Breathing room |
| Large | 20px | Section separation |
| Extra Large | 24px | Panel padding |

### Materials & Effects
- **Window background:** `.thickMaterial` for frosted glass effect
- **Cards:** Subtle shadows with rounded corners (10px)
- **Modals:** Blur backdrop (10px) with semi-transparent overlay
- **Transitions:** Spring animations (0.5s response, 0.85 damping)

### Icons
| Context | Library | Notes |
|---------|---------|-------|
| macOS App | SF Symbols | Native, weight-matched to SF Pro |
| Website | [Phosphor](https://phosphoricons.com) | 6 weights, matches SF Symbols flexibility |

---

## Value Pillars (With Proof)

| Pillar | Proof |
|--------|-------|
| **Mac-native** | Fast and lightweight — built natively for macOS. |
| **Private** | On-device processing. Files never leave your Mac. |
| **Fast** | Launches and previews in milliseconds on Apple Silicon. |
| **Reversible** | Full action history with one-click rollback. |
| **Transparent** | Preview every change before it happens. |

> **Note (Feb 2026):** "No Electron" was replaced with user-facing benefit language on the website. The technical distinction still matters for developer audiences (HN, technical press) but isn't meaningful to most users. Use "Fast and lightweight — built natively for macOS" for general audiences; reserve "No Electron" for technical contexts only.

---

## What Forma IS

✅ **Structural** - A system layer, not autonomous AI
✅ **Design-forward** - Visual sophistication is part of the product
✅ **Layered & material** - Uses depth, glass, translucency intentionally
✅ **Keyboard-first** - Power users can fly through with shortcuts
✅ **Native macOS** - Embraces platform conventions and materials
✅ **Confident** - Opinionated defaults, clear recommendations

## What Forma Is NOT

❌ An AI that "understands" your files
❌ An autonomous organizer that acts on its own
❌ A replacement for your file system
❌ Playful or cute (no cartoon illustrations)
❌ Overwhelming (progressive disclosure, focused views)
❌ Chatty (direct and precise communication)

---

## Document Hierarchy

| Document | Purpose |
|----------|---------|
| **BRAND-POSITIONING.md** | Strategic messaging foundation (source of truth) |
| **BRAND-OVERVIEW.md** (this) | Quick reference for developers/designers |
| **Forma-Brand-Guidelines.md** | Comprehensive implementation guide |
| **Forma-App-Store-Description.md** | App Store copy |
| **Forma-Onboarding-Flow.md** | In-app copy and flows |

When conflicts arise, defer to BRAND-POSITIONING.md.

---

## Resources

### Design Inspiration
- **Arc Browser** - Design-forward, confident, modern materials
- **Linear** - Sophisticated minimalism, keyboard-first
- **Figma** - Creative professional appeal, layered UI
- **Things 3** - Mac-native excellence, attention to detail
- **Craft** - Beautiful materials, polished interactions

### Apple Guidelines
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SF Symbols App](https://developer.apple.com/sf-symbols/)
- [Apple Design Awards](https://developer.apple.com/design/awards/) - Quality benchmark

---

**Next Review:** Q2 2026
**Strategic Foundation:** See BRAND-POSITIONING.md
