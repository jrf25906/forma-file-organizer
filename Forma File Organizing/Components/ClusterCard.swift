import SwiftUI

/// Card component for displaying a detected project cluster with action buttons
struct ClusterCard: View {
    let cluster: ProjectCluster
    let onOrganize: () -> Void
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header: Type and confidence
            HStack {
                // Cluster type icon and label
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: cluster.clusterType.iconName)
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaSteelBlue)
                    
                    Text(cluster.clusterType.displayName)
                        .font(.formaSmall)
                        .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
                }
                
                Spacer()
                
                // Confidence badge
                ConfidenceBadge(score: cluster.confidenceScore, matchReason: nil)
            }
            
            // Main content: Description and pattern
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text(cluster.displayDescription)
                    .font(.formaBody)
                    .foregroundColor(Color.formaObsidian)
                
                if let pattern = cluster.detectedPattern {
                    HStack(spacing: FormaSpacing.micro) {
                        Image(systemName: "tag.fill")
                            .font(.formaCaption)
                        Text(pattern)
                            .font(.formaMono)
                    }
                    .foregroundColor(.formaSteelBlue.opacity(Color.FormaOpacity.prominent))
                    .padding(.horizontal, FormaSpacing.tight)
                    .padding(.vertical, FormaSpacing.micro)
                    .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                    .formaCornerRadius(FormaRadius.micro)
                }
            }
            
            // Suggested folder name
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "folder.fill")
                    .font(.formaCompact)
                    .foregroundColor(Color.formaWarning)
                
                Text("Organize to:")
                    .font(.formaSmall)
                    .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                
                Text(cluster.suggestedFolderName)
                    .font(.formaSmall)
                    .fontWeight(.medium)
                    .foregroundColor(Color.formaObsidian)
            }
            
            Divider()
                .background(Color.formaObsidian.opacity(Color.FormaOpacity.light))
            
            // Action buttons
            HStack(spacing: FormaSpacing.standard) {
                Button(action: onOrganize) {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "folder.badge.plus")
                            .font(.formaCompactMedium)
                        Text("Organize Together")
                            .font(.formaSmall)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.formaBoneWhite)
                    .padding(.horizontal, FormaSpacing.large)
                    .padding(.vertical, FormaSpacing.tight)
                    .background(Color.formaSteelBlue)
                    .formaCornerRadius(FormaRadius.control)
                }
                .buttonStyle(.plain)
                
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.formaSmall)
                        .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaControlBackground)
                .shadow(
                    color: isHovered
                        ? .formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle)
                        : .formaObsidian.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle),
                    radius: isHovered ? 12 : 8,
                    x: 0,
                    y: isHovered ? 6 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(isHovered ? Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Note: Using ConfidenceBadge from FileRow.swift - removed duplicate definition

// MARK: - Preview

#Preview("Project Code Cluster") {
    VStack(spacing: 20) {
        ClusterCard(
            cluster: ProjectCluster(
                clusterType: .projectCode,
                filePaths: [
                    "/Users/test/Downloads/P-1024_proposal.pdf",
                    "/Users/test/Downloads/P-1024_budget.xlsx",
                    "/Users/test/Downloads/P-1024_timeline.png"
                ],
                confidenceScore: 0.95,
                suggestedFolderName: "Project P-1024",
                detectedPattern: "P-1024"
            ),
            onOrganize: { Log.debug("Preview organize project code cluster", category: .analytics) },
            onDismiss: { Log.debug("Preview dismiss project code cluster", category: .analytics) }
        )
        
        ClusterCard(
            cluster: ProjectCluster(
                clusterType: .temporal,
                filePaths: [
                    "/Users/test/Desktop/design_v1.sketch",
                    "/Users/test/Desktop/design_v2.sketch",
                    "/Users/test/Desktop/design_v3.sketch",
                    "/Users/test/Desktop/client_feedback.txt"
                ],
                confidenceScore: 0.65,
                suggestedFolderName: "Design Work Session"
            ),
            onOrganize: { Log.debug("Preview organize temporal cluster", category: .analytics) },
            onDismiss: { Log.debug("Preview dismiss temporal cluster", category: .analytics) }
        )
        
        ClusterCard(
            cluster: ProjectCluster(
                clusterType: .nameSimilarity,
                filePaths: [
                    "/Users/test/Downloads/report_draft.docx",
                    "/Users/test/Downloads/report_final.docx",
                    "/Users/test/Downloads/report_revised.docx"
                ],
                confidenceScore: 0.85,
                suggestedFolderName: "Report Versions"
            ),
            onOrganize: { Log.debug("Preview organize name similarity cluster", category: .analytics) },
            onDismiss: { Log.debug("Preview dismiss name similarity cluster", category: .analytics) }
        )
    }
    .padding()
    .frame(maxWidth: 500)
}
