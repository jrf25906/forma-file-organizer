import SwiftUI
import AppKit

/// Xcode-style sidebar glass overlay with nested corner radii.
struct SidebarGlassOverlay: View {
    let isKeyWindow: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var sheenGradient: LinearGradient {
        let topOpacity = FormaControlChromePalette.sidebarSheenTopOpacity(colorScheme, isWindowActive: isKeyWindow)
        let bottomOpacity = FormaControlChromePalette.sidebarSheenBottomOpacity(colorScheme, isWindowActive: isKeyWindow)

        return LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(topOpacity),
                Color.formaBoneWhite.opacity((topOpacity + bottomOpacity) * 0.5),
                Color.formaBoneWhite.opacity(bottomOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            VisualEffectView(
                material: .sidebar,
                blendingMode: .withinWindow,
                state: isKeyWindow ? .active : .inactive
            )

            sheenGradient
            .blendMode(.overlay)

            HStack(spacing: 0) {
                Spacer()

                Rectangle()
                    .fill(Color.formaBoneWhite.opacity(FormaControlChromePalette.sidebarEdgeOpacity(colorScheme, isWindowActive: isKeyWindow)))
                    .frame(width: 1)
            }
        }
        .allowsHitTesting(false)
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
