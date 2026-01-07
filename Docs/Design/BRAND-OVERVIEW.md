# Forma - Brand Overview

**Last Updated:** January 2025
**Status:** Design System Implemented, Visual Identity Finalized

---

## Quick Reference

**Brand Name:** Forma
**Positioning:** "Give your files form"
**Target Audience:** Creative professionals who value design excellence
**Personality:** Design-forward • Confident • Sophisticated

---

## Current Status Summary

### ✅ Completed (100%)
- **Brand Strategy** - Positioning, attributes, target audience defined
- **Design System** - Colors, typography, spacing, materials implemented in code
- **Core Functionality** - Full file organization engine with rules, keyboard navigation, multiple view modes
- **UI Architecture** - Three-panel layout with frosted glass materials, floating action bars
- **Documentation** - Brand guidelines and implementation docs

### ✅ Completed (100%)
- **Visual Identity** - Pure Grid V2 logo finalized (see `BRAND_ASSETS.md`)
- **UI Polish** - Core components refined, micro-interactions ongoing
- **Copy & Voice** - Guidelines exist, implementation consistent

### ❌ Not Started (0%)
- **Domain & Web** - forma.app preferred
- **Marketing Materials** - Screenshots, App Store assets
- **Landing Page** - Brand-aligned web presence

**Overall Progress:** ~75% Complete

---

## Brand Attributes

### Core Personality Traits
- ✨ **Design-forward** - Proudly visual, confident in its aesthetics
- 🎯 **Confident** - Opinionated defaults, no hedging or uncertainty
- 💎 **Sophisticated** - Layered depth, thoughtful materials, refined details
- 🧠 **Intelligent** - Pattern recognition, smart suggestions, learns behavior
- ⚡ **Capable** - Powerful features accessible through elegant UI

### Emotional Journey
1. **Impressed** → The app looks and feels premium from first launch
2. **Empowered** → Powerful tools feel accessible, not overwhelming
3. **Satisfied** → Organization feels good, progress is visible
4. **Trusted** → Preview before commit, undo available, no surprises

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
**Font:** SF Pro (macOS system font)

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Hero | 32pt | Bold | Headlines |
| H1 | 24pt | Semibold | Section headers |
| H2 | 20pt | Semibold | Subsection headers |
| H3 | 17pt | Medium | Card titles |
| Body | 13pt | Regular | Body text, UI |
| Small | 11pt | Regular | Metadata, captions |

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

---

## Critical Next Steps

### High Priority (Blocking Launch)
1. ~~**Design App Icon**~~ - ✅ Pure Grid V2 finalized (see `BRAND_ASSETS.md`)
2. **Secure Domain** - forma.app preferred
3. **App Store Assets** - Screenshots showcasing the UI
4. **Final UI polish** - Ensure Apple Design Award quality

### Medium Priority (Pre-Launch)
5. **Landing Page** - Simple, brand-aligned web presence
6. **Copy Audit** - Ensure voice consistency throughout
7. **Accessibility Pass** - VoiceOver, keyboard nav, contrast
8. **Performance Optimization** - Smooth 60fps animations

---

## Voice Guidelines

### Principles
- **Clear, not clever** - Function over wordplay
- **Specific, not vague** - "Move to Documents" not "Organize"
- **Active voice** - Imperative mood ("Move file" not "File will be moved")
- **Sentence case** - No Title Case, No ALL CAPS
- **Confident tone** - No hedging ("will" not "should")

### Example Copy
✅ **Good:**
- "Move to Documents"
- "All caught up"
- "23 files ready to organize"

❌ **Bad:**
- "Let's organize your files!" (too chatty)
- "FILE MOVED SUCCESSFULLY!" (all caps, exclamation)
- "Your files have been organized" (passive voice)

---

## What Forma IS

✅ **Design-forward** - Visual sophistication is part of the product
✅ **Layered & material** - Uses depth, glass, translucency intentionally
✅ **Keyboard-first** - Power users can fly through with shortcuts
✅ **Native macOS** - Embraces platform conventions and materials
✅ **Confident** - Opinionated defaults, clear recommendations

## What Forma Is NOT

❌ Playful or cute (no cartoon illustrations)
❌ Overwhelming (progressive disclosure, focused views)
❌ Chatty (direct and precise communication)
❌ Flat or sterile (uses materials and depth thoughtfully)
❌ Generic (distinctive visual identity)

---

## File Organization

### Detailed Documentation
For comprehensive information, see:

- **Brand Assets** → `BRAND_ASSETS.md` (Logo files, usage guide, deprecated files)
- **Brand Guidelines** → `Forma-Brand-Guidelines.md` (2,135 lines, authoritative reference)
- **Implementation TODO** → `FORMA-BRAND-TODO.md` (Task tracker with validation checkpoints)
- **HIG Compliance** → `CHANGELOG-HIG-COMPLIANCE.md` (macOS compliance updates)
- **Brand Status** → Archived (historical status snapshots)

### This Document's Purpose
This overview provides quick reference for developers and designers. For:
- **Strategic decisions** → See Brand Guidelines
- **Implementation tasks** → See Brand TODO
- **Technical compliance** → See HIG Compliance Changelog

---

## Validation Checkpoints

### Week 1 - Name Validation ✅
- [x] Live with "Forma" name for 3-5 days
- [x] Test in various contexts
- [x] Final decision: COMMITTED (Jan 17, 2025)

### Month 1 - Design Validation (Pending)
- [ ] Show icon to 3-5 designers for feedback
- [ ] Test icon recognition at 16x16px
- [ ] Verify "premium minimalist" perception
- [ ] Validate color palette in practice

### Month 2 - User Validation (Planned)
- [ ] Show prototype to 5-10 creative professionals
- [ ] Gather brand perception feedback
- [ ] Test pricing positioning ($49-99 range)

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

**Next Review:** December 2025
**Next Milestone:** App icon finalized + domain acquisition
**Launch Target:** Q1 2025
