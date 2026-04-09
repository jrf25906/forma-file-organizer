//
//  FormaCards.swift
//  Forma - Reusable UI Components
//
//  Implementation of Forma brand UI components
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

// MARK: - Card Container

struct FormaCard<Content: View>: View {
    let content: Content
    var isSelected: Bool = false

    init(isSelected: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        content
            .formaCardPadding()
            .background(Color.formaControlBackground)
            .formaCornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(
                        isSelected ? Color.formaSteelBlue : Color.formaSeparator,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .formaShadow(isSelected ? .raised : .resting)
    }
}

// MARK: - List Card Modifier

/// A lighter-weight card style for list views that maintains visual consistency
/// with the main card view but is more compact and suitable for dense lists
struct FormaListCard: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if isSelected {
                        // Slightly more subtle gradient for list view
                        LinearGradient(
                            colors: [
                                Color.formaSteelBlue.opacity(Color.FormaOpacity.light),
                                Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle + (Color.FormaOpacity.ultraSubtle / 2))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if isHovered {
                        Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
                    } else {
                        Color.formaBoneWhite
                    }
                }
            )
            .formaCornerRadius(FormaRadius.card) // Large card radius for consistency
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong)
                            : Color.formaObsidian.opacity(Color.FormaOpacity.subtle + (Color.FormaOpacity.ultraSubtle / 2)),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .formaShadow(isSelected ? .raised : .resting)
    }
}

extension View {
    func formaListCard(isSelected: Bool, isHovered: Bool) -> some View {
        modifier(FormaListCard(isSelected: isSelected, isHovered: isHovered))
    }
}

#Preview("Card") {
    VStack(spacing: 20) {
        FormaCard {
            Text("Unselected Card Content")
                .formaBodyStyle()
        }

        FormaCard(isSelected: true) {
            Text("Selected Card Content")
                .formaBodyStyle()
        }
    }
    .padding()
    .frame(width: 300)
}
