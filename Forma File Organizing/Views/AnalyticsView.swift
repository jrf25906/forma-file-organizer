import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel
    @Namespace private var periodAnimation

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: AnalyticsViewModel(modelContext: modelContext))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Align with MainContentView's toolbar position (traffic lights clearance)
            Color.clear.frame(height: FormaSpacing.Toolbar.topOffset)
            
            // Pinned Header
            header
                .padding(FormaSpacing.generous)
            
            Divider()
                .opacity(0.5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: FormaSpacing.large) {
                    if let error = viewModel.errorMessage {
                        Text(error)
                        .font(.formaSmall)
                        .foregroundColor(.formaError)
                    }
                    
                    // 1. Usage Statistics (Moved to top)
                    usageSection
                    
                    // 2. Charts Grid (Split view for Breakdown & Trends)
                    HStack(alignment: .top, spacing: FormaSpacing.generous) {
                        // Left: Storage Breakdown
                        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                            Text("Storage Breakdown")
                                 .font(.formaH2)
                                 .foregroundColor(.formaObsidian)

                            if let analytics = viewModel.latestStorageAnalytics {
                                StoragePanel(analytics: analytics, onCategoryTap: { _ in })
                                .frame(width: 320) // Fixed width for consistency
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
                        
                        // Right: Trend Chart
                        trendSection
                        .frame(maxWidth: .infinity)
                    }
                    
                    // 3. Health & Reports
                    HStack(alignment: .top, spacing: FormaSpacing.generous) {
                        healthSection
                        .frame(maxWidth: .infinity)
                        
                        reportSection
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(FormaSpacing.generous)
            }
        }
        .background(Color.clear) // Allow unified window glass to show through
        .onAppear {
            viewModel.onAppear()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(alignment: .center) { // Center alignment for consistent button positioning if added later
                VStack(alignment: .leading, spacing: 2) { // Tighter spacing like RulesManagementView
                    Text("Analytics & Insights")
                    .font(.formaH1)
                    .foregroundColor(.formaObsidian)

                    Text("Track storage trends, usage, and health.")
                    .font(.formaSmall) // Changed from .formaBody to match Rules view subtitle style
                    .foregroundColor(.formaSecondaryLabel)
                }
                Spacer()

                HStack(spacing: 4) { // Match compressionLevel.compact or medium
                    let periods: [(UsagePeriod, String)] = [
                        (.day, "Day"),
                        (.week, "Week"),
                        (.month, "Month")
                    ]
                    
                    ForEach(periods, id: \.0) { period, title in
                        PeriodTab(
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
            
            if viewModel.isLoading {
                ProgressView("Refreshing analytics…")
                .progressViewStyle(.linear)
                .tint(.formaSteelBlue)
            }
            
            if viewModel.hasNewReport {
                HStack {
                    Image(systemName: "sparkles")
                    .foregroundColor(.formaSteelBlue)
                    Text("New weekly report available.")
                    .font(.formaBody)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.dismissNewReportBanner()
                    }
                    .buttonStyle(.borderless)
                }
                .padding(FormaSpacing.standard)
                .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
            }
        }
    }
    
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Title removed to reduce clutter, cards speak for themselves
            if let usage = viewModel.usageStatistics {
                HStack(spacing: FormaSpacing.large) {
                    AnalyticsStatCard(icon: "tray.and.arrow.down.fill", value: "\(usage.filesOrganized)", label: "Files organized", color: Color.formaSteelBlue)
                    AnalyticsStatCard(icon: "square.stack.3d.up.fill", value: "\(usage.bulkOperations)", label: "Bulk operations", color: Color.formaSage)
                    AnalyticsStatCard(icon: "clock.arrow.circlepath", value: timeString(from: usage.timeSavedSeconds), label: "Time saved", color: Color.formaMutedBlue)
                }
            } else {
                AnalyticsEmptyStateView(title: "No usage data", message: "Organize some files to see usage insights.")
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Storage Trends")
            .font(.formaH2)
            .foregroundColor(.formaObsidian)
            
            if viewModel.trendPoints.isEmpty {
                AnalyticsEmptyStateView(title: "No snapshots yet", message: "Snapshots are created daily.")
            } else {
                TrendChart(points: viewModel.trendPoints)
                .frame(minHeight: 320) // Slightly taller to match storage panel
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
    }
    
    private var healthSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Storage Health")
            .font(.formaH2)
            .foregroundColor(.formaObsidian)
            
            if let health = viewModel.healthScore {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    HStack {
                        Text("\(health.score)")
                        .font(.formaHero)
                        .foregroundColor(.formaSteelBlue)
                        Text(health.grade)
                        .font(.formaH3)
                        .foregroundColor(.formaSecondaryLabel)
                    }
                    
                    Divider()
                    
                    ForEach(health.factors, id: \.type) { factor in
                        HStack {
                            Text(factor.type.rawValue.capitalized)
                            .font(.formaBody)
                            Spacer()
                            Text(String(format: "%.0f%%", factor.rawScore * 100))
                            .font(.formaBodyMedium)
                            .foregroundColor(.formaSecondaryLabel)
                        }
                        .padding(.vertical, FormaSpacing.micro)
                    }
                }
                .padding(FormaSpacing.large)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .strokeBorder(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
                )
            } else {
                AnalyticsEmptyStateView(title: "Health not available", message: "Health score appearing soon.")
            }
        }
    }
    
    // Kept report section, moved to bottom right
    private var reportSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Latest Report")
            .font(.formaH2)
            .foregroundColor(.formaObsidian)
            
            if let report = viewModel.latestReport {
                ReportPreviewView(report: report) {
                    let savePanel = NSSavePanel()
                    savePanel.nameFieldStringValue = "Forma-Analytics-Report.pdf"
                    savePanel.allowedContentTypes = [.pdf]
                    if savePanel.runModal() == .OK, let url = savePanel.url {
                        do {
                            try viewModel.exportCurrentReport(to: url)
                        } catch {
                            viewModel.errorMessage = "Failed to export report: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                AnalyticsEmptyStateView(title: "No report yet", message: "Reports generated weekly.")
            }
        }
    }
}

private struct AnalyticsEmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
            Text(title)
                .font(.formaBody)
                .foregroundColor(.formaObsidian)
            Text(message)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(FormaSpacing.large)
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
}

private func timeString(from seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

// MARK: - Period Tab Component

// MARK: - Period Tab Component

private struct PeriodTab: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) { // Text only, no icon
                Text(title)
                    .font(.formaBodyMedium) // Match UnifiedToolbar
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
            .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
            // IMPORTANT: foregroundColor MUST come before background for blending
            .foregroundColor(isSelected ? .formaLabel : .formaSecondaryLabel)
            .background {
                if isSelected {
                    PeriodGlassyBackground(
                        tint: Color.formaSteelBlue,
                        cornerRadius: 999
                    )
                    .matchedGeometryEffect(id: "activePeriod", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

private struct PeriodGlassyBackground: View {
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
