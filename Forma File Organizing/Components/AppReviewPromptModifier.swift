import StoreKit
import SwiftUI

/// Observes a boolean signal and triggers Apple's App Store review prompt.
struct AppReviewPromptModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @Binding var shouldRequestReview: Bool
    let eligibilityService: AppReviewEligibilityProviding

    func body(content: Content) -> some View {
        content
            .onChange(of: shouldRequestReview) { _, newValue in
                if newValue {
                    requestReview()
                    eligibilityService.markReviewRequested()
                    shouldRequestReview = false
                }
            }
    }
}

extension View {
    func appReviewPrompt(
        shouldRequest: Binding<Bool>,
        eligibilityService: AppReviewEligibilityProviding
    ) -> some View {
        modifier(AppReviewPromptModifier(
            shouldRequestReview: shouldRequest,
            eligibilityService: eligibilityService
        ))
    }
}
