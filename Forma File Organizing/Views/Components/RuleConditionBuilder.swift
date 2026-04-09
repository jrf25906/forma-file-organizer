import SwiftUI

struct RuleConditionBuilder: View {
    @Binding var formState: RuleFormState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
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
                                let condition = try RuleCondition(
                                    type: formState.conditionType,
                                    value: formState.conditionValue
                                )
                                formState.conditions = [condition]
                            } catch {
                                Log.warning("RuleConditionBuilder: Failed to create initial compound condition", category: .general)
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

        if formState.showExclusionConditions || !formState.exclusionConditions.isEmpty {
            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                HStack {
                    Text("Except when")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabel)

                    Spacer()

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
            Button(action: {
                withAnimation { formState.showExclusionConditions = true }
            }) {
                Text("+ Add Exception")
                    .font(.formaSmall)
                    .foregroundColor(.formaSteelBlue)
            }
            .buttonStyle(.plain)
        }
    }

    private var singleConditionView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("If file")
                .font(.formaBodyLarge)
                .foregroundColor(.formaSecondaryLabel)

            Menu {
                ForEach(Rule.ConditionType.allCases, id: \.self) { type in
                    Button(type.displayName) {
                        formState.conditionType = type
                    }
                }
            } label: {
                Text(formState.conditionType.displayName.lowercased())
                    .font(.formaBodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.formaSteelBlue)
                    .underline(true, color: .formaSteelBlue.opacity(0.3))
            }
            .menuStyle(.borderlessButton)

            Text("is")
                .font(.formaBodyLarge)
                .foregroundColor(.formaSecondaryLabel)

            TextField(conditionPlaceholder, text: $formState.conditionValue)
                .font(.formaBodyLarge)
                .textFieldStyle(.plain)
                .padding(FormaSpacing.tight)
                .background(Color.formaControlBackground)
                .cornerRadius(FormaRadius.control)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control)
                        .stroke(Color.formaSeparator, lineWidth: FormaBorderWidth.thin)
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

            VStack(spacing: FormaSpacing.tight) {
                ForEach(Array(formState.conditions.enumerated()), id: \.offset) { index, _ in
                    conditionRow(at: index)
                }
            }

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

            VStack(spacing: FormaSpacing.tight) {
                ForEach(Array(formState.exclusionConditions.enumerated()), id: \.offset) { index, _ in
                    exclusionConditionRow(at: index)
                }
            }

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
            Image(systemName: "xmark.circle.fill")
                .font(.formaCompact)
                .foregroundColor(Color.formaWarmOrange.opacity(Color.FormaOpacity.high))
                .frame(width: 20)

            Menu {
                ForEach(Rule.ConditionType.allCases, id: \.self) { type in
                    Button(type.displayName) {
                        updateExclusionConditionType(at: index, to: type)
                    }
                }
            } label: {
                Text((index < formState.exclusionConditions.count ? formState.exclusionConditions[index].type : .nameContains).displayName)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
                    .fixedSize()
            }
            .menuStyle(.borderlessButton)

            TextField(
                conditionPlaceholder(for: index < formState.exclusionConditions.count ? formState.exclusionConditions[index].type : .nameContains),
                text: Binding(
                    get: { index < formState.exclusionConditions.count ? formState.exclusionConditions[index].value : "" },
                    set: { newValue in
                        updateExclusionConditionValue(at: index, to: newValue)
                    }
                )
            )
            .textFieldStyle(.plain)
            .padding(FormaSpacing.tight)
            .background(Color.formaControlBackground)
            .cornerRadius(FormaRadius.control)
            .frame(maxWidth: .infinity)
            .foregroundColor(Color.formaLabel)

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
                Menu {
                    ForEach(Rule.ConditionType.allCases, id: \.self) { type in
                        Button(type.displayName) {
                            updateConditionType(at: index, to: type)
                        }
                    }
                } label: {
                    Text((index < formState.conditions.count ? formState.conditions[index].type : .fileExtension).displayName)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                        .fixedSize()
                }
                .menuStyle(.borderlessButton)

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
                    .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: FormaBorderWidth.thin)
            )
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

    private func addCondition() {
        do {
            let newCondition = try RuleCondition(type: .fileExtension, value: "pdf")
            formState.conditions.append(newCondition)
        } catch {
            Log.warning("RuleConditionBuilder: Failed to add new condition", category: .general)
        }
    }

    private func removeCondition(at index: Int) {
        formState.conditions.remove(at: index)
    }

    private func addExclusionCondition() {
        do {
            let newCondition = try RuleCondition(type: .nameContains, value: "temp")
            formState.exclusionConditions.append(newCondition)
        } catch {
            Log.warning("RuleConditionBuilder: Failed to add new exclusion condition - \(error.localizedDescription)", category: .general)
        }
    }

    private func removeExclusionCondition(at index: Int) {
        formState.exclusionConditions.remove(at: index)
        if formState.exclusionConditions.isEmpty {
            formState.showExclusionConditions = false
        }
    }
}
