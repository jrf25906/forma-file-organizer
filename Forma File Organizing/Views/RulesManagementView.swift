import SwiftUI
import SwiftData

/// View for managing all saved rules with create, edit, delete, and enable/disable functionality
struct RulesManagementView: View {
    @Environment(\.modelContext) private var modelContext
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
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Namespace private var categoryTabNamespace

    /// Rules filtered by search text and selected category
    var filteredRules: [Rule] {
        var rules = sortedAllRules

        // Filter by category if one is selected
        if let categoryID = selectedCategoryID {
            rules = rules.filter { $0.category?.id == categoryID }
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
                            .foregroundColor(.formaObsidian)

                        Text("\(totalEnabledCount) active")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabel)
                    }

                    Spacer()

                    PrimaryButton("New", icon: "plus") {
                        // Primary flow: open rule builder in right panel
                        dashboardViewModel.showRuleBuilderPanel()
                    }
                    .frame(width: 100)
                    .hoverLift(scale: 1.03, shadowRadius: 8)
                }
                
                // Combined Toolbar (Search + Tabs)
                HStack(spacing: 8) {
                    // Search Field (Compact)
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.formaSecondaryLabel)
                            .font(.system(size: 14))
                        
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.formaBody)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.formaTertiaryLabel)
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
                    
                    Spacer()
                    
                    // Filter Tabs (Compact)
                    if !sortedCategories.isEmpty {
                        categoryTabBar
                    }
                }
            }
            .padding(FormaSpacing.generous)

            Divider()
                .opacity(0.5)
            
            // Rules list
            if filteredRules.isEmpty {
                if searchText.isEmpty {
                    FormaEmptyState(
                        title: "No Rules Yet",
                        message: "Create your first rule to automatically organize files.",
                        actionTitle: "Create Rule",
                        action: {
                            // Primary flow: open rule builder in right panel
                            dashboardViewModel.showRuleBuilderPanel()
                        }
                    )
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
                    LazyVStack(spacing: 12) { // Tighter list spacing
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
                    .padding(FormaSpacing.generous)
                }

                // Hint for drag reordering when not filtering
                if searchText.isEmpty && allRules.count > 1 {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.formaSmall)
                        Text("Drag to reorder rule priority")
                            .font(.formaCaption)
                    }
                    .foregroundColor(.formaSecondaryLabel)
                    .padding(.bottom, FormaSpacing.standard)
                }
            }
        }
        .background(Color.clear) // Allow unified window glass to show through
        .sheet(isPresented: $showManageCategories) {
            ManageCategoriesSheet()
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
                    .foregroundColor(.formaSecondaryLabel)
                    .frame(width: 24, height: 24)
                    .background(Color.formaControlBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
    }

    private func rulesInCategory(_ category: RuleCategory) -> Int {
        allRules.filter { $0.category?.id == category.id }.count
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Category icon (optional)
                if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? color : .formaSecondaryLabel)
                }

                // Category name
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .formaObsidian : .formaSecondaryLabel)

                // Count badge (subtle)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? color.opacity(0.8) : .formaSecondaryLabel.opacity(0.7))
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
                        .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
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
