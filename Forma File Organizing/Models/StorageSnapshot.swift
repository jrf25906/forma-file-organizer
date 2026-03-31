import Foundation
import SwiftData

/// Persisted snapshot of storage state for trend analysis.
@Model
final class StorageSnapshot {
    #Index<StorageSnapshot>([\.date])

    @Attribute(.unique) var id: UUID
    var date: Date
    var totalBytes: Int64
    var fileCount: Int
    /// JSON-encoded category → bytes map (FileTypeCategory.rawValue keys).
    var categoryBreakdownData: Data
    /// Defaults to empty data so legacy stores can lightweight-migrate rows created
    /// before folder-level analytics were introduced.
    var folderBreakdownData: Data = Data()
    /// Difference in bytes from the previous snapshot (negative indicates cleanup).
    var deltaBytesSincePrevious: Int64?

    init(
        id: UUID = UUID(),
        date: Date,
        totalBytes: Int64,
        fileCount: Int,
        categoryBreakdownData: Data,
        folderBreakdownData: Data = Data(),
        deltaBytesSincePrevious: Int64? = nil
    ) {
        self.id = id
        self.date = date
        self.totalBytes = totalBytes
        self.fileCount = fileCount
        self.categoryBreakdownData = categoryBreakdownData
        self.folderBreakdownData = folderBreakdownData
        self.deltaBytesSincePrevious = deltaBytesSincePrevious
    }

    /// Decoded category breakdown with type safety.
    var categoryBreakdown: [String: Int64] {
        (try? JSONDecoder().decode([String: Int64].self, from: categoryBreakdownData)) ?? [:]
    }

    /// Bytes for a given category.
    func bytes(for category: FileTypeCategory) -> Int64 {
        categoryBreakdown[category.rawValue] ?? 0
    }

    /// Decoded folder breakdown with type safety.
    var folderBreakdown: [BookmarkFolder.FolderType: Int64] {
        guard let decoded = try? StorageFolderBreakdown(from: folderBreakdownData) else {
            return [:]
        }

        return decoded.bytesByFolder.reduce(into: [:]) { result, element in
            guard let folderType = BookmarkFolder.FolderType(rawValue: element.key) else { return }
            result[folderType] = element.value
        }
    }

    /// Bytes for a given monitored folder type.
    func bytes(for folderType: BookmarkFolder.FolderType) -> Int64 {
        folderBreakdown[folderType] ?? 0
    }
}

/// Value-type helper for encoding/decoding category breakdowns.
struct StorageCategoryBreakdown: Sendable {
    var bytesByCategory: [String: Int64]

    init(bytesByCategory: [String: Int64] = [:]) {
        self.bytesByCategory = bytesByCategory
    }

    init(from data: Data) throws {
        self.bytesByCategory = try JSONDecoder().decode([String: Int64].self, from: data)
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(bytesByCategory)
    }
}

struct StorageFolderBreakdown: Sendable {
    var bytesByFolder: [String: Int64]

    init(bytesByFolder: [String: Int64] = [:]) {
        self.bytesByFolder = bytesByFolder
    }

    init(from data: Data) throws {
        guard !data.isEmpty else {
            self.bytesByFolder = [:]
            return
        }

        self.bytesByFolder = try JSONDecoder().decode([String: Int64].self, from: data)
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(bytesByFolder)
    }
}
