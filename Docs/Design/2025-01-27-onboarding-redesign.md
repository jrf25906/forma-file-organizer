# Onboarding Redesign

## Summary

Redesign Forma's onboarding from a 5-step flow to a 4-step flow with bolder visual energy, OpenNote-inspired layout and typography, and streamlined folder permissions. The core change: onboarding becomes a "bookend" experience — high energy at Welcome and Preview, calm and focused in the middle.

## Design Decisions

### Flow (4 steps, down from 5)

| Step | Screen | Energy | Purpose |
|------|--------|--------|---------|
| 1 | Welcome | High | Files-into-folder animation, hero statement, CTA |
| 2 | Folder Selection | Calm | Vertical list of 5 pre-checked folders |
| 3 | Personality Quiz | Calm | Organization style assessment |
| 4 | Preview + Customize | High | Results applied, collapsible template customization |

**Removed:** Template Selection as a standalone step. Quiz-recommended templates auto-apply. A collapsible "Customize" section on the Preview step lets power users tweak before finishing.

### Visual Direction

**Palette:** Forma's existing colors (steel blue, sage, warm orange, muted blue, soft green) used more boldly in onboarding — larger color blocks, stronger contrast. Onboarding is the "louder" version of the Forma palette. The main app stays composed.

**Typography:**
- **Libre Baskerville** (serif, italic for hero text) for onboarding headlines — step titles, Welcome hero, Preview celebration. Already used on formafiles.com website. Free Google Font, OFL license, app-embedding safe.
- **SF Pro** (system font) for all body text, labels, buttons, and the rest of the app.

**Energy arc — Bookend:**
- Welcome and Preview are high-energy screens with bold animation
- Folder Selection and Quiz are calm, focused, typography-led — the user is making decisions and shouldn't be distracted
- This maps to: excite → decide → celebrate

### Step 1: Welcome

**Animation:** 12-15 file icons (realistic macOS file icons via `NSWorkspace.shared.icon(forFileType:)`) scattered at random positions with slight rotation. They drift lazily, then converge into a central Forma-branded folder icon with staggered timing (~2s). The folder pulses on "catch."

**After animation settles:**
- Hero text fades up: *"Your files, finally organized."* (Libre Baskerville, italic)
- Subtitle: "Forma learns how you work and keeps your folders tidy — automatically." (SF Pro, muted)
- Single CTA: "Get Started" button in steel blue

**Background:** Subtle radial gradient in Forma bone/off-white for depth.

No value proposition cards. The animation IS the value prop.

### Step 2: Folder Selection

**Layout change:** From 2-row grid (3+2) to a single vertical list of 5 folders. All pre-checked by default. User unchecks what they don't want.

**Folders (all pre-checked):**
1. Desktop (steel blue)
2. Downloads (sage)
3. Documents (muted blue)
4. Pictures (warm orange)
5. Music (soft green)

Each row: checkbox + color-coded folder icon + folder name + short description. Clean, scannable, minimal mouse movement.

**Permissions:** Requested for selected folders when user clicks Continue (same as current behavior, but defaults mean most users just confirm).

**Footer:** Privacy note ("Your files never leave your Mac") + Continue button.

### Step 3: Personality Quiz

**No major visual changes.** Keep the existing quiz UX but with updated typography (Libre Baskerville for the step title). The quiz is already well-designed — it's a differentiator and deserves its focused moment.

### Step 4: Preview + Customize

**High energy close.** Shows the folder structure that will be created based on quiz results and selected folders. Staggered entrance animations for each folder structure card.

**Collapsible "Customize" section:** A disclosure link that expands inline to show per-folder template dropdowns (reuses existing `TemplateSelectionStepView` logic). Hidden by default — most users skip it. Power users can tweak before finishing.

**CTA:** Celebratory finish button to complete onboarding.

### Permissions Strategy (App Store Safe)

- All 5 common folders pre-checked (Desktop, Downloads, Documents, Pictures, Music)
- Permissions requested per-folder via system dialog only after user confirms selection
- No batch/upfront permission requests (violates Apple guidelines)
- User explicitly sees which folders they're granting access to
- Pre-checking speeds up the flow without hiding anything

## Prototype

Interactive HTML prototype at: `Docs/Design/onboarding-prototype.html`

Shows Welcome animation (file convergence) and Folder Selection (vertical pre-checked list). Open in browser to preview.

## Implementation Notes

- Bundle Libre Baskerville font (Bold + Regular italic weights) in Xcode project, register in Info.plist
- Use `NSWorkspace.shared.icon(forFileType:)` for realistic file icons in Welcome animation
- Reuse existing `TemplateSelectionStepView` logic for the collapsible customize section in Preview
- Remove `TemplateSelectionStepView` as a standalone onboarding step
- Update `OnboardingState` to remove template selection step from navigation
- Update progress bar to show 3 dots (excluding Welcome) instead of 4
