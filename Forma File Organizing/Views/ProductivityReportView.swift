import SwiftUI
import SwiftData

/// Productivity Health Report - transforms Analytics from a graveyard of bar charts
/// into a compelling productivity dashboard that proves the app is saving time.
struct ProductivityReportView: View {
    @StateObject private var viewModel: ProductivityReportViewModel
    @Environment(\.colorScheme) private var colorScheme
    private let onBackToDashboard: (() -> Void)?

    init(
        modelContext: ModelContext,
        navigation: NavigationViewModel,
        dashboardViewModel: DashboardViewModel,
        onBackToDashboard: (() -> Void)? = nil
    ) {
        self.onBackToDashboard = onBackToDashboard
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
            headerBand

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: FormaSpacing.extraLarge) {
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    if viewModel.showsNoDataGuidance {
                        noDataGuidanceSection
                        gettingStartedChecklistSection
                    } else {
                        // 1. The "Big Three" Impact Metrics
                        impactMetricsSection

                        // 2. Charts Grid: Storage Treemap + Automation Efficiency
                        chartsGridSection

                        // 3. Stale Content Heatmap (365-day calendar)
                        stalenessHeatmapSection

                        // 4. Smart Insights
                        smartInsightsSection
                    }
                }
                .padding(FormaSpacing.generous)
                .padding(.bottom, FormaSpacing.extraLarge) // Ensure last section is fully visible
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.formaSurfaceChrome)
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

    private var headerBand: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: FormaSpacing.Toolbar.topOffset)

            header
                .padding(.horizontal, FormaSpacing.generous)
                .padding(.top, FormaSpacing.standard)
                .padding(.bottom, FormaSpacing.generous)
        }
        .background(Color.formaSurfaceAnchor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.formaSeparator.opacity(colorScheme == .dark ? 0.58 : 0.42))
                .frame(height: FormaBorderWidth.thin)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            if let onBackToDashboard {
                backButton(action: onBackToDashboard)
            }

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

                periodSelector
            }

            if viewModel.isLoading {
                ProgressView("Analyzing your productivity…")
                    .progressViewStyle(.linear)
                    .tint(.formaSteelBlue)
            }
        }
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Dashboard", systemImage: "chevron.left")
                .font(.formaSmallSemibold)
                .foregroundColor(.formaSteelBlue)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.formaSurfaceFloating.opacity(colorScheme == .dark ? 0.72 : 0.86))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.30 : 0.18),
                            lineWidth: FormaBorderWidth.thin
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("backToDashboardButton")
    }

    private var periodSelector: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            Text("Day").tag(UsagePeriod.day)
            Text("Week").tag(UsagePeriod.week)
            Text("Month").tag(UsagePeriod.month)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 170)
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
                .frame(minHeight: 40)

                Button("Open Pending Files") {
                    viewModel.openPendingReviewQueue()
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 40)

                Button("Create Rule") {
                    viewModel.openRuleBuilder()
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 40)
            }
            .controlSize(.small)
        }
        .padding(FormaSpacing.generous)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.formaBoneWhite.opacity(0.05)
                        : Color.formaBoneWhite.opacity(0.70)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.formaBoneWhite.opacity(0.11)
                        : Color.formaSeparator.opacity(0.38),
                    lineWidth: FormaBorderWidth.thin
                )
        )
    }

    private var gettingStartedChecklistSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Make this dashboard useful")
                .font(.formaBodyBold)
                .foregroundColor(.formaLabel)

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                onboardingStep(
                    title: "Scan a working folder",
                    detail: "Forma needs one real pass through Desktop, Downloads, or another working folder."
                )
                onboardingStep(
                    title: "Review and organize a few files",
                    detail: "Approving even a small batch gives the dashboard credible time-saved and storage data."
                )
                onboardingStep(
                    title: "Create one recurring rule",
                    detail: "Analytics becomes more useful once a rule or automation starts doing repeat work."
                )
            }
        }
        .padding(FormaSpacing.generous)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.strong), lineWidth: FormaBorderWidth.thin)
        )
    }

    private func onboardingStep(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: FormaSpacing.tight) {
            Image(systemName: "checkmark.circle.fill")
                .font(.formaSmallSemibold)
                .foregroundColor(.formaSteelBlue)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.formaSmallSemibold)
                    .foregroundColor(.formaLabel)
                Text(detail)
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }
        }
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
                RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                    .fill(Color.formaLabel.opacity(colorScheme == .dark ? 0.16 : 0.08))
                    .frame(width: 24, height: 24)
                RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                    .fill(Color.formaLabel.opacity(colorScheme == .dark ? 0.16 : 0.08))
                    .frame(width: 80, height: 16)
            }

            RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                .fill(Color.formaLabel.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .frame(width: 100, height: 36)

            RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                .fill(Color.formaLabel.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .frame(width: 60, height: 14)
        }
        .padding(FormaSpacing.generous)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(colorScheme == .dark ? Color.formaBoneWhite.opacity(0.045) : Color.formaBoneWhite.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.52 : 0.34), lineWidth: FormaBorderWidth.thin)
        )
    }

    // MARK: - Charts Grid Section

    private var chartsGridSection: some View {
        HStack(alignment: .top, spacing: FormaSpacing.generous) {
            // Left: Storage Treemap
            AnalyticsPanel(eyebrow: "STORAGE", title: "Storage Breakdown") {
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
            AnalyticsPanel(eyebrow: "AUTOMATION", title: "Automation Efficiency") {
                StackedAreaChart(points: viewModel.automationTimeline, chrome: false)
                    .frame(height: 280)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Staleness Heatmap Section

    private var stalenessHeatmapSection: some View {
        AnalyticsPanel(
            eyebrow: "FRESHNESS",
            title: "File Freshness Calendar",
            subtitle: "How fresh are your files? Green = recently used, red = digital dust (6+ months)."
        ) {
            // Horizontal scroll for wide calendar (52 weeks ≈ 800px)
            ScrollView(.horizontal, showsIndicators: false) {
                CalendarHeatmap(data: viewModel.stalenessCalendar, chrome: false) {
                    viewModel.nudgeCleanup()
                }
                .frame(minWidth: 820) // Ensure calendar has room to render
            }
        }
    }

    // MARK: - Smart Insights Section

    private var smartInsightsSection: some View {
        AnalyticsPanel(
            eyebrow: "INSIGHTS",
            title: "Smart Insights",
            trailing: {
                if !viewModel.smartInsights.isEmpty {
                    FormaBadge(
                        text: "\(viewModel.smartInsights.count) suggestion\(viewModel.smartInsights.count == 1 ? "" : "s")",
                        color: .formaSteelBlue,
                        size: .small,
                        style: .subtle
                    )
                }
            }
        ) {
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
    @Environment(\.colorScheme) private var colorScheme

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
                .fill(colorScheme == .dark ? Color.formaBoneWhite.opacity(0.045) : Color.formaBoneWhite.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.52 : 0.34), lineWidth: FormaBorderWidth.thin)
        )
    }
}

// MARK: - Analytics Panel

private struct AnalyticsPanel<Trailing: View, Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String?
    let trailing: Trailing
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.formaCompactMedium)
                        .foregroundColor(.formaTertiaryLabelHigh)
                        .textCase(.uppercase)

                    Text(title)
                        .font(.formaH2)
                        .foregroundColor(.formaLabel)

                    if let subtitle {
                        Text(subtitle)
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }
                }

                Spacer(minLength: FormaSpacing.standard)

                trailing
            }

            content
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSurfaceWork)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(
                    Color.formaSeparator.opacity(colorScheme == .dark ? 0.64 : 0.44),
                    lineWidth: FormaBorderWidth.thin
                )
        )
        .formaShadow(.resting)
    }
}

private extension AnalyticsPanel where Trailing == EmptyView {
    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            trailing: { EmptyView() },
            content: content
        )
    }
}



// MARK: - Preview

#Preview("Productivity Report") {
    // Note: Preview requires a valid ModelContext
    Text("ProductivityReportView requires ModelContext")
        .frame(width: 900, height: 800)
}
