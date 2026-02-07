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

    @Environment(\.colorScheme) private var colorScheme

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

    private var primaryRowHeight: CGFloat { 30 }

    var body: some View {
        // Use a fixed-height container that NEVER changes size between modes
        // This ensures content below starts at the exact same Y position
        VStack(spacing: 0) {
            // Main toolbar row - fixed height
            HStack(spacing: 12) {
                leftPill

                Spacer(minLength: 0)

                sortDropdown

                rightPill

                trailingControls
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

    private var isInspectorDisabled: Bool {
        viewModel.rightPanelMode == .analytics
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

            // Inspector toggle (sidebar.right) - toggles right panel visibility
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isRightPanelVisible.toggle()
                }
            }) {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut("i", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0.001)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            StocksStyleToolbarIconButton(
                icon: "sidebar.right",
                isSelected: viewModel.isRightPanelVisible,
                help: "Toggle Inspector (\u{2318}I)"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isRightPanelVisible.toggle()
                }
            }
            .disabled(isInspectorDisabled)
            .opacity(isInspectorDisabled ? 0.4 : 1.0)
            .accessibilityIdentifier("toolbarInspectorToggle")
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

    private var sortDropdown: some View {
        Menu {
            ForEach(SortMode.allCases) { mode in
                Button(action: { viewModel.sortMode = mode }) {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
                .disabled(viewModel.sortMode == mode)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10.5, weight: .medium))
                if compressionLevel != .compact {
                    Text(viewModel.sortMode.rawValue)
                        .font(.system(size: 12, weight: .regular))
                        .lineLimit(1)
                }
            }
            .foregroundColor(.formaSecondaryLabelHigh)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(sortDropdownFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(sortDropdownBorder, lineWidth: 0.5)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var sortDropdownFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(0.06)
    }

    private var sortDropdownBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(0.12)
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

    private let containerCornerRadius: CGFloat = 8
    private let selectedCornerRadius: CGFloat = 6
    private let segmentHeight: CGFloat = 24
    private let segmentPlateHorizontalInset: CGFloat = 2
    private let segmentPlateVerticalInset: CGFloat = 2

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentButton(segment)

                if index < segments.count - 1 {
                    Rectangle()
                        .fill(separatorColor)
                        .frame(width: 1, height: 16)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                .fill(containerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(containerBorder, lineWidth: 0.5)
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
                                .stroke(activeBorder, lineWidth: 0.5)
                        )
                        .shadow(color: selectedDropShadowColor, radius: 1.5, x: 0, y: 0.5)
                        .matchedGeometryEffect(id: "activeReviewSegment", in: namespace)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                HStack(spacing: 5) {
                    Image(systemName: segment.icon)
                        .font(.system(size: 10.5, weight: isSelected ? .medium : .regular))

                    Text(segment.label)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)

                    // Inline badge count
                    if segment.mode == .needsReview && pendingCount > 0 {
                        Text(pendingBadgeText)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.formaBoneWhite)
                            .frame(minWidth: 14, minHeight: 14)
                            .padding(.horizontal, 1.5)
                            .background {
                                Capsule().fill(badgeFill)
                            }
                    }
                }
                .padding(.horizontal, 10)
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
            ? Color.formaBoneWhite.opacity(0.20)
            : Color.formaObsidian.opacity(0.12)
    }

    private var containerFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(0.06)
    }

    private var containerBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(0.12)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaObsidian.opacity(0.08)
    }

    private var activeFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaBoneWhite.opacity(0.90)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.20)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.10)
            : Color.formaObsidian.opacity(0.05)
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

    private let containerCornerRadius: CGFloat = 8
    private let selectedCornerRadius: CGFloat = 6
    private let segmentWidth: CGFloat = 32
    private let segmentHeight: CGFloat = 24
    private let segmentPlateHorizontalInset: CGFloat = 2
    private let segmentPlateVerticalInset: CGFloat = 2

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentButton(segment)

                if index < segments.count - 1 {
                    Rectangle()
                        .fill(separatorColor)
                        .frame(width: 1, height: 16)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                .fill(containerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(containerBorder, lineWidth: 0.5)
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
                                .stroke(activeBorder, lineWidth: 0.5)
                        )
                        .shadow(color: selectedDropShadowColor, radius: 1.5, x: 0, y: 0.5)
                        .matchedGeometryEffect(id: "activeViewSegment", in: namespace)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                Image(systemName: segment.icon)
                    .font(.system(size: 11, weight: .medium))
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
            ? Color.formaBoneWhite.opacity(0.20)
            : Color.formaObsidian.opacity(0.12)
    }

    private var containerFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(0.06)
    }

    private var containerBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(0.12)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaObsidian.opacity(0.08)
    }

    private var activeFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaBoneWhite.opacity(0.90)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.20)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.10)
            : Color.formaObsidian.opacity(0.05)
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

    private let containerCornerRadius: CGFloat = 8
    private let selectedCornerRadius: CGFloat = 6
    private let segmentHeight: CGFloat = 24
    private let compactMinWidth: CGFloat = 30
    private let segmentPlateHorizontalInset: CGFloat = 2
    private let segmentPlateVerticalInset: CGFloat = 2

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentButton(segment)

                if index < segments.count - 1 {
                    Rectangle()
                        .fill(separatorColor)
                        .frame(width: 1, height: 16)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                .fill(containerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(containerBorder, lineWidth: 0.5)
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
                                .stroke(activeBorder, lineWidth: 0.5)
                        )
                        .shadow(color: selectedDropShadowColor, radius: 1.5, x: 0, y: 0.5)
                        .matchedGeometryEffect(id: "activeGroupingSegment", in: namespace)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                HStack(spacing: compact ? 0 : 4) {
                    Image(systemName: segment.icon)
                        .font(.system(size: 10.5, weight: isSelected ? .medium : .regular))

                    if !compact {
                        Text(segment.label)
                            .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, compact ? 8 : 9)
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
            ? Color.formaBoneWhite.opacity(0.20)
            : Color.formaObsidian.opacity(0.12)
    }

    private var containerFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(0.06)
    }

    private var containerBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(0.12)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaObsidian.opacity(0.08)
    }

    private var activeFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaBoneWhite.opacity(0.90)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.20)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.10)
            : Color.formaObsidian.opacity(0.05)
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

    private let containerCornerRadius: CGFloat = 8
    private let selectedCornerRadius: CGFloat = 6
    private let segmentWidth: CGFloat = 32
    private let segmentHeight: CGFloat = 24
    private let segmentPlateHorizontalInset: CGFloat = 2
    private let segmentPlateVerticalInset: CGFloat = 2

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.5)
                        )
                        .shadow(color: selectedDropShadowColor, radius: 1.5, x: 0, y: 0.5)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? (activeTint != nil ? activeTint! : .formaLabel)
                            : (isHovered ? .formaLabel : .formaSecondaryLabelHigh)
                    )
                    .frame(width: segmentWidth, height: segmentHeight)
            }
            .frame(width: segmentWidth, height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(showOuterShell ? 2 : 0)
        .background {
            if showOuterShell {
                RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                    .fill(containerFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                            .stroke(containerBorder, lineWidth: 0.5)
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

    private var containerFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(0.06)
    }

    private var containerBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(0.12)
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaObsidian.opacity(0.08)
    }

    private var activeFill: Color {
        if let activeTint {
            return activeTint.opacity(colorScheme == .dark ? 0.20 : 0.15)
        }
        return colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaBoneWhite.opacity(0.90)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.20)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.10)
            : Color.formaObsidian.opacity(0.05)
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
