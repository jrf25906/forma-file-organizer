# Forma: Apple Design Award Quality Review Prompt

**Purpose:** Comprehensive system-wide design review to ensure every aspect of Forma meets Apple Design Award standards.

**How to Use:** Copy the appropriate section below and use it as a prompt for AI-assisted code review, team review sessions, or personal audit.

---

## 🎯 Complete Application Review Prompt

```
I need you to conduct a comprehensive design review of the Forma file organization application.
The goal is to ensure every UI element, interaction, and visual detail meets Apple Design Award
standards.

### Context

Forma is a macOS file organization app built with SwiftUI. Our explicit goal is to win an
Apple Design Award, which means every design decision must be evaluated against the quality
demonstrated by award-winning apps.

### Review Scope

Examine the entire application systematically, evaluating:

1. **Visual Hierarchy & Depth**
   - Do all UI elements use proper elevation through layered shadows?
   - Is there clear visual separation between interface layers (Background → Content → Interactive → Selected → Floating)?
   - Are shadows realistic with appropriate blur radius, offset, and opacity?
   - Do selected states use multi-layered feedback (gradient + border + shadow)?

2. **Selection & Interactive States**
   - Are selection states immediately obvious through multiple visual channels?
   - Do hover states use subtle refinement (1.005x scale, gentle shadow changes)?
   - Are focus indicators clear for keyboard navigation?
   - Do interactive elements provide appropriate feedback?

3. **Native macOS Materials**
   - Are we using native materials (frosted glass, vibrancy) where appropriate?
   - Do floating UI elements use VisualEffectView instead of fake gradients?
   - Does the app respect system appearance settings?
   - Are we following macOS conventions for window chrome, sidebars, and panels?

4. **Typography & Spacing**
   - Does all text use the design system typography scale?
   - Is spacing consistent with the 4-point grid system?
   - Are there any hardcoded spacing values instead of design tokens?
   - Is type hierarchy clear and purposeful?

5. **Color & Contrast**
   - Are all colors from the design system (no hardcoded hex values)?
   - Do we meet WCAG 2.1 AA contrast requirements?
   - Are gradients used purposefully, not decoratively?
   - Is color alone never the only indicator of state?

6. **Animation & Motion**
   - Are animations natural with appropriate easing (easeInOut typically)?
   - Are durations appropriate (0.15-0.2s for most interactions)?
   - Is motion purposeful and enhancing understanding?
   - Do animations respect reduceMotion accessibility settings?

7. **Component Consistency**
   - Do all buttons meet minimum touch target sizes (32x32px)?
   - Are corner radii consistent (4px/8px/12px/16px)?
   - Do similar components use identical styling?
   - Are icon sizes appropriate (20-24px for lists, 64px for empty states)?

8. **Accessibility**
   - Do all icon-only buttons have accessibility labels?
   - Can the entire app be navigated via keyboard?
   - Does VoiceOver provide appropriate context?
   - Are touch targets adequately sized?

9. **Polish & Refinement**
   - Are there any "good enough" implementations that should be refined?
   - Do details feel intentional or accidental?
   - Would we be proud to demo any screen at WWDC?
   - Are there any web-like patterns instead of native macOS patterns?

### Apple Design Principles Evaluation

For each screen and component, evaluate against Apple's core principles:

**1. Clarity**
- Does the interface help users focus on content without distraction?
- Is visual hierarchy immediately apparent?
- Are interactive elements clearly distinguishable?

**2. Deference**
- Does the UI step back and let content be the star?
- Are visual effects subtle and purposeful?
- Is white space used intentionally?

**3. Depth**
- Do visual layers convey hierarchy?
- Are shadows realistic and appropriate?
- Does motion feel natural and physics-based?

**4. Subtlety**
- Are gradients gentle, not heavy-handed?
- Are hover effects refined, not dramatic?
- Do interactions delight without overwhelming?

### Specific Areas to Review

Please examine these files/areas systematically:

**Core Views:**
- `/Views/DashboardView.swift` - Main dashboard layout
- `/Views/MainContentView.swift` - File list/card/grid views
- `/Views/SidebarView.swift` - Navigation sidebar
- `/Views/RightPanelView.swift` - Storage/activity panel
- `/Views/Settings/SettingsView.swift` - Settings interface
- `/Views/RuleEditorView.swift` - Rule creation/editing

**Components:**
- `/Components/FileRow.swift` - File card component
- `/Components/FloatingActionBar.swift` - Selection toolbar
- `/Components/FileListRow.swift` - List view row
- `/Components/FileGridItem.swift` - Grid view item
- `/Components/Buttons.swift` - Button components
- `/Components/SecondaryFilterTab.swift` - Filter tabs
- `/Components/ReviewModeToggle.swift` - Toggle controls
- `/Components/ViewModeToggle.swift` - View switcher
- `/Components/StorageChart.swift` - Storage visualization
- `/Components/ActivityFeed.swift` - Activity timeline

**Design System:**
- `/DesignSystem/FormaColors.swift` - Color definitions
- `/DesignSystem/FormaTypography.swift` - Type scale
- `/DesignSystem/FormaSpacing.swift` - Spacing system
- `/DesignSystem/FormaAnimation.swift` - Animation constants

### Output Format

For each issue found, provide:

1. **Location:** File path and line number
2. **Current State:** What exists now
3. **Issue:** What doesn't meet Apple Design Award standards
4. **Apple Principle Violated:** Which of the 4 principles this affects
5. **Recommended Fix:** Specific code or design change
6. **Priority:** Critical / High / Medium / Low
7. **Example:** Reference to an award-winning app that does this well

### Quality Bar

Remember: Our standard is not "good for an indie app" or "acceptable." Our standard is
"would Apple feature this at WWDC as an example of great design."

If something is merely functional but not refined, flag it.
If something works but doesn't feel native to macOS, flag it.
If something is "good enough" but not excellent, flag it.

### Success Criteria

The review should result in:
- Zero hardcoded values (all use design tokens)
- All selection states use multi-layered feedback
- All floating UI uses native frosted glass
- All hover effects are subtle (≤1.005x scale)
- All shadows are realistic and layered
- All animations have appropriate easing
- All components meet accessibility standards
- Every screen feels worthy of an Apple Design Award

Please begin the comprehensive review.
```

---

## 📋 Focused Review Prompts

Use these for targeted reviews of specific areas:

### Selection States Review

```
Review all selection states in Forma to ensure they meet Apple Design Award standards.

**Requirements:**
- Multi-layered feedback: gradient background + enhanced border + colored shadow
- Selection gradient: Steel Blue 12% → 8% opacity
- Border: 2px at 60% opacity when selected, 1px at 8% when unselected
- Shadow: Colored (Steel Blue 15%, 8px radius, 3px offset) when selected
- No flat single-color selection states

**Files to check:**
- FileRow.swift
- FileListRow.swift
- FileGridItem.swift
- Any other selectable components

**Report:**
- Which components meet the standard?
- Which need updating?
- Provide specific code fixes for any issues
```

### Shadow & Elevation Review

```
Audit all shadows throughout Forma to ensure proper elevation hierarchy.

**Elevation System:**
- Background: No shadow
- Content (resting): Black 8%, 4px radius, 2px offset
- Interactive/Selected: Enhanced shadow (8px radius, 3px offset)
- Floating UI: Prominent shadow (16px radius, 4px offset, 15% opacity)

**Shadow Principles:**
- Y-offset creates realistic "lifting"
- Blur radius increases with importance
- Shadow color can match element state (e.g., steel blue for selected)
- Opacity keeps shadows subtle (8-15% typical)

**Check:**
- Are any shadows too harsh (>20% opacity)?
- Are any shadows unrealistic (too small radius for offset)?
- Do floating elements have proper elevation?
- Are shadows consistent across similar components?

**Files to review:**
- All component files in /Components/
- All view files in /Views/
```

### Native Materials Review

```
Verify all floating UI elements use native macOS materials instead of fake gradients.

**Standard:**
All floating UI (action bars, popovers, modals) should use:
```swift
VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
```

**Not:**
```swift
Color.white.opacity(0.9).blur(...)  // Fake frosted glass
```

**Benefits of native materials:**
- Respects system appearance
- Adapts to dark mode automatically
- Performance optimized by Apple
- Genuinely native feel

**Files to check:**
- FloatingActionBar.swift
- Any modal/popover components
- Tooltip components
- Context menus

**Report which components:**
- Already use native materials ✅
- Use fake gradients instead ❌
- Need to be updated
```

### Animation Review

```
Review all animations to ensure they meet Apple Design Award quality standards.

**Animation Standards:**
- Duration: 0.15-0.2s for most interactions
- Easing: .easeInOut (natural, not linear)
- Hover scale: ≤1.005x (subtle, not dramatic)
- Motion should enhance understanding, not distract
- Respect reduceMotion accessibility setting

**Red Flags:**
- Scale > 1.01x (too dramatic)
- Linear easing (feels robotic)
- Duration > 0.3s (feels sluggish)
- Duration < 0.1s (feels jarring)
- Animations that don't respect accessibility preferences

**Files to check:**
- All .animation() modifiers
- All withAnimation() blocks
- Transition modifiers
- Custom animation components

**Provide:**
- List of animations that meet standards
- List of animations that need adjustment
- Specific duration/easing recommendations
```

### Typography & Spacing Review

```
Audit typography and spacing throughout the app for consistency.

**Typography Standards:**
- All text must use design system tokens (.formaH1, .formaBody, etc.)
- No hardcoded .font() calls
- Clear hierarchy: Hero > H1 > H2 > H3 > Body > Small > Caption

**Spacing Standards:**
- All spacing must use 4-point grid
- Use design tokens: .micro, .tight, .standard, .large, .generous, .xl, .xxl
- No hardcoded spacing values (no raw 10, 15, 25, etc.)

**Find:**
- Any hardcoded .font(size:) calls
- Any hardcoded spacing values
- Inconsistent use of spacing tokens
- Type hierarchy violations

**Files to check:**
- All view files
- All component files
- Design system files

**Report:**
- Current compliance percentage
- Specific violations with file:line
- Recommended fixes
```

### Accessibility Review

```
Comprehensive accessibility audit for WCAG 2.1 AA compliance.

**Requirements:**

1. **Touch Targets**
   - Minimum 32x32px for all interactive elements
   - Recommended 44x44px for primary actions

2. **Accessibility Labels**
   - All icon-only buttons MUST have .accessibilityLabel()
   - Labels should be descriptive ("Settings" not "Gear icon")

3. **Keyboard Navigation**
   - All interactive elements must be keyboard accessible
   - Tab order should be logical
   - Focus indicators must be clear

4. **Color Contrast**
   - Primary text: ≥7:1 ratio
   - Secondary text: ≥4.5:1 ratio
   - Interactive elements: Clear focus indicators
   - Never use color alone to convey information

5. **VoiceOver**
   - All screens should be navigable via VoiceOver
   - Context and state should be clear
   - Form inputs should have proper labels

**Check all:**
- IconButton instances
- Toggle controls
- Custom interactive components
- Form inputs
- Navigation elements

**Report:**
- Missing accessibility labels (file:line)
- Touch targets below 32px
- Contrast ratio violations
- Keyboard navigation issues
```

### Component Consistency Review

```
Ensure all UI components follow consistent patterns and standards.

**Button Standards:**
- Heights: 32px (standard), 40-44px (toolbar)
- Corner radius: 4px (small), 8px (medium)
- Minimum touch target: 32x32px
- Consistent padding: .horizontal(18), .vertical(8)

**Corner Radius Standards:**
- Small: 4px (buttons, tags)
- Medium: 8px (cards, inputs)
- Large: 12px (panels, file cards)
- XLarge: 16px (modals, large containers)

**Icon Sizes:**
- List items: 20-24px
- Empty states: 64px
- Toolbar: 18-20px
- Sidebar: 20px

**Check for:**
- Inconsistent button heights
- Random corner radius values
- Inconsistent icon sizing
- Duplicate components with different styling
- Components that should share code but don't

**Report:**
- Pattern inconsistencies
- Opportunities for consolidation
- Recommended component refactoring
```

---

## 🔄 Iterative Review Process

Use this workflow for continuous quality improvement:

### Week 1: Foundation Audit
```
Focus: Design System & Core Components

Review:
1. Design system tokens (colors, spacing, typography)
2. Core reusable components (buttons, cards, etc.)
3. Ensure no hardcoded values exist

Goal: Establish foundation for consistency
```

### Week 2: Visual Hierarchy
```
Focus: Shadows, Elevation, Depth

Review:
1. All shadow implementations
2. Elevation hierarchy across the app
3. Selection state implementations
4. Hover state refinement

Goal: Proper depth and spatial relationships
```

### Week 3: Native Integration
```
Focus: macOS Materials & Patterns

Review:
1. Native material usage (frosted glass)
2. macOS HIG compliance
3. System appearance adaptation
4. Platform conventions

Goal: Feel genuinely native to macOS
```

### Week 4: Polish & Refinement
```
Focus: Animations, Interactions, Details

Review:
1. All animations and transitions
2. Micro-interactions
3. Edge cases and error states
4. Overall refinement

Goal: Every detail feels intentional
```

### Week 5: Accessibility
```
Focus: Inclusive Design

Review:
1. VoiceOver support
2. Keyboard navigation
3. Color contrast
4. Touch targets
5. Reduced motion support

Goal: WCAG 2.1 AA compliance minimum
```

### Week 6: Final Quality Pass
```
Focus: Apple Design Award Readiness

Review:
1. Compare to award-winning apps
2. Evaluate against "Would Apple showcase this?" standard
3. Final refinements and polish
4. Documentation of design decisions

Goal: Award-worthy quality across entire app
```

---

## 📊 Review Checklist Template

Copy this for each review session:

```markdown
# Design Review Session

**Date:** YYYY-MM-DD
**Reviewer:** Name
**Focus Area:** [Selection States / Shadows / Animations / etc.]

## Pre-Review

- [ ] Read relevant sections of APPLE-DESIGN-AWARD-STANDARDS.md
- [ ] Review UI-GUIDELINES.md for specific standards
- [ ] Have award-winning app examples ready for comparison

## Review Notes

### Components Reviewed
1.
2.
3.

### Meets Standards ✅
- Component/Feature: Why it's excellent
- Component/Feature: Why it's excellent

### Needs Improvement ⚠️
- **Component/Feature**
  - Issue:
  - Principle violated:
  - Priority:
  - Fix:

### Critical Issues ❌
- **Component/Feature**
  - Issue:
  - Principle violated:
  - Priority: CRITICAL
  - Fix:

## Action Items

- [ ] Fix critical issues
- [ ] Address high-priority improvements
- [ ] Schedule follow-up review
- [ ] Update documentation if patterns changed

## Overall Assessment

**Ready for Apple Design Award?** Yes / No / Needs Work

**Notes:**

## Next Review

**Focus:**
**Date:**
**Goals:**
```

---

## 🎯 Quick "WWDC Demo" Test

Before any release or major milestone, run this quick test:

```
Imagine you're at WWDC and Apple wants to showcase Forma on stage as an example
of great macOS design.

For each screen:
1. Would you be proud to see it on the keynote stage?
2. Would it hold up under close scrutiny on a 60-inch display?
3. Would developers in the audience think "I want to build something this good"?

If the answer to any question is "no" or "maybe," that screen needs more work.

Test these screens:
- [ ] Dashboard (main view)
- [ ] File list with selections
- [ ] Action toolbar in use
- [ ] Settings panel
- [ ] Rule editor
- [ ] Empty states
- [ ] Error states
- [ ] Onboarding flow

Any screen that wouldn't impress at WWDC is not ready.
```

---

## 📝 Documentation

After each review, update:

1. **This document** if you discover new patterns or standards
2. **APPLE-DESIGN-AWARD-STANDARDS.md** with examples from the review
3. **UI-GUIDELINES.md** if you refine any guidelines
4. **Design decision log** explaining why changes were made

---

## 🏆 Success Metrics

The review process is successful when:

- [ ] Zero hardcoded values (100% design token usage)
- [ ] All selection states use multi-layered feedback
- [ ] All floating UI uses native frosted glass
- [ ] All shadows follow elevation hierarchy
- [ ] All animations use natural easing
- [ ] All hover effects are subtle (≤1.005x)
- [ ] 100% accessibility compliance
- [ ] Every team member can answer "Yes" to "Would Apple showcase this?"

---

**Remember:** This isn't about being perfect on day one. It's about continuously refining until every aspect of Forma demonstrates the craftsmanship worthy of an Apple Design Award. Every review makes us better. Every refinement gets us closer.
