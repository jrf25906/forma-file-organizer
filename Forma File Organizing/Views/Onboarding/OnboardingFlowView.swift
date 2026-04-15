import SwiftUI
import SwiftData

// MARK: - Onboarding Flow Coordinator

/// Multi-step onboarding: Welcome → How It Works → Get Started → Dashboard.
/// "Start Organizing" on Get Started requests Downloads access, applies PARA defaults, and dismisses.
/// "Skip for now" on Welcome or Get Started completes onboarding without permissions (JIT recovery in sidebar).
struct OnboardingFlowView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep: OnboardingState.OnboardingStep = .welcome
    @State private var navigationDirection: NavigationDirection = .forward
    @State private var permissionErrorMessage: String?

    private enum NavigationDirection {
        case forward, backward
    }

    var body: some View {
        ZStack {
            Color.formaBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step indicator dots
                stepIndicator
                    .padding(.top, FormaSpacing.standard)

                // Screen content
                ZStack {
                    switch currentStep {
                    case .welcome:
                        WelcomeStepView(
                            onContinue: { navigateTo(.howItWorks) },
                            onSkip: skipAndComplete
                        )
                        .transition(slideTransition)

                    case .howItWorks:
                        HowItWorksStepView(
                            onContinue: { navigateTo(.getStarted) },
                            onBack: { navigateBack(to: .welcome) }
                        )
                        .transition(slideTransition)

                    case .getStarted:
                        GetStartedStepView(
                            onStartOrganizing: requestAccessAndComplete,
                            onBack: { navigateBack(to: .howItWorks) },
                            onSkip: skipAndComplete,
                            errorMessage: permissionErrorMessage
                        )
                        .transition(slideTransition)

                    case .done:
                        EmptyView()
                    }
                }
            }
        }
        .frame(width: 520, height: 520)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboardingFlow")
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: FormaSpacing.tight) {
            ForEach(OnboardingState.OnboardingStep.visibleSteps, id: \.rawValue) { step in
                Circle()
                    .fill(
                        step == currentStep
                            ? Color.formaSteelBlue
                            : Color.formaSecondaryLabel.opacity(0.3)
                    )
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
        }
    }

    // MARK: - Navigation

    private var slideTransition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private func navigateTo(_ step: OnboardingState.OnboardingStep) {
        navigationDirection = .forward
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = step
        }
    }

    private func navigateBack(to step: OnboardingState.OnboardingStep) {
        navigationDirection = .backward
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = step
        }
    }

    // MARK: - Actions

    private func requestAccessAndComplete() {
        Task {
            await MainActor.run {
                permissionErrorMessage = nil
            }

            let result = await dashboardViewModel.requestDownloadsAccess()

            await MainActor.run {
                switch result {
                case .granted:
                    finishOnboarding()
                case .cancelled:
                    permissionErrorMessage = "Downloads access is required to finish setup. Choose Downloads to continue."
                case .error(let message):
                    permissionErrorMessage = message
                }
            }
        }
    }

    private func skipAndComplete() {
        permissionErrorMessage = nil
        finishOnboarding()
    }

    private func finishOnboarding() {
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
