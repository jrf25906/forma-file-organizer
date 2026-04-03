import SwiftUI
import SwiftData

// MARK: - RuleEditorView

struct RuleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    private let isUITesting = CommandLine.arguments.contains("--uitesting")

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
    @State private var matchedFilesCount: Int = 0
    @State private var impactPreviewFiles: [FileItem] = []
    @State private var isLoadingImpactPreview: Bool = false
    @State private var impactPreviewTask: Task<Void, Never>?
    
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
                .accessibilityIdentifier("collapseRuleEditorButton")
                .help("Collapse to Side Panel")

                Button(action: {
                    dismissDraft()
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
                            .accessibilityLabel("Rule Name")
                            .accessibilityIdentifier("modalRuleNameField")
                            .accessibilityValue(formState.name)
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

                    composerSectionCard(
                        title: "When",
                        subtitle: "Choose which files this rule should target."
                    ) {
                        RuleConditionBuilder(formState: $formState)
                        composerValidationMessage(whenValidationMessage)
                    }
                    .overlay(alignment: .topLeading) {
                        if isUITesting {
                            Color.clear
                                .frame(width: 1, height: 1)
                                .accessibilityElement(children: .ignore)
                                .accessibilityIdentifier("ruleComposerWhenSection")
                        }
                    }

                    composerSectionCard(
                        title: "Then",
                        subtitle: "Define what happens to matched files."
                    ) {
                        RuleDestinationPicker(
                            formState: $formState,
                            onChooseFolder: requestDestinationAccess,
                            onPreviewDeleteMatches: previewDeleteRuleMatches
                        )

                        destinationStatusBanner
                        composerValidationMessage(thenValidationMessage)
                    }
                    .overlay(alignment: .topLeading) {
                        if isUITesting {
                            Color.clear
                                .frame(width: 1, height: 1)
                                .accessibilityElement(children: .ignore)
                                .accessibilityIdentifier("ruleComposerThenSection")
                        }
                    }

                    // Category picker
                    if !sortedCategories.isEmpty {
                        composerSectionCard(
                            title: "Category",
                            subtitle: "Group this rule with related organization behavior."
                        ) {
                            categoryPickerSection
                        }
                    }

                    impactPreviewCard
                        .overlay(alignment: .topLeading) {
                            if isUITesting {
                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityIdentifier("ruleComposerImpactSection")
                            }
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
                SecondaryButton(editingRule == nil ? "Discard Draft" : "Cancel") {
                    dismissDraft()
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
                        title: editingRule == nil ? "Save Rule" : "Save Changes",
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
                .disabled(saveButtonState != .normal || !canSubmitRule)
                .opacity(saveButtonState == .normal && canSubmitRule ? 1 : 0.6)
                .accessibilityIdentifier("ruleComposerSaveButton")
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
            if let draftSession = nav.ruleDraftSession {
                formState = draftSession.formState
            } else if let rule = editingRule {
                formState = RuleFormState(from: rule)
            } else if let file = fileContext {
                formState = RuleFormState(from: file)
            }

            let seedSuggestedText = nav.ruleDraftSession?.suggestedNaturalLanguageText ?? suggestedNaturalLanguageText
            if editingRule == nil,
               let suggestedText = seedSuggestedText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !suggestedText.isEmpty,
               naturalLanguageViewModel.text.isEmpty {
                naturalLanguageViewModel.onTextChanged(suggestedText)
                naturalLanguageViewModel.parseImmediately()
            }

            // Auto-select default category if none is selected yet
            if formState.categoryID == nil, let defaultCategory = sortedCategories.first(where: { $0.isDefault }) {
                formState.categoryID = defaultCategory.id
            }

            nav.updateRuleDraftFormState(formState)
            updateImpactPreview()
        }
        .onChange(of: formState) { _, newValue in
            nav.updateRuleDraftFormState(newValue)
            updateImpactPreview()
        }
        .onDisappear {
            impactPreviewTask?.cancel()
            impactPreviewTask = nil
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

    private func composerSectionCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            composerSectionHeader(title: title, subtitle: subtitle)
            content()
        }
        .padding(20)
        .background(Color.formaBoneWhite)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func composerSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text(title)
                .font(.formaBodyBold)
                .foregroundColor(.formaLabel)
            Text(subtitle)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
        }
    }

    @ViewBuilder
    private func composerValidationMessage(_ message: String?) -> some View {
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

    private var impactPreviewCard: some View {
        composerSectionCard(
            title: "Impact",
            subtitle: "Preview what this rule will affect before you save it."
        ) {
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: impactTone.icon)
                            .foregroundColor(impactTone.color)
                        Text(impactTone.title)
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaLabel)
                    }

                    Text(impactTone.message)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }

                Spacer()

                FormaBadge(
                    text: "\(matchedFilesCount) match\(matchedFilesCount == 1 ? "" : "es")",
                    color: impactTone.color,
                    size: .small,
                    style: .subtle
                )
            }

            if !hasValidConditionInput {
                Text("Complete the \"When\" section to preview impact.")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
            } else if isLoadingImpactPreview {
                HStack(spacing: FormaSpacing.tight) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Matching files...")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
            } else {
                Text(impactSummaryText)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)

                if !impactPreviewFiles.isEmpty {
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        ForEach(impactPreviewFiles) { file in
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
                    }
                }
            }
        }
    }

    /// Category picker allowing users to assign the rule to an organizational category.
    /// Uses compact pill-style selection with category colors.
    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
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
    private func collapseToPanel() {
        if nav.ruleDraftSession == nil {
            nav.beginRuleDraft(
                editingRule: editingRule,
                fileContext: fileContext,
                suggestedNaturalLanguageText: suggestedNaturalLanguageText,
                presentation: .modal,
                returnTarget: draftReturnTarget
            )
        }

        nav.updateRuleDraftFormState(formState)
        nav.presentRuleDraftPanel()

        // Open the panel with the current rule context
        // Small delay to ensure modal dismissal animation starts first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let draftSession = nav.ruleDraftSession
            dashboardViewModel.showRuleBuilderPanel(
                editingRule: draftSession?.editingRule ?? editingRule,
                fileContext: draftSession?.fileContext ?? fileContext
            )
        }
    }

    private var draftReturnTarget: RuleDraftReturnTarget {
        if let fileContext {
            return .inspector(filePath: fileContext.path)
        }
        return .defaultPanel
    }

    private func dismissDraft() {
        if nav.ruleDraftSession != nil {
            let returnTarget = nav.ruleDraftSession?.returnTarget ?? draftReturnTarget
            nav.discardRuleDraft()
            dashboardViewModel.restorePanel(afterRuleDraftReturnTarget: returnTarget)
            return
        }

        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
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

    private func updateImpactPreview() {
        impactPreviewTask?.cancel()

        guard hasValidConditionInput else {
            withAnimation(.easeInOut(duration: 0.15)) {
                impactPreviewFiles = []
                matchedFilesCount = 0
                isLoadingImpactPreview = false
            }
            return
        }

        isLoadingImpactPreview = true

        impactPreviewTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

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

            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.15)) {
                impactPreviewFiles = Array(matches.prefix(3))
                matchedFilesCount = matches.count
                isLoadingImpactPreview = false
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
        let isWorkflowDraft = nav.ruleDraftSession != nil
        let workflowReturnTarget = nav.ruleDraftSession?.returnTarget ?? draftReturnTarget

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
                if isWorkflowDraft {
                    nav.clearRuleDraft()
                    dashboardViewModel.restorePanel(afterRuleDraftReturnTarget: workflowReturnTarget)
                } else if let onDismiss = onDismiss {
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
