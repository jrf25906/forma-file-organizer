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
        categories.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.creationDate < rhs.creationDate
        }
    }

    let editingRule: Rule?
    let fileContext: FileItem?
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
    @State private var conditionTypeChangeId = UUID()
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Destination resolver for checking placeholder resolvability
    private let destinationResolver = DestinationResolver()

    init(rule: Rule? = nil, fileContext: FileItem? = nil, onDismiss: (() -> Void)? = nil, buttonNamespace: Namespace.ID? = nil) {
        self.editingRule = rule
        self.fileContext = fileContext
        self.onDismiss = onDismiss
        self.buttonNamespace = buttonNamespace
    }

    // MARK: - Header Configuration

    /// Determines the header icon, title, and subtitle based on context
    private var headerConfig: (icon: String, title: String, subtitle: String?) {
        if let _ = editingRule {
            // Editing existing rule
            return ("slider.horizontal.3", "Edit Rule", "Advanced conditions & actions")
        } else if fileContext != nil {
            // Creating from file context
            return ("bolt.fill", "Quick Rule", "From this file's pattern")
        } else {
            // Full rule editor from scratch
            return ("slider.horizontal.3", "Rule Editor", "Advanced conditions & actions")
        }
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
                        
                        // Matches Section
                        VStack(alignment: .leading, spacing: 16) {
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
                                            do {
                                                let condition = try RuleCondition(type: formState.conditionType, value: formState.conditionValue)
                                                formState.conditions = [condition]
                                            } catch {
                                                Log.warning("RuleEditorView: Failed to create initial compound condition", category: .general)
                                            }
                                        }
                                    }
                            }

                            if formState.useCompoundConditions {
                                compoundConditionsView
                            } else {
                                singleConditionView
                            }
                        }

                        // Exceptions (Except when...) - Keep this inside the card? 
                        // Inline doesn't show exceptions usually, but for consistency let's put it here or in a separate card?
                        // The user said "functionality of create rule modal is preferable", which implies keeping exclusions.
                        // Let's keep exclusions in the card for a unified "Sentence" flow if possible, or a separate section in the card.
                        
                        if formState.showExclusionConditions || !formState.exclusionConditions.isEmpty {
                            Divider().padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Except when")
                                        .font(.formaBodyLarge)
                                        .foregroundColor(.formaSecondaryLabel)
                                    
                                    Spacer()
                                    
                                    // If we want a toggle to turn it off completely? 
                                    // Existing UI used a toggle "Add exceptions". Let's keep that pattern but maybe subtle.
                                    Button(action: { 
                                        withAnimation { formState.showExclusionConditions.toggle() }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.formaSecondaryLabel)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                exclusionConditionsView
                            }
                        } else {
                            // Subtle button to add exception
                             Button(action: { 
                                withAnimation { formState.showExclusionConditions = true }
                            }) {
                                Text("+ Add Exception")
                                    .font(.formaSmall)
                                    .foregroundColor(.formaSteelBlue)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.vertical, 4)

                        // Action Section (Then...)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Then")
                                .font(.formaBodyLarge)
                                .foregroundColor(.formaSecondaryLabel)
                            
                            // Action Picker (Inline)
                            Menu {
                                ForEach(Rule.ActionType.allCases, id: \.self) { type in
                                    Button(type.rawValue.capitalized) { formState.actionType = type }
                                }
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

                        // Destination selection
                        if formState.actionType == .delete {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.formaError)
                                Text("Trash")
                                    .fontWeight(.medium)
                                    .foregroundColor(.formaError)
                            }
                            .padding(.vertical, 4)
                            
                            // Preview delete matches button
                             Button {
                                previewDeleteRuleMatches()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye")
                                    Text("Preview matches")
                                }
                                .font(.formaSmall)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button(action: { showFolderPicker = true }) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.formaSteelBlue)
                                    Text(formState.destinationDisplayPath.isEmpty ? "Select folder..." : formState.destinationDisplayPath)
                                        .fontWeight(.medium)
                                        .foregroundColor(formState.destinationDisplayPath.isEmpty ? .formaSecondaryLabel : .formaObsidian)
                                    
                                    if formState.destinationBookmarkData != nil {
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

                    // Destination warning for unresolvable placeholders
                    if let resolvability = destinationResolvability,
                       case .unresolvable(let reason) = resolvability {
                        HStack(alignment: .top, spacing: FormaSpacing.tight) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Destination may not work")
                                    .font(.formaCaption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.formaObsidian)

                                Text(reason)
                                    .font(.formaCaption)
                                    .foregroundColor(.formaSecondaryLabel)
                                    .fixedSize(horizontal: false, vertical: true)
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
	        .accessibilityIdentifier("ruleEditorView")
	        .onAppear {
            // Initialize form state from editing context
            if let rule = editingRule {
                formState = RuleFormState(from: rule)
            } else if let file = fileContext {
                formState = RuleFormState(from: file)
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

    private var singleConditionView: some View {
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
            .id(conditionTypeChangeId) // Keep the ID trigger if needed
            
            Text("is")
                .font(.formaBodyLarge)
                .foregroundColor(.formaSecondaryLabel)
            
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
                .frame(maxWidth: .infinity)
        }
    }
    
    private var compoundConditionsView: some View {
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

            // Conditions list
            VStack(spacing: 8) {
                ForEach(Array(formState.conditions.enumerated()), id: \.offset) { index, condition in
                    conditionRow(at: index)
                }
            }
            
            // Add condition button
            Button(action: {
                withAnimation(reduceMotion ? .linear(duration: 0.12) : FormaAnimation.interactiveSpring) {
                    addCondition()
                }
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
    }

    private var exclusionConditionsView: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Skip files matching ANY of these:")
                .formaMetadataStyle()
                .foregroundColor(Color.formaSecondaryLabel)

            // Exclusion conditions list
            VStack(spacing: FormaSpacing.tight) {
                ForEach(Array(formState.exclusionConditions.enumerated()), id: \.offset) { index, condition in
                    exclusionConditionRow(at: index)
                }
            }

            // Add exclusion condition button
            Button(action: {
                withAnimation(reduceMotion ? .linear(duration: 0.12) : FormaAnimation.interactiveSpring) {
                    addExclusionCondition()
                }
            }) {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Exception")
                }
                .formaMetadataStyle()
                .foregroundColor(Color.formaWarmOrange)
            }
            .buttonStyle(.plain)
            .hoverLift(scale: 1.02, shadowRadius: 4)
	        }
	        .padding(FormaSpacing.standard)
	        .background(Color.formaWarmOrange.opacity(Color.FormaOpacity.subtle))
	        .cornerRadius(FormaRadius.card)
	    }

    private func exclusionConditionRow(at index: Int) -> some View {
        HStack(spacing: FormaSpacing.tight) {
            // Exclusion marker
            Image(systemName: "xmark.circle.fill")
                .font(.formaCompact)
                .foregroundColor(Color.formaWarmOrange.opacity(Color.FormaOpacity.high))
                .frame(width: 20)

            // Condition type selector (Menu)
            Menu {
                ForEach(Rule.ConditionType.allCases, id: \.self) { type in
                    Button(conditionDisplayName(for: type)) {
                        updateExclusionConditionType(at: index, to: type)
                    }
                }
            } label: {
                Text(conditionDisplayName(for: index < formState.exclusionConditions.count ? formState.exclusionConditions[index].type : .nameContains))
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
                    .fixedSize()
            }
            .menuStyle(.borderlessButton)

            // Condition value
            TextField(conditionPlaceholder(for: index < formState.exclusionConditions.count ? formState.exclusionConditions[index].type : .nameContains), text: Binding(
                get: { index < formState.exclusionConditions.count ? formState.exclusionConditions[index].value : "" },
                set: { newValue in
                    updateExclusionConditionValue(at: index, to: newValue)
                }
            ))
            .textFieldStyle(.plain)
            .padding(FormaSpacing.tight)
            .background(Color.formaControlBackground)
            .cornerRadius(FormaRadius.control)
            .frame(maxWidth: .infinity)
            .foregroundColor(Color.formaLabel)

            // Remove button
            Button(action: {
                withAnimation(reduceMotion ? .linear(duration: 0.12) : FormaAnimation.quickExit) {
                    removeExclusionCondition(at: index)
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(Color.formaError.opacity(Color.FormaOpacity.high))
            }
            .buttonStyle(.plain)
            .hoverLift(scale: 1.1, shadowRadius: 2)
        }
    }

    private func conditionRow(at index: Int) -> some View {
        ConditionRowContainer(isVisible: true) {
            HStack(spacing: FormaSpacing.tight) {
                // Condition type selector (Menu)
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
                .padding(FormaSpacing.tight)
                .background(Color.formaControlBackground)
                .cornerRadius(FormaRadius.control)
                
                Spacer()
                
                // Remove button
                if formState.conditions.count > 1 {
                    Button(action: {
                        withAnimation(reduceMotion ? .linear(duration: 0.12) : FormaAnimation.quickExit) {
                            removeCondition(at: index)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.formaSecondaryLabel)
                            .font(.formaSmall)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(FormaSpacing.standard)
            .background(Color.formaCardBackground)
            .cornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
            )
        }
    }

    // MARK: - Condition Helper Methods
    
    private func updateConditionType(at index: Int, to type: Rule.ConditionType) {
        guard index < formState.conditions.count else { return }
        do {
            let newCondition = try RuleCondition(type: type, value: formState.conditions[index].value)
            formState.conditions[index] = newCondition
        } catch {
            print("Failed to update condition type: \(error)")
        }
    }

    private func updateConditionValue(at index: Int, to value: String) {
        guard index < formState.conditions.count else { return }
        do {
            let newCondition = try RuleCondition(type: formState.conditions[index].type, value: value)
            formState.conditions[index] = newCondition
        } catch {
            print("Failed to update condition value: \(error)")
        }
    }

    private func updateExclusionConditionType(at index: Int, to type: Rule.ConditionType) {
        guard index < formState.exclusionConditions.count else { return }
        do {
            let newCondition = try RuleCondition(type: type, value: formState.exclusionConditions[index].value)
            formState.exclusionConditions[index] = newCondition
        } catch {
            print("Failed to update exclusion condition type: \(error)")
        }
    }

    private func updateExclusionConditionValue(at index: Int, to value: String) {
        guard index < formState.exclusionConditions.count else { return }
        do {
            let newCondition = try RuleCondition(type: formState.exclusionConditions[index].type, value: value)
            formState.exclusionConditions[index] = newCondition
        } catch {
             print("Failed to update exclusion condition value: \(error)")
        }
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

    private func addCondition() {
        // Add a new empty condition with a default type
        do {
            let newCondition = try RuleCondition(type: .fileExtension, value: "pdf")
            formState.conditions.append(newCondition)
        } catch {
            Log.warning("RuleEditorView: Failed to add new condition - \(error.localizedDescription)", category: .general)
        }
    }

    private func removeCondition(at index: Int) {
        formState.conditions.remove(at: index)
    }

    private func addExclusionCondition() {
        // Add a new exclusion condition with default values
        do {
            let newCondition = try RuleCondition(type: .nameContains, value: "temp")
            formState.exclusionConditions.append(newCondition)
        } catch {
            Log.warning("RuleEditorView: Failed to add new exclusion condition - \(error.localizedDescription)", category: .general)
        }
    }

    private func removeExclusionCondition(at index: Int) {
        formState.exclusionConditions.remove(at: index)
        // If no exclusion conditions left, hide the section
        if formState.exclusionConditions.isEmpty {
            formState.showExclusionConditions = false
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

    private func conditionDisplayName(for type: Rule.ConditionType) -> String {
        switch type {
        case .fileExtension: return "File extension is"
        case .nameContains: return "Name contains"
        case .nameStartsWith: return "Name starts with"
        case .nameEndsWith: return "Name ends with"
        case .dateOlderThan: return "Date older than (days)"
        case .sizeLargerThan: return "Size larger than"
        case .dateModifiedOlderThan: return "Modified older than (days)"
        case .dateAccessedOlderThan: return "Not opened in (days)"
        case .fileKind: return "File kind is"
        case .sourceLocation: return "Source location is"
        }
    }

    private var conditionPlaceholder: String {
        conditionPlaceholder(for: formState.conditionType)
    }
    
    private func conditionPlaceholder(for type: Rule.ConditionType) -> String {
        switch type {
        case .fileExtension: return "pdf"
        case .nameContains: return "Invoice"
        case .nameStartsWith: return "Screenshot"
        case .nameEndsWith: return "_final"
        case .dateOlderThan: return "7"
        case .sizeLargerThan: return "100MB"
        case .dateModifiedOlderThan: return "30"
        case .dateAccessedOlderThan: return "90"
        case .fileKind: return "image"
        case .sourceLocation: return "desktop"
        }
    }

    private var conditionHint: String {
        switch formState.conditionType {
        case .fileExtension: return "Just the extension (no dot)"
        case .nameContains: return "Case insensitive matching"
        case .nameStartsWith: return "Case insensitive matching"
        case .nameEndsWith: return "Case insensitive matching"
        case .dateOlderThan: return "Number of days, or extension:days (e.g. dmg:7)"
        case .sizeLargerThan: return "e.g., 100MB, 1.5GB, 500KB"
        case .dateModifiedOlderThan: return "Number of days since last modification"
        case .dateAccessedOlderThan: return "Number of days since last opened"
        case .fileKind: return "Options: image, audio, video, document, spreadsheet, presentation, archive, code"
        case .sourceLocation: return "Options: desktop, downloads, documents, pictures, music, home"
        }
    }

    private func validateRule() -> Bool {
        // Extra safety for delete rules created from natural language
        if editingRule == nil,
           formState.actionType == .delete,
           !naturalLanguageViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let parsed = naturalLanguageViewModel.parsedRule {

            if parsed.overallConfidence < 0.75 || parsed.isAmbiguous {
                validationError = "This delete rule is based on an uncertain natural-language description. Please refine it or adjust the fields manually before saving."
                triggerValidationShake.toggle()
                return false
            }
        }

        if formState.name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Rule name is required"
            triggerValidationShake.toggle()
            return false
        }

        if formState.useCompoundConditions {
            // Validate compound conditions
            if formState.conditions.isEmpty {
                validationError = "At least one condition is required"
                return false
            }

            for (index, condition) in formState.conditions.enumerated() {
                if condition.value.trimmingCharacters(in: .whitespaces).isEmpty {
                    validationError = "Condition \(index + 1) value is required"
                    triggerValidationShake.toggle()
                    return false
                }

                if condition.type == .fileExtension && condition.value.hasPrefix(".") {
                    validationError = "Condition \(index + 1): File extension should not include the dot"
                    return false
                }
            }
        } else {
            // Validate single condition
            if formState.conditionValue.trimmingCharacters(in: .whitespaces).isEmpty {
                validationError = "Condition value is required"
                return false
            }

            if formState.conditionType == .fileExtension && formState.conditionValue.hasPrefix(".") {
                validationError = "File extension should not include the dot"
                return false
            }
        }

        if formState.actionType == .move || formState.actionType == .copy {
            // Must have a bookmark-backed destination for sandboxed operations
            if formState.destinationBookmarkData == nil {
                validationError = "Please select a destination folder using the folder picker"
                return false
            }
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
