import Foundation

struct StorageAnalytics {
    let totalBytes: Int64
    let categoryBreakdown: [FileTypeCategory: Int64]
    let fileCount: Int
    let categoryFileCounts: [FileTypeCategory: Int]

    var totalSize: String {
        formatBytes(totalBytes)
    }

    func sizeForCategory(_ category: FileTypeCategory) -> Int64 {
        categoryBreakdown[category] ?? 0
    }

    func formattedSizeForCategory(_ category: FileTypeCategory) -> String {
        formatBytes(sizeForCategory(category))
    }

    func percentageForCategory(_ category: FileTypeCategory) -> Double {
        guard totalBytes > 0 else { return 0 }
        let categoryBytes = Double(sizeForCategory(category))
        let total = Double(totalBytes)
        return (categoryBytes / total) * 100
    }

    func fileCountForCategory(_ category: FileTypeCategory) -> Int {
        categoryFileCounts[category] ?? 0
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static var empty: StorageAnalytics {
        StorageAnalytics(
            totalBytes: 0,
            categoryBreakdown: [:],
            fileCount: 0,
            categoryFileCounts: [:]
        )
    }
}

extension StorageAnalytics {
    static func calculate(from files: [FileItem]) -> StorageAnalytics {
        var categoryBreakdown: [FileTypeCategory: Int64] = [:]
        var categoryFileCounts: [FileTypeCategory: Int] = [:]
        var totalBytes: Int64 = 0

        for file in files {
            let category = file.category
            totalBytes += file.sizeInBytes

            // Update size breakdown
            categoryBreakdown[category, default: 0] += file.sizeInBytes

            // Update file count
            categoryFileCounts[category, default: 0] += 1
        }

        return StorageAnalytics(
            totalBytes: totalBytes,
            categoryBreakdown: categoryBreakdown,
            fileCount: files.count,
            categoryFileCounts: categoryFileCounts
        )
    }
}

extension StorageAnalytics {
    init(snapshot: StorageSnapshot, categoryBreakdown: StorageCategoryBreakdown) {
        let mappedBreakdown: [FileTypeCategory: Int64] = categoryBreakdown.bytesByCategory.reduce(into: [:]) { result, element in
            if let category = FileTypeCategory(rawValue: element.key) {
                result[category] = element.value
            }
        }

        self.init(
            totalBytes: snapshot.totalBytes,
            categoryBreakdown: mappedBreakdown,
            fileCount: snapshot.fileCount,
            categoryFileCounts: [:]
        )
    }

    func encodedCategoryBreakdown() throws -> Data {
        let stringKeyed = Dictionary(uniqueKeysWithValues: categoryBreakdown.map { ($0.key.rawValue, $0.value) })
        return try JSONEncoder().encode(stringKeyed)
    }
}
