import SwiftUI
import SwiftData

/// Empty state view shown when all files have been organized
struct AllCaughtUpView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if dashboardViewModel.hasDeferredReviewFiles {
            FormaActionableEmptyState(
                title: "Done For Now",
                message: "You set aside \(dashboardViewModel.deferredReviewFileCount) file\(dashboardViewModel.deferredReviewFileCount == 1 ? "" : "s") in this pass. Bring them back whenever you're ready.",
                iconName: "pause.circle.fill",
                iconColor: .formaSteelBlue
            ) {
                NextActionButton(
                    icon: "arrow.counterclockwise",
                    title: "Resume Deferred Files",
                    action: {
                        dashboardViewModel.resumeDeferredReviewFiles()
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
                    icon: "arrow.clockwise",
                    title: "Scan for new files",
                    action: {
                        Task { @MainActor in
                            await dashboardViewModel.scanFiles(context: modelContext)
                        }
                    }
                )
            }
        } else {
            FormaActionableEmptyState(
                title: "All Caught Up!",
                message: "You've organized all your files in review mode.",
                iconName: "checkmark.circle.fill",
                iconColor: .formaSage
            ) {
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
