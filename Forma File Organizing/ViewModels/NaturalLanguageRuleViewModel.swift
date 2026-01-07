import Foundation
import SwiftUI
import Combine

/// View model that coordinates natural-language rule input, parsing,
/// and preview state for the rule editor.
@MainActor
final class NaturalLanguageRuleViewModel: ObservableObject {
    /// Raw text the user has typed.
    @Published var text: String = ""

    /// Latest parse result from the NaturalLanguageRuleParser.
    @Published var parsedRule: NLParsedRule?

    /// Indicates that a parse is currently running (for subtle HUD/loading states).
    @Published var isParsing: Bool = false

    /// Optional human-readable error for the input zone (non-blocking informational message).
    @Published var inlineMessage: String?

    private let parser = NaturalLanguageRuleParser()
    private var debounceTask: Task<Void, Never>?

    // MARK: - Public API

    /// Called by the view when the text changes (on every keystroke).
    func onTextChanged(_ newText: String) {
        text = newText

        // Cancel any in-flight debounce task.
        debounceTask?.cancel()
        inlineMessage = nil

        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsedRule = nil
            isParsing = false
            return
        }

        // Debounce full parsing to avoid running on every keystroke.
        debounceTask = Task { [weak self] in
            // Small delay (≈600ms) before parsing.
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await self?.runParse(text: trimmed)
        }
    }

    /// Called when the user explicitly submits (e.g., presses Return).
    func parseImmediately() {
        debounceTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { [weak self] in
            await self?.runParse(text: trimmed)
        }
    }

    /// Whether the current parse is complete enough to apply into the Rule editor.
    var canApplyToEditor: Bool {
        guard let parsed = parsedRule else { return false }
        return parsed.isComplete && !parsed.hasBlockingError
    }

    /// Whether the preview card should be shown.
    var shouldShowPreview: Bool {
        guard let parsed = parsedRule else { return false }
        // Hide preview for extremely low-confidence or empty parses.
        return parsed.overallConfidence >= 0.5 && (!parsed.candidateConditions.isEmpty || parsed.primaryAction != nil)
    }

    // MARK: - Private

    private func runParse(text: String) async {
        isParsing = true
        let result = parser.parse(text)
        parsedRule = result
        isParsing = false

        if result.overallConfidence < 0.5 {
            inlineMessage = "I’m not very confident about this description. You can still edit the fields below."
        } else {
            inlineMessage = nil
        }
    }
}