import SwiftUI
import SwiftData

/// Celebration mode of the right panel showing success feedback and undo option
struct CelebrationView: View {
    let message: String
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false
    @State private var undoCountdown = 10
    @State private var timerActive = true
    @State private var undoTimerTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            VStack(spacing: FormaSpacing.extraLarge) {
                Spacer()
                    .frame(height: FormaSpacing.generous)
                
                // Success Animation
                successAnimation
                
                // Message Display
                messageSection
                
                actionSection

                if let recommendation = dashboardViewModel.trustedScopeRecommendation {
                    trustAutomationSection(recommendation)
                }
                
                // Next Action Suggestion
                if dashboardViewModel.celebrationShowsNextActionSuggestion,
                   let suggestion = nextActionSuggestion {
                    nextActionSection(suggestion)
                }
                
                Spacer()
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, FormaSpacing.generous)
        }
        .background(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
        .onAppear {
            startAnimation()
            startUndoTimer()
        }
        .sheet(isPresented: trustedScopeRecommendationSheetBinding) {
            if let recommendation = dashboardViewModel.trustedScopeRecommendation {
                TrustedAutomationScopeRecommendationSheet(
                    recommendation: recommendation,
                    onConfirm: { scopeType in
                        dashboardViewModel.confirmTrustedScopeRecommendation(
                            selectedScopeType: scopeType,
                            context: modelContext
                        )
                    },
                    onCancel: {
                        dashboardViewModel.dismissTrustedScopeRecommendation()
                    }
                )
            }
        }
        .onDisappear {
            undoTimerTask?.cancel()
            undoTimerTask = nil
        }
    }
    
    // MARK: - Success Animation
    
    private var successAnimation: some View {
        ZStack {
            // Gradient background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.formaSage.opacity(Color.FormaOpacity.medium),
                            Color.formaSteelBlue.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
            
            // Checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .font(.formaIconLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.formaSage, Color.formaSteelBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0.0)
        }
    }
    
    // MARK: - Message Section
    
    private var messageSection: some View {
        VStack(spacing: FormaSpacing.tight) {
            Text("Success!")
                .font(.formaH1)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundColor(.formaLabel)
            
            Text(message)
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, FormaSpacing.standard)
    }
    
    // MARK: - Actions
    
    private var actionSection: some View {
        VStack(spacing: FormaSpacing.standard) {
            if dashboardViewModel.celebrationShowsUndo {
                Button(action: {
                    timerActive = false
                    dashboardViewModel.undoLastAction(context: modelContext)
                }) {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.formaH3)
                        Text("Undo")
                            .font(.formaH3)

                        if timerActive {
                            Text("(\(undoCountdown)s)")
                                .font(.formaBodyMedium)
                                .foregroundColor(.formaBoneWhite.opacity(Color.FormaOpacity.prominent))
                        }
                    }
                    .foregroundStyle(Color.formaBoneWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.large)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaSage)
                    )
                    .shadow(color: Color.formaSage.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .pressAnimation()
                .disabled(!dashboardViewModel.canUndo())
                .opacity(dashboardViewModel.canUndo() ? 1.0 : Color.FormaOpacity.strong)
            }
            
            // Manual dismiss button
            Button(action: {
                timerActive = false
                dashboardViewModel.dismissCelebrationPanel()
            }) {
                Text("Continue")
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, FormaSpacing.standard)
    }
    
    // MARK: - Next Action Section
    
    private func nextActionSection(_ suggestion: String) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "lightbulb.fill")
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaWarmOrange)
                
                Text("What's next?")
                    .font(.formaBodySemibold)
                    .tracking(0.5)
                    .foregroundColor(.formaSecondaryLabel)
            }
            
            Text(suggestion)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .lineLimit(2)
            
            Button(action: {
                timerActive = false
                nav.openRuleBuilderPanel(returnTarget: .defaultPanel)
                dashboardViewModel.showRuleBuilderPanel()
            }) {
                HStack(spacing: FormaSpacing.micro) {
                    Text("Create Rule")
                        .font(.formaSmall)
                    Image(systemName: "arrow.right")
                        .font(.formaCaptionBold)
                }
                .foregroundColor(.formaSteelBlue)
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }

    private func trustAutomationSection(_ recommendation: TrustedAutomationScopeRecommendation) -> some View {
        let snapshot = TrustedAutomationScopeRecommendationSheet.Snapshot(
            recommendation: recommendation,
            selectedScopeType: recommendation.recommendedScope.scopeType
        )

        return VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "checkmark.shield")
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaSteelBlue)

                Text("Trust this automatically")
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
            }

            Text(snapshot.rationaleSummary)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                trustDetailRow(title: snapshot.sourceBoundaryTitle, value: snapshot.sourceBoundarySummary)
                trustDetailRow(title: snapshot.destinationTitle, value: snapshot.destinationSummary)
            }

            Text(snapshot.automaticBehaviorSummary)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            Text(snapshot.preflightSummary)
                .font(.formaCaption)
                .foregroundColor(.formaSecondaryLabelHigh)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                timerActive = false
                dashboardViewModel.presentTrustedScopeRecommendation()
            }) {
                HStack(spacing: FormaSpacing.micro) {
                    Text("Review trust boundary")
                        .font(.formaSmallSemibold)
                    Image(systemName: "arrow.right")
                        .font(.formaCaptionBold)
                }
                .foregroundColor(.formaSteelBlue)
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }

    private func trustDetailRow(title: String, value: String) -> some View {
        return VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text(title)
                .font(.formaCaptionBold)
                .foregroundColor(.formaSecondaryLabelHigh)
            Text(value)
                .font(.formaSmall)
                .foregroundColor(.formaLabel)
        }
    }
    
    // MARK: - Computed Properties
    
    private var nextActionSuggestion: String? {
        // Analyze recent actions and suggest next steps
        let recentFiles = dashboardViewModel.recentActivities
            .prefix(5)
            .filter { $0.activityType == .fileOrganized }
        
        if recentFiles.count >= 3 {
            return "You've organized several files. Create a rule to automate this in the future?"
        }

        return nil
    }

    private var trustedScopeRecommendationSheetBinding: Binding<Bool> {
        Binding(
            get: { dashboardViewModel.isTrustedScopeRecommendationPresented },
            set: { isPresented in
                if !isPresented {
                    dashboardViewModel.dismissTrustedScopeRecommendation()
                }
            }
        )
    }
    
    // MARK: - Animation Helpers
    
    private func startAnimation() {
        if reduceMotion {
            isAnimating = true
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                isAnimating = true
            }
        }
    }
    
    private func startUndoTimer() {
        undoTimerTask?.cancel()
        undoTimerTask = Task { @MainActor in
            while timerActive && undoCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                guard timerActive else { return }
                undoCountdown -= 1
            }

            if undoCountdown <= 0 {
                timerActive = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FileItem.self, Rule.self, ActivityItem.self, configurations: config)
    
    CelebrationView(message: "Organized 5 files to Documents/Work")
        .environmentObject(DashboardViewModel())
        .modelContainer(container)
        .frame(width: 360, height: 800)
        .background(.regularMaterial)
}
