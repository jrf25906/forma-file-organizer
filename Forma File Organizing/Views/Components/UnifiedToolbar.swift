//
//  UnifiedToolbar.swift
//  Forma File Organizing
//
//  Created by Antigravity on 11/24/25.
//

import SwiftUI

// Compression levels for responsive toolbar
enum CompressionLevel {
    case none       // >650px: Full spacing
    case medium     // 500-650px: 25% reduction
    case compact    // <500px: 50% reduction
    
    var horizontalPadding: CGFloat {
        switch self {
        case .none: return 12
        case .medium: return 9
        case .compact: return 6
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .none: return 8
        case .medium: return 6
        case .compact: return 4
        }
    }
}

struct UnifiedToolbar: View {
    let availableWidth: CGFloat
    @EnvironmentObject var viewModel: DashboardViewModel
    @Namespace private var animation

    // Local state for dropdown visibility
    @State private var showGrouping: Bool = false
    
    // Calculate compression level based on available width
    private var compressionLevel: CompressionLevel {
        if availableWidth > 650 { return .none }
        else if availableWidth > 500 { return .medium }
        else { return .compact }
    }
    
    // Compression logic for grouping row buttons
    private var shouldCompressGrouping: Bool {
        // Compress when space is tight and grouping row is visible
        return viewModel.reviewFilterMode == .all && availableWidth < 650
    }

    private var primaryRowHeight: CGFloat { 44 }

    var body: some View {
        // Use a fixed-height container that NEVER changes size between modes
        // This ensures content below starts at the exact same Y position
        VStack(spacing: 0) {
            // Main toolbar row - fixed height
            ZStack {
                centeredPills

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    trailingControls
                }
            }
            .frame(height: primaryRowHeight)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)

            // Secondary row - only shows grouping options when expanded
            if showGrouping {
                HStack {
                    Spacer()
                    groupingOptionsRow
                }
                .frame(height: FormaLayout.Toolbar.secondaryRowHeight)
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var centeredPills: some View {
        HStack(spacing: FormaSpacing.tight) {
            leftPill

            Rectangle()
                .fill(Color.formaSeparator.opacity(Color.FormaOpacity.strong))
                .frame(width: 1, height: 32)

            rightPill
        }
        .padding(FormaSpacing.tight)
        .frame(height: primaryRowHeight)
    }

    private var trailingControls: some View {
        HStack(spacing: 12) {
            if viewModel.isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)

                    if compressionLevel != .compact {
                        Text("Scanning...")
                            .font(.formaSmallMedium)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }
                .padding(.horizontal, FormaSpacing.tight)
                .padding(.vertical, FormaSpacing.micro)
                .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                .formaCornerRadius(FormaRadius.small)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(height: primaryRowHeight)
    }
    
    private var leftPill: some View {
        HStack(spacing: compressionLevel.spacing) {
            StocksStyleReviewModeControl(
                selectedMode: viewModel.reviewFilterMode,
                pendingCount: viewModel.needsReviewCount,
                namespace: animation
            ) { mode in
                viewModel.reviewFilterMode = mode
            }
        }
    }

    private var rightPill: some View {
        HStack(spacing: compressionLevel.spacing) {
            StocksStyleViewModeControl(
                selectedMode: viewModel.currentViewMode,
                namespace: animation
            ) { mode in
                viewModel.currentViewMode = mode
            }

            // Grouping section - only show in All Files mode
            if viewModel.reviewFilterMode == .all {
                // Grouping Toggle - icon-only, opens options row below
                StocksStyleToolbarIconButton(
                    icon: "square.stack.3d.up",
                    isSelected: showGrouping,
                    help: "Group files",
                    activeTint: Color.formaSteelBlue
                ) {
                    showGrouping.toggle()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.reviewFilterMode)
    }

    // MARK: - Grouping Options Row (Right-aligned second row)
    private var groupingOptionsRow: some View {
        StocksStyleGroupingControl(
            selectedMode: viewModel.groupingMode,
            namespace: animation,
            compact: shouldCompressGrouping
        ) { mode in
            viewModel.groupingMode = mode
        }
    }
}

// MARK: - Subcomponents

private struct StocksStyleReviewModeControl: View {
    let selectedMode: ReviewFilterMode
    let pendingCount: Int
    let namespace: Namespace.ID
    let onSelect: (ReviewFilterMode) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredMode: ReviewFilterMode?

    private struct Segment: Identifiable {
        let mode: ReviewFilterMode
        let icon: String
        let label: String
        let help: String
        let accessibilityID: String

        var id: ReviewFilterMode { mode }
    }

    private let segments: [Segment] = [
        Segment(
            mode: .needsReview,
            icon: "tray",
            label: "Pending",
            help: "Show pending files",
            accessibilityID: "reviewMode_needsReview"
        ),
        Segment(
            mode: .all,
            icon: "folder",
            label: "All Files",
            help: "Show all files",
            accessibilityID: "reviewMode_allFiles"
        ),
    ]

    private let containerCornerRadius: CGFloat = 17
    private let selectedCornerRadius: CGFloat = 13
    private let segmentHeight: CGFloat = 30
    private let segmentPlateHorizontalInset: CGFloat = 4
    private let segmentPlateVerticalInset: CGFloat = 1.5

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentButton(segment)

                if index < segments.count - 1 {
                    Rectangle()
                        .fill(separatorColor)
                        .frame(width: 1, height: 22)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(3)
        .background {
            ToolbarGlassyCapsuleBackground(tint: nil, cornerRadius: containerCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(topRimColor, lineWidth: 0.6)
                )
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: selectedMode)
        .animation(.easeOut(duration: 0.16), value: hoveredMode)
        .accessibilityElement(children: .contain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func segmentButton(_ segment: Segment) -> some View {
        let isSelected = selectedMode == segment.mode
        let isHovered = hoveredMode == segment.mode

        return Button(action: { onSelect(segment.mode) }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.9)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(selectedHighlight)
                                .frame(height: 8)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .shadow(color: selectedGlowColor, radius: 7, x: 0, y: 0)
                        .shadow(color: selectedDropShadowColor, radius: 2.5, x: 0, y: 1)
                        .matchedGeometryEffect(id: "activeReviewSegment", in: namespace)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(hoverBorder, lineWidth: 0.7)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(hoverHighlight)
                                .frame(height: 6)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                HStack(spacing: 6) {
                    Image(systemName: segment.icon)
                        .font(.system(size: 11.5, weight: isSelected ? .medium : .regular))

                    Text(segment.label)
                        .font(.system(size: 13.5, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .frame(height: segmentHeight)
                .foregroundColor(
                    isSelected
                        ? .formaLabel
                        : (isHovered ? .formaLabel : .formaSecondaryLabelHigh)
                )
            }
            .frame(height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if segment.mode == .needsReview && pendingCount > 0 {
                Text(pendingBadgeText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.formaBoneWhite)
                    .frame(minWidth: 14, minHeight: 14)
                    .padding(.horizontal, 3.5)
                    .background {
                        Capsule().fill(badgeFill)
                    }
                    .overlay(
                        Capsule()
                            .stroke(Color.formaBoneWhite.opacity(0.24), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 1.2, x: 0, y: 1)
                    .offset(x: 6, y: -7)
            }
        }
        .help(segment.help)
        .accessibilityIdentifier(segment.accessibilityID)
        .accessibilityLabel(segment.label)
        .accessibilityValue(segment.mode == .needsReview && pendingCount > 0 ? "\(pendingCount)" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { hovering in
            if hovering {
                hoveredMode = segment.mode
            } else if hoveredMode == segment.mode {
                hoveredMode = nil
            }
        }
    }

    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.20)
    }

    private var topRimColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaBoneWhite.opacity(0.45)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.13)
    }

    private var activeFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(0.18),
                        Color.formaBoneWhite.opacity(0.06),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(0.90),
                    Color.formaBoneWhite.opacity(0.70),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var selectedHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectedGlowColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.06)
            : Color.formaSteelBlue.opacity(0.05)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.24)
            : Color.formaObsidian.opacity(0.08)
    }

    private var hoverFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.formaBoneWhite.opacity(0.12))
        }
        return AnyShapeStyle(Color.formaObsidian.opacity(0.08))
    }

    private var hoverBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var pendingBadgeText: String {
        pendingCount > 99 ? "99+" : "\(pendingCount)"
    }

    private var badgeFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.formaWarmOrange.blend(with: .red, ratio: 0.22),
                Color.formaWarmOrange.opacity(0.95),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct StocksStyleViewModeControl: View {
    let selectedMode: ViewMode
    let namespace: Namespace.ID
    let onSelect: (ViewMode) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredMode: ViewMode?

    private struct Segment: Identifiable {
        let mode: ViewMode
        let icon: String
        let help: String

        var id: ViewMode { mode }
    }

    private let segments: [Segment] = [
        Segment(mode: .grid, icon: "square.grid.2x2", help: "Grid view (⌘1)"),
        Segment(mode: .list, icon: "list.bullet", help: "List view (⌘2)"),
        Segment(mode: .card, icon: "rectangle.grid.1x2", help: "Tile view (⌘3)"),
    ]

    private let containerCornerRadius: CGFloat = 17
    private let selectedCornerRadius: CGFloat = 13
    private let segmentWidth: CGFloat = 40
    private let segmentHeight: CGFloat = 30
    private let segmentPlateHorizontalInset: CGFloat = 4
    private let segmentPlateVerticalInset: CGFloat = 1.5

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentButton(segment)

                if index < segments.count - 1 {
                    Rectangle()
                        .fill(separatorColor)
                        .frame(width: 1, height: 22)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(3)
        .background {
            ToolbarGlassyCapsuleBackground(tint: nil, cornerRadius: containerCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(topRimColor, lineWidth: 0.6)
                )
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: selectedMode)
        .animation(.easeOut(duration: 0.16), value: hoveredMode)
        .accessibilityElement(children: .contain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func segmentButton(_ segment: Segment) -> some View {
        let isSelected = selectedMode == segment.mode
        let isHovered = hoveredMode == segment.mode

        return Button(action: { onSelect(segment.mode) }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.9)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(selectedHighlight)
                                .frame(height: 8)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .shadow(color: selectedGlowColor, radius: 7, x: 0, y: 0)
                        .shadow(color: selectedDropShadowColor, radius: 2.5, x: 0, y: 1)
                        .matchedGeometryEffect(id: "activeViewSegment", in: namespace)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(hoverBorder, lineWidth: 0.7)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(hoverHighlight)
                                .frame(height: 6)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                Image(systemName: segment.icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(
                        isSelected
                            ? .formaLabel
                            : (isHovered ? .formaLabel : .formaSecondaryLabelHigh)
                    )
                    .frame(width: segmentWidth, height: segmentHeight)
            }
            .frame(width: segmentWidth, height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(segment.help)
        .accessibilityLabel(segment.mode.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { hovering in
            if hovering {
                hoveredMode = segment.mode
            } else if hoveredMode == segment.mode {
                hoveredMode = nil
            }
        }
    }

    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.20)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.13)
    }

    private var activeFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(0.18),
                        Color.formaBoneWhite.opacity(0.06),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(0.90),
                    Color.formaBoneWhite.opacity(0.70),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var topRimColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaBoneWhite.opacity(0.45)
    }

    private var selectedHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectedGlowColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.06)
            : Color.formaSteelBlue.opacity(0.05)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.24)
            : Color.formaObsidian.opacity(0.08)
    }

    private var hoverFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.formaBoneWhite.opacity(0.12))
        }
        return AnyShapeStyle(Color.formaObsidian.opacity(0.08))
    }

    private var hoverBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct StocksStyleGroupingControl: View {
    let selectedMode: FileGroupingService.GroupingMode
    let namespace: Namespace.ID
    let compact: Bool
    let onSelect: (FileGroupingService.GroupingMode) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredMode: FileGroupingService.GroupingMode?

    private struct Segment: Identifiable {
        let mode: FileGroupingService.GroupingMode
        let icon: String
        let label: String
        let help: String

        var id: FileGroupingService.GroupingMode { mode }
    }

    private let segments: [Segment] = [
        Segment(mode: .none, icon: "square.grid.2x2", label: "None", help: "Disable grouping"),
        Segment(mode: .date, icon: "clock", label: "Date", help: "Group by date"),
        Segment(mode: .patterns, icon: "flag", label: "Patterns", help: "Group by patterns"),
        Segment(mode: .combined, icon: "sparkles", label: "Smart", help: "Use smart grouping"),
    ]

    private let containerCornerRadius: CGFloat = 17
    private let selectedCornerRadius: CGFloat = 13
    private let segmentHeight: CGFloat = 30
    private let compactMinWidth: CGFloat = 36
    private let segmentPlateHorizontalInset: CGFloat = 4
    private let segmentPlateVerticalInset: CGFloat = 1.5

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentButton(segment)

                if index < segments.count - 1 {
                    Rectangle()
                        .fill(separatorColor)
                        .frame(width: 1, height: 22)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(3)
        .background {
            ToolbarGlassyCapsuleBackground(tint: nil, cornerRadius: containerCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(topRimColor, lineWidth: 0.6)
                )
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: selectedMode)
        .animation(.easeOut(duration: 0.16), value: hoveredMode)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func segmentButton(_ segment: Segment) -> some View {
        let isSelected = selectedMode == segment.mode
        let isHovered = hoveredMode == segment.mode

        return Button(action: { onSelect(segment.mode) }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.9)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(selectedHighlight)
                                .frame(height: 8)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .shadow(color: selectedGlowColor, radius: 7, x: 0, y: 0)
                        .shadow(color: selectedDropShadowColor, radius: 2.5, x: 0, y: 1)
                        .matchedGeometryEffect(id: "activeGroupingSegment", in: namespace)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(hoverBorder, lineWidth: 0.7)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(hoverHighlight)
                                .frame(height: 6)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                HStack(spacing: compact ? 0 : 5) {
                    Image(systemName: segment.icon)
                        .font(.system(size: 11.5, weight: isSelected ? .medium : .regular))

                    if !compact {
                        Text(segment.label)
                            .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, compact ? 10 : 11)
                .frame(minWidth: compact ? compactMinWidth : nil)
                .frame(height: segmentHeight)
                .foregroundColor(
                    isSelected
                        ? .formaLabel
                        : (isHovered ? .formaLabel : .formaSecondaryLabelHigh)
                )
            }
            .frame(height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(segment.help)
        .onHover { hovering in
            if hovering {
                hoveredMode = segment.mode
            } else if hoveredMode == segment.mode {
                hoveredMode = nil
            }
        }
    }

    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.20)
    }

    private var topRimColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaBoneWhite.opacity(0.45)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.13)
    }

    private var activeFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(0.18),
                        Color.formaBoneWhite.opacity(0.06),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(0.90),
                    Color.formaBoneWhite.opacity(0.70),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var selectedHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectedGlowColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.06)
            : Color.formaSteelBlue.opacity(0.05)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.24)
            : Color.formaObsidian.opacity(0.08)
    }

    private var hoverFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.formaBoneWhite.opacity(0.12))
        }
        return AnyShapeStyle(Color.formaObsidian.opacity(0.08))
    }

    private var hoverBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct StocksStyleToolbarIconButton: View {
    let icon: String
    let isSelected: Bool
    let help: String
    var showOuterShell: Bool = true
    var activeTint: Color? = nil
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private let containerCornerRadius: CGFloat = 17
    private let selectedCornerRadius: CGFloat = 13
    private let segmentWidth: CGFloat = 40
    private let segmentHeight: CGFloat = 30
    private let segmentPlateHorizontalInset: CGFloat = 4
    private let segmentPlateVerticalInset: CGFloat = 1.5

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.9)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(selectedHighlight)
                                .frame(height: 8)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .shadow(color: selectedGlowColor, radius: 7, x: 0, y: 0)
                        .shadow(color: selectedDropShadowColor, radius: 2.5, x: 0, y: 1)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(hoverBorder, lineWidth: 0.7)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(hoverHighlight)
                                .frame(height: 6)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? .formaLabel
                            : (isHovered ? .formaLabel : .formaSecondaryLabelHigh)
                    )
                    .frame(width: segmentWidth, height: segmentHeight)
            }
            .frame(width: segmentWidth, height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(showOuterShell ? 3 : 0)
        .background {
            if showOuterShell {
                ToolbarGlassyCapsuleBackground(tint: nil, cornerRadius: containerCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                            .stroke(topRimColor, lineWidth: 0.6)
                    )
            }
        }
        .help(help)
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isSelected)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var topRimColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaBoneWhite.opacity(0.45)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.13)
    }

    private var activeFill: AnyShapeStyle {
        if let activeTint {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        activeTint.opacity(colorScheme == .dark ? 0.34 : 0.28),
                        activeTint.opacity(colorScheme == .dark ? 0.16 : 0.14),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(0.18),
                        Color.formaBoneWhite.opacity(0.06),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(0.90),
                    Color.formaBoneWhite.opacity(0.70),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var selectedHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectedGlowColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.06)
            : Color.formaSteelBlue.opacity(0.05)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.24)
            : Color.formaObsidian.opacity(0.08)
    }

    private var hoverFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.formaBoneWhite.opacity(0.12))
        }
        return AnyShapeStyle(Color.formaObsidian.opacity(0.08))
    }

    private var hoverBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct ToolbarGlassyCapsuleBackground: View {
    let tint: Color?
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    init(tint: Color?, cornerRadius: CGFloat) {
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .glassEffect(tint == nil ? .regular : .regular.tint(tint!.opacity(Color.FormaOpacity.overlay)))
                .overlay(shape.stroke(borderColor, lineWidth: 1))
        } else {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .clipShape(shape)

                if let tint {
                    shape.fill(tint.opacity(colorScheme == .dark ? 0.26 : 0.32))
                } else {
                    shape.fill(baseFillColor)
                }

                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(colorScheme == .dark ? Color.FormaOpacity.medium : 0.55),
                        Color.formaBoneWhite.opacity(colorScheme == .dark ? Color.FormaOpacity.subtle : 0.25),
                        Color.formaBoneWhite.opacity(0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                shape.stroke(borderColor, lineWidth: 1)
            }
        }
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(Color.FormaOpacity.medium)
            : Color.formaObsidian.opacity(0.18)
    }

    private var baseFillColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(Color.FormaOpacity.subtle)
            : Color.formaBoneWhite.opacity(0.72)
    }
}

#Preview {
    ZStack {
        Color.formaControlBackground.opacity(Color.FormaOpacity.light).ignoresSafeArea()
        UnifiedToolbar(availableWidth: 600)
            .environmentObject(DashboardViewModel())
    }
}
