import SwiftUI
import SwiftData

/// Productivity Health Report - transforms Analytics from a graveyard of bar charts
/// into a compelling productivity dashboard that proves the app is saving time.
struct ProductivityReportView: View {
    @StateObject private var viewModel: ProductivityReportViewModel
    @Namespace private var periodAnimation

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: ProductivityReportViewModel(modelContext: modelContext))
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
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Productivity Health")
                        .font(.formaH1)
                        .foregroundColor(.formaObsidian)

                    Text("See how Forma is saving you time and digital headspace.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
                Spacer()

                periodSelector
            }

            if viewModel.isLoading {
                ProgressView("Analyzing your productivity…")
                    .progressViewStyle(.linear)
                    .tint(.formaSteelBlue)
            }
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 4) {
            let periods: [(UsagePeriod, String)] = [
                (.day, "Day"),
                (.week, "Week"),
                (.month, "Month")
            ]

            ForEach(periods, id: \.0) { period, title in
                ProductivityPeriodTab(
                    title: title,
                    isSelected: viewModel.selectedPeriod == period,
                    namespace: periodAnimation,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedPeriod = period
                        }
                    }
                )
            }
        }
        .padding(FormaSpacing.micro)
        .formaMaterialTier(.raised, cornerRadius: 20)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.formaWarning)
            Text(message)
                .font(.formaSmall)
                .foregroundColor(.formaObsidian)
            Spacer()
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaWarning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
    }

    // MARK: - Impact Metrics Section

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
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .shadow(
            color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    // MARK: - Charts Grid Section

    private var chartsGridSection: some View {
        HStack(alignment: .top, spacing: FormaSpacing.generous) {
            // Left: Storage Treemap
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("Storage Breakdown")
                    .font(.formaH2)
                    .foregroundColor(.formaObsidian)

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
                    .foregroundColor(.formaObsidian)

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
                .foregroundColor(.formaObsidian)

            Text("How fresh are your files? Green = recently used, red = digital dust (6+ months).")
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)

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
                    .foregroundColor(.formaObsidian)

                Spacer()

                if !viewModel.smartInsights.isEmpty {
                    Text("\(viewModel.smartInsights.count) suggestion\(viewModel.smartInsights.count == 1 ? "" : "s")")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
            }

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

// MARK: - Empty State

private struct ProductivityEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: FormaSpacing.tight) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.formaSecondaryLabel)

            Text(title)
                .font(.formaBody)
                .foregroundColor(.formaObsidian)

            Text(message)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .shadow(
            color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Period Tab

private struct ProductivityPeriodTab: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.formaBodyMedium)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
                .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
                .foregroundColor(isSelected ? .formaLabel : .formaSecondaryLabel)
                .background {
                    if isSelected {
                        ProductivityPeriodGlassBackground(cornerRadius: 999)
                            .matchedGeometryEffect(id: "activePeriod", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

private struct ProductivityPeriodGlassBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .glassEffect(.regular.tint(Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay)))
                .overlay(shape.stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1))
        } else {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .clipShape(shape)

                shape.fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay))

                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(Color.FormaOpacity.medium),
                        Color.formaBoneWhite.opacity(Color.FormaOpacity.subtle),
                        Color.formaBoneWhite.opacity(0)
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

// MARK: - Preview

#Preview("Productivity Report") {
    // Note: Preview requires a valid ModelContext
    Text("ProductivityReportView requires ModelContext")
        .frame(width: 900, height: 800)
}
