import SwiftUI

/// Layout tokens for consistent gutters, paddings, and fixed layout measurements.
///
/// Keep these as the single source of truth for cross-pane layout so the sidebar,
/// center pane, and right panel can stay visually aligned.
enum FormaLayout {

    enum Gutters {
        /// Horizontal inset used by the center pane header and content container.
        static let center: CGFloat = FormaSpacing.extraLarge

        /// Horizontal inset used within the sidebar when expanded.
        static let sidebar: CGFloat = FormaSpacing.standard

        /// Horizontal inset used within the right panel.
        static let rightPanel: CGFloat = FormaSpacing.generous
    }

    enum Dashboard {
        static let interPaneSpacing: CGFloat = 12
        static let centerPaneHorizontalSafetyInset: CGFloat = FormaSpacing.generous

        static let sidebarCollapsedWidth: CGFloat = 72
        static let sidebarExpandedWidth: CGFloat = 256

        static let rightPanelIdealWidth: CGFloat = 360
        static let rightPanelMinWidth: CGFloat = 320
        static let rightPanelMaxWidth: CGFloat = 360
    }

    enum Sidebar {
        static let collapsedHorizontalPadding: CGFloat = FormaSpacing.tight
        static let expandedHorizontalPadding: CGFloat = Gutters.sidebar
        static let itemHorizontalPadding: CGFloat = Gutters.sidebar
    }

    enum Toolbar {
        /// Spacing between the toolbar pills row and content below.
        static let bottomToContentSpacing: CGFloat = 12

        /// Height for the secondary toolbar row (filters/grouping). Kept fixed to avoid
        /// layout jumps when switching between Pending and All Files.
        static let secondaryRowHeight: CGFloat = 24
    }

    enum Content {
        /// Top padding applied to scroll content below the toolbar.
        static let topPadding: CGFloat = 0

        /// Height of the tapered blur overlay at the top of the center pane.
        static let taperedFocusHeight: CGFloat = 200
    }

    /// Layout constants for the floating card container (Xcode/ChatGPT-style design)
    enum FloatingCard {
        /// Corner radius for window matching. Increased to 24pt to allow for deeper nesting.
        static let outerCornerRadius: CGFloat = 24

        /// Edge spacing between the window and the floating card content.
        /// Increased to 8pt to match the Magnify app's distinct 'Picture in Picture' look.
        static let edgeInset: CGFloat = 8

        /// Top inset should match `edgeInset` so the corner nesting is consistent.
        static var topInset: CGFloat { edgeInset }

        /// Corner radius for the floating card content area.
        /// Formula: innerRadius = outerRadius - inset (24 - 8 = 16).
        /// This ensures a perfect concentric squircle.
        static var cornerRadius: CGFloat { max(0, outerCornerRadius - edgeInset) }
    }

    /// Layout constants for the sidebar search bar
    enum SidebarSearch {
        /// Height of the search bar
        static let height: CGFloat = 36

        /// Corner radius for the search bar
        static let cornerRadius: CGFloat = 8
    }

    /// Layout constants for the floating right panel
    enum RightPanel {
        /// Inset from the window edges (top, right, bottom)
        static let edgeInset: CGFloat = FloatingCard.edgeInset // 8pt

        /// Corner radius for the panel background
        static let cornerRadius: CGFloat = FloatingCard.cornerRadius // 16pt (24 - 8)
    }
}
