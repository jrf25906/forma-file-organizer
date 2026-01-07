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
    @Binding var showKeyboardHelp: Bool
    @Namespace private var animation
    @Namespace private var filterGlassNamespace

    // Local state for dropdown visibility
    @State private var showGrouping: Bool = false
    
    // Calculate compression level based on available width
    private var compressionLevel: CompressionLevel {
        if availableWidth > 650 { return .none }
        else if availableWidth > 500 { return .medium }
        else { return .compact }
    }
    
    // Compression logic for Row 2 buttons
    private var shouldCompressGrouping: Bool {
        // Compress grouping when filters are visible AND space is tight
        // (grouping not actively expanded, but filters are showing)
        return viewModel.reviewFilterMode == .all && !showGrouping && availableWidth < 650
    }

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
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)

            // Secondary row - ALWAYS 48px, content visibility controlled via opacity
            // Key: Use ZStack with fixed frame so the container size never changes
            ZStack {
                // Filter options (left side) - always laid out, visibility via opacity
                HStack {
                    filterOptionsRow
                    Spacer()
                }
                .opacity(viewModel.reviewFilterMode == .all ? 1 : 0)
                .allowsHitTesting(viewModel.reviewFilterMode == .all)

                // Grouping options (right side) - always laid out, visibility via opacity
                HStack {
                    Spacer()
                    groupingOptionsRow
                }
                .opacity(showGrouping ? 1 : 0)
                .allowsHitTesting(showGrouping)
            }
            .frame(height: FormaLayout.Toolbar.secondaryRowHeight)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.15), value: viewModel.reviewFilterMode)
            .animation(.easeInOut(duration: 0.15), value: showGrouping)
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

            Button(action: { showKeyboardHelp = true }) {
                Image(systemName: "questionmark.circle")
                    .font(.formaBodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Keyboard Shortcuts (?)")

            // Right Panel Toggle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isRightPanelVisible.toggle()
                }
            }) {
                Image(systemName: "sidebar.right")
                    .font(.formaBodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.isRightPanelVisible ? .formaLabel : .secondary)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.isRightPanelVisible ? Color.formaSteelBlue.opacity(0.15) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Toggle Inspector (⌘I)")
        }
    }
    
    private var leftPill: some View {
        HStack(spacing: compressionLevel.spacing) {
            // Main Toggles
            HStack(spacing: 4) {
                // Pending Actions Toggle (with iOS-style badge)
                ModeToggleButton(
                    isActive: viewModel.reviewFilterMode == .needsReview,
                    icon: "tray",
                    label: "Pending",
                    badgeCount: viewModel.needsReviewCount,
                    color: .formaWarmOrange,
                    id: "review",
                    compressionLevel: compressionLevel,
                    namespace: animation
                ) {
                    viewModel.reviewFilterMode = .needsReview
                }

                // All Files Toggle
                ModeToggleButton(
                    isActive: viewModel.reviewFilterMode == .all,
                    icon: "folder",
                    label: "All Files",
                    badgeCount: 0,
                    color: .formaSteelBlue,
                    id: "allFiles",
                    compressionLevel: compressionLevel,
                    namespace: animation
                ) {
                    viewModel.reviewFilterMode = .all
                }
            }
            .padding(FormaSpacing.micro)
            .formaMaterialTier(.raised, cornerRadius: 20)
        }
    }

    private var rightPill: some View {
        HStack(spacing: compressionLevel.spacing) {
            // View Type Section - contracts to icon-only when grouping is expanded
            HStack(spacing: 4) {
                ViewTypeButton(
                    isActive: viewModel.currentViewMode == .grid,
                    icon: "square.grid.2x2",
                    label: "Grid",
                    namespace: animation,
                    compact: showGrouping
                ) {
                    viewModel.currentViewMode = .grid
                }
                .help("Grid view (⌘1)")

                ViewTypeButton(
                    isActive: viewModel.currentViewMode == .list,
                    icon: "list.bullet",
                    label: "List",
                    namespace: animation,
                    compact: showGrouping
                ) {
                    viewModel.currentViewMode = .list
                }
                .help("List view (⌘2)")

                ViewTypeButton(
                    isActive: viewModel.currentViewMode == .card,
                    icon: "rectangle.grid.1x2",
                    label: "Tile",
                    namespace: animation,
                    compact: showGrouping
                ) {
                    viewModel.currentViewMode = .card
                }
                .help("Tile view (⌘3)")
            }
            .padding(FormaSpacing.micro)
            .formaMaterialTier(.raised, cornerRadius: 20)

            // Grouping section - only show in All Files mode
            if viewModel.reviewFilterMode == .all {
                Divider()
                    .frame(height: 24)

                // Grouping Toggle - icon only when collapsed, expands with label when active
                Button(action: {
                    showGrouping.toggle()
                }) {
                    HStack(spacing: showGrouping ? 6 : 0) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.formaBodyLarge)

                        if showGrouping {
                            Text("Grouping")
                                .font(.formaBody)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))

                            Image(systemName: "chevron.up")
                                .font(.formaCaptionSemibold)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, showGrouping ? (FormaSpacing.standard - FormaSpacing.micro) : (FormaSpacing.tight + (FormaSpacing.micro / 2)))
                    .frame(height: 36)
                    // foregroundColor MUST come before background for proper glass blending
                    .foregroundColor(showGrouping ? .formaLabel : .formaSecondaryLabel)
                    .background {
                        ToolbarGlassyCapsuleBackground(
                            tint: showGrouping ? Color.formaSteelBlue : nil,
                            cornerRadius: 18
                        )
                    }
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.reviewFilterMode)
    }

    // MARK: - Filter Options Row (Left-aligned second row)
    private var filterOptionsRow: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 4) {
                    HStack(spacing: 4) {
                        filterTabsContent
                    }
                }
                .padding(.horizontal, FormaSpacing.tight)
            } else {
                HStack(spacing: 4) {
                    filterTabsContent
                }
                .padding(.horizontal, FormaSpacing.tight)
            }
        }
    }
    
    @ViewBuilder
    private var filterTabsContent: some View {
        SecondaryFilterTab(
            filter: .none,
            isSelected: viewModel.selectedSecondaryFilter == .none,
            glassNamespace: filterGlassNamespace
        ) {
            viewModel.selectedSecondaryFilter = .none
        }
        
        SecondaryFilterTab(
            filter: .recent,
            isSelected: viewModel.selectedSecondaryFilter == .recent,
            glassNamespace: filterGlassNamespace
        ) {
            viewModel.selectedSecondaryFilter = .recent
        }
        
        SecondaryFilterTab(
            filter: .flagged,
            isSelected: viewModel.selectedSecondaryFilter == .flagged,
            glassNamespace: filterGlassNamespace
        ) {
            viewModel.selectedSecondaryFilter = .flagged
        }
        
        SecondaryFilterTab(
            filter: .largeFiles,
            isSelected: viewModel.selectedSecondaryFilter == .largeFiles,
            glassNamespace: filterGlassNamespace
        ) {
            viewModel.selectedSecondaryFilter = .largeFiles
        }
    }
    
    // MARK: - Grouping Options Row (Right-aligned second row)
    private var groupingOptionsRow: some View {
        HStack(spacing: 4) {
            GroupingButton(
                isActive: viewModel.groupingMode == .none,
                icon: "square.grid.2x2",
                label: "None",
                namespace: animation,
                compact: shouldCompressGrouping
            ) {
                viewModel.groupingMode = .none
            }
            
            GroupingButton(
                isActive: viewModel.groupingMode == .date,
                icon: "clock",
                label: "Date",
                namespace: animation,
                compact: shouldCompressGrouping
            ) {
                viewModel.groupingMode = .date
            }
            
            GroupingButton(
                isActive: viewModel.groupingMode == .patterns,
                icon: "flag",
                label: "Patterns",
                namespace: animation,
                compact: shouldCompressGrouping
            ) {
                viewModel.groupingMode = .patterns
            }
            
            GroupingButton(
                isActive: viewModel.groupingMode == .combined,
                icon: "sparkles",
                label: "Smart",
                namespace: animation,
                compact: shouldCompressGrouping
            ) {
                viewModel.groupingMode = .combined
            }
        }
        .padding(FormaSpacing.micro / 2)
        .formaMaterialTier(.raised, cornerRadius: 20)
    }
}

// MARK: - Subcomponents

struct ModeToggleButton: View {
    let isActive: Bool
    let icon: String
    let label: String
    let badgeCount: Int
    let color: Color
    let id: String
    let compressionLevel: CompressionLevel
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.formaCompact)

                Text(label)
                    .font(.formaBodyMedium)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, compressionLevel == .compact ? 10 : 12)
            .padding(.horizontal, compressionLevel == .compact ? (FormaSpacing.tight + (FormaSpacing.micro / 2)) : (FormaSpacing.standard - FormaSpacing.micro))
            .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
            // IMPORTANT: foregroundColor MUST come before background
            // for VisualEffectView's .withinWindow blending to work correctly
            .foregroundColor(isActive ? .formaLabel : .formaSecondaryLabel)
            .background {
                if isActive {
                    ToolbarGlassyCapsuleBackground(
                        tint: Color.formaSteelBlue,
                        cornerRadius: 999
                    )
                    .matchedGeometryEffect(id: "activeModeToggle", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.formaSmallSemibold)
                    .foregroundColor(.formaBoneWhite)
                    .padding(.horizontal, FormaSpacing.tight - (FormaSpacing.micro / 2))
                    .padding(.vertical, FormaSpacing.micro / 2)
                    .background(Capsule().fill(color))
                    .offset(x: 8, y: -8)
            }
        }
    }
}

struct ViewTypeButton: View {
    let isActive: Bool
    let icon: String
    let label: String
    let namespace: Namespace.ID
    let compact: Bool  // When true, show icon only
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 0 : 6) {
                Image(systemName: icon)
                    .font(.formaCompact)

                if !compact {
                    Text(label)
                        .font(.formaBodyMedium)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, compact ? (FormaSpacing.tight + (FormaSpacing.micro / 2)) : (FormaSpacing.standard - FormaSpacing.micro))
            .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
            .foregroundColor(isActive ? .formaLabel : .formaSecondaryLabel)
            .background {
                if isActive {
                    ToolbarGlassyCapsuleBackground(
                        tint: Color.formaSteelBlue,
                        cornerRadius: 999
                    )
                    .matchedGeometryEffect(id: "activeView", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct GroupingButton: View {
    let isActive: Bool
    let icon: String
    let label: String
    let namespace: Namespace.ID
    let compact: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 0 : 6) {
                Image(systemName: icon)
                    .font(.formaCompact)

                if !compact {
                    Text(label)
                        .font(.formaBodyMedium)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, compact ? (FormaSpacing.tight + (FormaSpacing.micro / 2)) : (FormaSpacing.standard - FormaSpacing.micro))
            .padding(.vertical, FormaSpacing.micro)
            .foregroundColor(isActive ? .formaLabel : .formaSecondaryLabel)
            .background {
                if isActive {
                    ToolbarGlassyCapsuleBackground(
                        tint: Color.formaSteelBlue,
                        cornerRadius: 999
                    )
                    .matchedGeometryEffect(id: "activeGrouping", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ToolbarGlassyCapsuleBackground: View {
    let tint: Color?
    let cornerRadius: CGFloat

    init(tint: Color?, cornerRadius: CGFloat) {
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .glassEffect(tint == nil ? .regular : .regular.tint(tint!.opacity(Color.FormaOpacity.overlay)))
                .overlay(shape.stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1))
        } else {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .clipShape(shape)

                if let tint {
                    shape.fill(tint.opacity(Color.FormaOpacity.overlay))
                } else {
                    shape.fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.subtle))
                }

                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(Color.FormaOpacity.medium),
                        Color.formaBoneWhite.opacity(Color.FormaOpacity.subtle),
                        Color.formaBoneWhite.opacity(0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                shape.stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.formaControlBackground.opacity(Color.FormaOpacity.light).ignoresSafeArea()
        UnifiedToolbar(availableWidth: 600, showKeyboardHelp: .constant(false))
            .environmentObject(DashboardViewModel())
    }
}
