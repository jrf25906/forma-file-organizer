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
    @Environment(\.rightPanelLayout) private var rightPanelLayout
    private let isUITesting = CommandLine.arguments.contains("--uitesting")

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
        Color.formaSurfaceWork
    }

    private var ruleCardBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.10)
    }

    private var ruleCardShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.16)
            : Color.formaObsidian.opacity(0.055)
    }

    private var chromeSurfaceBackground: Color {
        Color.formaSurfaceAnchor
    }

    private var chromeSurfaceBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.12)
    }

    private var floatingSurfaceBackground: Color {
        Color.formaSurfaceFloating
    }

    private var floatingSurfaceBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.20)
            : Color.formaObsidian.opacity(0.12)
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

    private var rightPanelWidthClassText: String {
        rightPanelLayout.isCompact ? "compact" : "regular"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed header with context-aware labels
            headerChrome
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, FormaSpacing.standard)
            .background(chromeSurfaceBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(chromeSurfaceBorder),
                alignment: .bottom
            )
            .allowsHitTesting(true)
            .zIndex(999)

            // Scrollable content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                        ruleNameField

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
                    .padding(.vertical, FormaSpacing.generous)
                }
                .background(Color.formaSurfaceChrome)
            }

            persistentActionBar
        }
        .background(Color.formaSurfaceChrome)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inlineRuleBuilderView")
        .accessibilityLabel(isUITesting ? "widthClass=\(rightPanelWidthClassText)" : "")
        .accessibilityValue(isUITesting ? "widthClass=\(rightPanelWidthClassText)" : "")
        .overlay(alignment: .topLeading) {
            if isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("inlineRuleBuilderLayoutProbe")
                    .accessibilityLabel("widthClass=\(rightPanelWidthClassText)")
                    .accessibilityValue("widthClass=\(rightPanelWidthClassText)")
            }
        }
        .onAppear {
            hydrateDraftState()
            updatePreview()
        }
        .onChange(of: formState) { _, newValue in
            nav.updateRuleDraftFormState(newValue)
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

    @ViewBuilder
    private var headerChrome: some View {
        if rightPanelLayout.isCompact {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                headerTitleStack

                HStack(spacing: FormaSpacing.standard) {
                    headerIconButton(
                        systemImage: "arrow.up.left.and.arrow.down.right",
                        accessibilityIdentifier: "expandRuleEditorButton",
                        helpText: "Expand to Full Editor",
                        action: expandToModal
                    )

                    headerIconButton(
                        systemImage: "xmark.circle.fill",
                        accessibilityIdentifier: "closeRuleBuilderButton",
                        helpText: nil,
                        action: discardDraft
                    )
                }
            }
        } else {
            HStack {
                headerTitleStack

                Spacer()

                headerIconButton(
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    accessibilityIdentifier: "expandRuleEditorButton",
                    helpText: "Expand to Full Editor",
                    action: expandToModal
                )

                headerIconButton(
                    systemImage: "xmark.circle.fill",
                    accessibilityIdentifier: "closeRuleBuilderButton",
                    helpText: nil,
                    action: discardDraft
                )
            }
        }
    }

    private var headerTitleStack: some View {
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: headerConfig.icon)
                .foregroundColor(fileContext != nil ? .formaSage : .formaSteelBlue)
                .font(.formaBodySemibold)

            VStack(alignment: .leading, spacing: 1) {
                Text(headerConfig.title)
                    .font(.formaBodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.formaLabel)

                if let subtitle = headerConfig.subtitle {
                    Text(subtitle)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabelHigh)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerIconButton(
        systemImage: String,
        accessibilityIdentifier: String,
        helpText: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundColor(.formaSecondaryLabelHigh)
                .font(systemImage == "xmark.circle.fill" ? .formaH3 : .formaBodyLarge)
                .frame(width: 40, height: 40)
                .contentShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(accessibilityIdentifier)
        .help(helpText ?? "")
        .allowsHitTesting(true)
    }

    private var persistentActionBar: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            if rightPanelLayout.isCompact {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    impactToneRow

                    if matchedFilesCount > 0 {
                        matchBadge
                    }
                }
            } else {
                HStack(alignment: .top, spacing: FormaSpacing.tight) {
                    impactToneRow
                    Spacer()

                    if matchedFilesCount > 0 {
                        matchBadge
                    }
                }
            }

            Group {
                if rightPanelLayout.isCompact {
                    VStack(spacing: FormaSpacing.standard) {
                        discardRuleButton
                        saveRuleButton
                    }
                } else {
                    HStack(spacing: FormaSpacing.standard) {
                        discardRuleButton
                        saveRuleButton
                    }
                }
            }
        }
        .padding(.horizontal, FormaSpacing.generous)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(floatingSurfaceBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(floatingSurfaceBorder),
            alignment: .top
        )
        .formaShadow(.floating)
        .allowsHitTesting(true)
        .zIndex(998)
    }

    private var impactToneRow: some View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var matchBadge: some View {
        FormaBadge(
            text: "\(matchedFilesCount) match\(matchedFilesCount == 1 ? "" : "es")",
            color: impactTone.color,
            size: .small,
            style: .subtle
        )
    }

    private var discardRuleButton: some View {
        SecondaryButton(editingRule == nil ? "Discard Draft" : "Cancel") {
            discardDraft()
        }
        .accessibilityIdentifier("ruleComposerDiscardButton")
    }

    private var saveRuleButton: some View {
        Button(action: {
            if formState.actionType == .delete && matchedFilesCount > 0 {
                showDeleteConfirmation = true
            } else {
                saveRule()
            }
        }) {
            Text(editingRule == nil ? "Save Rule" : "Save Changes")
                .font(.formaBodyBold)
                .foregroundColor(.formaBoneWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .frame(minHeight: 40)
                .background(Color.formaSteelBlue)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmitRule)
        .opacity(canSubmitRule ? 1 : 0.6)
        .accessibilityIdentifier("ruleComposerSaveButton")
    }

    private var ruleNameField: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(spacing: FormaSpacing.tight) {
                FormaBadge(text: "RULE", color: .formaSteelBlue, size: .small, style: .subtle)
                Text("Rule name")
                    .font(.formaSmallSemibold)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }

            TextField("Name your rule...", text: $formState.name)
                .font(.formaH3)
                .textFieldStyle(.plain)
                .accessibilityLabel("Rule Name")
                .accessibilityIdentifier("inlineRuleNameField")
                .accessibilityValue(formState.name)
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.vertical, FormaSpacing.tight)
                .frame(minHeight: 48)
                .background(floatingSurfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .strokeBorder(
                            trimmedRuleName.isEmpty ? Color.formaSeparator.opacity(colorScheme == .dark ? 0.45 : 0.36) : Color.formaSteelBlue.opacity(0.38),
                            lineWidth: FormaBorderWidth.thin
                        )
                )
        }
        .padding(FormaSpacing.standard)
        .background(ruleCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(ruleCardBorder, lineWidth: FormaBorderWidth.thin)
        )
        .shadow(color: ruleCardShadow, radius: 3, x: 0, y: 1)
        .id("name-section")
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
    private func ruleSectionHeader(step: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: FormaSpacing.tight) {
            FormaBadge(text: step, color: tint, size: .small, style: .subtle)

            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text(title)
                    .font(.formaBodyBold)
                    .foregroundColor(.formaLabel)
                Text(subtitle)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro + 2)
            .background(Color.formaWarmOrange.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .strokeBorder(Color.formaWarmOrange.opacity(0.24), lineWidth: FormaBorderWidth.thin)
            )
        }
    }

    private func builderSectionCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(FormaSpacing.large)
            .background(ruleCardBackground)
            .cornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(ruleCardBorder, lineWidth: FormaBorderWidth.thin)
            )
            .shadow(color: ruleCardShadow, radius: 3, x: 0, y: 1)
    }

    private var whenSectionCard: some View {
        builderSectionCard {
            VStack(alignment: .leading, spacing: 18) {
                ruleSectionHeader(
                    step: "1",
                    title: "When",
                    subtitle: "Choose which files this rule should target.",
                    tint: .formaSteelBlue
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

                        VStack(spacing: FormaSpacing.tight) {
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
                        .padding(FormaSpacing.tight)
                        .background(floatingSurfaceBackground)
                        .cornerRadius(FormaRadius.control)
                        .overlay(
                            RoundedRectangle(cornerRadius: FormaRadius.control)
                                .stroke(whenValidationMessage == nil ? Color.formaSeparator : Color.formaWarmOrange, lineWidth: FormaBorderWidth.thin)
                        )
                        .onChange(of: formState.conditionValue) { _, _ in
                            updatePreview()
                        }
                }

                sectionValidationMessage(whenValidationMessage)
            }
        }
        .overlay(alignment: .topLeading) {
            if isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("ruleComposerWhenSection")
            }
        }
    }

    private var thenSectionCard: some View {
        builderSectionCard {
            VStack(alignment: .leading, spacing: 18) {
                ruleSectionHeader(
                    step: "2",
                    title: "Then",
                    subtitle: "Define what happens to matched files.",
                    tint: actionTypeBadgeColor
                )

                Group {
                    if rightPanelLayout.isCompact {
                        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                            Text("Then")
                                .font(.formaBodyLarge)
                                .foregroundColor(.formaSecondaryLabelHigh)

                            HStack(alignment: .firstTextBaseline, spacing: 6) {
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
                        }
                    } else {
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
                    }
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
                        .background(floatingSurfaceBackground)
                        .cornerRadius(FormaRadius.control)
                        .overlay(
                            RoundedRectangle(cornerRadius: FormaRadius.control)
                                .stroke(
                                    thenValidationMessage == nil ? Color.formaSeparator : Color.formaWarmOrange,
                                    lineWidth: FormaBorderWidth.thin
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
        .overlay(alignment: .topLeading) {
            if isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("ruleComposerThenSection")
            }
        }
    }

    private var categorySelectionCard: some View {
        builderSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                ruleSectionHeader(
                    step: "3",
                    title: "Category",
                    subtitle: "Group this rule with related organization behavior.",
                    tint: .formaSage
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FormaSpacing.tight) {
                        ForEach(sortedCategories) { category in
                            Button(action: { formState.categoryID = category.id }) {
                                HStack(spacing: FormaSpacing.micro) {
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
                                        : floatingSurfaceBackground
                                )
                                .foregroundColor(formState.categoryID == category.id ? category.color : .formaSecondaryLabelHigh)
                                .cornerRadius(FormaRadius.card)
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
        Group {
            if rightPanelLayout.isCompact {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    conditionTypeMenu(for: index)

                    HStack(spacing: FormaSpacing.tight) {
                        conditionValueField(for: index)
                        removeConditionButton(at: index)
                    }
                }
            } else {
                HStack(spacing: FormaSpacing.tight) {
                    conditionTypeMenu(for: index)
                    conditionValueField(for: index)
                    Spacer()
                    removeConditionButton(at: index)
                }
            }
        }
        .padding(FormaSpacing.standard)
        .background(floatingSurfaceBackground)
        .cornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(colorScheme == .dark ? 0.55 : Color.FormaOpacity.strong), lineWidth: FormaBorderWidth.thin)
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

    private func conditionTypeMenu(for index: Int) -> some View {
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
        }
        .menuStyle(.borderlessButton)
    }

    private func conditionValueField(for index: Int) -> some View {
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
    }

    private func removeConditionButton(at index: Int) -> some View {
        Button(action: { removeCondition(at: index) }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.formaSecondaryLabelHigh)
                .font(.formaSmall)
        }
        .buttonStyle(.plain)
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
                Group {
                    if rightPanelLayout.isCompact {
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            impactPreviewCopy

                            HStack(spacing: FormaSpacing.tight) {
                                impactMatchBadge
                                impactActionBadge
                            }
                        }
                    } else {
                        HStack(alignment: .top, spacing: FormaSpacing.standard) {
                            impactPreviewCopy

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                impactMatchBadge
                                impactActionBadge
                            }
                        }
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
        .overlay(alignment: .topLeading) {
            if isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("ruleComposerImpactSection")
            }
        }
    }

    private var impactPreviewCopy: some View {
        HStack(alignment: .top, spacing: FormaSpacing.tight) {
            FormaBadge(text: "REVIEW", color: impactTone.color, size: .small, style: .subtle)

            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            HStack(spacing: 6) {
                Image(systemName: impactTone.icon)
                    .foregroundColor(impactTone.color)
                Text("Impact")
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
            }

            Text(impactTone.title)
                .font(.formaBodyBold)
                .foregroundColor(.formaLabel)

            Text(impactTone.message)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabelHigh)
            }
        }
    }

    private var impactMatchBadge: some View {
        FormaBadge(
            text: "\(matchedFilesCount) match\(matchedFilesCount == 1 ? "" : "es")",
            color: impactTone.color,
            size: .small,
            style: .subtle
        )
    }

    private var impactActionBadge: some View {
        FormaBadge(
            text: formState.actionType == .delete ? "Trash" : formState.actionType.rawValue.capitalized,
            color: actionTypeBadgeColor,
            size: .small,
            style: .subtle
        )
    }
    
    // MARK: - Helpers

    /// Expands the panel rule builder to the full modal editor
    private func expandToModal() {
        if nav.ruleDraftSession == nil {
            nav.beginRuleDraft(
                editingRule: editingRule,
                fileContext: fileContext,
                presentation: .panel,
                returnTarget: draftReturnTarget
            )
        }

        nav.updateRuleDraftFormState(formState)

        // Close the panel first
        dashboardViewModel.returnToDefaultPanel()

        // Open the modal with a slight delay for smooth transition
        withAnimation(.easeInOut(duration: FormaEasing.Duration.fast)) {
            nav.presentRuleDraftModal()
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
    
    private var draftReturnTarget: RuleDraftReturnTarget {
        if let fileContext {
            return .inspector(filePath: fileContext.path)
        }
        return .defaultPanel
    }

    private func discardDraft() {
        let returnTarget = nav.ruleDraftSession?.returnTarget ?? draftReturnTarget
        nav.discardRuleDraft()
        dashboardViewModel.restorePanel(afterRuleDraftReturnTarget: returnTarget)
    }

    private func hydrateDraftState() {
        if let draftSession = nav.ruleDraftSession {
            formState = draftSession.formState
        } else if let rule = editingRule {
            formState = RuleFormState(from: rule)
        } else if let file = fileContext {
            formState = RuleFormState(from: file)
        }

        // Auto-select default category if none is selected yet
        if formState.categoryID == nil, let defaultCategory = sortedCategories.first(where: { $0.isDefault }) {
            formState.categoryID = defaultCategory.id
        }

        nav.updateRuleDraftFormState(formState)
    }
    
    private func updatePreview() {
        // Cancel any pending preview computation
        previewTask?.cancel()

        guard hasValidConditionInput else {
            withAnimation(.easeInOut(duration: FormaEasing.Duration.micro)) {
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
            withAnimation(.easeInOut(duration: FormaEasing.Duration.fast)) {
                previewFiles = Array(files.prefix(3))
                matchedFilesCount = files.count
                isLoadingPreview = false
            }
        }
    }
    
    private func getMatchedFiles() -> [FileItem] {
        let previewConditions = formState.conditions
        let previewConditionType = previewConditions.first?.type ?? formState.conditionType
        let previewConditionValue = previewConditions.first?.value ?? formState.conditionValue
        let previewLogicalOperator: Rule.LogicalOperator = previewConditions.isEmpty
            ? .single
            : formState.logicalOperator

        guard !previewConditionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !previewConditions.isEmpty else {
            return []
        }

        return dashboardViewModel.matchingFilesForRulePreview(
            conditions: previewConditions,
            conditionType: previewConditionType,
            conditionValue: previewConditionValue,
            logicalOperator: previewLogicalOperator,
            actionType: formState.actionType,
            destination: formState.buildDestination()
        )
    }

    // MARK: - Natural Language Integration

    /// Called live as the user types in the NL input bar.
    /// Auto-populates the form fields below without any tab switching.
    private func applyParsedRuleLive(_ parsed: NLParsedRule?) {
        guard let parsed = parsed, !parsed.hasBlockingError else { return }

        // Map action (animate the change for visual feedback)
        withAnimation(.easeInOut(duration: FormaEasing.Duration.fast)) {
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
        let returnTarget = nav.ruleDraftSession?.returnTarget ?? draftReturnTarget

        do {
            try dashboardViewModel.saveRuleDraft(
                rule,
                editingRule: editingRule,
                source: .inlineBuilder,
                context: modelContext
            )
            nav.clearRuleDraft()
            dashboardViewModel.showRuleWorkflowCelebration(
                message: editingRule == nil ? "Rule created!" : "Rule updated!",
                returnTarget: returnTarget
            )

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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.tight) {
                FormaBadge(text: "DRAFT", color: .formaSteelBlue, icon: "sparkles", size: .small, style: .subtle)
                Text("Describe the automation")
                    .font(.formaSmallSemibold)
                    .foregroundColor(.formaSecondaryLabelHigh)

                Spacer()

                if viewModel.isParsing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 18, height: 18)
                }
            }

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

            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)
            .frame(minHeight: 44)
            .background(Color.formaSurfaceFloating)
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .strokeBorder(
                        viewModel.text.isEmpty
                            ? Color.formaSeparator.opacity(colorScheme == .dark ? 0.46 : 0.34)
                            : Color.formaSteelBlue.opacity(0.42),
                        lineWidth: FormaBorderWidth.thin
                    )
            )

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
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .italic()
            }
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaSurfaceWork)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.46 : 0.30), lineWidth: FormaBorderWidth.thin)
        )
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
