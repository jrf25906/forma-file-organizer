import SwiftUI

/// A focus-aware background view that switches between a vibrant gradient (when active)
/// and a frosted glass slab (when inactive), similar to proper macOS widgets.
struct PrimaryBackgroundView: View {
    @State private var isKeyWindow = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Inactive State: Frosted Glass Slab
            // This allows the desktop to bleed through when the app is in the background.
            VisualEffectView(
                material: .underWindowBackground, // Use underWindowBackground for that "desktop bleed" feel
                blendingMode: .behindWindow,      // Blend behind the window content
                state: .active                    // Always active so it shows up even when window is inactive (wait, if we want it ONLY when inactive, we can control opacity)
            )
            // .opacity(isKeyWindow ? 0 : 1) // Removed to keep blur active in focus state
            // .animation(.easeInOut(duration: 0.2), value: isKeyWindow)

            // Active State: Gradient Backdrop
            // This is the vibrant Forma-brand gradient content.
            GradientBackdropView(intensity: 1.0)
                .opacity(isKeyWindow ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isKeyWindow)
            
            // Key Window Observer
            WindowKeyObserver(isKeyWindow: $isKeyWindow)
                .frame(width: 0, height: 0)
        }
        .ignoresSafeArea()
    }
}
