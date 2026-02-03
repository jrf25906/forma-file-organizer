import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - RuleEditorView

struct RuleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel

    // Categories for picker
    @Query private var categories: [RuleCategory]

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
    @State private var showFolderPicker: Bool = false
    @State private var validationError: String?
    @State private var triggerValidationShake: Bool = false
    
    // Natural language rule creation
    @StateObject private var naturalLanguageViewModel = NaturalLanguageRuleViewModel()
    
    // Delete rule safety preview
    @State private var deletePreviewFiles: [FileItem] = []
    @State private var showDeletePreviewSheet: Bool = false

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
                            showFolderPicker: $showFolderPicker,
                            onPreviewDeleteMatches: previewDeleteRuleMatches
                        )
                    }
                    .padding(20)
                    .background(Color.formaBoneWhite)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

                    // Destination warning for unresolvable placeholders
                    if let resolvability = destinationResolvability,
                       case .unresolvable(let reason) = resolvability {
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

                                Button(action: { showFolderPicker = true }) {
                                    Text("Select Folder")
                                        .font(.formaCaptionSemibold)
                                        .foregroundColor(.formaSteelBlue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(FormaSpacing.standard)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(FormaRadius.control)
                    }

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
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
        .sheet(isPresented: $showDeletePreviewSheet) {
            DeleteRulePreviewSheet(files: deletePreviewFiles)
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

    private func saveRule() {
        guard validateRule() else {
            saveButtonState = .error
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                saveButtonState = .normal
            }
            return
        }
        
        // Show loading state
        saveButtonState = .loading

        // Build destination from form state
        let destination = formState.buildDestination()

        let ruleService = RuleService(modelContext: modelContext)

        do {
            // Resolve category from selected ID
            let selectedCategory: RuleCategory?
            if let categoryID = formState.categoryID {
                selectedCategory = sortedCategories.first { $0.id == categoryID }
            } else {
                // Default to General category if no selection
                selectedCategory = sortedCategories.first { $0.isDefault }
            }

            if let existingRule = editingRule {
                // Update existing rule
                existingRule.name = formState.name
                existingRule.actionType = formState.actionType
                existingRule.destination = destination
                existingRule.isEnabled = formState.isEnabled
                existingRule.category = selectedCategory

                if formState.useCompoundConditions {
                    existingRule.conditions = formState.conditions
                    existingRule.logicalOperator = formState.logicalOperator
                } else {
                    existingRule.conditionType = formState.conditionType
                    existingRule.conditionValue = formState.conditionValue
                    existingRule.conditions = []
                    existingRule.logicalOperator = .single
                }

                // Update exclusion conditions
                existingRule.exclusionConditions = formState.showExclusionConditions ? formState.exclusionConditions : []

                try ruleService.updateRule(existingRule)
            } else {
                // Create new rule
                let enableFlag: Bool = (formState.actionType == .delete) ? false : formState.isEnabled

                // Get exclusion conditions if enabled
                let exclusions = formState.showExclusionConditions ? formState.exclusionConditions : []

                let newRule: Rule
                if formState.useCompoundConditions {
                    newRule = Rule(
                        name: formState.name,
                        conditions: formState.conditions,
                        logicalOperator: formState.logicalOperator,
                        actionType: formState.actionType,
                        destination: destination,
                        isEnabled: enableFlag,
                        exclusionConditions: exclusions
                    )
                } else {
                    newRule = Rule(
                        name: formState.name,
                        conditionType: formState.conditionType,
                        conditionValue: formState.conditionValue,
                        actionType: formState.actionType,
                        destination: destination,
                        isEnabled: enableFlag,
                        exclusionConditions: exclusions
                    )
                }

                // Assign category to new rule
                newRule.category = selectedCategory

                // Determine source for activity logging
                let nlText = naturalLanguageViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let source: RuleService.RuleSource
                if !nlText.isEmpty, naturalLanguageViewModel.parsedRule != nil {
                    source = .naturalLanguage(text: nlText)
                } else {
                    source = .ruleEditor
                }

                try ruleService.createRule(newRule, source: source)
            }

            // Re-evaluate all files against updated rules
            dashboardViewModel.loadRules(from: modelContext)
            dashboardViewModel.reEvaluateFilesAgainstRules(context: modelContext)

            // Show success state briefly
            saveButtonState = .success

            // Dismiss after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
        } catch {
            validationError = "Failed to save rule: \(error.localizedDescription)"
            saveButtonState = .error

            // Reset to normal after showing error
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                saveButtonState = .normal
            }
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

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                validationError = "Failed to access selected folder. Please try again."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Create security-scoped bookmark
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                formState.destinationBookmarkData = bookmarkData

                // Set display name (relative path from home if possible)
                let homeURL = FileManager.default.homeDirectoryForCurrentUser
                if url.path.hasPrefix(homeURL.path) {
                    let relativePath = String(url.path.dropFirst(homeURL.path.count + 1))
                    formState.destinationDisplayPath = relativePath
                } else {
                    formState.destinationDisplayPath = url.lastPathComponent
                }

                validationError = nil
            } catch {
                validationError = "Failed to create bookmark for folder: \(error.localizedDescription)"
            }

        case .failure(let error):
            validationError = "Failed to select folder: \(error.localizedDescription)"
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
