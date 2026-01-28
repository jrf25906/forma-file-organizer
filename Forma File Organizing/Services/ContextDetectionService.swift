import Foundation

/// Service for detecting contextual clusters of related files using various algorithms.
///
/// ContextDetectionService analyzes file metadata (names, timestamps, paths) to identify groups
/// of files that likely belong together and should be organized as a unit.
///
/// Note: This service is @MainActor-isolated because it works with FileItem @Model objects
/// which are inherently main-actor-isolated in SwiftData.
@MainActor
class ContextDetectionService {
    
    // MARK: - Configuration
    
    /// Temporal threshold: files modified within 5 minutes are considered part of the same work session
    private static let temporalThresholdSeconds: TimeInterval = 300 // 5 minutes
    
    /// Minimum number of files required to form a cluster
    private static let minClusterSize = 3
    
    /// Minimum confidence score to return a cluster
    private static let minConfidenceThreshold = 0.5
    
    /// Minimum Levenshtein similarity ratio (0.0-1.0) for name similarity clustering
    private static let minNameSimilarityRatio = 0.6
    
    // MARK: - Public API
    
    /// Detect all types of clusters from a list of files
    ///
    /// - Parameter files: Array of FileItem to analyze
    /// - Returns: Array of detected ProjectCluster objects
    func detectClusters(from files: [FileItem]) -> [ProjectCluster] {
        // Check feature flag before performing context detection
        guard FeatureFlagService.shared.isEnabled(.contextDetection) else {
            Log.info("ContextDetectionService: Context detection disabled by feature flag", category: .analytics)
            return []
        }

        let clusterId = PerformanceMonitor.shared.begin(.clusterDetection, metadata: "\(files.count) files")

        var allClusters: [ProjectCluster] = []

        // Run all detection algorithms
        allClusters.append(contentsOf: detectProjectCodeClusters(from: files))
        allClusters.append(contentsOf: detectTemporalClusters(from: files))
        allClusters.append(contentsOf: detectNameSimilarityClusters(from: files))
        allClusters.append(contentsOf: detectDateStampClusters(from: files))

        // Filter by confidence and size
        let result = allClusters.filter { cluster in
            cluster.confidenceScore >= Self.minConfidenceThreshold &&
            cluster.fileCount >= Self.minClusterSize
        }

        PerformanceMonitor.shared.end(.clusterDetection, id: clusterId, metadata: "\(result.count) clusters found")
        return result
    }
    
    // MARK: - Detection Algorithms
    
    /// Detect clusters based on project codes in file names
    ///
    /// Looks for patterns like: P-1024, JIRA-456, CLIENT_ABC, ABC-123
    ///
    /// - Parameter files: Array of FileItem to analyze
    /// - Returns: Array of ProjectCluster objects
    private func detectProjectCodeClusters(from files: [FileItem]) -> [ProjectCluster] {
        let patterns: [(String, String)] = [
            ("P-\\d{3,4}", "Project"),
            ("[A-Z]{2,5}-\\d{2,4}", "Project"),
            ("[A-Z]+_[A-Z]{2,}", "Project"),
            ("^\\d{4}-\\d{2}-\\d{2}", "Date"),
        ]

        return patterns.flatMap { pattern, prefix -> [ProjectCluster] in
            guard let groups = groupFilesByRegex(pattern, files: files) else { return [] }
            return groups.compactMap { code, groupFiles in
                guard groupFiles.count >= Self.minClusterSize else { return nil }
                return ProjectCluster(
                    clusterType: .projectCode,
                    filePaths: groupFiles.map { $0.path },
                    confidenceScore: calculateProjectCodeConfidence(fileCount: groupFiles.count),
                    suggestedFolderName: "\(prefix) \(code)",
                    detectedPattern: code
                )
            }
        }
    }
    
    /// Detect clusters based on temporal proximity (same work session)
    ///
    /// Files modified within 5 minutes of each other are likely related.
    ///
    /// - Parameter files: Array of FileItem to analyze
    /// - Returns: Array of ProjectCluster objects
    private func detectTemporalClusters(from files: [FileItem]) -> [ProjectCluster] {
        var clusters: [ProjectCluster] = []
        
        // Sort files by modification date
        let sortedFiles = files.sorted { $0.modificationDate < $1.modificationDate }
        
        var currentCluster: [FileItem] = []
        var lastTimestamp: Date?
        
        for file in sortedFiles {
            if let last = lastTimestamp {
                let timeDiff = file.modificationDate.timeIntervalSince(last)
                
                if timeDiff <= Self.temporalThresholdSeconds {
                    // Within threshold - add to current cluster
                    currentCluster.append(file)
                } else {
                    // Gap too large - finalize current cluster and start new one
                    if currentCluster.count >= Self.minClusterSize {
                        clusters.append(createTemporalCluster(from: currentCluster))
                    }
                    currentCluster = [file]
                }
            } else {
                // First file
                currentCluster.append(file)
            }
            
            lastTimestamp = file.modificationDate
        }
        
        // Don't forget the last cluster
        if currentCluster.count >= Self.minClusterSize {
            clusters.append(createTemporalCluster(from: currentCluster))
        }
        
        return clusters
    }
    
    /// Detect clusters based on name similarity (versions, sequences)
    ///
    /// Uses Levenshtein distance to find files with similar names.
    /// Optimized with pre-computation, length filtering, and prefix bucketing to reduce O(n²) comparisons.
    ///
    /// - Parameter files: Array of FileItem to analyze
    /// - Returns: Array of ProjectCluster objects
    private func detectNameSimilarityClusters(from files: [FileItem]) -> [ProjectCluster] {
        // OPTIMIZATION 1: Pre-compute basenames once upfront
        struct FileWithBasename {
            let file: FileItem
            let basename: String          // lowercased for comparison
            let originalBasename: String  // original casing for display
            let length: Int
            let prefixKey: String  // First 3 chars for bucketing
        }

        let filesWithBasenames: [FileWithBasename] = files.map { file in
            let originalBasename = stripExtension(from: file.name)
            let basename = originalBasename.lowercased()
            let prefixKey = String(basename.prefix(3))
            return FileWithBasename(
                file: file,
                basename: basename,
                originalBasename: originalBasename,
                length: basename.count,
                prefixKey: prefixKey
            )
        }

        // OPTIMIZATION 2: Group by prefix for bucket-based comparison
        // Files with different prefixes are unlikely to be similar
        var prefixBuckets: [String: [Int]] = [:]  // prefixKey -> indices in filesWithBasenames
        for (index, fileData) in filesWithBasenames.enumerated() {
            prefixBuckets[fileData.prefixKey, default: []].append(index)
        }

        // Calculate max length difference allowed for similarity threshold
        // If similarity must be >= 0.6, then maxDiff/maxLength <= 0.4
        let maxDiffRatio = 1.0 - Self.minNameSimilarityRatio

        var clusters: [ProjectCluster] = []
        var processedIndices = Set<Int>()

        for i in 0..<filesWithBasenames.count {
            guard !processedIndices.contains(i) else { continue }

            let fileData = filesWithBasenames[i]
            var clusterIndices: [Int] = [i]
            processedIndices.insert(i)

            // OPTIMIZATION 3: Only compare with files in same or similar prefix buckets
            // For small file sets, compare all files (O(n²) is cheap).
            // For larger sets, use prefix bucketing to reduce comparisons.
            var candidateIndices: Set<Int> = []

            if filesWithBasenames.count <= 50 {
                // Small set: compare all to avoid missing cross-bucket matches
                candidateIndices = Set(0..<filesWithBasenames.count)
            } else {
                // Same prefix bucket
                if let samePrefix = prefixBuckets[fileData.prefixKey] {
                    candidateIndices.formUnion(samePrefix)
                }

                // Also check buckets with similar first character (for typos/variations)
                let firstChar = fileData.prefixKey.first ?? Character(" ")
                for (key, indices) in prefixBuckets {
                    if key.first == firstChar && key != fileData.prefixKey {
                        candidateIndices.formUnion(indices)
                    }
                }
            }

            // Compare only with candidates
            for j in candidateIndices where j > i {
                guard !processedIndices.contains(j) else { continue }

                let otherData = filesWithBasenames[j]

                // OPTIMIZATION 4: Length-based early rejection
                // Skip if lengths differ too much for Levenshtein AND the shorter name
                // is too short for a meaningful prefix match. Prefix ratio uses minLength
                // as denominator, so names >= 3 chars can still score high (e.g. "report"
                // vs "report_v1_draft" has prefix ratio 1.0).
                let maxLength = max(fileData.length, otherData.length)
                let minLength = min(fileData.length, otherData.length)
                let lengthDiff = abs(fileData.length - otherData.length)
                let levenshteinRuledOut = maxLength > 0 && Double(lengthDiff) / Double(maxLength) > maxDiffRatio

                if levenshteinRuledOut && minLength < 3 {
                    continue
                }

                // Now compute actual similarity (still needed for accurate clustering)
                let similarity = calculateNameSimilarity(fileData.basename, otherData.basename)

                if similarity >= Self.minNameSimilarityRatio {
                    clusterIndices.append(j)
                    processedIndices.insert(j)
                }
            }

            // Create cluster if we found enough similar files
            if clusterIndices.count >= Self.minClusterSize {
                let clusterFiles = clusterIndices.map { filesWithBasenames[$0].file }
                let originalBasenames = clusterIndices.map { filesWithBasenames[$0].originalBasename }
                let commonPrefix = findCommonPrefix(originalBasenames)
                let confidence = Double(clusterIndices.count) / Double(files.count) + 0.5
                let clampedConfidence = min(confidence, 0.95)

                let suggestedName = commonPrefix.isEmpty ? "Related Files" : commonPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "_ -"))

                let cluster = ProjectCluster(
                    clusterType: .nameSimilarity,
                    filePaths: clusterFiles.map { $0.path },
                    confidenceScore: clampedConfidence,
                    suggestedFolderName: suggestedName
                )

                clusters.append(cluster)
            }
        }

        return clusters
    }
    
    /// Detect clusters based on date stamps in file names
    ///
    /// Groups files with the same date pattern (2024-11-15, 20241115, etc.)
    ///
    /// - Parameter files: Array of FileItem to analyze
    /// - Returns: Array of ProjectCluster objects
    private func detectDateStampClusters(from files: [FileItem]) -> [ProjectCluster] {
        let patterns = [
            "\\d{4}-\\d{2}-\\d{2}",  // 2024-11-15
            "\\d{8}",                 // 20241115
            "\\d{2}-\\d{2}-\\d{4}",  // 11-15-2024
        ]

        return patterns.flatMap { pattern -> [ProjectCluster] in
            guard let groups = groupFilesByRegex(pattern, files: files) else { return [] }
            return groups.compactMap { dateStamp, groupFiles in
                guard groupFiles.count >= Self.minClusterSize else { return nil }
                return ProjectCluster(
                    clusterType: .dateStamp,
                    filePaths: groupFiles.map { $0.path },
                    confidenceScore: calculateDateStampConfidence(fileCount: groupFiles.count),
                    suggestedFolderName: "Files from \(dateStamp)",
                    detectedPattern: dateStamp
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Strip file extension from filename
    ///
    /// - Parameter fileName: Filename with extension
    /// - Returns: Filename without extension
    private func stripExtension(from fileName: String) -> String {
        if let lastDot = fileName.lastIndex(of: ".") {
            return String(fileName[..<lastDot])
        }
        return fileName
    }

    /// Group files by first regex match in their names, returning `nil` for invalid patterns.
    private func groupFilesByRegex(_ pattern: String, files: [FileItem]) -> [String: [FileItem]]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            Log.warning("ContextDetectionService: Invalid regex pattern '\(pattern)'. Skipping.", category: .analytics)
            return nil
        }
        var groups: [String: [FileItem]] = [:]
        for file in files {
            let name = file.name
            let range = NSRange(name.startIndex..., in: name)
            if let match = regex.firstMatch(in: name, range: range),
               let matchRange = Range(match.range, in: name) {
                groups[String(name[matchRange]), default: []].append(file)
            }
        }
        return groups
    }

    /// Create a temporal cluster from a group of files
    private func createTemporalCluster(from files: [FileItem]) -> ProjectCluster {
        guard let firstFile = files.first else {
            Log.error("ContextDetectionService: createTemporalCluster called with empty files array", category: .analytics)
            return ProjectCluster(
                clusterType: .temporal,
                filePaths: [],
                confidenceScore: 0.0,
                suggestedFolderName: "Empty Cluster"
            )
        }

        let dates = files.map { $0.modificationDate }
        // Non-empty array always has min/max, so force-unwrap is safe after the guard above
        let timeSpan = dates.max()!.timeIntervalSince(dates.min()!)

        // Higher confidence for tighter time grouping
        let confidence: Double = timeSpan < 60 ? 0.85 : timeSpan < 180 ? 0.75 : 0.65

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let suggestedName = "Work Session - \(formatter.string(from: firstFile.modificationDate))"

        return ProjectCluster(
            clusterType: .temporal,
            filePaths: files.map { $0.path },
            confidenceScore: confidence,
            suggestedFolderName: suggestedName
        )
    }
    
    /// Calculate confidence for project code clusters
    private func calculateProjectCodeConfidence(fileCount: Int) -> Double {
        let base = 0.8
            + (fileCount >= 5 ? 0.1 : 0.0)
            + (fileCount >= 10 ? 0.05 : 0.0)
        return min(base, 0.95)
    }

    /// Calculate confidence for date stamp clusters
    private func calculateDateStampConfidence(fileCount: Int) -> Double {
        let base = 0.6
            + (fileCount >= 5 ? 0.15 : 0.0)
            + (fileCount >= 8 ? 0.1 : 0.0)
        return min(base, 0.85)
    }
    
    /// Calculate name similarity using Levenshtein distance ratio
    ///
    /// Returns a value between 0.0 (completely different) and 1.0 (identical)
    ///
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Similarity ratio (0.0-1.0)
    private func calculateNameSimilarity(_ str1: String, _ str2: String) -> Double {
        let maxLength = max(str1.count, str2.count)
        guard maxLength > 0 else { return 0.0 }

        let levenshteinSimilarity = 1.0 - (Double(levenshteinDistance(str1, str2)) / Double(maxLength))

        // Prefix ratio handles cases where one name is a prefix of another
        // (e.g. "report" vs "report_v1_draft")
        let minLength = min(str1.count, str2.count)
        let prefixRatio = minLength > 0
            ? Double(str1.commonPrefix(with: str2).count) / Double(minLength)
            : 0.0

        return max(levenshteinSimilarity, prefixRatio)
    }
    
    /// Calculate Levenshtein distance between two strings
    ///
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Edit distance (number of character changes needed)
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let len1 = str1.count
        let len2 = str2.count
        
        guard len1 > 0 else { return len2 }
        guard len2 > 0 else { return len1 }
        
        var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        
        // Initialize first column and row
        for i in 0...len1 { matrix[i][0] = i }
        for j in 0...len2 { matrix[0][j] = j }
        
        let chars1 = Array(str1)
        let chars2 = Array(str2)
        
        // Fill matrix
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = chars1[i-1] == chars2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[len1][len2]
    }
    
    /// Find the longest common prefix among a list of strings, trimmed to the last word boundary.
    private func findCommonPrefix(_ strings: [String]) -> String {
        guard let first = strings.first else { return "" }

        var prefix = strings.dropFirst().reduce(first) { $0.commonPrefix(with: $1) }

        // Trim to last word boundary (space, underscore, or hyphen)
        if let lastBoundary = prefix.lastIndex(where: { " _-".contains($0) }) {
            prefix = String(prefix[..<lastBoundary])
        }

        return prefix
    }
}
