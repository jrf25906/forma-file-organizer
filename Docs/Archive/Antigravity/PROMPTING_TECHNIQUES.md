# Advanced Prompting Techniques for Forma + Antigravity

## Gemini 3 Pro Optimization Strategies

### 1. Structured Delimiters (Used in Main Prompt)

Gemini 3 responds exceptionally well to clear XML-style tags:

```xml
<context>
Background information and setup
</context>

<task>
Specific objective to accomplish
</task>

<constraints>
Hard boundaries that must be respected
</constraints>

<creative_freedom>
Areas where you have flexibility
</creative_freedom>

<examples>
Pattern demonstrations
</examples>
```

**Why this works**: Gemini 3 can better compartmentalize different types of information and apply the right level of strictness to each section.

---

### 2. Role Definition (Critical for Design Work)

Always start with WHO the model is and WHO the audience is:

```
You are an expert SwiftUI developer and macOS UI/UX designer...
Your audience is creative professionals who value precision...
```

**Why this works**: Sets context for vocabulary, technical depth, and aesthetic judgment.

---

### 3. Multimodal Reference Pattern

For design work with visual inspiration:

```xml
<design_inspiration>
[Reference to images]

Use these as aesthetic anchors - absorb the mood,
the restraint, the sophistication - but DO NOT
simply replicate them.

Internalize these principles and create something
original that feels like it belongs to the same
design universe.
</design_inspiration>
```

**Why this works**: Encourages synthesis rather than copying, while still providing visual context.

---

### 4. Brand Attribute Anchoring

Instead of detailed requirements, use descriptive attributes:

```
Core Brand Attributes:
- Precise: Exact, structured, every detail matters
- Refined: Minimalist, premium feel without excess
- Confident: Direct, opinionated, self-assured
```

Then reference these throughout:
```
"Make the copy more **confident** and direct"
"Add more **precision** to the spacing"
"This needs to feel more **refined**"
```

**Why this works**: Creates a shared vocabulary for feedback and gives the model interpretive guidance rather than rigid rules.

---

### 5. Success Criteria Pattern

End with qualitative success metrics:

```
The UI should make me think:
"This is exactly the level of craft I want
for creative professionals."
```

**Why this works**: Gives the model a target feeling/reaction to aim for, not just checklist items.

---

## Iteration Patterns

### Pattern 1: Constraint Tightening

**First pass**: Broad creative freedom
```
"Create a file review interface that feels refined and minimalist"
```

**Second pass**: Add specific constraints based on output
```
"The layout is good, but constrain it to a 2-column grid:
left for list, right for preview"
```

### Pattern 2: Variation Exploration

Ask for multiple options with different emphases:

```
"Show me three variations of the main screen:
1. Optimize for information density
2. Optimize for visual elegance
3. Balance between the two

All should maintain the brand attributes."
```

### Pattern 3: Component Isolation

Zoom in on specific elements:

```
"Focus only on the file list item component.
Create 5 variations exploring different:
- Typography hierarchies
- Spacing strategies
- Visual treatments for status indicators

Maintain the 8pt grid and color palette."
```

---

## Feedback Optimization

### Effective Feedback Structure

```xml
<what_works>
The overall layout and spacing feel precise and refined.
The typography hierarchy is clear.
Dark mode is well-executed.
</what_works>

<what_needs_work>
1. The Steel Blue accent feels too saturated
2. The empty state lacks personality
3. The file preview is too small
</what_needs_work>

<specific_changes>
- Reduce Steel Blue saturation by 15%
- Add a subtle geometric illustration to empty state
- Increase preview pane width by 100px
</specific_changes>

<maintain>
Keep the current spacing system and typography.
Don't change the overall layout structure.
</maintain>
```

### Avoid Vague Feedback

❌ "Make it better"
❌ "This doesn't feel right"
❌ "More professional"

✅ "Increase the visual weight of primary actions by making them 2pt bolder"
✅ "The success state feels too celebratory - dial back to modest confirmation"
✅ "Add 16px more vertical spacing between list items for better scanability"

---

## Design System Evolution Prompts

### Creating a Component Library

```
"Extract all reusable components from the main screen into
a design system file. For each component, provide:

1. Component name and purpose
2. All visual states (default, hover, active, disabled)
3. Props/parameters
4. Usage examples
5. Accessibility considerations

Format as SwiftUI code with comments."
```

### Responsive Behavior Definition

```
"Define responsive behavior for all screens:

Breakpoints:
- Minimum: 600x400px (constrained state)
- Comfortable: 800x600px (preferred)
- Large: 1200x800px+ (spacious)

For each breakpoint, specify:
- Layout changes
- Spacing adjustments
- Typography scaling
- Component reflow

Maintain the brand attributes at all sizes."
```

### Dark Mode Refinement

```
"Review the dark mode implementation through
the lens of the brand attributes:

Precise: Are contrast ratios exact and measurable?
Refined: Does it maintain the premium feel?
Confident: Are colors assertive, not washed out?

Provide specific color adjustments if needed,
with hex values and rationale."
```

---

## Advanced Gemini 3 Techniques

### 1. Chain of Thought for Complex Decisions

```
"Before generating the code, think through:

1. What layout pattern best serves users reviewing
   many files quickly while maintaining elegance?
2. How can we make status indicators (has rule,
   no rule) immediately scannable without visual noise?
3. What interaction model feels most native to macOS
   while being efficient?

Share your reasoning, then implement based on
your conclusions."
```

### 2. Comparative Analysis

```
"Compare two approaches for the review interface:

Approach A: List view with inline actions
Approach B: Card view with focused single-file review

For each, analyze:
- Efficiency for processing many files
- Visual elegance and refinement
- Cognitive load on user
- Alignment with brand attributes

Recommend one with detailed rationale."
```

### 3. Progressive Enhancement

```
"Start with the absolute minimal version that
demonstrates the core visual language:

Phase 1: Static layouts, hardcoded data
Phase 2: Add interaction states (hover, active)
Phase 3: Add transitions and micro-animations
Phase 4: Add accessibility and keyboard navigation

Build incrementally so I can validate the
foundation before adding complexity."
```

---

## Handling Edge Cases

### When Output Drifts from Brand

```
"I'm seeing brand drift in these areas:

1. The color palette is becoming too saturated
   → Pull back to monochromatic with subtle accents

2. The copy is too casual ('Hey there!')
   → Make it professional and direct

3. The UI feels busy with too many elements
   → Embrace whitespace, reduce visual elements

Reference: Forma is Precise, Refined, Confident -
not Playful, Colorful, or Casual.

Revise maintaining strict brand adherence."
```

### When Technical Constraints Conflict with Design

```
"I understand the visual goal, but SwiftUI has
limitations for [specific issue].

Either:
1. Find a workaround that maintains the aesthetic
2. Propose an alternative that's technically feasible
   while staying true to Precise, Refined, Confident

Explain the trade-offs of each approach."
```

---

## Meta-Prompting for Your Use Case

### Teaching Gemini Your Preferences

After a few iterations, you can create a "style guide" prompt:

```
"Based on our previous work on Forma, I've noticed
I consistently prefer:

Layout:
- More whitespace over information density
- Asymmetric layouts over centered symmetry
- Sharp corners over rounded (2px max)

Typography:
- Bold hierarchy (big size jumps)
- Generous line height (1.6x minimum)
- Left-aligned everything

Interactions:
- Subtle over dramatic
- Fast (200ms) over slow
- Direct feedback over delayed

Apply these preferences to all future Forma work
while maintaining the core brand attributes."
```

### Creating Shorthand References

```
"When I say 'more Forma', I mean:
- Increase whitespace
- Reduce saturation
- Sharpen typography hierarchy
- Make interactions more direct
- Remove decorative elements

When I say 'less Forma', I mean:
- Add visual warmth
- Soften edges slightly
- Make copy friendlier
- Add subtle personality

Use this shorthand in our feedback loop."
```

---

## Workflow Optimization

### Rapid Iteration Cycle

```
Round 1: "Create [component] with these requirements [...]"
         → Review output

Round 2: "More Forma. Specifically: [2-3 adjustments]"
         → Review output

Round 3: "Perfect. Now create 3 variations exploring [aspect]"
         → Choose favorite

Round 4: "Lock this in. Document as reusable component."
```

### Parallel Exploration

```
"In parallel, create:

Thread A: Main review interface optimized for speed
Thread B: Main review interface optimized for elegance
Thread C: Main review interface balancing both

Use the same component library and brand system,
but optimize the layout and interaction model
differently.

Label each clearly so I can compare."
```

---

## Validation Prompts

### Before Finalizing

```
"Before we consider this complete, validate:

Brand Alignment:
- [ ] Precise: Is every measurement exact?
- [ ] Refined: Is whitespace generous?
- [ ] Confident: Is language direct?

Technical Quality:
- [ ] SwiftUI best practices followed?
- [ ] Dark mode properly implemented?
- [ ] Accessibility labels present?
- [ ] Keyboard navigation works?

User Experience:
- [ ] Primary task is obvious?
- [ ] Feedback is immediate?
- [ ] Errors are prevented, not handled?

Report any gaps before I review."
```

### Accessibility Check

```
"Run an accessibility audit:

1. VoiceOver: Can all actions be accessed?
2. Keyboard: Can I navigate without mouse?
3. Contrast: Do all colors meet WCAG AA?
4. Motion: Is reduced motion supported?
5. Dynamic Type: Does text scale properly?

Provide a checklist with pass/fail for each,
and fix any failures."
```

---

## Remember

The best prompt is the one that:
1. **Provides clear constraints** where you have strong opinions
2. **Allows creative freedom** where you want to be surprised
3. **Establishes shared language** for efficient iteration
4. **Defines success qualitatively** not just technically

Your main prompt does all of this. These techniques help you refine from there.

---

## Quick Reference Card

### When starting fresh:
Use structured XML tags, define role, reference brand attributes

### When iterating:
Reference brand attributes in feedback, use specific measurements

### When stuck:
Ask for variations, comparative analysis, or reasoning

### When finalizing:
Run validation prompts, accessibility checks, edge case testing

**Trust Gemini 3's synthesis ability. Trust your aesthetic instinct. The magic happens where they meet.**
