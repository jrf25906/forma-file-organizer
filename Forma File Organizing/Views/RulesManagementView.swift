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
                        
                        // Filter Tabs (Compact) — only show when multiple categories exist
                        if !meaningfulCategories.isEmpty {
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
                        ForEach(Array(filteredRules.enumerated()), id: \.element.id) { index, rule in
                            HStack(alignment: .center, spacing: FormaSpacing.tight) {
                                // Priority number — visible when not searching
                                if searchText.isEmpty && !filterNeedsAccessOnly {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel)
                                        .frame(width: 20, alignment: .trailing)
                                }

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
                            }
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
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                // "All" tab
                CategoryTab(
                    title: "All",
                    count: allRules.count,
                    color: .formaSecondaryLabel,
                    iconName: nil,
                    isSelected: selectedCategoryID == nil,
                    namespace: categoryTabNamespace,
                    tabID: "all"
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategoryID = nil
                    }
                }

                if !meaningfulCategories.isEmpty {
                    categoryTabDivider
                }

                // Category tabs
                ForEach(Array(meaningfulCategories.enumerated()), id: \.element.id) { index, category in
                    CategoryTab(
                        title: category.name,
                        count: rulesInCategory(category),
                        color: category.color,
                        iconName: nil,
                        isSelected: selectedCategoryID == category.id,
                        namespace: categoryTabNamespace,
                        tabID: category.id.uuidString
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategoryID = category.id
                        }
                    }

                    if index < meaningfulCategories.count - 1 {
                        categoryTabDivider
                    }
                }
            }
            .padding(3)
            .background {
                StocksStyleRulesCapsuleBackground(cornerRadius: 17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(categoryTopRimColor, lineWidth: 0.6)
                    )
            }
            .fixedSize(horizontal: true, vertical: false)

            // Manage categories button
            StocksStyleRulesIconButton(
                icon: "slider.horizontal.3",
                help: "Manage categories"
            ) {
                showManageCategories = true
            }
        }
    }

    private var categoryTabDivider: some View {
        Rectangle()
            .fill(categorySeparatorColor)
            .frame(width: 1, height: 22)
            .allowsHitTesting(false)
    }

    private var categorySeparatorColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.20)
    }

    private var categoryTopRimColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaBoneWhite.opacity(0.45)
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

// MARK: - Window-Drag Prevention

/// An NSView subclass that returns `false` for `mouseDownCanMoveWindow`,
/// preventing `isMovableByWindowBackground` from intercepting drag gestures
/// on child SwiftUI views (e.g., rule cards that support onDrag reordering).
private class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

/// Wraps a SwiftUI view in a layer that blocks window-background dragging,
/// allowing system drag-and-drop (onDrag/onDrop) to work correctly.
private struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NonDraggableNSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Prevents `isMovableByWindowBackground` from capturing mouse events on this view.
    fileprivate func blockWindowDrag() -> some View {
        self.background(WindowDragBlocker())
    }
}

// MARK: - Category Tab Component

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

    private let selectedCornerRadius: CGFloat = 13
    private let segmentHeight: CGFloat = 30
    private let segmentPlateHorizontalInset: CGFloat = 4
    private let segmentPlateVerticalInset: CGFloat = 1.5

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(activeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(activeBorder, lineWidth: 0.9)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(selectedHighlight)
                                .frame(height: 8)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .shadow(color: selectedGlowColor, radius: 7, x: 0, y: 0)
                        .shadow(color: selectedDropShadowColor, radius: 2.5, x: 0, y: 1)
                        .matchedGeometryEffect(id: "categoryIndicator", in: namespace)
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(hoverBorder, lineWidth: 0.7)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(hoverHighlight)
                                .frame(height: 6)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                HStack(spacing: 6) {
                    if let icon = iconName {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    }

                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)

                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isSelected ? color.opacity(0.9) : color.opacity(0.72))
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: segmentHeight)
                .foregroundColor(
                    isSelected
                        ? .formaLabel
                        : (isHovered ? .formaLabel : unselectedTextColor)
                )
            }
            .frame(height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rulesCategoryTab_\(tabID)")
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isSelected)
        .animation(.easeOut(duration: 0.16), value: isHovered)
    }

    private var unselectedTextColor: Color {
        colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel
    }

    private var activeBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.13)
    }

    private var activeFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(0.18),
                        Color.formaBoneWhite.opacity(0.06),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(0.90),
                    Color.formaBoneWhite.opacity(0.70),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var selectedHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectedGlowColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.06)
            : Color.formaSteelBlue.opacity(0.05)
    }

    private var selectedDropShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.24)
            : Color.formaObsidian.opacity(0.08)
    }

    private var hoverFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.formaBoneWhite.opacity(0.12))
        }
        return AnyShapeStyle(Color.formaObsidian.opacity(0.08))
    }

    private var hoverBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct StocksStyleRulesIconButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private let containerCornerRadius: CGFloat = 17
    private let selectedCornerRadius: CGFloat = 13
    private let segmentWidth: CGFloat = 40
    private let segmentHeight: CGFloat = 30
    private let segmentPlateHorizontalInset: CGFloat = 4
    private let segmentPlateVerticalInset: CGFloat = 1.5

    var body: some View {
        Button(action: action) {
            ZStack {
                if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(hoverFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(hoverBorder, lineWidth: 0.7)
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .fill(hoverHighlight)
                                .frame(height: 6)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, segmentPlateVerticalInset)
                        .padding(.horizontal, segmentPlateHorizontalInset)
                }

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHovered ? .formaLabel : idleForeground)
                    .frame(width: segmentWidth, height: segmentHeight)
            }
            .frame(width: segmentWidth, height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(3)
        .background {
            StocksStyleRulesCapsuleBackground(cornerRadius: containerCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(topRimColor, lineWidth: 0.6)
                )
        }
        .help(help)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var idleForeground: Color {
        colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel
    }

    private var topRimColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaBoneWhite.opacity(0.45)
    }

    private var hoverFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.formaBoneWhite.opacity(0.12))
        }
        return AnyShapeStyle(Color.formaObsidian.opacity(0.08))
    }

    private var hoverBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.10)
    }

    private var hoverHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24),
                Color.formaBoneWhite.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct StocksStyleRulesCapsuleBackground: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .withinWindow)
                .clipShape(shape)

            shape.fill(baseFillColor)

            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(colorScheme == .dark ? Color.FormaOpacity.medium : 0.55),
                    Color.formaBoneWhite.opacity(colorScheme == .dark ? Color.FormaOpacity.subtle : 0.25),
                    Color.formaBoneWhite.opacity(0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)

            shape.stroke(borderColor, lineWidth: 1)
        }
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(Color.FormaOpacity.medium)
            : Color.formaObsidian.opacity(0.18)
    }

    private var baseFillColor: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(Color.FormaOpacity.subtle)
            : Color.formaBoneWhite.opacity(0.72)
    }
}
