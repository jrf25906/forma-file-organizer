import SwiftUI
import SwiftData

/// Productivity Health Report - transforms Analytics from a graveyard of bar charts
/// into a compelling productivity dashboard that proves the app is saving time.
struct ProductivityReportView: View {
    @StateObject private var viewModel: ProductivityReportViewModel
    @Namespace private var periodAnimation
    @Environment(\.colorScheme) private var colorScheme

    init(modelContext: ModelContext, navigation: NavigationViewModel, dashboardViewModel: DashboardViewModel) {
        _viewModel = StateObject(
            wrappedValue: ProductivityReportViewModel(
                modelContext: modelContext,
                navigation: navigation,
                dashboardViewModel: dashboardViewModel
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Match MainContentView toolbar spacing
            Color.clear.frame(height: FormaSpacing.Toolbar.topOffset)

            // Pinned Header
            header
                .padding(FormaSpacing.generous)

            Divider()
                .opacity(0.5)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: FormaSpacing.large) {
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    if viewModel.showsNoDataGuidance {
                        noDataGuidanceSection
                    }

                    // 1. The "Big Three" Impact Metrics
                    impactMetricsSection

                    // 2. Charts Grid: Storage Treemap + Automation Efficiency
                    chartsGridSection

                    // 3. Stale Content Heatmap (365-day calendar)
                    stalenessHeatmapSection

                    // 4. Smart Insights
                    smartInsightsSection
                }
                .padding(FormaSpacing.generous)
                .padding(.bottom, FormaSpacing.extraLarge) // Ensure last section is fully visible
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.clear) // Allow unified window glass to show through
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            viewModel.scheduleRefresh()
        }
        .onDisappear {
            viewModel.cancelRefresh()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Productivity Health")
                        .font(.formaH1)
                        .foregroundColor(.formaLabel)

                    Text("See how Forma is saving you time and digital headspace.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabelHigh)
                }
                Spacer()

                HStack(spacing: FormaSpacing.tight) {
                    periodSelector
                    analyticsInspectorToggle
                }
            }

            if viewModel.isLoading {
                ProgressView("Analyzing your productivity…")
                    .progressViewStyle(.linear)
                    .tint(.formaSteelBlue)
            }
        }
    }

    private var periodSelector: some View {
        StocksStylePeriodControl(
            selectedPeriod: viewModel.selectedPeriod,
            namespace: periodAnimation,
            onSelect: { period in
                viewModel.selectedPeriod = period
            }
        )
    }

    private var analyticsInspectorToggle: some View {
        Button(action: {}) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.formaSecondaryLabelHigh)
                .frame(width: 30, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? Color.formaBoneWhite.opacity(0.08)
                                : Color.formaObsidian.opacity(0.06)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                                ? Color.formaBoneWhite.opacity(0.14)
                                : Color.formaObsidian.opacity(0.12),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(0.4)
        .help("Inspector unavailable in Analytics")
        .accessibilityIdentifier("toolbarInspectorToggle")
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.formaWarning)
            Text(message)
                .font(.formaSmall)
                .foregroundColor(.formaLabel)
            Spacer()
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaWarning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
    }

    // MARK: - Impact Metrics Section

    private var noDataGuidanceSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Label("No Activity Yet", systemImage: "sparkles")
                .font(.formaBodyBold)
                .foregroundColor(.formaLabel)

            Text("Run one scan and organize a few files to unlock insights in this dashboard.")
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabelHigh)

            HStack(spacing: FormaSpacing.standard) {
                Button("Scan Folders") {
                    viewModel.runInitialScan()
                }
                .buttonStyle(.borderedProminent)
                .tint(.formaSteelBlue)

                Button("Open Pending Files") {
                    viewModel.openPendingReviewQueue()
                }
                .buttonStyle(.bordered)

                Button("Create Rule") {
                    viewModel.openRuleBuilder()
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(FormaSpacing.generous)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.formaBoneWhite.opacity(0.08)
                        : Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.formaBoneWhite.opacity(0.16)
                        : Color.formaObsidian.opacity(Color.FormaOpacity.light),
                    lineWidth: 1
                )
        )
    }

    private var impactMetricsSection: some View {
        HStack(spacing: FormaSpacing.generous) {
            if let metrics = viewModel.productivityMetrics {
                ImpactMetricCard.spaceReclaimed(
                    metrics.spaceReclaimedBytes,
                    previousBytes: metrics.previousPeriod?.spaceReclaimedBytes
                )
                .frame(minWidth: 180, maxWidth: .infinity)

                ImpactMetricCard.timeSaved(
                    metrics.timeSavedSeconds,
                    previousSeconds: metrics.previousPeriod?.timeSavedSeconds
                )
                .frame(minWidth: 180, maxWidth: .infinity)

                ImpactMetricCard.organizationScore(metrics.organizationScore)
                    .frame(minWidth: 180, maxWidth: .infinity)
            } else {
                // Loading placeholders
                ForEach(0..<3, id: \.self) { _ in
                    impactMetricPlaceholder
                        .frame(minWidth: 180, maxWidth: .infinity)
                }
            }
        }
    }

    private var impactMetricPlaceholder: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.formaObsidian.opacity(0.1))
                    .frame(width: 24, height: 24)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.formaObsidian.opacity(0.1))
                    .frame(width: 80, height: 16)
            }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.formaObsidian.opacity(0.1))
                .frame(width: 100, height: 36)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.formaObsidian.opacity(0.1))
                .frame(width: 60, height: 14)
        }
        .padding(FormaSpacing.generous)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
    }

    // MARK: - Charts Grid Section

    private var chartsGridSection: some View {
        HStack(alignment: .top, spacing: FormaSpacing.generous) {
            // Left: Storage Treemap
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("Storage Breakdown")
                    .font(.formaH2)
                    .foregroundColor(.formaLabel)

                if let treemap = viewModel.storageTreemap, !treemap.children.isEmpty {
                    TreemapChart(rootNode: treemap) { node in
                        viewModel.handleTreemapNodeTap(node)
                    }
                    .frame(height: 280)
                } else {
                    ProductivityEmptyState(
                        icon: "square.grid.3x3.fill",
                        title: "No storage data",
                        message: "Scan some folders to see your storage breakdown."
                    )
                    .frame(height: 280)
                }
            }
            .frame(maxWidth: .infinity)

            // Right: Automation Efficiency Graph
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("Automation Efficiency")
                    .font(.formaH2)
                    .foregroundColor(.formaLabel)

                StackedAreaChart(points: viewModel.automationTimeline)
                    .frame(height: 280)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Staleness Heatmap Section

    private var stalenessHeatmapSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("File Freshness Calendar")
                .font(.formaH2)
                .foregroundColor(.formaLabel)

            Text("How fresh are your files? Green = recently used, red = digital dust (6+ months).")
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabelHigh)

            // Horizontal scroll for wide calendar (52 weeks ≈ 800px)
            ScrollView(.horizontal, showsIndicators: false) {
                CalendarHeatmap(data: viewModel.stalenessCalendar) {
                    viewModel.nudgeCleanup()
                }
                .frame(minWidth: 820) // Ensure calendar has room to render
            }
        }
    }

    // MARK: - Smart Insights Section

    private var smartInsightsSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                Text("Smart Insights")
                    .font(.formaH2)
                    .foregroundColor(.formaLabel)

                Spacer()

                if !viewModel.smartInsights.isEmpty {
                    Text("\(viewModel.smartInsights.count) suggestion\(viewModel.smartInsights.count == 1 ? "" : "s")")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabelHigh)
                    }
            }

            if viewModel.showsNoDataGuidance {
                ProductivityEmptyState(
                    icon: "lightbulb",
                    title: "Insights will appear after your first pass",
                    message: "After Forma organizes a few files, you'll get actionable recommendations here."
                )
                .frame(minHeight: 140)
            } else {
                SmartInsightList(
                    insights: viewModel.smartInsights,
                    onAction: { insight in
                        viewModel.handleInsightAction(insight)
                    },
                    onDismiss: { insight in
                        viewModel.dismissInsight(insight)
                    }
                )
            }
        }
    }
}

// MARK: - Empty State

private struct ProductivityEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: FormaSpacing.tight) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.formaSecondaryLabelHigh)

            Text(title)
                .font(.formaBody)
                .foregroundColor(.formaLabel)

            Text(message)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabelHigh)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
    }
}

// MARK: - Period Control (Stocks Style)

private struct StocksStylePeriodControl: View {
    let selectedPeriod: UsagePeriod
    let namespace: Namespace.ID
    let onSelect: (UsagePeriod) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredPeriod: UsagePeriod?

    private let periods: [(UsagePeriod, String)] = [
        (.day, "Day"),
        (.week, "Week"),
        (.month, "Month"),
    ]

    private let containerCornerRadius: CGFloat = FormaControlChromeMetrics.containerCornerRadius
    private let selectedCornerRadius: CGFloat = FormaControlChromeMetrics.selectedCornerRadius
    private let segmentHeight: CGFloat = FormaControlChromeMetrics.segmentHeight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(periods.enumerated()), id: \.element.0) { index, item in
                let (period, title) = item
                segmentButton(period: period, title: title)

                if index < periods.count - 1 {
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
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: selectedPeriod)
        .animation(.easeOut(duration: 0.16), value: hoveredPeriod)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func segmentButton(period: UsagePeriod, title: String) -> some View {
        let isSelected = selectedPeriod == period
        let isHovered = hoveredPeriod == period

        return Button(action: { onSelect(period) }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.5)
                        )
                        .shadow(color: selectedDropShadowColor, radius: 1.5, x: 0, y: 0.5)
                        .matchedGeometryEffect(id: "activePeriod", in: namespace)
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                }

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
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
                hoveredPeriod = period
            } else if hoveredPeriod == period {
                hoveredPeriod = nil
            }
        }
    }

    // MARK: - Colors

    private var separatorColor: Color {
        FormaControlChromePalette.separator(colorScheme)
    }

    private var containerTint: Color {
        colorScheme == .dark
            ? Color.formaSage.opacity(0.18)
            : Color.formaMutedBlue.opacity(0.10)
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
        colorScheme == .dark
            ? Color.formaSage
            : Color.formaSteelBlue
    }

    private var selectedDropShadowColor: Color {
        FormaControlChromePalette.activeShadow(colorScheme)
    }

    private var hoverFill: Color {
        FormaControlChromePalette.hoverFill(colorScheme, tint: selectedTint)
    }
}

// MARK: - Preview

#Preview("Productivity Report") {
    // Note: Preview requires a valid ModelContext
    Text("ProductivityReportView requires ModelContext")
        .frame(width: 900, height: 800)
}
