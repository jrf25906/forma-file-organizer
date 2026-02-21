import SwiftUI
import AppKit

/// Xcode-style sidebar glass overlay with nested corner radii.
struct SidebarGlassOverlay: View {
    let isKeyWindow: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var sheenGradient: LinearGradient {
        // macOS standard liquid glass window reflection approach: Let the top material have a very light
        // solid edge, fading transparent immediately to let the popover material do the heavy lifting.
        let topOpacity: Double = colorScheme == .dark
            ? Color.FormaOpacity.light
            : Color.FormaOpacity.medium
        
        let bottomOpacity: Double = colorScheme == .dark
            ? Color.FormaOpacity.ultraSubtle
            : Color.FormaOpacity.subtle

        return LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(topOpacity),
                Color.formaBoneWhite.opacity(bottomOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            VisualEffectView(
                material: .popover,
                blendingMode: .withinWindow,
                state: isKeyWindow ? .active : .inactive
            )
            
            // Refraction / Volume Gradient (White sheen)
            sheenGradient
            .blendMode(.overlay)
        }
    }
}

#if DEBUG
struct SidebarGlassOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            SidebarGlassOverlay(isKeyWindow: true)
                .frame(width: FormaLayout.Dashboard.sidebarExpandedWidth)
        }
        .frame(width: 420, height: 520)
        .previewDisplayName("Sidebar Glass Overlay")
    }
}
#endif
