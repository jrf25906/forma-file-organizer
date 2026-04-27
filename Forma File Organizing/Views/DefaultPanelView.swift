import Foundation
import SwiftUI
import SwiftData

private struct DefaultPanelEditorialSuggestionItem: Identifiable {
    let snapshot: DefaultPanelEditorialSuggestionSnapshot
    let action: () -> Void

    var id: String { snapshot.id }
}

// MARK: - Premium Default Panel View
// Redesigned for Apple Design Award quality
// Features: Circular progress ring, refined insights, clear hierarchy

struct DefaultPanelView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject private var filterViewModel: FilterViewModel
    @EnvironmentObject private var analyticsViewModel: AnalyticsDashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rightPanelLayout) private var rightPanelLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allPatterns: [LearnedPattern]
    @State private var insights: [FileInsight] = []
    @State private var showAllSuggestions: Bool = false
    @State private var dismissedInsightIDs: Set<String> = []
    @State private var uiTestSectionFrames: [String: CGRect] = [:]
    private let isUITesting = CommandLine.arguments.contains("--uitesting")

    private let insightsService = InsightsService.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let automationState = AutomationEngine.shared.state

    /// Check if any suggestions (Smart Rules or Quick Actions) are available
    private var hasAnySuggestions: Bool {
        !editorialSuggestionItems.isEmpty
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

    private enum UITestSectionID {
        static let heroCard = "heroCard"
        static let automationCard = "automationCard"
        static let automationVisibleCard = "automationVisibleCard"
        static let suggestionsCard = "suggestionsCard"
        static let suggestionsVisibleCard = "suggestionsVisibleCard"
    }

    private enum InspectorSectionChrome {
        case standard
        case quiet
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

    private var inspectorQuietCardFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.035)
            : Color.formaBoneWhite.opacity(0.68)
    }

    private var inspectorQuietCardBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle)
    }

    private var inspectorCardShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.formaObsidian.opacity(0.07)
    }

    private var heroCardBorder: Color {
        colorScheme == .dark
            ? Color.formaSteelBlue.opacity(0.34)
            : Color.formaSteelBlue.opacity(0.30)
    }

    private var heroCardShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.34)
            : Color.formaObsidian.opacity(0.12)
    }

    private var commandPrimaryActionShadow: Color {
        Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.22 : 0.16)
    }

    private var projectSpacesFeatureEnabled: Bool {
        FeatureFlagService.shared.isEnabled(.projectSpaces)
    }

    private var activeProjectSpaceDetail: ProjectSpaceDetail? {
        guard projectSpacesFeatureEnabled else { return nil }
        return dashboardViewModel.selectedProjectSpaceDetail
    }

    private var projectSpaceWorkflowSectionSnapshot: ProjectSpaceDetailView.Snapshot.WorkflowSectionSnapshot? {
        guard activeProjectSpaceDetail != nil,
              !dashboardViewModel.isProjectSpaceAutomationBoardEnabled else { return nil }

        let selectedTemplateText = WorkflowTemplateCatalog
            .template(for: dashboardViewModel.selectedProjectSpaceWorkflowTemplateID)?
            .displayName ?? "No workflow template selected"

        return .init(
            sectionTitle: "Workflow",
            selectedTemplateText: selectedTemplateText,
            helperText: "Pick a built-in workflow template, preview it here, then run it manually for this project space.",
            previewText: dashboardViewModel.projectSpaceWorkflowSimulationPreview?.summaryText,
            organizeButtonTitle: "Organize Project Space",
            isOrganizeButtonEnabled: dashboardViewModel.projectSpaceWorkflowDisabledReason == nil,
            disabledReasonText: dashboardViewModel.projectSpaceWorkflowDisabledReason,
            latestRunSummaryText: dashboardViewModel.selectedProjectSpaceWorkflowLatestRunSummary?.summaryText
        )
    }

    private var projectSpaceAutomationSectionSnapshot: ProjectSpaceAutomationSection.Snapshot? {
        guard dashboardViewModel.isProjectSpaceAutomationBoardEnabled,
              let board = dashboardViewModel.selectedProjectSpaceAutomationBoard else {
            return nil
        }

        return ProjectSpaceAutomationSection.Snapshot(board: board)
    }

    private var showsProjectSpacesSection: Bool {
        projectSpacesFeatureEnabled && !dashboardViewModel.projectSpaces.isEmpty
    }

    private var trustedAutomationScopeSnapshot: TrustedAutomationScopesSection.Snapshot? {
        TrustedAutomationScopesSection.Snapshot(
            title: "Autopilot scopes",
            sections: dashboardViewModel.trustedAutomationScopeSections,
            style: .compact
        )
    }

    private var rightPanelWidthClassText: String {
        rightPanelLayout.isCompact ? "compact" : "regular"
    }

    private var rightPanelWidthProbeText: String {
        "width=\(Int(rightPanelLayout.width.rounded()));widthClass=\(rightPanelWidthClassText)"
    }

    private var suggestablePatterns: [LearnedPattern] {
        allPatterns
            .filter(\.shouldSuggest)
            .sorted { lhs, rhs in
                if lhs.confidenceScore != rhs.confidenceScore {
                    return lhs.confidenceScore > rhs.confidenceScore
                }

                if lhs.occurrenceCount != rhs.occurrenceCount {
                    return lhs.occurrenceCount > rhs.occurrenceCount
                }

                return lhs.patternDescription.localizedCaseInsensitiveCompare(rhs.patternDescription) == .orderedAscending
            }
    }

    var body: some View {
        panelContent
        .coordinateSpace(name: "defaultPanelLayout")
        .background(Color.clear)
        .onAppear {
            loadInsightsImmediately()
            dashboardViewModel.scheduleTrustedAutomationScopeRefresh()
        }
        .onChange(of: dashboardViewModel.allFiles) { _, _ in
            loadInsightsDebounced()
        }
        .onChange(of: analyticsViewModel.recentActivities) { _, _ in
            loadInsightsDebounced()
        }
        .onChange(of: analyticsViewModel.detectedClusters.count) { _, _ in
            loadInsightsDebounced()
        }
        .onDisappear {
            // Cancel any pending insight load when view disappears
            insightLoadSequence &+= 1
            insightLoadTask?.cancel()
            dashboardViewModel.cancelScheduledTrustedAutomationScopeRefresh()
        }
        .onPreferenceChange(DefaultPanelSectionFramesPreferenceKey.self) { frames in
            guard isUITesting else { return }
            uiTestSectionFrames = frames
        }
        .sheet(isPresented: trustedAutomationScopeDetailSheetBinding) {
            if let detail = dashboardViewModel.selectedTrustedAutomationScopeDetail {
                TrustedAutomationScopeDetailSheet(
                    detail: detail,
                    onPause: {
                        dashboardViewModel.pauseSelectedTrustedAutomationScope()
                    },
                    onResume: {
                        dashboardViewModel.resumeSelectedTrustedAutomationScope()
                    },
                    onRevoke: {
                        dashboardViewModel.revokeSelectedTrustedAutomationScope()
                    },
                    onClose: {
                        dashboardViewModel.dismissTrustedAutomationScopeDetail()
                    }
                )
            }
        }
        .sheet(isPresented: projectSpaceAutomationComposerSheetBinding) {
            if let draft = dashboardViewModel.projectSpaceAutomationComposerDraft {
                ProjectSpaceAutomationComposerSheet(
                    draft: Binding(
                        get: { dashboardViewModel.projectSpaceAutomationComposerDraft ?? draft },
                        set: { dashboardViewModel.projectSpaceAutomationComposerDraft = $0 }
                    ),
                    onSave: {
                        dashboardViewModel.createProjectSpaceAutomationPolicyFromComposer()
                    },
                    onCancel: {
                        dashboardViewModel.dismissProjectSpaceAutomationComposer()
                    }
                )
            }
        }
        .sheet(isPresented: projectSpaceAutomationPolicySheetBinding) {
            if let policy = dashboardViewModel.selectedProjectSpaceAutomationPolicyDetail {
                ProjectSpaceAutomationPolicySheet(
                    policy: policy,
                    preview: dashboardViewModel.selectedProjectSpaceAutomationPolicyPreview,
                    manualRunDisabledReason: dashboardViewModel.selectedProjectSpaceAutomationManualRunDisabledReason,
                    isManualRunInProgress: dashboardViewModel.isProjectSpaceWorkflowInProgress,
                    onRunNow: {
                        Task { @MainActor in
                            await dashboardViewModel.runSelectedProjectSpaceAutomationPolicyManually()
                        }
                    },
                    onActivate: [.draft, .recommended].contains(policy.state) ? {
                        dashboardViewModel.activateSelectedProjectSpaceAutomationPolicy()
                    } : nil,
                    onPause: policy.state == .active ? {
                        dashboardViewModel.pauseSelectedProjectSpaceAutomationPolicy()
                    } : nil,
                    onResume: policy.state == .paused ? {
                        dashboardViewModel.resumeSelectedProjectSpaceAutomationPolicy()
                    } : nil,
                    onClose: {
                        dashboardViewModel.dismissProjectSpaceAutomationPolicy()
                    }
                )
            }
        }
        .overlay(alignment: .topLeading) {
            if isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("defaultPanelContrastProbe")
                    .accessibilityLabel(
                        "primaryAction=\(String(format: "%.2f", defaultPanelPrimaryActionContrastRatio));ignore=\(String(format: "%.2f", defaultPanelIgnoreContrastRatio));heroToAutomation=\(String(format: "%.2f", defaultPanelHeroToAutomationMetric));automationToSuggestions=\(String(format: "%.2f", defaultPanelAutomationToSuggestionsMetric));\(rightPanelWidthProbeText)"
                    )
                    .accessibilityValue(
                        "primaryAction=\(String(format: "%.2f", defaultPanelPrimaryActionContrastRatio));ignore=\(String(format: "%.2f", defaultPanelIgnoreContrastRatio));heroToAutomation=\(String(format: "%.2f", defaultPanelHeroToAutomationMetric));automationToSuggestions=\(String(format: "%.2f", defaultPanelAutomationToSuggestionsMetric));\(rightPanelWidthProbeText)"
                    )
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if let detail = activeProjectSpaceDetail {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    if let fileRow = dashboardViewModel.projectSpaceAssociationCorrectionFileRow {
                        inspectorSectionCard {
                            ProjectSpaceAssociationEditorView(
                                fileName: fileRow.displayName,
                                sourceFolderHint: fileRow.sourceFolderHint,
                                proposedLabel: $dashboardViewModel.projectSpaceAssociationCorrectionProposedLabel,
                                suggestedLabels: dashboardViewModel.projectSpaceAssociationSuggestedLabels,
                                onSave: {
                                    dashboardViewModel.saveProjectSpaceAssociationCorrection()
                                },
                                onCancel: {
                                    dashboardViewModel.cancelProjectSpaceAssociationCorrection()
                                }
                            )
                        }
                    }

                    inspectorSectionCard(emphasized: true) {
                        ProjectSpaceDetailView(
                            snapshot: ProjectSpaceDetailView.Snapshot(
                                detail: detail,
                                automationSection: projectSpaceAutomationSectionSnapshot,
                                workflowSection: projectSpaceWorkflowSectionSnapshot
                            ),
                            onCreatePolicy: dashboardViewModel.isProjectSpaceAutomationBoardEnabled ? {
                                dashboardViewModel.presentProjectSpaceAutomationComposer()
                            } : nil,
                            onInspectPolicy: dashboardViewModel.isProjectSpaceAutomationBoardEnabled ? { policyID in
                                dashboardViewModel.presentProjectSpaceAutomationPolicy(id: policyID)
                            } : nil,
                            workflowTemplateID: $dashboardViewModel.selectedProjectSpaceWorkflowTemplateID,
                            workflowSimulationPreview: dashboardViewModel.projectSpaceWorkflowSimulationPreview,
                            isWorkflowTemplatePickerEnabled: dashboardViewModel.isProjectSpaceWorkflowTemplatePickerEnabled,
                            isOrganizingProjectSpaceWorkflow: dashboardViewModel.isProjectSpaceWorkflowInProgress,
                            onOrganizeProjectSpace: {
                                Task { @MainActor in
                                    await dashboardViewModel.organizeSelectedProjectSpace()
                                }
                            },
                            onBack: {
                                dashboardViewModel.closeProjectSpaceDetail()
                            },
                            onOpenFile: { fileRow in
                                dashboardViewModel.openFileFromProjectSpace(fileRow)
                            },
                            onCorrectAssociation: { fileRow in
                                dashboardViewModel.beginProjectSpaceAssociationCorrection(fileRow)
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
            heroSectionCard {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    heroSection

                    if shouldShowPinnedPrimaryAction {
                        pinnedPrimaryAction
                            .guidedTourRegion(.organizeButton)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("defaultPanelHeroSection")
            .background(sectionFrameReader(id: UITestSectionID.heroCard))
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.top, FormaSpacing.standard)
            .padding(.bottom, FormaSpacing.standard)

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
                        automationStatusSection
                            .background(sectionFrameReader(id: UITestSectionID.automationCard))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("defaultPanelAutomationCard")
                    }

                    if hasAnySuggestions {
                        suggestionsSection
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("defaultPanelSuggestionsSection")
                        .background(sectionFrameReader(id: UITestSectionID.suggestionsCard))
                    }
                }
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.bottom, FormaSpacing.generous)
            }
        }
    }

    private func inspectorSectionCard<Content: View>(
        emphasized: Bool = false,
        chrome: InspectorSectionChrome = .standard,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(emphasized ? FormaSpacing.large : FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(inspectorSectionFill(emphasized: emphasized, chrome: chrome))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        inspectorSectionBorder(emphasized: emphasized, chrome: chrome),
                        lineWidth: inspectorSectionBorderWidth(emphasized: emphasized, chrome: chrome)
                    )
            )
            .shadow(
                color: inspectorSectionShadow(chrome: chrome),
                radius: inspectorSectionShadowRadius(emphasized: emphasized, chrome: chrome),
                x: 0,
                y: inspectorSectionShadowYOffset(emphasized: emphasized, chrome: chrome)
            )
    }

    private func inspectorSectionFill(
        emphasized: Bool,
        chrome: InspectorSectionChrome
    ) -> Color {
        switch chrome {
        case .standard:
            return emphasized ? inspectorPrimaryCardFill : inspectorSecondaryCardFill
        case .quiet:
            return inspectorQuietCardFill
        }
    }

    private func inspectorSectionBorder(
        emphasized: Bool,
        chrome: InspectorSectionChrome
    ) -> Color {
        switch chrome {
        case .standard:
            return emphasized ? inspectorPrimaryCardBorder : inspectorSecondaryCardBorder
        case .quiet:
            return inspectorQuietCardBorder
        }
    }

    private func inspectorSectionBorderWidth(
        emphasized: Bool,
        chrome: InspectorSectionChrome
    ) -> CGFloat {
        switch chrome {
        case .standard:
            return emphasized ? 1.1 : 1
        case .quiet:
            return 0.9
        }
    }

    private func inspectorSectionShadow(
        chrome: InspectorSectionChrome
    ) -> Color {
        switch chrome {
        case .standard:
            return inspectorCardShadow
        case .quiet:
            return colorScheme == .dark
                ? Color.black.opacity(0.14)
                : Color.formaObsidian.opacity(0.045)
        }
    }

    private func inspectorSectionShadowRadius(
        emphasized: Bool,
        chrome: InspectorSectionChrome
    ) -> CGFloat {
        switch chrome {
        case .standard:
            return emphasized ? 10 : 6
        case .quiet:
            return emphasized ? 8 : 4
        }
    }

    private func inspectorSectionShadowYOffset(
        emphasized: Bool,
        chrome: InspectorSectionChrome
    ) -> CGFloat {
        switch chrome {
        case .standard:
            return emphasized ? 3 : 2
        case .quiet:
            return emphasized ? 2 : 1
        }
    }

    private func heroSectionCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, rightPanelLayout.isCompact ? FormaSpacing.standard : FormaSpacing.large)
            .padding(.vertical, rightPanelLayout.isCompact ? FormaSpacing.standard : FormaSpacing.generous)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                        .fill(Color.formaSurfaceAnchor)

                    RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.20 : 0.14),
                                    Color.formaSurfaceWork.opacity(colorScheme == .dark ? 0.05 : 0.38)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.formaObsidian.opacity(colorScheme == .dark ? 0.22 : 0.055),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                    .strokeBorder(heroCardBorder, lineWidth: 1)
            )
            .shadow(
                color: heroCardShadow,
                radius: 18,
                x: 0,
                y: 5
            )
    }

    private func sectionFrameReader(id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: DefaultPanelSectionFramesPreferenceKey.self,
                value: [id: proxy.frame(in: .named("defaultPanelLayout"))]
            )
        }
    }

    // MARK: - Hero Section

    private struct CurrentTaskHeroPresentation {
        let countText: String?
        let title: String
        let summary: String
    }

    private var currentTaskHeroPresentation: CurrentTaskHeroPresentation {
        let reviewCount = filterViewModel.cachedNeedsReviewCount
        let currentChunkCount = dashboardViewModel.currentReviewChunkCount

        if reviewCount == 0 {
            return CurrentTaskHeroPresentation(
                countText: nil,
                title: "All organized",
                summary: "\(greetingText). Your \(locationDisplayPhrase) is tidy."
            )
        }

        if dashboardViewModel.hasDeferredReviewFiles && currentChunkCount == 0 {
            return CurrentTaskHeroPresentation(
                countText: "\(dashboardViewModel.deferredReviewFileCount)",
                title: "Files set aside",
                summary: "Resume this pass when you're ready. Nothing else is crowding the queue right now."
            )
        }

        if currentChunkCount == 0 {
            return CurrentTaskHeroPresentation(
                countText: "0",
                title: "Files in this filter",
                summary: "Adjust the current filter to bring the next pass back into view."
            )
        }

        return CurrentTaskHeroPresentation(
            countText: "\(taskHeadlineCount)",
            title: taskDescription,
            summary: taskExplanation
        )
    }

    private var currentTaskProgressValue: Double {
        let reviewCount = filterViewModel.cachedNeedsReviewCount
        if reviewCount == 0 {
            return 1.0
        }

        guard currentPassTotalCount > 0 else { return 0.0 }
        return dashboardViewModel.currentPassProgress
    }

    private var heroSection: some View {
        let presentation = currentTaskHeroPresentation

        return VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text("CURRENT TASK")
                .font(.formaCaptionSemibold)
                .tracking(0.8)
                .foregroundStyle(currentTaskLabelColor)

            if let countText = presentation.countText {
                Text(countText)
                    .font(.system(size: rightPanelLayout.isCompact ? 26 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.formaLabel)
                    .monospacedDigit()
                    .accessibilityLabel(countText)
                    .accessibilityIdentifier("defaultPanelHeroCount")
            } else {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(RightRailSemanticTone.live.color)
                    Text("Done")
                        .font(.formaCallout)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                }
            }

            Text(presentation.title)
                .font(.system(size: rightPanelLayout.isCompact ? 15 : 16, weight: .semibold, design: .default))
                .foregroundStyle(Color.formaLabel)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.summary)
                .font(.formaCaption)
                .foregroundStyle(currentTaskSubtextColor)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(presentation.summary)
                .accessibilityIdentifier("defaultPanelHeroSummary")

            scanPhaseStatusSection

            if filterViewModel.cachedNeedsReviewCount == 0 {
                heroCompletionActions
            }

            progressSection
            categoryStatsRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var heroCompletionActions: some View {
        HStack(spacing: FormaSpacing.tight) {
            Button(action: {
                dashboardViewModel.showAnalyticsWorkspace()
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
                .frame(minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                )
            }
            .buttonStyle(.plain)

            Button(action: {
                dashboardViewModel.showRulesWorkspace()
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
                .frame(minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .fill(Color.formaLabel.opacity(Color.FormaOpacity.subtle))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, FormaSpacing.tight)
    }

    // MARK: - Task Description (Dynamic)

    /// Returns a description of the current task based on file characteristics
    private var taskDescription: String {
        if shouldEmphasizeStaleTask {
            return "Stale Files in This Pass"
        } else if currentPassDominantCategory != .all {
            return "\(currentPassDominantCategory.displayName) in This Pass"
        } else {
            return "Files in This Pass"
        }
    }

    /// Returns an explanation of why these files were prioritized
    private var taskExplanation: String {
        let currentChunkCount = dashboardViewModel.currentReviewChunkCount
        let hiddenCount = max(0, filterViewModel.cachedNeedsReviewCount - currentChunkCount)
        let passSentence = "\(countedText(currentChunkCount, singular: "file", plural: "files")) in this pass."
        let backlogSentence = hiddenCount > 0 ? outsidePassText(for: hiddenCount) : nil

        if shouldEmphasizeStaleTask {
            return [passSentence, "Oldest first.", backlogSentence]
                .compactMap { $0 }
                .joined(separator: " ")
        }

        if currentPassDominantCategory != .all {
            return [passSentence, "Mostly \(currentPassDominantCategory.displayName.lowercased()).", backlogSentence]
                .compactMap { $0 }
                .joined(separator: " ")
        }

        return [passSentence, backlogSentence]
            .compactMap { $0 }
            .joined(separator: " ")
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
    private var currentPassDominantCategory: FileTypeCategory {
        let categories = dashboardViewModel.currentPassCategorySummaries

        guard let dominant = categories.max(by: { $0.count < $1.count }),
              dominant.count > 0,
              dominant.count >= Swift.max(1, currentPassTotalCount / 2) else {
            return .all
        }
        return dominant.category
    }

    /// Current folder location name
    private var currentLocationName: String {
        filterViewModel.selectedFolder.displayName
    }

    /// Display phrase for location (e.g., "Desktop" or "Documents folder")
    private var locationDisplayPhrase: String {
        switch filterViewModel.selectedFolder {
        case .desktop:
            return "Desktop"
        default:
            return "\(currentLocationName) folder"
        }
    }

    /// Preposition for location (e.g., "on" for Desktop, "in" for folders)
    private var locationPreposition: String {
        switch filterViewModel.selectedFolder {
        case .desktop:
            return "on"
        default:
            return "in"
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            Color.formaObsidian.opacity(
                                colorScheme == .dark ? 0.38 : 0.14
                            )
                        )
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    currentTaskProgressTone.color.opacity(0.82),
                                    currentTaskProgressTone.color
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * currentTaskProgressValue), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("PASS PROGRESS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                .foregroundStyle(progressLabelColor)

                Spacer()

                Text(progressSummaryText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(progressLabelColor)
                    .accessibilityIdentifier("defaultPanelProgressSummary")
            }
        }
    }

    private var progressSummaryText: String {
        let reviewCount = filterViewModel.cachedNeedsReviewCount

        if reviewCount == 0 {
            return "Pass complete"
        }

        guard currentPassTotalCount > 0 else {
            if dashboardViewModel.hasDeferredReviewFiles {
                return "Pass paused"
            }
            return "Waiting for a visible pass"
        }

        return "\(organizedFilesCount) of \(currentPassTotalCount) organized"
    }

    // MARK: - Category Stats Row (Clickable Filters)

    private var categoryStatsRow: some View {
        let categories = dashboardViewModel.currentPassCategorySummaries

        return Group {
            if !categories.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.element.category) { index, item in
                        HeroCategoryStatButton(
                            category: item.category,
                            count: item.count,
                            isSelected: filterViewModel.selectedCategory == item.category
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if filterViewModel.selectedCategory == item.category {
                                    dashboardViewModel.selectCategory(.all)
                                } else {
                                    dashboardViewModel.selectCategory(item.category)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if index < categories.count - 1 {
                            VStack {
                                Spacer(minLength: 0)

                                Rectangle()
                                    .fill(Color.formaObsidian.opacity(colorScheme == .dark ? 0.18 : Color.FormaOpacity.light))
                                    .frame(width: 1, height: 24)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(height: 42)
                .padding(.horizontal, -4)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("defaultPanelHeroCategoryBand")
            }
        }
    }

    private func countedText(_ count: Int, singular: String, plural: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(plural)"
    }

    private func outsidePassText(for count: Int) -> String {
        if count == 1 {
            return "1 more file waits outside this pass."
        }

        return "\(count) wait outside this pass."
    }

    // MARK: - Pinned Primary Action
    
    private var pinnedPrimaryAction: some View {
        let readyFiles = dashboardViewModel.reviewableFiles.filter { $0.status == .ready }
        
        return VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            if dashboardViewModel.hasDeferredReviewFiles && dashboardViewModel.currentReviewChunkCount == 0 {
                commandPrimaryActionButton(
                    title: "Resume \(dashboardViewModel.deferredReviewFileCount) Deferred \(dashboardViewModel.deferredReviewFileCount == 1 ? "File" : "Files")",
                    systemImage: "arrow.triangle.2.circlepath",
                    help: "Bring back the files you set aside for now"
                ) {
                    dashboardViewModel.resumeDeferredReviewFiles()
                }
            } else if !readyFiles.isEmpty {
                if dashboardViewModel.showsDashboardWorkflowTemplatePicker {
                    WorkflowTemplatePicker(
                        selectedTemplateID: $dashboardViewModel.selectedWorkflowTemplateID,
                        preview: dashboardViewModel.dashboardWorkflowSimulationPreview
                    )
                }

                commandPrimaryActionButton(
                    title: "Organize \(readyFiles.count) \(readyFiles.count == 1 ? "File" : "Files")",
                    systemImage: "tray.and.arrow.down.fill",
                    help: "Organize all ready files"
                ) {
                    dashboardViewModel.organizeAllReadyFiles(context: modelContext)
                }
            }
        }
    }

    private func commandPrimaryActionButton(
        title: String,
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.formaBodySemibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Spacer(minLength: FormaSpacing.tight)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.formaBoneWhite)
            .frame(maxWidth: .infinity, minHeight: rightPanelLayout.isCompact ? 44 : 46)
            .contentShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: FormaRadius.control))
        .controlSize(.large)
        .tint(Color.formaSteelBlue)
        .shadow(color: commandPrimaryActionShadow, radius: 8, x: 0, y: 3)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(help))
        .help(help)
    }

    // MARK: - Automation Status Section (v1.5 - Promoted to status bar)

    @ViewBuilder
    private var automationStatusSection: some View {
        if showsAutomationStatusSection {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                if let automationStatusPresentation = dashboardViewModel.automationStatusPresentation {
                    AutomationStatusWidget(
                        pendingReviewCount: filterViewModel.cachedNeedsReviewCount,
                        activeScopeCount: dashboardViewModel.trustedAutomationActiveScopeCount,
                        attentionScopeCount: dashboardViewModel.trustedAutomationAttentionScopeCount,
                        presentation: automationStatusPresentation
                    )
                    .background(sectionFrameReader(id: UITestSectionID.automationVisibleCard))

                    if isUITesting {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier("defaultPanelAutomationSummaryProbe")
                            .accessibilityLabel(automationSummaryProbeText(presentation: automationStatusPresentation))
                            .accessibilityValue(automationSummaryProbeText(presentation: automationStatusPresentation))

                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier("defaultPanelAutomationWidthProbe")
                            .accessibilityLabel(defaultPanelAutomationWidthProbeText)
                            .accessibilityValue(defaultPanelAutomationWidthProbeText)
                    }
                }

                if let trustedAutomationScopeSnapshot {
                    TrustedAutomationScopesSection(snapshot: trustedAutomationScopeSnapshot) { scopeID in
                        dashboardViewModel.presentTrustedAutomationScopeDetail(id: scopeID)
                    }
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

    private func automationSummaryProbeText(presentation: DashboardAutomationStatusPresentation) -> String {
        let primaryText: String
        if filterViewModel.cachedNeedsReviewCount > 0 {
            let count = filterViewModel.cachedNeedsReviewCount
            primaryText = "\(count) \(count == 1 ? "file" : "files") waiting for review"
        } else if let meaningfulRunSummary = presentation.latestMeaningfulRunSummary {
            primaryText = meaningfulRunSummary
        } else if let preflightSummary = presentation.latestPreflightSummary {
            primaryText = preflightSummary
        } else {
            primaryText = "Automation is ready for the next pass"
        }

        var secondaryFragments: [String] = []

        if dashboardViewModel.trustedAutomationActiveScopeCount > 0 {
            let count = dashboardViewModel.trustedAutomationActiveScopeCount
            secondaryFragments.append("\(count) folder\(count == 1 ? "" : "s") on autopilot")
        }

        if dashboardViewModel.trustedAutomationAttentionScopeCount > 0 {
            let count = dashboardViewModel.trustedAutomationAttentionScopeCount
            secondaryFragments.append("\(count) folder\(count == 1 ? "" : "s") blocked")
        }

        let secondaryText = secondaryFragments.isEmpty ? "none" : secondaryFragments.joined(separator: " · ")

        return [
            "surface=single",
            "headline=\(editorialProbeText(presentation.headlineText))",
            "primary=\(editorialProbeText(primaryText))",
            "secondary=\(editorialProbeText(secondaryText))"
        ].joined(separator: "|")
    }

    private var trustedAutomationScopeDetailSheetBinding: Binding<Bool> {
        Binding(
            get: { dashboardViewModel.isTrustedAutomationScopeDetailPresented },
            set: { isPresented in
                if !isPresented {
                    dashboardViewModel.dismissTrustedAutomationScopeDetail()
                }
            }
        )
    }

    private var projectSpaceAutomationComposerSheetBinding: Binding<Bool> {
        Binding(
            get: { dashboardViewModel.isProjectSpaceAutomationComposerPresented },
            set: { isPresented in
                if !isPresented {
                    dashboardViewModel.dismissProjectSpaceAutomationComposer()
                }
            }
        )
    }

    private var projectSpaceAutomationPolicySheetBinding: Binding<Bool> {
        Binding(
            get: { dashboardViewModel.isProjectSpaceAutomationPolicySheetPresented },
            set: { isPresented in
                if !isPresented {
                    dashboardViewModel.dismissProjectSpaceAutomationPolicy()
                }
            }
        )
    }

    private func automationUndoCard(_ summary: UndoBatchSummary) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            if rightPanelLayout.isCompact {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.formaCompactSemibold)
                            .foregroundStyle(Color.formaSteelBlue)

                        Text("Undo Available")
                            .font(.formaCompactSemibold)
                            .foregroundStyle(Color.formaLabel)
                    }

                    Text(relativeTimestamp(for: summary.timestamp))
                        .font(.formaCaption)
                        .foregroundStyle(Color.formaTertiaryLabel)
                }
            } else {
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
        Group {
            if rightPanelLayout.isCompact {
                HStack(alignment: .top, spacing: FormaSpacing.tight) {
                    Image(systemName: icon)
                        .font(.formaCompactSemibold)
                        .foregroundStyle(tint)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                        Text(label)
                            .font(.formaSmall)
                            .foregroundStyle(Color.formaSecondaryLabelHigh)
                            .lineLimit(2)

                        Text("\(count)")
                            .font(.formaSmallSemibold)
                            .foregroundStyle(Color.formaLabel)
                    }

                    Spacer(minLength: 0)
                }
            } else {
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

    @ViewBuilder
    private var suggestionsSection: some View {
        let items = displayedEditorialSuggestionItems

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                HStack(alignment: .firstTextBaseline, spacing: FormaSpacing.tight) {
                    Text("NEXT MOVES")
                        .font(.formaCaptionSemibold)
                        .tracking(0.8)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)

                    Spacer()

                    if editorialSuggestionItems.count > 1 {
                        Text("Featured first")
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaTertiaryLabelHigh)
                    }
                }

                if let featuredItem = items.first {
                    FeaturedEditorialSuggestionCard(
                        snapshot: featuredItem.snapshot,
                        action: featuredItem.action
                    )
                    .background(sectionFrameReader(id: UITestSectionID.suggestionsVisibleCard))

                    if isUITesting {
                        editorialSuggestionProbe(
                            identifier: "defaultPanelFeaturedNextMoveProbe",
                            value: editorialSuggestionProbeValue(snapshot: featuredItem.snapshot, style: "featured")
                        )
                    }
                }

                ForEach(Array(items.dropFirst())) { item in
                    EditorialSuggestionCard(
                        snapshot: item.snapshot,
                        action: item.action
                    )
                }

                if editorialSuggestionItems.count > collapsedEditorialSuggestionLimit {
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            showAllSuggestions.toggle()
                        }
                    }) {
                        HStack(spacing: FormaSpacing.tight) {
                            Image(systemName: showAllSuggestions ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                            Text(showAllSuggestions ? "Show fewer actions" : "See all actions (\(editorialSuggestionItems.count))")
                                .font(.formaSmallSemibold)
                            Spacer()
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
                }

                if isUITesting {
                    editorialSuggestionProbe(
                        identifier: "defaultPanelSuggestionsSectionProbe",
                        value: "outer=none|featured=primary|count=\(items.count)|delta=\(String(format: "%.1f", defaultPanelSuggestionsWidthDeltaMetric))"
                    )
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    /// Filtered insights excluding dismissed suggestions
    private var visibleInsights: [FileInsight] {
        insights.filter { !dismissedInsightIDs.contains($0.id) }
    }

    private var editorialSuggestionItems: [DefaultPanelEditorialSuggestionItem] {
        let snapshots = DefaultPanelEditorialSuggestionFactory.build(
            promotion: dashboardViewModel.externalReviewPromotionSuggestion,
            insights: visibleInsights,
            patterns: suggestablePatterns
        )

        var actions: [String: () -> Void] = [:]

        if let promotionSuggestion = dashboardViewModel.externalReviewPromotionSuggestion {
            let promotionSnapshot = DefaultPanelEditorialSuggestionFactory.promotionSnapshot(for: promotionSuggestion)
            actions[promotionSnapshot.id] = {
                _ = dashboardViewModel.promoteExternalReviewFolder()
            }
        }

        let normalizedPatternTitles = Set(
            suggestablePatterns.map { DefaultPanelEditorialSuggestionFactory.normalizedTitle($0.patternDescription) }
        )

        for insight in visibleInsights where !normalizedPatternTitles.contains(
            DefaultPanelEditorialSuggestionFactory.normalizedTitle(insight.message)
        ) {
            actions[insight.id] = {
                handleEditorialInsightAction(insight)
            }
        }

        for pattern in suggestablePatterns {
            actions[pattern.id.uuidString] = {
                dashboardViewModel.createRuleFromPattern(pattern, context: modelContext)
            }
        }

        var items: [DefaultPanelEditorialSuggestionItem] = []
        for snapshot in snapshots {
            guard let action = actions[snapshot.id] else { continue }
            items.append(DefaultPanelEditorialSuggestionItem(snapshot: snapshot, action: action))
        }

        if items.isEmpty, isUITesting {
            return [
                DefaultPanelEditorialSuggestionItem(
                    snapshot: DefaultPanelEditorialSuggestionFactory.uiTestFeaturedSnapshot(),
                    action: { dashboardViewModel.showAnalyticsWorkspace() }
                )
            ]
        }

        return items
    }

    private var collapsedEditorialSuggestionLimit: Int {
        3
    }

    private var displayedEditorialSuggestionItems: [DefaultPanelEditorialSuggestionItem] {
        guard !showAllSuggestions else { return editorialSuggestionItems }
        return Array(editorialSuggestionItems.prefix(collapsedEditorialSuggestionLimit))
    }

    private func handleEditorialInsightAction(_ insight: FileInsight) {
        if let action = insight.action {
            action()
            return
        }

        switch insight.actionLabel {
        case "Create Rule", "Organize Together":
            nav.openRuleBuilderPanel(returnTarget: .defaultPanel)
            dashboardViewModel.showRuleBuilderPanel()
        case "Review", "Review Files", "Review Now":
            dashboardViewModel.showAnalyticsWorkspace()
        default:
            dashboardViewModel.showAnalyticsWorkspace()
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
        let total = currentPassTotalCount
        guard total > 0 else { return 1.0 }
        return dashboardViewModel.currentPassProgress
    }

    private var currentPassTotalCount: Int {
        dashboardViewModel.currentPassTotalCount
    }

    private var organizedFilesCount: Int {
        dashboardViewModel.currentPassOrganizedCount
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
        currentTaskProgressTone == .live
            ? RightRailSemanticTone.live.color
            : (
                colorScheme == .dark
                    ? Color.formaBoneWhite.opacity(0.82)
                    : Color.formaLabel.opacity(0.70)
            )
    }

    private var currentTaskProgressTone: RightRailSemanticTone {
        filterViewModel.cachedNeedsReviewCount == 0 ? .live : .progress
    }

    private var defaultPanelPrimaryActionContrastRatio: Double {
        let foreground = Color.formaSteelBlue
        let background = editorialAccentColor(.warm).opacity(colorScheme == .dark ? 0.16 : 0.11)
        return FormaContrastMetrics.contrastRatio(
            foreground: foreground,
            background: background,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var defaultPanelIgnoreContrastRatio: Double {
        let foreground = colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.84)
            : Color.formaObsidian.opacity(0.66)
        let background = editorialAccentColor(.warm).opacity(colorScheme == .dark ? 0.16 : 0.11)
        return FormaContrastMetrics.contrastRatio(
            foreground: foreground,
            background: background,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var defaultPanelHeroToAutomationMetric: Double {
        guard let heroFrame = uiTestSectionFrames[UITestSectionID.heroCard],
              let automationFrame = uiTestSectionFrames[UITestSectionID.automationCard] else {
            return -1
        }

        return Double(automationFrame.minY - heroFrame.maxY)
    }

    private var defaultPanelAutomationToSuggestionsMetric: Double {
        guard let automationFrame = uiTestSectionFrames[UITestSectionID.automationCard],
              let suggestionsFrame = uiTestSectionFrames[UITestSectionID.suggestionsCard] else {
            return -1
        }

        return Double(suggestionsFrame.minY - automationFrame.maxY)
    }

    private var defaultPanelAutomationWidthDeltaMetric: Double {
        guard let automationSectionFrame = uiTestSectionFrames[UITestSectionID.automationCard],
              let automationCardFrame = uiTestSectionFrames[UITestSectionID.automationVisibleCard] else {
            return -1
        }

        return abs(Double(automationSectionFrame.width - automationCardFrame.width))
    }

    private var defaultPanelAutomationWidthProbeText: String {
        let delta = defaultPanelAutomationWidthDeltaMetric
        return "delta=\(String(format: "%.1f", delta))"
    }

    private var defaultPanelSuggestionsWidthDeltaMetric: Double {
        guard let suggestionsSectionFrame = uiTestSectionFrames[UITestSectionID.suggestionsCard],
              let suggestionsCardFrame = uiTestSectionFrames[UITestSectionID.suggestionsVisibleCard] else {
            return -1
        }

        return abs(Double(suggestionsSectionFrame.width - suggestionsCardFrame.width))
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
                activities: analyticsViewModel.recentActivities,
                rules: [],
                precomputedClusters: analyticsViewModel.detectedClusters
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
    @Environment(\.rightPanelLayout) private var rightPanelLayout
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

    private var isCompactLayout: Bool {
        rightPanelLayout.isCompact
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
                            .frame(width: 40, height: 40)
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
                Group {
                    if isCompactLayout {
                        primaryActionButton(actionLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(spacing: FormaSpacing.tight) {
                            primaryActionButton(actionLabel)
                            Spacer()
                    }
                }
            }
        }
    }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func primaryActionButton(_ actionLabel: String) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(actionLabel)
                    .font(.formaSmallSemibold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(primaryActionTextColor)
            .frame(maxWidth: isCompactLayout ? .infinity : nil, alignment: .leading)
            .frame(minHeight: 40)
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)
            .background(primaryActionBackground)
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .pressAnimation()
    }
}

private struct FeaturedEditorialSuggestionCard: View {
    let snapshot: DefaultPanelEditorialSuggestionSnapshot
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rightPanelLayout) private var rightPanelLayout

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                editorialMetadataRow(snapshot: snapshot, metricFont: .formaSmallSemibold, tokenSize: 40)

                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text(snapshot.title)
                        .font(.formaCallout)
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(snapshot.summary)
                        .font(.formaBody)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(editorialWhyNowText(for: snapshot))
                        .font(.formaSmall)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: FormaSpacing.tight)

                editorialFooter(
                    actionTitle: snapshot.actionTitle,
                    accent: snapshot.accent
                )
            }
            .frame(maxWidth: .infinity, minHeight: rightPanelLayout.isCompact ? 176 : 188, alignment: .topLeading)
            .padding(FormaSpacing.standard)
            .background(featuredBackground)
            .overlay(featuredBorder)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .accessibilityIdentifier("defaultPanelFeaturedNextMove")
        .accessibilityValue(editorialSuggestionProbeValue(snapshot: snapshot, style: "featured"))
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }

    private var featuredBackground: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .fill(Color.formaSurfaceWork.opacity(colorScheme == .dark ? 0.72 : 0.94))
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                editorialAccentColor(snapshot.accent).opacity(colorScheme == .dark ? 0.14 : 0.075),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(
                        isHovered
                            ? Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.08 : 0.04)
                            : Color.clear
                    )
            )
    }

    private var featuredBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .strokeBorder(
                Color.formaObsidian.opacity(colorScheme == .dark ? 0.22 : 0.08),
                lineWidth: 1
            )
    }
}

private struct EditorialSuggestionCard: View {
    let snapshot: DefaultPanelEditorialSuggestionSnapshot
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                editorialMetadataRow(snapshot: snapshot, metricFont: .formaCaptionSemibold, tokenSize: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.title)
                        .font(.formaBodySemibold)
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(snapshot.summary)
                        .font(.formaSmall)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let whyNowText = snapshot.whyNowText {
                        Text(whyNowText)
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaTertiaryLabelHigh)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)

                editorialFooter(
                    actionTitle: snapshot.actionTitle,
                    accent: snapshot.accent
                )
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .padding(FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(
                        isHovered
                            ? Color.formaSurfaceWork.opacity(colorScheme == .dark ? 0.86 : 1.0)
                            : Color.formaSurfaceWork.opacity(colorScheme == .dark ? 0.68 : 0.84)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        Color.formaObsidian.opacity(
                            isHovered
                                ? (colorScheme == .dark ? 0.30 : 0.12)
                                : (colorScheme == .dark ? 0.20 : 0.07)
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }
}

private struct EditorialSuggestionToken: View {
    let snapshot: DefaultPanelEditorialSuggestionSnapshot
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(editorialAccentColor(snapshot.accent).opacity(Color.FormaOpacity.light))

            Image(systemName: snapshot.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(editorialAccentColor(snapshot.accent))
        }
        .frame(width: size, height: size)
    }
}

private func editorialMetadataRow(
    snapshot: DefaultPanelEditorialSuggestionSnapshot,
    metricFont: Font,
    tokenSize: CGFloat
) -> some View {
    HStack(alignment: .center, spacing: FormaSpacing.tight) {
        EditorialSuggestionToken(snapshot: snapshot, size: tokenSize)

        Text(snapshot.provenanceText.uppercased())
            .font(.formaCaptionSemibold)
            .tracking(0.4)
            .foregroundStyle(Color.formaTertiaryLabelHigh)
            .lineLimit(1)

        Spacer(minLength: FormaSpacing.tight)

        if let metricText = snapshot.metricText {
            Text(metricText)
                .font(metricFont)
                .foregroundStyle(editorialAccentColor(snapshot.accent))
                .lineLimit(1)
        }
    }
}

private func editorialFooter(
    actionTitle: String,
    accent: DefaultPanelEditorialSuggestionAccent
) -> some View {
    HStack(spacing: FormaSpacing.tight) {
        Text(actionTitle)
            .font(.formaCaptionSemibold)
            .foregroundStyle(editorialAccentColor(accent))
            .lineLimit(1)
            .minimumScaleFactor(0.84)

        Spacer(minLength: FormaSpacing.tight)

        Image(systemName: "arrow.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(editorialAccentColor(accent))
    }
    .padding(.top, FormaSpacing.tight)
    .overlay(alignment: .top) {
        Rectangle()
            .fill(Color.formaObsidian.opacity(0.16))
            .frame(height: 1)
    }
}

private func editorialWhyNowText(for snapshot: DefaultPanelEditorialSuggestionSnapshot) -> String {
    snapshot.whyNowText ?? "Why it matters: this is the clearest next move in the current queue."
}

private func editorialSuggestionProbeValue(
    snapshot: DefaultPanelEditorialSuggestionSnapshot,
    style: String
) -> String {
    [
        "style=\(style)",
        "provenance=\(editorialProbeText(snapshot.provenanceText))",
        "title=\(editorialProbeText(snapshot.title))",
        "summary=\(editorialProbeText(snapshot.summary))",
        "why=\(editorialProbeText(editorialWhyNowText(for: snapshot)))",
        "action=\(editorialProbeText(snapshot.actionTitle))",
        "metric=\(editorialProbeText(snapshot.metricText ?? "none"))"
    ].joined(separator: "|")
}

private func editorialSuggestionProbe(
    identifier: String,
    value: String
) -> some View {
    Color.clear
        .frame(width: 1, height: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(value)
        .accessibilityValue(value)
        .allowsHitTesting(false)
}

private func editorialProbeText(_ text: String) -> String {
    text.replacingOccurrences(of: "|", with: "/")
}

private func editorialAccentColor(_ accent: DefaultPanelEditorialSuggestionAccent) -> Color {
    switch accent {
    case .steelBlue:
        return RightRailSemanticTone.progress.color
    case .warm:
        return RightRailSemanticTone.blocked.color
    case .sage:
        return RightRailSemanticTone.live.color
    }
}


// MARK: - Category Stat Button (Clickable Filter)

struct HeroCategoryStatButton: View {
    let category: FileTypeCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var labelText: String {
        switch (category, count) {
        case (.archives, 1): return "Archive"
        case (.documents, 1): return "Doc"
        case (.images, 1): return "Image"
        case (.videos, 1): return "Video"
        case (.audio, 1): return "Audio"
        case (.documents, _): return "Docs"
        default: return category.displayName
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("\(count)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? RightRailSemanticTone.progress.color : Color.formaLabel)

                Text(labelText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabelHigh)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            .padding(.horizontal, 8)
            .background(
                Rectangle()
                    .fill(
                        isSelected
                            ? RightRailSemanticTone.progress.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                            : (
                                isHovered
                                    ? RightRailSemanticTone.progress.color.opacity(colorScheme == .dark ? 0.06 : 0.04)
                                    : Color.clear
                            )
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
        .accessibilityLabel("\(count) \(labelText)")
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

private struct DefaultPanelSectionFramesPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FileItem.self, Rule.self, ActivityItem.self, configurations: config)
    let viewModel = DashboardViewModel()

    DefaultPanelView()
        .environmentObject(viewModel)
        .environmentObject(viewModel.filterViewModel)
        .environmentObject(viewModel.analyticsViewModel)
        .environmentObject(NavigationViewModel())
        .modelContainer(container)
        .frame(width: 340, height: 800)
        .background(.regularMaterial)
}
