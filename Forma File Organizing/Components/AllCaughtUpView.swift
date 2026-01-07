import SwiftUI

/// Empty state view shown when all files have been organized
struct AllCaughtUpView: View {
    @State private var showCelebration = false
    @State private var checkmarkScale: CGFloat = 0.5
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    
    var body: some View {
        VStack(spacing: FormaSpacing.generous) {
            Spacer()
            
            // Success checkmark with spring animation
            ZStack {
                Circle()
                    .fill(Color.formaSage.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.formaIconLarge)
                    .foregroundColor(.formaSage)
                    .scaleEffect(checkmarkScale)
            }
            .scaleEffect(showCelebration ? 1.0 : 0.5)
            .opacity(showCelebration ? 1.0 : 0.0)
            
            // Title
            Text("All Caught Up!")
                .font(.formaH2)
                .foregroundColor(.formaLabel)
            
            // Subtitle
            Text("You've organized all your files in review mode.")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
            
            // Daily stats (if available)
            if let stats = todayStats {
                HStack(spacing: FormaSpacing.generous) {
                    StatBadge(value: "\(stats.organized)", label: "Organized")
                    StatBadge(value: "\(stats.skipped)", label: "Skipped")
                    StatBadge(value: "\(stats.rulesCreated)", label: "Rules")
                }
                .padding(.top, FormaSpacing.tight)
            }
            
            Spacer()
            
            // Next actions
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("What's next?")
                    .font(.formaBodyBold)
                    .foregroundColor(.formaLabel)
                
                VStack(spacing: FormaSpacing.tight) {
                    NextActionButton(
                        icon: "arrow.clockwise",
                        title: "Scan for new files",
                        action: {
                            Task { @MainActor in
                                await dashboardViewModel.scanFiles(context: modelContext)
                            }
                        }
                    )
                    
                    NextActionButton(
                        icon: "folder.fill",
                        title: "Switch to All Files view",
                        action: {
                            dashboardViewModel.reviewFilterMode = .all
                        }
                    )
                    
                    NextActionButton(
                        icon: "slider.horizontal.3",
                        title: "Review rules",
                        action: {
                            // This would open rules view - implement based on your navigation
                        }
                    )
                }
            }
            .padding(FormaSpacing.generous)
            .background(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
            .formaCornerRadius(FormaRadius.card)
            
            Spacer()
        }
        .padding(.horizontal, FormaSpacing.extraLarge + (FormaSpacing.standard - FormaSpacing.micro))
        .padding(.vertical, FormaSpacing.large + FormaSpacing.tight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                    showCelebration = true
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                    checkmarkScale = 1.0
                }
            } else {
                showCelebration = true
                checkmarkScale = 1.0
            }
        }
    }
    
    // Compute today's stats from activities
    private var todayStats: (organized: Int, skipped: Int, rulesCreated: Int)? {
        let today = Calendar.current.startOfDay(for: Date())
        let todayActivities = dashboardViewModel.recentActivities.filter {
            Calendar.current.isDate($0.timestamp, inSameDayAs: today)
        }
        
        guard !todayActivities.isEmpty else { return nil }
        
        let organized = todayActivities.filter { $0.activityType == .fileOrganized }.count
        let skipped = todayActivities.filter { $0.activityType == .fileSkipped }.count
        let rulesCreated = todayActivities.filter { $0.activityType == .ruleCreated }.count
        
        return (organized, skipped, rulesCreated)
    }
}

/// Small stat badge
private struct StatBadge: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: FormaSpacing.micro) {
            Text(value)
                .font(.formaH1)
                .fontWeight(.bold)
                .foregroundColor(.formaSteelBlue)
            
            Text(label)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
        }
        .frame(width: 80)
        .padding(.vertical, FormaSpacing.tight)
        .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
        .formaCornerRadius(FormaRadius.control)
    }
}

/// Next action button with icon
private struct NextActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: icon)
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaSteelBlue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.formaBody)
                    .foregroundColor(.formaLabel)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.formaCompactSemibold)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .padding(FormaSpacing.standard)
            .background(Color.formaBackground)
            .formaCornerRadius(FormaRadius.control)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AllCaughtUpView()
        .frame(width: 600, height: 400)
        .background(Color.formaBoneWhite)
}
