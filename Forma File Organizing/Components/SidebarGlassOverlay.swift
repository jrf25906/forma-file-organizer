import SwiftUI
import AppKit

/// Xcode-style sidebar glass overlay with nested corner radii.
struct SidebarGlassOverlay: View {
    let isKeyWindow: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var sheenGradient: LinearGradient {
        let topOpacity: Double = colorScheme == .dark
            ? (isKeyWindow ? 0.08 : 0.05)
            : (isKeyWindow ? 0.12 : 0.08)
        let bottomOpacity: Double = colorScheme == .dark
            ? (isKeyWindow ? 0.025 : 0.015)
            : (isKeyWindow ? 0.04 : 0.025)

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
