import SwiftUI
import SwiftData

// MARK: - RuleEditorView

struct RuleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel

    @Query private var existingRules: [Rule]

    // Categories for picker
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

    let editingRule: Rule?
    let fileContext: FileItem?
    let suggestedNaturalLanguageText: String?
    var onDismiss: (() -> Void)?
    var buttonNamespace: Namespace.ID?

    // Consolidated form state (reduces 9 @State to 1)
    @State private var formState = RuleFormState()

    // UI state
    @State private var validationError: String?
    @State private var triggerValidationShake: Bool = false
    @State private var isChoosingDestination = false
    
    // Natural language rule creation
    @StateObject private var naturalLanguageViewModel = NaturalLanguageRuleViewModel()
    
    // Delete rule safety preview
    @State private var deletePreviewFiles: [FileItem] = []
    @State private var showDeletePreviewSheet: Bool = false
    @State private var detectedOverlaps: [RuleOverlapDetector.RuleOverlap] = []
    @State private var showOverlapWarning: Bool = false
    @State private var pendingRuleForSave: Rule?

    // Create category popover state
    @State private var showCreateCategoryPopover: Bool = false
    @State private var newCategoryName: String = ""
    @State private var newCategoryColor: Color = .formaSteelBlue
    
    // Animation states
    @State private var saveButtonState: ButtonMorphState = .normal
    // Destination resolver for checking placeholder resolvability
    private let destinationResolver = DestinationResolver()

    init(
        rule: Rule? = nil,
        fileContext: FileItem? = nil,
        suggestedNaturalLanguageText: String? = nil,
        onDismiss: (() -> Void)? = nil,
        buttonNamespace: Namespace.ID? = nil
    ) {
        self.editingRule = rule
        self.fileContext = fileContext
        self.suggestedNaturalLanguageText = suggestedNaturalLanguageText
        self.onDismiss = onDismiss
        self.buttonNamespace = buttonNamespace
    }

    // MARK: - Header Configuration

    /// Determines the header icon, title, and subtitle based on context
    private var headerConfig: RuleEditorHeaderConfig {
        RuleEditorHeaderConfig.make(editingRule: editingRule, fileContext: fileContext, style: .fullEditor)
    }

    // MARK: - Destination Resolvability

    /// Checks if the current destination can be resolved.
    /// Only relevant for move/copy actions with placeholder destinations.
    private var destinationResolvability: DestinationResolver.ResolvabilityStatus? {
        // Only check for move/copy actions
        guard formState.actionType == .move || formState.actionType == .copy else {
            return nil
        }

        // If destination has a valid bookmark, it's valid
        if formState.destinationBookmarkData != nil {
            return .valid
        }

        // If no destination path set, nothing to check
        guard !formState.destinationDisplayPath.isEmpty else {
            return nil
        }

        // Check resolvability of the placeholder destination
        let placeholderDestination = Destination.folder(
            bookmark: Data(),
            displayName: formState.destinationDisplayPath
        )
        return destinationResolver.checkResolvability(placeholderDestination)
    }

    private var selectedCategory: RuleCategory? {
        if let categoryID = formState.categoryID {
            return sortedCategories.first { $0.id == categoryID }
        }
        return sortedCategories.first { $0.isDefault }
    }

    private var ruleSourceForSave: RuleService.RuleSource {
        let nlText = naturalLanguageViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if editingRule == nil, !nlText.isEmpty, naturalLanguageViewModel.parsedRule != nil {
            return .naturalLanguage(text: nlText)
        }
        return .ruleEditor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with context-aware labels
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: headerConfig.icon)
                        .font(.formaBodySemibold)
                        .foregroundColor(fileContext != nil ? .formaSage : .formaSteelBlue)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(headerConfig.title)
                            .font(.formaH3)
                            .foregroundColor(Color.formaLabel)

                        if let subtitle = headerConfig.subtitle {
                            Text(subtitle)
                                .font(.formaCompact)
                                .foregroundColor(.formaSecondaryLabel)
                        }
                    }
                }
                .if(buttonNamespace != nil && editingRule == nil) { view in
                    view.matchedGeometryEffect(id: "ruleButton", in: buttonNamespace!, isSource: true)
                }
                Spacer()

                // Collapse to panel button
                Button(action: collapseToPanel) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.formaBodySemibold)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse to Panel")
                .help("Collapse to Side Panel")

                Button(action: {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.formaBodySemibold)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(FormaSpacing.generous)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: FormaSpacing.generous) {
                    // Rule Name with validation shake
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        Text("Name")
                            .font(.formaBodySemibold)
                            .tracking(0.5)
                            .foregroundColor(Color.formaSecondaryLabel)
                        TextField("e.g., Screenshot Sweeper", text: $formState.name)
                            .textFieldStyle(.plain)
                            .padding(FormaSpacing.tight + (FormaSpacing.micro / 2))
                            .background(Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle))
                            .cornerRadius(FormaRadius.control)
                            .foregroundColor(Color.formaLabel)
                            .overlay(
                                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                    .stroke(
                                        validationError != nil && formState.name.isEmpty ? Color.formaWarmOrange : Color.clear,
                                        lineWidth: 1
                                    )
                            )

                            .validationShake(trigger: triggerValidationShake)
                    }
                    .padding(.bottom, 8) // Add some breathing room

                    // Natural language input (creation-only)
                    if editingRule == nil {
                        NaturalLanguageRuleView(
                            viewModel: naturalLanguageViewModel,
                            onApplyToEditor: applyParsedRuleFromNaturalLanguage
                        )
                    }

                    // Main Form Card (Sentence Builder Style)
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Category picker (integrated into the card flow or just above/below - Inline has it inside the card if I recall, but let's check. 
                        // Actually in Inline it was outside, then Matches inside. 
                        // Let's keep Category separate if it needs to be, but the request says match Inline. 
                        // InlineView puts Matches | Then inside a white card. Category is separate.
                        // So let's start the card here for Matches and Then.
                        
                        RuleConditionBuilder(formState: $formState)

                        Divider().padding(.vertical, 4)

                        RuleDestinationPicker(
                            formState: $formState,
                            onChooseFolder: requestDestinationAccess,
                            onPreviewDeleteMatches: previewDeleteRuleMatches
                        )
                    }
                    .padding(20)
                    .background(Color.formaBoneWhite)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

                    destinationStatusBanner

                    // Category picker
                    if !sortedCategories.isEmpty {
                        categoryPickerSection
                    }

                    
                    // Validation error
                    if let error = validationError {
                        HStack(spacing: FormaSpacing.tight) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.formaWarning)
                            Text(error)
                                .formaMetadataStyle()
                                .foregroundColor(.formaWarning)
                        }
                        .padding(FormaSpacing.standard)
                        .background(Color.formaWarmOrange.opacity(Color.FormaOpacity.light))
                        .cornerRadius(FormaRadius.control)
                    }
                }
                .padding(FormaSpacing.generous)
            }

            Divider()

            // Footer
            HStack(spacing: FormaSpacing.standard) {
                SecondaryButton("Cancel") {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }

                // Enable toggle (re-added in footer)
                Toggle("Enable", isOn: $formState.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .help("Enable or disable this rule")

	            Button(action: {
	                    saveRule()
	                }) {
	                    MorphingButtonContent(
	                        state: saveButtonState,
	                        title: editingRule == nil ? "Create Rule" : "Save Changes",
	                        iconColor: .formaBoneWhite
	                    )
	                    .padding(.horizontal, FormaSpacing.large)
	                    .padding(.vertical, FormaSpacing.tight + (FormaSpacing.micro / 2))
	                }
	                .background(
	                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
	                        .fill(Color.formaSteelBlue)
	                )
	                .shadow(color: Color.formaSteelBlue.opacity(Color.FormaOpacity.medium), radius: 4, x: 0, y: 2)
	                .disabled(saveButtonState != .normal)
	            }
	            .padding(FormaSpacing.generous)
	        }
        .frame(width: 500, height: 550)
        .background(
            ZStack {
                // Solid backing for better contrast
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(Color.formaCardBackground)
                // Frosted glass overlay
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
            }
	        )
	        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
	        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.overlay), radius: 24, x: 0, y: 12)
	        .accessibilityElement(children: .contain)
	        .accessibilityIdentifier("ruleEditorView")
        .onAppear {
            // Initialize form state from editing context
            if let rule = editingRule {
                formState = RuleFormState(from: rule)
            } else if let file = fileContext {
                formState = RuleFormState(from: file)
            }

            if editingRule == nil,
               let suggestedText = suggestedNaturalLanguageText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !suggestedText.isEmpty,
               naturalLanguageViewModel.text.isEmpty {
                naturalLanguageViewModel.onTextChanged(suggestedText)
                naturalLanguageViewModel.parseImmediately()
            }

            // Auto-select default category if none is selected yet
            if formState.categoryID == nil, let defaultCategory = sortedCategories.first(where: { $0.isDefault }) {
                formState.categoryID = defaultCategory.id
            }
        }
        .sheet(isPresented: $showDeletePreviewSheet) {
            DeleteRulePreviewSheet(files: deletePreviewFiles)
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
                        pendingRuleForSave = nil
                        detectedOverlaps = []
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

    // MARK: - View Components

    /// Category picker allowing users to assign the rule to an organizational category.
    /// Uses compact pill-style selection with category colors.
	    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text("Category")
                .font(.formaBodySemibold)
                .tracking(0.5)
                .foregroundColor(Color.formaSecondaryLabel)

            // Horizontal scroll of category pills with create button
	            ScrollView(.horizontal, showsIndicators: false) {
	                HStack(spacing: FormaSpacing.tight) {
                    ForEach(sortedCategories) { category in
                        CategoryPill(
                            category: category,
                            isSelected: formState.categoryID == category.id,
                            action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    // Toggle: deselect if already selected (reverts to General)
                                    if formState.categoryID == category.id && !category.isDefault {
                                        // Find and select the default category
                                        if let defaultCategory = sortedCategories.first(where: { $0.isDefault }) {
                                            formState.categoryID = defaultCategory.id
                                        } else {
                                            formState.categoryID = nil
                                        }
                                    } else {
                                        formState.categoryID = category.id
                                    }
                                }
                            }
                        )
                    }

	                    // Create Category button - perfect circle, same height as pills
	                    createCategoryButton
	                }
	                .padding(.vertical, FormaSpacing.micro / 2)
	            }

            // Show scope hint if a scoped category is selected
	            if let selectedCategory = sortedCategories.first(where: { $0.id == formState.categoryID }),
	               case .folders = selectedCategory.scope {
	                HStack(spacing: 4) {
	                    Image(systemName: "folder.badge.gearshape")
	                        .font(.formaCaption)
	                    Text("This category only applies to files from specific folders")
	                        .font(.formaCaption)
	                }
	                .foregroundColor(selectedCategory.color.opacity(Color.FormaOpacity.prominent))
	                .padding(.top, FormaSpacing.micro / 2)
	            }
	        }
	    }

    @ViewBuilder
    private var destinationStatusBanner: some View {
        if let resolvability = destinationResolvability {
            switch resolvability {
            case .valid:
                EmptyView()

            case .resolvable(let parentFolder):
                HStack(alignment: .top, spacing: FormaSpacing.tight) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.formaSteelBlue)
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Folder will be created on save")
                            .font(.formaCaption)
                            .fontWeight(.medium)
                            .foregroundColor(.formaObsidian)

                        Text("Forma can create this destination inside \(parentFolder) as soon as you save the rule.")
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(FormaSpacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.formaSteelBlue.opacity(0.08))
                .cornerRadius(FormaRadius.control)

            case .unresolvable(let reason):
                HStack(alignment: .top, spacing: FormaSpacing.tight) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Destination may not work")
                            .font(.formaCaption)
                            .fontWeight(.medium)
                            .foregroundColor(.formaObsidian)

                        Text(reason)
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Grant access to the suggested parent folder and Forma will finish the destination path for you.")
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: requestDestinationAccess) {
                            Text(isChoosingDestination ? "Granting Access..." : "Grant Access")
                                .font(.formaCaptionSemibold)
                                .foregroundColor(.formaSteelBlue)
                        }
                        .buttonStyle(.plain)
                        .disabled(isChoosingDestination)
                    }
                }
                .padding(FormaSpacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(FormaRadius.control)
            }
        }
    }

    /// Subtle circular button to create a new category
    private var createCategoryButton: some View {
        Button(action: {
            newCategoryName = ""
            newCategoryColor = .formaSteelBlue
            showCreateCategoryPopover = true
        }) {
	            Image(systemName: "plus")
	                .font(.formaSmall)
	                .foregroundColor(Color.formaSecondaryLabel)
	                .frame(width: 28, height: 28)
	                .background(
	                    Circle()
	                        .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
	                )
	                .overlay(
	                    Circle()
	                        .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.overlay), lineWidth: 1)
	                )
	        }
        .buttonStyle(.plain)
        .help("Create new category")
        .popover(isPresented: $showCreateCategoryPopover, arrowEdge: .bottom) {
            CreateCategoryPopover(
                name: $newCategoryName,
                color: $newCategoryColor,
                onSave: saveNewCategory,
                onCancel: { showCreateCategoryPopover = false }
            )
        }
    }

    /// Saves a new category created from the popover
    private func saveNewCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Create the new category
        let newCategory = RuleCategory(
            name: trimmedName,
            colorHex: newCategoryColor.hexString,
            iconName: "folder.fill"
        )
        newCategory.sortOrder = sortedCategories.count

        modelContext.insert(newCategory)

        // Auto-select the newly created category
        formState.categoryID = newCategory.id

        showCreateCategoryPopover = false
    }

    // MARK: - Helper Functions

    /// Collapses the modal editor back to the right panel
    /// Transfers current state (editingRule and fileContext) to the panel
    private func collapseToPanel() {
        // Close the modal
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }

        // Open the panel with the current rule context
        // Small delay to ensure modal dismissal animation starts first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dashboardViewModel.showRuleBuilderPanel(editingRule: editingRule, fileContext: fileContext)
        }
    }

    private func applyParsedRuleFromNaturalLanguage(_ parsed: NLParsedRule) {
        guard parsed.isComplete, !parsed.hasBlockingError else { return }

        // Map action
        if let action = parsed.primaryAction {
            formState.actionType = action
        }

        // Map destination (only for move/copy)
        // Note: Natural language parsing provides path strings, not bookmarks
        // User will need to confirm via folder picker for sandbox access
        if let dest = parsed.destinationPath, !dest.isEmpty {
            formState.destinationDisplayPath = dest
            // Clear bookmark since NL path is just a string
            formState.destinationBookmarkData = nil
        }

        // Map conditions
        if parsed.candidateConditions.count == 1, let first = parsed.candidateConditions.first {
            formState.useCompoundConditions = false
            formState.conditionType = first.type
            formState.conditionValue = first.value
        } else if !parsed.candidateConditions.isEmpty {
            formState.useCompoundConditions = true
            formState.conditions = parsed.candidateConditions
            formState.logicalOperator = parsed.logicalOperator
        }

        // Suggest a rule name if none provided yet
        if formState.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = parsed.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                formState.name = trimmed
            }
        }
    }

    private func validateRule() -> Bool {
        if let result = RuleValidator.validate(
            formState: formState,
            editingRule: editingRule,
            naturalLanguageViewModel: naturalLanguageViewModel,
            mode: .fullEditor
        ) {
            validationError = result.message
            if result.shouldShake {
                triggerValidationShake.toggle()
            }
            return false
        }

        validationError = nil
        return true
    }

    private func showSaveError(_ message: String) {
        validationError = message
        saveButtonState = .error

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            saveButtonState = .normal
        }
    }

    private func buildRuleCandidate(destination: Destination?) throws -> Rule {
        let trimmedName = formState.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let exclusions = formState.showExclusionConditions ? formState.exclusionConditions : []
        let enableFlag = editingRule == nil && formState.actionType == .delete ? false : formState.isEnabled

        if formState.useCompoundConditions {
            let rule = Rule(
                name: trimmedName,
                conditions: formState.conditions,
                logicalOperator: formState.logicalOperator,
                actionType: formState.actionType,
                destination: destination,
                isEnabled: enableFlag,
                exclusionConditions: exclusions,
                category: selectedCategory
            )
            return rule
        }

        let conditionValue = formState.conditionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try RuleCondition(type: formState.conditionType, value: conditionValue)

        return Rule(
            name: trimmedName,
            conditionType: formState.conditionType,
            conditionValue: conditionValue,
            actionType: formState.actionType,
            destination: destination,
            isEnabled: enableFlag,
            exclusionConditions: exclusions,
            category: selectedCategory
        )
    }

    private func saveRule() {
        guard validateRule() else {
            showSaveError(validationError ?? "Please review the highlighted fields.")
            return
        }

        do {
            let candidateRule = try buildRuleCandidate(destination: formState.buildDestination())
            let overlaps = RuleOverlapDetector().detectOverlaps(
                for: candidateRule,
                against: sortedExistingRules,
                excludeRuleID: editingRule?.id
            )

            if !overlaps.isEmpty {
                pendingRuleForSave = candidateRule
                detectedOverlaps = overlaps
                showOverlapWarning = true
                saveButtonState = .normal
                return
            }

            commitSave(rule: candidateRule)
        } catch {
            showSaveError("Failed to prepare rule: \(error.localizedDescription)")
        }
    }

    private func commitSave(rule: Rule) {
        saveButtonState = .loading

        let ruleService = RuleService(modelContext: modelContext)

        do {
            let materializedDestination = try destinationResolver.materializeForExplicitSave(rule.destination)

            if let existingRule = editingRule {
                existingRule.name = rule.name
                existingRule.actionType = rule.actionType
                existingRule.destination = materializedDestination
                existingRule.isEnabled = rule.isEnabled
                existingRule.category = rule.category
                existingRule.exclusionConditions = rule.exclusionConditions
                existingRule.conditionType = rule.conditionType
                existingRule.conditionValue = rule.conditionValue
                existingRule.conditions = rule.conditions
                existingRule.logicalOperator = rule.logicalOperator

                try ruleService.updateRule(existingRule)
            } else {
                rule.destination = materializedDestination
                try ruleService.createRule(rule, source: ruleSourceForSave)
            }

            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)
            pendingRuleForSave = nil
            detectedOverlaps = []
            saveButtonState = .success

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
        } catch {
            showSaveError("Failed to save rule: \(error.localizedDescription)")
        }
    }

    private func previewDeleteRuleMatches() {
        // Only run for delete rules; for other actions this is informational at best.
        let previewConditions: [RuleCondition]
        let previewConditionType: Rule.ConditionType
        let previewConditionValue: String
        let previewLogicalOperator: Rule.LogicalOperator

        if formState.useCompoundConditions {
            previewConditions = formState.conditions
            previewConditionType = formState.conditions.first?.type ?? formState.conditionType
            previewConditionValue = formState.conditions.first?.value ?? formState.conditionValue
            previewLogicalOperator = formState.logicalOperator
        } else {
            previewConditions = []
            previewConditionType = formState.conditionType
            previewConditionValue = formState.conditionValue
            previewLogicalOperator = .single
        }

        let matches = dashboardViewModel.matchingFilesForRulePreview(
            conditions: previewConditions,
            conditionType: previewConditionType,
            conditionValue: previewConditionValue,
            logicalOperator: previewLogicalOperator,
            actionType: formState.actionType,
            destination: formState.buildDestination()
        )

        deletePreviewFiles = matches
        showDeletePreviewSheet = true
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
                formState.destinationDisplayPath = destination.displayName
                formState.destinationBookmarkData = destination.bookmarkData
            } catch DestinationResolver.AccessGrantError.cancelled {
                return
            } catch {
                validationError = "Failed to grant access for destination: \(error.localizedDescription)"
            }
        }
    }
}

/// Sheet that previews files matching a delete rule configuration.
/// This does not perform any destructive operations; it simply lists the
/// files that would match if the rule were enabled and applied.
private struct DeleteRulePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let files: [FileItem]

    var body: some View {
	        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
	            HStack(spacing: FormaSpacing.tight) {
	                Image(systemName: "trash")
	                    .foregroundColor(.formaError)
	                Text("Delete rule preview")
                    .font(.formaH3)
                    .foregroundColor(.formaLabel)
                Spacer()
            }

            Text("These files currently match this rule. They will not be deleted until you explicitly run an organization pass.")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)

            Text("Matches: \(files.count)")
                .font(.formaBodySemibold)
                .foregroundColor(files.count > 50 ? .formaWarmOrange : .formaSecondaryLabel)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(files, id: \.path) { file in
	                        HStack(spacing: FormaSpacing.tight) {
                            Image(systemName: "doc")
                                .foregroundColor(.formaSecondaryLabel)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.formaBody)
                                    .foregroundColor(.formaLabel)
                                Text(file.path)
                                    .font(.formaCaption)
                                    .foregroundColor(.formaSecondaryLabel)
                                    .lineLimit(1)
                            }
                            Spacer()
	                        }
	                        .padding(FormaSpacing.micro)
	                    }
	                }
	            }
            .frame(maxHeight: 260)

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, FormaSpacing.standard)
        }
        .padding(FormaSpacing.large)
        .frame(width: 460, height: 360)
    }
}

// MARK: - View Extension for conditional modifiers

extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    RuleEditorView()
        .modelContainer(for: Rule.self, inMemory: true)
}
