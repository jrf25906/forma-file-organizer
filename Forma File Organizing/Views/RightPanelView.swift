import SwiftUI
import SwiftData

struct RightPanelView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var panelTransition

    // MARK: - Mode Header Properties

    /// Whether to show the mode header (hidden in default mode)
    private var showModeHeader: Bool {
        if case .default = dashboardViewModel.rightPanelMode {
            return false
        }
        return true
    }

    /// Icon for current panel mode
    private var modeIcon: String {
        switch dashboardViewModel.rightPanelMode {
        case .default: return "house"
        case .inspector: return "doc.text.magnifyingglass"
        case .ruleBuilder: return "wand.and.stars"
        case .celebration: return "party.popper"
        case .completionCelebration: return "party.popper.fill"
        case .analytics: return "chart.pie.fill"
        }
    }

    /// Title for current panel mode
    private var modeTitle: String {
        switch dashboardViewModel.rightPanelMode {
        case .default: return "Dashboard"
        case .inspector(let files):
            return files.count == 1 ? "File Details" : "\(files.count) Files"
        case .ruleBuilder(let rule, _):
            return rule == nil ? "New Rule" : "Edit Rule"
        case .celebration: return "Success!"
        case .completionCelebration: return "All Done!"
        case .analytics: return "Analytics"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Traffic lights clearance (matches other panels)
            Color.clear.frame(height: FormaSpacing.Toolbar.topOffset)

            // Mode indicator header (visible in non-default modes)
            if showModeHeader {
                panelModeHeader

                Divider()
                    .foregroundColor(Color.formaSeparator.opacity(Color.FormaOpacity.overlay))
            }

            // Panel content
            Group {
                switch dashboardViewModel.rightPanelMode {
                case .default:
                    DefaultPanelView()
                        .matchedGeometryEffect(id: "panel", in: panelTransition)
                        .transition(.opacity)

                case .inspector(let files):
                    FileInspectorView(files: files)
                        .matchedGeometryEffect(id: "panel", in: panelTransition)
                        .transition(.opacity)

                case .celebration(let message):
                    CelebrationView(message: message)
                        .matchedGeometryEffect(id: "panel", in: panelTransition)
                        .transition(.opacity)

                case .completionCelebration(let filesOrganized):
                    CompletionCelebrationView(filesOrganized: filesOrganized)
                        .matchedGeometryEffect(id: "panel", in: panelTransition)
                        .transition(.opacity)

                case .ruleBuilder(let editingRule, let fileContext):
                    InlineRuleBuilderView(editingRule: editingRule, fileContext: fileContext)
                        .matchedGeometryEffect(id: "panel", in: panelTransition)
                        .transition(.opacity)
                case .analytics:
                    CompactAnalyticsPanel()
                        .matchedGeometryEffect(id: "panel", in: panelTransition)
                        .transition(.opacity)
                }
            }
        }
        .background(
            Material.regular
        )
        .clipShape(RoundedRectangle(cornerRadius: FormaLayout.RightPanel.cornerRadius, style: .continuous))
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 12,
            x: 0,
            y: 4
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaLayout.RightPanel.cornerRadius, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
        .animation(
            reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85),
            value: dashboardViewModel.rightPanelMode
        )
    }

    // MARK: - Mode Header View

    /// Header showing current mode with back navigation
    @ViewBuilder
    private var panelModeHeader: some View {
        HStack(spacing: 12) {
            // Back to dashboard button
            Button(action: {
                dashboardViewModel.returnToDefaultPanel()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.formaSmallSemibold)
                    Text("Dashboard")
                        .font(.formaCompactMedium)
                }
                .foregroundColor(.formaSteelBlue)
            }
            .buttonStyle(.plain)
            .help("Return to Dashboard")

            Spacer()

            // Current mode indicator
            HStack(spacing: 6) {
                Image(systemName: modeIcon)
                    .font(.formaSmall)
                Text(modeTitle)
                    .font(.formaCompactMedium)
            }
            .foregroundColor(.formaSecondaryLabel)
        }
        .padding(.horizontal, FormaLayout.Gutters.rightPanel)
        .padding(.vertical, FormaSpacing.tight + (FormaSpacing.micro / 2))
        .background(Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle))
    }
}

// MARK: - Compact Analytics Panel

// MARK: - Analytics Actions Panel
private struct CompactAnalyticsPanel: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @State private var healthScore: StorageHealthScore?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                Text("Opportunities")
                    .font(.formaH3)
                    .foregroundColor(.formaObsidian)
                Spacer()
                if isLoading {
                    ProgressView()
                    .controlSize(.small)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.formaSmall)
                    .foregroundColor(.formaError)
            } else if let health = healthScore {
                if health.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.formaSoftGreen)
                        Text("All optimized!")
                            .font(.formaBody)
                            .foregroundColor(.formaObsidian)
                        Text("Great job keeping your files organized.")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                    .padding(FormaSpacing.large)
                    .frame(maxWidth: .infinity)
                    .background(Color.formaControlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                } else {
                    ScrollView {
                        VStack(spacing: FormaSpacing.standard) {
                            ForEach(health.recommendations) { recommendation in
                                RecommendationCard(recommendation: recommendation)
                            }
                        }
                    }
                }
            } else {
                Text("Insights will appear after the next snapshot.")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
            }
        }
        .padding(FormaSpacing.large)
        .task {
            await loadInsights()
        }
    }

    @MainActor
    private func loadInsights() async {
        guard services.featureFlags.isEnabled(.analyticsAndInsights) else {
            errorMessage = "Analytics disabled"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Ensure snapshot is recorded
            try await services.analyticsService.recordDailySnapshotIfNeeded(container: modelContext.container)
            
            // Load only the summary to get fresh health score
            let summary = try await services.analyticsService.loadAnalyticsSummary(for: .week, container: modelContext.container)
            self.healthScore = summary.healthScore
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RecommendationCard: View {
    let recommendation: OptimizationRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.formaSteelBlue)
                    .font(.formaBody)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.title)
                        .font(.formaBodyBold)
                        .foregroundColor(.formaObsidian)
                    
                    Text(recommendation.detail)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                        .lineLimit(3)
                }
            }
            
            // Placeholder for future "Fix it" action
            Button("Review") {
                // Future: Navigate to relevant filter/view
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.formaSteelBlue)
            .padding(.leading, 24) // Indent to align with text
        }
        .padding(FormaSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle), radius: 4, x: 0, y: 2)
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
