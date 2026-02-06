import Foundation
import SwiftUI
import SwiftData

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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Query private var allRules: [Rule]

    @Query private var categories: [RuleCategory]

    private var sortedAllRules: [Rule] {
        allRules.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.creationDate < rhs.creationDate
        }
    }

    private var sortedCategories: [RuleCategory] {
        categories.sortedByOrder
    }

    @State private var searchText = ""
    @State private var selectedCategoryID: UUID? // nil = "All" tab
    @State private var showManageCategories = false
    @State private var filterNeedsAccessOnly = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Namespace private var categoryTabNamespace
    private let destinationResolver = DestinationResolver()
    private let isUITesting = CommandLine.arguments.contains("--uitesting")
    private let listRowSpacing: CGFloat = FormaSpacing.tight
    private let listContentPadding: CGFloat = FormaSpacing.standard

    /// Rules filtered by search text and selected category
    var filteredRules: [Rule] {
        var rules = sortedAllRules

        // Filter by category if one is selected
        if let categoryID = selectedCategoryID {
            rules = rules.filter { $0.category?.id == categoryID }
        }

        if filterNeedsAccessOnly {
            rules = rules.filter { needsAccess($0) }
        }

        // Filter by search text
        if !searchText.isEmpty {
            rules = rules.filter { rule in
                rule.name.localizedCaseInsensitiveContains(searchText) ||
                rule.conditionValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        return rules
    }

    var enabledCount: Int {
        filteredRules.filter(\.isEnabled).count
    }

    var totalEnabledCount: Int {
        allRules.filter(\.isEnabled).count
    }

    private var needsAccessCount: Int {
        allRules.filter { needsAccess($0) }.count
    }

    private var isInitialEmptyState: Bool {
        sortedAllRules.isEmpty && searchText.isEmpty
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
    
    var body: some View {
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

                        Text("\(totalEnabledCount) active")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }

                    Spacer()

                    if !isInitialEmptyState {
                        PrimaryButton("New", icon: "plus") {
                            // Primary flow: open rule builder in right panel
                            dashboardViewModel.showRuleBuilderPanel()
                        }
                        .frame(width: 100)
                        .hoverLift(scale: 1.03, shadowRadius: 8)
                    }
                }
                
                // Combined Toolbar (Search + Tabs)
                if !isInitialEmptyState {
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
                        
                        // Filter Tabs (Compact)
                        if !sortedCategories.isEmpty {
                            categoryTabBar
                        }
                    }
                }
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.standard)

            if needsAccessCount > 0 {
                needsAccessBanner
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.bottom, FormaSpacing.standard)
            }

            Divider()
                .opacity(0.5)
            
            // Rules list
            if filteredRules.isEmpty {
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
                ScrollView {
                    LazyVStack(spacing: listRowSpacing) {
                        ForEach(filteredRules) { rule in
                            RuleManagementCard(
                                rule: rule,
                                onEdit: {
                                    // Primary flow: open rule builder in right panel for editing
                                    dashboardViewModel.showRuleBuilderPanel(editingRule: rule)
                                },
                                onDelete: {
                                    deleteRule(rule)
                                },
                                onToggle: {
                                    toggleRule(rule)
                                }
                            )
                            .draggable(rule.id.uuidString) {
                                // Drag preview
                                RuleManagementCard(
                                    rule: rule,
                                    onEdit: {},
                                    onDelete: {},
                                    onToggle: {}
                                )
                                .opacity(Color.FormaOpacity.prominent)
                                .frame(width: 300)
                            }
                            .dropDestination(for: String.self) { items, location in
                                guard let draggedId = items.first,
                                      let draggedUUID = UUID(uuidString: draggedId),
                                      draggedUUID != rule.id else {
                                    return false
                                }
                                reorderRule(draggedId: draggedUUID, targetId: rule.id)
                                return true
                            }
                        }
                    }
                    .padding(listContentPadding)
                }
                .accessibilityIdentifier("smartRulesListScroll")

                // Hint for drag reordering when not filtering
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
        .background(Color.clear) // Allow unified window glass to show through
        .sheet(isPresented: $showManageCategories) {
            ManageCategoriesSheet()
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
        HStack(spacing: 4) {
            // "All" tab
            CategoryTab(
                title: "All",
                count: allRules.count,
                color: .formaSecondaryLabel,
                iconName: nil, // Removed icon for cleaner look
                isSelected: selectedCategoryID == nil,
                namespace: categoryTabNamespace,
                tabID: "all"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedCategoryID = nil
                }
            }

            // Category tabs
            ForEach(sortedCategories) { category in
                CategoryTab(
                    title: category.name,
                    count: rulesInCategory(category),
                    color: category.color,
                    iconName: nil, // Removed icon
                    isSelected: selectedCategoryID == category.id,
                    namespace: categoryTabNamespace,
                    tabID: category.id.uuidString
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategoryID = category.id
                    }
                }
            }

            // Manage categories button
            Button {
                showManageCategories = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel)
                    .frame(width: 24, height: 24)
                    .background(Color.formaControlBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
    }

    // MARK: - Access Warnings

    private func needsAccess(_ rule: Rule) -> Bool {
        guard rule.actionType != .delete,
              let destination = rule.destination else {
            return false
        }

        let status = destinationResolver.checkResolvability(destination)
        if case .unresolvable = status {
            return true
        }
        return false
    }

    private var needsAccessBanner: some View {
        HStack(alignment: .center, spacing: FormaSpacing.standard) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.formaBodySemibold)
                .foregroundColor(.formaWarmOrange)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    FormaBadge(
                        text: "\(needsAccessCount)",
                        color: .formaWarmOrange,
                        size: .small,
                        style: .subtle
                    )
                    Text(needsAccessCount == 1 ? "rule needs folder access" : "rules need folder access")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaLabel)
                }

                Text("Review these rules to select accessible destinations.")
                    .font(.formaCaption)
                    .foregroundColor(colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel)
            }

            Spacer()

            Button(action: {
                if filterNeedsAccessOnly {
                    filterNeedsAccessOnly = false
                } else {
                    filterNeedsAccessOnly = true
                    selectedCategoryID = nil
                    searchText = ""
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: filterNeedsAccessOnly ? "xmark.circle.fill" : "arrow.right")
                        .font(.formaCaptionSemibold)
                    Text(filterNeedsAccessOnly ? "Show All" : "Review")
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
        allRules.filter { $0.category?.id == category.id }.count
    }

    private var starterTemplatesSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text("Starter templates")
                .font(.formaBodySemibold)
                .foregroundColor(.formaSecondaryLabelHigh)

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
    
    private func toggleRule(_ rule: Rule) {
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

    private func deleteRule(_ rule: Rule) {
        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.deleteRule(rule)
            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)
        } catch {
            Log.error("RulesManagementView: Failed to delete rule '\(rule.name)' - \(error.localizedDescription)", category: .analytics)
        }
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

// MARK: - Category Tab Component

/// A pill-shaped tab for category selection with morphing glass indicator.
///
/// Uses Forma's Liquid Glass design for smooth transitions between selected states.
private struct CategoryTab: View {
    let title: String
    let count: Int
    let color: Color
    let iconName: String?
    let isSelected: Bool
    let namespace: Namespace.ID
    let tabID: String
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var unselectedColor: Color {
        colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel
    }

    private var selectedTextColor: Color {
        colorScheme == .dark ? .formaLabel : .formaObsidian
    }

    private var hoverFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Category icon (optional)
                if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? color : unselectedColor)
                }

                // Category name
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? selectedTextColor : unselectedColor)

                // Count badge (subtle)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? color.opacity(0.85) : unselectedColor.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    Capsule()
                        .fill(color.opacity(Color.FormaOpacity.medium))
                        .matchedGeometryEffect(id: "categoryIndicator", in: namespace)
                } else if isHovered {
                    Capsule()
                        .fill(hoverFill)
                }
            }
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(Color.FormaOpacity.overlay) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
    }
}
