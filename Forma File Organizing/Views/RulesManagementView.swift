import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// View for managing all saved rules with create, edit, delete, and enable/disable functionality
struct RulesManagementView: View {
    private struct StarterTemplate: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let icon: String
        let accent: Color
        let trigger: String
        let outcome: String
        let prompt: String
    }

    private struct ContentState {
        let healthByID: [UUID: RuleHealthService.RuleHealth]
        let filteredRules: [Rule]
        let totalEnabledCount: Int
        let duplicateCount: Int
        let duplicateCleanupPlan: RuleHealthService.ExactDuplicateCleanupPlan?
        let overlapCount: Int
        let needsPermissionCount: Int
        let willCreateCount: Int
        let disabledCount: Int
        let recentlyTriggeredCount: Int
        let staleRuleCount: Int
        let stableRuleCount: Int
        let isInitialEmptyState: Bool
        let showsOperationalSections: Bool
        let duplicateRules: [Rule]
        let overlapRules: [Rule]
        let needsPermissionRules: [Rule]
        let willCreateRules: [Rule]
        let recentlyTriggeredRules: [Rule]
        let staleRules: [Rule]
        let stableRules: [Rule]
        let disabledRules: [Rule]
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Query private var allRules: [Rule]

    @Query private var categories: [RuleCategory]

    private var sortedAllRules: [Rule] {
        visibleAllRules.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.creationDate < rhs.creationDate
        }
    }

    private var sortedCategories: [RuleCategory] {
        categories.sortedByOrder
    }

    /// Categories that provide meaningful filtering (exclude if only one category holds all rules)
    private var meaningfulCategories: [RuleCategory] {
        let sorted = sortedCategories
        // If there's only one category and it contains all rules, no tab adds value
        if sorted.count <= 1 {
            return []
        }
        return sorted
    }

    @State private var searchText = ""
    @State private var selectedCategoryID: UUID? // nil = "All" tab
    @AppStorage(FolderHealthAlertSettings.Keys.staleRuleThresholdDays) private var staleRuleThresholdDaysStorage = 0
    @State private var showManageCategories = false
    @State private var filterNeedsPermissionOnly = false
    @State private var pendingDeletionRuleIDs: Set<UUID> = []
    @State private var duplicateCleanupConfirmationPlan: RuleHealthService.ExactDuplicateCleanupPlan?
    @State private var isDeletingDuplicateCopies = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    private let destinationResolver = DestinationResolver()
    private let ruleHealthService = RuleHealthService()
    private let isUITesting = CommandLine.arguments.contains("--uitesting")
    private let listRowSpacing: CGFloat = FormaSpacing.tight
    private let listContentPadding: CGFloat = FormaSpacing.standard

    private var visibleAllRules: [Rule] {
        allRules.filter { !pendingDeletionRuleIDs.contains($0.id) }
    }

    private let starterTemplates: [StarterTemplate] = [
        StarterTemplate(
            title: "Screenshots",
            detail: "Archive old screenshots",
            icon: "camera.viewfinder",
            accent: .formaSteelBlue,
            trigger: "If name contains Screenshot",
            outcome: "Move to Archives/Screenshots",
            prompt: "Move screenshots older than 14 days to Archives/Screenshots"
        ),
        StarterTemplate(
            title: "PDF Archive",
            detail: "Organize older PDFs",
            icon: "doc.text",
            accent: .formaSage,
            trigger: "If extension is pdf and older than 30 days",
            outcome: "Move to Documents/Archive",
            prompt: "Move PDF files older than 30 days to Documents/Archive"
        ),
        StarterTemplate(
            title: "Camera Roll",
            detail: "Sort phone images",
            icon: "photo.on.rectangle.angled",
            accent: .formaWarmOrange,
            trigger: "If filename starts with IMG_",
            outcome: "Move to Pictures/Camera Roll",
            prompt: "Move image files containing IMG_ to Pictures/Camera Roll"
        )
    ]

    private func health(for rule: Rule, in healthByID: [UUID: RuleHealthService.RuleHealth]) -> RuleHealthService.RuleHealth {
        healthByID[rule.id] ?? RuleHealthService.RuleHealth(kind: .ready, badgeLabel: nil, message: nil)
    }

    private func makeContentState() -> ContentState {
        let sortedRules = sortedAllRules
        let healthByID = ruleHealthService.classify(
            rules: sortedRules,
            staleRuleThresholdDays: configuredStaleRuleThresholdDays,
            evaluationDate: Date()
        )

        var filteredRules = sortedRules

        if let categoryID = selectedCategoryID {
            filteredRules = filteredRules.filter { $0.category?.id == categoryID }
        }

        if filterNeedsPermissionOnly {
            filteredRules = filteredRules.filter { health(for: $0, in: healthByID).kind == .needsPermission }
        }

        if !searchText.isEmpty {
            filteredRules = filteredRules.filter { rule in
                rule.name.localizedCaseInsensitiveContains(searchText) ||
                rule.conditionValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        let duplicateRules = filteredRules.filter { health(for: $0, in: healthByID).kind == .duplicate }
        let overlapRules = filteredRules.filter { health(for: $0, in: healthByID).kind == .overlap }
        let needsPermissionRules = filteredRules.filter { health(for: $0, in: healthByID).kind == .needsPermission }
        let willCreateRules = filteredRules.filter { health(for: $0, in: healthByID).kind == .willCreate }
        let recentlyTriggeredRules = filteredRules.filter { rule in
            health(for: rule, in: healthByID).kind == .ready && wasTriggeredRecently(rule)
        }
        let staleRules = filteredRules.filter { health(for: $0, in: healthByID).kind == .stale }
        let stableRules = filteredRules.filter { rule in
            health(for: rule, in: healthByID).kind == .ready && !wasTriggeredRecently(rule)
        }
        let disabledRules = filteredRules.filter { health(for: $0, in: healthByID).kind == .disabled }

        return ContentState(
            healthByID: healthByID,
            filteredRules: filteredRules,
            totalEnabledCount: sortedRules.filter(\.isEnabled).count,
            duplicateCount: sortedRules.filter { health(for: $0, in: healthByID).kind == .duplicate }.count,
            duplicateCleanupPlan: ruleHealthService.exactDuplicateCleanupPlan(duplicateRules: duplicateRules),
            overlapCount: sortedRules.filter { health(for: $0, in: healthByID).kind == .overlap }.count,
            needsPermissionCount: sortedRules.filter { health(for: $0, in: healthByID).kind == .needsPermission }.count,
            willCreateCount: sortedRules.filter { health(for: $0, in: healthByID).kind == .willCreate }.count,
            disabledCount: sortedRules.filter { health(for: $0, in: healthByID).kind == .disabled }.count,
            recentlyTriggeredCount: sortedRules.filter { rule in
                health(for: rule, in: healthByID).kind == .ready && wasTriggeredRecently(rule)
            }.count,
            staleRuleCount: sortedRules.filter { health(for: $0, in: healthByID).kind == .stale }.count,
            stableRuleCount: sortedRules.filter { rule in
                health(for: rule, in: healthByID).kind == .ready && !wasTriggeredRecently(rule)
            }.count,
            isInitialEmptyState: sortedRules.isEmpty && searchText.isEmpty,
            showsOperationalSections: searchText.isEmpty && selectedCategoryID == nil && !filterNeedsPermissionOnly && !sortedRules.isEmpty,
            duplicateRules: duplicateRules,
            overlapRules: overlapRules,
            needsPermissionRules: needsPermissionRules,
            willCreateRules: willCreateRules,
            recentlyTriggeredRules: recentlyTriggeredRules,
            staleRules: staleRules,
            stableRules: stableRules,
            disabledRules: disabledRules
        )
    }
    
    var body: some View {
        let content = makeContentState()

        VStack(spacing: 0) {
            // Align with MainContentView's toolbar position (traffic lights clearance)
            Color.clear.frame(height: FormaSpacing.Toolbar.topOffset)

            // Header
            VStack(spacing: FormaSpacing.standard) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Rules")
                            .font(.formaH1)
                            .foregroundColor(.formaLabel)

                        Text("\(content.totalEnabledCount) active")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }

                    Spacer()

                    if !content.isInitialEmptyState {
                        PrimaryButton("New", icon: "plus") {
                            // Primary flow: open rule builder in right panel
                            dashboardViewModel.showRuleBuilderPanel()
                        }
                        .frame(width: 100)
                        .hoverLift(scale: 1.03, shadowRadius: 8)
                    }
                }
                
                // Combined Toolbar (Search + Tabs)
                if !content.isInitialEmptyState {
                    HStack(spacing: 8) {
                        // Search Field (Compact)
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.formaSecondaryLabelHigh)
                                .font(.system(size: 14))
                            
                            TextField("Search...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.formaBody)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.formaTertiaryLabelHigh)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.formaControlBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.formaSeparator, lineWidth: 0.5)
                        )
                        .frame(width: 200)
                        .accessibilityIdentifier("smartRulesSearchBar")
                        
                        Spacer()
                        
                        // Filter Tabs (Compact) — only show when multiple categories exist
                        if !meaningfulCategories.isEmpty {
                            categoryTabBar
                        }
                    }
                }
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.standard)

            if !content.isInitialEmptyState {
                rulesOverviewStrip(content: content)
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.bottom, FormaSpacing.standard)
            }

            if !content.needsPermissionRules.isEmpty {
                needsPermissionBanner(count: content.needsPermissionRules.count)
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.bottom, FormaSpacing.standard)
            }

            if !content.willCreateRules.isEmpty {
                willCreateBanner(
                    count: content.willCreateRules.count,
                    createAction: { createResolvableFoldersNow(rules: content.willCreateRules) }
                )
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.bottom, FormaSpacing.standard)
            }

            Divider()
                .opacity(0.5)
            
            // Rules list
            if content.filteredRules.isEmpty {
                if searchText.isEmpty {
                    VStack(spacing: FormaSpacing.generous) {
                        FormaEmptyState(
                            title: "No Rules Yet",
                            message: "Create your first rule to automatically organize files.",
                            actionTitle: "Create Rule",
                            action: {
                                // Primary flow: open rule builder in right panel
                                dashboardViewModel.showRuleBuilderPanel()
                            }
                        )

                        starterTemplatesSection
                            .padding(.horizontal, FormaSpacing.generous)
                    }
                } else {
                    FormaEmptyState(
                        title: "No Matching Rules",
                        message: "Try a different search term.",
                        actionTitle: "Clear Search",
                        action: { searchText = "" }
                    )
                }
            } else {
                if content.showsOperationalSections {
                    sectionedRulesList(content: content)
                } else {
                    flatRulesList(rules: content.filteredRules, healthByID: content.healthByID)
                }
            }
        }
        .background(Color.clear) // Allow unified window glass to show through
        .sheet(isPresented: $showManageCategories) {
            ManageCategoriesSheet()
        }
        .onChange(of: allRules.map(\.id)) { _, remainingRuleIDs in
            pendingDeletionRuleIDs.formIntersection(Set(remainingRuleIDs))
        }
        .accessibilityIdentifier("smartRulesView")
        .overlay(alignment: .topLeading) {
            if isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("smartRulesContrastProbe")
                    .accessibilityLabel(
                        "titleOnCard=\(String(format: "%.2f", titleOnCardContrastRatio));secondaryOnCard=\(String(format: "%.2f", secondaryOnCardContrastRatio));bodyOnBanner=\(String(format: "%.2f", needsAccessBodyContrastRatio));rowSpacing=\(Int(listRowSpacing));rowVerticalPadding=\(Int(RuleManagementCard.verticalPadding));listPadding=\(Int(listContentPadding))"
                    )
            }
        }
    }

    // MARK: - Category Tab Bar

    private var categoryTabBar: some View {
        HStack(spacing: 8) {
            let options: [UUID?] = [nil] + meaningfulCategories.map { $0.id }
            Picker("Rule Category", selection: $selectedCategoryID) {
                ForEach(options, id: \.self) { option in
                    Text(categoryTabTitle(for: option))
                        .tag(option as UUID?)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            // Manage categories button
            Button {
                showManageCategories = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Manage categories")
        }
    }

    private func categoryTabTitle(for option: UUID?) -> String {
        if option == nil {
            return allRules.isEmpty ? "All" : "All \(allRules.count)"
        }

        guard
            let option,
            let category = meaningfulCategories.first(where: { $0.id == option })
        else {
            return "Category"
        }

        let count = rulesInCategory(category)
        return count > 0 ? "\(category.name) \(count)" : category.name
    }

    // MARK: - Rule Health

    private func needsPermissionBanner(count: Int) -> some View {
        HStack(alignment: .center, spacing: FormaSpacing.standard) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.formaBodySemibold)
                .foregroundColor(.formaWarmOrange)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    FormaBadge(
                        text: "\(count)",
                        color: .formaWarmOrange,
                        size: .small,
                        style: .subtle
                    )
                    Text(count == 1 ? "rule needs permission" : "rules need permission")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaLabel)
                }

                Text("These destinations are outside the folders Forma can currently access.")
                    .font(.formaCaption)
                    .foregroundColor(colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel)
            }

            Spacer()

            Button(action: {
                if filterNeedsPermissionOnly {
                    filterNeedsPermissionOnly = false
                } else {
                    filterNeedsPermissionOnly = true
                    selectedCategoryID = nil
                    searchText = ""
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: filterNeedsPermissionOnly ? "xmark.circle.fill" : "arrow.right")
                        .font(.formaCaptionSemibold)
                    Text(filterNeedsPermissionOnly ? "Show All" : "Review")
                        .font(.formaCaptionSemibold)
                }
                .foregroundColor(.formaWarmOrange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.formaWarmOrange.opacity(colorScheme == .dark ? 0.2 : Color.FormaOpacity.light))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.formaWarmOrange.opacity(colorScheme == .dark ? 0.55 : Color.FormaOpacity.overlay), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaWarmOrange.opacity(colorScheme == .dark ? 0.09 : Color.FormaOpacity.ultraSubtle))
        .cornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaWarmOrange.opacity(colorScheme == .dark ? 0.3 : Color.FormaOpacity.light), lineWidth: 1)
        )
        .accessibilityIdentifier("smartRulesNeedsAccessBanner")
        .accessibilityLabel(
            isUITesting
                ? "bodyOnBanner=\(String(format: "%.2f", needsAccessBodyContrastRatio))"
                : ""
        )
        .accessibilityValue(
            isUITesting
                ? "bodyOnBanner=\(String(format: "%.2f", needsAccessBodyContrastRatio))"
                : ""
        )
        .overlay {
            if isUITesting {
                Color.clear
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("smartRulesNeedsAccessBannerProbe")
                    .accessibilityLabel("bodyOnBanner=\(String(format: "%.2f", needsAccessBodyContrastRatio))")
            }
        }
    }

    private func willCreateBanner(count: Int, createAction: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: FormaSpacing.standard) {
            Image(systemName: "folder.badge.plus")
                .font(.formaBodySemibold)
                .foregroundColor(.formaSteelBlue)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    FormaBadge(
                        text: "\(count)",
                        color: .formaSteelBlue,
                        size: .small,
                        style: .subtle
                    )
                    Text(count == 1 ? "rule can create its folder" : "rules can create their folders")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaLabel)
                }

                Text("Forma already has the right parent-folder access. Create these destinations now, or they will be created the next time you save/edit those rules.")
                    .font(.formaCaption)
                    .foregroundColor(colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel)
            }

            Spacer()

            Button(action: createAction) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.formaCaptionSemibold)
                    Text("Create Folders Now")
                        .font(.formaCaptionSemibold)
                }
                .foregroundColor(.formaSteelBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.2 : Color.FormaOpacity.light))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.55 : Color.FormaOpacity.overlay), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.09 : Color.FormaOpacity.ultraSubtle))
        .cornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.3 : Color.FormaOpacity.light), lineWidth: 1)
        )
    }

    private func rulesOverviewStrip(content: ContentState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FormaSpacing.tight) {
                overviewPill(
                    title: "Duplicates",
                    count: content.duplicateCount,
                    color: .formaError,
                    isEmphasized: content.duplicateCount > 0
                )
                overviewPill(
                    title: "Overlaps",
                    count: content.overlapCount,
                    color: .formaWarmOrange,
                    isEmphasized: content.overlapCount > 0
                )
                overviewPill(
                    title: "Needs permission",
                    count: content.needsPermissionCount,
                    color: .formaWarmOrange,
                    isEmphasized: content.needsPermissionCount > 0
                )
                overviewPill(
                    title: "Will create",
                    count: content.willCreateCount,
                    color: .formaSteelBlue,
                    isEmphasized: content.willCreateCount > 0
                )
                overviewPill(
                    title: "Recently triggered",
                    count: content.recentlyTriggeredCount,
                    color: .formaSteelBlue,
                    isEmphasized: content.recentlyTriggeredCount > 0
                )
                overviewPill(
                    title: "Stale",
                    count: content.staleRuleCount,
                    color: .formaWarmOrange,
                    isEmphasized: content.staleRuleCount > 0
                )
                overviewPill(
                    title: "Stable",
                    count: content.stableRuleCount,
                    color: .formaSage,
                    isEmphasized: content.stableRuleCount > 0
                )
                overviewPill(
                    title: "Disabled",
                    count: content.disabledCount,
                    color: .formaSecondaryLabelHigh,
                    isEmphasized: content.disabledCount > 0
                )
            }
        }
    }

    private func overviewPill(title: String, count: Int, color: Color, isEmphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.formaCaptionSemibold)
                .foregroundColor(.formaSecondaryLabelHigh)
            Text("\(count)")
                .font(.formaBodyBold)
                .foregroundColor(isEmphasized ? color : .formaLabel)
        }
        .padding(.horizontal, FormaSpacing.standard)
        .padding(.vertical, FormaSpacing.tight)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(color.opacity(isEmphasized ? Color.FormaOpacity.light : Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(color.opacity(isEmphasized ? Color.FormaOpacity.strong : Color.FormaOpacity.light), lineWidth: 1)
        )
    }

    private func flatRulesList(
        rules: [Rule],
        healthByID: [UUID: RuleHealthService.RuleHealth]
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: listRowSpacing) {
                ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                    HStack(alignment: .center, spacing: FormaSpacing.tight) {
                        if searchText.isEmpty && !filterNeedsPermissionOnly {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel)
                                .frame(width: 20, alignment: .trailing)
                        }

                        ruleCardRow(rule, health: health(for: rule, in: healthByID))
                            .blockWindowDrag()
                            .onDrag {
                                NSItemProvider(object: rule.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: RuleDropDelegate(
                                targetRule: rule,
                                allRules: allRules,
                                onReorder: { draggedId, targetId in
                                    reorderRule(draggedId: draggedId, targetId: targetId)
                                }
                            ))
                    }
                }
            }
            .padding(listContentPadding)
        }
        .accessibilityIdentifier("smartRulesListScroll")
        .safeAreaInset(edge: .bottom) {
            if searchText.isEmpty && allRules.count > 1 {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.formaSmall)
                    Text("Drag to reorder rule priority")
                        .font(.formaCaption)
                }
                .foregroundColor(.formaSecondaryLabelHigh)
                .padding(.bottom, FormaSpacing.standard)
            }
        }
    }

    private func sectionedRulesList(content: ContentState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaSpacing.large) {
                if !content.duplicateRules.isEmpty {
                    duplicateRuleSection(content: content)
                }

                if !content.overlapRules.isEmpty {
                    ruleSection(
                        title: "Overlaps",
                        subtitle: "Rules that may compete for some of the same files and need review before cleanup.",
                        rules: content.overlapRules,
                        healthByID: content.healthByID
                    )
                }

                if !content.needsPermissionRules.isEmpty {
                    ruleSection(
                        title: "Needs Permission",
                        subtitle: "Rules pointed at destinations outside Forma's current folder access.",
                        rules: content.needsPermissionRules,
                        healthByID: content.healthByID
                    )
                }

                if !content.willCreateRules.isEmpty {
                    ruleSection(
                        title: "Will Create",
                        subtitle: "Rules with valid parent access whose destination folders can be created on demand.",
                        rules: content.willCreateRules,
                        healthByID: content.healthByID
                    )
                }

                if !content.recentlyTriggeredRules.isEmpty {
                    ruleSection(
                        title: "Recently Triggered",
                        subtitle: "Rules Forma has used recently.",
                        rules: content.recentlyTriggeredRules,
                        healthByID: content.healthByID
                    )
                }

                if !content.staleRules.isEmpty {
                    ruleSection(
                        title: "Stale",
                        subtitle: "Enabled rules that have not matched within your configured alert window.",
                        rules: content.staleRules,
                        healthByID: content.healthByID
                    )
                }

                if !content.stableRules.isEmpty {
                    ruleSection(
                        title: "Stable",
                        subtitle: "Active rules ready for background organization.",
                        rules: content.stableRules,
                        healthByID: content.healthByID
                    )
                }

                if !content.disabledRules.isEmpty {
                    ruleSection(
                        title: "Disabled",
                        subtitle: "Rules kept for later but not currently running.",
                        rules: content.disabledRules,
                        healthByID: content.healthByID
                    )
                }
            }
            .padding(listContentPadding)
        }
        .accessibilityIdentifier("smartRulesListScroll")
    }

    private func duplicateRuleSection(content: ContentState) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duplicates")
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaLabel)
                    Text("Rules with identical conditions and destination. Safe to delete extra copies.")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabelHigh)
                }

                Spacer(minLength: FormaSpacing.tight)

                if let cleanupPlan = content.duplicateCleanupPlan,
                   cleanupPlan.duplicateCount > 0 {
                    Button {
                        duplicateCleanupConfirmationPlan = cleanupPlan
                    } label: {
                        HStack(spacing: 6) {
                            if isDeletingDuplicateCopies {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                            }

                            Text(isDeletingDuplicateCopies ? "Deleting..." : "Delete \(cleanupPlan.duplicateCount) Extras")
                                .font(.formaCaptionSemibold)
                        }
                        .foregroundColor(.formaError)
                        .padding(.horizontal, FormaSpacing.standard)
                        .padding(.vertical, FormaSpacing.tight)
                        .background(Color.formaError.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                .stroke(Color.formaError.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeletingDuplicateCopies)
                }
            }

            LazyVStack(spacing: listRowSpacing) {
                ForEach(content.duplicateRules, id: \.id) { rule in
                    ruleCardRow(rule, health: health(for: rule, in: content.healthByID))
                }
            }
        }
        .alert(item: $duplicateCleanupConfirmationPlan) { cleanupPlan in
            Alert(
                title: Text("Delete Duplicate Rules"),
                message: Text("Delete \(cleanupPlan.duplicateCount) duplicate rule\(cleanupPlan.duplicateCount == 1 ? "" : "s") and keep \(cleanupPlan.preservedRuleCount) original\(cleanupPlan.preservedRuleCount == 1 ? "" : "s")?"),
                primaryButton: .destructive(Text("Delete Extras")) {
                    deleteDuplicateCopies(cleanupPlan)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func ruleSection(
        title: String,
        subtitle: String,
        rules: [Rule],
        healthByID: [UUID: RuleHealthService.RuleHealth]
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
                Text(subtitle)
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }

            LazyVStack(spacing: listRowSpacing) {
                ForEach(rules, id: \.id) { rule in
                    ruleCardRow(rule, health: health(for: rule, in: healthByID))
                }
            }
        }
    }

    private func ruleCardRow(_ rule: Rule, health: RuleHealthService.RuleHealth) -> some View {
        let snapshot = RuleManagementCard.Snapshot(rule: rule, health: health)

        return RuleManagementCard(
            snapshot: snapshot,
            onEdit: {
                guard let liveRule = liveRule(withID: snapshot.id) else { return }
                dashboardViewModel.showRuleBuilderPanel(editingRule: liveRule)
            },
            onDelete: {
                deleteRule(id: snapshot.id, fallbackName: snapshot.name)
            },
            onToggle: {
                toggleRule(id: snapshot.id)
            }
        )
    }

    @MainActor
    private func createResolvableFoldersNow(rules: [Rule]) {
        guard !rules.isEmpty else { return }

        var createdCount = 0
        var failureCount = 0

        for rule in rules {
            guard let destination = rule.destination else { continue }

            do {
                let resolvedDestination = try destinationResolver.materializeForExplicitSave(destination)
                if let resolvedDestination, resolvedDestination != rule.destination {
                    rule.destination = resolvedDestination
                    createdCount += 1
                }
            } catch {
                failureCount += 1
                Log.warning(
                    "RulesManagementView: Failed to materialize '\(rule.name)' destination '\(destination.displayName)' - \(error.localizedDescription)",
                    category: .bookmark
                )
            }
        }

        guard createdCount > 0 else { return }

        do {
            try modelContext.save()
            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)

            let message: String
            if failureCount > 0 {
                message = "Created \(createdCount) folder\(createdCount == 1 ? "" : "s"); \(failureCount) still need review."
            } else {
                message = "Created \(createdCount) folder\(createdCount == 1 ? "" : "s")."
            }
            dashboardViewModel.showCelebrationPanel(message: message)
        } catch {
            Log.error(
                "RulesManagementView: Failed saving materialized destinations - \(error.localizedDescription)",
                category: .analytics
            )
        }
    }

    private var needsAccessBodyContrastRatio: Double {
        let foreground = colorScheme == .dark ? Color.formaSecondaryLabelHigh : Color.formaSecondaryLabel
        let background = Color.formaWarmOrange.opacity(colorScheme == .dark ? 0.09 : Color.FormaOpacity.ultraSubtle)
        return FormaContrastMetrics.contrastRatio(
            foreground: foreground,
            background: background,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var titleOnCardContrastRatio: Double {
        FormaContrastMetrics.contrastRatio(
            foreground: .formaLabel,
            background: cardBackgroundColor,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var secondaryOnCardContrastRatio: Double {
        let foreground = colorScheme == .dark ? Color.formaSecondaryLabelHigh : Color.formaSecondaryLabel
        return FormaContrastMetrics.contrastRatio(
            foreground: foreground,
            background: cardBackgroundColor,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.06) : .formaBoneWhite
    }

    private func rulesInCategory(_ category: RuleCategory) -> Int {
        sortedAllRules.filter { $0.category?.id == category.id }.count
    }

    private func wasTriggeredRecently(_ rule: Rule) -> Bool {
        guard let lastTriggeredDate = rule.lastTriggeredDate,
              let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
            return false
        }
        return lastTriggeredDate >= cutoff
    }

    private var configuredStaleRuleThresholdDays: Int? {
        staleRuleThresholdDaysStorage > 0 ? staleRuleThresholdDaysStorage : nil
    }

    private var starterTemplatesSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quick starts")
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
                Text("Common cleanup rules you can turn into working automation.")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }

            HStack(spacing: FormaSpacing.tight) {
                ForEach(starterTemplates) { template in
                    starterTemplateCard(template)
                }
            }
        }
    }

    private func starterTemplateCard(_ template: StarterTemplate) -> some View {
        Button {
            openStarterTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                HStack(alignment: .center, spacing: FormaSpacing.tight) {
                    Image(systemName: template.icon)
                        .font(.formaBodySemibold)
                        .foregroundColor(template.accent)
                        .frame(width: 24, height: 24)
                        .background(template.accent.opacity(colorScheme == .dark ? 0.18 : 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.title)
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaLabel)
                        Text(template.detail)
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ruleSnippet(label: "When", text: template.trigger)
                    ruleSnippet(label: "Then", text: template.outcome)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Text("Use Template")
                        .font(.formaCaptionSemibold)
                    Image(systemName: "arrow.right")
                        .font(.formaMicro)
                }
                .foregroundColor(.formaSteelBlue)
            }
            .frame(maxWidth: .infinity, minHeight: 152, maxHeight: 152, alignment: .topLeading)
            .padding(FormaSpacing.standard)
            .background(cardBackgroundColor)
            .cornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func ruleSnippet(label: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.formaMicro)
                .fontWeight(.semibold)
                .foregroundColor(.formaSecondaryLabelHigh)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.formaControlBackground)
                .clipShape(Capsule())

            Text(text)
                .font(.formaCaption)
                .foregroundColor(.formaSecondaryLabelHigh)
                .lineLimit(2)
        }
    }

    private func openStarterTemplate(_ template: StarterTemplate) {
        nav.editingRule = nil
        nav.ruleEditorFileContext = nil
        nav.ruleEditorSuggestedText = template.prompt
        withAnimation(.easeInOut(duration: 0.2)) {
            nav.isShowingRuleEditor = true
        }
    }
    
    private func liveRule(withID id: UUID) -> Rule? {
        allRules.first { $0.id == id }
    }

    private func toggleRule(id: UUID) {
        guard let rule = liveRule(withID: id) else { return }
        rule.isEnabled.toggle()
        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.updateRule(rule)
            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)
        } catch {
            Log.error("RulesManagementView: Failed to toggle rule '\(rule.name)' - \(error.localizedDescription)", category: .analytics)
            // Revert the toggle since save failed
            rule.isEnabled.toggle()
        }
    }

    private func deleteRule(id: UUID, fallbackName: String) {
        guard let rule = liveRule(withID: id) else { return }

        pendingDeletionRuleIDs.insert(id)
        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.deleteRule(rule)
            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)
        } catch {
            pendingDeletionRuleIDs.remove(id)
            Log.error("RulesManagementView: Failed to delete rule '\(fallbackName)' - \(error.localizedDescription)", category: .analytics)
        }
    }

    private func deleteDuplicateCopies(_ cleanupPlan: RuleHealthService.ExactDuplicateCleanupPlan) {
        let ruleIDsToDelete = Set(cleanupPlan.duplicateRuleIDs)
        let rulesToDelete = sortedAllRules.filter { ruleIDsToDelete.contains($0.id) }

        guard !rulesToDelete.isEmpty else { return }

        isDeletingDuplicateCopies = true
        pendingDeletionRuleIDs.formUnion(ruleIDsToDelete)

        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.deleteRules(rulesToDelete)
            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)
            dashboardViewModel.showCelebrationPanel(
                message: "Deleted \(rulesToDelete.count) duplicate rule\(rulesToDelete.count == 1 ? "" : "s")."
            )
        } catch {
            pendingDeletionRuleIDs.subtract(ruleIDsToDelete)
            Log.error("RulesManagementView: Failed to bulk delete duplicate rules - \(error.localizedDescription)", category: .analytics)
        }

        isDeletingDuplicateCopies = false
    }

    /// Reorders rules by updating their sortOrder values.
    /// The dragged rule is moved to the position of the target rule.
    private func reorderRule(draggedId: UUID, targetId: UUID) {
        guard let draggedIndex = allRules.firstIndex(where: { $0.id == draggedId }),
              let targetIndex = allRules.firstIndex(where: { $0.id == targetId }) else {
            return
        }

        // Create a mutable copy of the rules array
        var reorderedRules = allRules

        // Move the dragged rule to the target position
        let draggedRule = reorderedRules.remove(at: draggedIndex)
        reorderedRules.insert(draggedRule, at: targetIndex)

        // Update sortOrder for all rules based on new positions
        let ruleService = RuleService(modelContext: modelContext)
        do {
            try ruleService.updateRulePriorities(reorderedRules)
            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)
        } catch {
            Log.error("RulesManagementView: Failed to reorder rules - \(error.localizedDescription)", category: .analytics)
        }
    }
}

// MARK: - Drag-to-Reorder Drop Delegate

/// Uses the older onDrag/onDrop API to avoid the macOS window-drag conflict
/// that occurs with SwiftUI's `.draggable()` in unified title bar windows.
private struct RuleDropDelegate: DropDelegate {
    let targetRule: Rule
    let allRules: [Rule]
    let onReorder: (UUID, UUID) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else {
            return false
        }
        let targetRuleID = targetRule.id

        // Load the dragged rule ID asynchronously
        _ = provider.loadObject(ofClass: NSString.self) { nsString, _ in
            guard let idString = nsString as? String,
                  let draggedUUID = UUID(uuidString: idString),
                  draggedUUID != targetRuleID else {
                return
            }
            DispatchQueue.main.async {
                onReorder(draggedUUID, targetRuleID)
            }
        }
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {
        // Optional: could add hover highlight here
    }
}
