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
    @Environment(\.colorScheme) private var colorScheme

    init(isSelected: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        content
            .formaCardPadding()
            .background(Color.formaSurfaceWork)
            .formaCornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.formaSteelBlue.opacity(0.72)
                            : Color.formaSeparator.opacity(colorScheme == .dark ? 0.64 : 0.48),
                        lineWidth: isSelected ? 1.5 : 1
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
    @Environment(\.colorScheme) private var colorScheme

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
                        colorScheme == .dark
                            ? Color.formaBoneWhite.opacity(0.075)
                            : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 3)
                    } else {
                        Color.formaSurfaceWork
                    }
                }
            )
            .formaCornerRadius(FormaRadius.card) // Large card radius for consistency
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong)
                            : Color.formaSeparator.opacity(colorScheme == .dark ? 0.55 : 0.36),
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
