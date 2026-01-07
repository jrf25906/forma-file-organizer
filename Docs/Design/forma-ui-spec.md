# Forma File Management - UI Specification

## Overview
This document specifies UI improvements for the center panel of Forma's file management interface. The goal is to create a design that would make an experienced UI/UX designer say "Wow, that is a really nice design."

**Primary Use Case:** Help users find files that need attention and organize them automatically or with their assistance.

**Design Philosophy:** Clean, polished, delightful interactions with professional-grade attention to detail.

---

## Design Tokens

### Typography
```
Font Family: SF Pro Display (system font)

Sizes & Weights:
- File names: 13px, Medium (500)
- File metadata: 11px, Regular (400)
- Group headers: 12px, Semibold (600), uppercase, 0.5px letter-spacing
- Buttons: 12px, Medium (500)
- Section titles: 14px, Semibold (600)

Line Heights:
- File names: 1.4
- Metadata: 1.3
- Body text: 1.6
```

### Colors
```
Primary Text: #1D1D1F (near black)
Secondary Text: #86868B (gray)
Tertiary Text: #C7C7CC (light gray)
Accent Blue: #4A7BA7
Success Green: #34C759
Warning Orange: #FF9500

Backgrounds:
- White: #FFFFFF
- Light gray: #F9F9F9
- Lighter gray: #F5F5F7
- Border gray: #E5E5E7
- Divider: #F0F0F0
```

### Spacing
```
Row Height (List View): 64px
Row Padding: 12px vertical, 16px horizontal
Grid Gap: 16px
Thumbnail Size: 40×40px (List), 140px height (Grid)
Icon Button Size: 28×28px
Border Radius: 6px (small), 8px (medium), 12px (large)
```

### Transitions
```
Duration: 150-200ms for most interactions, 300ms for larger movements
Easing: ease-out for most, spring for playful moments
Hover Transform: translateY(-1px) or translateY(-2px)
Shadow on Hover: 0 2px 8px rgba(0,0,0,0.06) or 0 4px 12px rgba(0,0,0,0.1)
```

---

## Component Specifications

### 1. File List View (Center Panel)

#### Unified Toolbar (Header)
- **Mode Toggles:**
  - "Review" (primary): Morphing button with count badge. Expands to solid blue pill when active.
  - "All Files" (secondary): Morphing button. Shows full text when active, collapses to icon/text when inactive.

- **Secondary Filters:**
  - Options: All, Recent, Large Files, Flagged
  - Style: Glass-morphism capsules
  - Behavior: Dynamically appear/disappear based on selected mode

#### Smart Grouping
Files are automatically grouped by:
1. **Date-based:**
   - Today
   - Yesterday
   - This Week (last 7 days)
   - This Month
   - Older

2. **AI/Pattern-based:**
   - "Possible Duplicates" (similar names/sizes)
   - "These look like screenshots" (filename patterns)
   - "Large files" (over threshold)
   - "Untitled files" (generic names)

**Group Header Styling:**
- Font: 12px Semibold, uppercase, 0.5px letter-spacing
- Color: #86868B
- Padding: 16px top, 8px bottom
- Border bottom: 1px solid #F0F0F0
- First group has no top margin

#### File Row
**Default State:**
```
Height: 64px
Padding: 12px vertical, 16px horizontal
Background: transparent
Border radius: 8px
Display: flex, align-items: center
Cursor: pointer
```

**Hover State:**
```
Background: #F9F9F9
Transform: translateY(-1px)
Box shadow: 0 2px 8px rgba(0,0,0,0.06)
Transition: all 0.2s ease-out
```

**Layout (left to right):**
1. Thumbnail (40×40px)
2. File Info (flex: 1)
3. Action Buttons (right-aligned)

#### Thumbnails

**Implementation:**
- **Size:** 40×40px in list view
- **Border radius:** 6px
- **Fallback:** Generic icon with gradient background for non-previewable files
- **Loading:** Lazy load as user scrolls, prioritize visible items

**File Types with Previews:**
- Images (PNG, JPG, JPEG, GIF, WebP): Show actual image
- PDFs: Show first page thumbnail
- Videos: Show first/middle frame
- Documents: Preview first page if possible

**Fallback Icons:**
- Use colored gradient backgrounds with emoji or icon
- Different gradients for different file types

**Hover Preview Popup:**
- Appears near cursor when hovering over thumbnail
- Max size: 300px wide/tall (maintain aspect ratio)
- Shows: Larger preview + file details (name, type, size, modified date, dimensions)
- Background: White with shadow
- Border radius: 12px
- Padding: 16px
- Fade in/out: 150ms
- Z-index: 1000

#### File Info
```
Flex: 1
Min-width: 0 (allows text truncation)
```

**File Name:**
- Font: 13px Medium
- Color: #1D1D1F
- Line height: 1.4
- White-space: nowrap
- Overflow: hidden
- Text-overflow: ellipsis

**Smart Truncation Logic:**
- Screenshots with timestamps: Show "Screenshot...5.08.40PM.png" (keep timestamp visible)
- Duplicates: Show unique differentiator (numbers in parentheses)
- General: Show start and end, truncate middle with "..."

**Metadata:**
- Font: 11px Regular
- Color: #86868B
- Line height: 1.3
- Margin top: 2px
- Format: "TYPE • SIZE • TIME"
- Use middle dot (•) separator with spaces

#### Action Buttons

**Default State (always visible):**
1. Rule Button
2. Menu Button (⋯)

**Hover State (fade in):**
1. Flag/Star Icon
2. Quick Move Icon
3. Rule Button
4. Menu Button

**Rule Button:**
```
Padding: 6px 12px
Border radius: 6px
Font: 12px Medium
Border: 1px solid #E5E5E7
Background: white
Transition: all 0.2s

States:
- No Rule: Orange text (#FF9500)
- Has Rule: Green text (#34C759), green border
```

**On Click (Rule Button):**
Opens dropdown menu:
- Position: Below button, left-aligned
- Margin top: 4px
- Background: White
- Border radius: 8px
- Box shadow: 0 4px 16px rgba(0,0,0,0.12)
- Min width: 200px
- Padding: 6px

**Dropdown Items:**
```
First Item (Create):
- Text: "+ Create New Rule..."
- Color: #4A7BA7 (accent)
- Font weight: 500

Divider:
- Height: 1px
- Background: #E5E5E7
- Margin: 6px vertical

Existing Rules:
- Icon + text
- Examples: "📁 Move to Documents", "🗄️ Archive", etc.
- Hover background: #F5F5F7
- Border radius: 6px
- Padding: 8px 12px
```

**Hover Action Icons:**
```
Opacity: 0 (default)
Transform: translateX(-8px) (default)
Transition: all 0.2s ease-out

On Row Hover:
- Opacity: 1
- Transform: translateX(0)

Icon Buttons:
- Size: 28×28px
- Border radius: 6px
- Background: transparent
- Hover background: #E5E5E7
- Icons: ⭐ (flag), 📁 (quick move)
- Gap: 4px between buttons
```

**Menu Button (⋯):**
```
Size: 28×28px
Border radius: 6px
Background: transparent
Hover background: #E5E5E7
Color: #86868B
Font size: 16px
```

**Menu Items (on click):**
- Rename
- Duplicate
- Move to...
- Show in Finder
- Get Info
- Delete

---

### 2. Grid View

#### Layout
```
Display: grid
Grid template columns: repeat(auto-fill, minmax(160px, 1fr))
Gap: 16px
```

#### File Card

**Default State:**
```
Background: #F9F9F9
Border radius: 12px
Overflow: hidden
Cursor: pointer
Transition: all 0.2s ease-out
```

**Hover State:**
```
Transform: translateY(-2px)
Box shadow: 0 4px 12px rgba(0,0,0,0.1)
```

**Structure:**
1. Card Thumbnail (140px height)
2. Card Info (padding: 12px)

**Card Thumbnail:**
```
Width: 100%
Height: 140px
Position: relative
Background: Gradient or preview image
Display: flex
Align items: center
Justify content: center
```

**Card Overlay (on hover):**
```
Position: absolute
Top/Left/Right/Bottom: 0
Background: rgba(0, 0, 0, 0.3)
Opacity: 0 (default)
Transition: opacity 0.2s
Display: flex
Align items: center
Justify content: center
Gap: 12px

On Hover:
- Opacity: 1
```

**Overlay Buttons:**
```
Size: 36×36px
Border radius: 8px
Background: rgba(255, 255, 255, 0.95)
Backdrop filter: blur(10px)
Border: none
Cursor: pointer
Transition: all 0.15s

Icons: ⭐ (flag), 📁 (quick move), ⋯ (menu)

Hover:
- Background: white
- Transform: scale(1.05)
```

**Card Info:**
```
Padding: 12px

Card Name:
- Font: 12px Medium
- Color: #1D1D1F
- White-space: nowrap
- Overflow: hidden
- Text-overflow: ellipsis
- Line height: 1.4
- Margin bottom: 4px

Card Metadata:
- Font: 10px Regular
- Color: #86868B
```

---

### 3. View Toggle

**Position:** Bottom of center panel
**Styling:**
```
Display: flex
Gap: 4px
Margin top: 24px
Padding top: 16px
Border top: 1px solid #F0F0F0
```

**View Options:**
```
Padding: 6px 12px
Font: 12px Regular
Color: #86868B (inactive)
Background: #F9F9F9 (inactive)
Border radius: 6px
Cursor: pointer
Transition: all 0.15s

Active State:
- Background: #4A7BA7
- Color: white
```

---

### 4. Empty State

**When "Needs Review" = 0:**

```
Text align: center
Padding: 60px 40px

Icon:
- Size: 48px
- Emoji: ✨
- Opacity: 0.3
- Margin bottom: 16px

Title:
- Font: 18px Semibold
- Color: #1D1D1F
- Margin bottom: 8px
- Text: "All Caught Up!"

Subtitle:
- Font: 14px Regular
- Color: #86868B
- Text: "You've organized all your files. Nice work!"
```

---

## Interaction Patterns

### Micro-interactions

1. **File Hover:**
   - Smooth scale/lift effect
   - Shadow increase
   - Action buttons fade in from left

2. **Rule Applied:**
   - Checkmark animation
   - File fades out or moves smoothly to new position
   - Duration: 300ms

3. **File Organized:**
   - Satisfying "swoosh" animation
   - File moves to appropriate group

4. **Empty State Reached:**
   - Subtle celebration (confetti or pulse effect on icon)

### Keyboard Shortcuts

```
⌘ + Click: Multi-select files
Space: Quick preview
⌘ + Delete: Delete selected files
⌘ + R: Apply rule to selected
Arrow Keys: Navigate files
Enter: Open selected file
Escape: Close preview/dropdown
```

**Implementation:**
- Show tooltips on hover to teach shortcuts
- Visual indicators for keyboard focus states
- Smooth focus ring animations

---

## Technical Implementation Notes

### File Preview System

**Lazy Loading Strategy:**
```javascript
// Load thumbnails as user scrolls
// Prioritize visible items in viewport
// Use IntersectionObserver API
// Cache previews for performance
```

**Preview Generation:**
- Use native macOS APIs for thumbnail generation
- For images: Load at lower resolution, show full on hover
- For PDFs: Render first page using PDFKit
- For videos: Extract frame using AVFoundation

### Smart Grouping Logic

**Date-based:**
```javascript
// Calculate date ranges
const today = startOfDay(new Date())
const yesterday = subDays(today, 1)
const weekAgo = subDays(today, 7)
const monthAgo = subMonths(today, 1)

// Group files by modifiedDate
```

**Pattern-based:**
```javascript
// Screenshot detection
if (fileName.includes('Screenshot') || fileName.includes('Screen Shot')) {
  group = 'These look like screenshots'
}

// Duplicate detection
// Check for similar names with (1), (2), etc.
// Or similar file sizes and names

// Large files
if (fileSize > 100 * 1024 * 1024) { // 100MB
  group = 'Large files'
}
```

### Animation Performance

**Use CSS transforms for animations:**
```css
/* Good - GPU accelerated */
transform: translateY(-1px);
transform: scale(1.05);

/* Avoid - causes repaints */
margin-top: -1px;
width: 105%;
```

**Will-change for hover elements:**
```css
.file-row {
  will-change: transform, box-shadow;
}
```

---

## File Structure Recommendations

```
/src
  /components
    /FileList
      FileList.tsx
      FileRow.tsx
      FileRowActions.tsx
      GroupHeader.tsx
    /FileGrid
      FileGrid.tsx
      FileCard.tsx
      CardOverlay.tsx
    /Thumbnail
      Thumbnail.tsx
      ThumbnailPreview.tsx
    /RuleButton
      RuleButton.tsx
      RuleDropdown.tsx
    /EmptyState
      EmptyState.tsx
  /hooks
    useLazyThumbnails.ts
    useFileGrouping.ts
    useKeyboardShortcuts.ts
  /utils
    fileGrouping.ts
    thumbnailGenerator.ts
    smartTruncation.ts
  /styles
    tokens.ts (design tokens)
    animations.ts
```

---

## Implementation Priority

### Phase 1: Core Visual Updates
1. ✅ Implement new typography and spacing
2. ✅ Add smart grouping with headers
3. ✅ Update action button layout (hybrid approach)
4. ✅ Improve file name truncation

### Phase 2: Thumbnails & Previews
1. ✅ Implement thumbnail preview system
2. ✅ Add hover preview popup
3. ✅ Lazy loading for performance

### Phase 3: Interactions & Polish
1. ✅ Add all hover states and animations
2. ✅ Implement keyboard shortcuts
3. ✅ Add empty state
4. ✅ Polish grid view with overlays

### Phase 4: Advanced Features
1. ✅ AI-powered smart grouping
2. ✅ Rule creation flow
3. ✅ Quick preview panel
4. ✅ Performance optimization

---

## Success Criteria

A designer should say "Wow" because:
- ✅ Typography is refined and hierarchical
- ✅ Spacing creates clear visual rhythm
- ✅ Interactions are smooth and delightful
- ✅ Smart features feel intelligent, not gimmicky
- ✅ Hover states reveal functionality without clutter
- ✅ Empty states provide positive reinforcement
- ✅ The app feels polished at every zoom level
- ✅ Performance is buttery smooth (60fps)

---

## Reference Implementation

See `forma-mockups.html` for interactive HTML prototype demonstrating all patterns and interactions.

---

## Questions or Clarifications

If any part of this spec needs clarification during implementation:
1. Refer to the HTML mockup for visual reference
2. Follow macOS Human Interface Guidelines for system conventions
3. Prioritize delightful interactions over feature completeness
4. Test all animations at 60fps
5. Consider accessibility (keyboard navigation, screen readers)

Good luck building! 🚀
