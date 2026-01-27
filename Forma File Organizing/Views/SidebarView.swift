import SwiftUI
import SwiftData

struct SidebarView: View {
    @EnvironmentObject var nav: NavigationViewModel
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var services: AppServices
    @Environment(\.modelContext) private var modelContext
    @Binding var shouldFocusSearch: Bool

    @ObservedObject private var folderService = BookmarkFolderService.shared
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

                    // Show folders that have granted permissions (from Keychain)
                    if folderService.availableFolders.isEmpty {
                        // Empty state - prompt to add locations
                        emptyLocationsPrompt
                    } else {
                        ForEach(folderService.availableFolders) { folder in
                            bookmarkFolderItem(folder)
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
        .onAppear {
            // Refresh folder service when sidebar appears to ensure locations are current
            folderService.refresh()
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

    // MARK: - Bookmark Folder Item

    @ViewBuilder
    private func bookmarkFolderItem(_ folder: BookmarkFolder) -> some View {
        let selection = NavigationSelection.from(folderType: folder.folderType)
        let isSelected = isFolderSelected(folder)

        Button(action: { nav.select(selection) }) {
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: folder.iconName)
                    .font(.formaH3)
                    .frame(width: 20, alignment: .center)

                Text(folder.displayName)
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

    /// Check if a bookmark folder is currently selected
    private func isFolderSelected(_ folder: BookmarkFolder) -> Bool {
        nav.selection.folderType == folder.folderType
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

            // Show folder picker to grant access to a new folder
            // This will save the bookmark to Keychain via FileSystemService
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Choose a folder to organize"
            panel.prompt = "Grant Access"

            let response = await panel.begin()
            guard response == .OK, let url = panel.url else {
                return // User cancelled
            }

            // Determine which folder type this is (if it's a standard folder)
            let folderType = determineFolderType(from: url)

            if let folderType = folderType {
                // It's a standard folder - save bookmark via the existing system
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    try SecureBookmarkStore.saveBookmark(bookmarkData, forKey: folderType.bookmarkKey)
                    folderService.refresh()

                    // Auto-select the newly added folder
                    nav.select(.from(folderType: folderType))

                    // Rescan to include new folder
                    await dashboardViewModel.scanFiles(context: modelContext)

                    Log.info("SidebarView: Added location '\(folderType.displayName)'", category: .filesystem)
                } catch {
                    Log.error("SidebarView: Failed to save bookmark - \(error.localizedDescription)", category: .filesystem)
                    dashboardViewModel.errorMessage = "Failed to add location: \(error.localizedDescription)"
                }
            } else {
                // Not a standard folder - show error for now
                // (Future: could support arbitrary custom folders)
                dashboardViewModel.errorMessage = "Please select a standard folder (Desktop, Downloads, Documents, Pictures, or Music)"
            }
        }
    }

    /// Determines the BookmarkFolder.FolderType based on the folder path
    private func determineFolderType(from url: URL) -> BookmarkFolder.FolderType? {
        let path = url.path.lowercased()

        if path.hasSuffix("/desktop") { return .desktop }
        if path.hasSuffix("/downloads") { return .downloads }
        if path.hasSuffix("/documents") { return .documents }
        if path.hasSuffix("/pictures") { return .pictures }
        if path.hasSuffix("/music") { return .music }

        return nil
    }

    private func removeFolder(_ folder: BookmarkFolder) {
        let folderName = folder.displayName

        // Remove the bookmark from Keychain
        folderService.removeBookmark(for: folder.folderType)

        // If we were viewing this folder, navigate away
        if isFolderSelected(folder) {
            if let firstRemaining = folderService.availableFolders.first {
                nav.select(.from(folderType: firstRemaining.folderType))
            } else {
                nav.select(.rules) // Fallback to rules if no locations remain
            }
        }

        Log.info("SidebarView: Removed location '\(folderName)'", category: .filesystem)
    }
}
