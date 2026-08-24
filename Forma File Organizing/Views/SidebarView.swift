import AppKit
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

    private let sidebarControlHitHeight: CGFloat = 40

    @ObservedObject private var folderService = BookmarkFolderService.shared
    @State private var isAddingFolder = false
    @State private var isSettingsHovered = false
    @State private var isHelpHovered = false
    @State private var expandedNestedFolders: Set<BookmarkFolder.FolderType> = []
    @SceneStorage("sidebarExpandedNestedFolders") private var expandedNestedFoldersStorage = ""
    @AppStorage(ScanOptionsResolver.scanSubfoldersKey) private var scanSubfolders = false

    private var shouldUseModalRuleEditor: Bool {
        dashboardViewModel.workspaceDestination != .home
    }

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
                }
                .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)
            }

            // MARK: - Actions Section
            Color.formaSeparator
                .frame(height: 0.5)
                .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)

            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                sectionHeader("ACTIONS")

                SidebarActionRow(title: "New Rule", icon: "plus", accessibilityIdentifier: "sidebarAction_newRule") {
                    openNewRule()
                }
                .help("Create a new organization rule (R)")
                .guidedTourRegion(.newRuleButton)

                SidebarActionRow(title: "Add Folder", icon: "folder.badge.plus", accessibilityIdentifier: "sidebarAction_addFolder") {
                    addNewLocation()
                }
                .disabled(isAddingFolder)
                .help("Add a new location")

                // Smart Rules — opens right panel in rules list mode
                SidebarActionRow(title: "Smart Rules", icon: "list.bullet.rectangle", accessibilityIdentifier: "sidebarAction_smartRules") {
                    dashboardViewModel.showRulesWorkspace()
                }
                .help("View and manage organization rules")

                // Analytics — opens right panel in analytics mode
                if services.featureFlags.isEnabled(.analyticsAndInsights) {
                    SidebarActionRow(title: "Analytics", icon: "chart.bar", accessibilityIdentifier: "sidebarAction_analytics") {
                        dashboardViewModel.showAnalyticsWorkspace()
                    }
                    .help("View activity and insights")
                }
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
                            .font(.formaBodyMedium)

                        Text("Settings")
                            .font(.formaBodyMedium)
                    }
                    .foregroundColor(isSettingsHovered ? .formaLabel : .formaSecondaryLabelHigh)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: sidebarControlHitHeight)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
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
                        .frame(width: sidebarControlHitHeight, height: sidebarControlHitHeight)
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
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
            SidebarGlassOverlay()
                .ignoresSafeArea(edges: .top)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboardSidebar")
        .onAppear {
            restoreExpandedNestedFolders()

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
        .onChange(of: expandedNestedFolders) { _, newValue in
            persistExpandedNestedFolders(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            folderService.refresh()
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

    private func openNewRule() {
        if shouldUseModalRuleEditor {
            withAnimation(.easeInOut(duration: 0.2)) {
                nav.openRuleEditor(returnTarget: .none)
            }
        } else {
            nav.openRuleBuilderPanel(returnTarget: .defaultPanel)
            dashboardViewModel.showRuleBuilderPanel()
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

    private func restoreExpandedNestedFolders() {
        expandedNestedFolders = Set(
            expandedNestedFoldersStorage
                .split(separator: ",")
                .compactMap { BookmarkFolder.FolderType(rawValue: String($0)) }
        )
    }

    private func persistExpandedNestedFolders(_ folders: Set<BookmarkFolder.FolderType>) {
        expandedNestedFoldersStorage = folders
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
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
        let isSelected = nav.selection == selection

        LockedFolderSidebarRow(
            title: folder.displayName,
            icon: folder.iconName,
            isSelected: isSelected,
            accessibilityIdentifier: "sidebarRequestAccess_\(folder.folderType.rawValue)",
            accessibilityValue: "\(folder.displayName), Access required"
        ) {
            nav.select(selection)
        }
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityIdentifier("sidebarLockedFolder_\(folder.folderType.rawValue)")
                .accessibilityLabel("\(folder.displayName), Access required")
                .accessibilityValue("Access required")
        }
        .help("Select \(folder.displayName) to open the macOS access flow.")
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
                            .font(.formaCaptionSemibold)
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
        let actionableCount = fileCount(for: folder)
        let readyCount = readyFileCount(for: folder)

        SidebarNativeRow(
            title: folder.displayName,
            icon: folder.iconName,
            isSelected: isSelected,
            badgeCount: actionableCount,
            readyCount: readyCount,
            accessibilityIdentifier: "sidebarFolder_\(folder.folderType.rawValue)"
        ) {
            expandedNestedFolders.insert(folder.folderType)
            nav.select(selection)
        }
        .help(readyCount > 0
            ? "\(readyCount) ready to organize in \(folder.displayName)."
            : "Show files from \(folder.displayName).")
        .accessibilityValue(sidebarFolderAccessibilityValue(actionableCount: actionableCount, readyCount: readyCount))
        .accessibilityHint("Show files from \(folder.displayName).")
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

    private func readyFileCount(for folder: BookmarkFolder) -> Int {
        dashboardViewModel.allFiles.filter { file in
            fileBelongs(to: folder.folderType, file: file)
                && file.status == .ready
                && file.destination != nil
                && normalizedRelativePath(file.relativeParentPath) == nil
        }.count
    }

    private func sidebarFolderAccessibilityValue(actionableCount: Int, readyCount: Int) -> String {
        switch (actionableCount, readyCount) {
        case (0, _):
            return "No actionable files"
        case (_, 0):
            return actionableCount == 1 ? "1 actionable file" : "\(actionableCount) actionable files"
        default:
            let actionableText = actionableCount == 1 ? "1 actionable file" : "\(actionableCount) actionable files"
            let readyText = readyCount == 1 ? "1 ready to organize" : "\(readyCount) ready to organize"
            return "\(actionableText), \(readyText)"
        }
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
        BookmarkFolder.FolderType.inferredFromRootPath(url.standardizedFileURL.path)
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
                nav.select(.home) // Fallback to home if no locations remain
            }
        }

        Log.info("SidebarView: Removed location '\(folderName)'", category: .filesystem)
    }

    private var footerHoverFill: Color {
        Color.formaControlBackground.opacity(colorScheme == .dark ? 0.65 : 0.9)
    }
}

private struct LockedFolderSidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let accessibilityValue: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private let rowRadius: CGFloat = FormaRadius.small

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: icon)
                    .font(.formaBodyMedium)
                    .foregroundColor(iconColor)
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(isSelected ? .formaBodyMedium : .formaBody)
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Access")
                        .font(.formaCaptionSemibold)
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? Color.formaSteelBlue : Color.formaSecondaryLabelHigh)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill((isSelected ? Color.formaSteelBlue : Color.formaSecondaryLabelHigh)
                            .opacity(Color.FormaOpacity.light))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            (isSelected ? Color.formaSteelBlue : Color.formaSecondaryLabelHigh)
                                .opacity(Color.FormaOpacity.medium),
                            lineWidth: 0.75
                        )
                )
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .strokeBorder(selectedBorder, lineWidth: isSelected ? FormaBorderWidth.hairline : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel("Request Access")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Select \(title) to open the permission recovery view.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(FormaEasing.microFeedback, value: isHovered)
    }

    private var iconColor: Color {
        isSelected ? .formaSteelBlue : foregroundColor
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

private struct SidebarNativeRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var badgeCount: Int? = nil
    var readyCount: Int? = nil
    var trailingIcon: String? = nil
    var trailingAccessoryLabel: String? = nil
    var trailingAccessorySystemImage: String? = nil
    var accessibilityIdentifier: String? = nil
    var trailingAccessoryIdentifier: String? = nil
    var accessibilityLabel: String? = nil
    var accessibilityValue: String? = nil
    var accessibilityHint: String? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private let rowRadius: CGFloat = FormaRadius.small

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: icon)
                    .font(.formaBodyMedium)
                    .foregroundColor(iconColor)
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(isSelected ? .formaBodyMedium : .formaBody)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let trailingAccessoryLabel {
                    HStack(spacing: 4) {
                        if let trailingAccessorySystemImage {
                            Image(systemName: trailingAccessorySystemImage)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        Text(trailingAccessoryLabel)
                            .font(.formaCaptionSemibold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(
                        isSelected
                            ? Color.formaSteelBlue
                            : Color.formaSecondaryLabelHigh
                    )
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                (isSelected ? Color.formaSteelBlue : Color.formaSecondaryLabelHigh)
                                    .opacity(Color.FormaOpacity.light)
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                (isSelected ? Color.formaSteelBlue : Color.formaSecondaryLabelHigh)
                                    .opacity(Color.FormaOpacity.medium),
                                lineWidth: 0.75
                            )
                    )
                    .accessibilityIdentifier(trailingAccessoryIdentifier ?? "")
                } else if let trailing = trailingIcon {
                    Image(systemName: trailing)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.formaTertiaryLabel)
                } else if let readyCount, readyCount > 0 {
                    FormaBadge(
                        text: "\(readyCount)",
                        color: .formaSteelBlue,
                        icon: "checkmark",
                        size: .small,
                        style: .subtle
                    )
                    .help(readyCount == 1 ? "1 ready to organize" : "\(readyCount) ready to organize")

                    if let count = badgeCount, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.formaSecondaryLabelHigh)
                    }
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
            .frame(minHeight: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
                    .strokeBorder(selectedBorder, lineWidth: isSelected ? FormaBorderWidth.hairline : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(FormaEasing.microFeedback, value: isHovered)
        .if(accessibilityIdentifier != nil) { row in
            row.accessibilityIdentifier(accessibilityIdentifier!)
        }
        .accessibilityElement(children: accessibilityLabel != nil ? .ignore : .combine)
        .if(accessibilityLabel != nil) { row in
            row.accessibilityLabel(accessibilityLabel!)
        }
        .if(accessibilityValue != nil) { row in
            row.accessibilityValue(accessibilityValue!)
        }
        .if(accessibilityHint != nil) { row in
            row.accessibilityHint(accessibilityHint!)
        }
        .if(accessibilityLabel == nil) { row in
            row.accessibilityChildren {
                if let trailingAccessoryLabel,
                   let trailingAccessoryIdentifier {
                    Text(trailingAccessoryLabel)
                        .accessibilityIdentifier(trailingAccessoryIdentifier)
                }
            }
        }
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
    let accessibilityIdentifier: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: icon)
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(.formaBody)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundColor(isHovered ? .formaLabel : .formaSecondaryLabelHigh)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(isHovered
                        ? Color.formaControlBackground.opacity(colorScheme == .dark ? 0.65 : 0.9)
                        : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(title)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
