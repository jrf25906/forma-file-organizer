import SwiftUI
import SwiftData

/// View for displaying and managing detected project clusters
struct ProjectClusterView: View {
    @Environment(\.modelContext) private var modelContext

    let clusters: [ProjectCluster]
    let files: [FileItem]
    let isLoading: Bool
    let onOrganizeCluster: (ProjectCluster) -> Void
    let onDismissCluster: (ProjectCluster) -> Void

    @State private var selectedCluster: ProjectCluster?
    @State private var showOrganizeSheet = false

    init(
        clusters: [ProjectCluster],
        files: [FileItem],
        isLoading: Bool = false,
        onOrganizeCluster: @escaping (ProjectCluster) -> Void,
        onDismissCluster: @escaping (ProjectCluster) -> Void
    ) {
        self.clusters = clusters
        self.files = files
        self.isLoading = isLoading
        self.onOrganizeCluster = onOrganizeCluster
        self.onDismissCluster = onDismissCluster
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaSpacing.generous) {
                // Header
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.formaH1)
                            .foregroundColor(.formaSteelBlue)
                        
                        Text("Smart Clusters")
                            .formaH2Style()
                    }
                    
                    Text("We detected \(clusters.count) group\(clusters.count == 1 ? "" : "s") of related files")
                        .formaBodyStyle()
                        .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
                }
                .padding(.horizontal, FormaSpacing.generous)
                .padding(.top, FormaSpacing.generous)
                
                if isLoading {
                    // Loading state
                    VStack(spacing: FormaSpacing.large) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.formaSteelBlue)

                        Text("Analyzing file patterns...")
                            .formaBodyStyle()
                            .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.huge)
                } else if clusters.isEmpty {
                    // Empty state
                    VStack(spacing: FormaSpacing.large) {
                        Image(systemName: "doc.on.doc")
                            .font(.formaIcon)
                            .foregroundColor(.formaObsidian.opacity(Color.FormaOpacity.overlay))

                        Text("No clusters detected yet")
                            .formaH3Style()
                            .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))

                        Text("As you work with files, we'll detect patterns and suggest organizing related files together")
                            .formaBodyStyle()
                            .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.huge)
                } else {
                    // Cluster cards
                    VStack(spacing: FormaSpacing.large) {
                        ForEach(clusters, id: \.id) { cluster in
                            ClusterCard(
                                cluster: cluster,
                                onOrganize: {
                                    handleOrganizeCluster(cluster)
                                },
                                onDismiss: {
                                    handleDismissCluster(cluster)
                                }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.bottom, FormaSpacing.generous)
                }
            }
        }
        .background(Color.formaBoneWhite)
        .sheet(isPresented: $showOrganizeSheet) {
            if let cluster = selectedCluster {
                ClusterOrganizeSheet(
                    cluster: cluster,
                    files: files,
                    onConfirm: { destinationPath in
                        organizeCluster(cluster, to: destinationPath)
                    },
                    onCancel: {
                        showOrganizeSheet = false
                        selectedCluster = nil
                    }
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleOrganizeCluster(_ cluster: ProjectCluster) {
        selectedCluster = cluster
        showOrganizeSheet = true
    }
    
    private func handleDismissCluster(_ cluster: ProjectCluster) {
        withAnimation(.easeOut(duration: 0.2)) {
            cluster.dismiss()
            onDismissCluster(cluster)

            // Save changes
            do {
                try modelContext.save()
            } catch {
                Log.error("ProjectClusterView: Failed to save cluster dismissal - \(error.localizedDescription)", category: .analytics)
            }
        }
    }

    private func organizeCluster(_ cluster: ProjectCluster, to destinationPath: String) {
        onOrganizeCluster(cluster)
        cluster.markAsOrganized()

        // Save changes
        do {
            try modelContext.save()
        } catch {
            Log.error("ProjectClusterView: Failed to save cluster organization - \(error.localizedDescription)", category: .analytics)
        }

        // Close sheet
        showOrganizeSheet = false
        selectedCluster = nil
    }
}

// MARK: - Organize Sheet

private struct ClusterOrganizeSheet: View {
    let cluster: ProjectCluster
    let files: [FileItem]
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var destinationPath: String = ""
    @State private var createNewFolder = true
    
    var clusterFiles: [FileItem] {
        files.filter { cluster.filePaths.contains($0.path) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.large) {
            // Header
            HStack {
                Image(systemName: cluster.clusterType.iconName)
                    .font(.formaH1)
                    .foregroundColor(.formaSteelBlue)
                
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Organize Cluster")
                        .formaH3Style()
                    
                    Text(cluster.displayDescription)
                        .font(.formaSmall)
                        .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
                }
                
                Spacer()
            }
            
            Divider()
            
            // Files in cluster
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text("Files to organize (\(clusterFiles.count))")
                    .font(.formaBody)
                    .fontWeight(.semibold)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        ForEach(clusterFiles, id: \.path) { file in
                            HStack(spacing: FormaSpacing.tight) {
                                Image(systemName: file.iconName)
                                    .font(.formaCompact)
                                    .foregroundColor(file.category.color)
                                
                                Text(file.name)
                                    .font(.formaSmall)
                                    .foregroundColor(Color.formaObsidian)
                                
                                Spacer()
                                
                                Text(file.size)
                                    .font(.formaCaption)
                                    .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong))
                            }
                            .padding(.vertical, FormaSpacing.micro)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .padding(FormaSpacing.standard)
                .background(Color.formaBoneWhite)
                .formaCornerRadius(FormaRadius.control)
            }
            
            // Destination settings
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Toggle("Create new folder", isOn: $createNewFolder)
                    .formaBodyStyle()
                
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text("Folder name")
                        .font(.formaSmall)
                        .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
                    
                    TextField("", text: $destinationPath)
                        .textFieldStyle(.plain)
                        .padding(FormaSpacing.standard)
                        .background(Color.formaBoneWhite)
                        .formaCornerRadius(FormaRadius.control)
                        .overlay(
                            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
                        )
                }
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: FormaSpacing.standard) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .formaBodyStyle()
                        .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FormaSpacing.standard)
                        .background(Color.formaBoneWhite)
                        .formaCornerRadius(FormaRadius.control)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    let finalPath = destinationPath.isEmpty ? cluster.suggestedFolderName : destinationPath
                    onConfirm(finalPath)
                }) {
                    Text("Organize Files")
                        .formaBodyStyle()
                        .fontWeight(.medium)
                        .foregroundColor(.formaBoneWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FormaSpacing.standard)
                        .background(Color.formaSteelBlue)
                        .formaCornerRadius(FormaRadius.control)
                }
                .buttonStyle(.plain)
                .disabled(createNewFolder && destinationPath.isEmpty && cluster.suggestedFolderName.isEmpty)
            }
        }
        .padding(FormaSpacing.generous)
        .frame(minWidth: 500, maxWidth: 600)
        .onAppear {
            destinationPath = cluster.suggestedFolderName
        }
    }
}

// MARK: - Preview

#Preview("With Clusters") {
    ProjectClusterView(
        clusters: ProjectCluster.mocks,
        files: FileItem.mocks,
        onOrganizeCluster: { cluster in
            Log.debug("Preview organize cluster: \(cluster.suggestedFolderName)", category: .analytics)
        },
        onDismissCluster: { cluster in
            Log.debug("Preview dismiss cluster: \(cluster.suggestedFolderName)", category: .analytics)
        }
    )
}

#Preview("Empty State") {
    ProjectClusterView(
        clusters: [],
        files: [],
        onOrganizeCluster: { _ in },
        onDismissCluster: { _ in }
    )
}

#Preview("Loading State") {
    ProjectClusterView(
        clusters: [],
        files: [],
        isLoading: true,
        onOrganizeCluster: { _ in },
        onDismissCluster: { _ in }
    )
}
