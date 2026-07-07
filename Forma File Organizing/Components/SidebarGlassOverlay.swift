import SwiftUI

/// Xcode-style sidebar glass overlay with nested corner radii.
struct SidebarGlassOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var isWindowActive: Bool {
        controlActiveState != .inactive
    }

    private var glassStyle: FormaSidebarGlassStyle {
        FormaControlChromePalette.sidebarGlassStyle(
            colorScheme,
            isWindowActive: isWindowActive,
            reduceTransparency: reduceTransparency
        )
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

    private var sidebarWashGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaSurfaceChrome.opacity(colorScheme == .dark ? 0.18 : 0.30),
                Color.formaMutedBlue.opacity(colorScheme == .dark ? 0.06 : 0.08),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            sidebarWashGradient
                .blendMode(.overlay)

            sheenGradient
                .blendMode(.overlay)
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
