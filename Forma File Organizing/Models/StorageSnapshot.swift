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
    /// Difference in bytes from the previous snapshot (negative indicates cleanup).
    var deltaBytesSincePrevious: Int64?

    init(
        id: UUID = UUID(),
        date: Date,
        totalBytes: Int64,
        fileCount: Int,
        categoryBreakdownData: Data,
        deltaBytesSincePrevious: Int64? = nil
    ) {
        self.id = id
        self.date = date
        self.totalBytes = totalBytes
        self.fileCount = fileCount
        self.categoryBreakdownData = categoryBreakdownData
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
