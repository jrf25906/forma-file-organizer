# Apple Design Award Standards for Forma

**Document Purpose:** Quick reference for maintaining Apple Design Award-level quality throughout development

**Last Updated:** November 23, 2025

---

## 🎯 The Quality Bar

**Every design decision in Forma is evaluated against this question:**

> "Would Apple showcase this at WWDC?"

If the answer is anything other than an enthusiastic "yes," it needs more refinement.

---

## Core Principles

### 1. Clarity
**Content is paramount. The UI should never compete with it.**

✅ **Good:**
- Clear visual hierarchy guides the eye naturally
- Selection states are immediately obvious through layered feedback
- Typography scale creates clear information structure
- Icons communicate function precisely

❌ **Avoid:**
- Cluttered interfaces with competing focal points
- Subtle selection states users might miss
- Inconsistent visual hierarchy
- Decorative elements that don't serve a purpose

**Forma Implementation:**
- File cards use gradient + border + shadow for selection
- Action toolbar: one prominent button, secondary actions collapsed
- Clear typography hierarchy (H1 → H2 → H3 → Body → Small)

### 2. Deference
**The interface helps people understand content but never competes with it.**

✅ **Good:**
- Subtle use of gradients and translucency
- Minimal visual weight in UI chrome
- Content (files) always remains the focus
- Interactions discoverable but not intrusive

❌ **Avoid:**
- Heavy borders and backgrounds that distract
- Busy UI chrome that fights for attention
- Overly dramatic animations
- Unnecessary visual effects

**Forma Implementation:**
- Frosted glass action bar with subtle gradient border
- 1px borders at 8% opacity (present but understated)
- Hover actions appear gently when needed
- White space is purposeful, not accidental

### 3. Depth
**Visual layers and realistic motion convey hierarchy.**

✅ **Good:**
- Distinct visual layers establish hierarchy
- Shadows create realistic elevation
- Motion feels natural and purposeful
- Proper z-ordering of elements

❌ **Avoid:**
- Flat interfaces with no depth cues
- Inconsistent or unrealistic shadows
- Jerky or exaggerated animations
- Elements that don't respect spatial relationships

**Forma Implementation:**
- 5 distinct layers: Background → Content → Interactive → Selected → Floating
- Shadow progression: 4px (resting) → 8px (selected) → 16px (floating)
- Selected cards "lift" with enhanced shadows
- Hover scale: 1.005x (subtle, not 1.01x)

### 4. Subtlety
**Refined interactions create delight without overwhelming.**

✅ **Good:**
- Gentle animations with natural easing
- Gradients used purposefully
- Shadows are layered and realistic
- Color choices restrained and meaningful

❌ **Avoid:**
- Flashy effects that call attention to themselves
- Heavy-handed gradients
- Overly saturated colors
- Distracting micro-interactions

**Forma Implementation:**
- Selection gradient: Steel Blue 12% → 8% (subtle fade)
- Border opacity transitions: 8% → 60% on selection
- Shadow color matches state (black → steel blue tint)
- Animations: 0.15s easeInOut for hover states

---

## Visual Design Standards

### Selection States

**Multi-layered feedback ensures clarity:**

1. **Background**: Gradient (not flat color)
   - `LinearGradient(colors: [Color.formaSteelBlue.opacity(0.12), Color.formaSteelBlue.opacity(0.08)])`

2. **Border**: Enhanced stroke
   - Selected: 2px at 60% opacity
   - Unselected: 1px at 8% opacity

3. **Shadow**: State-appropriate elevation
   - Selected: `Color.formaSteelBlue.opacity(0.15), radius: 8, y: 3`
   - Unselected: `Color.black.opacity(0.08), radius: 4, y: 2`

**Why it works:**
- Immediately obvious which items are selected
- Doesn't rely on color alone (accessibility)
- Feels refined, not jarring
- Multiple feedback channels reinforce each other

### Elevation System

Different UI elements require different elevation:

```swift
// Resting content (cards)
.shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

// Interactive/selected content
.shadow(color: Color.formaSteelBlue.opacity(0.15), radius: 8, x: 0, y: 3)

// Floating UI (action bars, modals)
.shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 4)
```

**Key Principles:**
- Y-offset creates realistic "lifting"
- Radius increases with importance
- Shadow color can match element state
- Opacity keeps shadows subtle

### Native Materials

**Use macOS native materials, not imitations:**

```swift
// Frosted glass for floating UI
VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

// With subtle gradient overlay
LinearGradient(
    colors: [Color.white.opacity(0.5), Color.white.opacity(0.3)],
    startPoint: .top,
    endPoint: .bottom
)
```

**Why native materials matter:**
- Respects system appearance settings
- Adapts to dark mode automatically
- Feels genuinely macOS, not web-like
- Performance optimized by Apple

### Hover Interactions

**Subtle refinement, not flashy effects:**

```swift
// Gentle scale on hover
.scaleEffect(isHovered ? 1.005 : 1.0)
.animation(.easeInOut(duration: 0.15), value: isHovered)

// Appropriate shadow for hover
.shadow(color: Color.black.opacity(isHovered ? 0.12 : 0.08), ...)
```

**Why 1.005x (not 1.01x or higher):**
- Creates perceptible feedback without being dramatic
- Feels refined, not cartoonish
- Respects the "deference" principle
- Matches patterns in award-winning apps

---

## Action Toolbar Design

### Before (Cluttered)
```
[3 files selected] [Organize All] [Skip All] [Bulk Edit] [Deselect]
```
- 4 buttons competing for attention
- No clear primary action
- Feels crowded and web-like

### After (Refined)
```
[○ 3] files selected                [Organize All]              [⋯] [✕]
```
- Clear hierarchy: one prominent action
- Secondary actions collapsed into menu
- Selection count has visual pill indicator
- Frosted glass background with subtle gradient border
- Feels native to macOS

**Design Decisions:**
- **Left**: Selection indicator (pill with count) + label
- **Center**: Primary action (gradient button, prominent shadow)
- **Right**: Secondary menu + close button (icon-only)
- **Background**: Frosted glass (`.hudWindow`) + gradient overlay
- **Border**: Subtle gradient (30% → 10% opacity) instead of solid bar

---

## Card Visual Hierarchy

### Layered Depth

**Standard Card (Unselected):**
- Background: `Color.formaBoneWhite`
- Border: 1px at 8% opacity
- Shadow: Black 8%, 4px radius, 2px offset

**Selected Card:**
- Background: Gradient (Steel Blue 12% → 8%)
- Border: 2px at 60% opacity
- Shadow: Steel Blue 15%, 8px radius, 3px offset

**Hover State:**
- Background: Obsidian 3% opacity
- Scale: 1.005x
- Shadow: Slightly enhanced

**Why borders matter:**
- Prevent cards from "fading into background"
- Create clear boundaries between elements
- Work with shadows to create depth
- Subtle enough not to dominate

---

## Decision Framework

When implementing or reviewing any UI element, ask:

### Quality Questions

1. **"Is this refined or just functional?"**
   - Functional is the minimum, refined is the goal

2. **"Would this impress someone from Apple's design team?"**
   - If you're not sure, it probably needs work

3. **"Does this use native patterns or web patterns?"**
   - Native macOS should always win

4. **"Is the visual feedback multi-layered?"**
   - Single-layer feedback (just color) is rarely enough

5. **"Are the details intentional or accidental?"**
   - Every shadow, border, spacing value should be deliberate

### Implementation Checklist

Before marking any UI work as "done":

- [ ] Uses design system tokens (no hardcoded values)
- [ ] Follows 4-point grid for spacing
- [ ] Shadows are appropriate for element's elevation
- [ ] Animations use natural easing (easeInOut typically)
- [ ] Selection states use layered feedback
- [ ] Hover effects are subtle (1.005x or similar)
- [ ] Native materials used where appropriate
- [ ] Visual hierarchy is clear
- [ ] Accessibility labels present
- [ ] Would you be proud to demo this at WWDC?

---

## Examples from Recent Work

### Selection State Enhancement (November 2025)

**Before:**
```swift
.background(
    isSelected ? Color.formaSteelBlue.opacity(0.05) : Color.formaControlBackground
)
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(isSelected ? Color.formaSteelBlue : Color.clear, lineWidth: 2)
)
```

**After:**
```swift
.background(
    Group {
        if isSelected {
            LinearGradient(
                colors: [
                    Color.formaSteelBlue.opacity(0.12),
                    Color.formaSteelBlue.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.formaBoneWhite
        }
    }
)
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
            isSelected ? Color.formaSteelBlue.opacity(0.6) : Color.formaObsidian.opacity(0.08),
            lineWidth: isSelected ? 2 : 1
        )
)
.shadow(
    color: isSelected ? Color.formaSteelBlue.opacity(0.15) : Color.black.opacity(0.08),
    radius: isSelected ? 8 : 4,
    x: 0,
    y: isSelected ? 3 : 2
)
```

**Why this is better:**
- Multi-layered feedback: gradient + border + shadow
- Selection is immediately obvious
- Feels refined, not just functional
- Respects Apple's design principles

### Action Toolbar Redesign (November 2025)

**Before:** 4 buttons in a row with solid colored top bar

**After:** Frosted glass bar with clear hierarchy

**Improvements:**
- Uses native macOS material (`.hudWindow`)
- Clear visual hierarchy (1 primary action, menu for secondary)
- Selection count has branded pill indicator
- Subtle gradient border (not harsh solid bar)
- Proper elevation with enhanced shadow
- Feels genuinely macOS, not web-like

---

## Continuous Learning

### Study These Apps (Apple Design Award Winners)

- **Things 3**: Selection states, depth, subtle interactions
- **Craft**: Native materials, refined animations
- **Darkroom**: Visual hierarchy, purposeful gradients
- **Procreate**: Attention to detail, delightful interactions
- **Notability**: Clean UI, clear hierarchy

### Key Observations

- **Selection states**: Always multi-layered (color + border + shadow)
- **Hover effects**: Subtle (1.005x typical, not 1.01x+)
- **Materials**: Frosted glass for floating UI is common
- **Shadows**: Layered and realistic, not flat
- **Animation**: 0.15-0.2s with natural easing
- **Details matter**: Every pixel is intentional

---

## Maintaining Standards

### Regular Reviews

Every sprint, review recent UI work against this checklist:

1. Does it meet our quality bar?
2. Would we showcase this at WWDC?
3. Are the details refined or just functional?
4. Does it use native patterns?
5. Is visual feedback multi-layered?

### When in Doubt

If you're unsure whether something meets our standards:

1. **Compare to award winners**: How would Things 3 handle this?
2. **Ask "refined or functional?"**: If just functional, iterate
3. **Test the details**: Zoom in, check shadows, borders, spacing
4. **Get feedback**: Show it to the team with fresh eyes
5. **Trust your instincts**: If it feels "off," it probably is

---

## Resources

- [Apple Design Award Winners](https://developer.apple.com/design/awards/)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [WWDC Design Sessions](https://developer.apple.com/videos/design/)

---

**Remember:** We're not just building a file organizer. We're creating an example of what's possible when design excellence is prioritized equally with functionality. Every detail matters. Every interaction is an opportunity for refinement. This is how you win Apple Design Awards.
