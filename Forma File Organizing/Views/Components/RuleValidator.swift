import Foundation

enum RuleValidatorMode {
    case fullEditor
    case inline
}

struct RuleValidationResult {
    let message: String
    let shouldShake: Bool
}

enum RuleValidator {
    @MainActor
    static func validate(
        formState: RuleFormState,
        editingRule: Rule?,
        naturalLanguageViewModel: NaturalLanguageRuleViewModel?,
        mode: RuleValidatorMode
    ) -> RuleValidationResult? {
        switch mode {
        case .fullEditor:
            return validateFullEditor(
                formState: formState,
                editingRule: editingRule,
                naturalLanguageViewModel: naturalLanguageViewModel
            )
        case .inline:
            return validateInline(formState: formState)
        }
    }

    @MainActor
    private static func validateFullEditor(
        formState: RuleFormState,
        editingRule: Rule?,
        naturalLanguageViewModel: NaturalLanguageRuleViewModel?
    ) -> RuleValidationResult? {
        if editingRule == nil,
           formState.actionType == .delete,
           let naturalLanguageViewModel,
           !naturalLanguageViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let parsed = naturalLanguageViewModel.parsedRule,
           (parsed.overallConfidence < 0.75 || parsed.isAmbiguous) {
            return RuleValidationResult(
                message: "This delete rule is based on an uncertain natural-language description. Please refine it or adjust the fields manually before saving.",
                shouldShake: true
            )
        }

        if formState.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return RuleValidationResult(message: "Rule name is required", shouldShake: true)
        }

        if formState.useCompoundConditions {
            if formState.conditions.isEmpty {
                return RuleValidationResult(message: "At least one condition is required", shouldShake: false)
            }

            for (index, condition) in formState.conditions.enumerated() {
                if condition.value.trimmingCharacters(in: .whitespaces).isEmpty {
                    return RuleValidationResult(
                        message: "Condition \(index + 1) value is required",
                        shouldShake: true
                    )
                }

                if condition.type == .fileExtension && condition.value.hasPrefix(".") {
                    return RuleValidationResult(
                        message: "Condition \(index + 1): File extension should not include the dot",
                        shouldShake: false
                    )
                }
            }
        } else {
            if formState.conditionValue.trimmingCharacters(in: .whitespaces).isEmpty {
                return RuleValidationResult(message: "Condition value is required", shouldShake: false)
            }

            if formState.conditionType == .fileExtension && formState.conditionValue.hasPrefix(".") {
                return RuleValidationResult(message: "File extension should not include the dot", shouldShake: false)
            }
        }

        if formState.actionType == .move || formState.actionType == .copy {
            if formState.destinationBookmarkData == nil {
                return RuleValidationResult(
                    message: "Please select a destination folder using the folder picker",
                    shouldShake: false
                )
            }
        }

        return nil
    }

    private static func validateInline(formState: RuleFormState) -> RuleValidationResult? {
        if formState.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return RuleValidationResult(message: "Rule name is required", shouldShake: false)
        }

        let hasConditions = !formState.conditions.isEmpty
            || !formState.conditionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasConditions {
            return RuleValidationResult(message: "At least one condition is required", shouldShake: false)
        }

        if formState.actionType == .move || formState.actionType == .copy {
            if !formState.hasBookmark {
                return RuleValidationResult(message: "Please select a destination folder", shouldShake: false)
            }
        }

        return nil
    }
}
