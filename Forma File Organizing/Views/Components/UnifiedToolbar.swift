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

    var showContextDetail: Bool {
        self == .none
    }

    var showArrangeLabel: Bool {
        self != .compact
    }

    var showLoadingLabel: Bool {
        self != .compact
    }

    var scopeWidth: CGFloat {
        switch self {
        case .none: return 230
        case .medium: return 212
        case .compact: return 182
        }
    }

    var viewModeWidth: CGFloat {
        switch self {
        case .none: return 110
        case .medium: return 104
        case .compact: return 96
        }
    }
}

private struct ToolbarCluster<Content: View>: View {
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let tint: Color?
    let elevation: FormaChromeElevation
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        spacing: CGFloat = FormaSpacing.tight,
        horizontalPadding: CGFloat = FormaSpacing.tight,
        verticalPadding: CGFloat = FormaSpacing.tight - FormaSpacing.micro,
        tint: Color? = nil,
        elevation: FormaChromeElevation = .resting,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.tint = tint
        self.elevation = elevation
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            FormaChromeSurface(
                cornerRadius: FormaRadius.control,
                fill: clusterFill,
                tint: tint,
                elevation: elevation
            )
        )
    }

    private var clusterFill: Color {
        FormaControlChromePalette.clusterFill(colorScheme, elevation: elevation)
    }
}

private struct ToolbarSegmentButton<Label: View>: View {
    let isSelected: Bool
    let tint: Color
    let action: () -> Void
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    @ViewBuilder let label: Label
    @Environment(\.colorScheme) private var colorScheme

    init(
        isSelected: Bool,
        tint: Color = .formaSteelBlue,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.isSelected = isSelected
        self.tint = tint
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .padding(.horizontal, FormaSpacing.standard - 2)
                .background(
                    FormaCompactSelectionChrome(
                        isSelected: isSelected,
                        tint: tint,
                        cornerRadius: FormaRadius.small
                    )
                )
                .foregroundStyle(
                    isSelected
                        ? FormaControlChromePalette.selectedForeground(colorScheme, tint: tint)
                        : Color.formaLabel
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct UnifiedToolbar: View {
    let availableWidth: CGFloat
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    // Calculate compression level based on available width
    private var compressionLevel: CompressionLevel {
        if availableWidth > 760 { return .none }
        else if availableWidth > 560 { return .medium }
        else { return .compact }
    }
    
    private var primaryRowHeight: CGFloat { 32 }

    var body: some View {
        HStack(spacing: compressionLevel == .compact ? FormaSpacing.tight : FormaSpacing.standard - FormaSpacing.micro) {
            leftToolbarGroup

            Spacer(minLength: compressionLevel.spacing)

            displayGroup
        }
        .frame(height: primaryRowHeight)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.reviewFilterMode)
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentViewMode)
        .animation(.easeInOut(duration: 0.2), value: viewModel.groupingMode)
    }

    private var isInspectorDisabled: Bool {
        viewModel.rightPanelMode == .analytics
    }

    private var isInspectorEffectivelyVisible: Bool {
        viewModel.isRightPanelVisible && !isInspectorDisabled
    }

    private var showsContextCluster: Bool {
        availableWidth > 460 || compressionLevel != .compact || viewModel.isLoading || viewModel.isSelectionMode
    }

    private var selectionCount: Int {
        viewModel.selectedFileIDs.count
    }

    private var visibleFileCount: Int {
        viewModel.visibleFiles.count
    }

    @ViewBuilder
    private var leftToolbarGroup: some View {
        HStack(spacing: compressionLevel == .compact ? FormaSpacing.tight : FormaSpacing.standard - FormaSpacing.micro) {
            scopeGroup

            if showsContextCluster {
                contextCluster
            }

            arrangeMenu
        }
    }

    private var scopeGroup: some View {
        ToolbarCluster(
            spacing: FormaSpacing.micro,
            horizontalPadding: FormaSpacing.micro,
            verticalPadding: FormaSpacing.micro,
            tint: reviewModeClusterTint,
            elevation: reviewModeClusterElevation
        ) {
            ToolbarSegmentButton(
                isSelected: viewModel.reviewFilterMode == .needsReview,
                accessibilityIdentifier: "reviewMode_needsReview",
                accessibilityLabel: pendingSegmentTitle,
                action: { viewModel.reviewFilterMode = .needsReview }
            ) {
                Text(pendingSegmentTitle)
                    .font(.formaSmallSemibold)
                    .lineLimit(1)
            }

            ToolbarSegmentButton(
                isSelected: viewModel.reviewFilterMode == .all,
                accessibilityIdentifier: "reviewMode_allFiles",
                accessibilityLabel: "All Files",
                action: { viewModel.reviewFilterMode = .all }
            ) {
                Text("All Files")
                    .font(.formaSmallSemibold)
                    .lineLimit(1)
            }
        }
        .frame(width: compressionLevel.scopeWidth)
        .frame(height: primaryRowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toolbarReviewModePicker")
    }

    private var contextCluster: some View {
        ToolbarCluster(
            spacing: compressionLevel.spacing + FormaSpacing.micro,
            horizontalPadding: compressionLevel.horizontalPadding,
            verticalPadding: FormaSpacing.micro + 1,
            tint: contextClusterTint,
            elevation: contextClusterElevation
        ) {
            contextLeadingAccessory

            HStack(spacing: FormaSpacing.micro + 2) {
                Text(contextSummaryTitle)
                    .font(.formaSmallSemibold)
                    .foregroundColor(.formaLabel)
                    .monospacedDigit()

                if compressionLevel.showContextDetail {
                    Text("·")
                        .font(.formaCaption)
                        .foregroundColor(.formaTertiaryLabel)

                    Text(contextSummaryDetail)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: primaryRowHeight)
        .frame(minWidth: compressionLevel == .compact ? 88 : 132, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("toolbarContextSummary")
        .accessibilityLabel(contextSummaryTitle)
        .accessibilityValue(contextSummaryDetail)
    }

    @ViewBuilder
    private var contextLeadingAccessory: some View {
        if viewModel.isLoading {
            HStack(spacing: FormaSpacing.micro) {
                ProgressView()
                    .controlSize(.small)

                if compressionLevel.showLoadingLabel {
                    Text("Scanning")
                        .font(.formaCaptionSemibold)
                        .foregroundColor(.formaSteelBlue)
                }
            }
        } else {
            Image(systemName: contextSymbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(contextSymbolColor)
        }
    }

    private var arrangeMenu: some View {
        Menu {
            Section("Sort") {
                Picker("Sort", selection: $viewModel.sortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
            }

            if viewModel.reviewFilterMode == .all {
                Section("Group") {
                    Picker("Grouping", selection: $viewModel.groupingMode) {
                        Label("None", systemImage: "square.grid.2x2")
                            .tag(FileGroupingService.GroupingMode.none)
                        Label("Date", systemImage: "clock")
                            .tag(FileGroupingService.GroupingMode.date)
                        Label("Patterns", systemImage: "flag")
                            .tag(FileGroupingService.GroupingMode.patterns)
                        Label("Smart", systemImage: "sparkles")
                            .tag(FileGroupingService.GroupingMode.combined)
                    }
                }
            }
        } label: {
            ToolbarCluster(
                spacing: compressionLevel.spacing,
                horizontalPadding: compressionLevel.horizontalPadding,
                verticalPadding: FormaSpacing.micro + 1,
                tint: arrangeClusterTint,
                elevation: arrangeClusterElevation
            ) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.formaSecondaryLabelHigh)

                Text(arrangeSummary)
                    .font(.formaSmallMedium)
                    .foregroundColor(.formaLabel)
                    .lineLimit(1)
            }
        }
        .menuStyle(.borderlessButton)
        .frame(height: primaryRowHeight)
        .fixedSize(horizontal: true, vertical: false)
        .help(arrangeHelpText)
        .accessibilityIdentifier("toolbarArrangeMenu")
        .accessibilityLabel(arrangeAccessibilityLabel)
        .accessibilityValue(arrangeSummary)
    }

    private var displayGroup: some View {
        ToolbarCluster(
            spacing: compressionLevel.spacing,
            horizontalPadding: compressionLevel.horizontalPadding - (compressionLevel == .compact ? FormaSpacing.micro : 0),
            verticalPadding: FormaSpacing.micro + 1,
            tint: isInspectorEffectivelyVisible ? .formaSteelBlue : nil,
            elevation: displayGroupElevation
        ) {
            HStack(spacing: FormaSpacing.micro) {
                viewModeButton(mode: .grid, systemName: "square.grid.2x2", accessibilityIdentifier: "viewMode_grid", accessibilityLabel: "Grid view")
                viewModeButton(mode: .list, systemName: "list.bullet", accessibilityIdentifier: "viewMode_list", accessibilityLabel: "List view")
                viewModeButton(mode: .card, systemName: "rectangle.grid.1x2", accessibilityIdentifier: "viewMode_card", accessibilityLabel: "Card view")
            }
            .frame(width: compressionLevel.viewModeWidth)

            Divider()
                .frame(height: primaryRowHeight - FormaSpacing.tight)

            Button(action: toggleInspector) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(inspectorButtonForeground)
                    .frame(width: 28, height: 24)
                    .background(
                        FormaChromeSurface(
                            cornerRadius: FormaRadius.small,
                            fill: inspectorButtonBackground,
                            tint: isInspectorEffectivelyVisible ? .formaSteelBlue : nil,
                            elevation: isInspectorEffectivelyVisible ? .raised : .inset
                        )
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("i", modifiers: .command)
            .help(inspectorHelpText)
            .disabled(isInspectorDisabled)
            .opacity(isInspectorDisabled ? 0.45 : 1.0)
            .accessibilityIdentifier("toolbarInspectorToggle")
            .accessibilityLabel(inspectorAccessibilityLabel)
        }
        .frame(height: primaryRowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toolbarViewModePicker")
    }

    @ViewBuilder
    private func viewModeButton(
        mode: ViewMode,
        systemName: String,
        accessibilityIdentifier: String,
        accessibilityLabel: String
    ) -> some View {
        Button(action: { viewModel.currentViewMode = mode }) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    FormaCompactSelectionChrome(
                        isSelected: viewModel.currentViewMode == mode,
                        tint: .formaSteelBlue,
                        cornerRadius: FormaRadius.small
                    )
                )
                .foregroundStyle(
                    viewModel.currentViewMode == mode
                        ? FormaControlChromePalette.selectedForeground(colorScheme, tint: .formaSteelBlue)
                        : Color.formaSecondaryLabelHigh
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(viewModel.currentViewMode == mode ? .isSelected : [])
    }

    private var pendingSegmentTitle: String {
        guard viewModel.totalPendingCount > 0 else { return "Pending" }
        return "Pending \(viewModel.totalPendingCount > 99 ? "99+" : "\(viewModel.totalPendingCount)")"
    }

    private var contextSummaryTitle: String {
        if viewModel.isSelectionMode {
            return "\(selectionCount) selected"
        }

        if viewModel.reviewFilterMode == .needsReview {
            return "\(viewModel.currentPassCount) in current pass"
        }

        return visibleFileCount == 1 ? "1 file" : "\(visibleFileCount) files"
    }

    private var contextSummaryDetail: String {
        if viewModel.isLoading {
            return "Scanning folders"
        }

        if viewModel.isSelectionMode {
            return viewModel.canOrganizeAllSelected
                ? "Batch actions ready"
                : "Some files still need review"
        }

        var detailParts = [shortSortTitle(viewModel.sortMode)]

        if viewModel.reviewFilterMode == .all, viewModel.groupingMode != .none {
            detailParts.append("Grouped by \(groupingModeTitle(viewModel.groupingMode))")
        }

        return detailParts.joined(separator: " · ")
    }

    private var contextClusterTint: Color? {
        if viewModel.isSelectionMode || viewModel.isLoading {
            return .formaSteelBlue
        }

        if viewModel.reviewFilterMode == .needsReview {
            return .formaMutedBlue
        }

        return nil
    }

    private var reviewModeClusterTint: Color? {
        viewModel.reviewFilterMode == .needsReview ? .formaMutedBlue : nil
    }

    private var reviewModeClusterElevation: FormaChromeElevation {
        viewModel.reviewFilterMode == .needsReview ? .raised : .resting
    }

    private var contextClusterElevation: FormaChromeElevation {
        if viewModel.isSelectionMode || viewModel.isLoading {
            return .raised
        }

        return .resting
    }

    private var arrangeClusterTint: Color? {
        if viewModel.reviewFilterMode == .all, viewModel.groupingMode != .none {
            return .formaMutedBlue
        }

        return nil
    }

    private var arrangeClusterElevation: FormaChromeElevation {
        viewModel.reviewFilterMode == .all && viewModel.groupingMode != .none ? .raised : .resting
    }

    private var displayGroupElevation: FormaChromeElevation {
        isInspectorEffectivelyVisible ? .raised : .resting
    }

    private var contextSymbolName: String {
        if viewModel.isSelectionMode {
            return "checkmark.circle"
        }

        return viewModel.reviewFilterMode == .needsReview ? "tray.full" : "doc.on.doc"
    }

    private var contextSymbolColor: Color {
        if viewModel.isSelectionMode || viewModel.reviewFilterMode == .needsReview {
            return .formaSteelBlue
        }

        return .formaSecondaryLabelHigh
    }

    private var arrangeSummary: String {
        var detailParts = [shortSortTitle(viewModel.sortMode)]

        if viewModel.reviewFilterMode == .all, viewModel.groupingMode != .none {
            detailParts.append(groupingModeTitle(viewModel.groupingMode))
        }

        return detailParts.joined(separator: " · ")
    }

    private var arrangeHelpText: String {
        viewModel.reviewFilterMode == .all
            ? "Arrange files by sort order and grouping"
            : "Arrange files by sort order"
    }

    private var arrangeAccessibilityLabel: String {
        if viewModel.reviewFilterMode == .all {
            return "Arrange files. Sorted by \(viewModel.sortMode.rawValue). Grouped by \(groupingModeTitle(viewModel.groupingMode))"
        }

        return "Arrange files. Sorted by \(viewModel.sortMode.rawValue)"
    }

    private var inspectorHelpText: String {
        "\(isInspectorEffectivelyVisible ? "Hide" : "Show") Inspector (\u{2318}I)"
    }

    private var inspectorAccessibilityLabel: String {
        isInspectorEffectivelyVisible ? "Hide inspector" : "Show inspector"
    }

    private var inspectorButtonForeground: Color {
        if isInspectorDisabled {
            return .formaTertiaryLabel
        }

        return isInspectorEffectivelyVisible ? .formaSteelBlue : .formaSecondaryLabelHigh
    }

    private var inspectorButtonBackground: Color {
        isInspectorEffectivelyVisible
            ? Color.formaBoneWhite.opacity(Color.FormaOpacity.strong)
            : Color.clear
    }

    private func toggleInspector() {
        guard !isInspectorDisabled else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.setRightPanelVisible(!viewModel.isRightPanelVisible)
        }
    }

    private func shortSortTitle(_ mode: SortMode) -> String {
        switch mode {
        case .newestFirst:
            return "Newest"
        case .oldestFirst:
            return "Oldest"
        case .largest:
            return "Largest"
        case .nameAZ:
            return "A-Z"
        case .priority:
            return "Priority"
        }
    }

    private func groupingModeTitle(_ mode: FileGroupingService.GroupingMode) -> String {
        switch mode {
        case .none:
            return "None"
        case .date:
            return "Date"
        case .patterns:
            return "Patterns"
        case .combined:
            return "Smart"
        }
    }
}

#Preview {
    ZStack {
        Color.formaControlBackground.opacity(Color.FormaOpacity.light).ignoresSafeArea()
        UnifiedToolbar(availableWidth: 600)
            .environmentObject(DashboardViewModel())
    }
}
