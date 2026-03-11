import SwiftUI
import SwiftData

/// Compact inline rule builder for the right panel
struct InlineRuleBuilderView: View {
    let editingRule: Rule?
    let fileContext: FileItem?
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // Query existing rules for overlap detection
    @Query private var existingRules: [Rule]

    // Query categories for the category picker
    @Query private var categories: [RuleCategory]

    private var sortedExistingRules: [Rule] {
        existingRules.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.creationDate < rhs.creationDate
        }
    }

    private var sortedCategories: [RuleCategory] {
        categories.sortedByOrder
    }

    // Consolidated form state (8 properties → 1)
    @State private var formState = RuleFormState()

    // UI state (kept separate - these control UI behavior, not form data)
    @State private var validationError: String?
    @State private var matchedFilesCount: Int = 0
    @State private var previewFiles: [FileItem] = []
    @State private var isLoadingPreview: Bool = false
    @State private var previewTask: Task<Void, Never>?
    @State private var isChoosingDestination = false
    @State private var showDeleteConfirmation: Bool = false

    // Overlap detection state
    @State private var detectedOverlaps: [RuleOverlapDetector.RuleOverlap] = []
    @State private var showOverlapWarning: Bool = false
    @State private var pendingRuleForSave: Rule?

    // Natural language rule creation
    @StateObject private var naturalLanguageViewModel = NaturalLanguageRuleViewModel()
    private let destinationResolver = DestinationResolver()
    
    // MARK: - Header Configuration

    /// Determines the header icon, title, and subtitle based on context
    private var headerConfig: RuleEditorHeaderConfig {
        RuleEditorHeaderConfig.make(editingRule: editingRule, fileContext: fileContext, style: .inline)
    }

    private var ruleCardBackground: Color {
        colorScheme == .dark
            ? Color.formaObsidian.opacity(0.32)
            : Color.formaBoneWhite
    }

    private var ruleCardBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(0.08)
    }

    private var ruleCardShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color.black.opacity(0.08)
    }

    private var chromeSurfaceBackground: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.06)
            : Color.formaBoneWhite.opacity(0.88)
    }

    private var chromeSurfaceBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle)
    }

    private var trimmedRuleName: String {
        formState.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasValidConditionInput: Bool {
        if formState.useCompoundConditions {
            return !formState.conditions.isEmpty &&
                formState.conditions.allSatisfy { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return !formState.conditionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var destinationIsRequired: Bool {
        formState.actionType != .delete
    }

    private var destinationResolvability: DestinationResolver.ResolvabilityStatus? {
        guard destinationIsRequired else {
            return nil
        }

        if formState.destinationBookmarkData != nil {
            return .valid
        }

        let trimmedPath = formState.destinationDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return nil
        }

        return destinationResolver.checkResolvability(
            .folder(bookmark: Data(), displayName: trimmedPath)
        )
    }

    private var selectedCategory: RuleCategory? {
        if let categoryID = formState.categoryID {
            return sortedCategories.first { $0.id == categoryID }
        }
        return sortedCategories.first { $0.isDefault }
    }

    private var hasValidDestinationInput: Bool {
        !formState.destinationDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var whenValidationMessage: String? {
        hasValidConditionInput ? nil : "Add at least one condition value so Forma can match files."
    }

    private var thenValidationMessage: String? {
        if destinationIsRequired && !hasValidDestinationInput {
            return "Select a destination folder for move/copy actions."
        }
        if case .unresolvable(let reason) = destinationResolvability {
            return reason
        }
        return nil
    }

    private var canSubmitRule: Bool {
        !trimmedRuleName.isEmpty &&
        whenValidationMessage == nil &&
        thenValidationMessage == nil
    }

    private var impactTone: (title: String, message: String, color: Color, icon: String) {
        if let validationMessage = whenValidationMessage ?? thenValidationMessage {
            return (
                title: "Needs attention",
                message: validationMessage,
                color: .formaWarmOrange,
                icon: "exclamationmark.triangle.fill"
            )
        }

        if formState.actionType == .delete && matchedFilesCount > 0 {
            return (
                title: "High impact",
                message: "This rule will automatically send matching files to Trash.",
                color: .formaWarmOrange,
                icon: "trash.fill"
            )
        }

        if case .resolvable(let parentFolder) = destinationResolvability {
            return (
                title: "Will create folder",
                message: "Forma can create this destination inside \(parentFolder) as soon as you save.",
                color: .formaSteelBlue,
                icon: "folder.badge.plus"
            )
        }

        if matchedFilesCount == 0 {
            return (
                title: "Ready, no matches yet",
                message: "The rule is valid, but nothing in the current file set matches it right now.",
                color: .formaSteelBlue,
                icon: "sparkles"
            )
        }

        return (
            title: "Ready to save",
            message: "Previewed files below show what this rule will affect first.",
            color: .formaSage,
            icon: "checkmark.circle.fill"
        )
    }

    private var actionTypeBadgeColor: Color {
        switch formState.actionType {
        case .move:
            return .formaSteelBlue
        case .copy:
            return .formaSage
        case .delete:
            return .formaWarmOrange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed header with context-aware labels
            HStack {
                // Icon and title with optional subtitle
                HStack(spacing: 8) {
                    Image(systemName: headerConfig.icon)
                        .foregroundColor(fileContext != nil ? .formaSage : .formaSteelBlue)
                        .font(.formaBodySemibold)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(headerConfig.title)
                            .font(.formaBodyLarge).fontWeight(.semibold)
                            .foregroundColor(.formaLabel)

                        if let subtitle = headerConfig.subtitle {
                            Text(subtitle)
                                .font(.formaSmall)
                                .foregroundColor(.formaSecondaryLabelHigh)
                        }
                    }
                }

                Spacer()

                // Expand to modal button
                Button(action: expandToModal) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(.formaSecondaryLabelHigh)
                        .font(.formaBodyLarge)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help("Expand to Full Editor")
                .allowsHitTesting(true)

                Button(action: {
                    dashboardViewModel.returnToDefaultPanel()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.formaSecondaryLabelHigh)
                        .font(.formaH3)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .allowsHitTesting(true)
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, FormaSpacing.standard)
            .background(chromeSurfaceBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.formaSeparator.opacity(Color.FormaOpacity.strong)),
                alignment: .bottom
            )
            .allowsHitTesting(true)
            .zIndex(999)

            // Scrollable content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. Rule Name (Cleaner)
                        TextField("Name your rule...", text: $formState.name)
                            .font(.formaH3)
                            .textFieldStyle(.plain)
                            .padding(.bottom, 8)
                            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.formaSeparator).padding(.top, 32), alignment: .bottom)
                            .id("name-section")

                        // 2. Natural Language Input (Magical Entry)
                        if editingRule == nil {
                            NaturalLanguageInputBar(
                                viewModel: naturalLanguageViewModel,
                                onParsedRuleChanged: applyParsedRuleLive
                            )
                            .padding(.bottom, 8)
                        }

                        whenSectionCard
                        thenSectionCard
                        categorySelectionCard
                        impactPreviewCard

                    }
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.vertical, 20)
                }
            }

            persistentActionBar
        }
        .onAppear {
            initializeFields()
            updatePreview()
        }
        .alert(
            "Confirm Delete Rule",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Create Delete Rule", role: .destructive) {
                saveRule()
            }
        } message: {
            Text(deleteConfirmationMessage())
        }
        .sheet(isPresented: $showOverlapWarning) {
            if let rule = pendingRuleForSave {
	                RuleOverlapWarningView(
	                    overlaps: detectedOverlaps,
	                    ruleName: rule.name,
	                    rulePriority: (sortedExistingRules.firstIndex(where: { $0.id == editingRule?.id }) ?? sortedExistingRules.count) + 1,
	                    onSaveAnyway: {
	                        showOverlapWarning = false
                        commitSave(rule: rule)
                    },
                    onEditRule: {
                        showOverlapWarning = false
                        // User stays on the editor to make changes
                    },
                    onCancel: {
                        showOverlapWarning = false
                        pendingRuleForSave = nil
                        detectedOverlaps = []
                    }
                )
            }
        }
    }

    private var persistentActionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: FormaSpacing.tight) {
                Image(systemName: impactTone.icon)
                    .font(.formaCompactSemibold)
                    .foregroundColor(impactTone.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(impactTone.title)
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaLabel)
                    Text(impactTone.message)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabelHigh)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if matchedFilesCount > 0 {
                    FormaBadge(
                        text: "\(matchedFilesCount) match\(matchedFilesCount == 1 ? "" : "es")",
                        color: impactTone.color,
                        size: .small,
                        style: .subtle
                    )
                }
            }

            Button(action: {
                if formState.actionType == .delete && matchedFilesCount > 0 {
                    showDeleteConfirmation = true
                } else {
                    saveRule()
                }
            }) {
                Text(editingRule == nil ? "Create Rule" : "Save Changes")
                    .font(.formaBodyBold)
                    .foregroundColor(.formaBoneWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.formaSteelBlue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmitRule)
            .opacity(canSubmitRule ? 1 : 0.6)
        }
        .padding(.horizontal, FormaSpacing.generous)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(chromeSurfaceBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.formaSeparator.opacity(Color.FormaOpacity.strong)),
            alignment: .top
        )
        .allowsHitTesting(true)
        .zIndex(998)
    }

    /// Generates a confirmation message showing the impact of a delete rule.
    /// Uses cached preview data for consistency with the displayed count.
    private func deleteConfirmationMessage() -> String {
        let count = matchedFilesCount

        if count == 0 {
            return "This delete rule doesn't currently match any files."
        }

        var message = "This rule will send \(count) file\(count == 1 ? "" : "s") to Trash when applied.\n\n"

        // Use cached preview files for sample names
        if !previewFiles.isEmpty {
            let sampleNames = previewFiles.map { "• \($0.name)" }.joined(separator: "\n")
            message += "Files that will be affected:\n\(sampleNames)"

            if count > 3 {
                message += "\n...and \(count - 3) more"
            }
        }

        message += "\n\nYou can undo individual deletions, but this action affects files automatically."

        return message
    }

    @ViewBuilder
    private func ruleSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text(title)
                .font(.formaBodyBold)
                .foregroundColor(.formaLabel)
            Text(subtitle)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabelHigh)
        }
    }

    @ViewBuilder
    private func sectionValidationMessage(_ message: String?) -> some View {
        if let message {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.formaCompact)
                    .foregroundColor(.formaWarmOrange)
                Text(message)
                    .font(.formaSmall)
                    .foregroundColor(.formaWarmOrange)
            }
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro + 2)
            .background(Color.formaWarmOrange.opacity(Color.FormaOpacity.light))
            .cornerRadius(FormaRadius.control)
        }
    }

    private func builderSectionCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(20)
            .background(ruleCardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ruleCardBorder, lineWidth: 1)
            )
            .shadow(color: ruleCardShadow, radius: 6, x: 0, y: 2)
    }

    private var whenSectionCard: some View {
        builderSectionCard {
            VStack(alignment: .leading, spacing: 18) {
                ruleSectionHeader(
                    title: "When",
                    subtitle: "Choose which files this rule should target."
                )

                HStack {
                    Text("Matches")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabelHigh)

                    Spacer()

                    Toggle("Multiple", isOn: $formState.useCompoundConditions)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                        .onChange(of: formState.useCompoundConditions) { _, newValue in
                            if newValue && formState.conditions.isEmpty {
                                do {
                                    let condition = try RuleCondition(type: formState.conditionType, value: formState.conditionValue)
                                    formState.conditions = [condition]
                                } catch {
                                    // Ignore invalid initial condition
                                }
                            }
                            updatePreview()
                        }
                }
                .padding(.bottom, 4)

                if formState.useCompoundConditions {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("If")
                                .font(.formaBodyLarge)
                                .foregroundColor(.formaSecondaryLabelHigh)

                            Menu {
                                Button("ALL conditions (AND)") { formState.logicalOperator = .and }
                                Button("ANY condition (OR)") { formState.logicalOperator = .or }
                            } label: {
                                Text(formState.logicalOperator == .and ? "ALL conditions met" : "ANY condition met")
                                    .font(.formaBodyLarge)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.formaSteelBlue)
                                    .underline(true, color: .formaSteelBlue.opacity(0.3))
                            }
                            .menuStyle(.borderlessButton)
                        }

                        VStack(spacing: 8) {
                            ForEach(Array(formState.conditions.enumerated()), id: \.offset) { index, _ in
                                editableConditionRow(at: index)
                            }
                        }

                        Button(action: addCondition) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Condition")
                            }
                            .font(.formaSmall)
                            .foregroundColor(.formaSteelBlue)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("If file")
                            .font(.formaBodyLarge)
                            .foregroundColor(.formaSecondaryLabelHigh)

                        Menu {
                            ForEach(Rule.ConditionType.allCases, id: \.self) { type in
                                Button(type.compactDisplayName) {
                                    formState.conditionType = type
                                    updatePreview()
                                }
                            }
                        } label: {
                            Text(formState.conditionType.compactDisplayName.lowercased())
                                .font(.formaBodyLarge)
                                .fontWeight(.semibold)
                                .foregroundColor(.formaSteelBlue)
                                .underline(true, color: .formaSteelBlue.opacity(0.3))
                        }
                        .menuStyle(.borderlessButton)

                        Text("is")
                            .font(.formaBodyLarge)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }

                    TextField(conditionPlaceholder, text: $formState.conditionValue)
                        .font(.formaBodyLarge)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.formaControlBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(whenValidationMessage == nil ? Color.formaSeparator : Color.formaWarmOrange, lineWidth: 1)
                        )
                        .onChange(of: formState.conditionValue) { _, _ in
                            updatePreview()
                        }
                }

                sectionValidationMessage(whenValidationMessage)
            }
        }
    }

    private var thenSectionCard: some View {
        builderSectionCard {
            VStack(alignment: .leading, spacing: 18) {
                ruleSectionHeader(
                    title: "Then",
                    subtitle: "Define what happens to matched files."
                )

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Then")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabelHigh)

                    Menu {
                        Button("move") { formState.actionType = .move }
                        Button("copy") { formState.actionType = .copy }
                        Button("delete") { formState.actionType = .delete }
                    } label: {
                        Text(formState.actionType.rawValue)
                            .font(.formaBodyLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(.formaSteelBlue)
                            .underline(true, color: .formaSteelBlue.opacity(0.3))
                    }
                    .menuStyle(.borderlessButton)

                    Text("to")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabelHigh)
                        .opacity(formState.actionType == .delete ? 0.3 : 1.0)
                }

                if formState.actionType == .delete {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.formaWarmOrange)
                        Text("Trash")
                            .font(.formaBodyLarge)
                            .fontWeight(.medium)
                            .foregroundColor(.formaError)
                    }
                    .padding(.vertical, 4)
                } else {
                    Button(action: requestDestinationAccess) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.formaSteelBlue)
                            Text(formState.destinationDisplayPath.isEmpty ? "Select folder..." : formState.destinationDisplayPath)
                                .fontWeight(.medium)
                                .foregroundColor(formState.destinationDisplayPath.isEmpty ? .formaSecondaryLabelHigh : .formaLabel)

                            if formState.hasBookmark {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.formaSoftGreen)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.formaControlBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    thenValidationMessage == nil ? Color.formaSeparator : Color.formaWarmOrange,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isChoosingDestination)
                }

                if case .resolvable(let parentFolder) = destinationResolvability {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(.formaSteelBlue)
                        Text("Will create this folder inside \(parentFolder) when you save.")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }
                }

                if case .unresolvable = destinationResolvability {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundColor(.formaWarmOrange)
                        Text("Click the destination field to grant access to the suggested parent folder. Forma will keep the suggested path and create any missing subfolders after access is granted.")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabelHigh)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                sectionValidationMessage(thenValidationMessage)
            }
        }
    }

    private var categorySelectionCard: some View {
        builderSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                ruleSectionHeader(
                    title: "Category",
                    subtitle: "Group this rule with related organization behavior."
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedCategories) { category in
                            Button(action: { formState.categoryID = category.id }) {
                                HStack(spacing: 4) {
                                    if formState.categoryID == category.id {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                    }
                                    Text(category.name)
                                }
                                .font(.formaSmall)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    formState.categoryID == category.id
                                        ? category.color.opacity(0.2)
                                        : Color.formaControlBackground
                                )
                                .foregroundColor(formState.categoryID == category.id ? category.color : .formaSecondaryLabelHigh)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Condition Row
    
    @ViewBuilder
    private func editableConditionRow(at index: Int) -> some View {
        HStack(spacing: FormaSpacing.tight) {
            // Condition type selector
            Menu {
                ForEach(Rule.ConditionType.allCases, id: \.self) { type in
                    Button(type.compactDisplayName) {
                        updateConditionType(at: index, to: type)
                    }
                }
            } label: {
                Text((index < formState.conditions.count ? formState.conditions[index].type : .fileExtension).compactDisplayName)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .fixedSize()
            }
            .menuStyle(.borderlessButton)

            // Condition value
            TextField(
                conditionPlaceholder(for: index < formState.conditions.count ? formState.conditions[index].type : .fileExtension),
                text: Binding(
                    get: { index < formState.conditions.count ? formState.conditions[index].value : "" },
                    set: { newValue in
                        updateConditionValue(at: index, to: newValue)
                    }
                )
            )
            .textFieldStyle(.plain)
            .font(.formaBody)
            .foregroundColor(.formaLabel)
            
            Spacer()
            
            Button(action: { removeCondition(at: index) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .font(.formaSmall)
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.standard)
        .background(colorScheme == .dark ? Color.formaObsidian.opacity(0.28) : Color.formaCardBackground)
        .cornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(colorScheme == .dark ? 0.55 : Color.FormaOpacity.strong), lineWidth: 1)
        )
    }

    private func updateConditionType(at index: Int, to type: Rule.ConditionType) {
        guard index < formState.conditions.count else { return }
        do {
            let newCondition = try RuleCondition(type: type, value: formState.conditions[index].value)
            formState.conditions[index] = newCondition
            updatePreview()
        } catch {
            print("Failed to update condition type: \(error)")
        }
    }

    private func updateConditionValue(at index: Int, to value: String) {
        guard index < formState.conditions.count else { return }
        do {
            let newCondition = try RuleCondition(type: formState.conditions[index].type, value: value)
            formState.conditions[index] = newCondition
            updatePreview()
        } catch {
            print("Failed to update condition value: \(error)")
        }
    }
    
    // MARK: - Impact Preview Card

    private var impactSummaryText: String {
        let countText = "\(matchedFilesCount) file\(matchedFilesCount == 1 ? "" : "s")"
        switch formState.actionType {
        case .delete:
            return "Would send \(countText) to Trash."
        case .copy:
            if hasValidDestinationInput {
                return "Would copy \(countText) to \(formState.destinationDisplayPath)."
            }
            return "Would copy \(countText) after a destination is selected."
        case .move:
            if hasValidDestinationInput {
                return "Would move \(countText) to \(formState.destinationDisplayPath)."
            }
            return "Would move \(countText) after a destination is selected."
        }
    }

    private var impactPreviewCard: some View {
        builderSectionCard {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                HStack(alignment: .top, spacing: FormaSpacing.standard) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: impactTone.icon)
                                .foregroundColor(impactTone.color)
                            Text("Impact")
                                .font(.formaBodySemibold)
                                .tracking(0.5)
                                .foregroundColor(.formaLabel)
                        }

                        Text(impactTone.title)
                            .font(.formaBodyBold)
                            .foregroundColor(.formaLabel)

                        Text(impactTone.message)
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        FormaBadge(
                            text: "\(matchedFilesCount) match\(matchedFilesCount == 1 ? "" : "es")",
                            color: impactTone.color,
                            size: .small,
                            style: .subtle
                        )

                        FormaBadge(
                            text: formState.actionType == .delete ? "Trash" : formState.actionType.rawValue.capitalized,
                            color: actionTypeBadgeColor,
                            size: .small,
                            style: .subtle
                        )
                    }
                }

                if !hasValidConditionInput {
                    Text("Complete the \"When\" section to preview impact.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabelHigh)
                } else if isLoadingPreview {
                    HStack(spacing: FormaSpacing.tight) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Matching files...")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }
                } else {
                    Text(impactSummaryText)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabelHigh)

                    if !previewFiles.isEmpty {
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            ForEach(previewFiles) { file in
                                HStack(spacing: FormaSpacing.tight) {
                                    Image(systemName: file.category.iconName)
                                        .foregroundColor(file.category.color)
                                        .font(.formaCompact)

                                    Text(file.name)
                                        .font(.formaCaption)
                                        .foregroundColor(.formaLabel)
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.horizontal, FormaSpacing.tight)
                                .padding(.vertical, FormaSpacing.tight - 2)
                                .background(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
                                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                            }

                            if matchedFilesCount > 3 {
                                Text("+\(matchedFilesCount - 3) more")
                                    .font(.formaCaption)
                                    .foregroundColor(.formaSecondaryLabelHigh)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers

    /// Expands the panel rule builder to the full modal editor
    /// Transfers current state (editingRule and fileContext) to the modal
    private func expandToModal() {
        // Transfer state to NavigationViewModel for the modal
        nav.editingRule = editingRule
        nav.ruleEditorFileContext = fileContext

        // Close the panel first
        dashboardViewModel.returnToDefaultPanel()

        // Open the modal with a slight delay for smooth transition
        withAnimation(.easeInOut(duration: 0.2)) {
            nav.isShowingRuleEditor = true
        }
    }

    private func addCondition() {
        // If single mode, don't allow adding (shouldn't be reached)
        if !formState.useCompoundConditions { return }

        do {
            // Add new condition (defaulting to extension: pdf)
            let newCondition = try RuleCondition(type: .fileExtension, value: "")
            formState.conditions.append(newCondition)
        } catch {
            validationError = error.localizedDescription
            return
        }

        // Update logical operator if this is the second condition
        if formState.conditions.count == 2 && formState.logicalOperator == .single {
            formState.logicalOperator = .and
        }

        updatePreview()
    }



    private func removeCondition(at index: Int) {
        formState.conditions.remove(at: index)

        // Reset logical operator if we're back to 0 conditions
        if formState.conditions.isEmpty {
            formState.logicalOperator = .single
        }

        updatePreview()
    }
    
    private func initializeFields() {
        // Initialize form state from editing context using struct initializers
        if let rule = editingRule {
            formState = RuleFormState(from: rule)
        } else if let file = fileContext {
            formState = RuleFormState(from: file)
        }
        // Default formState already initialized for new rules

        // Auto-select default category if none is selected yet
        if formState.categoryID == nil, let defaultCategory = sortedCategories.first(where: { $0.isDefault }) {
            formState.categoryID = defaultCategory.id
        }
    }
    
    private func updatePreview() {
        // Cancel any pending preview computation
        previewTask?.cancel()

        guard hasValidConditionInput else {
            withAnimation(.easeInOut(duration: 0.15)) {
                previewFiles = []
                matchedFilesCount = 0
                isLoadingPreview = false
            }
            return
        }

        // Start loading state immediately for visual feedback
        isLoadingPreview = true

        // Debounce preview computation to avoid excessive filtering
        previewTask = Task { @MainActor in
            // Small delay to batch rapid changes (e.g., typing)
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms

            guard !Task.isCancelled else { return }

            let files = getMatchedFiles()

            guard !Task.isCancelled else { return }

            // Update state on completion
            withAnimation(.easeInOut(duration: 0.2)) {
                previewFiles = Array(files.prefix(3))
                matchedFilesCount = files.count
                isLoadingPreview = false
            }
        }
    }
    
    private func getMatchedFiles() -> [FileItem] {
        // If we have compound conditions, use those
        if !formState.conditions.isEmpty {
            return dashboardViewModel.allFiles.filter { file in
                matchesCompoundConditions(file: file)
            }
        }

        // Otherwise, check the current input condition
        guard !formState.conditionValue.isEmpty else { return [] }

        return dashboardViewModel.allFiles.filter { file in
            matchesSingleCondition(file: file, type: formState.conditionType, value: formState.conditionValue)
        }
    }

    private func matchesCompoundConditions(file: FileItem) -> Bool {
        switch formState.logicalOperator {
        case .and:
            return formState.conditions.allSatisfy { condition in
                matchesSingleCondition(file: file, type: condition.type, value: condition.value)
            }
        case .or:
            return formState.conditions.contains { condition in
                matchesSingleCondition(file: file, type: condition.type, value: condition.value)
            }
        case .single:
            if let first = formState.conditions.first {
                return matchesSingleCondition(file: file, type: first.type, value: first.value)
            }
            return false
        }
    }
    
    private func matchesSingleCondition(file: FileItem, type: Rule.ConditionType, value: String) -> Bool {
        switch type {
        case .fileExtension:
            return file.fileExtension.localizedCaseInsensitiveCompare(value) == .orderedSame
        case .nameContains:
            return file.name.localizedCaseInsensitiveContains(value)
        case .nameStartsWith:
            return file.name.lowercased().hasPrefix(value.lowercased())
        case .nameEndsWith:
            return file.name.lowercased().hasSuffix(value.lowercased())
        default:
            return false // For unsupported condition types in inline builder
        }
    }

    // MARK: - Natural Language Integration

    /// Called live as the user types in the NL input bar.
    /// Auto-populates the form fields below without any tab switching.
    private func applyParsedRuleLive(_ parsed: NLParsedRule?) {
        guard let parsed = parsed, !parsed.hasBlockingError else { return }

        // Map action (animate the change for visual feedback)
        withAnimation(.easeInOut(duration: 0.2)) {
            if let action = parsed.primaryAction {
                formState.actionType = action
            }

            // Map destination display path (only for move/copy)
            // Note: NL parsing sets the display path, but user must still select via folder picker
            // to create the required security-scoped bookmark
            if let dest = parsed.destinationPath, !dest.isEmpty {
                formState.destinationDisplayPath = dest
                // Clear any existing bookmark since NL text can't provide one
                formState.destinationBookmarkData = nil
            }

            // Map conditions
            if parsed.candidateConditions.count == 1, let first = parsed.candidateConditions.first {
                formState.conditions = []
                formState.logicalOperator = .single
                formState.conditionType = first.type
                formState.conditionValue = first.value
            } else if !parsed.candidateConditions.isEmpty {
                formState.conditions = parsed.candidateConditions
                formState.logicalOperator = parsed.logicalOperator
                formState.conditionValue = "" // Clear single condition field
            }

            // Suggest a rule name based on input if user hasn't typed one
            if formState.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = parsed.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    // Truncate to a reasonable length for a name
                    formState.name = String(trimmed.prefix(50))
                }
            }
        }

        updatePreview()
    }

    private func saveRule() {
        if let result = RuleValidator.validate(
            formState: formState,
            editingRule: editingRule,
            naturalLanguageViewModel: naturalLanguageViewModel,
            mode: .inline
        ) {
            validationError = result.message
            return
        }

        validationError = nil

        let ruleToCheck: Rule
        do {
            ruleToCheck = try buildRuleCandidate(destination: formState.buildDestination())
        } catch {
            validationError = error.localizedDescription
            return
        }

        // Check for overlaps with existing rules
        let detector = RuleOverlapDetector()
        let overlaps = detector.detectOverlaps(
            for: ruleToCheck,
            against: sortedExistingRules,
            excludeRuleID: editingRule?.id
        )

        if !overlaps.isEmpty {
            // Store the pending rule and show warning dialog
            pendingRuleForSave = ruleToCheck
            detectedOverlaps = overlaps
            showOverlapWarning = true
            Log.info("InlineRuleBuilderView: Detected \(overlaps.count) overlap(s) for rule '\(ruleToCheck.name)'", category: .pipeline)
        } else {
            // No overlaps - proceed directly to save
            commitSave(rule: ruleToCheck)
        }
    }

    /// Commits the rule save after validation and overlap checks have passed.
    /// Called either directly (no overlaps) or after user confirms in overlap dialog.
    private func commitSave(rule: Rule) {
        let ruleService = RuleService(modelContext: modelContext)

        do {
            let materializedDestination = try destinationResolver.materializeForExplicitSave(rule.destination)

            if let existingRule = editingRule {
                // Update existing rule's properties from the checked rule
                existingRule.name = rule.name
                existingRule.actionType = rule.actionType
                existingRule.isEnabled = rule.isEnabled
                existingRule.destination = materializedDestination
                existingRule.category = rule.category
                existingRule.conditionType = rule.conditionType
                existingRule.conditionValue = rule.conditionValue
                existingRule.conditions = rule.conditions
                existingRule.logicalOperator = rule.logicalOperator

                try ruleService.updateRule(existingRule)
            } else {
                // Assign category to new rule
                rule.destination = materializedDestination
                try ruleService.createRule(rule, source: .inlineBuilder)
            }

            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)
            dashboardViewModel.showCelebrationPanel(message: editingRule == nil ? "Rule created!" : "Rule updated!")

            // Clear pending state
            pendingRuleForSave = nil
            detectedOverlaps = []
        } catch {
            Log.error("InlineRuleBuilderView: Failed to save rule - \(error.localizedDescription)", category: .analytics)
            validationError = "Failed to save rule: \(error.localizedDescription)"
        }
    }
    
    private func requestDestinationAccess() {
        guard !isChoosingDestination else { return }

        isChoosingDestination = true
        validationError = nil

        Task { @MainActor in
            defer { isChoosingDestination = false }

            do {
                let destination = try await destinationResolver.requestDestinationAccess(
                    forSuggestedPath: formState.destinationDisplayPath
                )
                formState.destinationBookmarkData = destination.bookmarkData
                formState.destinationDisplayPath = destination.displayName

                #if DEBUG
                Log.info("InlineRuleBuilderView: Granted access for '\(destination.displayName)'", category: .bookmark)
                #endif
            } catch DestinationResolver.AccessGrantError.cancelled {
                return
            } catch {
                #if DEBUG
                Log.error("InlineRuleBuilderView: Failed to grant destination access - \(error.localizedDescription)", category: .bookmark)
                #endif
                validationError = "Failed to grant access for destination: \(error.localizedDescription)"
            }
        }
    }

    // Note: defaultDestination(for:) moved to RuleFormState struct
    
    private var conditionPlaceholder: String {
        conditionPlaceholder(for: formState.conditionType)
    }

    private func buildRuleCandidate(destination: Destination?) throws -> Rule {
        let trimmedName = formState.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let enableFlag = editingRule == nil && formState.actionType == .delete ? false : formState.isEnabled

        if formState.useCompoundConditions {
            return Rule(
                name: trimmedName,
                conditions: formState.conditions,
                logicalOperator: formState.logicalOperator,
                actionType: formState.actionType,
                destination: destination,
                isEnabled: enableFlag,
                category: selectedCategory
            )
        }

        let trimmedValue = formState.conditionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try RuleCondition(type: formState.conditionType, value: trimmedValue)

        return Rule(
            name: trimmedName,
            conditionType: formState.conditionType,
            conditionValue: trimmedValue,
            actionType: formState.actionType,
            destination: destination,
            isEnabled: enableFlag,
            category: selectedCategory
        )
    }

    private func conditionPlaceholder(for type: Rule.ConditionType) -> String {
        switch type {
        case .fileExtension: return "e.g., pdf"
        case .nameContains: return "e.g., invoice"
        case .nameStartsWith: return "e.g., Screenshot"
        case .nameEndsWith: return "e.g., -final"
        case .sourceLocation: return "e.g., desktop"
        default: return "Enter value"
        }
    }

}

// MARK: - Natural Language Input Bar

/// A compact NL input bar that auto-populates the rule form as the user types.
/// Shows only the input field and HUD tokens for feedback - no preview card needed
/// since the form below IS the live preview.
private struct NaturalLanguageInputBar: View {
    @ObservedObject var viewModel: NaturalLanguageRuleViewModel
    var onParsedRuleChanged: (NLParsedRule?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            // Compact input with inline label
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "sparkles.text.rectangle")
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaSteelBlue)

                TextField(
                    "Describe what you want to automate...",
                    text: $viewModel.text,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.formaBody)
                .foregroundColor(.formaLabel)
                .lineLimit(1...3)
                .onSubmit {
                    viewModel.parseImmediately()
                }
                .onChange(of: viewModel.text) { _, newValue in
                    viewModel.onTextChanged(newValue)
                }

                if viewModel.isParsing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)
            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle))
            .cornerRadius(FormaRadius.control)

            // HUD tokens showing what was parsed
            if let parsed = viewModel.parsedRule, !hudTokens(for: parsed).isEmpty {
                HStack(spacing: 6) {
                    ForEach(hudTokens(for: parsed), id: \.self) { token in
                        Text(token)
                            .font(.formaSmallMedium)
                            .foregroundColor(.formaSteelBlue)
                            .padding(.horizontal, FormaSpacing.tight)
                            .padding(.vertical, FormaSpacing.micro - (FormaSpacing.micro / 4))
                            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                            .clipShape(Capsule())
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: viewModel.parsedRule?.overallConfidence)
            }

            // Help text when empty
            if viewModel.text.isEmpty {
                Text("Try: \"Move PDFs older than 30 days to Archive\"")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel.opacity(Color.FormaOpacity.high))
                    .italic()
            }
        }
        // Observe changes to the parsed result via confidence (which is Equatable)
        .onChange(of: viewModel.parsedRule?.overallConfidence) { _, _ in
            onParsedRuleChanged(viewModel.parsedRule)
        }
        // Also observe when parsing completes
        .onChange(of: viewModel.isParsing) { _, isParsing in
            if !isParsing {
                onParsedRuleChanged(viewModel.parsedRule)
            }
        }
    }

    private func hudTokens(for parsed: NLParsedRule) -> [String] {
        var tokens: [String] = []

        // Action
        if let action = parsed.primaryAction {
            switch action {
            case .move: tokens.append("move")
            case .copy: tokens.append("copy")
            case .delete: tokens.append("delete")
            }
        }

        // File type (first one only)
        if let fileToken = parsed.candidateConditions.compactMap(fileTokenForCondition).first {
            tokens.append(fileToken)
        }

        // Time constraint
        if let t = parsed.timeConstraints.first {
            switch t {
            case .olderThan(let days):
                tokens.append(">\(days)d")
            }
        }

        // Destination
        if let dest = parsed.destinationPath, !dest.isEmpty {
            let shortDest = dest.count > 15 ? "…" + dest.suffix(12) : dest
            tokens.append("→\(shortDest)")
        }

        return tokens
    }

    private func fileTokenForCondition(_ condition: RuleCondition) -> String? {
        switch condition {
        case .fileExtension(let ext):
            return ".\(ext.lowercased())"
        case .fileKind(let kind):
            return kind.lowercased()
        default:
            return nil
        }
    }
}

@MainActor
private enum InlineRuleBuilderViewPreview {
    static func make() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: FileItem.self, Rule.self, RuleCategory.self, ActivityItem.self, configurations: config)

        // Seed a default category for the preview
        let context = container.mainContext
        let defaultCategory = RuleCategory.createDefault()
        context.insert(defaultCategory)
        do {
            try context.save()
        } catch {
            Log.debug("InlineRuleBuilderView Preview: Failed to save preview context - \(error.localizedDescription)", category: .ui)
        }

        return InlineRuleBuilderView(editingRule: nil, fileContext: nil)
            .environmentObject(DashboardViewModel())
            .environmentObject(NavigationViewModel())
            .modelContainer(container)
            .frame(width: 360, height: 800)
    }
}

#Preview {
    InlineRuleBuilderViewPreview.make()
}
