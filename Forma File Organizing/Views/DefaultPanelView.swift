import SwiftUI
import SwiftData

// MARK: - Premium Default Panel View
// Redesigned for Apple Design Award quality
// Features: Circular progress ring, refined insights, clear hierarchy

struct DefaultPanelView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var allPatterns: [LearnedPattern]
    @State private var insights: [FileInsight] = []
    @State private var isStorageExpanded: Bool = false
    @State private var showAllInsights: Bool = false
    @State private var dismissedInsightIDs: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let insightsService = InsightsService.shared

    /// Check if any suggestions (Smart Rules or Quick Actions) are available
    private var hasAnySuggestions: Bool {
        let hasSuggestablePatterns = allPatterns.contains { $0.shouldSuggest }
        let hasVisibleInsights = !visibleInsights.isEmpty
        return hasSuggestablePatterns || hasVisibleInsights
    }

    // MARK: - Debouncing for Insights Generation
    /// Task handle for debounced insight loading - cancels previous pending loads
    @State private var insightLoadTask: Task<Void, Never>?
    /// Debounce interval in seconds (300ms coalesces rapid onChange triggers)
    private let insightDebounceInterval: UInt64 = 300_000_000 // nanoseconds

    var body: some View {
        VStack(spacing: 0) {
            // PINNED HEADER: Greeting + Progress + Primary Action
            VStack(alignment: .leading, spacing: FormaSpacing.large) {
                // Hero Section: Greeting + Progress Bar
                heroSection
                    .padding(.top, FormaSpacing.generous)

                // Primary Action (pinned)
                pinnedPrimaryAction
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.bottom, FormaSpacing.standard)
            .background(.regularMaterial)
            
            // Subtle separator
            Rectangle()
                .fill(Color.formaSeparator.opacity(Color.FormaOpacity.strong))
                .frame(height: 1)
            
            // SCROLLING CONTENT: Automation status bar (top) + Suggestions (primary)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    // Automation Status Bar (slim, at top for visibility)
                    automationStatusSection
                        .padding(.top, FormaSpacing.standard)

                    // Unified Suggestions Section (Smart Rules + Quick Actions)
                    // This is now the PRIMARY focus of the panel
                    suggestionsSection
                        .padding(.top, FormaSpacing.tight)
                }
                .padding(.horizontal, FormaSpacing.generous)
                .padding(.bottom, FormaSpacing.generous)
            }
        }
        .background(Color.clear)
        .onAppear {
            loadInsightsImmediately()
        }
        .onChange(of: dashboardViewModel.allFiles) { _, _ in
            loadInsightsDebounced()
        }
        .onChange(of: dashboardViewModel.recentActivities) { _, _ in
            loadInsightsDebounced()
        }
        .onDisappear {
            // Cancel any pending insight load when view disappears
            insightLoadTask?.cancel()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            let reviewCount = dashboardViewModel.cachedNeedsReviewCount

            if reviewCount > 0 {
                // Active task state with contextual explanation
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    // Current task label
                    Text("CURRENT TASK")
                        .font(.formaCaption)
                        .tracking(0.5)
                        .foregroundStyle(Color.formaTertiaryLabel)

                    // Main headline with contextual count
                    Text("\(reviewCount) \(taskDescription)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Contextual explanation - why these files were chosen
                    Text(taskExplanation)
                        .font(.formaBody)
                        .foregroundStyle(Color.formaSecondaryLabel)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Progress indicator with percentage
                progressSection

                // Clickable category stats
                categoryStatsRow

            } else {
                // All done state
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.formaSage)
                        Text("All Organized")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.formaLabel)
                    }

                    Text("\(greetingText)! Your \(locationDisplayPhrase) is tidy.")
                        .font(.formaBody)
                        .foregroundStyle(Color.formaSecondaryLabel)
                }

                // Progress at 100%
                progressSection

                // Still show category stats for navigation
                categoryStatsRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 2), lineWidth: 1)
        )
    }

    // MARK: - Task Description (Dynamic)

    /// Returns a description of the current task based on file characteristics
    private var taskDescription: String {
        if urgentFilesCount > 0 && urgentFilesCount >= dashboardViewModel.cachedNeedsReviewCount / 2 {
            return "Stale Files"
        } else if dominantCategory != .all {
            return "\(dominantCategory.displayName)"
        } else {
            return "Files to Review"
        }
    }

    /// Returns an explanation of why these files were prioritized
    private var taskExplanation: String {
        let reviewCount = dashboardViewModel.cachedNeedsReviewCount

        if urgentFilesCount > 0 && urgentFilesCount >= reviewCount / 2 {
            return "These files have been \(locationPreposition) your \(locationDisplayPhrase) for over 30 days."
        } else if dominantCategory != .all {
            let categoryCount = dashboardViewModel.filteredStorageAnalytics.fileCountForCategory(dominantCategory)
            return "Mostly \(dominantCategory.displayName.lowercased()) (\(categoryCount) of \(reviewCount))."
        } else {
            return "A mix of file types waiting for organization."
        }
    }

    /// The dominant category in the current file set
    private var dominantCategory: FileTypeCategory {
        let analytics = dashboardViewModel.filteredStorageAnalytics
        let categories: [(FileTypeCategory, Int)] = [
            (.images, analytics.fileCountForCategory(.images)),
            (.documents, analytics.fileCountForCategory(.documents)),
            (.videos, analytics.fileCountForCategory(.videos)),
            (.audio, analytics.fileCountForCategory(.audio)),
            (.archives, analytics.fileCountForCategory(.archives))
        ]

        guard let max = categories.max(by: { $0.1 < $1.1 }),
              max.1 > 0,
              max.1 >= dashboardViewModel.cachedNeedsReviewCount / 2 else {
            return .all
        }
        return max.0
    }

    /// Current folder location name
    private var currentLocationName: String {
        dashboardViewModel.selectedFolder.displayName
    }

    /// Display phrase for location (e.g., "Desktop" or "Documents folder")
    private var locationDisplayPhrase: String {
        switch dashboardViewModel.selectedFolder {
        case .desktop:
            return "Desktop"
        default:
            return "\(currentLocationName) folder"
        }
    }

    /// Preposition for location (e.g., "on" for Desktop, "in" for folders)
    private var locationPreposition: String {
        switch dashboardViewModel.selectedFolder {
        case .desktop:
            return "on"
        default:
            return "in"
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.formaObsidian.opacity(Color.FormaOpacity.light))
                        .frame(height: 6)

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.formaSage.opacity(0.8), Color.formaSage],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * organizationProgress), height: 6)
                }
            }
            .frame(height: 6)

            // Percentage label
            Text("\(Int(organizationProgress * 100))% organized")
                .font(.formaCaption)
                .foregroundStyle(Color.formaTertiaryLabel)
        }
    }

    // MARK: - Category Stats Row (Clickable Filters)

    private var categoryStatsRow: some View {
        let analytics = dashboardViewModel.filteredStorageAnalytics
        let categories: [(FileTypeCategory, Int, String)] = [
            (.images, analytics.fileCountForCategory(.images), "photo"),
            (.documents, analytics.fileCountForCategory(.documents), "doc.text"),
            (.videos, analytics.fileCountForCategory(.videos), "film"),
            (.audio, analytics.fileCountForCategory(.audio), "waveform"),
            (.archives, analytics.fileCountForCategory(.archives), "archivebox")
        ].filter { $0.1 > 0 }

        return Group {
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FormaSpacing.tight) {
                        ForEach(Array(categories.prefix(4)), id: \.0) { category, count, icon in
                            CategoryStatButton(
                                category: category,
                                count: count,
                                icon: icon,
                                isSelected: dashboardViewModel.selectedCategory == category
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if dashboardViewModel.selectedCategory == category {
                                        dashboardViewModel.selectCategory(.all)
                                    } else {
                                        dashboardViewModel.selectCategory(category)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, FormaSpacing.tight)
            }
        }
    }

    // MARK: - Pinned Primary Action
    
    private var pinnedPrimaryAction: some View {
        let readyFiles = dashboardViewModel.filteredFiles.filter { $0.status == .ready }
        
        return Group {
            if !readyFiles.isEmpty {
                Button(action: {
                    dashboardViewModel.organizeAllReadyFiles(context: modelContext)
                }) {
                    Text("Organize \(readyFiles.count) \(readyFiles.count == 1 ? "File" : "Files")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.formaSoftGreen) // Revert to brand green
                .controlSize(.large)
                .help("Organize all ready files")
            }
        }
    }

    // MARK: - Secondary Actions (scrolling)
    // NOTE: Create Rule button removed - duplicate of sidebar button (both call showRuleBuilderPanel)
    // NOTE: Review Files link removed - duplicate of Pending toggle in toolbar

    private var secondaryActionsSection: some View {
        EmptyView()
    }

    // MARK: - Automation Status Section (v1.5 - Promoted to status bar)

    @ViewBuilder
    private var automationStatusSection: some View {
        // Only show if at least one automation feature is enabled
        let showAutomation = FeatureFlagService.shared.isEnabled(.backgroundMonitoring) ||
                             FeatureFlagService.shared.isEnabled(.autoOrganize)

        if showAutomation {
            AutomationStatusWidget()
        }
    }

    // MARK: - Secondary Actions (deprecated in v1.5)
    // NOTE: Removed - these were duplicates of sidebar actions

    // MARK: - Unified Suggestions Section
    // Combines Smart Rules (learned patterns) and Quick Actions (file insights)
    // under a single mental model for users

    @ViewBuilder
    private var suggestionsSection: some View {
        if hasAnySuggestions {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                // Unified section header
                Text("SUGGESTIONS")
                    .font(.formaBodySemibold)
                    .tracking(0.5)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .padding(.top, FormaSpacing.tight)

                // Smart Rules (learned patterns) - self-hides when empty
                smartRulesSection

                // Quick Actions (file insights) - self-hides when empty or all dismissed
                if !visibleInsights.isEmpty {
                    quickActionsSection(insight: visibleInsights.first!)
                }
            }
        }
    }

    // MARK: - Smart Rules Section (Learned Patterns)

    @ViewBuilder
    private var smartRulesSection: some View {
        RuleSuggestionView(
            onCreateRule: { pattern in
                dashboardViewModel.createRuleFromPattern(pattern, context: modelContext)
            },
            onDismiss: { pattern in
                // Pattern already records rejection in RuleSuggestionView
                // Just need to save the context
                do {
                    try modelContext.save()
                } catch {
                    Log.error("DefaultPanelView: Failed to save pattern dismissal - \(error.localizedDescription)", category: .analytics)
                }
            }
        )
    }
    
    // MARK: - Quick Actions (one-time file grouping suggestions)

    /// Filtered insights excluding dismissed suggestions
    private var visibleInsights: [FileInsight] {
        insights.filter { !dismissedInsightIDs.contains($0.id.uuidString) }
    }

    private func quickActionsSection(insight: FileInsight) -> some View {
        // Get visible insights (excluding dismissed)
        let visible = visibleInsights

        return VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Sub-section label (lighter weight than main header)
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "bolt.fill")
                    .font(.formaCaption)
                Text("Quick Actions")
                    .font(.formaCompactMedium)
            }
            .foregroundStyle(Color.formaTertiaryLabel)

            // Single prominent insight card (first visible)
            if let topInsight = visible.first {
                QuickActionCard(
                    insight: topInsight,
                    action: { dashboardViewModel.showRuleBuilderPanel() },
                    onDismiss: { dismissedInsightIDs.insert(topInsight.id.uuidString) }
                )
            }

            // Additional insights (if expanded)
            if showAllInsights {
                ForEach(visible.dropFirst()) { visibleInsight in
                    QuickActionCard(
                        insight: visibleInsight,
                        action: { dashboardViewModel.showRuleBuilderPanel() },
                        onDismiss: { dismissedInsightIDs.insert(visibleInsight.id.uuidString) }
                    )
                }
            }

            // "See more" / "See less" toggle - prominent button style (use visible count)
            if visible.count > 1 {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAllInsights.toggle()
                    }
                }) {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: showAllInsights ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))

                        Text(showAllInsights ? "Show Less" : "See \(visible.count - 1) More Suggestions")
                            .font(.formaSmallSemibold)

                        Spacer()

                        // Count badge
                        Text("\(visible.count - 1)")
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaSteelBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                            )
                    }
                    .foregroundStyle(Color.formaSteelBlue)
                    .padding(FormaSpacing.standard)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.ultraSubtle * 2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.ultraSubtle * 4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, FormaSpacing.tight)
            }
        }
    }

    // MARK: - Computed Properties

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var organizationProgress: Double {
        let total = totalFilesCount + organizedFilesCount
        guard total > 0 else { return 1.0 }
        return Double(organizedFilesCount) / Double(total)
    }

    private var totalFilesCount: Int {
        dashboardViewModel.allFilesCount
    }

    private var organizedFilesCount: Int {
        dashboardViewModel.allFiles.filter { $0.status == .completed }.count
    }

    private var readyFilesCount: Int {
        dashboardViewModel.filteredFiles.filter { $0.status == .ready }.count
    }

    private var urgentFilesCount: Int {
        dashboardViewModel.allFiles.filter { file in
            let daysSince = Calendar.current.dateComponents([.day], from: file.creationDate, to: Date()).day ?? 0
            return daysSince > 30 && file.status != .completed
        }.count
    }

    // MARK: - Insight Loading

    /// Load insights on appear - uses async to avoid blocking main thread
    private func loadInsightsImmediately() {
        Task {
            let newInsights = await insightsService.generateInsights(
                from: dashboardViewModel.allFiles,
                activities: dashboardViewModel.recentActivities,
                rules: []
            )
            await MainActor.run {
                insights = newInsights
            }
        }
    }

    /// Load insights with debouncing (used on data changes)
    /// Cancels any pending load and waits for debounce interval before executing
    /// Uses async version with parallel execution for better performance
    private func loadInsightsDebounced() {
        // Cancel any existing pending task
        insightLoadTask?.cancel()

        // Create new debounced task
        insightLoadTask = Task {
            // Wait for debounce interval
            try? await Task.sleep(nanoseconds: insightDebounceInterval)

            // Check if cancelled during sleep
            guard !Task.isCancelled else { return }

            // Generate insights using async version (runs expensive ops in parallel, off main thread)
            let newInsights = await insightsService.generateInsights(
                from: dashboardViewModel.allFiles,
                activities: dashboardViewModel.recentActivities,
                rules: []
            )

            // Update state on main thread if not cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    insights = newInsights
                }
            }
        }
    }
}

// MARK: - Quick Action Card (one-time file organization action)

struct QuickActionCard: View {
    let insight: FileInsight
    let action: () -> Void
    var onDismiss: (() -> Void)?

    @State private var isHovered = false
    @State private var isDismissHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header: Icon + Message + Dismiss
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                // Icon with category background
                ZStack {
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .fill(insight.categoryColor.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle))
                        .frame(width: 44, height: 44)

                    Image(systemName: insight.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(insight.categoryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.message)
                        .font(.formaBodyMedium)
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Contextual detail line
                    if let detail = insight.detail {
                        Text(detail)
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaSecondaryLabel)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Dismiss button (X)
                if let onDismiss {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(
                                isDismissHovered
                                    ? Color.formaLabel
                                    : Color.formaSecondaryLabel
                            )
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(
                                        isDismissHovered
                                            ? Color.formaObsidian.opacity(Color.FormaOpacity.light)
                                            : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 2)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.1)) {
                            isDismissHovered = hovering
                        }
                    }
                    .help("Dismiss this suggestion")
                }
            }

            // Action buttons row
            if let actionLabel = insight.actionLabel {
                HStack(spacing: FormaSpacing.tight) {
                    // Primary action
                    Button(action: action) {
                        HStack(spacing: 6) {
                            Text(actionLabel)
                                .font(.formaSmallSemibold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.formaSteelBlue)
                        .padding(.horizontal, FormaSpacing.standard)
                        .padding(.vertical, FormaSpacing.tight)
                        .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .pressAnimation()

                    Spacer()

                    // Secondary dismiss as text button
                    if onDismiss != nil {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                onDismiss?()
                            }
                        } label: {
                            Text("Ignore")
                                .font(.formaSmall)
                                .foregroundStyle(Color.formaTertiaryLabel)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(
                    isHovered
                        ? Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 2)
                        : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaObsidian.opacity(isHovered ? 0.1 : 0.06), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}


// MARK: - Category Stat Button (Clickable Filter)

struct CategoryStatButton: View {
    let category: FileTypeCategory
    let count: Int
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    /// Category-specific accent color
    private var categoryColor: Color {
        switch category {
        case .images: return .formaWarmOrange
        case .documents: return .formaMutedBlue
        case .videos: return .formaSteelBlue
        case .audio: return .formaSage
        case .archives: return .formaSoftGreen
        case .all: return .formaSteelBlue
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.formaCaption)
                Text("\(count)")
                    .font(.formaCompactSemibold)
            }
            .foregroundStyle(isSelected ? Color.formaBoneWhite : categoryColor)
            .padding(.horizontal, FormaSpacing.tight + 2)
            .padding(.vertical, FormaSpacing.micro + 2)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(
                        isSelected
                            ? categoryColor
                            : (isHovered ? categoryColor.opacity(Color.FormaOpacity.light) : categoryColor.opacity(Color.FormaOpacity.subtle))
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("Filter by \(category.displayName)")
        .accessibilityLabel("\(count) \(category.displayName)")
        .accessibilityHint(isSelected ? "Currently filtered. Tap to show all." : "Tap to filter by \(category.displayName)")
    }
}

// MARK: - Press Animation Modifier

struct PressAnimationModifier: ViewModifier {
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func pressAnimation() -> some View {
        modifier(PressAnimationModifier())
    }
}

// MARK: - FileInsight Extension

extension FileInsight {
    var categoryColor: Color {
        // Map insight type to appropriate color
        switch iconName {
        case "photo.fill", "camera.fill":
            return .formaWarmOrange
        case "doc.fill", "doc.text.fill":
            return .formaMutedBlue
        case "arrow.down.circle.fill":
            return .formaSoftGreen
        default:
            return .formaSteelBlue
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FileItem.self, Rule.self, ActivityItem.self, CustomFolder.self, configurations: config)

    DefaultPanelView()
        .environmentObject(DashboardViewModel())
        .modelContainer(container)
        .frame(width: 340, height: 800)
        .background(.regularMaterial)
}
