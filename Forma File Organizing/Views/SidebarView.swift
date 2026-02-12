import SwiftUI
import SwiftData

struct SidebarView: View {
    @EnvironmentObject var nav: NavigationViewModel
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var services: AppServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Binding var shouldFocusSearch: Bool
    @Binding var showKeyboardHelp: Bool

    @ObservedObject private var folderService = BookmarkFolderService.shared
    @State private var isAddingFolder = false
    @State private var isSettingsHovered = false
    @State private var isHelpHovered = false
    @State private var expandedNestedFolders: Set<BookmarkFolder.FolderType> = []
    @AppStorage(ScanOptionsResolver.scanSubfoldersKey) private var scanSubfolders = false

    var body: some View {
        // Sidebar content
        VStack(alignment: .leading, spacing: 0) {
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
                    // Locations - all 5 standard folders, lock icon if no access
                    VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                        sectionHeader("LOCATIONS")

                        ForEach(BookmarkFolder.FolderType.allCases, id: \.self) { folderType in
                            let hasAccess = folderService.hasAccess(to: folderType)
                            let folder = BookmarkFolder(folderType: folderType)
                            if hasAccess {
                                bookmarkFolderSection(folder)
                            } else {
                                lockedFolderItem(folder)
                            }
                        }
                    }
                    .guidedTourRegion(.sidebarLocations)



                    // TOOLS SECTION (Grouped per user feedback)
                    sectionHeader("TOOLS")
                    
                    // Smart Rules
                    sidebarItem("Smart Rules", icon: "list.bullet.rectangle.fill", selection: .rules)

                    // Analytics (if enabled)
                    if services.featureFlags.isEnabled(.analyticsAndInsights) {
                        sidebarItem("Analytics", icon: "chart.pie.fill", selection: .analytics)
                    }
                }
                .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)
            }

            // MARK: - Actions Section
            Color.formaSeparator
                .frame(height: 0.5)
                .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)

            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                sectionHeader("ACTIONS")

                SidebarActionRow(title: "New Rule", icon: "plus") {
                    dashboardViewModel.showRuleBuilderPanel()
                }
                .help("Create a new organization rule (R)")
                .guidedTourRegion(.newRuleButton)

                SidebarActionRow(title: "Add Folder", icon: "folder.badge.plus") {
                    addNewLocation()
                }
                .disabled(isAddingFolder)
                .help("Add a new location")
            }
            .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)
            .padding(.bottom, FormaSpacing.tight)

            // MARK: - Settings Footer
            Color.formaSeparator
                .frame(height: 0.5)
                .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)

            HStack(spacing: FormaSpacing.tight) {
                SettingsLink {
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
        .background(
            PaneMaterialBackground(role: .sidebar)
                .ignoresSafeArea(edges: .top)
        )
        .onAppear {
            // Refresh folder service when sidebar appears to ensure locations are current
            folderService.refresh()
            if case .nestedFolder(let base, let relativePath, let includeSubfolders) = nav.selection {
                expandedNestedFolders.insert(base)
                if includeSubfolders != scanSubfolders {
                    nav.selection =
                        .nestedFolder(
                            base: base,
                            relativePath: relativePath,
                            includeSubfolders: scanSubfolders
                        )
                }
            }
        }
        .onChange(of: nav.selection) { _, newSelection in
            guard case .nestedFolder(let base, _, _) = newSelection else { return }
            expandedNestedFolders.insert(base)
        }
        .onChange(of: scanSubfolders) { _, includeSubfolders in
            guard case .nestedFolder(let base, let relativePath, _) = nav.selection else { return }
            nav.selection =
                .nestedFolder(
                    base: base,
                    relativePath: relativePath,
                    includeSubfolders: includeSubfolders
                )
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

    // MARK: - Locked Folder Item (JIT Permission)

    @ViewBuilder
    private func lockedFolderItem(_ folder: BookmarkFolder) -> some View {
        let selection = NavigationSelection.from(folderType: folder.folderType)

        SidebarNativeRow(
            title: folder.displayName,
            icon: folder.iconName,
            isSelected: false,
            trailingIcon: "lock.fill"
        ) {
            nav.select(selection)
        }
    }

    // MARK: - Bookmark Folder Item

    @ViewBuilder
    private func bookmarkFolderSection(_ folder: BookmarkFolder) -> some View {
        let nestedEntries = nestedFolderEntries(for: folder.folderType)
        let isExpanded = expandedNestedFolders.contains(folder.folderType)
        let showNestedControls = isFolderSelected(folder) && !nestedEntries.isEmpty

        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            bookmarkFolderItem(folder)

            if showNestedControls {
                Button {
                    if isExpanded {
                        expandedNestedFolders.remove(folder.folderType)
                    } else {
                        expandedNestedFolders.insert(folder.folderType)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.formaTertiaryLabel)
                        Text("Subfolders")
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaSecondaryLabel)
                        Text("\(nestedEntries.count)")
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaTertiaryLabel)
                    }
                    .padding(.leading, 26)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Subfolders for \(folder.displayName)")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Show nested folders discovered in this location.")
                .accessibilityIdentifier("sidebarSubfoldersDisclosure_\(folder.folderType.rawValue)")

                if isExpanded {
                    ForEach(nestedEntries) { entry in
                        let nestedSelection = NavigationSelection.nestedFolder(
                            base: folder.folderType,
                            relativePath: entry.relativePath,
                            includeSubfolders: scanSubfolders
                        )
                        SidebarNativeRow(
                            title: entry.displayName,
                            icon: "folder",
                            isSelected: nav.selection == nestedSelection,
                            badgeCount: entry.actionableCount > 0 ? entry.actionableCount : nil
                        ) {
                            nav.select(nestedSelection)
                        }
                        .padding(.leading, CGFloat(entry.depth + 1) * 14 + 10)
                        .help(entry.relativePath)
                        .accessibilityLabel("\(entry.displayName) folder")
                        .accessibilityValue(entry.actionableCount > 0 ? "\(entry.actionableCount) pending files" : "No pending files")
                        .accessibilityHint(scanSubfolders
                            ? "Filter files in this folder and subfolders."
                            : "Filter files only in this folder.")
                        .accessibilityIdentifier("sidebarNestedFolder_\(folder.folderType.rawValue)_\(entry.relativePath.replacingOccurrences(of: "/", with: "_"))")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bookmarkFolderItem(_ folder: BookmarkFolder) -> some View {
        let selection = NavigationSelection.from(folderType: folder.folderType)
        let isSelected = isFolderSelected(folder)

        SidebarNativeRow(
            title: folder.displayName,
            icon: folder.iconName,
            isSelected: isSelected,
            badgeCount: fileCount(for: folder)
        ) {
            expandedNestedFolders.insert(folder.folderType)
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

    /// Count of files in the given bookmark folder that need review
    private func fileCount(for folder: BookmarkFolder) -> Int {
        return dashboardViewModel.allFiles.filter { file in
            fileBelongs(to: folder.folderType, file: file)
                && (file.status == .pending || file.status == .ready)
                && normalizedRelativePath(file.relativeParentPath) == nil
        }.count
    }

    private struct NestedFolderEntry: Identifiable {
        let relativePath: String
        let displayName: String
        let depth: Int
        let actionableCount: Int

        var id: String { relativePath }
    }

    private func nestedFolderEntries(for folderType: BookmarkFolder.FolderType) -> [NestedFolderEntry] {
        let filesInFolder = dashboardViewModel.allFiles.filter { fileBelongs(to: folderType, file: $0) }
        guard !filesInFolder.isEmpty else { return [] }

        var allPrefixPaths: Set<String> = []
        var actionableByExactPath: [String: Int] = [:]

        for file in filesInFolder {
            guard let relativeParent = normalizedRelativePath(file.relativeParentPath),
                  !relativeParent.isEmpty else {
                continue
            }

            let components = relativeParent.split(separator: "/").map(String.init)
            var runningPath = ""
            for component in components {
                runningPath = runningPath.isEmpty ? component : "\(runningPath)/\(component)"
                allPrefixPaths.insert(runningPath)
            }

            if file.status == .pending || file.status == .ready {
                actionableByExactPath[relativeParent, default: 0] += 1
            }
        }

        let sortedPaths = allPrefixPaths.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return sortedPaths.map { path in
            let depth = max(0, path.split(separator: "/").count - 1)
            let displayName = path.split(separator: "/").last.map(String.init) ?? path
            let actionableCount = actionableByExactPath[path, default: 0]

            return NestedFolderEntry(
                relativePath: path,
                displayName: displayName,
                depth: depth,
                actionableCount: actionableCount
            )
        }
    }

    private func normalizedRelativePath(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    private func fileBelongs(to folderType: BookmarkFolder.FolderType, file: FileItem) -> Bool {
        if file.location == fileLocationKind(for: folderType) {
            return true
        }
        return file.path.contains("/\(folderType.displayName)/")
    }

    private func fileLocationKind(for folderType: BookmarkFolder.FolderType) -> FileLocationKind {
        switch folderType {
        case .desktop:
            return .desktop
        case .downloads:
            return .downloads
        case .documents:
            return .documents
        case .pictures:
            return .pictures
        case .music:
            return .music
        }
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
            panel.level = .modalPanel

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
        expandedNestedFolders.remove(folder.folderType)

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
}

private struct SidebarNativeRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var badgeCount: Int? = nil
    var trailingIcon: String? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private let rowRadius: CGFloat = 7

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let trailing = trailingIcon {
                    Image(systemName: trailing)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.formaTertiaryLabel)
                } else if let count = badgeCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.formaSecondaryLabelHigh)
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .strokeBorder(selectedBorder, lineWidth: isSelected ? 0.5 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var iconColor: Color {
        if isSelected {
            return .formaSteelBlue
        }
        return foregroundColor
    }

    private var foregroundColor: Color {
        if isSelected || isHovered {
            return .formaLabel
        }
        return .formaSecondaryLabelHigh
    }

    private var backgroundFill: Color {
        if isSelected {
            return Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.22 : 0.14)
        }
        if isHovered {
            return Color.formaControlBackground.opacity(colorScheme == .dark ? 0.55 : 0.8)
        }
        return .clear
    }

    private var selectedBorder: Color {
        if isSelected {
            return Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.35 : 0.2)
        }
        return .clear
    }
}

/// Action row for the sidebar ACTIONS section.
/// Visually distinct from navigation rows: uses secondary label color for icons
/// and lighter text weight to read as "do something" rather than "go somewhere".
private struct SidebarActionRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundColor(isHovered ? .formaLabel : .formaSecondaryLabelHigh)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered
                        ? Color.formaControlBackground.opacity(colorScheme == .dark ? 0.65 : 0.9)
                        : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
