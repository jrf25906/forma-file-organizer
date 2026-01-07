import SwiftUI
import SwiftData

struct SidebarView: View {
    @EnvironmentObject var nav: NavigationViewModel
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var services: AppServices
    @Environment(\.modelContext) private var modelContext
    @Binding var shouldFocusSearch: Bool

    @StateObject private var customFolderManager = CustomFolderManager()
    @State private var isAddingFolder = false
    @State private var isKeyWindow = true

    var body: some View {
        // Sidebar content
        VStack(alignment: .leading, spacing: 0) {
            // Spacer to position content below traffic lights (Apple pattern)
            // Fixed height of 54pt to match standard Unified Toolbar height
            Color.clear.frame(height: 54)

            // Search Bar (Moved to top)
            SidebarSearchBar(
                text: $nav.searchText,
                shouldFocus: $shouldFocusSearch
            )
            .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)
            .padding(.bottom, FormaSpacing.standard)

            // Navigation
            ScrollView {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    // Locations - dynamically populated from granted permissions
                    HStack {
                        sectionHeader("LOCATIONS")
                        Spacer()
                        Button(action: { addNewLocation() }) {
                            Image(systemName: "plus")
                                .font(.formaCaptionBold)
                                .foregroundColor(Color.formaTertiaryLabel) // Match section header color
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isAddingFolder)
                        .help("Add a new location")
                        .padding(.top, FormaSpacing.standard)
                        .padding(.bottom, FormaSpacing.micro)
                    }
                    .padding(.trailing, FormaLayout.Sidebar.expandedHorizontalPadding)

                    // Show custom folders that have granted permissions
                    if dashboardViewModel.customFolders.isEmpty {
                        // Empty state - prompt to add locations
                        emptyLocationsPrompt
                    } else {
                        ForEach(dashboardViewModel.customFolders) { folder in
                            customFolderItem(folder)
                        }
                    }



                    // TOOLS SECTION (Grouped per user feedback)
                    sectionHeader("TOOLS")
                    
                    // Smart Rules
                    sidebarItem("Smart Rules", icon: "list.bullet.rectangle.fill", selection: .rules)

                    // Analytics (if enabled)
                    if services.featureFlags.isEnabled(.analyticsAndInsights) {
                        sidebarItem("Analytics", icon: "chart.pie.fill", selection: .analytics)
                    }

                    // Create Rule Convenience Button
                    Button(action: {
                        dashboardViewModel.showRuleBuilderPanel()
                    }) {
                        HStack(spacing: FormaSpacing.standard) {
                            Image(systemName: "plus")
                                .font(.formaCaptionBold)
                                .foregroundColor(Color.formaSecondaryLabel)
                                .frame(width: 20, alignment: .center)

                            Text("New Rule")
                                .font(.formaBody)
                            Spacer()
                        }
                        .foregroundColor(Color.formaSecondaryLabel)
                        .padding(.horizontal, FormaLayout.Sidebar.itemHorizontalPadding)
                        .padding(.vertical, FormaSpacing.tight)
                    }
                    .buttonStyle(.plain)
                    .help("Create a new organization rule (R)")
                }
                .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)
            }

        }
        // Native Flush/Replica Sidebar:
        .background {
            SidebarGlassOverlay(isKeyWindow: isKeyWindow)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: FormaLayout.FloatingCard.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: FormaLayout.FloatingCard.cornerRadius,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isKeyWindow ? 0.5 : 0.3),
                        Color.white.opacity(isKeyWindow ? 0.1 : 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .overlay(alignment: .trailing) {
            EmptyView()
        }
        .overlay {
            WindowKeyObserver(isKeyWindow: $isKeyWindow)
                .frame(width: 0, height: 0)
        }
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.formaCaption)
            .foregroundColor(Color.formaTertiaryLabel)
            .tracking(1.0)
            .padding(.top, FormaSpacing.standard)
            .padding(.bottom, FormaSpacing.micro)
    }
    
    @ViewBuilder
    private func sidebarItem(_ title: String, icon: String, selection: NavigationSelection) -> some View {
        Button(action: { nav.select(selection) }) {
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: icon)
                    .font(.formaH3)
                    .frame(width: 20, alignment: .center)

                Text(title)
                    .font(.formaBody)
                Spacer()
            }
            .foregroundColor(nav.selection == selection ? Color.formaLabel : Color.formaSecondaryLabel)
            .padding(.horizontal, FormaLayout.Sidebar.itemHorizontalPadding)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(nav.selection == selection ? Color.formaSteelBlue.opacity(Color.FormaOpacity.medium) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Folder Item

    @ViewBuilder
    private func customFolderItem(_ folder: CustomFolder) -> some View {
        let selection = NavigationSelection.custom(folder)
        let isSelected = isCustomFolderSelected(folder)

        Button(action: { nav.select(selection) }) {
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: iconForFolder(folder))
                    .font(.formaH3)
                    .frame(width: 20, alignment: .center)

                Text(folder.name)
                    .font(.formaBody)
                    .lineLimit(1)
                Spacer()
            }
            .foregroundColor(isSelected ? Color.formaLabel : Color.formaSecondaryLabel)
            .padding(.horizontal, FormaLayout.Sidebar.itemHorizontalPadding)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.medium) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                removeFolder(folder)
            } label: {
                Label("Remove Location", systemImage: "minus.circle")
            }
        }
    }

    /// Check if a custom folder is currently selected
    private func isCustomFolderSelected(_ folder: CustomFolder) -> Bool {
        if case .custom(let selectedFolder) = nav.selection {
            return selectedFolder.id == folder.id
        }
        return false
    }

    /// Get appropriate icon for a folder based on its path
    private func iconForFolder(_ folder: CustomFolder) -> String {
        let path = folder.path.lowercased()
        if path.contains("/desktop") { return "desktopcomputer" }
        if path.contains("/downloads") { return "arrow.down.circle" }
        if path.contains("/documents") { return "doc.fill" }
        if path.contains("/pictures") || path.contains("/photos") { return "photo.fill" }
        if path.contains("/music") { return "music.note" }
        if path.contains("/movies") || path.contains("/videos") { return "film" }
        return "folder.fill"
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyLocationsPrompt: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.formaBodyLarge)
                    .foregroundColor(Color.formaTertiaryLabel)
                Text("No locations added")
                    .font(.formaCaption)
                    .foregroundColor(Color.formaTertiaryLabel)
            }
            Text("Add folders to organize")
                .font(.formaSmall)
                .foregroundColor(Color.formaTertiaryLabel.opacity(Color.FormaOpacity.high))
        }
        .padding(.horizontal, FormaLayout.Sidebar.itemHorizontalPadding)
        .padding(.vertical, FormaSpacing.tight)
    }

    // MARK: - Add Location Button

    @ViewBuilder
    private var addLocationButton: some View {
        Button(action: { addNewLocation() }) {
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: "plus")
                    .font(.formaCompactSemibold)
                    .foregroundColor(Color.formaSecondaryLabel)
                    .frame(width: 20)

                Text("Add Location")
                    .font(.formaBody)
                Spacer()
            }
            .foregroundColor(Color.formaSecondaryLabel)
            .padding(.horizontal, FormaLayout.Sidebar.itemHorizontalPadding)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    .foregroundColor(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.strong))
            )
        }
        .buttonStyle(.plain)
        .disabled(isAddingFolder)
    }

    // MARK: - Folder Management Actions

    private func addNewLocation() {
        isAddingFolder = true
        Task {
            defer { isAddingFolder = false }
            do {
                let folders = try await customFolderManager.createCustomFolders()
                for folder in folders {
                    modelContext.insert(folder)
                }
                try modelContext.save()
                dashboardViewModel.loadCustomFolders(from: modelContext)

                // Auto-select the first newly added folder
                if let firstFolder = folders.first {
                    nav.select(.custom(firstFolder))
                }

                // Rescan to include new folders
                await dashboardViewModel.scanFiles(context: modelContext)
            } catch CustomFolderManager.CustomFolderError.userCancelled {
                // User cancelled - do nothing
            } catch {
                Log.error("SidebarView: Failed to add location - \(error.localizedDescription)", category: .filesystem)
                dashboardViewModel.errorMessage = "Failed to add location: \(error.localizedDescription)"
            }
        }
    }

    private func removeFolder(_ folder: CustomFolder) {
        let folderName = folder.name
        modelContext.delete(folder)
        do {
            try modelContext.save()
            dashboardViewModel.loadCustomFolders(from: modelContext)

            // If we were viewing this folder, navigate away
            if isCustomFolderSelected(folder) {
                if let firstRemaining = dashboardViewModel.customFolders.first {
                    nav.select(.custom(firstRemaining))
                } else {
                    nav.select(.rules) // Fallback to rules if no locations remain
                }
            }

            Log.info("SidebarView: Removed location '\(folderName)'", category: .filesystem)
        } catch {
            Log.error("SidebarView: Failed to remove location '\(folderName)' - \(error.localizedDescription)", category: .filesystem)
            modelContext.insert(folder) // Re-insert on failure
            dashboardViewModel.errorMessage = "Failed to remove location"
        }
    }
}
