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

    /// Available folders from BookmarkFolderService (for UI display)
    var availableFolders: [BookmarkFolder] {
        BookmarkFolderService.shared.availableFolders
    }

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

        // Build list of accessible folders from BookmarkFolderService
        let accessibleFolders = BookmarkFolderService.shared.enabledFolderLocations

        // Use shared pipeline to scan all accessible folders
        let result = await fileScanPipeline.scanAndPersist(
            baseFolders: accessibleFolders,
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

    // MARK: - Private Helpers

    /// Update recent files (last 8 by modification date)
    private func updateRecentFiles() {
        recentFiles = allFiles
            .sorted { $0.modificationDate > $1.modificationDate }
            .prefix(8)
            .map { $0 }
    }
}
