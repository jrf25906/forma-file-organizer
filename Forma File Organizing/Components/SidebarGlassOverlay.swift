import SwiftUI
import AppKit

/// Xcode-style sidebar glass overlay with nested corner radii.
struct SidebarGlassOverlay: View {
    let isKeyWindow: Bool
    var body: some View {
        ZStack {
            VisualEffectView(
                material: .popover,
                blendingMode: .withinWindow,
                state: isKeyWindow ? .active : .inactive
            )
            
            // Refraction / Volume Gradient (White sheen)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
