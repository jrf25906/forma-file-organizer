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
            GradientBackdropView(intensity: Color.FormaOpacity.medium, animated: isKeyWindow)
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
            if reduceTransparency {
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
                        if DebugFlags.baseSurfaceEnabled {
                            paneSurfaceWash
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
        .raised
    }

    private var paneSurfaceWash: Color {
        Color.formaSurfaceChrome.opacity(colorScheme == .dark ? 0.46 : 0.42)
    }

    private var fallbackColor: Color {
        Color.formaSurfaceChrome.opacity(colorScheme == .dark ? 0.78 : 0.66)
    }

    private var tintColor: Color {
        switch role {
        case .sidebar:
            return Color.formaMutedBlue
        case .content:
            return Color.formaMutedBlue
        case .inspector:
            return Color.formaMutedBlue
        }
    }

    private var surfaceTintOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.82
        let base = colorScheme == .dark ? 0.52 : 0.42
        return base * activeMultiplier
    }

    private var sheenTopOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.78
        let base = colorScheme == .dark ? 0.026 : 0.045
        return base * activeMultiplier
    }

    private var sheenBottomOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.78
        let base = colorScheme == .dark ? 0.02 : 0.04
        return base * activeMultiplier
    }

    private var backdropOverlayOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.72
        return (colorScheme == .dark ? 0.13 : 0.10) * activeMultiplier
    }

    private var grainIntensity: Float {
        0.50
    }

    private var grainOpacity: Double {
        colorScheme == .dark ? 0.038 : 0.026
    }

    private var roleAccentGradient: LinearGradient {
        return LinearGradient(
            colors: [
                Color.formaMutedBlue.opacity(colorScheme == .dark ? 0.22 : 0.16),
                Color.formaSurfaceAnchor.opacity(colorScheme == .dark ? 0.16 : 0.12),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accentOverlayOpacity: Double {
        let activeMultiplier = isWindowActive ? 1.0 : 0.75
        return (colorScheme == .dark ? 0.040 : 0.030) * activeMultiplier
    }

    @ViewBuilder
    private var edgeDivider: some View {
        switch role {
        case .sidebar:
            EmptyView()
        case .content:
            EmptyView()
        case .inspector:
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.formaObsidian.opacity(colorScheme == .dark ? 0.14 : 0.035),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 22)
                Spacer()
            }
        }
    }
}
