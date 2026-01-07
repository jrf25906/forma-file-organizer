# How to Use the Antigravity Prompt for Forma

## Quick Start

1. **Open Antigravity** (Google's new agentic IDE)
2. **Copy the entire contents** of `ANTIGRAVITY_PROMPT.md`
3. **Paste into Antigravity's agent interface**
4. **Make sure the design inspiration images** are accessible to the agent
5. **Let it run** - Gemini 3 Pro will create an implementation plan and scaffold

---

## What to Expect

### Phase 1: Planning
Antigravity will likely:
- Analyze the design inspiration images
- Review the brand guidelines
- Create a detailed task breakdown
- Propose an implementation plan
- Ask for your approval before proceeding

### Phase 2: Implementation
The agent will:
- Generate SwiftUI code for all screens
- Create reusable components
- Set up the project structure
- Implement both light and dark modes
- Add mock data for demonstration

### Phase 3: Artifacts
You'll receive:
- Complete Xcode project scaffold
- SwiftUI view files
- Component library
- Mock data structures
- Screenshots/previews of key states

---

## Tips for Best Results

### 1. **Let the Agent See the Images**
Make sure Antigravity has access to the `/ui design inspiration` folder. Gemini 3's multimodal capabilities are key here.

### 2. **Temperature Setting**
Keep the default temperature at **1.0**. Don't change it - Gemini 3 performs best at default settings.

### 3. **Iterative Refinement**
After the first pass:
- Review the generated UI
- Provide specific feedback on what to adjust
- Reference the brand attributes when requesting changes
  - "This feels too playful - make it more **refined**"
  - "Add more **precision** to the spacing"
  - "The copy should be more **confident** and direct"

### 4. **Use Follow-up Prompts**
If you want to refine specific aspects:

```
"The review interface looks good, but make it feel more premium by:
- Increasing whitespace between list items
- Making the typography hierarchy sharper
- Using the Steel Blue accent more sparingly"
```

Or:

```
"Show me three variations of the empty state screen:
1. More geometric/abstract
2. More playful with illustration
3. Ultra-minimal (text only)

All should maintain the Precise, Refined, Confident attributes."
```

---

## Flexibility vs. Direction

### The Prompt Strikes a Balance

**Directive on**:
- Color palette (specific hex values)
- Typography system (SF Pro, specific sizes)
- Spacing system (8pt grid)
- Brand attributes (Precise, Refined, Confident)
- Platform conventions (native macOS)

**Flexible on**:
- Exact layout composition
- Screen flow and navigation
- Micro-interaction details
- Icon choices (from SF Symbols)
- Information architecture within screens
- Which view style to use (list vs. card)

### How to Adjust the Balance

**If the output is too generic/safe:**
Add constraints:
```
"<constraint>
Use a strict 2-column grid layout for the review interface.
Left column: file list. Right column: large file preview.
</constraint>"
```

**If the output is too rigid:**
Loosen constraints:
```
"<creative_freedom>
Feel free to explore unconventional layouts for the settings screen
as long as they maintain the minimalist, refined aesthetic.
</creative_freedom>"
```

---

## Watching for Brand Drift

### Good Signs (Stays True to Forma)
- Generous whitespace
- Monochromatic with subtle accents
- Precise alignment and spacing
- Clear, direct copy
- Native macOS feel
- Minimal corner rounding (2-10px)
- Subtle, purposeful animations

### Warning Signs (Brand Drift)
- Bright, vibrant colors
- Playful or cutesy copy
- Rounded, bubbly UI elements
- Decorative illustrations
- Excessive animations
- Non-native controls
- Centered body text

**If you see drift**: Reference the brand attributes explicitly in feedback.

---

## Gemini 3 Pro Specific Features

### Multimodal Analysis
Gemini 3 can analyze the design inspiration images and extract:
- Color relationships
- Spacing patterns
- Typography hierarchy
- Visual rhythm
- Compositional balance

This is why including the images is crucial - it gives the model visual context beyond text descriptions.

### Agentic Breakdown
Antigravity's agent will:
1. Break the prompt into subtasks
2. Create an execution plan
3. Generate artifacts for validation
4. Allow you to approve/modify before full implementation

**Trust this process** - Gemini 3 is designed to handle complex, creative+technical prompts.

### Artifacts You'll Get
- Task lists (showing the breakdown)
- Implementation plans (architecture decisions)
- Code scaffolds (runnable projects)
- Screenshots/mockups (visual validation)
- Design system documentation

---

## Iterating on the Output

### Round 1: Accept the Foundation
Even if it's not perfect, accept the first pass if it's in the right direction. You can refine from there.

### Round 2: Targeted Refinements
Focus on specific areas:
```
"The main review interface is great, but:
1. Increase vertical spacing between file items to 24px
2. Make the file name bolder (Semibold instead of Regular)
3. Reduce the opacity of the current/suggested paths to 60%"
```

### Round 3: Polish Details
```
"Add subtle hover states to all interactive elements:
- Buttons: Scale to 0.98 on press (150ms)
- List items: 5% gray background on hover
- Icons: Slight opacity change on hover"
```

### Round 4: Dark Mode Tuning
```
"Review the dark mode implementation and ensure:
- Contrast ratios meet WCAG AA
- The Steel Blue accent is still visible
- Shadows are inverted appropriately"
```

---

## Common Adjustments You Might Want

### If the UI feels too dense:
```
"Double the vertical spacing between major sections.
Apply the 8pt grid more generously - err on the side of more whitespace."
```

### If the colors feel too muted:
```
"Increase the saturation of Steel Blue by 10% to make it pop more
against the monochromatic background."
```

### If the typography feels flat:
```
"Create more dramatic size contrast between headers and body text.
Make H1 28pt instead of 24pt."
```

### If it feels too corporate:
```
"Add subtle personality through:
- Smoother animation curves
- More elegant empty states
- Warmer success messages (but still professional)"
```

### If it feels too playful:
```
"Pull back on:
- Animation complexity
- Emoji usage
- Casual language
Make everything more restrained and sophisticated."
```

---

## Success Metrics

### You'll know it's working when:
1. **First Reaction**: "Oh, this is beautiful"
2. **Second Look**: "Every detail is considered"
3. **Interaction**: "This feels native and natural"
4. **Dark Mode**: "Both modes are equally refined"
5. **Overall**: "I would pay for software that looks like this"

### You'll know it needs work when:
1. "This looks like a generic template"
2. "The colors feel off-brand"
3. "The spacing is inconsistent"
4. "This doesn't feel premium"
5. "I've seen this UI pattern everywhere"

---

## Troubleshooting

### Agent gets stuck or loops
- Simplify the prompt
- Break it into smaller phases
- Provide more specific constraints

### Output is too generic
- Reference the design inspiration more explicitly
- Add more specific visual requirements
- Include screenshot examples of what you like

### Code doesn't compile
- Ask agent to fix compilation errors
- Specify macOS version and Xcode version
- Request simpler implementations

### Dark mode looks wrong
- Request explicit dark mode color values
- Ask to test with actual macOS dark mode
- Reference system colors more explicitly

---

## After You Get the Initial Build

### Next Steps:
1. **Import into Xcode** and run it
2. **Take screenshots** of what you like/dislike
3. **Test interactions** and note friction points
4. **Try dark mode** extensively
5. **Show it to someone** (fresh eyes help)

### Then Return to Antigravity:
```
"Here's what I love: [specific elements]
Here's what needs work: [specific issues]
Here are screenshots: [attach images]

Please refine based on this feedback while maintaining
the Precise, Refined, Confident brand attributes."
```

---

## Remember

**The goal is the visual language**, not a production-ready app. You want:
- A design system you love
- Components that feel native
- A UI that embodies precision and refinement
- Something you're excited to build on

The backend implementation can come after you've fallen in love with the interface.

**Antigravity + Gemini 3 Pro + this prompt = A UI prototype that shows you exactly what Forma should feel like.**

Good luck! 🚀
