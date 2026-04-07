import Foundation
import SwiftUI
import SwiftData

// MARK: - Premium Default Panel View
// Redesigned for Apple Design Award quality
// Features: Circular progress ring, refined insights, clear hierarchy

struct DefaultPanelView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allPatterns: [LearnedPattern]
    @State private var insights: [FileInsight] = []
    @State private var showAllInsights: Bool = false
    @State private var dismissedInsightIDs: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let isUITesting = CommandLine.arguments.contains("--uitesting")

    private let insightsService = InsightsService.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let automationState = AutomationEngine.shared.state

    /// Check if any suggestions (Smart Rules or Quick Actions) are available
    private var hasAnySuggestions: Bool {
        let hasSuggestablePatterns = allPatterns.contains { $0.shouldSuggest }
        let hasVisibleInsights = !visibleInsights.isEmpty
        let hasExternalReviewPromotion = dashboardViewModel.externalReviewPromotionSuggestion != nil
        return hasSuggestablePatterns || hasVisibleInsights || hasExternalReviewPromotion
    }

    /// Hide right-panel primary CTA when another surface owns primary action or
    /// when the center view is in a non-file workflow.
    private var shouldShowPinnedPrimaryAction: Bool {
        dashboardViewModel.shouldShowDefaultPanelPrimaryAction(
            for: nav.selection,
            hasActiveRuleDraft: nav.hasActiveRuleDraft
        )
    }

    // MARK: - Debouncing for Insights Generation
    /// Task handle for debounced insight loading - cancels previous pending loads
    @State private var insightLoadTask: Task<Void, Never>?
    /// Monotonic sequence to ensure only the latest insight refresh task can apply state.
    @State private var insightLoadSequence: UInt64 = 0
    /// Debounce interval in seconds (300ms coalesces rapid onChange triggers)
    private let insightDebounceInterval: UInt64 = 300_000_000 // nanoseconds

    private var showsAutomationStatusSection: Bool {
        FeatureFlagService.shared.isEnabled(.backgroundMonitoring) ||
            FeatureFlagService.shared.isEnabled(.autoOrganize)
    }

    private var inspectorPrimaryCardFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.09)
            : Color.formaBoneWhite.opacity(0.92)
    }

    private var inspectorSecondaryCardFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.05)
            : Color.formaBoneWhite.opacity(0.78)
    }

    private var inspectorPrimaryCardBorder: Color {
        colorScheme == .dark
            ? Color.formaSage.opacity(0.30)
            : Color.formaSteelBlue.opacity(0.16)
    }

    private var inspectorSecondaryCardBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle)
    }

    private var inspectorCardShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.formaObsidian.opacity(0.07)
    }

    private var projectSpacesFeatureEnabled: Bool {
        FeatureFlagService.shared.isEnabled(.projectSpaces)
    }

    private var activeProjectSpaceDetail: ProjectSpaceDetail? {
        guard projectSpacesFeatureEnabled else { return nil }
        return dashboardViewModel.selectedProjectSpaceDetail
    }

    private var showsProjectSpacesSection: Bool {
        projectSpacesFeatureEnabled && !dashboardViewModel.projectSpaces.isEmpty
    }

    var body: some View {
        panelContent
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
        .onChange(of: dashboardViewModel.detectedClusters.count) { _, _ in
            loadInsightsDebounced()
        }
        .onDisappear {
            // Cancel any pending insight load when view disappears
            insightLoadSequence &+= 1
            insightLoadTask?.cancel()
        }
        .overlay(alignment: .topLeading) {
            if isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("defaultPanelContrastProbe")
                    .accessibilityLabel(
                        "primaryAction=\(String(format: "%.2f", defaultPanelPrimaryActionContrastRatio));ignore=\(String(format: "%.2f", defaultPanelIgnoreContrastRatio))"
                    )
                    .accessibilityValue(
                        "primaryAction=\(String(format: "%.2f", defaultPanelPrimaryActionContrastRatio));ignore=\(String(format: "%.2f", defaultPanelIgnoreContrastRatio))"
                    )
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if let detail = activeProjectSpaceDetail {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    inspectorSectionCard(emphasized: true) {
                        ProjectSpaceDetailView(
                            detail: detail,
                            onBack: {
                                dashboardViewModel.closeProjectSpaceDetail()
                            },
                            onOpenFile: { fileRow in
                                dashboardViewModel.openFileFromProjectSpace(fileRow)
                            }
                        )
                    }
                }
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.top, FormaSpacing.standard)
                .padding(.bottom, FormaSpacing.generous)
            }
        } else {
            dashboardContent
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            inspectorSectionCard(emphasized: true) {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    heroSection

                    if shouldShowPinnedPrimaryAction {
                        pinnedPrimaryAction
                            .guidedTourRegion(.organizeButton)
                    }
                }
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.top, FormaSpacing.standard)
            .padding(.bottom, FormaSpacing.tight)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    if showsProjectSpacesSection {
                        inspectorSectionCard {
                            ProjectSpacesSection(summaries: dashboardViewModel.projectSpaces) { summary in
                                dashboardViewModel.selectProjectSpace(summary)
                            }
                        }
                    }

                    if showsAutomationStatusSection {
                        inspectorSectionCard {
                            automationStatusSection
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("defaultPanelAutomationSection")
                        }
                    }

                    if hasAnySuggestions {
                        inspectorSectionCard {
                            suggestionsSection
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("defaultPanelSuggestionsSection")
                        }
                    }
                }
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.bottom, FormaSpacing.generous)
            }
        }
    }

    private func inspectorSectionCard<Content: View>(
        emphasized: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(emphasized ? FormaSpacing.large : FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(emphasized ? inspectorPrimaryCardFill : inspectorSecondaryCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        emphasized ? inspectorPrimaryCardBorder : inspectorSecondaryCardBorder,
                        lineWidth: emphasized ? 1.1 : 1
                    )
            )
            .shadow(
                color: inspectorCardShadow,
                radius: emphasized ? 10 : 6,
                x: 0,
                y: emphasized ? 3 : 2
            )
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            let reviewCount = dashboardViewModel.cachedNeedsReviewCount
            let currentChunkCount = dashboardViewModel.currentReviewChunkCount

            if reviewCount > 0 {
                if dashboardViewModel.hasDeferredReviewFiles && currentChunkCount == 0 {
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        Text("CURRENT TASK")
                            .font(.formaCaption)
                            .tracking(0.5)
                            .foregroundStyle(currentTaskLabelColor)

                        Text("\(dashboardViewModel.deferredReviewFileCount) Files Set Aside")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("You're done for now. Resume this pass whenever you want to pick it back up.")
                            .font(.formaBodyMedium)
                            .foregroundStyle(currentTaskSubtextColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if currentChunkCount == 0 {
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        Text("CURRENT TASK")
                            .font(.formaCaption)
                            .tracking(0.5)
                            .foregroundStyle(currentTaskLabelColor)

                        Text("No Files in This Filter")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("The current review filters hide the queue. Adjust them to pick the next pass.")
                            .font(.formaBodyMedium)
                            .foregroundStyle(currentTaskSubtextColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        Text("CURRENT TASK")
                            .font(.formaCaption)
                            .tracking(0.5)
                            .foregroundStyle(currentTaskLabelColor)

                        Text("\(taskHeadlineCount) \(taskDescription)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(taskExplanation)
                            .font(.formaBodyMedium)
                            .foregroundStyle(currentTaskSubtextColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                scanPhaseStatusSection

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
                        .font(.formaBodyMedium)
                        .foregroundStyle(currentTaskSubtextColor)
                }

                // Next actions
                HStack(spacing: FormaSpacing.tight) {
                    Button(action: {
                        nav.select(.analytics)
                    }) {
                        HStack(spacing: FormaSpacing.micro) {
                            Image(systemName: "chart.bar")
                                .font(.formaSmallSemibold)
                            Text("View Activity")
                                .font(.formaSmallSemibold)
                        }
                        .foregroundStyle(Color.formaSteelBlue)
                        .padding(.horizontal, FormaSpacing.standard)
                        .padding(.vertical, FormaSpacing.tight)
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        nav.select(.rules)
                    }) {
                        HStack(spacing: FormaSpacing.micro) {
                            Image(systemName: "gearshape")
                                .font(.formaSmallSemibold)
                            Text("Manage Rules")
                                .font(.formaSmallSemibold)
                        }
                        .foregroundStyle(Color.formaSecondaryLabel)
                        .padding(.horizontal, FormaSpacing.standard)
                        .padding(.vertical, FormaSpacing.tight)
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                .fill(Color.formaLabel.opacity(Color.FormaOpacity.subtle))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, FormaSpacing.tight)

                scanPhaseStatusSection

                // Progress at 100%
                progressSection

                // Still show category stats for navigation
                categoryStatsRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("defaultPanelHeroSection")
    }

    // MARK: - Task Description (Dynamic)

    /// Returns a description of the current task based on file characteristics
    private var taskDescription: String {
        if shouldEmphasizeStaleTask {
            return "Stale Files in This Pass"
        } else if dominantCategory != .all {
            return "\(dominantCategory.displayName) in This Pass"
        } else {
            return "Files in This Pass"
        }
    }

    /// Returns an explanation of why these files were prioritized
    private var taskExplanation: String {
        let reviewCount = dashboardViewModel.cachedNeedsReviewCount
        let currentChunkCount = dashboardViewModel.currentReviewChunkCount
        let hiddenCount = max(0, reviewCount - currentChunkCount)

        if shouldEmphasizeStaleTask {
            if hiddenCount > 0 {
                return "These top-level files have been \(locationPreposition) your \(locationDisplayPhrase) for over 30 days. \(hiddenCount) more will wait until this pass is done."
            }
            return "These top-level files have been \(locationPreposition) your \(locationDisplayPhrase) for over 30 days."
        } else if dominantCategory != .all, hiddenCount > 0 {
            return "Showing the next \(currentChunkCount), mostly \(dominantCategory.displayName.lowercased()). \(hiddenCount) more stay tucked away for later."
        } else if dominantCategory != .all {
            return "Mostly \(dominantCategory.displayName.lowercased()) in the current pass."
        } else if hiddenCount > 0 {
            return "Showing the next \(currentChunkCount) now. \(hiddenCount) more stay tucked away until you're ready."
        } else {
            return "A focused pass through what still needs your attention."
        }
    }

    /// Count shown in the primary task headline.
    /// When stale framing is active, show only actionable stale files to avoid
    /// counting nested historical files discovered by recursive scans.
    private var taskHeadlineCount: Int {
        shouldEmphasizeStaleTask ? actionableStaleCount : dashboardViewModel.currentReviewChunkCount
    }

    /// Whether the hero should frame the current task around stale files.
    private var shouldEmphasizeStaleTask: Bool {
        let currentChunkCount = dashboardViewModel.currentReviewChunkCount
        guard currentChunkCount > 0 else { return false }
        return actionableStaleCount > 0 && actionableStaleCount >= max(1, currentChunkCount / 2)
    }

    /// "Stale" files that are still actionable in the primary queue.
    /// We intentionally scope this to top-level items so nested files inside
    /// already-organized subfolders do not dominate the task callout.
    private var actionableStaleCount: Int {
        dashboardViewModel.reviewableFiles.filter { file in

            // Only treat files at the selected root level as "stale task" items.
            let isTopLevel = (file.relativeParentPath?.isEmpty ?? true)
            guard isTopLevel else { return false }

            let daysSince = Calendar.current.dateComponents([.day], from: file.creationDate, to: Date()).day ?? 0
            return daysSince > 30
        }.count
    }

    /// The dominant category in the current file set
    private var dominantCategory: FileTypeCategory {
        let reviewFiles = dashboardViewModel.reviewableFiles
        let categories: [(FileTypeCategory, Int)] = [
            (.images, reviewFiles.filter { $0.category == .images }.count),
            (.documents, reviewFiles.filter { $0.category == .documents }.count),
            (.videos, reviewFiles.filter { $0.category == .videos }.count),
            (.audio, reviewFiles.filter { $0.category == .audio }.count),
            (.archives, reviewFiles.filter { $0.category == .archives }.count)
        ]

        guard let dominant = categories.max(by: { $0.1 < $1.1 }),
              dominant.1 > 0,
              dominant.1 >= Swift.max(1, reviewFiles.count / 2) else {
            return .all
        }
        return dominant.0
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
                        .fill(
                            Color.formaObsidian.opacity(
                                colorScheme == .dark ? 0.38 : 0.14
                            )
                        )
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

            // Progress labels: percentage left, file count right
            HStack {
                HStack(spacing: 3) {
                    Text("\(Int(organizationProgress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("ORGANIZED")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.3)
                }
                .foregroundStyle(progressLabelColor)

                Spacer()

                Text("\(organizedFilesCount) of \(totalFilesCount) organized")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(progressLabelColor)
            }
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
        let readyFiles = dashboardViewModel.reviewableFiles.filter { $0.status == .ready }
        
        return Group {
            if dashboardViewModel.hasDeferredReviewFiles && dashboardViewModel.currentReviewChunkCount == 0 {
                Button(action: {
                    dashboardViewModel.resumeDeferredReviewFiles()
                }) {
                    Text("Resume \(dashboardViewModel.deferredReviewFileCount) Deferred \(dashboardViewModel.deferredReviewFileCount == 1 ? "File" : "Files")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.formaSteelBlue)
                .controlSize(.large)
                .help("Bring back the files you set aside for now")
            } else if !readyFiles.isEmpty {
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

    // MARK: - Automation Status Section (v1.5 - Promoted to status bar)

    @ViewBuilder
    private var automationStatusSection: some View {
        if showsAutomationStatusSection {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                AutomationStatusWidget(
                    pendingReviewCount: dashboardViewModel.cachedNeedsReviewCount
                )

                if let summary = automationState.lastPreflightSummary,
                   shouldShowAutomationPreflight(summary) {
                    automationPreflightCard(summary)
                }

                if let undoSummary = dashboardViewModel.latestUndoableBatchSummary,
                   undoSummary.origin == .automation {
                    automationUndoCard(undoSummary)
                }
            }
        }
    }

    private func automationPreflightCard(_ summary: AutomationPreflightSummary) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "checklist")
                    .font(.formaCompactSemibold)
                    .foregroundStyle(Color.formaSteelBlue)

                Text("Next Automatic Pass")
                    .font(.formaCompactSemibold)
                    .foregroundStyle(Color.formaLabel)
            }

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                automationTrustMetricRow(
                    icon: "checkmark.circle.fill",
                    tint: Color.formaSage,
                    label: "Eligible now",
                    count: summary.eligibleCount
                )

                if summary.skippedPermissionIssues > 0 {
                    automationTrustMetricRow(
                        icon: "lock.shield",
                        tint: Color.formaWarmOrange,
                        label: "Waiting for folder access",
                        count: summary.skippedPermissionIssues
                    )
                }

                if summary.skippedMissingDestination > 0 {
                    automationTrustMetricRow(
                        icon: "folder.badge.questionmark",
                        tint: Color.formaWarmOrange,
                        label: "Missing destination",
                        count: summary.skippedMissingDestination
                    )
                }

                if summary.skippedConfidenceThreshold > 0 {
                    automationTrustMetricRow(
                        icon: "speedometer",
                        tint: Color.formaSecondaryLabelHigh,
                        label: "Held for low confidence",
                        count: summary.skippedConfidenceThreshold
                    )
                }

                if summary.skippedExcludedFromAutomation > 0 {
                    automationTrustMetricRow(
                        icon: "eye.slash",
                        tint: Color.formaSecondaryLabelHigh,
                        label: "Kept for review",
                        count: summary.skippedExcludedFromAutomation
                    )
                }
            }

            if !summary.exampleFileNames.isEmpty {
                Text("Eligible next: \(summary.exampleFileNames.prefix(3).joined(separator: ", "))")
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabelHigh)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(inspectorSecondaryCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(inspectorSecondaryCardBorder, lineWidth: 1)
        )
    }

    private func automationUndoCard(_ summary: UndoBatchSummary) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.formaCompactSemibold)
                    .foregroundStyle(Color.formaSteelBlue)

                Text("Undo Available")
                    .font(.formaCompactSemibold)
                    .foregroundStyle(Color.formaLabel)

                Spacer()

                Text(relativeTimestamp(for: summary.timestamp))
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaTertiaryLabel)
            }

            Text(
                "Last automatic pass: \(summary.affectedFileCount) \(summary.affectedFileCount == 1 ? "file" : "files"). Undo restores them to their original locations."
            )
                .font(.formaSmall)
                .foregroundStyle(Color.formaSecondaryLabelHigh)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.14 : Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
        .accessibilityIdentifier("defaultPanelAutomationUndoCard")
    }

    private func automationTrustMetricRow(
        icon: String,
        tint: Color,
        label: String,
        count: Int
    ) -> some View {
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: icon)
                .font(.formaCompactSemibold)
                .foregroundStyle(tint)
                .frame(width: 16)

            Text(label)
                .font(.formaSmall)
                .foregroundStyle(Color.formaSecondaryLabelHigh)

            Spacer()

            Text("\(count)")
                .font(.formaSmallSemibold)
                .foregroundStyle(Color.formaLabel)
        }
    }

    private func shouldShowAutomationPreflight(_ summary: AutomationPreflightSummary) -> Bool {
        summary.eligibleCount > 0 || summary.totalSkippedCount > 0
    }

    private func relativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
                Text("NEXT MOVES")
                    .font(.formaBodySemibold)
                    .tracking(0.5)
                    .foregroundStyle(Color.formaSecondaryLabelHigh)

                if let promotionSuggestion = dashboardViewModel.externalReviewPromotionSuggestion {
                    externalReviewPromotionCard(suggestion: promotionSuggestion)
                }

                // Smart Rules (learned patterns) - self-hides when empty
                smartRulesSection

                // Quick Actions (file insights) - self-hides when empty or all dismissed
                if !visibleInsights.isEmpty {
                    quickActionsSection(insight: visibleInsights.first!)
                }
            }
        }
    }

    private func externalReviewPromotionCard(suggestion: ExternalReviewPromotionSuggestion) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                ZStack {
                    Circle()
                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle))
                        .frame(width: 38, height: 38)

                    Image(systemName: suggestion.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.formaSteelBlue)
                }

                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text(suggestion.titleText)
                        .font(.formaBodySemibold)
                        .foregroundStyle(Color.formaLabel)

                    Text(suggestion.detailText)
                        .font(.formaBodyMedium)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: {
                _ = dashboardViewModel.promoteExternalReviewFolder()
            }) {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11, weight: .semibold))

                    Text(suggestion.primaryActionTitle)
                        .font(.formaSmallSemibold)

                    Spacer()
                }
                .foregroundStyle(Color.formaBoneWhite)
                .padding(FormaSpacing.standard)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .fill(Color.formaSteelBlue)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("defaultPanelMonitorFolderSuggestion")
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
        insights.filter { !dismissedInsightIDs.contains($0.id) }
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
                        action: {
                            nav.openRuleBuilderPanel(returnTarget: .defaultPanel)
                            dashboardViewModel.showRuleBuilderPanel()
                        },
                        onDismiss: { dismissedInsightIDs.insert(topInsight.id) }
                    )
                }

            // Additional insights (if expanded)
            if showAllInsights {
                ForEach(visible.dropFirst()) { visibleInsight in
                    QuickActionCard(
                        insight: visibleInsight,
                        action: {
                            nav.openRuleBuilderPanel(returnTarget: .defaultPanel)
                            dashboardViewModel.showRuleBuilderPanel()
                        },
                        onDismiss: { dismissedInsightIDs.insert(visibleInsight.id) }
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

                        Text(showAllInsights ? "Show Less" : "See \(visible.count - 1) More Quick Actions")
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
                            .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.light), lineWidth: 1)
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
        let total = totalFilesCount
        guard total > 0 else { return 1.0 }
        return Double(organizedFilesCount) / Double(total)
    }

    private var totalFilesCount: Int {
        dashboardViewModel.organizationProgressTotalCount
    }

    private var organizedFilesCount: Int {
        dashboardViewModel.organizationProgressOrganizedCount
    }

    private var currentTaskLabelColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.90)
            : Color.formaLabel.opacity(0.82)
    }

    private var currentTaskSubtextColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.86)
            : Color.formaLabel.opacity(0.74)
    }

    private var progressLabelColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.80)
            : Color.formaLabel.opacity(0.68)
    }

    private var defaultPanelPrimaryActionContrastRatio: Double {
        let foreground = colorScheme == .dark ? Color.formaBoneWhite : Color.formaSteelBlue
        let background = Color.formaSteelBlue.opacity(
            colorScheme == .dark ? 0.42 : Color.FormaOpacity.light
        )
        return FormaContrastMetrics.contrastRatio(
            foreground: foreground,
            background: background,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var defaultPanelIgnoreContrastRatio: Double {
        // Use an explicit light-mode foreground color so the measured contrast
        // reflects the rendered quick-action secondary text.
        let foreground = colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.82)
            : Color.formaObsidian.opacity(0.62)
        let background = Color.formaObsidian.opacity(colorScheme == .dark ? 0.18 : Color.FormaOpacity.subtle)
        return FormaContrastMetrics.contrastRatio(
            foreground: foreground,
            background: background,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    @ViewBuilder
    private var scanPhaseStatusSection: some View {
        if dashboardViewModel.isLoading, let phase = dashboardViewModel.scanPhaseStatusText {
            HStack(spacing: FormaSpacing.tight) {
                ProgressView()
                    .controlSize(.small)
                Text(phase)
                    .font(.formaCaption)
                    .foregroundStyle(progressLabelColor)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("defaultPanelScanPhaseStatus")
        }
    }

    // MARK: - Insight Loading

    /// Load insights on appear - uses async to avoid blocking main thread
    private func loadInsightsImmediately() {
        scheduleInsightRefresh(metadata: "immediate", debounceNanoseconds: 0)
    }

    /// Load insights with debouncing (used on data changes)
    /// Cancels any pending load and waits for debounce interval before executing
    /// Uses async version with parallel execution for better performance
    private func loadInsightsDebounced() {
        scheduleInsightRefresh(metadata: "debounced", debounceNanoseconds: insightDebounceInterval)
    }

    /// Enforces a strict single in-flight refresh policy:
    /// each new request cancels and supersedes any previous request.
    private func scheduleInsightRefresh(metadata: String, debounceNanoseconds: UInt64) {
        insightLoadSequence &+= 1
        let requestSequence = insightLoadSequence
        insightLoadTask?.cancel()
        insightLoadTask = Task {
            let refreshId = performanceMonitor.begin(
                .defaultPanelInsightRefresh,
                metadata: metadata
            )
            var completionMetadata = "cancelled"
            defer {
                performanceMonitor.end(
                    .defaultPanelInsightRefresh,
                    id: refreshId,
                    metadata: completionMetadata
                )
            }

            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }

            guard !Task.isCancelled, requestSequence == insightLoadSequence else { return }

            let newInsights = await insightsService.generateInsights(
                from: dashboardViewModel.allFiles,
                activities: dashboardViewModel.recentActivities,
                rules: [],
                precomputedClusters: dashboardViewModel.detectedClusters
            )
            guard !Task.isCancelled, requestSequence == insightLoadSequence else { return }

            completionMetadata = "\(newInsights.count) insights"
            await MainActor.run {
                guard requestSequence == insightLoadSequence else { return }
                applyInsights(newInsights)
            }
        }
    }

    private func applyInsights(_ newInsights: [FileInsight]) {
        if insights == newInsights {
            return
        }

        let liveInsightIDs = Set(newInsights.map(\.id))
        dismissedInsightIDs.formIntersection(liveInsightIDs)
        insights = newInsights
    }
}

// MARK: - Quick Action Card (one-time file organization action)

struct QuickActionCard: View {
    let insight: FileInsight
    let action: () -> Void
    var onDismiss: (() -> Void)?

    @State private var isHovered = false
    @State private var isDismissHovered = false
    @Environment(\.colorScheme) private var colorScheme
    private let isUITesting = CommandLine.arguments.contains("--uitesting")

    private var primaryActionTextColor: Color {
        colorScheme == .dark ? Color.formaBoneWhite : Color.formaSteelBlue
    }

    private var primaryActionBackground: Color {
        Color.formaSteelBlue.opacity(
            colorScheme == .dark ? 0.42 : Color.FormaOpacity.light
        )
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.82)
            : Color.formaObsidian.opacity(0.62)
    }

    private var quickActionCardBackground: Color {
        isHovered
            ? Color.formaObsidian.opacity(colorScheme == .dark ? 0.28 : Color.FormaOpacity.light)
            : Color.formaObsidian.opacity(colorScheme == .dark ? 0.18 : Color.FormaOpacity.subtle)
    }

    private var dismissBackgroundColor: Color {
        colorScheme == .dark
            ? Color.formaTextBackground.opacity(isDismissHovered ? 0.96 : 0.84)
            : Color.formaObsidian.opacity(isDismissHovered ? Color.FormaOpacity.light : Color.FormaOpacity.ultraSubtle * 2)
    }

    private var cardBorderColor: Color {
        Color.formaObsidian.opacity(
            isHovered
                ? (colorScheme == .dark ? 0.35 : Color.FormaOpacity.medium)
                : (colorScheme == .dark ? 0.25 : Color.FormaOpacity.light)
        )
    }

    private var primaryActionContrastRatio: Double {
        FormaContrastMetrics.contrastRatio(
            foreground: primaryActionTextColor,
            background: primaryActionBackground,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            // Header: Icon + Message + Dismiss
            HStack(alignment: .top, spacing: FormaSpacing.tight) {
                // Icon with category background
                ZStack {
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .fill(insight.categoryColor.opacity(Color.FormaOpacity.medium))
                        .frame(width: 44, height: 44)

                    Image(systemName: insight.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(insight.categoryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.message)
                        .font(.formaBodySemibold)
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Affected count subtitle
                    if let count = insight.affectedCount, count > 0 {
                        Text("\(count) files affected")
                            .font(.formaCaptionSemibold)
                            .foregroundStyle(insight.categoryColor)
                    }

                    // Contextual detail line
                    if let detail = insight.detail {
                        Text(detail)
                            .font(.formaCaption)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(2)
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
                                    : secondaryTextColor
                            )
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(dismissBackgroundColor)
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
                        .foregroundStyle(primaryActionTextColor)
                        .padding(.horizontal, FormaSpacing.standard)
                        .padding(.vertical, FormaSpacing.tight)
                        .background(primaryActionBackground)
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .pressAnimation()

                    Spacer()
                }
            }
        }
        .padding(.horizontal, FormaSpacing.standard)
        .padding(.vertical, FormaSpacing.tight)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(quickActionCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityIdentifier("quickActionCard")
        .accessibilityValue(
            isUITesting
                ? "primaryAction=\(String(format: "%.2f", primaryActionContrastRatio))"
                : ""
        )
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
        // Use file type category color when available (matches category stat pills),
        // otherwise fall back to neutral steelBlue for cross-category insights.
        if let category = fileTypeCategory {
            return category.color
        }
        return .formaSteelBlue
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FileItem.self, Rule.self, ActivityItem.self, configurations: config)

    DefaultPanelView()
        .environmentObject(DashboardViewModel())
        .environmentObject(NavigationViewModel())
        .modelContainer(container)
        .frame(width: 340, height: 800)
        .background(.regularMaterial)
}
