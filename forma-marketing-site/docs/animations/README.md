# Forma Marketing Site Animation Specifications

This directory contains detailed Figma/Magic Animator design specifications for feature demo, celebration, and ambient animations used on the Forma marketing site.

---

## Animation Index

### Feature Demo Animations

| File | Purpose | Duration | Emotional Goal |
|------|---------|----------|----------------|
| [natural-language-demo.md](./natural-language-demo.md) | Files sliding to Archive folder | 700ms | Effortless, magical |
| [connections-demo.md](./connections-demo.md) | Project files connecting with lines | 800ms | Intelligence, understanding |
| [control-demo.md](./control-demo.md) | Approval checkmarks cascade | 600ms | Control, satisfaction |

### Celebration & Ambient Animations

| File | Purpose | Duration | Loop |
|------|---------|----------|------|
| [success-checkmark.md](./success-checkmark.md) | Beta signup confirmation | 800ms | No |
| [scattered-chaos.md](./scattered-chaos.md) | "Before" state floating files | 3000ms | Yes |
| [organized-folders.md](./organized-folders.md) | "After" state folder stack | 1200ms | No |

---

## Forma Color Palette Reference

| Token | Hex | Usage |
|-------|-----|-------|
| `forma-warm-orange` | `#C97E66` | Chaos, urgency, accent |
| `forma-warm-orange-light` | `#D9A08E` | Secondary warm |
| `forma-sage` | `#7A9D7E` | Primary success, organized |
| `forma-sage-light` | `#9BB89E` | Highlights |
| `forma-sage-dark` | `#5C7A60` | Depth, shadows |
| `forma-steel-blue` | `#5B7C99` | Accent, secondary |
| `forma-cream` | `#F5F2EB` | Backgrounds |
| `forma-charcoal` | `#2D2D2D` | Text, outlines |

---

## Quick Start for Designers

### 1. Setting Up in Figma

1. Create a new Figma file for animations
2. Set up color styles matching the palette above
3. Create component sets for each animation
4. Use Smart Animate between variants

### 2. Magic Animator Workflow

1. Design all animation states as component variants
2. Name variants clearly (e.g., "State: Initial", "State: Complete")
3. Configure prototype transitions between variants
4. Test animation timing in prototype mode
5. Export via LottieFiles plugin

### 3. Export Checklist

- [ ] Lottie JSON export at 60fps
- [ ] SVG fallback for static states
- [ ] WebM/MP4 for video fallback
- [ ] Test reduced-motion behavior

---

## Forma Brand Easing Curves

These easing functions are defined in `src/lib/animation/ease-curves.ts` and define the motion personality of the Forma brand.

| Token | GSAP Equivalent | Usage |
|-------|-----------------|-------|
| `formaSnap` | `elastic.out(1, 0.5)` | File cards landing, drag-and-drop, satisfying clicks |
| `formaReveal` | `power3.out` | Section reveals, content appearing on scroll |
| `formaSettle` | `back.out(1.7)` | Elements finding final position, modals, tooltips |
| `formaMagnetic` | `power2.out` | Button hovers, cursor following, interactive elements |
| `formaExit` | `power2.in` | Elements animating out, closing modals |

### CSS Cubic Bezier Equivalents

| Name | CSS Cubic Bezier | Usage |
|------|------------------|-------|
| Standard ease | `cubic-bezier(0.4, 0, 0.2, 1)` | Most transitions |
| Decelerate | `cubic-bezier(0, 0, 0.2, 1)` | Enter animations |
| Accelerate | `cubic-bezier(0.4, 0, 1, 1)` | Exit animations |
| Spring/Settle | `cubic-bezier(0.34, 1.56, 0.64, 1)` | Bouncy, playful |
| Smooth float | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` | Ambient motion |

### Forma Duration Standards

| Token | Duration | Usage |
|-------|----------|-------|
| `instant` | 150ms | Micro-interactions, quick feedback |
| `fast` | 300ms | UI transitions, hover states |
| `normal` | 600ms | Standard animations |
| `slow` | 900ms | Emphasized reveals |
| `reveal` | 1200ms | Hero section animations |

### Stagger Timing

| Token | Duration | Usage |
|-------|----------|-------|
| `fast` | 50ms | Quick succession |
| `cascade` | 80ms | Feature demo sequences |
| `normal` | 100ms | Standard stagger |
| `slow` | 150ms | Dramatic reveals |

---

## Accessibility Requirements

All animations MUST:

1. Respect `prefers-reduced-motion: reduce`
2. Provide static fallback states
3. Not flash more than 3 times per second
4. Be decorative-only or have proper ARIA labels
5. Allow user pause/stop for looping animations

### Reduced Motion CSS

```css
@media (prefers-reduced-motion: reduce) {
  .animation {
    animation: none;
    transition: none;
  }
}
```

---

## Performance Guidelines

| Metric | Target |
|--------|--------|
| File size (Lottie) | < 50KB per animation |
| Frame rate | 30-60fps depending on complexity |
| CPU usage | < 10% during animation |
| First paint | Animation ready within 100ms of trigger |

### Optimization Tips

- Minimize path complexity in vector shapes
- Use shape tweening over path animation when possible
- Limit number of animated properties per element
- Test on low-end devices

---

## Implementation Order

1. **Phase 1:** Success checkmark (critical for signup flow)
2. **Phase 2:** Scattered chaos + organized folders (hero section)
3. **Phase 3:** Additional micro-interactions as needed

---

## Resources

- [LottieFiles Figma Plugin](https://www.figma.com/community/plugin/809860933081065308/LottieFiles)
- [Figma Smart Animate Documentation](https://help.figma.com/hc/en-us/articles/360039818874-Smart-animate)
- [Motion Design Principles](https://material.io/design/motion/understanding-motion.html)
- [Cubic Bezier Generator](https://cubic-bezier.com/)
