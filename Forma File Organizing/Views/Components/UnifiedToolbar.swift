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
    
    // Calculate compression level based on available width
    private var compressionLevel: CompressionLevel {
        if availableWidth > 650 { return .none }
        else if availableWidth > 500 { return .medium }
        else { return .compact }
    }
    
    private var primaryRowHeight: CGFloat { 30 }

    var body: some View {
        HStack(spacing: 12) {
            leftPill

            Spacer(minLength: compressionLevel.spacing)

            modeControls

            trailingControls
        }
        .frame(height: primaryRowHeight)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.reviewFilterMode)
    }

    private var isInspectorDisabled: Bool {
        viewModel.rightPanelMode == .analytics
    }

    private var isInspectorEffectivelyVisible: Bool {
        viewModel.isRightPanelVisible && !isInspectorDisabled
    }

    private var trailingControls: some View {
        HStack(spacing: 12) {
            if viewModel.isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)

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
                guard !isInspectorDisabled else { return }
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
            .disabled(isInspectorDisabled)

            Toggle(
                isOn: Binding(
                    get: { isInspectorEffectivelyVisible },
                    set: { newValue in
                        guard !isInspectorDisabled else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.isRightPanelVisible = newValue
                        }
                    }
                )
            ) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help("Toggle Inspector (\u{2318}I)")
            .disabled(isInspectorDisabled)
            .opacity(isInspectorDisabled ? 0.4 : 1.0)
            .accessibilityIdentifier("toolbarInspectorToggle")
        }
        .frame(height: primaryRowHeight)
    }
    
    private var leftPill: some View {
        HStack(spacing: compressionLevel.spacing) {
            Picker("Review Filter", selection: $viewModel.reviewFilterMode) {
                Text(pendingSegmentTitle)
                    .accessibilityIdentifier("reviewMode_needsReview")
                    .tag(ReviewFilterMode.needsReview)
                Text("All Files")
                    .accessibilityIdentifier("reviewMode_allFiles")
                    .tag(ReviewFilterMode.all)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: compressionLevel == .compact ? 190 : 230)
            .accessibilityIdentifier("toolbarReviewModePicker")
        }
    }

    private var modeControls: some View {
        HStack(spacing: compressionLevel.spacing) {
            sortDropdown

            if viewModel.reviewFilterMode == .all {
                groupingDropdown
            }

            rightPill
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.reviewFilterMode)
    }

    private var sortDropdown: some View {
        Picker("Sort", selection: $viewModel.sortMode) {
            ForEach(SortMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(minWidth: compressionLevel == .compact ? 42 : 130, alignment: .leading)
        .help("Sort files")
        .accessibilityIdentifier("toolbarSortMenu")
        .accessibilityLabel("Sort files by \(viewModel.sortMode.rawValue)")
    }

    private var groupingDropdown: some View {
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
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(minWidth: compressionLevel == .compact ? 42 : 130, alignment: .leading)
        .help("Group files")
        .accessibilityIdentifier("toolbarGroupingMenu")
        .accessibilityLabel("Group files by \(groupingModeTitle(viewModel.groupingMode))")
    }

    private var rightPill: some View {
        HStack(spacing: compressionLevel.spacing) {
            Picker("View Mode", selection: $viewModel.currentViewMode) {
                Image(systemName: "square.grid.2x2")
                    .accessibilityLabel("Grid view")
                    .accessibilityIdentifier("viewMode_grid")
                    .tag(ViewMode.grid)
                Image(systemName: "list.bullet")
                    .accessibilityLabel("List view")
                    .accessibilityIdentifier("viewMode_list")
                    .tag(ViewMode.list)
                Image(systemName: "rectangle.grid.1x2")
                    .accessibilityLabel("Card view")
                    .accessibilityIdentifier("viewMode_card")
                    .tag(ViewMode.card)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 110)
        }
        .accessibilityIdentifier("toolbarViewModePicker")
    }

    private var pendingSegmentTitle: String {
        guard viewModel.needsReviewCount > 0 else { return "Pending" }
        return "Pending \(viewModel.needsReviewCount > 99 ? "99+" : "\(viewModel.needsReviewCount)")"
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
