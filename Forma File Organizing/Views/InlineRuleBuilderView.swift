import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Compact inline rule builder for the right panel
struct InlineRuleBuilderView: View {
    let editingRule: Rule?
    let fileContext: FileItem?
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Environment(\.modelContext) private var modelContext

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
        categories.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.creationDate < rhs.creationDate
        }
    }

    // Consolidated form state (8 properties → 1)
    @State private var formState = RuleFormState()

    // UI state (kept separate - these control UI behavior, not form data)
    @State private var validationError: String?
    @State private var matchedFilesCount: Int = 0
    @State private var previewFiles: [FileItem] = []
    @State private var isLoadingPreview: Bool = false
    @State private var previewTask: Task<Void, Never>?
    @State private var showFolderPicker: Bool = false
    @State private var showConditionForm: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    // Overlap detection state
    @State private var detectedOverlaps: [RuleOverlapDetector.RuleOverlap] = []
    @State private var showOverlapWarning: Bool = false
    @State private var pendingRuleForSave: Rule?

    // Create category popover state
    @State private var showCreateCategoryPopover: Bool = false
    @State private var newCategoryName: String = ""
    @State private var newCategoryColor: Color = .formaSteelBlue

    // Natural language rule creation
    @StateObject private var naturalLanguageViewModel = NaturalLanguageRuleViewModel()
    
    // MARK: - Header Configuration

    /// Determines the header icon, title, and subtitle based on context
    private var headerConfig: (icon: String, title: String, subtitle: String?) {
        if let _ = editingRule {
            // Editing existing rule
            return ("slider.horizontal.3", "Edit Rule", "Modify conditions & destination")
        } else if fileContext != nil {
            // Creating from file context - quick rule
            return ("bolt.fill", "Quick Rule", "From this file's pattern")
        } else {
            // Creating from scratch
            return ("wand.and.stars", "New Rule", nil)
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
                                .foregroundColor(.formaSecondaryLabel)
                        }
                    }
                }

                Spacer()

                // Expand to modal button
                Button(action: expandToModal) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(.formaSecondaryLabel)
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
                        .foregroundColor(.formaSecondaryLabel)
                        .font(.formaH3)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .allowsHitTesting(true)
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, FormaSpacing.standard)
            .background(.regularMaterial)
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
                    VStack(alignment: .leading, spacing: 20) {
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

                        // 3. Sentence Builder Section (Visual Verification)
                        VStack(alignment: .leading, spacing: 16) {
                            // Header with Toggle
                            HStack {
                                Text("Matches")
                                    .font(.formaBodyLarge)
                                    .foregroundColor(.formaSecondaryLabel)
                                
                                Spacer()
                                
                                Toggle("Multiple", isOn: $formState.useCompoundConditions)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .controlSize(.mini)
                                    .onChange(of: formState.useCompoundConditions) { _, newValue in
                                        if newValue && formState.conditions.isEmpty {
                                            // Initialize with one condition from legacy fields
                                            do {
                                                let condition = try RuleCondition(type: formState.conditionType, value: formState.conditionValue)
                                                formState.conditions = [condition]
                                            } catch {
                                                // Ignore invalid initial condition
                                            }
                                        }
                                    }
                            }
                            .padding(.bottom, 4)

                            if formState.useCompoundConditions {
                                // Compound conditions view
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("If")
                                            .font(.formaBodyLarge)
                                            .foregroundColor(.formaSecondaryLabel)

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

                                    Button(action: {
                                        addCondition()
                                    }) {
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
                                // Single condition view
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("If file")
                                        .font(.formaBodyLarge)
                                        .foregroundColor(.formaSecondaryLabel)
                                    
                                    // Condition Type Picker (Inline)
                                    Menu {
                                        ForEach(Rule.ConditionType.allCases, id: \.self) { type in
                                            Button(conditionDisplayName(for: type)) {
                                                formState.conditionType = type
                                            }
                                        }
                                    } label: {
                                        Text(conditionDisplayName(for: formState.conditionType).lowercased())
                                            .font(.formaBodyLarge)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.formaSteelBlue)
                                            .underline(true, color: .formaSteelBlue.opacity(0.3))
                                    }
                                    .menuStyle(.borderlessButton)
                                    
                                    Text("is")
                                        .font(.formaBodyLarge)
                                        .foregroundColor(.formaSecondaryLabel)
                                }
                                
                                // Condition Value (Inline)
                                TextField(conditionPlaceholder, text: $formState.conditionValue)
                                    .font(.formaBodyLarge)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(Color.formaControlBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.formaSeparator, lineWidth: 1)
                                    )
                                    .onChange(of: formState.conditionValue) { _, _ in
                                        updatePreview()
                                    }
                            }
                            
                            // "Then..."
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("Then")
                                    .font(.formaBodyLarge)
                                    .foregroundColor(.formaSecondaryLabel)
                                
                                // Action Picker (Inline)
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
                                    .foregroundColor(.formaSecondaryLabel)
                                    .opacity(formState.actionType == .delete ? 0.3 : 1.0)
                            }
                            
                            // Destination (Inline)
                            if formState.actionType == .delete {
                                Text("Trash")
                                    .font(.formaBodyLarge)
                                    .fontWeight(.medium)
                                    .foregroundColor(.formaError)
                                    .padding(.vertical, 4)
                            } else {
                                Button(action: { showFolderPicker = true }) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.formaSteelBlue)
                                        Text(formState.destinationDisplayPath.isEmpty ? "Select folder..." : formState.destinationDisplayPath)
                                            .fontWeight(.medium)
                                            .foregroundColor(formState.destinationDisplayPath.isEmpty ? .formaSecondaryLabel : .formaObsidian)
                                        
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
                                            .stroke(formState.destinationDisplayPath.isEmpty ? Color.formaSteelBlue : Color.formaSeparator, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                        .background(Color.formaBoneWhite)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

                        // 3. Category Chip (Subtle)
                        HStack {
                            Text("Category:")
                                .font(.formaSmall)
                                .foregroundColor(.formaSecondaryLabel)
                            
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
                                            .foregroundColor(formState.categoryID == category.id ? category.color : .formaSecondaryLabel)
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)

                        // Live Preview
                        if matchedFilesCount > 0 {
                            livePreviewCard
                        }

                        // Save Actions
                        VStack(spacing: 12) {
                            Button(action: {
                                if formState.actionType == .delete && matchedFilesCount > 0 {
                                    showDeleteConfirmation = true
                                } else {
                                    saveRule()
                                }
                            }) {
                                Text(editingRule == nil ? "Create Rule" : "Save Changes")
                                    .font(.formaBodyBold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.formaSteelBlue)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.vertical, 20)
                }
            }
        }
        .onAppear {
            initializeFields()
            updatePreview()
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
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

    // MARK: - Category Picker Section

    /// Compact category picker using horizontal pill selection
    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text("Category")
                .font(.formaBodySemibold)
                .tracking(0.5)
                .foregroundColor(.formaSecondaryLabel)

            if sortedCategories.isEmpty {
                // Fallback text when categories haven't loaded yet
                Text("Loading categories...")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
                    .padding(.vertical, FormaSpacing.tight)
            } else {
                // Horizontal scroll of category pills with create button
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FormaSpacing.tight) {
                        ForEach(sortedCategories) { category in
                            CategoryPill(
                                category: category,
                                isSelected: formState.categoryID == category.id,
                                textFont: .formaCompactMedium,
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
                        inlineCreateCategoryButton
                    }
                    .padding(.vertical, FormaSpacing.micro / 2)
                }
            }
        }
        .id("category-section")
    }

    /// Subtle circular button to create a new category
    private var inlineCreateCategoryButton: some View {
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

    // MARK: - Condition Row
    
    @ViewBuilder
    private func editableConditionRow(at index: Int) -> some View {
        HStack(spacing: FormaSpacing.tight) {
            // Condition type selector
            Menu {
                ForEach(Rule.ConditionType.allCases, id: \.self) { type in
                    Button(conditionDisplayName(for: type)) {
                        updateConditionType(at: index, to: type)
                    }
                }
            } label: {
                 Text(conditionDisplayName(for: index < formState.conditions.count ? formState.conditions[index].type : .fileExtension))
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
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
                    .foregroundColor(.formaSecondaryLabel)
                    .font(.formaSmall)
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaCardBackground)
        .cornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
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
    
    // MARK: - Live Preview Card
    
    private var livePreviewCard: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.formaSteelBlue)
                Text("Live Preview")
                    .font(.formaBodySemibold)
                    .tracking(0.5)
                    .foregroundColor(.formaSecondaryLabel)
            }
            
            if isLoadingPreview {
                HStack(spacing: FormaSpacing.tight) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Matching files...")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
            } else {
                Text("This rule would match \(matchedFilesCount) file\(matchedFilesCount == 1 ? "" : "s")")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)

                // Show up to 3 matched files (from cached previewFiles)
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
                        }

                        if matchedFilesCount > 3 {
                            Text("+\(matchedFilesCount - 3) more")
                                .font(.formaCaption)
                                .foregroundColor(.formaSecondaryLabel)
                        }
                    }
                }
            }
        }
        .padding(FormaSpacing.large)
        .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSteelBlue.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
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
        // Validation
        guard !formState.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "Rule name is required"
            return
        }

        // Check if we have at least one condition (either in conditions array or in the input field)
        let hasConditions = !formState.conditions.isEmpty || !formState.conditionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasConditions else {
            validationError = "At least one condition is required"
            return
        }

        // Validate destination - require bookmark for move/copy actions
        if formState.actionType == .move || formState.actionType == .copy {
            guard formState.hasBookmark else {
                validationError = "Please select a destination folder"
                return
            }
        }

        validationError = nil

        // Build final conditions array
        var finalConditions: [RuleCondition] = []

        if formState.useCompoundConditions {
            finalConditions = formState.conditions
        } else {
            if !formState.conditionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    let condition = try RuleCondition(
                        type: formState.conditionType,
                        value: formState.conditionValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    finalConditions.append(condition)
                } catch {
                    validationError = error.localizedDescription
                    return
                }
            }
        }

        // Build unified Destination from form state
        let destination = formState.buildDestination()

        // Build the rule object for overlap detection
        let ruleToCheck: Rule
        if finalConditions.count > 1 {
            ruleToCheck = Rule(
                name: formState.name.trimmingCharacters(in: .whitespacesAndNewlines),
                conditions: finalConditions,
                logicalOperator: formState.logicalOperator,
                actionType: formState.actionType,
                destination: destination,
                isEnabled: formState.isEnabled
            )
        } else if let condition = finalConditions.first {
            ruleToCheck = Rule(
                name: formState.name.trimmingCharacters(in: .whitespacesAndNewlines),
                conditionType: condition.type,
                conditionValue: condition.value,
                actionType: formState.actionType,
                destination: destination,
                isEnabled: formState.isEnabled
            )
        } else {
            Log.error("InlineRuleBuilderView: saveRule called with no conditions", category: .analytics)
            validationError = "At least one condition is required"
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

        // Resolve category from selected ID
        let selectedCategory: RuleCategory?
        if let categoryID = formState.categoryID {
            selectedCategory = sortedCategories.first { $0.id == categoryID }
        } else {
            // Default to General category if no selection
            selectedCategory = sortedCategories.first { $0.isDefault }
        }

        do {
            if let existingRule = editingRule {
                // Update existing rule's properties from the checked rule
                existingRule.name = rule.name
                existingRule.actionType = rule.actionType
                existingRule.isEnabled = rule.isEnabled
                existingRule.destination = rule.destination
                existingRule.category = selectedCategory

                if !rule.conditions.isEmpty {
                    existingRule.conditions = rule.conditions
                    existingRule.logicalOperator = rule.logicalOperator
                } else {
                    existingRule.conditionType = rule.conditionType
                    existingRule.conditionValue = rule.conditionValue
                    existingRule.conditions = []
                    existingRule.logicalOperator = .single
                }

                try ruleService.updateRule(existingRule)
            } else {
                // Assign category to new rule
                rule.category = selectedCategory
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
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing the security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                // Create security-scoped bookmark data
                // This persists access across app launches and avoids path comparison bugs
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                // Store bookmark and display name in unified form state
                formState.destinationBookmarkData = bookmarkData
                formState.destinationDisplayPath = url.lastPathComponent

                validationError = nil

                #if DEBUG
                Log.info("InlineRuleBuilderView: Created bookmark for '\(url.lastPathComponent)' at \(url.path)", category: .bookmark)
                #endif

            } catch {
                #if DEBUG
                Log.error("InlineRuleBuilderView: Failed to create bookmark - \(error.localizedDescription)", category: .bookmark)
                #endif
                validationError = "Failed to save folder access: \(error.localizedDescription)"
            }

        case .failure(let error):
            validationError = "Failed to select folder: \(error.localizedDescription)"
        }
    }

    // Note: defaultDestination(for:) moved to RuleFormState struct
    
    private func conditionDisplayName(for type: Rule.ConditionType) -> String {
        switch type {
        case .fileExtension: return "Extension is"
        case .nameContains: return "Name contains"
        case .nameStartsWith: return "Name starts with"
        case .nameEndsWith: return "Name ends with"
        case .sourceLocation: return "Source location is"
        default: return type.rawValue.capitalized
        }
    }

    private var conditionPlaceholder: String {
        conditionPlaceholder(for: formState.conditionType)
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

    private var conditionHint: String {
        switch formState.conditionType {
        case .fileExtension: return "Without the dot (e.g., 'pdf' not '.pdf')"
        case .nameContains: return "Case insensitive match"
        case .nameStartsWith: return "Checks the beginning of the filename"
        case .nameEndsWith: return "Checks the end of the filename (before extension)"
        case .sourceLocation: return "Options: desktop, downloads, documents, pictures, music, home"
        default: return ""
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
        let container = try! ModelContainer(for: FileItem.self, Rule.self, RuleCategory.self, ActivityItem.self, CustomFolder.self, configurations: config)

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
