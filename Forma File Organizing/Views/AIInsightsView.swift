import SwiftUI
import SwiftData
import Combine

/// Unified view for AI-powered insights and suggestions.
///
/// Combines multiple AI features into a single, organized interface:
/// - Pattern suggestions from user behavior
/// - Duplicate file detection
/// - Project cluster detection
/// - Temporal organization insights
struct AIInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPatterns: [LearnedPattern]

    @StateObject private var viewModel = AIInsightsViewModel()

    var onCreateRule: (LearnedPattern) -> Void
    var onDismissPattern: (LearnedPattern) -> Void

    // Filter patterns for display
    private var suggestablePatterns: [LearnedPattern] {
        sortedPatterns.filter { $0.shouldSuggest && !$0.isNegativePattern }
    }

    private var negativePatterns: [LearnedPattern] {
        sortedPatterns.filter { $0.isNegativePattern }
    }

    private var sortedPatterns: [LearnedPattern] {
        allPatterns.sorted { $0.confidenceScore > $1.confidenceScore }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FormaSpacing.huge) {
                // Header
                header

                // Quick stats
                statsOverview

                // Tab selector
                tabSelector

                // Content based on selected tab
                contentForSelectedTab
            }
            .padding(.vertical, FormaSpacing.large)
        }
        .background(Color.formaBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Insights")
                    .font(.formaH1)
                    .foregroundColor(.formaLabel)

                Text("Smart suggestions based on your file organization behavior")
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()

            // Refresh button
            Button(action: viewModel.refreshInsights) {
                Image(systemName: "arrow.clockwise")
                    .font(.formaBody)
                    .foregroundColor(.formaSteelBlue)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, FormaSpacing.large)
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: FormaSpacing.large) {
            StatCard(
                icon: "wand.and.stars",
                value: "\(suggestablePatterns.count)",
                label: "Suggestions",
                color: .formaSteelBlue
            )

            StatCard(
                icon: "doc.on.doc.fill",
                value: "\(viewModel.duplicateGroups.count)",
                label: "Duplicate Groups",
                color: .formaWarmOrange
            )

            StatCard(
                icon: "folder.badge.gearshape",
                value: "\(viewModel.projectClusters.count)",
                label: "Projects Detected",
                color: .formaSage
            )

            StatCard(
                icon: "xmark.shield.fill",
                value: "\(negativePatterns.count)",
                label: "Anti-Patterns",
                color: .formaTertiaryLabel
            )
        }
        .padding(.horizontal, FormaSpacing.large)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AIInsightsViewModel.Tab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.displayName,
                    icon: tab.iconName,
                    isSelected: viewModel.selectedTab == tab,
                    badgeCount: badgeCount(for: tab)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedTab = tab
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(Color.formaControlBackground)
        )
        .padding(.horizontal, FormaSpacing.large)
    }

    private func badgeCount(for tab: AIInsightsViewModel.Tab) -> Int {
        switch tab {
        case .suggestions: return suggestablePatterns.count
        case .duplicates: return viewModel.duplicateGroups.count
        case .projects: return viewModel.projectClusters.count
        case .learned: return negativePatterns.count
        case .mlPredictions: return viewModel.mlModelMetadata != nil ? 1 : 0
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var contentForSelectedTab: some View {
        switch viewModel.selectedTab {
        case .suggestions:
            suggestionsContent

        case .duplicates:
            duplicatesContent

        case .projects:
            projectsContent

        case .learned:
            learnedContent
            
        case .mlPredictions:
            mlPredictionsContent
        }
    }

    // MARK: - Suggestions Tab

    private var suggestionsContent: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            if suggestablePatterns.isEmpty {
                EmptyTabState(
                    icon: "sparkles",
                    title: "No suggestions yet",
                    message: "Keep organizing files manually and I'll learn your patterns"
                )
            } else {
                ForEach(suggestablePatterns) { pattern in
                    PatternSuggestionCard(
                        pattern: pattern,
                        onCreateRule: {
                            onCreateRule(pattern)
                        },
                        onDismiss: {
                            pattern.recordRejection()
                            onDismissPattern(pattern)
                            do {
                                try modelContext.save()
                            } catch {
                                Log.error("AIInsightsView: Failed to save pattern dismissal - \(error.localizedDescription)", category: .analytics)
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, FormaSpacing.large)
    }

    // MARK: - Duplicates Tab

    private var duplicatesContent: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            if viewModel.duplicateGroups.isEmpty {
                EmptyTabState(
                    icon: "checkmark.circle.fill",
                    title: "No duplicates found",
                    message: "Your files are well-organized with no duplicate content detected"
                )
            } else {
                DuplicateGroupsView(
                    groups: viewModel.duplicateGroups,
                    onKeepFile: { file, group in
                        viewModel.keepFile(file, in: group)
                    },
                    onRemoveFile: { file, group in
                        viewModel.removeFile(file, from: group)
                    },
                    onDismissGroup: { group in
                        viewModel.dismissGroup(group)
                    }
                )
            }
        }
    }

    // MARK: - Projects Tab

    private var projectsContent: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            if viewModel.projectClusters.isEmpty {
                EmptyTabState(
                    icon: "folder.badge.gearshape",
                    title: "No projects detected",
                    message: "Add more files to detect project clusters"
                )
            } else {
                ForEach(viewModel.projectClusters) { cluster in
                    ProjectClusterCard(cluster: cluster)
                }
            }
        }
        .padding(.horizontal, FormaSpacing.large)
    }

    // MARK: - Learned Tab

    private var learnedContent: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Description
            Text("Anti-patterns are learned from your rejections. Forma won't suggest these destinations for matching files.")
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .padding(.bottom, FormaSpacing.tight)

            if negativePatterns.isEmpty {
                EmptyTabState(
                    icon: "xmark.shield",
                    title: "No anti-patterns learned",
                    message: "When you reject suggestions, patterns are learned to avoid repeating mistakes"
                )
            } else {
                ForEach(negativePatterns) { pattern in
                    NegativePatternCard(pattern: pattern)
                }
            }
        }
        .padding(.horizontal, FormaSpacing.large)
    }
    
    // MARK: - ML Predictions Tab
    
    private var mlPredictionsContent: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.large) {
            // ML Enable/Disable Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Machine Learning Predictions")
                        .font(.formaH3)
                        .foregroundColor(.formaLabel)
                    
                    Text("Use on-device ML to predict file destinations based on your history")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.mlEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(FormaSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(Color.formaControlBackground)
            )
            
            if let metadata = viewModel.mlModelMetadata {
                // Model metadata
                MLModelMetadataCard(metadata: metadata)
            } else {
                EmptyTabState(
                    icon: "brain",
                    title: "No ML Model Trained",
                    message: "Keep organizing files to build enough training data for ML predictions"
                )
            }
        }
        .padding(.horizontal, FormaSpacing.large)
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: FormaSpacing.tight) {
            Image(systemName: icon)
                .font(.formaH2)
                .foregroundColor(color)

            Text(value)
                .font(.formaH2)
                .foregroundColor(.formaLabel)

            Text(label)
                .font(.formaCaption)
                .foregroundColor(.formaSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(color.opacity(Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(color.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
    }
}

private struct MLModelMetadataCard: View {
    let metadata: DestinationModelMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.large) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.formaH1)
                    .foregroundColor(.formaSteelBlue)
                
                VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                    Text("Model v\(metadata.version)")
                        .font(.formaH3)
                        .foregroundColor(.formaLabel)
                    
                    Text(formattedDate(metadata.trainedAt))
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }
                
                Spacer()
                
                // Status badge
                if metadata.isActive {
                    Text("ACTIVE")
                        .font(.formaCaption.bold())
                        .foregroundColor(.formaSage)
                        .padding(.horizontal, FormaSpacing.tight)
                        .padding(.vertical, FormaSpacing.micro)
                        .background(
                            Capsule()
                                .fill(Color.formaSage.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle))
                        )
                }
            }
            
            Divider()
            
            // Metrics grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FormaSpacing.standard) {
                MetricRow(label: "Training Examples", value: "\(metadata.exampleCount)")
                MetricRow(label: "Destinations", value: "\(metadata.labelCount)")
                MetricRow(label: "Accuracy", value: String(format: "%.1f%%", metadata.accuracy * 100))
                MetricRow(label: "Status", value: metadata.isActive ? "Active" : "Inactive")
            }
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaControlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.medium), lineWidth: 1)
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Trained " + formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
            
            Spacer()
            
            Text(value)
                .font(.formaBodyBold)
                .foregroundColor(.formaLabel)
        }
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                Image(systemName: icon)
                    .font(.formaCompact)

                Text(title)
                    .font(.formaBodyMedium)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.formaCaptionSemibold)
                        .foregroundColor(isSelected ? .formaBoneWhite : .formaSteelBlue)
                        .padding(.horizontal, FormaSpacing.tight - (FormaSpacing.micro / 2))
                        .padding(.vertical, FormaSpacing.micro / 2)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                        ? Color.formaBoneWhite.opacity(Color.FormaOpacity.overlay)
                                        : Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
                                )
                        )
                }
            }
            .foregroundColor(isSelected ? .formaBoneWhite : .formaSecondaryLabel)
            .padding(.horizontal, FormaSpacing.large)
            .padding(.vertical, FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control - (FormaRadius.micro / 2), style: .continuous)
                    .fill(isSelected ? Color.formaSteelBlue : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyTabState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: FormaSpacing.standard) {
            Image(systemName: icon)
                .font(.formaIcon)
                .foregroundColor(.formaTertiaryLabel)

            Text(title)
                .font(.formaH3)
                .foregroundColor(.formaLabel)

            Text(message)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FormaSpacing.huge)
    }
}

private struct PatternSuggestionCard: View {
    let pattern: LearnedPattern
    let onCreateRule: () -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Icon
            Image(systemName: FileTypeCategory.category(for: pattern.fileExtension).iconName)
                .font(.formaH2)
                .foregroundColor(FileTypeCategory.category(for: pattern.fileExtension).color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(FileTypeCategory.category(for: pattern.fileExtension).color.opacity(Color.FormaOpacity.light))
                )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.patternDescription)
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaLabel)
                    .lineLimit(2)

                HStack(spacing: FormaSpacing.tight) {
                    // Confidence badge
                    ConfidenceBadge(score: pattern.confidenceScore, matchReason: nil)

                    Text("•")
                        .foregroundColor(.formaTertiaryLabel)

                    Text("\(pattern.occurrenceCount) times")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)

                    // Show if multi-condition
                    if pattern.conditions.count > 1 {
                        Text("•")
                            .foregroundColor(.formaTertiaryLabel)

                        Text("\(pattern.conditions.count) conditions")
                            .font(.formaCaption)
                            .foregroundColor(.formaSteelBlue)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: FormaSpacing.tight) {
                Button(action: onCreateRule) {
                    Text("Create Rule")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaBoneWhite)
                        .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
                        .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
                        .background(
                            Capsule()
                                .fill(Color.formaSteelBlue)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.formaCompact)
                        .foregroundColor(.formaTertiaryLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(
                    isHovered
                        ? Color.formaBoneWhite.opacity(Color.FormaOpacity.prominent)
                        : Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle), radius: 4, x: 0, y: 2)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct ProjectClusterCard: View {
    let cluster: ProjectCluster

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: "folder.badge.gearshape")
                .font(.formaH2)
                .foregroundColor(.formaSage)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.formaSage.opacity(Color.FormaOpacity.light))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.suggestedFolderName)
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaLabel)

                Text("\(cluster.filePaths.count) related files")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()

            Text(cluster.clusterType.rawValue.capitalized)
                .font(.formaCaption)
                .foregroundColor(.formaSage)
                .padding(.horizontal, FormaSpacing.tight)
                .padding(.vertical, FormaSpacing.micro)
                .background(
                    Capsule()
                        .fill(Color.formaSage.opacity(Color.FormaOpacity.light))
                )
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
}

private struct NegativePatternCard: View {
    let pattern: LearnedPattern

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: "xmark.shield.fill")
                .font(.formaH2)
                .foregroundColor(.formaTertiaryLabel)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.formaTertiaryLabel.opacity(Color.FormaOpacity.light))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.patternDescription)
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaLabel)

                Text("Rejected \(pattern.rejectionCount) times")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong - Color.FormaOpacity.light))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.overlay), lineWidth: 1)
        )
    }
}

// MARK: - View Model

@MainActor
class AIInsightsViewModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case suggestions
        case duplicates
        case projects
        case learned
        case mlPredictions

        var displayName: String {
            switch self {
            case .suggestions: return "Suggestions"
            case .duplicates: return "Duplicates"
            case .projects: return "Projects"
            case .learned: return "Learned"
            case .mlPredictions: return "ML Predictions"
            }
        }

        var iconName: String {
            switch self {
            case .suggestions: return "wand.and.stars"
            case .duplicates: return "doc.on.doc"
            case .projects: return "folder.badge.gearshape"
            case .learned: return "brain.head.profile"
            case .mlPredictions: return "cpu.fill"
            }
        }
    }

    @Published var selectedTab: Tab = .suggestions
    @Published var isLoading = false
    @Published var duplicateGroups: [DuplicateDetectionService.DuplicateGroup] = []
    @Published var projectClusters: [ProjectCluster] = []
    @Published var mlModelMetadata: DestinationModelMetadata?
    @Published var mlEnabled = true

    private let duplicateService = DuplicateDetectionService()
    private let contextService = ContextDetectionService()
    private var refreshTask: Task<Void, Never>?

    func refreshInsights() {
        // Cancel any previous refresh in progress
        refreshTask?.cancel()
        isLoading = true

        // In a real implementation, this would fetch fresh data
        // For now, we'll use mock data after a brief delay
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Check if task was cancelled during sleep
            guard !Task.isCancelled else {
                await MainActor.run { self.isLoading = false }
                return
            }

            await MainActor.run {
                self.duplicateGroups = DuplicateDetectionService.DuplicateGroup.mocks
                self.projectClusters = ProjectCluster.mocks
                self.isLoading = false
            }
        }
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func keepFile(_ file: FileItem, in group: DuplicateDetectionService.DuplicateGroup) {
        // Mark file as kept, remove others
        Log.debug("Keep duplicate file: \\(file.name)", category: .analytics)
    }

    func removeFile(_ file: FileItem, from group: DuplicateDetectionService.DuplicateGroup) {
        // Remove the file
        Log.debug("Remove duplicate file: \\(file.name)", category: .analytics)
    }

    func dismissGroup(_ group: DuplicateDetectionService.DuplicateGroup) {
        duplicateGroups.removeAll { $0.id == group.id }
    }
}

// MARK: - Preview

@MainActor
private enum AIInsightsViewPreview {
    static func make() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: LearnedPattern.self, ProjectCluster.self,
            configurations: config
        )

        LearnedPattern.mocks.forEach { container.mainContext.insert($0) }

        return AIInsightsView(
            onCreateRule: { pattern in
                Log.debug("Preview create rule for: \\(pattern.patternDescription)", category: .analytics)
            },
            onDismissPattern: { pattern in
                Log.debug("Preview dismissed pattern: \\(pattern.patternDescription)", category: .analytics)
            }
        )
        .modelContainer(container)
        .frame(width: 700, height: 800)
    }
}

#Preview {
    AIInsightsViewPreview.make()
}
