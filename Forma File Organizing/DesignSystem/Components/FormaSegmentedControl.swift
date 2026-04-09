//
//  FormaSegmentedControl.swift
//  Forma - Segmented Control Components
//
//  Premium segmented control with sliding highlight animation
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

// MARK: - Segmented Control

/// A premium, segmented control with a sliding highlight, often used for tab bars or mode switches.
struct FormaSegmentedControl<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    let options: [SelectionValue]
    @ViewBuilder let content: (SelectionValue) -> Content

    @Namespace private var namespace
    @Environment(\.colorScheme) private var colorScheme

    private let containerCornerRadius: CGFloat = FormaControlChromeMetrics.containerCornerRadius
    private let selectedCornerRadius: CGFloat = FormaControlChromeMetrics.selectedCornerRadius
    private let segmentHeight: CGFloat = FormaControlChromeMetrics.segmentHeight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                FormaSegmentButton(
                    isSelected: selection == option,
                    namespace: namespace,
                    tint: .formaSteelBlue,
                    selectedCornerRadius: selectedCornerRadius,
                    segmentHeight: segmentHeight,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = option
                        }
                    },
                    content: { content(option) }
                )

                if index < options.count - 1 {
                    Rectangle()
                        .fill(FormaControlChromePalette.separator(colorScheme))
                        .frame(width: 1, height: FormaControlChromeMetrics.dividerHeight)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(2)
        .background {
            FormaSegmentedBackground(
                cornerRadius: containerCornerRadius,
                tint: containerTint
            )
            .overlay(
                RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                    .stroke(FormaControlChromePalette.containerBorder(colorScheme), lineWidth: 0.5)
            )
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: selection)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var containerTint: Color {
        colorScheme == .dark
            ? Color.formaMutedBlue.opacity(0.16)
            : Color.formaSteelBlue.opacity(0.10)
    }
}

struct FormaSegmentButton<Content: View>: View {
    let isSelected: Bool
    let namespace: Namespace.ID
    let tint: Color
    let selectedCornerRadius: CGFloat
    let segmentHeight: CGFloat
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(FormaControlChromePalette.activeFill(colorScheme, tint: tint))
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(FormaControlChromePalette.activeBorder(colorScheme), lineWidth: 0.5)
                        )
                        .shadow(color: FormaControlChromePalette.activeShadow(colorScheme), radius: 1.5, x: 0, y: 0.5)
                        .matchedGeometryEffect(id: "segmentIndicator", in: namespace)
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(FormaControlChromePalette.hoverFill(colorScheme, tint: tint))
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                }

                content()
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
            isHovered = hovering
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isSelected)
        .animation(.easeOut(duration: 0.16), value: isHovered)
    }
}

/// Standalone icon button that perfectly matches the segmented control styling.
struct FormaSegmentedIconButton: View {
    let icon: String
    let isSelected: Bool
    let help: String?
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private let containerCornerRadius: CGFloat = FormaControlChromeMetrics.containerCornerRadius
    private let selectedCornerRadius: CGFloat = FormaControlChromeMetrics.selectedCornerRadius
    private let segmentWidth: CGFloat = FormaControlChromeMetrics.iconSegmentWidth
    private let segmentHeight: CGFloat = FormaControlChromeMetrics.segmentHeight

    init(icon: String, isSelected: Bool = false, help: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.isSelected = isSelected
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(FormaControlChromePalette.activeFill(colorScheme, tint: .formaSteelBlue))
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(FormaControlChromePalette.activeBorder(colorScheme), lineWidth: 0.5)
                        )
                        .shadow(color: FormaControlChromePalette.activeShadow(colorScheme), radius: 1.5, x: 0, y: 0.5)
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(FormaControlChromePalette.hoverFill(colorScheme, tint: .formaSteelBlue))
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                }

                Image(systemName: icon)
                    .font(.system(size: FormaControlChromeMetrics.segmentIconFontSize, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? FormaControlChromePalette.selectedForeground(colorScheme)
                            : (
                                isHovered
                                    ? FormaControlChromePalette.highlightedForeground(colorScheme)
                                    : FormaControlChromePalette.normalForeground(colorScheme)
                            )
                    )
                    .frame(width: segmentWidth, height: segmentHeight)
            }
            .frame(width: segmentWidth, height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(FormaControlPressButtonStyle())
        .padding(2)
        .background {
            FormaSegmentedBackground(
                cornerRadius: containerCornerRadius,
                tint: containerTint
            )
            .overlay(
                RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                    .stroke(FormaControlChromePalette.containerBorder(colorScheme), lineWidth: 0.5)
            )
        }
        .help(help ?? "")
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isSelected)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var containerTint: Color {
        colorScheme == .dark
            ? Color.formaMutedBlue.opacity(0.16)
            : Color.formaSteelBlue.opacity(0.10)
    }
}

/// Shared capsule background used for FormaSegmentedControl and standalone FormaSegmentedIconButton
struct FormaSegmentedBackground: View {
    let cornerRadius: CGFloat
    var tint: Color? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            FormaMaterialSurface(tier: .raised, cornerRadius: cornerRadius, tint: tint)

            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.10 : 0.16),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(shape)
        }
    }
}
