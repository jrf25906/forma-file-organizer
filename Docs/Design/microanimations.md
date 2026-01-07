# Forma Micro-animations

## Brand Philosophy: "Precise, Refined, Confident"

Forma is not playful or bouncy. It is a tool for bringing order to chaos. Therefore, its motion design must reflect **stability, precision, and efficiency**.

*   **No Overshoot**: Avoid "bouncy" spring animations that overshoot their target. Elements should land with certainty.
*   **High Friction**: Movements should feel deliberate and controlled, like a heavy, well-oiled machine part sliding into place.
*   **Transformative**: Objects shouldn't just appear/disappear; they should morph, flow, or slide to show where they came from or went.

## The "Forma Curve" (Easing)

Standard ease-in-out is too generic. For Forma, we use a custom curve that starts quickly (responsive) and decelerates smoothly (refined).

*   **CSS Equivalent**: `cubic-bezier(0.2, 0.0, 0.0, 1.0)`
*   **SwiftUI Equivalent**: `.interpolatingSpring(stiffness: 300, damping: 30)` (High damping prevents bounce)
*   **Feel**: "Snappy start, soft landing."

---

## Proposed Micro-animations

### 1. The "Organize" Action (File Completion)

When a user accepts a file organization rule or moves a file, it shouldn't just vanish. It should feel like it's being physically filed away.

*   **Interaction**: User clicks "Move" or "Accept".
*   **Animation**:
    1.  **Scale & Fade**: The row/card scales down slightly (to 0.95) and opacity drops.
    2.  **Slide**: Simultaneously, it slides *towards* the destination (or just to the right/left depending on UI).
    3.  **Collapse**: The remaining space collapses smoothly (height animates to 0).
*   **Reference**: **Things 3 (macOS/iOS)** - When checking off a task, it doesn't just disappear; it fades and the list closes the gap smoothly.
*   **Source**: [Cultured Code - Things 3 Design](https://culturedcode.com/things/) (Observe the task completion interaction).

### 2. View Toggle (List vs. Grid)

Switching views is a jarring context switch. We can make it fluid.

*   **Interaction**: User toggles between List and Grid modes.
*   **Animation**:
    1.  **Matched Geometry**: Use `matchedGeometryEffect` in SwiftUI.
    2.  **Morph**: The list rows should morph into the grid cards. The icon in the row becomes the preview in the card. The text reflows.
    3.  **Stagger**: Don't animate all at once. Stagger the transition of items by a few milliseconds (e.g., 0.02s delay per item) to create a "waterfall" effect.
*   **Reference**: **Apple Photos** - Pinching to zoom in/out of the grid. The items flow into their new positions.
*   **Source**: [Apple Human Interface Guidelines - Layout](https://developer.apple.com/design/human-interface-guidelines/layout)

### 3. The "Processing" Button

When clicking "Organize All", the user needs immediate feedback that work is happening, without blocking the UI with a full-screen spinner.

*   **Interaction**: Click "Organize All".
*   **Animation**:
    1.  **Morph**: The button width shrinks to a circle.
    2.  **State Change**: The text fades out, replaced by a spinner or a progress ring *inside* the button.
    3.  **Completion**: On success, the circle morphs into a checkmark icon, then expands back to the original button with "Done" or resets.
*   **Reference**: **Stripe Checkout** - The "Pay" button often contains the loading state within itself to maintain context.
*   **Source**: [Stripe Elements](https://stripe.com/docs/payments/elements) (See the payment button states).

### 4. Rule Editor Transition

Opening the rule editor should feel like bringing a focused workspace to the foreground.

*   **Interaction**: Clicking "Edit Rule" or "New Rule".
*   **Animation**:
    1.  **Background Blur**: The main content doesn't just dim; it blurs (`.blur(radius: 10)`). This pushes the background "back" in Z-space.
    2.  **Scale & Slide**: The modal shouldn't just slide up from the very bottom. It should scale up slightly (from 0.9 to 1.0) and fade in, giving the impression it was "waiting" just behind the glass.
*   **Reference**: **macOS Control Center** - It fades and blurs the background, feeling lightweight but grounded.

### 5. Hover States (The "Premium" Feel)

Standard hover is just a color change. Premium hover adds depth.

*   **Interaction**: Hovering over a file card or button.
*   **Animation**:
    1.  **Lift**: `scaleEffect(1.02)` - subtle lift.
    2.  **Shadow**: Increase shadow radius and decrease opacity slightly (softer, larger shadow).
    3.  **Highlight**: A subtle "sheen" or gradient shift across the surface.
*   **Reference**: **Linear** - Their UI elements often have subtle glows or border highlights on hover that follow the mouse cursor.
*   **Source**: [Linear Design System](https://linear.app/method) (Note the subtle interactions on cards and buttons).

### 6. Celebration Animations

When the user successfully organizes files, we celebrate their progress with appropriate feedback.

#### Standard Celebration (Batch Complete)
*   **Trigger**: User organizes files (but pending files remain)
*   **Animation**:
    1.  **Panel Transition**: Right panel smoothly transitions to celebration view
    2.  **Checkmark**: Animated checkmark appears
    3.  **Auto-dismiss**: Returns to default after 5 seconds
*   **Feel**: Quick acknowledgment - "good job, keep going"

#### Completion Celebration (Inbox Zero)
*   **Trigger**: User clears ALL pending files (inbox zero achieved)
*   **Animation**:
    1.  **Confetti Layer**: 30 particles with randomized properties:
        - Colors: Warm Orange, Sage, Steel Blue, Muted Blue (brand palette)
        - Sizes: 6-12px rectangles with rounded corners
        - Trajectories: Fall from top (-0.2 to 0 normalized Y) to bottom (1.0 to 1.3)
        - Rotation: 360° spin during fall
        - Stagger: 0-0.5s random delay per particle
        - Duration: 2-3.5s per particle (organic variation)
    2.  **Trophy Icon**: Party popper with glow rings
        - Three concentric gradient rings scale in (0.8 → 1.0)
        - Each ring has 0.1s staggered delay
        - Spring animation: `response: 0.8, dampingFraction: 0.6`
        - Icon scales from 0.3 → 1.0 with spring
    3.  **Content**: Fades in with y-offset (10px → 0)
        - 0.4s duration, 0.3s delay
    4.  **Auto-dismiss**: 10 seconds (2x standard - this is a bigger win!)
*   **Accessibility**: All animations disabled when `reduceMotion` is enabled
*   **Feel**: "You did it! Celebrate the accomplishment."
*   **Reference**: **Duolingo** - Celebrates completion milestones with confetti and encouraging messages

**Implementation Note**: Confetti uses `GeometryReader` with normalized coordinates (0-1) for responsive sizing. Each `ConfettiPiece` manages its own animation state to prevent coordination overhead.

```swift
// Confetti Particle Properties
struct ConfettiParticle: Identifiable {
    let color: Color          // Brand color
    let size: CGFloat         // 6-12px
    let x: CGFloat            // Horizontal position (0-1)
    let startY: CGFloat       // Starting Y (-0.2 to 0)
    let endY: CGFloat         // Ending Y (1.0 to 1.3)
    let rotation: Double      // Initial rotation (0-360)
    let delay: Double         // Animation delay (0-0.5s)
    let duration: Double      // Animation duration (2-3.5s)
}
```

## Implementation Guide (SwiftUI)

To achieve the "Forma Curve" globally:

```swift
extension Animation {
    static let formaDefault = Animation.timingCurve(0.2, 0.0, 0.0, 1.0, duration: 0.4)
    static let formaSnappy = Animation.timingCurve(0.2, 0.0, 0.0, 1.0, duration: 0.25)
}
```

Usage:
```swift
.withAnimation(.formaDefault) {
    // Change state
}
```
