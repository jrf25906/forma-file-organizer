import Foundation

/// Service for calculating and caching storage analytics
struct StorageService: Sendable {
    static let shared = StorageService()

    private init() {}

    /// Calculate storage analytics from a list of files
    func calculateAnalytics(from files: [FileItem]) -> StorageAnalytics {
        StorageAnalytics.calculate(from: files)
    }

    /// Get analytics for the current set of files.
    ///
    /// Note: This previously cached results, but caching required shared mutable state which
    /// is incompatible with Swift 6's strict concurrency rules. If caching becomes necessary,
    /// introduce an `actor`-backed cache rather than global shared mutable state.
    func getAnalytics(from files: [FileItem], forceRefresh: Bool = false) -> StorageAnalytics {
        _ = forceRefresh
        return calculateAnalytics(from: files)
    }

    /// Invalidate the cache
    func invalidateCache() {
    }

    /// Filter files by category
    func filterFiles(_ files: [FileItem], by category: FileTypeCategory) -> [FileItem] {
        if category == .all {
            return files
        }
        return files.filter { $0.category == category }
    }

    /// Get recent files (sorted by creation date, most recent first)
    func getRecentFiles(_ files: [FileItem], limit: Int = 10) -> [FileItem] {
        return Array(files.sorted { $0.creationDate > $1.creationDate }.prefix(limit))
    }

    /// Group files by category
    func groupByCategory(_ files: [FileItem]) -> [FileTypeCategory: [FileItem]] {
        var grouped: [FileTypeCategory: [FileItem]] = [:]

        for file in files {
            grouped[file.category, default: []].append(file)
        }

        return grouped
    }

    /// Aggregate bytes by current monitored folder membership for alerting and snapshots.
    func calculateFolderBreakdown(
        from files: [FileItem],
        monitoredRootPathsByFolder: [BookmarkFolder.FolderType: String] = BookmarkFolder.alertEligibleRootPaths()
    ) -> [BookmarkFolder.FolderType: Int64] {
        let monitoredRootPaths = monitoredRootPathsByFolder.map { ($0.key, $0.value) }
        .sorted { $0.1.count > $1.1.count }

        return files.reduce(into: [:]) { result, file in
            let filePath = URL(fileURLWithPath: file.path).standardizedFileURL.path
            guard let folderType = monitoredRootPaths.first(where: { isFilePath(filePath, withinRootPath: $0.1) })?.0 else {
                return
            }
            result[folderType, default: 0] += file.sizeInBytes
        }
    }

    private func isFilePath(_ filePath: String, withinRootPath rootPath: String) -> Bool {
        filePath == rootPath || filePath.hasPrefix(rootPath + "/")
    }
}
