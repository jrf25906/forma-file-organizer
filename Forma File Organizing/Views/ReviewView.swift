import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject var nav: NavigationViewModel
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @StateObject private var viewModel = ReviewViewModel()
    @State private var viewMode: ViewMode = .grouped
    @State private var showQuickRuleSheet = false
    @State private var selectedFileForRule: FileItem?
    @State private var expandedGroups: Set<String> = []
    
    // Grouped files by destination and confidence
    private var fileGroups: [(destination: String, files: [FileItem], confidenceLevel: ConfidenceLevel)] {
        let filesWithDestinations = viewModel.files.filter { $0.destination != nil }

        // Group by destination display name
        let byDestination = Dictionary(grouping: filesWithDestinations) { $0.destination?.displayName ?? "Unknown" }
        
        var groups: [(destination: String, files: [FileItem], confidenceLevel: ConfidenceLevel)] = []
        
        // Then sub-group by confidence level within each destination
        for (destination, destFiles) in byDestination {
            let byConfidence = Dictionary(grouping: destFiles) { file -> ConfidenceLevel in
                guard let score = file.confidenceScore else { return .low }
                if score >= 0.9 { return .high }
                else if score >= 0.6 { return .medium }
                else { return .low }
            }
            
            // Create a group for each confidence level that has files
            for level in [ConfidenceLevel.high, .medium, .low] {
                if let files = byConfidence[level], !files.isEmpty {
                    groups.append((destination, files, level))
                }
            }
        }
        
        // Sort: high confidence first, then by destination
        return groups.sorted { lhs, rhs in
            if lhs.confidenceLevel != rhs.confidenceLevel {
                return lhs.confidenceLevel.sortOrder < rhs.confidenceLevel.sortOrder
            }
            return lhs.destination < rhs.destination
        }
    }
    
    private var filesWithoutDestinations: [FileItem] {
        viewModel.files.filter { $0.destination == nil }
    }

    enum ViewMode {
        case list
        case grouped
        case card
    }
    
    enum ConfidenceLevel: Hashable {
        case high, medium, low
        
        var sortOrder: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
        
        var displayName: String {
            switch self {
            case .high: return "High Confidence"
            case .medium: return "Medium Confidence"
            case .low: return "Low Confidence"
            }
        }
        
        var icon: String {
            switch self {
            case .high: return "checkmark.shield.fill"
            case .medium: return "checkmark.circle.fill"
            case .low: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .high: return .formaSage
            case .medium: return .formaSteelBlue
            case .low: return .formaWarmOrange
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Review Files")
                        .formaH2Style()
                        .foregroundColor(Color.formaObsidian)
                    Text("\(viewModel.files.count) \(viewModel.files.count == 1 ? "file" : "files") found on Desktop")
                        .formaMetadataStyle()
                        .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                }

                Spacer()

                // Quick Actions
                HStack(spacing: FormaSpacing.tight) {
                    // Refresh Button
                    Button(action: { Task { await viewModel.refresh() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.formaBodyMedium)
                            .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
                            .frame(width: 32, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.loadingState == .loading)
                    .accessibilityLabel("Refresh")

                    // Add Rule Button
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            nav.isShowingRuleEditor = true 
                        }
                    }) {
                        HStack(spacing: FormaSpacing.micro) {
                            Image(systemName: "plus")
                                .font(.formaCompactSemibold)
                            Text("Rule")
                                .font(.formaCompactSemibold)
                        }
                        .foregroundColor(Color.formaSteelBlue)
                        .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
                        .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
                        .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                        .formaCornerRadius(FormaRadius.micro)
                    }
                    .buttonStyle(.plain)

                    // Settings Button
                    Button(action: { openSettings() }) {
                        Image(systemName: "gearshape")
                            .font(.formaBodyMedium)
                            .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
                            .frame(width: 32, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }

                // View Toggle
                Picker("View Mode", selection: $viewMode) {
                    Label("List", systemImage: "list.bullet")
                        .tag(ViewMode.list)
                    Label("Grouped", systemImage: "folder.badge.gearshape")
                        .tag(ViewMode.grouped)
                    Label("Grid", systemImage: "square.grid.2x2")
                        .tag(ViewMode.card)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(FormaSpacing.generous)
            .background(Color.formaBoneWhite)

            // Status Messages
            if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.formaWarning)
                        Text(errorMessage)
                            .formaMetadataStyle()
                            .foregroundColor(Color.formaObsidian)
                        Spacer()
                        Button("Try Again") {
                            viewModel.clearError()
                            Task { await viewModel.refresh() }
                        }
                        .formaMetadataStyle()
                        .foregroundColor(Color.formaSteelBlue)
                        .buttonStyle(.plain)
                    }

                    // Show reset permissions option for permission-related errors
                    if errorMessage.contains("permission") || errorMessage.contains("Permission") {
                        HStack {
                            Text("Still having trouble?")
                                .formaMetadataStyle()
                                .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
                            Button("Reset All Permissions") {
                                viewModel.resetAllPermissions()
                            }
                            .formaMetadataStyle()
                            .foregroundColor(Color.formaSteelBlue)
                            .buttonStyle(.plain)
                            .underline()
                        }
                        .padding(.top, FormaSpacing.micro)
                    }
                }
                .padding(FormaSpacing.standard)
                .background(Color.formaWarning.opacity(Color.FormaOpacity.light))
                .formaCornerRadius(FormaRadius.micro)
                .padding(.horizontal, FormaSpacing.generous)
                .padding(.top, FormaSpacing.tight)
            }

            if let successMessage = viewModel.successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.formaSuccess)
                    Text(successMessage)
                        .formaMetadataStyle()
                        .foregroundColor(Color.formaObsidian)
                    Spacer()
                }
                .padding(FormaSpacing.standard)
                .background(Color.formaSuccess.opacity(Color.FormaOpacity.light))
                .formaCornerRadius(FormaRadius.micro)
                .padding(.horizontal, FormaSpacing.generous)
                .padding(.top, FormaSpacing.tight)
            }
            
            Divider()

            // Content
            Group {
                switch viewModel.loadingState {
                case .idle, .loading:
                    ReviewLoadingStateView()

                case .error:
                    EmptyStateView()

                case .loaded:
                    if viewModel.files.isEmpty {
                        EmptyStateView()
                    } else {
                        ScrollView {
                            if viewMode == .grouped {
                                // Grouped View
                                VStack(spacing: FormaSpacing.large) {
                                    // Groups with destinations (grouped by confidence)
                                    ForEach(fileGroups, id: \.destination) { group in
                                        let groupKey = "\(group.destination)-\(group.confidenceLevel.displayName)"
                                        let destinationGroupConfidence: DestinationGroupView.ConfidenceLevel? = {
                                            switch group.confidenceLevel {
                                            case .high: return .high
                                            case .medium: return .medium
                                            case .low: return .low
                                            }
                                        }()
                                        DestinationGroupView(
                                            destination: group.destination,
                                            files: group.files,
                                            confidenceLevel: destinationGroupConfidence,
                                            isExpanded: expandedGroups.contains(groupKey),
                                            onToggle: {
                                                if expandedGroups.contains(groupKey) {
                                                    expandedGroups.remove(groupKey)
                                                } else {
                                                    expandedGroups.insert(groupKey)
                                                }
                                            },
                                            onAcceptAll: { files in
                                                Task {
                                                    for file in files {
                                                        await viewModel.moveFile(file)
                                                    }
                                                }
                                            },
                                            onSkipAll: { files in
                                                for file in files {
                                                    viewModel.skipFile(file)
                                                }
                                            },
                                            onOrganizeFile: { file in
                                                Task { await viewModel.moveFile(file) }
                                            },
                                            onSkipFile: { file in
                                                viewModel.skipFile(file)
                                            },
                                            onCreateRule: { file in
                                                selectedFileForRule = file
                                                showQuickRuleSheet = true
                                            }
                                        )
                                    }
                                    
                                    // Files without destinations
                                    if !filesWithoutDestinations.isEmpty {
                                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                                            Text("No destination suggested")
                                                .font(.formaBodySemibold)
                                                .foregroundStyle(Color.formaSecondaryLabel)
                                                .padding(.horizontal, FormaSpacing.large)
                                            
                                            ForEach(filesWithoutDestinations) { file in
                                                FileRow(
                                                    file: file,
                                                    onOrganize: { item in
                                                        Task { await viewModel.moveFile(item) }
                                                    },
                                                    onSkip: { item in
                                                        viewModel.skipFile(item)
                                                    },
                                                    onCreateRule: { item in
                                                        selectedFileForRule = item
                                                        showQuickRuleSheet = true
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                                .padding(FormaSpacing.generous)
                            } else if viewMode == .list {
                                LazyVStack(spacing: 1) {
                                    ForEach(viewModel.files) { file in
                                        FileRow(
                                            file: file,
                                            onOrganize: { item in
                                                Task { await viewModel.moveFile(item) }
                                            },
                                            onSkip: { item in
                                                viewModel.skipFile(item)
                                            },
                                            onCreateRule: { item in
                                                selectedFileForRule = item
                                                showQuickRuleSheet = true
                                            }
                                        )
                                        Divider()
                                            .opacity(Color.FormaOpacity.strong)
                                    }
                                }
                                .padding(.bottom, FormaSpacing.standard)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: FormaSpacing.generous)], spacing: FormaSpacing.generous) {
                                    ForEach(viewModel.files) { file in
                                        FileRow(
                                            file: file,
                                            onOrganize: { item in
                                                Task { await viewModel.moveFile(item) }
                                            },
                                            onSkip: { item in
                                                viewModel.skipFile(item)
                                            },
                                            onCreateRule: { item in
                                                selectedFileForRule = item
                                                showQuickRuleSheet = true
                                            }
                                        )
                                    }
                                }
                                .padding(FormaSpacing.generous)
                                .padding(.bottom, FormaSpacing.standard)
                            }
                        }
                        .background(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong))
                        .overlay(alignment: .bottom) {
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.formaBoneWhite.opacity(Color.FormaOpacity.overlay),
                                    Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 40)
                            .allowsHitTesting(false)
                        }
                    }
                }
            }
            
            // Footer / Batch Actions (List Mode only)
            if viewMode == .list && !viewModel.files.isEmpty && viewModel.loadingState == .loaded {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        let readyCount = viewModel.files.filter { $0.status == .ready }.count
                        Text("\(readyCount) of \(viewModel.files.count) ready to organize")
                            .formaMetadataStyle()
                            .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))

                        Spacer()

                        PrimaryButton("Organize All", icon: "sparkles") {
                            Task { await viewModel.moveAllFiles() }
                        }
                        .frame(width: 160)
                        .disabled(readyCount == 0)
                    }
                    .padding(FormaSpacing.standard)
                    .background(Color.formaBoneWhite)
                }
            }
        }
        .background(Color.formaBoneWhite)
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .sheet(isPresented: $showQuickRuleSheet) {
            if let file = selectedFileForRule {
                QuickRuleCreationSheet(file: file)
                    .environmentObject(dashboardViewModel)
            }
        }
    }
}

// MARK: - Loading State View
struct ReviewLoadingStateView: View {
    var body: some View {
        VStack(spacing: FormaSpacing.generous) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.formaSteelBlue)

            Text("Scanning Desktop...")
                .formaBodyStyle()
                .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.high))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong))
    }
}
