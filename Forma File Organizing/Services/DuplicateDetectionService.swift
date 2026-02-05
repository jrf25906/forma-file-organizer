import Foundation
import CryptoKit

// MARK: - Security-Scoped Bookmark Access

/// Bookmark keys for monitored source folders
private let sourceFolderBookmarks: [String: String] = [
    "Desktop": "DesktopFolderBookmark",
    "Downloads": "DownloadsFolderBookmark",
    "Documents": "DocumentsFolderBookmark",
    "Pictures": "PicturesFolderBookmark",
    "Music": "MusicFolderBookmark"
]

/// Service for detecting duplicate and near-duplicate files.
///
/// ## Detection Capabilities
/// - **Exact Duplicates**: Files with identical content (same hash)
/// - **Near Duplicates**: Files with similar names but different content
/// - **Version Series**: Related files that are versions of each other (file_v1, file_v2, etc.)
///
/// ## Usage
/// ```swift
/// let service = DuplicateDetectionService()
/// let groups = service.detectDuplicates(in: files)
/// for group in groups {
///     Log.info("Found \\(group.files.count) duplicates of type \\(group.type)", category: .analytics)
/// }
/// ```
///
class DuplicateDetectionService {

    // MARK: - Configuration

    /// Minimum file size to consider for duplicate detection (skip tiny files)
    private let minimumFileSize: Int64 = 1024 // 1KB

    /// Similarity threshold for near-duplicate detection (0.0-1.0)
    private let nameSimilarityThreshold: Double = 0.85

    /// Maximum number of files to compare for performance
    private let maxComparisonCount = 5000

    /// Chunk size for streaming hash reads (avoid loading entire files into memory).
    private static let hashChunkSize = 1_048_576 // 1 MB

    /// Keep hash cache bounded to avoid unbounded memory growth.
    private static let maxHashCacheEntries = 2_000

    private struct HashCacheEntry {
        let sizeInBytes: Int64
        let modificationDate: Date
        let hash: String
    }

    private struct NameComparableFile {
        let file: FileItem
        let baseName: String
        let length: Int
        let prefix: String
    }

    private static let versionStripRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"[\s_-]*v?\d+$"#, options: .caseInsensitive),                  // v1, _2, -3
        try! NSRegularExpression(pattern: #"[\s_-]*\(\d+\)$"#, options: .caseInsensitive),                // (1), (2)
        try! NSRegularExpression(pattern: #"[\s_-]*copy[\s_-]*\d*$"#, options: .caseInsensitive),         // copy, copy 2
        try! NSRegularExpression(pattern: #"[\s_-]*\d{4}[-_]\d{2}[-_]\d{2}$"#, options: .caseInsensitive), // 2024-01-01
        try! NSRegularExpression(pattern: #"[\s_-]*(draft|final|v\d+|rev\d*)$"#, options: .caseInsensitive) // draft/final/rev1
    ]

    private static let versionIndicatorRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"v\d+"#, options: .caseInsensitive),           // v1, v2, v10
        try! NSRegularExpression(pattern: #"\(\d+\)"#, options: .caseInsensitive),        // (1), (2)
        try! NSRegularExpression(pattern: #"_\d{1,2}$"#, options: .caseInsensitive),      // _1, _12
        try! NSRegularExpression(pattern: #"draft"#, options: .caseInsensitive),           // draft
        try! NSRegularExpression(pattern: #"final"#, options: .caseInsensitive),           // final
        try! NSRegularExpression(pattern: #"rev\d*"#, options: .caseInsensitive),          // rev, rev1
        try! NSRegularExpression(pattern: #"\d{4}[-_]\d{2}"#, options: .caseInsensitive)   // 2024-01, 2024_02
    ]

    private static let versionNumberRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"v(\d+)"#, options: .caseInsensitive),          // v1, v2
        try! NSRegularExpression(pattern: #"\((\d+)\)"#, options: .caseInsensitive),       // (1), (2)
        try! NSRegularExpression(pattern: #"_(\d+)\."#, options: .caseInsensitive),        // _1., _2.
        try! NSRegularExpression(pattern: #"rev(\d+)"#, options: .caseInsensitive)          // rev1, rev2
    ]

    /// Reuse content hashes across repeated scans while invalidating on file changes.
    private var hashCacheByPath: [String: HashCacheEntry] = [:]

    // MARK: - Security Scope Helpers

    /// Finds the bookmark key for a file's parent monitored folder
    private func findMonitoredFolderBookmarkKey(for path: String) -> String? {
        // Get real home directory (not sandboxed container path)
        let homeDir: String
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
            homeDir = String(cString: home)
        } else {
            homeDir = NSHomeDirectory()
        }

        for (folderName, bookmarkKey) in sourceFolderBookmarks {
            let folderPath = "\(homeDir)/\(folderName)"
            if path.hasPrefix(folderPath) {
                return bookmarkKey
            }
        }

        // Check for custom folder bookmarks
        let customFolderPrefix = "CustomFolder_"
        let keychainKeys = BookmarkStoreProvider.shared.listAllBookmarkKeys()
        for key in keychainKeys where key.hasPrefix(customFolderPrefix) {
            if let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: key) {
                var isStale = false
                if let url = try? URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ), path.hasPrefix(url.path) {
                    return key
                }
            }
        }

        return nil
    }

    /// Establishes security-scoped access for a file's parent monitored folder
    private func establishSecurityScope(for path: String) -> URL? {
        guard let bookmarkKey = findMonitoredFolderBookmarkKey(for: path) else {
            return nil
        }

        guard let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }

        return url
    }

    /// Releases security-scoped access for a folder URL
    private func releaseSecurityScope(for url: URL?) {
        url?.stopAccessingSecurityScopedResource()
    }

    // MARK: - Types

    /// Represents a group of duplicate or related files
    struct DuplicateGroup: Identifiable {
        let id: UUID
        let type: DuplicateType
        var files: [FileItem]

        /// Human-readable description of the duplicate group
        var description: String {
            switch type {
            case .exactDuplicate:
                return "\(files.count) identical copies"
            case .nearDuplicate:
                return "\(files.count) similar files"
            case .versionSeries:
                return "\(files.count) versions"
            }
        }

        /// Suggested action for this duplicate group
        var suggestedAction: SuggestedAction {
            switch type {
            case .exactDuplicate:
                return .keepNewest
            case .nearDuplicate:
                return .review
            case .versionSeries:
                return .keepLatestVersion
            }
        }

        /// Total size that could be recovered by removing duplicates
        var potentialSpaceSavings: Int64 {
            guard files.count > 1 else { return 0 }
            // Sum all but the largest file
            let sorted = files.sorted { $0.sizeInBytes > $1.sizeInBytes }
            return sorted.dropFirst().reduce(0) { $0 + $1.sizeInBytes }
        }

        enum SuggestedAction {
            case keepNewest
            case keepLatestVersion
            case review

            var displayName: String {
                switch self {
                case .keepNewest: return "Keep newest"
                case .keepLatestVersion: return "Keep latest version"
                case .review: return "Review"
                }
            }
        }
    }

    /// Type of duplicate relationship
    enum DuplicateType: String, Codable {
        case exactDuplicate     // Identical content (same hash)
        case nearDuplicate      // Similar names, different content
        case versionSeries      // file_v1.pdf, file_v2.pdf, etc.

        var iconName: String {
            switch self {
            case .exactDuplicate: return "doc.on.doc.fill"
            case .nearDuplicate: return "doc.badge.ellipsis"
            case .versionSeries: return "clock.arrow.circlepath"
            }
        }

        var priority: Int {
            switch self {
            case .exactDuplicate: return 3  // Highest priority
            case .versionSeries: return 2
            case .nearDuplicate: return 1
            }
        }
    }

    // MARK: - Main Detection Entry Point

    /// Detect all types of duplicates in a collection of files
    ///
    /// - Parameter files: Files to analyze for duplicates
    /// - Returns: Array of DuplicateGroup objects
    func detectDuplicates(in files: [FileItem]) -> [DuplicateGroup] {
        let dupId = PerformanceMonitor.shared.begin(.duplicateDetection, metadata: "\(files.count) files")

        // Filter out tiny files and limit for performance
        let relevantFiles = Array(
            files
                .lazy
                .filter { $0.sizeInBytes >= self.minimumFileSize }
                .prefix(self.maxComparisonCount)
        )

        var allGroups: [DuplicateGroup] = []

        // 1. Detect exact duplicates (by size first, then hash)
        let exactDuplicates = detectExactDuplicates(in: relevantFiles)
        allGroups.append(contentsOf: exactDuplicates)

        // 2. Detect version series
        let versionGroups = detectVersionSeries(in: relevantFiles)
        allGroups.append(contentsOf: versionGroups)

        // 3. Detect near duplicates (similar names)
        let nearDuplicates = detectNearDuplicates(in: relevantFiles)
        allGroups.append(contentsOf: nearDuplicates)

        // Remove overlapping groups (prefer more specific type)
        let deduplicated = deduplicateGroups(allGroups)

        // Sort by priority and potential savings
        let result = deduplicated.sorted { g1, g2 in
            if g1.type.priority != g2.type.priority {
                return g1.type.priority > g2.type.priority
            }
            return g1.potentialSpaceSavings > g2.potentialSpaceSavings
        }

        PerformanceMonitor.shared.end(.duplicateDetection, id: dupId, metadata: "\(result.count) groups found")
        return result
    }

    // MARK: - Exact Duplicate Detection

    /// Detect files with identical content using hash comparison
    ///
    /// Uses a two-phase approach for efficiency:
    /// 1. Group by file size (same size is necessary for identical content)
    /// 2. Compare hashes within size groups
    private func detectExactDuplicates(in files: [FileItem]) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []

        // Phase 1: Group by size
        let sizeGroups = Dictionary(grouping: files) { $0.sizeInBytes }
        groups.reserveCapacity(sizeGroups.count)

        for (_, sameSize) in sizeGroups where sameSize.count >= 2 {
            // Phase 2: Calculate hashes and group
            var hashGroups: [String: [FileItem]] = [:]
            hashGroups.reserveCapacity(sameSize.count)

            for file in sameSize {
                if let hash = calculateFileHash(for: file) {
                    hashGroups[hash, default: []].append(file)
                }
            }

            // Create duplicate groups for files with same hash
            for (_, filesWithSameHash) in hashGroups where filesWithSameHash.count >= 2 {
                let group = DuplicateGroup(
                    id: UUID(),
                    type: .exactDuplicate,
                    files: filesWithSameHash.sorted { $0.modificationDate > $1.modificationDate }
                )
                groups.append(group)
            }
        }

        return groups
    }

    /// Calculate SHA256 hash of a file
    private func calculateFileHash(for file: FileItem) -> String? {
        if let cached = cachedHash(for: file) {
            return cached
        }

        let hashId = PerformanceMonitor.shared.begin(.fileHash, metadata: (file.path as NSString).lastPathComponent)

        // Establish security-scoped access for sandboxed file reading
        let scopeURL = establishSecurityScope(for: file.path)
        defer { releaseSecurityScope(for: scopeURL) }

        do {
            let fileURL = URL(fileURLWithPath: file.path)
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer { try? fileHandle.close() }

            var hasher = SHA256()
            var bytesRead: Int = 0

            while true {
                let chunk = try fileHandle.read(upToCount: Self.hashChunkSize) ?? Data()
                if chunk.isEmpty { break }
                hasher.update(data: chunk)
                bytesRead += chunk.count
            }

            let digest = hasher.finalize()
            let hash = digest.compactMap { String(format: "%02x", $0) }.joined()
            cacheHash(hash, for: file)
            PerformanceMonitor.shared.end(.fileHash, id: hashId, metadata: "\(bytesRead) bytes")
            return hash
        } catch {
            PerformanceMonitor.shared.end(.fileHash, id: hashId, metadata: "failed to read")
            return nil
        }
    }

    private func cachedHash(for file: FileItem) -> String? {
        guard let entry = hashCacheByPath[file.path] else {
            return nil
        }
        guard entry.sizeInBytes == file.sizeInBytes,
              entry.modificationDate == file.modificationDate else {
            hashCacheByPath.removeValue(forKey: file.path)
            return nil
        }
        return entry.hash
    }

    private func cacheHash(_ hash: String, for file: FileItem) {
        if hashCacheByPath.count >= Self.maxHashCacheEntries,
           let oldestKey = hashCacheByPath.keys.first {
            hashCacheByPath.removeValue(forKey: oldestKey)
        }

        hashCacheByPath[file.path] = HashCacheEntry(
            sizeInBytes: file.sizeInBytes,
            modificationDate: file.modificationDate,
            hash: hash
        )
    }

    // MARK: - Version Series Detection

    /// Detect files that are versions of each other
    ///
    /// Patterns detected:
    /// - Numeric versions: file_v1.pdf, file_v2.pdf
    /// - Date versions: report_2024-01-01.pdf, report_2024-02-01.pdf
    /// - Copy suffixes: file.pdf, file (1).pdf, file (2).pdf
    /// - Draft versions: proposal_draft.docx, proposal_final.docx
    private func detectVersionSeries(in files: [FileItem]) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []

        // Group by extension first
        let extensionGroups = Dictionary(grouping: files) { $0.fileExtension }

        for (ext, filesWithExt) in extensionGroups where !ext.isEmpty {
            // Extract base names and version info
            var baseNameGroups: [String: [FileItem]] = [:]

            for file in filesWithExt {
                if let baseName = extractBaseName(from: file.name) {
                    baseNameGroups[baseName.lowercased(), default: []].append(file)
                }
            }

            // Create version groups where multiple versions exist
            for (_, versionFiles) in baseNameGroups where versionFiles.count >= 2 {
                // Verify these are actually versions (not just similar names)
                if hasVersionIndicators(versionFiles.map { $0.name }) {
                    let sorted = versionFiles
                        .map { ($0, extractVersionNumber($0.name)) }
                        .sorted { lhs, rhs in
                            if lhs.1 != rhs.1 {
                                return lhs.1 < rhs.1
                            }
                            return lhs.0.modificationDate < rhs.0.modificationDate
                        }
                        .map { $0.0 }
                    let group = DuplicateGroup(
                        id: UUID(),
                        type: .versionSeries,
                        files: sorted
                    )
                    groups.append(group)
                }
            }
        }

        return groups
    }

    /// Extract the base name without version indicators
    private func extractBaseName(from fileName: String) -> String? {
        var name = (fileName as NSString).deletingPathExtension

        // Remove common version patterns
        for regex in Self.versionStripRegexes {
            let range = NSRange(name.startIndex..., in: name)
            name = regex.stringByReplacingMatches(in: name, range: range, withTemplate: "")
        }

        // Trim and return if not empty
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Check if file names show version patterns
    private func hasVersionIndicators(_ names: [String]) -> Bool {
        var matchCount = 0
        for name in names {
            let range = NSRange(name.startIndex..., in: name)
            for regex in Self.versionIndicatorRegexes {
                if regex.firstMatch(in: name, range: range) != nil {
                    matchCount += 1
                    break
                }
            }
        }

        // At least half should have version indicators
        return matchCount >= names.count / 2
    }

    /// Extract a numeric version for sorting
    private func extractVersionNumber(_ name: String) -> Int {
        // Try to extract version number from common patterns
        let range = NSRange(name.startIndex..., in: name)
        for regex in Self.versionNumberRegexes {
            if let match = regex.firstMatch(in: name, range: range),
               match.numberOfRanges >= 2,
               let numberRange = Range(match.range(at: 1), in: name),
               let number = Int(name[numberRange]) {
                return number
            }
        }

        // Fallback: use modification date would be better, but we'll use 0
        return 0
    }

    // MARK: - Near Duplicate Detection

    /// Detect files with similar names that might be duplicates
    private func detectNearDuplicates(in files: [FileItem]) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        let maxDiffRatio = 1.0 - nameSimilarityThreshold

        // Group by extension for efficiency
        let extensionGroups = Dictionary(grouping: files) { $0.fileExtension.lowercased() }

        for (ext, filesWithExt) in extensionGroups where !ext.isEmpty && filesWithExt.count >= 2 {
            let candidates: [NameComparableFile] = filesWithExt.map { file in
                let baseName = (file.name as NSString).deletingPathExtension.lowercased()
                return NameComparableFile(
                    file: file,
                    baseName: baseName,
                    length: baseName.count,
                    prefix: String(baseName.prefix(3))
                )
            }

            var prefixBuckets: [String: [Int]] = [:]
            prefixBuckets.reserveCapacity(candidates.count)
            for (index, candidate) in candidates.enumerated() {
                prefixBuckets[candidate.prefix, default: []].append(index)
            }

            var processed = Set<Int>()
            processed.reserveCapacity(candidates.count)

            for i in candidates.indices where !processed.contains(i) {
                let reference = candidates[i]
                guard !reference.baseName.isEmpty else { continue }

                var similarIndices: [Int] = [i]
                var candidateIndices: Set<Int> = []

                if candidates.count <= 40 {
                    candidateIndices = Set(candidates.indices)
                } else {
                    if let samePrefix = prefixBuckets[reference.prefix] {
                        candidateIndices.formUnion(samePrefix)
                    }

                    if let firstChar = reference.prefix.first {
                        for (prefix, indices) in prefixBuckets where prefix.first == firstChar {
                            candidateIndices.formUnion(indices)
                        }
                    }
                }

                for j in candidateIndices where j > i && !processed.contains(j) {
                    let other = candidates[j]
                    guard !other.baseName.isEmpty else { continue }

                    let maxLength = max(reference.length, other.length)
                    if maxLength == 0 { continue }

                    let lengthDiff = abs(reference.length - other.length)
                    if Double(lengthDiff) / Double(maxLength) > maxDiffRatio {
                        continue
                    }

                    let similarity = calculateNameSimilarity(reference.baseName, other.baseName)
                    if similarity >= nameSimilarityThreshold {
                        similarIndices.append(j)
                    }
                }

                if similarIndices.count >= 2 {
                    processed.formUnion(similarIndices)
                    let group = DuplicateGroup(
                        id: UUID(),
                        type: .nearDuplicate,
                        files: similarIndices
                            .map { candidates[$0].file }
                            .sorted { $0.modificationDate > $1.modificationDate }
                    )
                    groups.append(group)
                }
            }
        }

        return groups
    }

    /// Calculate similarity between two file names using Levenshtein distance
    private func calculateNameSimilarity(_ name1: String, _ name2: String) -> Double {
        if name1 == name2 { return 1.0 }
        if name1.isEmpty || name2.isEmpty { return 0.0 }

        let distance = levenshteinDistance(name1, name2)
        let maxLength = max(name1.count, name2.count)

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Calculate Levenshtein edit distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let arr1 = Array(s1)
        let arr2 = Array(s2)

        let n = arr1.count
        let m = arr2.count

        if n == 0 { return m }
        if m == 0 { return n }

        // Keep the inner dimension as the shorter string to reduce memory.
        let (longer, shorter): ([Character], [Character]) = n >= m ? (arr1, arr2) : (arr2, arr1)
        let shortCount = shorter.count

        var previous = Array(0...shortCount)
        var current = Array(repeating: 0, count: shortCount + 1)

        for (i, longerChar) in longer.enumerated() {
            current[0] = i + 1
            for (j, shorterChar) in shorter.enumerated() {
                let cost = longerChar == shorterChar ? 0 : 1
                let deletion = previous[j + 1] + 1
                let insertion = current[j] + 1
                let substitution = previous[j] + cost
                current[j + 1] = min(deletion, insertion, substitution)
            }
            swap(&previous, &current)
        }

        return previous[shortCount]
    }

    // MARK: - Deduplication

    /// Remove overlapping duplicate groups, preferring more specific types
    private func deduplicateGroups(_ groups: [DuplicateGroup]) -> [DuplicateGroup] {
        var result: [DuplicateGroup] = []
        var usedPaths: Set<String> = []

        // Sort by priority (exact > version > near)
        let sorted = groups.sorted { $0.type.priority > $1.type.priority }

        for group in sorted {
            let newPaths = Set(group.files.map { $0.path })

            // Check if this group overlaps significantly with already-used paths
            let overlapCount = newPaths.intersection(usedPaths).count
            let overlapRatio = Double(overlapCount) / Double(newPaths.count)

            // Allow if less than 50% overlap
            if overlapRatio < 0.5 {
                result.append(group)
                usedPaths.formUnion(newPaths)
            }
        }

        return result
    }

    // MARK: - Convenience Methods

    /// Get total potential space savings from all duplicate groups
    func totalPotentialSavings(from groups: [DuplicateGroup]) -> Int64 {
        groups.reduce(0) { $0 + $1.potentialSpaceSavings }
    }

    /// Format bytes as human-readable string
    func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Quick check if a file collection might have duplicates
    /// (faster than full detection, for UI hints)
    func mightHaveDuplicates(in files: [FileItem]) -> Bool {
        // Check for same-size files (quick heuristic)
        let sizes = files.map { $0.sizeInBytes }
        let uniqueSizes = Set(sizes)
        return Double(uniqueSizes.count) < Double(sizes.count) * 0.9
    }
}

// MARK: - Mock Data

extension DuplicateDetectionService.DuplicateGroup {
    static var mocks: [DuplicateDetectionService.DuplicateGroup] {
        [
            DuplicateDetectionService.DuplicateGroup(
                id: UUID(),
                type: .exactDuplicate,
                files: [
                    FileItem(
                        path: "/Users/test/Desktop/Report.pdf",
                        sizeInBytes: 2_500_000,
                        creationDate: Date()
                    ),
                    FileItem(
                        path: "/Users/test/Documents/Report.pdf",
                        sizeInBytes: 2_500_000,
                        creationDate: Date().addingTimeInterval(-86400)
                    )
                ]
            ),
            DuplicateDetectionService.DuplicateGroup(
                id: UUID(),
                type: .versionSeries,
                files: [
                    FileItem(
                        path: "/Users/test/Documents/Proposal_v1.docx",
                        sizeInBytes: 150_000,
                        creationDate: Date().addingTimeInterval(-172800)
                    ),
                    FileItem(
                        path: "/Users/test/Documents/Proposal_v2.docx",
                        sizeInBytes: 175_000,
                        creationDate: Date().addingTimeInterval(-86400)
                    ),
                    FileItem(
                        path: "/Users/test/Documents/Proposal_v3_final.docx",
                        sizeInBytes: 200_000,
                        creationDate: Date()
                    )
                ]
            )
        ]
    }
}
