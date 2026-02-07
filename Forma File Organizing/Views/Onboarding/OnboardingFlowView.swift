import SwiftUI
import SwiftData

// MARK: - Onboarding Flow Coordinator

/// Streamlined onboarding: single welcome screen with trust signals and CTA.
/// "Start Organizing" requests Downloads access, applies PARA defaults, and dismisses.
/// "Skip for now" completes onboarding without permissions (JIT recovery in sidebar).
struct OnboardingFlowView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.formaBackground
                .ignoresSafeArea()

            WelcomeStepView(
                onStartOrganizing: requestAccessAndComplete,
                onSkip: skipAndComplete
            )
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Actions

    private func requestAccessAndComplete() {
        Task {
            // Request Downloads access via NSOpenPanel
            _ = await dashboardViewModel.requestDownloadsAccess()

            await MainActor.run {
                finishOnboarding()
            }
        }
    }

    private func skipAndComplete() {
        finishOnboarding()
    }

    private func finishOnboarding() {
        // Log onboarding completion
        let activityService = ActivityLoggingService(modelContext: modelContext)
        activityService.logOnboardingCompleted(templateName: "PARA Method")

        dashboardViewModel.completeOnboarding()
    }
}

// MARK: - Preview

#Preview("Onboarding Flow") {
    OnboardingFlowView()
        .environmentObject(DashboardViewModel())
}
