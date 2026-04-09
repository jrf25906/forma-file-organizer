//
//  FormaEmptyStates.swift
//  Forma - Empty State Components
//
//  Empty state views for when content areas have no data to display
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

// MARK: - Empty State View

struct FormaEmptyState: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: FormaSpacing.generous) {
            Spacer()

            // Icon or illustration would go here
            Image(systemName: "folder.badge.questionmark")
                .font(.formaIconLarge)
                .foregroundColor(.formaSecondaryLabelHigh)

            VStack(spacing: FormaSpacing.tight) {
                Text(title)
                    .formaH2Style()

                Text(message)
                    .font(.formaBody)
                    .foregroundColor(messageColor)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                FormaPrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 200)
            }

            Spacer()
        }
        .frame(maxWidth: 400)
        .padding(FormaSpacing.extraLarge)
    }

    private var messageColor: Color {
        colorScheme == .dark
            ? .formaSecondaryLabelHigh
            : Color.formaLabel.opacity(0.7)
    }
}

// MARK: - Actionable Empty State View

/// An empty state variant that presents a curated list of next actions
/// rather than a single primary button.
struct FormaActionableEmptyState<ActionContent: View>: View {
    let title: String
    let message: String
    let iconName: String
    let iconColor: Color
    @ViewBuilder let actions: () -> ActionContent

    @Environment(\.colorScheme) private var colorScheme
    @State private var showCelebration = false
    @State private var checkmarkScale: CGFloat = 0.5
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: FormaSpacing.generous) {
            Spacer()

            // Success checkmark with spring animation
            ZStack {
                Circle()
                    .fill(iconColor.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle))
                    .frame(width: 100, height: 100)

                Image(systemName: iconName)
                    .font(.formaIconLarge)
                    .foregroundColor(iconColor)
                    .scaleEffect(checkmarkScale)
            }
            .scaleEffect(showCelebration ? 1.0 : 0.5)
            .opacity(showCelebration ? 1.0 : 0.0)

            VStack(spacing: FormaSpacing.tight) {
                Text(title)
                    .formaH2Style()

                Text(message)
                    .font(.formaBody)
                    .foregroundColor(messageColor)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Next actions section
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("What's next?")
                    .font(.formaBodyBold)
                    .foregroundColor(.formaLabel)

                VStack(spacing: FormaSpacing.tight) {
                    actions()
                }
            }
            .padding(FormaSpacing.generous)
            .background(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
            .formaCornerRadius(FormaRadius.card)

            Spacer()
        }
        .padding(.horizontal, FormaSpacing.extraLarge + (FormaSpacing.standard - FormaSpacing.micro))
        .padding(.vertical, FormaSpacing.large + FormaSpacing.tight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                    showCelebration = true
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                    checkmarkScale = 1.0
                }
            } else {
                showCelebration = true
                checkmarkScale = 1.0
            }
        }
    }

    private var messageColor: Color {
        colorScheme == .dark
            ? .formaSecondaryLabelHigh
            : Color.formaLabel.opacity(0.7)
    }
}

// MARK: - Hero Icon Container

/// A large decorative icon container for empty states and celebration screens.
/// Provides consistent styling for prominent icons throughout the app.
///
/// Usage:
/// ```swift
/// FormaHeroIcon(systemName: "checkmark.circle.fill", color: .formaSage)
/// FormaHeroIcon(systemName: "folder.badge.plus", style: .subtle)
/// ```
struct FormaHeroIcon: View {
    let systemName: String
    var color: Color = .formaSteelBlue
    var size: HeroSize = .regular
    var style: HeroStyle = .prominent

    enum HeroSize {
        case regular  // 48pt icon
        case large    // 64pt icon

        var font: Font {
            switch self {
            case .regular: return .formaIcon
            case .large: return .formaIconLarge
            }
        }

        var containerSize: CGFloat {
            switch self {
            case .regular: return 80
            case .large: return 100
            }
        }
    }

    enum HeroStyle {
        case prominent  // Colored icon with tinted background
        case subtle     // Muted icon for secondary empty states
    }

    var body: some View {
        ZStack {
            if style == .prominent {
                Circle()
                    .fill(color.opacity(Color.FormaOpacity.light))
                    .frame(width: size.containerSize, height: size.containerSize)
            }

            Image(systemName: systemName)
                .font(size.font)
                .foregroundColor(style == .prominent ? color : .formaSecondaryLabel)
        }
    }
}

// MARK: - Preview Helpers

#Preview("Empty State") {
    FormaEmptyState(
        title: "No Files to Organize",
        message: "Your Desktop is clean! When files need organizing, they'll appear here.",
        actionTitle: "Scan Now",
        action: {}
    )
}

#Preview("FormaHeroIcon") {
    VStack(spacing: 24) {
        FormaHeroIcon(systemName: "checkmark.circle.fill", color: .formaSage)
        FormaHeroIcon(systemName: "folder.badge.plus", size: .large)
        FormaHeroIcon(systemName: "questionmark.folder", style: .subtle)
    }
    .padding()
    .background(Color.formaBackground)
}
