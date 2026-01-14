//
//  FormaColors.swift
//  Forma - Brand Color System
//
//  Implementation of Forma brand colors with automatic dark mode support
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI
import AppKit

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
    /// HEX: #8BA688 | RGB: 139, 166, 136
    static let formaSoftGreen = Color(red: 139/255, green: 166/255, blue: 136/255)
    
    // MARK: - System Colors (Semantic)
    // Use these for UI elements that need automatic dark mode support
    
    /// Main window background (automatically adapts to light/dark mode)
    static let formaBackground = Color(NSColor.windowBackgroundColor)
    
    /// Control backgrounds (buttons, cards, etc.)
    static let formaControlBackground = Color(NSColor.controlBackgroundColor)
    
    /// Text field backgrounds
    static let formaTextBackground = Color(NSColor.textBackgroundColor)
    
    /// Card backgrounds (slightly off-white for depth)
    /// HEX: #F9F9F9 | RGB: 249, 249, 249
    static let formaCardBackground = Color(red: 249/255, green: 249/255, blue: 249/255)
    
    /// Primary text (automatically adapts contrast for light/dark mode)
    static let formaLabel = Color(NSColor.labelColor)
    
    /// Secondary text (slightly dimmed)
    static let formaSecondaryLabel = Color(NSColor.secondaryLabelColor)
    
    /// Tertiary text (metadata, timestamps)
    static let formaTertiaryLabel = Color(NSColor.tertiaryLabelColor)
    
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
    static let formaSoftGreen = NSColor(red: 139/255, green: 166/255, blue: 136/255, alpha: 1.0)
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

// MARK: - File Category Color Helper
// NOTE: File category logic has been consolidated into FileTypeCategory.swift
// Use FileTypeCategory.category(for: extension) to get the category for a file extension
// This duplicate FileCategory enum has been removed to eliminate redundancy
