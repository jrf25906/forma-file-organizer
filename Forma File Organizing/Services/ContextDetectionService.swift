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
        var clusters: [ProjectCluster] = []
        
        // Project code patterns
        let patterns = [
            // P-1024, P-001
            ("P-\\d{3,4}", "Project"),
            // JIRA-456, ABC-123
            ("[A-Z]{2,5}-\\d{2,4}", "Project"),
            // CLIENT_ABC, PROJ_XYZ
            ("[A-Z]+_[A-Z]{2,}", "Project"),
            // 2024-11-15 format dates at start
            ("^\\d{4}-\\d{2}-\\d{2}", "Date"),
        ]
        
        for (pattern, prefix) in patterns {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                Log.warning("ContextDetectionService: Invalid regex pattern '\(pattern)': \(error.localizedDescription). Skipping.", category: .analytics)
                continue
            }

            // Group files by detected pattern
            var patternGroups: [String: [FileItem]] = [:]

            for file in files {
                let fileName = file.name
                let range = NSRange(fileName.startIndex..., in: fileName)

                if let match = regex.firstMatch(in: fileName, options: [], range: range),
                   let matchRange = Range(match.range, in: fileName) {
                    let detectedCode = String(fileName[matchRange])
                    patternGroups[detectedCode, default: []].append(file)
                }
            }
            
            // Create clusters for groups with enough files
            for (code, groupFiles) in patternGroups where groupFiles.count >= Self.minClusterSize {
                let confidence = calculateProjectCodeConfidence(
                    fileCount: groupFiles.count,
                    totalFiles: files.count
                )
                
                let suggestedName = "\(prefix) \(code)"
                
                let cluster = ProjectCluster(
                    clusterType: .projectCode,
                    filePaths: groupFiles.map { $0.path },
                    confidenceScore: confidence,
                    suggestedFolderName: suggestedName,
                    detectedPattern: code
                )
                
                clusters.append(cluster)
            }
        }
        
        return clusters
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
            let basename: String
            let length: Int
            let prefixKey: String  // First 3 chars for bucketing
        }

        let filesWithBasenames: [FileWithBasename] = files.map { file in
            let basename = stripExtension(from: file.name).lowercased()
            let prefixKey = String(basename.prefix(3))
            return FileWithBasename(
                file: file,
                basename: basename,
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
            // Get candidate indices from this bucket and neighboring buckets
            var candidateIndices: Set<Int> = []

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

            // Compare only with candidates
            for j in candidateIndices where j > i {
                guard !processedIndices.contains(j) else { continue }

                let otherData = filesWithBasenames[j]

                // OPTIMIZATION 4: Length-based early rejection
                // If lengths are too different, similarity can't meet threshold
                let maxLength = max(fileData.length, otherData.length)
                let lengthDiff = abs(fileData.length - otherData.length)

                if maxLength > 0 && Double(lengthDiff) / Double(maxLength) > maxDiffRatio {
                    continue  // Skip expensive Levenshtein calculation
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
                let basenames = clusterIndices.map { filesWithBasenames[$0].basename }
                let commonPrefix = findCommonPrefix(basenames)
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
        var clusters: [ProjectCluster] = []
        
        // Date patterns to look for
        let patterns = [
            "\\d{4}-\\d{2}-\\d{2}",  // 2024-11-15
            "\\d{8}",                 // 20241115
            "\\d{2}-\\d{2}-\\d{4}",  // 11-15-2024
        ]
        
        for pattern in patterns {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                Log.warning("ContextDetectionService: Invalid regex pattern '\(pattern)': \(error.localizedDescription). Skipping.", category: .analytics)
                continue
            }

            var dateGroups: [String: [FileItem]] = [:]

            for file in files {
                let fileName = file.name
                let range = NSRange(fileName.startIndex..., in: fileName)

                if let match = regex.firstMatch(in: fileName, options: [], range: range),
                   let matchRange = Range(match.range, in: fileName) {
                    let dateStamp = String(fileName[matchRange])
                    dateGroups[dateStamp, default: []].append(file)
                }
            }
            
            // Create clusters for groups with enough files
            for (dateStamp, groupFiles) in dateGroups where groupFiles.count >= Self.minClusterSize {
                let confidence = calculateDateStampConfidence(
                    fileCount: groupFiles.count,
                    totalFiles: files.count
                )
                
                let cluster = ProjectCluster(
                    clusterType: .dateStamp,
                    filePaths: groupFiles.map { $0.path },
                    confidenceScore: confidence,
                    suggestedFolderName: "Files from \(dateStamp)",
                    detectedPattern: dateStamp
                )
                
                clusters.append(cluster)
            }
        }
        
        return clusters
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
    
    /// Create a temporal cluster from a group of files
    private func createTemporalCluster(from files: [FileItem]) -> ProjectCluster {
        // Guard against empty array to prevent crashes
        guard let firstFile = files.first else {
            Log.error("ContextDetectionService: createTemporalCluster called with empty files array", category: .analytics)
            return ProjectCluster(
                clusterType: .temporal,
                filePaths: [],
                confidenceScore: 0.0,
                suggestedFolderName: "Empty Cluster"
            )
        }

        // Calculate time span of the cluster
        let dates = files.map { $0.modificationDate }
        guard let maxDate = dates.max(), let minDate = dates.min() else {
            Log.error("ContextDetectionService: could not compute date range", category: .analytics)
            return ProjectCluster(
                clusterType: .temporal,
                filePaths: files.map { $0.path },
                confidenceScore: 0.5,
                suggestedFolderName: "Unknown Cluster"
            )
        }
        let timeSpan = maxDate.timeIntervalSince(minDate)

        // Higher confidence for tighter time grouping
        let confidence: Double
        if timeSpan < 60 { // Within 1 minute
            confidence = 0.85
        } else if timeSpan < 180 { // Within 3 minutes
            confidence = 0.75
        } else {
            confidence = 0.65
        }
        // Note: baseName available for future use in suggested naming
        _ = URL(fileURLWithPath: firstFile.path)
            .deletingPathExtension()
            .lastPathComponent
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: firstFile.modificationDate)
        
        let suggestedName = "Work Session - \(dateString)"
        
        return ProjectCluster(
            clusterType: .temporal,
            filePaths: files.map { $0.path },
            confidenceScore: confidence,
            suggestedFolderName: suggestedName
        )
    }
    
    /// Calculate confidence for project code clusters
    private func calculateProjectCodeConfidence(fileCount: Int, totalFiles: Int) -> Double {
        // Base confidence starts high for explicit codes
        var confidence = 0.8
        
        // Increase confidence with more files
        if fileCount >= 5 {
            confidence += 0.1
        }
        if fileCount >= 10 {
            confidence += 0.05
        }
        
        return min(confidence, 0.95)
    }
    
    /// Calculate confidence for date stamp clusters
    private func calculateDateStampConfidence(fileCount: Int, totalFiles: Int) -> Double {
        // Base confidence lower than project codes
        var confidence = 0.6
        
        // Increase with more files
        if fileCount >= 5 {
            confidence += 0.15
        }
        if fileCount >= 8 {
            confidence += 0.1
        }
        
        return min(confidence, 0.85)
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
        // First, calculate standard Levenshtein similarity
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        let levenshteinSimilarity = 1.0 - (Double(distance) / Double(maxLength))
        
        // Also consider common prefix ratio to handle cases where one name is a prefix of another
        let minLength = min(str1.count, str2.count)
        var commonPrefixLength = 0
        for i in 0..<minLength {
            let idx1 = str1.index(str1.startIndex, offsetBy: i)
            let idx2 = str2.index(str2.startIndex, offsetBy: i)
            if str1[idx1] == str2[idx2] {
                commonPrefixLength += 1
            } else {
                break
            }
        }
        let prefixRatio = Double(commonPrefixLength) / Double(minLength)
        
        // Return the higher of the two scores to be more lenient with mixed-length names
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
    
    /// Find the longest common prefix among a list of strings
    ///
    /// - Parameter strings: Array of strings to analyze
    /// - Returns: Common prefix string
    private func findCommonPrefix(_ strings: [String]) -> String {
        guard !strings.isEmpty else { return "" }
        guard strings.count > 1 else { return strings[0] }
        
        var prefix = ""
        let firstString = strings[0]
        
        for (offset, char) in firstString.enumerated() {
            // Check if all strings have this character at this position, using safe indexing
            let allMatch = strings.allSatisfy { string in
                // Empty strings cannot contribute to a common prefix
                guard !string.isEmpty else { return false }
                let lastValidIndex = string.index(before: string.endIndex)
                guard let stringIndex = string.index(
                    string.startIndex,
                    offsetBy: offset,
                    limitedBy: lastValidIndex
                ) else {
                    return false
                }
                return string[stringIndex] == char
            }
            
            if allMatch {
                prefix.append(char)
            } else {
                break
            }
        }
        
        // Return prefix up to last word boundary (space, underscore, or hyphen)
        if let lastBoundary = prefix.lastIndex(of: " ")
            ?? prefix.lastIndex(of: "_")
            ?? prefix.lastIndex(of: "-") {
            return String(prefix[..<lastBoundary])
        }
        
        return prefix
    }
}
