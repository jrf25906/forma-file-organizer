import SwiftUI
import SwiftData

struct SidebarView: View {
    @EnvironmentObject var nav: NavigationViewModel
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var services: AppServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @Binding var shouldFocusSearch: Bool
    @Binding var showKeyboardHelp: Bool

    @ObservedObject private var folderService = BookmarkFolderService.shared
    @State private var isAddingFolder = false
    @State private var isKeyWindow = true
    @State private var isAddLocationHovered = false
    @State private var isSettingsHovered = false
    @State private var isHelpHovered = false

    var body: some View {
        // Sidebar content
        VStack(alignment: .leading, spacing: 0) {
            // Spacer to position content below traffic lights (Apple pattern)
            // Tuned to 52pt to keep search aligned under traffic-light chrome.
            Color.clear.frame(height: 52)

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
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isAddLocationHovered ? .formaLabel : .formaSecondaryLabelHigh)
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isAddLocationHovered ? footerHoverFill : Color.clear)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isAddingFolder)
                        .help("Add a new location")
                        .onHover { hovering in
                            isAddLocationHovered = hovering
                        }
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
                    SidebarNativeRow(
                        title: "New Rule",
                        icon: "plus",
                        isSelected: false
                    ) {
                        dashboardViewModel.showRuleBuilderPanel()
                    }
                    .help("Create a new organization rule (R)")
                }
                .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)
            }

            HStack(spacing: FormaSpacing.tight) {
                Button(action: { openSettings() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))

                        Text("Settings")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(isSettingsHovered ? .formaLabel : .formaSecondaryLabelHigh)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSettingsHovered ? footerHoverFill : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .help("Open Settings (⌘,)")
                .accessibilityIdentifier("sidebarSettingsButton")
                .onHover { hovering in
                    isSettingsHovered = hovering
                }

                Spacer(minLength: 0)

                Button(action: { showKeyboardHelp = true }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isHelpHovered ? .formaLabel : .formaSecondaryLabelHigh)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isHelpHovered ? footerHoverFill : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Keyboard Shortcuts (?)")
                .accessibilityIdentifier("sidebarKeyboardHelpButton")
                .onHover { hovering in
                    isHelpHovered = hovering
                }
            }
            .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)
            .padding(.vertical, FormaSpacing.tight)
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
            .strokeBorder(sidebarShellStroke, lineWidth: 0.85)
        }
        .shadow(color: sidebarShadowColor, radius: 14, x: 0, y: 2)
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
        SidebarNativeRow(
            title: title,
            icon: icon,
            isSelected: nav.selection == selection
        ) {
            nav.select(selection)
        }
    }

    // MARK: - Bookmark Folder Item

    @ViewBuilder
    private func bookmarkFolderItem(_ folder: BookmarkFolder) -> some View {
        let selection = NavigationSelection.from(folderType: folder.folderType)
        let isSelected = isFolderSelected(folder)

        SidebarNativeRow(
            title: folder.displayName,
            icon: folder.iconName,
            isSelected: isSelected
        ) {
            nav.select(selection)
        }
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
                    try BookmarkStoreProvider.shared.saveBookmark(bookmarkData, forKey: folderType.bookmarkKey)
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

    private var footerHoverFill: Color {
        Color.formaControlBackground.opacity(colorScheme == .dark ? 0.65 : 0.9)
    }

    private var sidebarShellStroke: LinearGradient {
        let topOpacity: Double = colorScheme == .dark
            ? (isKeyWindow ? 0.26 : 0.18)
            : (isKeyWindow ? 0.34 : 0.24)
        let bottomOpacity: Double = colorScheme == .dark
            ? (isKeyWindow ? 0.09 : 0.06)
            : (isKeyWindow ? 0.14 : 0.10)

        return LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(topOpacity),
                Color.formaBoneWhite.opacity(bottomOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var sidebarShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(isKeyWindow ? 0.32 : 0.2)
            : Color.black.opacity(isKeyWindow ? 0.14 : 0.09)
    }
}

private struct SidebarNativeRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var foregroundColor: Color {
        if isSelected || isHovered {
            return .formaLabel
        }
        return .formaSecondaryLabelHigh
    }

    private var backgroundFill: Color {
        if isSelected {
            return Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.28 : 0.2)
        }
        if isHovered {
            return Color.formaControlBackground.opacity(colorScheme == .dark ? 0.65 : 0.9)
        }
        return .clear
    }
}
