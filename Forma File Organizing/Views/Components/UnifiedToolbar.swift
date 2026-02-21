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

                modeControls

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
                    .tag(ReviewFilterMode.needsReview)
                Text("All Files")
                    .tag(ReviewFilterMode.all)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: compressionLevel == .compact ? 190 : 230)
        }
    }

    private var modeControls: some View {
        HStack(spacing: compressionLevel.spacing) {
            sortDropdown
            rightPill
        }
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

    private var rightPill: some View {
        HStack(spacing: compressionLevel.spacing) {
            Picker("View Mode", selection: $viewModel.currentViewMode) {
                Image(systemName: "square.grid.2x2")
                    .tag(ViewMode.grid)
                Image(systemName: "list.bullet")
                    .tag(ViewMode.list)
                Image(systemName: "rectangle.grid.1x2")
                    .tag(ViewMode.card)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 110)

            // Grouping section - only show in All Files mode
            if viewModel.reviewFilterMode == .all {
                // Grouping Toggle - icon-only, opens options row below
                Toggle(isOn: $showGrouping) {
                    Image(systemName: "square.stack.3d.up")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Group files")
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.reviewFilterMode)
    }

    // MARK: - Grouping Options Row (Right-aligned second row)
    private var groupingOptionsRow: some View {
        Picker("Grouping", selection: $viewModel.groupingMode) {
            groupingOptionLabel("None", icon: "square.grid.2x2", compressed: shouldCompressGrouping)
                .tag(FileGroupingService.GroupingMode.none)
            groupingOptionLabel("Date", icon: "clock", compressed: shouldCompressGrouping)
                .tag(FileGroupingService.GroupingMode.date)
            groupingOptionLabel("Patterns", icon: "flag", compressed: shouldCompressGrouping)
                .tag(FileGroupingService.GroupingMode.patterns)
            groupingOptionLabel("Smart", icon: "sparkles", compressed: shouldCompressGrouping)
                .tag(FileGroupingService.GroupingMode.combined)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: shouldCompressGrouping ? 200 : 290)
    }

    @ViewBuilder
    private func groupingOptionLabel(_ title: String, icon: String, compressed: Bool) -> some View {
        if compressed {
            Image(systemName: icon)
        } else {
            Label(title, systemImage: icon)
        }
    }

    private var pendingSegmentTitle: String {
        guard viewModel.needsReviewCount > 0 else { return "Pending" }
        return "Pending \(viewModel.needsReviewCount > 99 ? "99+" : "\(viewModel.needsReviewCount)")"
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
