import SwiftUI

struct FilterTabBar: View {
    @Binding var selectedCategory: FileTypeCategory
    let categoryFileCounts: [FileTypeCategory: Int]
    @Namespace private var filterAnimation
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredCategory: FileTypeCategory?

    private let containerCornerRadius: CGFloat = FormaControlChromeMetrics.containerCornerRadius
    private let selectedCornerRadius: CGFloat = FormaControlChromeMetrics.selectedCornerRadius
    private let segmentHeight: CGFloat = FormaControlChromeMetrics.segmentHeight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(FileTypeCategory.allCases.enumerated()), id: \.element) { index, category in
                segmentButton(category: category)

                if index < FileTypeCategory.allCases.count - 1 {
                    Rectangle()
                        .fill(separatorColor)
                        .frame(width: 1, height: FormaControlChromeMetrics.dividerHeight)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(2)
        .background {
            ZStack {
                FormaMaterialSurface(
                    tier: .raised,
                    cornerRadius: containerCornerRadius,
                    tint: containerTint
                )

                RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                    .stroke(containerBorder, lineWidth: 0.5)

                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.10 : 0.16),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous))
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: selectedCategory)
        .animation(.easeOut(duration: 0.16), value: hoveredCategory)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func segmentButton(category: FileTypeCategory) -> some View {
        let isSelected = selectedCategory == category
        let isHovered = hoveredCategory == category
        let fileCount = categoryFileCounts[category] ?? 0

        return Button(action: { selectedCategory = category }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.5)
                        )
                        .shadow(color: selectedDropShadowColor, radius: 1.5, x: 0, y: 0.5)
                        .matchedGeometryEffect(id: "activeFilterSegment", in: filterAnimation)
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                }

                HStack(spacing: 5) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 10.5, weight: isSelected ? .medium : .regular))

                    Text(category.displayName)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)

                    if fileCount > 0 {
                        Text(fileCount > 99 ? "99+" : "\(fileCount)")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(badgeTextColor(isSelected: isSelected))
                            .frame(minWidth: 14, minHeight: 14)
                            .padding(.horizontal, 1.5)
                            .background {
                                Capsule().fill(badgeFill(isSelected: isSelected))
                            }
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: segmentHeight)
                .foregroundColor(
                    isSelected
                        ? FormaControlChromePalette.selectedForeground(colorScheme)
                        : (
                            isHovered
                                ? FormaControlChromePalette.highlightedForeground(colorScheme)
                                : FormaControlChromePalette.normalForeground(colorScheme)
                        )
                )
            }
            .frame(height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(FormaControlPressButtonStyle())
        .onHover { hovering in
            if hovering {
                hoveredCategory = category
            } else if hoveredCategory == category {
                hoveredCategory = nil
            }
        }
    }

    // MARK: - Badge Colors

    private func badgeTextColor(isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? .formaBoneWhite : .formaSteelBlue
        }
        return .formaBoneWhite
    }

    private func badgeFill(isSelected: Bool) -> Color {
        isSelected
            ? (colorScheme == .dark
                ? Color.formaBoneWhite.opacity(0.18)
                : Color.formaSteelBlue.opacity(0.16))
            : Color.formaSecondaryLabel
    }

    // MARK: - Colors

    private var separatorColor: Color {
        FormaControlChromePalette.separator(colorScheme)
    }

    private var containerTint: Color {
        colorScheme == .dark
            ? Color.formaMutedBlue.opacity(0.18)
            : Color.formaSteelBlue.opacity(0.10)
    }

    private var containerBorder: Color {
        FormaControlChromePalette.containerBorder(colorScheme)
    }

    private var activeBorder: Color {
        FormaControlChromePalette.activeBorder(colorScheme)
    }

    private var activeFill: Color {
        FormaControlChromePalette.activeFill(colorScheme, tint: selectedTint)
    }

    private var selectedTint: Color {
        Color.formaSteelBlue
    }

    private var selectedDropShadowColor: Color {
        FormaControlChromePalette.activeShadow(colorScheme)
    }

    private var hoverFill: Color {
        FormaControlChromePalette.hoverFill(colorScheme, tint: selectedTint)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: FormaSpacing.generous - FormaSpacing.micro) {
        FilterTabBar(
            selectedCategory: .constant(.all),
            categoryFileCounts: [
                .all: 42,
                .documents: 15,
                .images: 8,
                .videos: 3,
                .audio: 5,
                .archives: 11
            ]
        )

        FilterTabBar(
            selectedCategory: .constant(.images),
            categoryFileCounts: [
                .all: 42,
                .documents: 15,
                .images: 8,
                .videos: 3,
                .audio: 5,
                .archives: 11
            ]
        )
    }
    .frame(width: 800)
    .padding()
}
