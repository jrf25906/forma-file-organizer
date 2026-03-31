import SwiftUI

/// Xcode-style sidebar glass overlay with nested corner radii.
struct SidebarGlassOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState

    private var isWindowActive: Bool {
        controlActiveState != .inactive
    }

    private var glassStyle: FormaSidebarGlassStyle {
        FormaControlChromePalette.sidebarGlassStyle(colorScheme, isWindowActive: isWindowActive)
    }

    private var sheenGradient: LinearGradient {
        return LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(glassStyle.sheenTopOpacity),
                Color.formaBoneWhite.opacity((glassStyle.sheenTopOpacity + glassStyle.sheenBottomOpacity) * 0.5),
                Color.formaBoneWhite.opacity(glassStyle.sheenBottomOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            sheenGradient
                .blendMode(.overlay)

            HStack(spacing: 0) {
                Spacer()

                Rectangle()
                    .fill(Color.formaBoneWhite.opacity(glassStyle.edgeOpacity))
                    .frame(width: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
struct SidebarGlassOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            SidebarGlassOverlay()
                .frame(width: FormaLayout.Dashboard.sidebarExpandedWidth)
        }
        .frame(width: 420, height: 520)
        .previewDisplayName("Sidebar Glass Overlay")
    }
}
#endif
