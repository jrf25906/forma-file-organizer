//
//  FormaTypography.swift
//  Forma - Typography System
//
//  Implementation of Forma typography hierarchy using SF Pro
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

/// Forma's typography system using SF Pro
/// All sizes follow the brand guidelines type scale
extension Font {
    
    // MARK: - Type Scale (Desktop/Window Sizes)
    
    /// Hero text for welcome screens and large displays
    /// 32pt Bold - Use for major welcome screens
    static let formaHero = Font.system(size: 32, weight: .bold, design: .default)
    
    /// H1 for main screen titles
    /// 24pt Semibold - Use for primary screen headers
    static let formaH1 = Font.system(size: 24, weight: .semibold, design: .default)
    
    /// H2 for section headers
    /// 20pt Semibold - Use for major section divisions
    static let formaH2 = Font.system(size: 20, weight: .semibold, design: .default)
    
    /// H3 for subsections
    /// 17pt Semibold - Use for subsection headers
    static let formaH3 = Font.system(size: 17, weight: .semibold, design: .default)
    
    /// Large body text
    /// 15pt Regular - Use for emphasized body content
    static let formaBodyLarge = Font.system(size: 15, weight: .regular, design: .default)
    
    /// Standard body text (most common)
    /// 13pt Regular - Use for most UI text, descriptions, list items
    static let formaBody = Font.system(size: 13, weight: .regular, design: .default)

    /// Medium body text
    /// 13pt Medium - Use for slightly emphasized body text
    static let formaBodyMedium = Font.system(size: 13, weight: .medium, design: .default)

    /// Semibold body text
    /// 13pt Semibold - Use for labels, section headers inline
    static let formaBodySemibold = Font.system(size: 13, weight: .semibold, design: .default)

    /// Bold body text
    /// 13pt Bold - Use for strongly emphasized body text
    static let formaBodyBold = Font.system(size: 13, weight: .bold, design: .default)

    /// Compact text (between body and small)
    /// 12pt Regular - Use for compact UI elements
    static let formaCompact = Font.system(size: 12, weight: .regular, design: .default)

    /// Compact text medium weight
    /// 12pt Medium - Use for emphasized compact elements
    static let formaCompactMedium = Font.system(size: 12, weight: .medium, design: .default)

    /// Compact text semibold weight
    /// 12pt Semibold - Use for compact labels, badges
    static let formaCompactSemibold = Font.system(size: 12, weight: .semibold, design: .default)

    /// Small text for metadata
    /// 11pt Regular - Use for secondary information, timestamps, file counts
    static let formaSmall = Font.system(size: 11, weight: .regular, design: .default)

    /// Small text medium weight
    /// 11pt Medium - Use for emphasized metadata
    static let formaSmallMedium = Font.system(size: 11, weight: .medium, design: .default)

    /// Small text semibold weight
    /// 11pt Semibold - Use for small labels, badges
    static let formaSmallSemibold = Font.system(size: 11, weight: .semibold, design: .default)

    /// Caption text (smallest)
    /// 10pt Regular - Use for fine print, tertiary information
    static let formaCaption = Font.system(size: 10, weight: .regular, design: .default)

    /// Caption text semibold
    /// 10pt Semibold - Use for small badges, labels
    static let formaCaptionSemibold = Font.system(size: 10, weight: .semibold, design: .default)

    /// Caption text bold
    /// 10pt Bold - Use for emphasized small badges
    static let formaCaptionBold = Font.system(size: 10, weight: .bold, design: .default)

    /// Micro text (smallest readable)
    /// 9pt Medium - Use for tiny badges, compact indicators, fine print
    static let formaMicro = Font.system(size: 9, weight: .medium, design: .default)

    // MARK: - Display Font (Onboarding)

    /// Display hero text for onboarding welcome
    /// 34pt Libre Baskerville Italic - Use for onboarding hero headlines
    static let formaDisplayHero = Font.custom("LibreBaskerville-Italic", size: 34)

    /// Display heading for onboarding step titles
    /// 24pt Libre Baskerville Italic - Use for onboarding step headings
    static let formaDisplayHeading = Font.custom("LibreBaskerville-Italic", size: 24)

    /// Display subheading for onboarding celebration text
    /// 20pt Libre Baskerville Bold - Use for onboarding celebration/emphasis
    static let formaDisplaySubheading = Font.custom("LibreBaskerville-Bold", size: 20)

    // MARK: - Large Icon Sizes

    /// Standard large icon
    /// 48pt Light - Use for empty state icons, decorative elements
    static let formaIcon = Font.system(size: 48, weight: .light, design: .default)

    /// Medium icon (for cards and tiles)
    /// 32pt Medium - Use for mid-size icons in cards and previews
    static let formaIconMedium = Font.system(size: 32, weight: .medium, design: .default)

    /// Thumbnail icon size
    /// 36pt Medium - Use for file thumbnails and grid tiles
    static let formaThumbnailIcon = Font.system(size: 36, weight: .medium, design: .default)

    /// Hero icon (largest)
    /// 64pt Medium - Use for celebration screens, major empty states
    static let formaIconLarge = Font.system(size: 64, weight: .medium, design: .default)

    // MARK: - Menu Bar Dropdown Sizes
    
    /// Menu bar title
    /// 13pt Semibold
    static let formaMenuTitle = Font.system(size: 13, weight: .semibold, design: .default)
    
    /// Menu bar items
    /// 13pt Regular
    static let formaMenuItem = Font.system(size: 13, weight: .regular, design: .default)
    
    /// Menu bar metadata
    /// 11pt Regular
    static let formaMenuMetadata = Font.system(size: 11, weight: .regular, design: .default)
    
    // MARK: - Button Sizes
    
    /// Primary button text
    /// 13pt Semibold
    static let formaPrimaryButton = Font.system(size: 13, weight: .semibold, design: .default)
    
    /// Secondary button text
    /// 13pt Regular
    static let formaSecondaryButton = Font.system(size: 13, weight: .regular, design: .default)
    
    // MARK: - Monospace (Technical Text)
    
    /// Monospace for file paths and technical content
    /// 13pt Regular SF Mono
    static let formaMono = Font.system(size: 13, weight: .regular, design: .monospaced)
    
    /// Small monospace
    /// 11pt Regular SF Mono
    static let formaMonoSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
}

// MARK: - Text Modifiers

extension View {
    
    /// Apply Forma hero text style
    func formaHeroStyle() -> some View {
        self
            .font(.formaHero)
            .foregroundColor(.formaLabel)
    }
    
    /// Apply Forma H1 style
    func formaH1Style() -> some View {
        self
            .font(.formaH1)
            .foregroundColor(.formaLabel)
    }
    
    /// Apply Forma H2 style
    func formaH2Style() -> some View {
        self
            .font(.formaH2)
            .foregroundColor(.formaLabel)
    }
    
    /// Apply Forma H3 style
    func formaH3Style() -> some View {
        self
            .font(.formaH3)
            .foregroundColor(.formaLabel)
    }
    
    /// Apply standard body text style
    func formaBodyStyle() -> some View {
        self
            .font(.formaBody)
            .foregroundColor(.formaLabel)
    }
    
    /// Apply secondary text style (dimmed)
    func formaSecondaryStyle() -> some View {
        self
            .font(.formaBody)
            .foregroundColor(.formaSecondaryLabel)
    }
    
    /// Apply metadata text style
    func formaMetadataStyle() -> some View {
        self
            .font(.formaSmall)
            .foregroundColor(.formaTertiaryLabel)
    }
    
    /// Apply monospace text style (file paths, technical)
    func formaMonoStyle() -> some View {
        self
            .font(.formaMono)
            .foregroundColor(.formaSecondaryLabel)
    }
}

// MARK: - Line Height and Spacing
