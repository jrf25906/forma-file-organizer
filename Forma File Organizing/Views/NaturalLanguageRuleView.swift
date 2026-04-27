import SwiftUI

/// Natural-language rule input zone embedded in the rule editor.
/// Provides a text field, HUD tokens, and a parsed rule preview card.
struct NaturalLanguageRuleView: View {
    @ObservedObject var viewModel: NaturalLanguageRuleViewModel
    var onApplyToEditor: (NLParsedRule) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var showTimeAmbiguitySheet = false
    @State private var showGroupingAmbiguitySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.tight) {
                FormaBadge(text: "DRAFT", color: .formaSteelBlue, icon: "sparkles", size: .small, style: .subtle)
                Text("Describe what you want to automate")
                    .font(.formaSmallSemibold)
                    .foregroundColor(Color.formaSecondaryLabelHigh)
            }

            // Input field
            TextField(
                "e.g., Move PDFs older than 30 days to Archive",
                text: $viewModel.text,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .padding(FormaSpacing.tight + (FormaSpacing.micro / 2))
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
            .foregroundColor(Color.formaLabel)
            .onSubmit {
                viewModel.parseImmediately()
            }
            .onChange(of: viewModel.text) { _, newValue in
                viewModel.onTextChanged(newValue)
            }

            // HUD tokens
            if let parsed = viewModel.parsedRule, !hudTokens(for: parsed).isEmpty {
                HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                    ForEach(hudTokens(for: parsed), id: \.self) { token in
                        Text(token)
                            .font(.formaCaption)
                            .foregroundColor(.formaSteelBlue)
                            .padding(.horizontal, FormaSpacing.tight)
                            .padding(.vertical, FormaSpacing.micro - (FormaSpacing.micro / 4))
                            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                            .clipShape(Capsule())
                    }

                    if viewModel.isParsing {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: viewModel.parsedRule?.overallConfidence)
            }

            // Inline message
            if let message = viewModel.inlineMessage {
                Text(message)
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }

            // Ambiguity resolution prompts
            if let parsed = viewModel.parsedRule {
                if hasAmbiguousTime(in: parsed) {
                    Button {
                        showTimeAmbiguitySheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.questionmark")
                                .font(.formaCaption)
                            Text("Clarify time range…")
                                .font(.formaCaption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 40)
                }

                if hasAmbiguousGrouping(in: parsed) {
                    Button {
                        showGroupingAmbiguitySheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.formaCaption)
                            Text("Clarify how to organize by month…")
                                .font(.formaCaption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 40)
                }
            }

            // Preview card
            if viewModel.shouldShowPreview, let parsed = viewModel.parsedRule {
                RulePreviewCard(parsedRule: parsed) { applied in
                    onApplyToEditor(applied)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: parsed.overallConfidence)
            }
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaSurfaceWork)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.46 : 0.30), lineWidth: FormaBorderWidth.thin)
        )
        .sheet(isPresented: $showTimeAmbiguitySheet) {
            TimeAmbiguityResolutionSheet { customDays in
                resolveTimeAmbiguity(customDays: customDays)
            }
        }
        .sheet(isPresented: $showGroupingAmbiguitySheet) {
            GroupingAmbiguityResolutionSheet { resolution in
                resolveGroupingAmbiguity(resolution)
            }
        }
    }

    private func hudTokens(for parsed: NLParsedRule) -> [String] {
        var tokens: [String] = []

        // Action
        if let action = parsed.primaryAction {
            let label: String
            switch action {
            case .move: label = "move"
            case .copy: label = "copy"
            case .delete: label = "delete"
            }
            tokens.append(label)
        }

        // File type / kind (first few only)
        if let fileToken = parsed.candidateConditions.compactMap(fileTokenForCondition).first {
            tokens.append(fileToken)
        }

        // Time constraint
        if let t = parsed.timeConstraints.first {
            switch t {
            case .olderThan(let days):
                tokens.append("older than \(days) days")
            }
        }

        // Destination
        if let dest = parsed.destinationPath, !dest.isEmpty {
            tokens.append("→ \(dest)")
        }

        return tokens
    }

    private func fileTokenForCondition(_ condition: RuleCondition) -> String? {
        switch condition {
        case .fileExtension(let ext):
            return ext.lowercased()
        case .fileKind(let kind):
            return kind.lowercased()
        default:
            return nil
        }
    }

    private func hasAmbiguousTime(in parsed: NLParsedRule) -> Bool {
        parsed.clauses.contains { $0.ambiguityTags.contains(.ambiguousTimePhrase) }
    }

    private func hasAmbiguousGrouping(in parsed: NLParsedRule) -> Bool {
        parsed.clauses.contains { $0.ambiguityTags.contains(.ambiguousGrouping) }
    }

    private func resolveTimeAmbiguity(customDays: Int?) {
        guard let parsed = viewModel.parsedRule else { return }

        let resolvedDays = customDays

        let updatedTimeConstraints: [NLTimeConstraint] = parsed.timeConstraints.map { constraint in
            switch constraint {
            case .olderThan(let days):
                if let resolvedDays {
                    return .olderThan(days: resolvedDays)
                } else {
                    return .olderThan(days: days)
                }
            }
        }

        let updatedConditions: [RuleCondition] = parsed.candidateConditions.map { condition in
            switch condition {
            case .dateOlderThan(let days, let ext):
                if let resolvedDays {
                    return .dateOlderThan(days: resolvedDays, extension: ext)
                } else {
                    return .dateOlderThan(days: days, extension: ext)
                }
            default:
                return condition
            }
        }

        let updatedClauses: [NLParsedClause] = parsed.clauses.map { clause in
            if clause.ambiguityTags.contains(.ambiguousTimePhrase) {
                let newTags = clause.ambiguityTags.filter { $0 != .ambiguousTimePhrase }
                return NLParsedClause(
                    kind: clause.kind,
                    rawText: clause.rawText,
                    normalizedValue: clause.normalizedValue,
                    confidence: clause.confidence,
                    ambiguityTags: newTags
                )
            }
            return clause
        }

        viewModel.parsedRule = NLParsedRule(
            originalText: parsed.originalText,
            clauses: updatedClauses,
            timeConstraints: updatedTimeConstraints,
            candidateConditions: updatedConditions,
            primaryAction: parsed.primaryAction,
            destinationPath: parsed.destinationPath,
            logicalOperator: parsed.logicalOperator,
            overallConfidence: parsed.overallConfidence,
            issues: parsed.issues,
            groupingHint: parsed.groupingHint,
            groupingResolution: parsed.groupingResolution
        )
    }

    private func resolveGroupingAmbiguity(_ resolution: NLGroupingResolution) {
        guard let parsed = viewModel.parsedRule else { return }

        let updatedClauses: [NLParsedClause] = parsed.clauses.map { clause in
            if clause.ambiguityTags.contains(.ambiguousGrouping) {
                let newTags = clause.ambiguityTags.filter { $0 != .ambiguousGrouping }
                return NLParsedClause(
                    kind: clause.kind,
                    rawText: clause.rawText,
                    normalizedValue: clause.normalizedValue,
                    confidence: clause.confidence,
                    ambiguityTags: newTags
                )
            }
            return clause
        }

        viewModel.parsedRule = NLParsedRule(
            originalText: parsed.originalText,
            clauses: updatedClauses,
            timeConstraints: parsed.timeConstraints,
            candidateConditions: parsed.candidateConditions,
            primaryAction: parsed.primaryAction,
            destinationPath: parsed.destinationPath,
            logicalOperator: parsed.logicalOperator,
            overallConfidence: parsed.overallConfidence,
            issues: parsed.issues,
            groupingHint: parsed.groupingHint,
            groupingResolution: resolution
        )
    }
}

/// Sheet used to resolve ambiguous time phrases like "last week" or "last month".
/// The user can keep Forma's defaults or override the number of days.
private struct TimeAmbiguityResolutionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var customDaysString: String = ""
    let onResolve: (Int?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Clarify time range")
                .font(.formaH3)
                .foregroundColor(.formaLabel)

            Text("Phrases like ‘last week’ or ‘last month’ have been interpreted as a number of days. You can keep the defaults or choose an exact number of days.")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text("Custom days (optional)")
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaSecondaryLabel)

                TextField("e.g., 7", text: $customDaysString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            HStack(spacing: FormaSpacing.standard) {
                Button("Keep defaults") {
                    onResolve(nil)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 40)

                Button("Apply custom days") {
                    if let days = Int(customDaysString), days > 0 {
                        onResolve(days)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 40)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .frame(minHeight: 40)
            }
            .padding(.top, FormaSpacing.standard)
        }
        .padding(FormaSpacing.large)
        .frame(minWidth: 380, idealWidth: 420, maxWidth: 520)
        .background(Color.formaBackground)
    }
}

/// Sheet used to resolve grouping phrases like "organize by month".
/// Lets the user decide whether Forma should group by creation month,
/// modification month, or leave grouping manual.
private struct GroupingAmbiguityResolutionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: NLGroupingResolution = .byCreationMonth
    let onResolve: (NLGroupingResolution) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Clarify “by month”")
                .font(.formaH3)
                .foregroundColor(.formaLabel)

            Text("“By month” can mean using the file’s creation month, its last modification month, or leaving grouping manual. Choose how you’d like Forma to interpret this.")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)

            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                groupingOptionRow(
                    title: "Use creation month",
                    subtitle: "Files are organized based on when they were originally created.",
                    value: .byCreationMonth
                )

                groupingOptionRow(
                    title: "Use modification month",
                    subtitle: "Files are organized based on when they were last edited.",
                    value: .byModificationMonth
                )

                groupingOptionRow(
                    title: "Keep grouping manual",
                    subtitle: "Don’t enforce a month-based folder structure automatically.",
                    value: .manual
                )
            }

            HStack(spacing: FormaSpacing.standard) {
                Button("Continue") {
                    onResolve(selection)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 40)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .frame(minHeight: 40)

                Spacer()
            }
            .padding(.top, FormaSpacing.standard)
        }
        .padding(FormaSpacing.large)
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 560)
        .background(Color.formaBackground)
    }

    @ViewBuilder
    private func groupingOptionRow(title: String, subtitle: String, value: NLGroupingResolution) -> some View {
        Button {
            selection = value
        } label: {
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                Image(systemName: selection == value ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selection == value ? .formaSteelBlue : .formaSecondaryLabel)

                VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                    Text(title)
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaLabel)
                    Text(subtitle)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }

                Spacer()
            }
            .padding(FormaSpacing.tight)
            .background(
                colorScheme == .dark
                    ? Color.formaBoneWhite.opacity(selection == value ? 0.075 : 0.035)
                    : Color.formaBoneWhite.opacity(selection == value ? 0.70 : 0.52)
            )
            .formaCornerRadius(FormaRadius.control)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 56)
    }
}
