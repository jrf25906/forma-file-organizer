import SwiftUI
import AppKit

/// A focus-aware background view that switches between a vibrant gradient (when active)
/// and a frosted glass slab (when inactive), similar to proper macOS widgets.
struct PrimaryBackgroundView: View {
    @State private var isKeyWindow = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            GradientBackdropView(intensity: Color.FormaOpacity.high, animated: isKeyWindow)
                .opacity(isKeyWindow ? 1 : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isKeyWindow)
            
            // Key Window Observer
            WindowKeyObserver(isKeyWindow: $isKeyWindow)
                .frame(width: 0, height: 0)
        }
        .ignoresSafeArea()
    }
}

/// Shared pane background styling for split-view columns.
/// Keeps native macOS chrome while restoring Forma's depth and vibrancy.
struct PaneMaterialBackground: View {
    enum Role {
        case sidebar
        case content
        case inspector
    }

    let role: Role

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private enum DebugFlags {
        #if DEBUG
        private static let arguments = Set(CommandLine.arguments)
        static let baseOnly = arguments.contains("--debug-pane-base-only")
        static let baseSurfaceEnabled = !arguments.contains("--debug-pane-disable-base")
        static let ambientOverlayEnabled = !arguments.contains("--debug-pane-disable-ambient")
        static let accentOverlayEnabled = !arguments.contains("--debug-pane-disable-accent")
        static let sheenOverlayEnabled = !arguments.contains("--debug-pane-disable-sheen")
        static let grainOverlayEnabled = !arguments.contains("--debug-pane-disable-grain")
        #else
        static let baseOnly = false
        static let baseSurfaceEnabled = true
        static let ambientOverlayEnabled = true
        static let accentOverlayEnabled = true
        static let sheenOverlayEnabled = true
        static let grainOverlayEnabled = true
        #endif

        static var showsAmbientOverlay: Bool { !baseOnly && ambientOverlayEnabled }
        static var showsAccentOverlay: Bool { !baseOnly && accentOverlayEnabled }
        static var showsSheenOverlay: Bool { !baseOnly && sheenOverlayEnabled }
        static var showsGrainOverlay: Bool { !baseOnly && grainOverlayEnabled }
    }

    private var isWindowActive: Bool {
        controlActiveState != .inactive
    }

    var body: some View {
        ZStack {
            if usesOpaquePanelSurface {
                inspectorOpaqueBackground
            } else if reduceTransparency {
                fallbackColor
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .background {
                        if DebugFlags.baseSurfaceEnabled {
                            FormaMaterialSurface(
                                tier: materialTier,
                                cornerRadius: 0,
                                tint: tintColor.opacity(surfaceTintOpacity)
                            )
                        } else {
                            Color.clear
                        }
                    }
                    .overlay {
                        if DebugFlags.showsAmbientOverlay {
                            paneAmbientGradient
                                .blendMode(.overlay)
                                .opacity(backdropOverlayOpacity)
                        }
                    }
                    .overlay {
                        if DebugFlags.showsAccentOverlay {
                            roleAccentGradient
                                .blendMode(.overlay)
                                .opacity(accentOverlayOpacity)
                        }
                    }
                    .overlay {
                        if DebugFlags.showsSheenOverlay {
                            LinearGradient(
                                colors: [
                                    Color.formaBoneWhite.opacity(sheenTopOpacity),
                                    Color.formaBoneWhite.opacity(sheenBottomOpacity)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .blendMode(.screen)
                        }
                    }
                    .overlay {
                        if DebugFlags.showsGrainOverlay {
                            Rectangle()
                                .fill(Color.formaBoneWhite.opacity(0.001))
                                .formaFrostedTexture(intensity: grainIntensity)
                                .opacity(grainOpacity)
                        }
                    }
            }

            edgeDivider
        }
    }

    @ViewBuilder
    private var inspectorOpaqueBackground: some View {
        Rectangle()
            .fill(
                colorScheme == .dark
                    ? Color.formaControlBackground
                    : Color.formaBoneWhite
            )
    }

    private var usesOpaquePanelSurface: Bool {
        role == .inspector
    }

    private var paneAmbientGradient: LinearGradient {
        let top = Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.08 : 0.10)
        let mid = tintColor.opacity(colorScheme == .dark ? 0.12 : 0.10)
        let bottom = Color.formaObsidian.opacity(colorScheme == .dark ? 0.08 : 0.04)

        return LinearGradient(
            colors: [top, mid, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var materialTier: FormaMaterialTier {
        switch role {
        case .sidebar:
            return .raised
        case .content:
            return .base
        case .inspector:
            return .raised
        }
    }

    private var fallbackColor: Color {
        switch role {
        case .sidebar:
            return Color.formaControlBackground.opacity(colorScheme == .dark ? 0.84 : 0.95)
        case .content:
            return Color.formaBackground
        case .inspector:
            return Color.formaControlBackground.opacity(colorScheme == .dark ? 0.82 : 0.94)
        }
    }

    private var tintColor: Color {
        switch role {
        case .sidebar:
            return Color.formaMutedBlue
        case .content:
            return Color.formaMutedBlue
        case .inspector:
            return Color.formaSage
        }
    }

    private var surfaceTintOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.82

        let base: Double
        switch role {
        case .sidebar:
            base = colorScheme == .dark ? 0.78 : 0.62
        case .content:
            base = colorScheme == .dark ? 0.40 : 0.28
        case .inspector:
            base = colorScheme == .dark ? 0.56 : 0.44
        }

        return base * activeMultiplier
    }

    private var sheenTopOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.78

        let base: Double
        switch role {
        case .sidebar:
            base = colorScheme == .dark ? 0.06 : 0.10
        case .content:
            base = colorScheme == .dark ? 0.025 : 0.055
        case .inspector:
            base = colorScheme == .dark ? 0.04 : 0.07
        }

        return base * activeMultiplier
    }

    private var sheenBottomOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.78

        let base: Double
        switch role {
        case .sidebar:
            base = colorScheme == .dark ? 0.02 : 0.04
        case .content:
            base = colorScheme == .dark ? 0.01 : 0.03
        case .inspector:
            base = colorScheme == .dark ? 0.02 : 0.04
        }

        return base * activeMultiplier
    }

    private var backdropOverlayOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.72

        switch role {
        case .sidebar:
            return (colorScheme == .dark ? 0.30 : 0.22) * activeMultiplier
        case .content:
            return (colorScheme == .dark ? 0.12 : 0.08) * activeMultiplier
        case .inspector:
            return (colorScheme == .dark ? 0.16 : 0.12) * activeMultiplier
        }
    }

    private var grainIntensity: Float {
        switch role {
        case .sidebar:
            return 0.72
        case .content:
            return 0.42
        case .inspector:
            return 0.50
        }
    }

    private var grainOpacity: Double {
        switch role {
        case .sidebar:
            return colorScheme == .dark ? 0.10 : 0.07
        case .content:
            return colorScheme == .dark ? 0.05 : 0.035
        case .inspector:
            return colorScheme == .dark ? 0.06 : 0.045
        }
    }

    private var roleAccentGradient: LinearGradient {
        let top: Color
        let middle: Color

        switch role {
        case .sidebar:
            top = Color.formaMutedBlue.opacity(colorScheme == .dark ? 0.34 : 0.24)
            middle = Color.formaSurfaceAnchor.opacity(colorScheme == .dark ? 0.20 : 0.16)
        case .content:
            top = Color.formaMutedBlue.opacity(colorScheme == .dark ? 0.18 : 0.12)
            middle = Color.formaWarmOrange.opacity(colorScheme == .dark ? 0.10 : 0.06)
        case .inspector:
            top = Color.formaSage.opacity(colorScheme == .dark ? 0.28 : 0.18)
            middle = Color.formaWarmOrange.opacity(colorScheme == .dark ? 0.12 : 0.08)
        }

        return LinearGradient(
            colors: [top, middle, Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accentOverlayOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.75

        switch role {
        case .sidebar:
            return (colorScheme == .dark ? 0.18 : 0.13) * activeMultiplier
        case .content:
            return (colorScheme == .dark ? 0.06 : 0.04) * activeMultiplier
        case .inspector:
            return (colorScheme == .dark ? 0.08 : 0.06) * activeMultiplier
        }
    }

    @ViewBuilder
    private var edgeDivider: some View {
        switch role {
        case .sidebar:
            HStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.10 : 0.16))
                    .frame(width: 1)
            }
        case .content:
            EmptyView()
        case .inspector:
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.08 : 0.14))
                    .frame(width: 1)
                Spacer()
            }
        }
    }
}
