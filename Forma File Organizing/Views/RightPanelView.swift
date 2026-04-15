import SwiftUI
import SwiftData

struct RightPanelView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject private var panelStateManager: PanelStateManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var panelTransition

    private var defaultPanelTopAlignmentOffset: CGFloat {
        FormaSpacing.Toolbar.topOffset + FormaSpacing.tight
    }

    // MARK: - Mode Header Properties

    /// Whether to show the mode header (hidden in default mode)
    private var showModeHeader: Bool {
        if case .default = panelStateManager.rightPanelMode {
            return false
        }
        return true
    }

    /// Icon for current panel mode
    private var modeIcon: String {
        switch panelStateManager.rightPanelMode {
        case .default: return "house"
        case .inspector: return "doc.text.magnifyingglass"
        case .rulesManagement: return "list.bullet.rectangle"
        case .ruleBuilder: return "wand.and.stars"
        case .celebration: return "party.popper"
        case .completionCelebration: return "party.popper.fill"
        case .analytics: return "chart.pie.fill"
        }
    }

    /// Title for current panel mode
    private var modeTitle: String {
        switch panelStateManager.rightPanelMode {
        case .default: return "Dashboard"
        case .inspector(let files):
            return files.count == 1 ? "File Details" : "\(files.count) Files"
        case .rulesManagement: return "Smart Rules"
        case .ruleBuilder(let rule, _):
            return rule == nil ? "New Rule" : "Edit Rule"
        case .celebration: return "Success!"
        case .completionCelebration: return "All Done!"
        case .analytics: return "Analytics"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let panelLayout = RightPanelLayout(width: proxy.size.width)

            VStack(spacing: 0) {
                // Mode indicator header (visible in non-default modes)
                if showModeHeader {
                    panelModeHeader(layout: panelLayout)

                    Divider()
                        .foregroundColor(Color.formaSeparator.opacity(Color.FormaOpacity.overlay))
                }

                // Panel content
                Group {
                    switch panelStateManager.rightPanelMode {
                    case .default:
                        DefaultPanelView()
                            .padding(.top, -defaultPanelTopAlignmentOffset)
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

                    case .rulesManagement:
                        RulesManagementView()
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
            .environment(\.rightPanelLayout, panelLayout)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                PaneMaterialBackground(role: .inspector)
                    .ignoresSafeArea(edges: .top)
            )
            .animation(
                reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85),
                value: panelStateManager.rightPanelMode
            )
        }
    }

    // MARK: - Mode Header View

    /// Header showing current mode with back navigation
    @ViewBuilder
    private func panelModeHeader(layout: RightPanelLayout) -> some View {
        Group {
            if layout.isCompact {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    panelModeBackButton
                        .frame(maxWidth: .infinity, alignment: .leading)

                    panelModeIndicator
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 12) {
                    panelModeBackButton

                    Spacer(minLength: FormaSpacing.tight)

                    panelModeIndicator
                }
            }
        }
        .padding(.horizontal, FormaLayout.Gutters.rightPanel)
        .padding(.vertical, FormaSpacing.tight + (FormaSpacing.micro / 2))
        .background(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
    }

    private var panelModeBackButton: some View {
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
            )
        }
        .buttonStyle(.plain)
        .help("Return to Dashboard")
    }

    private var panelModeIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: modeIcon)
                .font(.formaSmall)
            Text(modeTitle)
                .font(.formaSmallSemibold)
        }
        .foregroundColor(.formaLabel)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
}

// MARK: - Compact Analytics Panel

// MARK: - Analytics Actions Panel
private struct CompactAnalyticsPanel: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @State private var healthScore: StorageHealthScore?
    @State private var folderHealthEvaluation: FolderHealthEvaluation = .empty
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                Text("Opportunities")
                    .font(.formaH3)
                    .foregroundColor(.formaLabel)
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
                if health.recommendations.isEmpty && !folderHealthEvaluation.hasActiveAlerts {
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.formaSoftGreen)
                        Text("All optimized!")
                            .font(.formaBody)
                            .foregroundColor(.formaLabel)
                        Text("Great job keeping your files organized.")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }
                    .padding(FormaSpacing.large)
                    .frame(maxWidth: .infinity)
                    .background(Color.formaControlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                } else {
                    ScrollView {
                        VStack(spacing: FormaSpacing.standard) {
                            ForEach(folderHealthEvaluation.activeAlerts) { alert in
                                FolderHealthAlertCard(alert: alert)
                            }

                            ForEach(health.recommendations) { recommendation in
                                RecommendationCard(recommendation: recommendation)
                            }
                        }
                    }
                }
            } else {
                Text("Insights will appear after the next snapshot.")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }
        }
        .padding(FormaSpacing.large)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compactAnalyticsPanel")
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
            self.folderHealthEvaluation = summary.folderHealthEvaluation
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FolderHealthAlertCard: View {
    let alert: FolderHealthAlert

    private var accentColor: Color {
        .formaWarmOrange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(alignment: .top, spacing: FormaSpacing.tight) {
                Image(systemName: iconName)
                    .foregroundColor(accentColor)
                    .font(.formaBody)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.formaBodyBold)
                        .foregroundColor(.formaLabel)

                    Text(detail)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabelHigh)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(FormaSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(accentColor.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch alert {
        case .folderSize:
            return "externaldrive.badge.exclamationmark"
        case .staleRules:
            return "clock.badge.exclamationmark"
        }
    }

    private var title: String {
        switch alert {
        case .folderSize(let folderAlert):
            return "\(folderAlert.folderType.displayName) over \(formattedBytes(folderAlert.thresholdBytes))"
        case .staleRules(let staleRuleAlert):
            if staleRuleAlert.rules.count == 1, let rule = staleRuleAlert.rules.first {
                return "\"\(rule.ruleName)\" is stale"
            }
            return "\(staleRuleAlert.rules.count) stale rules"
        }
    }

    private var detail: String {
        switch alert {
        case .folderSize(let folderAlert):
            return "Tracked files currently use \(formattedBytes(folderAlert.currentBytes)) in \(folderAlert.folderType.displayName)."
        case .staleRules(let staleRuleAlert):
            if staleRuleAlert.rules.count == 1, let rule = staleRuleAlert.rules.first {
                return "\"\(rule.ruleName)\" hasn't matched in \(staleRuleAlert.thresholdDays) days."
            }
            let names = staleRuleAlert.rules.prefix(3).map(\.ruleName).joined(separator: ", ")
            if staleRuleAlert.rules.count <= 3 {
                return "\(names) have not matched in \(staleRuleAlert.thresholdDays) days."
            }
            return "\(names), and \(staleRuleAlert.rules.count - 3) more, have not matched in \(staleRuleAlert.thresholdDays) days."
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
                        .foregroundColor(.formaLabel)
                    
                    Text(recommendation.detail)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabelHigh)
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
