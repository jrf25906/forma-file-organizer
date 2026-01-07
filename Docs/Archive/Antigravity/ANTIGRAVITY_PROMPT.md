# Forma - Antigravity Development Prompt

## Context & Role

You are an expert SwiftUI developer and macOS UI/UX designer tasked with building **Forma**, a premium file organization app for macOS. Your primary objective is to **develop the user interface and visual language first**, creating a refined, minimalist experience that embodies precision and elegance.

---

## Project Vision

**Forma** helps creative professionals organize their Desktop and Downloads folders through intelligent pattern recognition and refined user experience. The tagline is **"Give your files form"**.

### Core Brand Attributes
- **Precise**: Exact, structured, unambiguous - every detail matters
- **Refined**: Minimalist, monochromatic, premium feel without excess
- **Confident**: Direct, opinionated, self-assured without being arrogant

### Emotional Journey
1. **Satisfying** (First use): Immediate visual clarity, appreciation for minimalism
2. **Trusted** (Ongoing): Intelligent pattern matching, respects workflow
3. **Seamless** (Long-term): Invisible yet essential, part of refined system

---

## Design Inspiration

<design_inspiration>
I've provided 7 UI design inspiration images in the `/ui design inspiration` folder. These represent the visual aesthetic I'm drawn to:
- Minimalist, geometric interfaces
- Sophisticated use of whitespace
- Monochromatic or limited color palettes
- Clean typography and precision

**Important**: Use these as aesthetic anchors - absorb the mood, the restraint, the sophistication - but DO NOT simply replicate them. I want you to internalize these principles and create something original that feels like it belongs to the same design universe while being uniquely suited to Forma's purpose.
</design_inspiration>

---

## Visual Language & Design System

### Color Palette
```
Primary:
  Obsidian:    #1A1A1A (primary text, dark mode backgrounds, UI elements)
  Bone White:  #FAFAF8 (light mode backgrounds, text on dark)

Accents (use sparingly, 5-10% of interface):
  Steel Blue:  #5B7C99 (primary actions, interactive elements)
  Sage:        #7A9D7E (success states, confirmations)

System Colors:
  Use native macOS system colors for semantic states (success, warning, error)
  Leverage NSColor for automatic dark mode support
```

### Typography
```
Primary: SF Pro (system font)
- Large (>19pt): SF Pro Display
- UI/Body (≤19pt): SF Pro Text
- Monospace: SF Mono (for file paths)

Type Scale:
- Hero: 32pt Bold
- H1: 24pt Semibold
- H2: 20pt Semibold
- Body: 13pt Regular
- Small: 11pt Regular

Rules:
- Sentence case for everything
- Left-aligned (never centered except empty states)
- Line height: 1.5x for body, 1.2x for headers
```

### Spacing & Layout
```
8pt Grid System (all spacing in multiples of 8):
- Micro: 4px (icon to text)
- Tight: 8px (related elements)
- Standard: 16px (most common)
- Generous: 24px (sections)
- Large: 32px (major sections)
- XL: 48px (screen margins)
```

### UI Components Style
```
Buttons:
- Primary: Steel Blue fill, Bone White text, 2px corner radius
- Secondary: Clear background, Obsidian border (1px at 20% opacity)
- Minimal corner rounding (2px max - we're going for sharp, precise)

Cards/Containers:
- Corner radius: 10px
- Subtle shadows: 0px 2px 8px at 5% black
- Use system background colors

Forms:
- System-standard inputs
- 6px corner radius for text fields
- Steel Blue for focus states
```

---

## Core Screens to Develop (UI-First)

### 1. Menu Bar Dropdown
**Purpose**: Quick status + launch point

**Requirements**:
- Shows file counts for Desktop/Downloads
- Primary action: "Scan & Review Now"
- Links to Settings and About
- Clean, minimal (~250px wide)
- Native macOS menu bar styling

### 2. Main Review Interface (Primary Screen)
**Purpose**: Where users spend 90% of their time reviewing files

**Two Layout Options** (choose the one that feels more refined):

**Option A - List View** (recommended for efficiency):
- Shows all files at once with suggestions
- One file per row with inline actions
- Filters at top (file type, status, location)
- Batch operations at bottom
- Fast keyboard navigation

**Option B - Card View** (more focused):
- One file at a time with large preview
- Swipe/arrow navigation between files
- More visual, less overwhelming
- Better for visual confirmation

**Key Features for Both**:
- File preview (icon or Quick Look)
- Current location vs. suggested destination
- Status indicators (✓ Has rule, ⚠️ No rule)
- Inline actions: Accept, Choose Different, Skip
- Keyboard shortcuts essential

### 3. Rules & Settings Screen
**Purpose**: Define organizational logic

**Requirements**:
- List of folders to watch (Desktop, Downloads)
- Organization rules (add/edit/delete/reorder)
- Rule builder with conditions and destinations
- Preferences (preview, auto-process, confirmations)
- About section

### 4. Empty States & Success States
- Empty: Clean, positive ("All clean!")
- Success: Modest celebration (no over-the-top emojis)
- Error: Clear problem + solution

---

## Technical Foundation (Defer Backend)

**For Now, Focus On**:
- SwiftUI views and components
- Visual hierarchy and layout
- Interaction patterns and micro-animations
- Dark mode support
- Accessibility basics (VoiceOver labels, keyboard navigation)

**Backend Can Wait**:
- Actual file operations (FileManager)
- Rule engine logic
- Permissions handling
- Data persistence

**Create**:
- Mock data for demonstration
- Hardcoded file lists for prototypes
- Simulated states (loading, success, error)
- The VISUAL LANGUAGE should be production-ready even if functionality is stubbed

---

## Design Principles to Guide You

1. **Clarity Over Creativity**: Users should never wonder what something does
2. **Invisible Until Needed**: Menu bar presence, minimal notifications
3. **Respect Intelligence**: Show reasoning, provide escape hatches, trust users
4. **Speed is a Feature**: <100ms UI responses, instant feedback
5. **Native First**: Embrace macOS patterns, use system colors/fonts
6. **Opinionated Defaults, Flexible Options**: Smart suggestions, but user can override
7. **Progressive Disclosure**: Start simple, reveal complexity as needed
8. **Error Prevention**: Preview before committing, confirm destructive actions

---

## Voice & Tone for Copy

**Writing Principles**:
- Clear over clever (no puns, no jokes)
- Confident, not arrogant (state facts, don't apologize unnecessarily)
- Helpful, not judgmental (never comment on messiness)
- Specific, not vague (use exact numbers, concrete actions)

**Examples**:
✅ "Organized 102 files"
❌ "Boom! Your files are tidy now!"

✅ "No files found"
❌ "Looks like you're all caught up, champ!"

✅ "43 PDFs → Documents/Finance/Invoices"
❌ "Some documents will be moved"

---

## What I Want You to Create

### Phase 1: UI Prototype (Your Primary Focus)

**Deliverables**:
1. **Main Review Interface** (list or card view - your choice based on what feels more refined)
2. **Menu Bar Dropdown** (clean, minimal, functional)
3. **Settings/Rules Screen** (clear rule management)
4. **Empty State** (when no files to organize)
5. **Success State** (after organizing files)

**For Each Screen**:
- Complete SwiftUI implementation
- Both light and dark mode support
- Proper spacing (8pt grid)
- Typography hierarchy
- Color palette adherence
- Keyboard shortcuts
- Accessibility labels
- Micro-animations (subtle, purposeful, 200-300ms)

### Phase 2: Design System Components

Create reusable SwiftUI components:
- Buttons (primary, secondary, icon)
- File list items
- Cards/containers
- Form inputs
- Status indicators
- Progress bars
- Empty state templates

---

## Creative Freedom & Flexibility

**Where You Have Creative License**:
- Exact layout and composition of screens
- Specific iconography choices (use SF Symbols)
- Micro-interaction details
- Animation timings and easing
- Information hierarchy within constraints
- Component composition and reusability
- Deciding between list vs. card view for review interface

**Where You Should Stay True**:
- Color palette (Obsidian, Bone White, Steel Blue, Sage)
- Brand attributes (Precise, Refined, Confident)
- Typography system (SF Pro)
- Spacing system (8pt grid)
- Overall minimalist, monochromatic aesthetic
- Native macOS patterns and conventions

**Think of it like this**: The brand guidelines are the musical key and tempo. You're free to compose the melody, harmony, and arrangement - but stay in key.

---

## Success Criteria

The UI you create should:
1. **Feel precise**: Every pixel considered, aligned to grid, exact spacing
2. **Look refined**: Generous whitespace, restrained color, premium feel
3. **Communicate confidence**: Clear hierarchy, direct copy, opinionated
4. **Work beautifully**: Both light and dark mode, smooth animations
5. **Be native**: Feels like it was made by Apple for macOS
6. **Inspire trust**: Through clarity, consistency, and attention to detail

When I see it, I should think: "This is exactly the level of craft I want for creative professionals."

---

## Reference Documentation Available

In the `/Docs` folder you'll find:
- `Forma-Design-Doc.md`: Complete product vision, features, user flows
- `Forma-Brand-Guidelines.md`: Detailed brand system, voice, examples
- `Forma-Onboarding-Flow.md`: User onboarding journey (if needed)

**Use these as reference**, but the design inspiration images should guide your visual instincts.

---

## Implementation Notes

**Gemini 3 Pro Specific**:
- Take advantage of your multimodal capabilities - analyze the design inspiration images
- Synthesize the creative brief (brand attributes) with technical spec (SwiftUI requirements)
- Create a detailed execution plan first, then scaffold the project
- Produce artifacts that are easy to validate (screenshots, implementation plans)

**macOS/SwiftUI Specific**:
- Use `@main` with `App` protocol
- Menu bar app structure with `NSApplicationDelegate`
- SwiftUI for all UI
- `ColorScheme` environment for dark mode
- System colors via `Color(NSColor.labelColor)` etc.
- SF Symbols for icons: `Image(systemName: "folder")`

---

## My Request to You

**Please create**:

1. **An implementation plan** showing the structure and approach
2. **Complete SwiftUI code** for the core screens (focus on review interface)
3. **A visual design system** file documenting your component choices
4. **Mock data structures** to populate the UI
5. **Screenshots or descriptions** of key states (normal, empty, success)

**Start with the Main Review Interface** - this is the heart of the app. Make it feel precise, refined, and confident. Make it something a creative professional would be proud to use daily.

**Remember**: I can handle the backend logic later. Right now, I need to fall in love with the visual language. Make me feel like this app has *form*.

---

## Final Guidance

The design inspiration images show a certain aesthetic sensibility - clean, structured, sophisticated, minimal. But they're not the only way to achieve precision and refinement.

**Trust your interpretation of the brand attributes**. If you see a way to make something more precise, more refined, more confident while staying within the palette and typography system - do it.

I want to be surprised by how well you understand the vision, not by how closely you copied someone else's homework.

**Begin when ready. Show me what Forma should look like.**
