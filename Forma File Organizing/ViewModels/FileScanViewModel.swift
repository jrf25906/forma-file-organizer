import Foundation
import SwiftUI
import SwiftData
import Combine

/// Manages file scanning, discovery, and real-time updates.
/// Responsible for:
/// - Desktop/Downloads/Custom folder scanning
/// - Real-time file system monitoring
/// - Scan progress and state
/// - Custom folder management
@MainActor
class FileScanViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All discovered files from scanning
    @Published private(set) var allFiles: [FileItem] = []

    /// Recent files (last 8)
    @Published private(set) var recentFiles: [FileItem] = []

    /// Whether a scan is currently in progress
    @Published private(set) var isScanning = false

    /// Scan progress (0.0 to 1.0)
    @Published private(set) var scanProgress: Double = 0.0

    /// Custom folders to scan (beyond Desktop/Downloads)
    @Published private(set) var customFolders: [CustomFolder] = []

    /// Error message from scanning
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let fileSystemService: FileSystemServiceProtocol
    private let fileScanPipeline: FileScanPipelineProtocol
    private let ruleEngine: RuleEngine

    // MARK: - Private State

    private var rules: [Rule] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        fileSystemService: FileSystemServiceProtocol,
        fileScanPipeline: FileScanPipelineProtocol,
        ruleEngine: RuleEngine = RuleEngine()
    ) {
        self.fileSystemService = fileSystemService
        self.fileScanPipeline = fileScanPipeline
        self.ruleEngine = ruleEngine
    }

    convenience init() {
        self.init(
            fileSystemService: FileSystemService(),
            fileScanPipeline: FileScanPipeline()
        )
    }

    // MARK: - Public Interface

    /// Scan files from all configured folders
    func scanFiles(context: ModelContext, rules: [Rule]) async {
        let scanId = PerformanceMonitor.shared.begin(.fileScan, metadata: "Starting file scan")

        isScanning = true
        scanProgress = 0.0
        errorMessage = nil
        self.rules = rules

        // Load custom folders first
        loadCustomFolders(from: context)

        // Build list of accessible folders
        var accessibleFolders: [FolderLocation] = []
        if fileSystemService.hasDesktopAccess() { accessibleFolders.append(.desktop) }
        if fileSystemService.hasDownloadsAccess() { accessibleFolders.append(.downloads) }
        if fileSystemService.hasDocumentsAccess() { accessibleFolders.append(.documents) }
        if fileSystemService.hasPicturesAccess() { accessibleFolders.append(.pictures) }
        if fileSystemService.hasMusicAccess() { accessibleFolders.append(.music) }

        // Use shared pipeline to scan all accessible folders + custom folders
        let result = await fileScanPipeline.scanAndPersist(
            baseFolders: accessibleFolders,
            customFolders: customFolders,
            fileSystemService: fileSystemService,
            ruleEngine: ruleEngine,
            rules: self.rules,
            context: context
        )

        if let summary = result.errorSummary {
            errorMessage = summary
        }

        // Update state
        allFiles = result.files
        updateRecentFiles()

        isScanning = false
        scanProgress = 1.0

        PerformanceMonitor.shared.end(.fileScan, id: scanId, metadata: "\(result.files.count) files")
    }

    /// Refresh file scan
    func refresh(context: ModelContext, rules: [Rule]) async {
        await scanFiles(context: context, rules: rules)
    }

    /// Update a file's metadata (called after organization)
    func updateFile(_ file: FileItem) {
        if let index = allFiles.firstIndex(where: { $0.path == file.path }) {
            allFiles[index] = file
            updateRecentFiles()
        }
    }

    /// Remove a file from the list (called after successful organization)
    func removeFile(at path: String) {
        allFiles.removeAll { $0.path == path }
        updateRecentFiles()
    }

    #if DEBUG
    /// Test helper to set allFiles directly (bypasses scanning)
    func _testSetFiles(_ files: [FileItem]) {
        allFiles = files
        updateRecentFiles()
    }
    #endif

    // MARK: - Custom Folders

    /// Load custom folders from SwiftData
    func loadCustomFolders(from context: ModelContext) {
        let descriptor = FetchDescriptor<CustomFolder>(
            sortBy: [SortDescriptor(\.creationDate, order: .forward)]
        )

        do {
            var fetchedFolders = try context.fetch(descriptor)

            // Migration: If no CustomFolders exist but we have bookmarks, create them
            if fetchedFolders.isEmpty {
                let migratedFolders = migrateBookmarksToCustomFolders(context: context)
                if !migratedFolders.isEmpty {
                    fetchedFolders = migratedFolders
                    Log.info("FileScanViewModel: Migrated \(migratedFolders.count) bookmarks to CustomFolders", category: .pipeline)
                }
            }

            // Filter enabled folders and deduplicate by path
            let enabledFolders = fetchedFolders.filter { $0.isEnabled }
            var seenPaths = Set<String>()
            let uniqueFolders = enabledFolders.filter { folder in
                let normalizedPath = folder.path.lowercased()
                if seenPaths.contains(normalizedPath) {
                    Log.warning("FileScanViewModel: Skipping duplicate folder at path '\(folder.path)'", category: .pipeline)
                    return false
                }
                seenPaths.insert(normalizedPath)
                return true
            }

            // Apply semantic sort: system folders first, then custom folders
            customFolders = uniqueFolders.sorted { folder1, folder2 in
                let priority1 = folderSortPriority(for: folder1.path)
                let priority2 = folderSortPriority(for: folder2.path)

                if priority1 != priority2 {
                    return priority1 < priority2
                }

                return folder1.name.localizedStandardCompare(folder2.name) == .orderedAscending
            }

            Log.info("Successfully loaded \(customFolders.count) enabled custom folders", category: .pipeline)
        } catch {
            Log.error("Failed to load custom folders: \(error.localizedDescription)", category: .pipeline)
            errorMessage = "Failed to load custom folders. Some locations may not be available."
            customFolders = []
        }
    }

    // MARK: - Private Helpers

    /// Update recent files (last 8 by modification date)
    private func updateRecentFiles() {
        recentFiles = allFiles
            .sorted { $0.modificationDate > $1.modificationDate }
            .prefix(8)
            .map { $0 }
    }

    /// Returns sort priority for a folder path (system folders = 1-6, custom = 100)
    private func folderSortPriority(for path: String) -> Int {
        let lowercasedPath = path.lowercased()

        if lowercasedPath.hasSuffix("/desktop") { return 1 }
        if lowercasedPath.hasSuffix("/downloads") { return 2 }
        if lowercasedPath.hasSuffix("/documents") { return 3 }
        if lowercasedPath.hasSuffix("/pictures") { return 4 }
        if lowercasedPath.hasSuffix("/music") { return 5 }
        if lowercasedPath.hasSuffix("/movies") { return 6 }

        return 100 // Custom folders
    }

    /// Migrate existing bookmarks to CustomFolder entries (one-time migration)
    private func migrateBookmarksToCustomFolders(context: ModelContext) -> [CustomFolder] {
        var createdFolders: [CustomFolder] = []

        let standardFolders: [(String, String, String)] = {
            let home = realHomeDirectory().path
            return [
                ("Desktop", FormaConfig.Security.desktopBookmarkKey, "\(home)/Desktop"),
                ("Downloads", FormaConfig.Security.downloadsBookmarkKey, "\(home)/Downloads"),
                ("Documents", FormaConfig.Security.documentsBookmarkKey, "\(home)/Documents"),
                ("Pictures", FormaConfig.Security.picturesBookmarkKey, "\(home)/Pictures"),
                ("Music", FormaConfig.Security.musicBookmarkKey, "\(home)/Music")
            ]
        }()

        for (name, bookmarkKey, path) in standardFolders {
            guard let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) else {
                continue
            }

            do {
                let customFolder = try CustomFolder(
                    name: name,
                    path: path,
                    bookmarkData: bookmarkData
                )
                context.insert(customFolder)
                createdFolders.append(customFolder)
                Log.info("FileScanViewModel: Created CustomFolder for \(name) from existing bookmark", category: .pipeline)
            } catch {
                Log.error("FileScanViewModel: Failed to create CustomFolder for \(name) - \(error.localizedDescription)", category: .pipeline)
            }
        }

        if !createdFolders.isEmpty {
            do {
                try context.save()
                Log.info("FileScanViewModel: Saved \(createdFolders.count) migrated CustomFolders", category: .pipeline)
            } catch {
                Log.error("FileScanViewModel: Failed to save migrated CustomFolders - \(error.localizedDescription)", category: .pipeline)
            }
        }

        return createdFolders
    }
}

// MARK: - Helper Functions

/// Returns the user's real home directory (not sandbox container)
private func realHomeDirectory() -> URL {
    if let pw = getpwuid(getuid()) {
        let homeDir = String(cString: pw.pointee.pw_dir)
        return URL(fileURLWithPath: homeDir)
    }
    return FileManager.default.homeDirectoryForCurrentUser
}
