//
//  FormaColors.swift
//  Forma - Brand Color System
//
//  Implementation of Forma brand colors with automatic dark mode support
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI
import AppKit

private func formaDynamicColor(
    named name: String,
    _ provider: @escaping (_ isDark: Bool) -> NSColor
) -> Color {
    Color(
        NSColor(name: NSColor.Name(name)) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return provider(isDark)
        }
    )
}

/// Forma's brand color system
/// Provides both custom brand colors and semantic color usage
extension Color {
    
    // MARK: - Primary Brand Colors
    
    /// Primary dark color - use for primary text, strong UI elements, dark mode backgrounds, icon fills
    /// HEX: #1A1A1A | RGB: 26, 26, 26 | HSL: 0° 0% 10%
    static let formaObsidian = Color(red: 26/255, green: 26/255, blue: 26/255)
    
    /// Primary light color - use for light mode backgrounds, text on dark surfaces, subtle contrast
    /// HEX: #FAFAF8 | RGB: 250, 250, 248 | HSL: 60° 33% 98%
    static let formaBoneWhite = Color(red: 250/255, green: 250/255, blue: 248/255)
    
    // MARK: - Accent Colors
    
    /// Interactive accent color - use for primary actions, interactive elements, links, selected states, progress indicators
    /// HEX: #5B7C99 | RGB: 91, 124, 153 | HSL: 208° 25% 48%
    static let formaSteelBlue = Color(red: 91/255, green: 124/255, blue: 153/255)
    
    /// Success accent color - use for success states, confirmation messages, completed actions, positive feedback
    /// HEX: #7A9D7E | RGB: 122, 157, 126 | HSL: 126° 17% 55%
    static let formaSage = Color(red: 122/255, green: 157/255, blue: 126/255)
    
    // MARK: - Category Colors (from logo)
    
    /// Documents/Text files category color
    /// HEX: #6B8CA8 | RGB: 107, 140, 168
    static let formaMutedBlue = Color(red: 107/255, green: 140/255, blue: 168/255)
    
    /// Media/Images category color
    /// HEX: #C97E66 | RGB: 201, 126, 102
    static let formaWarmOrange = Color(red: 201/255, green: 126/255, blue: 102/255)
    
    /// Downloads/Archives category color
    /// HEX: #96A67E | RGB: 150, 166, 126 | HSL: 98° 17% 57%
    // #96A67E (98° 17% 57%) — olive-green, ≥15° hue separation from formaSage
    static let formaSoftGreen = Color(red: 150/255, green: 166/255, blue: 126/255)
    
    // MARK: - System Colors (Semantic)
    // Use these for UI elements that need automatic dark mode support
    
    /// Main window background (automatically adapts to light/dark mode)
    static let formaBackground = Color(NSColor.windowBackgroundColor)
    
    /// Control backgrounds (buttons, cards, etc.).
    /// Uses a deeper charcoal in dark mode so controls remain legible and intentional
    /// without collapsing into pure black.
    static let formaControlBackground = Color(
        NSColor(name: NSColor.Name("formaControlBackground")) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(red: 32/255, green: 37/255, blue: 44/255, alpha: 1.0) // #20252C
            }
            return NSColor.controlBackgroundColor
        }
    )
    
    /// Text field backgrounds.
    /// Slightly darker than control backgrounds in dark mode for clearer input affordance.
    static let formaTextBackground = Color(
        NSColor(name: NSColor.Name("formaTextBackground")) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(red: 27/255, green: 32/255, blue: 38/255, alpha: 1.0) // #1B2026
            }
            return NSColor.textBackgroundColor
        }
    )
    
    /// Card backgrounds with appearance-aware contrast.
    /// Light: #F9F9F9 | Dark: #22252A
    static let formaCardBackground = Color(
        NSColor(name: NSColor.Name("formaCardBackground")) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(red: 39/255, green: 44/255, blue: 52/255, alpha: 1.0) // #272C34
            }
            return NSColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1.0)
        }
    )

    /// Blue Slate anchor surface for strong navigation, command modules, and high-priority rails.
    /// This adapts instead of forcing a flat dark sidebar in every appearance.
    static let formaSurfaceAnchor = formaDynamicColor(named: "formaSurfaceAnchor") { isDark in
        if isDark {
            return NSColor(red: 18/255, green: 27/255, blue: 36/255, alpha: 1.0) // #121B24
        }
        return NSColor(red: 224/255, green: 233/255, blue: 241/255, alpha: 1.0) // #E0E9F1
    }

    /// Primary work surface for dense review rows, cards, and settings groups.
    static let formaSurfaceWork = formaDynamicColor(named: "formaSurfaceWork") { isDark in
        if isDark {
            return NSColor(red: 37/255, green: 43/255, blue: 51/255, alpha: 1.0) // #252B33
        }
        return NSColor(red: 253/255, green: 254/255, blue: 255/255, alpha: 1.0) // #FDFEFF
    }

    /// Cooler application chrome behind work surfaces.
    static let formaSurfaceChrome = formaDynamicColor(named: "formaSurfaceChrome") { isDark in
        if isDark {
            return NSColor(red: 28/255, green: 35/255, blue: 43/255, alpha: 1.0) // #1C232B
        }
        return NSColor(red: 237/255, green: 242/255, blue: 247/255, alpha: 1.0) // #EDF2F7
    }

    /// Floating surface for popovers, command palette chrome, and transient controls.
    static let formaSurfaceFloating = formaDynamicColor(named: "formaSurfaceFloating") { isDark in
        if isDark {
            return NSColor(red: 45/255, green: 53/255, blue: 63/255, alpha: 1.0) // #2D353F
        }
        return NSColor(red: 251/255, green: 252/255, blue: 253/255, alpha: 1.0) // #FBFCFD
    }

    /// List-row base surface. In dark mode this sits slightly above panel surfaces,
    /// preserving the elevation ladder: background -> panel -> row.
    static let formaListRowBackground = Color(
        NSColor(name: NSColor.Name("formaListRowBackground")) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(red: 44/255, green: 50/255, blue: 59/255, alpha: 0.78) // #2C323B @ 78%
            }
            return NSColor(calibratedWhite: 1.0, alpha: 0.86)
        }
    )

    /// Shared hover overlay for file surfaces. Hover should read as proximity, not commitment.
    static let formaFileSurfaceHoverOverlay = formaDynamicColor(named: "formaFileSurfaceHoverOverlay") { isDark in
        if isDark {
            return NSColor.formaBoneWhite.withAlphaComponent(0.05)
        }
        return NSColor.formaObsidian.withAlphaComponent(0.03)
    }

    /// Shared selected/focused overlay for file surfaces.
    static let formaFileSurfaceSelectionOverlay = formaDynamicColor(named: "formaFileSurfaceSelectionOverlay") { isDark in
        let alpha: CGFloat = isDark ? 0.20 : 0.12
        return NSColor.formaSteelBlue.withAlphaComponent(alpha)
    }

    /// Pending overlay for files awaiting review or confirmation.
    static let formaFileSurfacePendingOverlay = formaDynamicColor(named: "formaFileSurfacePendingOverlay") { isDark in
        let alpha: CGFloat = isDark ? 0.20 : 0.12
        return NSColor.systemOrange.withAlphaComponent(alpha)
    }

    /// Processing overlay for active work in progress.
    static let formaFileSurfaceProcessingOverlay = formaDynamicColor(named: "formaFileSurfaceProcessingOverlay") { isDark in
        let alpha: CGFloat = isDark ? 0.24 : 0.14
        return NSColor.systemBlue.withAlphaComponent(alpha)
    }

    /// Error overlay for failed file operations or permission states.
    static let formaFileSurfaceErrorOverlay = formaDynamicColor(named: "formaFileSurfaceErrorOverlay") { isDark in
        let alpha: CGFloat = isDark ? 0.22 : 0.14
        return NSColor.systemRed.withAlphaComponent(alpha)
    }

    /// Rest-state border for shared file surfaces.
    static let formaFileSurfaceBorder = formaDynamicColor(named: "formaFileSurfaceBorder") { isDark in
        if isDark {
            return NSColor.formaBoneWhite.withAlphaComponent(0.14)
        }
        return NSColor.formaObsidian.withAlphaComponent(0.10)
    }

    /// Hover border for shared file surfaces.
    static let formaFileSurfaceHoverBorder = formaDynamicColor(named: "formaFileSurfaceHoverBorder") { isDark in
        if isDark {
            return NSColor.formaBoneWhite.withAlphaComponent(0.22)
        }
        return NSColor.formaObsidian.withAlphaComponent(0.16)
    }

    /// Selected border for shared file surfaces.
    static let formaFileSurfaceSelectedBorder = formaDynamicColor(named: "formaFileSurfaceSelectedBorder") { isDark in
        let alpha: CGFloat = isDark ? 0.58 : 0.42
        return NSColor.formaSteelBlue.withAlphaComponent(alpha)
    }

    /// Focus border for shared file surfaces.
    static let formaFileSurfaceFocusedBorder = formaDynamicColor(named: "formaFileSurfaceFocusedBorder") { isDark in
        let alpha: CGFloat = isDark ? 0.86 : 0.70
        return NSColor.formaSteelBlue.withAlphaComponent(alpha)
    }

    /// Pending border for shared file surfaces.
    static let formaFileSurfacePendingBorder = formaDynamicColor(named: "formaFileSurfacePendingBorder") { isDark in
        let alpha: CGFloat = isDark ? 0.68 : 0.46
        return NSColor.systemOrange.withAlphaComponent(alpha)
    }

    /// Processing border for shared file surfaces.
    static let formaFileSurfaceProcessingBorder = formaDynamicColor(named: "formaFileSurfaceProcessingBorder") { isDark in
        let alpha: CGFloat = isDark ? 0.72 : 0.50
        return NSColor.systemBlue.withAlphaComponent(alpha)
    }

    /// Error border for shared file surfaces.
    static let formaFileSurfaceErrorBorder = formaDynamicColor(named: "formaFileSurfaceErrorBorder") { isDark in
        let alpha: CGFloat = isDark ? 0.76 : 0.54
        return NSColor.systemRed.withAlphaComponent(alpha)
    }

    /// Backward-compatible alias for existing list-row hover styling.
    static let formaListRowHoverOverlay = formaFileSurfaceHoverOverlay

    /// Backward-compatible alias for existing list-row selection styling.
    static let formaListRowSelectionOverlay = formaFileSurfaceSelectionOverlay

    /// Backward-compatible alias for existing list-row rest border styling.
    static let formaListRowBorder = formaFileSurfaceBorder

    /// Backward-compatible alias for existing list-row hover border styling.
    static let formaListRowHoverBorder = formaFileSurfaceHoverBorder

    /// Backward-compatible alias for existing list-row selected border styling.
    static let formaListRowSelectedBorder = formaFileSurfaceSelectedBorder

    /// Backward-compatible alias for existing list-row focused border styling.
    static let formaListRowFocusedBorder = formaFileSurfaceFocusedBorder
    
    /// Primary text (automatically adapts contrast for light/dark mode)
    static let formaLabel = Color(NSColor.labelColor)
    
    /// Secondary text (slightly dimmed)
    static let formaSecondaryLabel = Color(NSColor.secondaryLabelColor)
    
    /// Tertiary text (metadata, timestamps)
    static let formaTertiaryLabel = Color(NSColor.tertiaryLabelColor)

    /// Secondary text with extra contrast in dark mode (for glass/low-contrast surfaces)
    static let formaSecondaryLabelHigh = Color(
        NSColor(name: NSColor.Name("formaSecondaryLabelHigh")) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor.secondaryLabelColor
                    .blended(withFraction: 0.35, of: NSColor.labelColor)
                    ?? NSColor.secondaryLabelColor
            }
            return NSColor.secondaryLabelColor
        }
    )

    /// Tertiary text with extra contrast in dark mode (for captions and metadata)
    static let formaTertiaryLabelHigh = Color(
        NSColor(name: NSColor.Name("formaTertiaryLabelHigh")) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor.tertiaryLabelColor
                    .blended(withFraction: 0.45, of: NSColor.labelColor)
                    ?? NSColor.tertiaryLabelColor
            }
            return NSColor.tertiaryLabelColor
        }
    )

    /// Placeholder text
    static let formaQuaternaryLabel = Color(NSColor.quaternaryLabelColor)
    
    /// Borders and dividers
    static let formaSeparator = Color(NSColor.separatorColor)
    
    // MARK: - Semantic State Colors
    // Use system colors for semantic feedback
    
    /// Success state (file successfully moved, rule matched)
    static let formaSuccess = Color(NSColor.systemGreen)  // #34C759 light, #30D158 dark
    
    /// Warning state (no rule found, action needs attention)
    static let formaWarning = Color(NSColor.systemOrange)  // #FF9500 light, #FF9F0A dark
    
    /// Error state (move failed, permission denied)
    static let formaError = Color(NSColor.systemRed)  // #FF3B30 light, #FF453A dark
    
    /// Info state (helpful tips, onboarding guidance)
    static let formaInfo = Color(NSColor.systemBlue)  // #007AFF light, #0A84FF dark
    
    // MARK: - Liquid Glass Tints (macOS 26.0+)
    // Use these with .glassEffect() for consistent brand appearance
    
    /// Steel blue glass tint for primary interactive elements
    static let glassBlue = Color.formaSteelBlue.opacity(Color.FormaOpacity.strong - Color.FormaOpacity.subtle)
    
    /// Sage green glass tint for success states
    static let glassGreen = Color.formaSage.opacity(Color.FormaOpacity.overlay + Color.FormaOpacity.subtle)
    
    /// Warm orange glass tint for media/highlights
    static let glassOrange = Color.formaWarmOrange.opacity(Color.FormaOpacity.overlay + Color.FormaOpacity.subtle)
    
    /// Muted blue glass tint for documents
    static let glassMutedBlue = Color.formaMutedBlue.opacity(Color.FormaOpacity.overlay + Color.FormaOpacity.subtle)
    
    /// Soft green glass tint for downloads
    static let glassSoftGreen = Color.formaSoftGreen.opacity(Color.FormaOpacity.overlay + Color.FormaOpacity.subtle)

    // MARK: - Standardized Opacity Tokens
    // Apple Design Award refinement: Consistent opacity values across the application
    // Eliminates 30+ hardcoded opacity values for better visual consistency

    /// Opacity levels for consistent UI depth and hierarchy
    enum FormaOpacity {
        /// Ultra-subtle backgrounds, barely visible tints
        /// Use for: Very subtle hover states, minimal background tints
        static let ultraSubtle: Double = 0.02

        /// Very light backgrounds, subtle hover states
        /// Use for: Ghost button backgrounds, very light overlays
        static let subtle: Double = 0.05

        /// Light backgrounds and glass effects
        /// Use for: Hover states, glass material tints, light borders
        static let light: Double = 0.10

        /// Medium weight borders and dividers
        /// Use for: Card borders, section dividers, disabled states
        static let medium: Double = 0.20

        /// Overlay dimming, modal backgrounds
        /// Use for: Sheet/modal backdrop dimming, overlay effects
        static let overlay: Double = 0.30

        /// Strong visual elements, active states
        /// Use for: Selected state borders, prominent dividers, active overlays
        static let strong: Double = 0.50

        /// High emphasis, near-solid elements
        /// Use for: Strong text on backgrounds, high-contrast elements
        static let high: Double = 0.70

        /// Near-solid overlays, high emphasis
        /// Use for: Modal backdrops, strong overlays, emphasized elements
        static let prominent: Double = 0.80
    }

    // MARK: - Gradient Backdrop Colors
    // Use these for subtle background gradients that make glass materials more visible
    
    /// Brand color palette for gradient backdrops
    /// Order: Steel Blue (top-left), Sage (bottom-right), Warm Orange (center), Muted Blue (accent)
    static let gradientBackdropColors: [Color] = [
        .formaSteelBlue,
        .formaSage,
        .formaWarmOrange,
        .formaMutedBlue
    ]
}

enum RightRailSemanticTone: Equatable {
    case progress
    case live
    case blocked
    case failure
    case neutral

    var color: Color {
        switch self {
        case .progress:
            return .formaSteelBlue
        case .live:
            return .formaSage
        case .blocked:
            return .formaWarmOrange
        case .failure:
            return .formaError
        case .neutral:
            return .formaSecondaryLabelHigh
        }
    }
}

// MARK: - NSColor Extensions (for AppKit compatibility)

extension NSColor {
    
    /// Forma Obsidian - Primary dark
    static let formaObsidian = NSColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1.0)
    
    /// Forma Bone White - Primary light
    static let formaBoneWhite = NSColor(red: 250/255, green: 250/255, blue: 248/255, alpha: 1.0)
    
    /// Forma Steel Blue - Interactive accent
    static let formaSteelBlue = NSColor(red: 91/255, green: 124/255, blue: 153/255, alpha: 1.0)
    
    /// Forma Sage - Success accent
    static let formaSage = NSColor(red: 122/255, green: 157/255, blue: 126/255, alpha: 1.0)
    
    /// Forma Muted Blue - Documents category
    static let formaMutedBlue = NSColor(red: 107/255, green: 140/255, blue: 168/255, alpha: 1.0)
    
    /// Forma Warm Orange - Media category
    static let formaWarmOrange = NSColor(red: 201/255, green: 126/255, blue: 102/255, alpha: 1.0)
    
    /// Forma Soft Green - Downloads category
    // #96A67E (98° 17% 57%) — olive-green, ≥15° hue separation from formaSage
    static let formaSoftGreen = NSColor(red: 150/255, green: 166/255, blue: 126/255, alpha: 1.0)
}

// MARK: - Color Blending

extension Color {
    /// Blend this color with another color at a given ratio
    /// - Parameters:
    ///   - other: The color to blend with
    ///   - ratio: 0.0 = this color, 1.0 = other color
    /// - Returns: A new blended color
    func blend(with other: Color, ratio: Double) -> Color {
        let ratio = max(0, min(1, ratio))

        // Convert to NSColor for component access
        guard let thisNS = NSColor(self).usingColorSpace(.sRGB),
              let otherNS = NSColor(other).usingColorSpace(.sRGB) else {
            return self
        }

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        thisNS.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherNS.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return Color(
            red: r1 + (r2 - r1) * ratio,
            green: g1 + (g2 - g1) * ratio,
            blue: b1 + (b2 - b1) * ratio
        ).opacity(a1 + (a2 - a1) * ratio)
    }
}

// MARK: - Contrast Metrics

enum FormaContrastMetrics {
    static func contrastRatio(
        foreground: Color,
        background: Color,
        colorScheme: ColorScheme,
        baseBackground: Color? = nil
    ) -> Double {
        let appearance = colorScheme == .dark
            ? NSAppearance(named: .darkAqua)
            : NSAppearance(named: .aqua)

        guard let appearance else { return 1.0 }

        var backgroundRGBA = rgba(for: background, appearance: appearance)
        if let baseBackground {
            let baseRGBA = rgba(for: baseBackground, appearance: appearance)
            backgroundRGBA = composite(foreground: backgroundRGBA, background: baseRGBA)
        }

        let foregroundRGBA = rgba(for: foreground, appearance: appearance)
        let resolvedForeground = composite(foreground: foregroundRGBA, background: backgroundRGBA)

        let foregroundLuminance = relativeLuminance(resolvedForeground)
        let backgroundLuminance = relativeLuminance(backgroundRGBA)

        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func rgba(for color: Color, appearance: NSAppearance) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var resolvedColor = NSColor(color)
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor = NSColor(color)
        }

        let resolved = resolvedColor.usingColorSpace(NSColorSpace.sRGB)
            ?? resolvedColor.usingColorSpace(.deviceRGB)
            ?? resolvedColor

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private static func composite(
        foreground: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
        background: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let outAlpha = foreground.a + background.a * (1 - foreground.a)
        guard outAlpha > 0 else { return (0, 0, 0, 0) }

        let outRed = (foreground.r * foreground.a + background.r * background.a * (1 - foreground.a)) / outAlpha
        let outGreen = (foreground.g * foreground.a + background.g * background.a * (1 - foreground.a)) / outAlpha
        let outBlue = (foreground.b * foreground.a + background.b * background.a * (1 - foreground.a)) / outAlpha

        return (outRed, outGreen, outBlue, outAlpha)
    }

    private static func relativeLuminance(_ rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> Double {
        func transform(_ channel: CGFloat) -> Double {
            let c = Double(channel)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let r = transform(rgba.r)
        let g = transform(rgba.g)
        let b = transform(rgba.b)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

// MARK: - File Category Color Helper
// NOTE: File category logic has been consolidated into FileTypeCategory.swift
// Use FileTypeCategory.category(for: extension) to get the category for a file extension
// This duplicate FileCategory enum has been removed to eliminate redundancy
