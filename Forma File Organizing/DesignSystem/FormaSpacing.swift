//
//  FormaSpacing.swift
//  Forma - 8pt Grid Spacing System
//
//  Implementation of Forma's 8pt grid system for consistent spacing
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

/// Forma's 8pt grid spacing system
/// All spacing values are multiples of 8 for visual rhythm and consistency
enum FormaSpacing {
    
    // MARK: - Base Grid Values
    
    /// Micro spacing (4px) - Use for icon to text, very tight relationships
    static let micro: CGFloat = 4
    
    /// Tight spacing (8px) - Use for related elements, compact layouts
    static let tight: CGFloat = 8
    
    /// Standard spacing (16px) - Most common, default spacing
    static let standard: CGFloat = 16
    
    /// Generous spacing (24px) - Use between sections, comfortable layouts
    static let generous: CGFloat = 24
    
    /// Large spacing (32px) - Use for major section breaks
    static let large: CGFloat = 32
    
    /// Extra large spacing (48px) - Use for screen margins, major divisions
    static let extraLarge: CGFloat = 48
    
    /// Huge spacing (64px) - Use for empty states, hero sections
    static let huge: CGFloat = 64
    
    // MARK: - Component-Specific Padding
    
    /// Button padding
    struct Button {
        /// Vertical padding inside buttons (8px)
        static let vertical: CGFloat = 8
        
        /// Horizontal padding inside buttons (16px)
        static let horizontal: CGFloat = 16
    }
    
    /// Card padding
    struct Card {
        /// Padding inside cards (16px all sides)
        static let all: CGFloat = 16
    }
    
    /// Form spacing
    struct Form {
        /// Space between form fields (16px)
        static let fieldSpacing: CGFloat = 16
        
        /// Space between form sections (32px)
        static let sectionSpacing: CGFloat = 32
    }
    
    /// Screen margins
    struct Screen {
        /// Minimum edge margins (24px)
        static let minMargin: CGFloat = 24
        
        /// Standard content width limit for forms/text (480-600px)
        static let contentWidth: ClosedRange<CGFloat> = 480...600
        
        /// Multi-column content width (800-1000px)
        static let multiColumnWidth: ClosedRange<CGFloat> = 800...1000
    }
    
    /// Window sizes
    struct Window {
        /// Minimum window width
        static let minWidth: CGFloat = 600

        /// Minimum window height
        static let minHeight: CGFloat = 400

        /// Preferred initial size (matches ideal window proportions from design)
        static let preferredWidth: CGFloat = 1400
        static let preferredHeight: CGFloat = 970
    }

    /// Toolbar spacing constants
    struct Toolbar {
        /// Minimal breathing room between window top and toolbar content
        static let topOffset: CGFloat = 20
    }

    /// Responsive breakpoints
    struct Breakpoints {
        /// Toolbar compression threshold - below this width, toolbar enters compact mode
        static let compactWidth: CGFloat = 600
    }
}

// MARK: - Spacing View Modifiers

extension View {
    
    /// Apply standard Forma padding (16px all sides)
    func formaPadding() -> some View {
        self.padding(FormaSpacing.standard)
    }
    
    /// Apply tight Forma padding (8px all sides)
    func formaPaddingTight() -> some View {
        self.padding(FormaSpacing.tight)
    }
    
    /// Apply generous Forma padding (24px all sides)
    func formaPaddingGenerous() -> some View {
        self.padding(FormaSpacing.generous)
    }
    
    /// Apply button-specific padding (8px vertical, 16px horizontal)
    func formaButtonPadding() -> some View {
        self.padding(.vertical, FormaSpacing.Button.vertical)
            .padding(.horizontal, FormaSpacing.Button.horizontal)
    }
    
    /// Apply card padding (16px all sides)
    func formaCardPadding() -> some View {
        self.padding(FormaSpacing.Card.all)
    }
    
    /// Apply standard vertical spacing between elements (16px)
    func formaVerticalSpacing() -> some View {
        self.padding(.vertical, FormaSpacing.standard / 2)
    }
}

// MARK: - Corner Radius Tokens

/// Forma's corner radius system for consistent rounded corners
/// Uses Apple's continuous corner style for premium feel
enum FormaRadius {

    /// No radius (0px) - Sharp corners
    static let none: CGFloat = 0

    /// Micro radius (4px) - Small badges, tags, inline elements
    static let micro: CGFloat = 4

    /// Small radius (6px) - Badges, small controls
    static let small: CGFloat = 6

    /// Control radius (8px) - Text fields, small buttons, chips
    static let control: CGFloat = 8

    /// Card radius (12px) - Cards, panels, sheets, modals
    static let card: CGFloat = 12

    /// Large radius (16px) - Large cards, prominent containers
    static let large: CGFloat = 16

    /// Pill radius (999px) - Fully rounded pills, floating bars
    static let pill: CGFloat = 999
}

// MARK: - Radius View Modifiers

extension View {

    /// Apply card corner radius with continuous style (12px)
    func formaCardRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
    }

    /// Apply control corner radius with continuous style (8px)
    func formaControlRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
    }

    /// Apply pill corner radius with continuous style (fully rounded)
    func formaPillRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: FormaRadius.pill, style: .continuous))
    }

    /// Apply custom Forma radius with continuous style
    func formaRadius(_ radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Layout Helpers
