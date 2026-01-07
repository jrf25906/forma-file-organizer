import SwiftUI

// MARK: - Personality Quiz Step View

/// Third step: Wrapper for the personality quiz
struct PersonalityQuizStepView: View {
    let onComplete: (OrganizationPersonality) -> Void
    let onBack: () -> Void

    var body: some View {
        PersonalityQuizView(
            onComplete: onComplete,
            onBack: onBack,
            showStepIndicator: false
        )
    }
}

// MARK: - Preview

#Preview("Personality Quiz Step") {
    PersonalityQuizStepView(
        onComplete: { personality in
            Log.debug("Personality quiz completed: \(personality)", category: .analytics)
        },
        onBack: {}
    )
    .frame(width: 650, height: 720)
    .background(Color.formaBackground)
}
