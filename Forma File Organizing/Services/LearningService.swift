import Foundation
import SwiftData

/// Service for learning from user behavior and suggesting automation rules.
///
/// LearningService analyzes ActivityItem history to detect repeated file organization patterns
/// and converts them into LearnedPattern objects that can be suggested to users or
/// automatically converted into permanent rules.
///
/// ## Pattern Detection Capabilities
/// - **Simple Patterns**: Extension → Destination (e.g., "PDFs go to Documents")
/// - **Multi-Condition Patterns**: Extension + Name prefix → Destination (e.g., "PDFs starting with Invoice_ go to Finance")
/// - **Temporal Patterns**: Time-based organization (e.g., "Screenshots during work hours go to Work folder")
/// - **Negative Patterns**: Anti-patterns learned from user rejections (e.g., "Don't suggest Desktop for temp files")
///
/// Note: This service is @MainActor-isolated because it works with SwiftData @Model objects
/// (ActivityItem, LearnedPattern) which are inherently main-actor-isolated.
@MainActor
class LearningService {

    // MARK: - Configuration

    /// Minimum occurrences required to form a pattern
    private let minimumOccurrences = 3

    /// Minimum confidence score for pattern suggestion
    private let minimumConfidence = 0.5

    /// Common file name prefixes that indicate distinct categories
    private let significantPrefixes = [
        "Invoice", "Receipt", "Screenshot", "Photo", "IMG", "DSC", "VID",
        "Report", "Contract", "Agreement", "Proposal", "Draft", "Final",
        "Meeting", "Notes", "Summary", "Backup", "Archive", "Export"
    ]

    /// Keywords that indicate file purpose
    private let purposeKeywords = [
        "invoice", "receipt", "statement", "contract", "agreement",
        "report", "presentation", "proposal", "meeting", "notes",
        "screenshot", "photo", "image", "video", "audio",
        "backup", "archive", "export", "download", "temp"
    ]

    // MARK: - Main Detection Entry Point

    /// Detect all types of patterns from user's file organization activities
    ///
    /// This is the main entry point that combines all pattern detection algorithms.
    ///
    /// - Parameter activities: Array of ActivityItem representing user actions
    /// - Returns: Array of LearnedPattern objects detected from user behavior
    func detectPatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        // Check feature flag
        guard FeatureFlagService.shared.isEnabled(.patternLearning) else {
            Log.info("LearningService: Pattern learning disabled by feature flag", category: .analytics)
            return []
        }

        var allPatterns: [LearnedPattern] = []

        // 1. Detect simple extension-based patterns (baseline)
        let simplePatterns = detectSimplePatterns(from: activities)
        allPatterns.append(contentsOf: simplePatterns)

        // 2. Detect multi-condition patterns (more specific)
        let multiConditionPatterns = detectMultiConditionPatterns(from: activities)
        allPatterns.append(contentsOf: multiConditionPatterns)

        // 3. Detect temporal patterns
        let temporalPatterns = detectTemporalPatterns(from: activities)
        allPatterns.append(contentsOf: temporalPatterns)

        // 4. Detect negative patterns from rejections
        let negativePatterns = detectNegativePatterns(from: activities)
        allPatterns.append(contentsOf: negativePatterns)

        // Deduplicate and prioritize more specific patterns
        let deduplicatedPatterns = deduplicatePatterns(allPatterns)

        return deduplicatedPatterns.sorted { $0.confidenceScore > $1.confidenceScore }
    }

    // MARK: - Simple Pattern Detection (Extension-Based)

    /// Detect simple extension → destination patterns
    ///
    /// - Parameter activities: Array of ActivityItem representing user actions
    /// - Returns: Array of LearnedPattern objects for simple patterns
    private func detectSimplePatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        // Filter to only organization activities (fileOrganized and fileMoved)
        let organizationActivities = activities.filter {
            $0.activityType == .fileOrganized || $0.activityType == .fileMoved
        }

        // Group by file extension
        let extensionGroups = Dictionary(grouping: organizationActivities) { activity in
            activity.fileExtension ?? ""
        }

        var patterns: [LearnedPattern] = []

        for (ext, activitiesForExtension) in extensionGroups where !ext.isEmpty {
            // Extract destinations from activity details
            // Format: "Moved to Documents/Finance" or similar
            let destinationCounts = Dictionary(grouping: activitiesForExtension) { activity in
                extractDestination(from: activity.details)
            }

            // Calculate the total number of moves for this extension
            let totalMoves = activitiesForExtension.count

            for (destination, activitiesForDestination) in destinationCounts where !destination.isEmpty {
                let occurrenceCount = activitiesForDestination.count

                // Calculate confidence score (frequency-based)
                let frequency = Double(occurrenceCount) / Double(totalMoves)

                // Only create patterns for significant behaviors (at least 3 occurrences)
                guard occurrenceCount >= minimumOccurrences else { continue }

                // Create pattern
                let patternDescription = "Move \(ext.uppercased()) files to \(abbreviatePath(destination))"

                let pattern = LearnedPattern(
                    patternDescription: patternDescription,
                    fileExtension: ext,
                    destinationPath: destination,
                    occurrenceCount: occurrenceCount,
                    confidenceScore: frequency,
                    lastSeenDate: activitiesForDestination.map { $0.timestamp }.max() ?? Date()
                )

                // Add the single condition
                pattern.addCondition(.fileExtension(ext))

                patterns.append(pattern)
            }
        }

        return patterns
    }

    // MARK: - Multi-Condition Pattern Detection

    /// Detect patterns with multiple conditions (e.g., extension + name prefix)
    ///
    /// These patterns are more specific than simple extension-based patterns
    /// and should have higher priority when they match.
    ///
    /// - Parameter activities: Array of ActivityItem representing user actions
    /// - Returns: Array of LearnedPattern objects with multiple conditions
    private func detectMultiConditionPatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        let organizationActivities = activities.filter {
            $0.activityType == .fileOrganized || $0.activityType == .fileMoved
        }

        var patterns: [LearnedPattern] = []

        // Strategy 1: Extension + Name Prefix patterns
        patterns.append(contentsOf: detectExtensionPrefixPatterns(from: organizationActivities))

        // Strategy 2: Extension + Keyword patterns
        patterns.append(contentsOf: detectExtensionKeywordPatterns(from: organizationActivities))

        // Strategy 3: Size range patterns
        patterns.append(contentsOf: detectSizeRangePatterns(from: organizationActivities))

        return patterns
    }

    /// Detect patterns where files with same extension AND name prefix go to same place
    private func detectExtensionPrefixPatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        var patterns: [LearnedPattern] = []

        // Group by extension first
        let extensionGroups = Dictionary(grouping: activities) { $0.fileExtension ?? "" }

        for (ext, activitiesForExtension) in extensionGroups where !ext.isEmpty {
            // For each extension, look for common prefixes
            for prefix in significantPrefixes {
                let matchingActivities = activitiesForExtension.filter { activity in
                    activity.fileName.lowercased().hasPrefix(prefix.lowercased())
                }

                guard matchingActivities.count >= minimumOccurrences else { continue }

                // Group these by destination
                let destinationGroups = Dictionary(grouping: matchingActivities) {
                    extractDestination(from: $0.details)
                }

                for (destination, activitiesForDestination) in destinationGroups where !destination.isEmpty {
                    let count = activitiesForDestination.count
                    guard count >= minimumOccurrences else { continue }

                    // Calculate confidence (occurrences / total matching prefix)
                    let confidence = Double(count) / Double(matchingActivities.count)

                    // Boost confidence for multi-condition patterns (they're more specific)
                    let boostedConfidence = min(1.0, confidence * 1.15)

                    let description = "Move \(prefix) \(ext.uppercased()) files to \(abbreviatePath(destination))"

                    let pattern = LearnedPattern(
                        patternDescription: description,
                        fileExtension: ext,
                        destinationPath: destination,
                        occurrenceCount: count,
                        confidenceScore: boostedConfidence,
                        lastSeenDate: activitiesForDestination.map { $0.timestamp }.max() ?? Date()
                    )

                    // Add compound conditions
                    pattern.addCondition(.fileExtension(ext))
                    pattern.addCondition(.nameStartsWith(prefix))
                    pattern.logicalOperator = .and

                    // Extract keywords from the prefix
                    pattern.extractedKeywords = [prefix.lowercased()]

                    patterns.append(pattern)
                }
            }
        }

        return patterns
    }

    /// Detect patterns based on keywords appearing in file names
    private func detectExtensionKeywordPatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        var patterns: [LearnedPattern] = []

        let extensionGroups = Dictionary(grouping: activities) { $0.fileExtension ?? "" }

        for (ext, activitiesForExtension) in extensionGroups where !ext.isEmpty {
            for keyword in purposeKeywords {
                let matchingActivities = activitiesForExtension.filter { activity in
                    activity.fileName.lowercased().contains(keyword)
                }

                guard matchingActivities.count >= minimumOccurrences else { continue }

                let destinationGroups = Dictionary(grouping: matchingActivities) {
                    extractDestination(from: $0.details)
                }

                for (destination, activitiesForDestination) in destinationGroups where !destination.isEmpty {
                    let count = activitiesForDestination.count
                    guard count >= minimumOccurrences else { continue }

                    let confidence = Double(count) / Double(matchingActivities.count)
                    let boostedConfidence = min(1.0, confidence * 1.1)

                    let description = "Move \(ext.uppercased()) files containing '\(keyword)' to \(abbreviatePath(destination))"

                    let pattern = LearnedPattern(
                        patternDescription: description,
                        fileExtension: ext,
                        destinationPath: destination,
                        occurrenceCount: count,
                        confidenceScore: boostedConfidence,
                        lastSeenDate: activitiesForDestination.map { $0.timestamp }.max() ?? Date()
                    )

                    pattern.addCondition(.fileExtension(ext))
                    pattern.addCondition(.nameContains(keyword))
                    pattern.logicalOperator = .and
                    pattern.extractedKeywords = [keyword]

                    patterns.append(pattern)
                }
            }
        }

        return patterns
    }

    /// Detect patterns based on file size ranges
    /// Note: This requires activities to have size info - we parse from details if available
    private func detectSizeRangePatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        // Size ranges in bytes - prepared for future enhancement when ActivityItem includes file size
        // let sizeRanges: [(name: String, min: Int64, max: Int64)] = [
        //     ("tiny", 0, 10 * 1024),                           // < 10KB
        //     ("small", 10 * 1024, 1024 * 1024),                // 10KB - 1MB
        //     ("medium", 1024 * 1024, 10 * 1024 * 1024),        // 1MB - 10MB
        //     ("large", 10 * 1024 * 1024, 100 * 1024 * 1024),   // 10MB - 100MB
        //     ("huge", 100 * 1024 * 1024, Int64.max)            // > 100MB
        // ]

        // For now, return empty - size patterns require size data in activities
        // This can be enhanced when ActivityItem includes file size
        _ = activities // Silence unused parameter warning until implementation
        return []
    }

    // MARK: - Temporal Pattern Detection

    /// Detect time-based organization patterns
    ///
    /// Users often organize files differently based on time of day or day of week.
    /// For example: work files during business hours, personal files on weekends.
    ///
    /// - Parameter activities: Array of ActivityItem representing user actions
    /// - Returns: Array of LearnedPattern objects with temporal conditions
    private func detectTemporalPatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        let organizationActivities = activities.filter {
            $0.activityType == .fileOrganized || $0.activityType == .fileMoved
        }

        var patterns: [LearnedPattern] = []

        // Group activities by time category
        let timeCategories = Dictionary(grouping: organizationActivities) { activity -> LearnedPattern.TimeCategory in
            let context = TemporalContext(from: activity.timestamp)
            if !context.isWorkHours && (context.dayOfWeek == 1 || context.dayOfWeek == 7) {
                return .weekends
            } else if context.isWorkHours {
                return .workHours
            } else if context.hourOfDay >= 5 && context.hourOfDay < 12 {
                return .mornings
            } else {
                return .evenings
            }
        }

        // For each time category, look for extension/destination patterns
        for (timeCategory, activitiesInTimeSlot) in timeCategories {
            guard activitiesInTimeSlot.count >= minimumOccurrences else { continue }

            let extensionGroups = Dictionary(grouping: activitiesInTimeSlot) { $0.fileExtension ?? "" }

            for (ext, activitiesForExtension) in extensionGroups where !ext.isEmpty {
                let destinationGroups = Dictionary(grouping: activitiesForExtension) {
                    extractDestination(from: $0.details)
                }

                for (destination, activitiesForDestination) in destinationGroups where !destination.isEmpty {
                    let count = activitiesForDestination.count
                    guard count >= minimumOccurrences else { continue }

                    // Check if this pattern is significantly more common in this time slot
                    // vs the overall pattern for this extension
                    let allActivitiesForExt = organizationActivities.filter { $0.fileExtension == ext }
                    let allToDestination = allActivitiesForExt.filter {
                        extractDestination(from: $0.details) == destination
                    }

                    let overallRatio = Double(allToDestination.count) / Double(allActivitiesForExt.count)
                    let timeSlotRatio = Double(count) / Double(activitiesForExtension.count)

                    // Only create temporal pattern if ratio in this time slot is significantly higher
                    guard timeSlotRatio > overallRatio * 1.3 else { continue }

                    let timeCategoryName = timeCategory.rawValue.replacingOccurrences(of: "Hours", with: " hours")
                    let description = "During \(timeCategoryName): Move \(ext.uppercased()) files to \(abbreviatePath(destination))"

                    let pattern = LearnedPattern(
                        patternDescription: description,
                        fileExtension: ext,
                        destinationPath: destination,
                        occurrenceCount: count,
                        confidenceScore: timeSlotRatio,
                        lastSeenDate: activitiesForDestination.map { $0.timestamp }.max() ?? Date()
                    )

                    pattern.addCondition(PatternCondition.fileExtension(ext))
                    pattern.timeCategory = timeCategory

                    // Add temporal contexts from the activities
                    for activity in activitiesForDestination {
                        let context = TemporalContext(from: activity.timestamp)
                        pattern.temporalContexts.append(context)
                    }

                    // Add time condition based on category
                    switch timeCategory {
                    case .workHours:
                        pattern.addCondition(PatternCondition.timeOfDay(startHour: 9, endHour: 17))
                        pattern.addCondition(PatternCondition.dayOfWeek([2, 3, 4, 5, 6])) // Mon-Fri
                    case .evenings:
                        pattern.addCondition(PatternCondition.timeOfDay(startHour: 17, endHour: 23))
                    case .mornings:
                        pattern.addCondition(PatternCondition.timeOfDay(startHour: 5, endHour: 12))
                    case .weekends:
                        pattern.addCondition(PatternCondition.dayOfWeek([1, 7])) // Sun, Sat
                    case .anyTime:
                        break
                    }

                    patterns.append(pattern)
                }
            }
        }

        return patterns
    }

    // MARK: - Negative Pattern Detection

    /// Detect negative patterns from user rejections and skips
    ///
    /// When users consistently skip or reject certain suggestions, we learn
    /// to avoid making those suggestions in the future.
    ///
    /// - Parameter activities: Array of ActivityItem representing user actions
    /// - Returns: Array of negative LearnedPattern objects
    private func detectNegativePatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        // Filter to skipped activities
        let skippedActivities = activities.filter { $0.activityType == .fileSkipped }

        guard skippedActivities.count >= 2 else { return [] }

        var patterns: [LearnedPattern] = []

        // Group skips by extension
        let extensionGroups = Dictionary(grouping: skippedActivities) { $0.fileExtension ?? "" }

        for (ext, skippedForExtension) in extensionGroups where !ext.isEmpty {
            // If users consistently skip files of this extension, create negative pattern
            guard skippedForExtension.count >= 2 else { continue }

            // Look for destinations that were suggested but rejected
            // (parsed from details like "Skipped suggestion for Documents/Work")
            let rejectedDestinations = Dictionary(grouping: skippedForExtension) { activity -> String in
                extractRejectedDestination(from: activity.details)
            }

            for (destination, rejections) in rejectedDestinations where !destination.isEmpty {
                let rejectionCount = rejections.count
                guard rejectionCount >= 2 else { continue }

                // Calculate confidence based on rejection consistency
                let confidence = min(0.9, Double(rejectionCount) / 5.0)

                let description = "Don't suggest \(abbreviatePath(destination)) for \(ext.uppercased()) files"

                let pattern = LearnedPattern(
                    patternDescription: description,
                    fileExtension: ext,
                    destinationPath: destination,
                    occurrenceCount: rejectionCount,
                    confidenceScore: confidence,
                    lastSeenDate: rejections.map { $0.timestamp }.max() ?? Date()
                )

                // Mark as negative pattern
                pattern.convertToNegativePattern()
                pattern.rejectionCount = rejectionCount

                patterns.append(pattern)
            }
        }

        return patterns
    }

    /// Extract rejected destination from skip activity details
    private func extractRejectedDestination(from details: String) -> String {
        let patterns = [
            "Skipped suggestion for ",
            "Rejected ",
            "Skipped: "
        ]

        for pattern in patterns {
            if let range = details.range(of: pattern, options: .caseInsensitive) {
                return String(details[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ""
    }

    // MARK: - Pattern Deduplication

    /// Remove duplicate patterns, preferring more specific ones
    private func deduplicatePatterns(_ patterns: [LearnedPattern]) -> [LearnedPattern] {
        var result: [LearnedPattern] = []
        var seen: Set<String> = []

        // Sort by specificity (more conditions = more specific)
        let sorted = patterns.sorted { p1, p2 in
            if p1.conditions.count != p2.conditions.count {
                return p1.conditions.count > p2.conditions.count
            }
            return p1.confidenceScore > p2.confidenceScore
        }

        for pattern in sorted {
            // Create a signature for deduplication
            let signature = "\(pattern.fileExtension)-\(pattern.destinationPath)"

            // For multi-condition patterns, include conditions in signature
            if pattern.conditions.count > 1 {
                let conditionSig = pattern.conditions.map { "\($0)" }.sorted().joined(separator: ",")
                let fullSignature = "\(signature)-\(conditionSig)"
                if !seen.contains(fullSignature) {
                    seen.insert(fullSignature)
                    result.append(pattern)
                }
            } else {
                // For simple patterns, only add if no more specific pattern exists
                let hasMoreSpecific = result.contains { existing in
                    existing.fileExtension == pattern.fileExtension &&
                    existing.destinationPath == pattern.destinationPath &&
                    existing.conditions.count > pattern.conditions.count
                }

                if !hasMoreSpecific && !seen.contains(signature) {
                    seen.insert(signature)
                    result.append(pattern)
                }
            }
        }

        return result
    }

    // MARK: - Suggestion Filtering

    /// Filter suggestions by applying negative patterns
    ///
    /// - Parameters:
    ///   - suggestions: Positive patterns to filter
    ///   - negativePatterns: Negative patterns to apply
    /// - Returns: Filtered suggestions with bad matches removed
    func filterSuggestionsWithNegativePatterns(
        suggestions: [LearnedPattern],
        negativePatterns: [LearnedPattern]
    ) -> [LearnedPattern] {
        return suggestions.filter { suggestion in
            // Check if any negative pattern should suppress this suggestion
            for negative in negativePatterns where negative.isNegativePattern {
                if negative.shouldSuppress(
                    fileExtension: suggestion.fileExtension,
                    destination: suggestion.destinationPath
                ) {
                    return false
                }
            }
            return true
        }
    }

    /// Filter suggestions using both negative patterns and file-level rejections
    ///
    /// - Parameters:
    ///   - suggestions: Positive patterns to filter
    ///   - negativePatterns: Negative patterns from the model
    ///   - files: Files being organized (to check rejection history)
    /// - Returns: Filtered suggestions
    func filterSuggestions(
        _ suggestions: [LearnedPattern],
        withNegativePatterns negativePatterns: [LearnedPattern],
        forFiles files: [FileItem]
    ) -> [LearnedPattern] {
        // First filter by negative patterns
        var filtered = filterSuggestionsWithNegativePatterns(
            suggestions: suggestions,
            negativePatterns: negativePatterns
        )

        // Then check file-level rejection history
        filtered = filtered.filter { suggestion in
            // If any file has rejected this destination multiple times, lower priority
            let rejectedByFiles = files.filter { file in
                file.rejectedDestination == suggestion.destinationPath &&
                file.rejectionCount >= 2
            }

            // If more than half the relevant files rejected this destination, suppress
            let relevantFiles = files.filter { $0.fileExtension == suggestion.fileExtension }
            if !relevantFiles.isEmpty {
                let rejectionRate = Double(rejectedByFiles.count) / Double(relevantFiles.count)
                if rejectionRate > 0.5 {
                    return false
                }
            }

            return true
        }

        return filtered
    }

    // MARK: - Rule Conversion

    /// Convert a learned pattern into a permanent Rule
    ///
    /// Uses the pattern's `toRule()` method which properly handles both
    /// simple and compound conditions, preserving all learned information.
    ///
    /// - Parameter pattern: The LearnedPattern to convert
    /// - Returns: A new Rule object with conditions matching the pattern
    func convertPatternToRule(_ pattern: LearnedPattern) -> Rule {
        // Use the enhanced toRule() method on LearnedPattern
        // which properly handles compound conditions
        return pattern.toRule()
    }

    /// Determine if a pattern should be suggested to the user
    ///
    /// - Parameter pattern: The LearnedPattern to evaluate
    /// - Returns: Boolean indicating if the pattern should be suggested
    func shouldSuggestPattern(_ pattern: LearnedPattern) -> Bool {
        // Check feature flag for suggestions
        guard FeatureFlagService.shared.isEnabled(.ruleSuggestions) else {
            return false
        }
        return pattern.shouldSuggest
    }
    
    /// Update existing patterns with new activities or create new ones
    ///
    /// - Parameters:
    ///   - existingPatterns: Array of existing LearnedPattern objects
    ///   - newActivities: New ActivityItem objects to analyze
    /// - Returns: Updated array of LearnedPattern objects
    func updatePatterns(
        existing existingPatterns: [LearnedPattern],
        with newActivities: [ActivityItem]
    ) -> [LearnedPattern] {
        // Detect new patterns from all activities
        let newPatterns = detectPatterns(from: newActivities)
        
        var updatedPatterns: [LearnedPattern] = []
        
        // Merge existing patterns with new detections
        for existingPattern in existingPatterns {
            // Find matching pattern in new detections
            if let matchingNew = newPatterns.first(where: { 
                $0.fileExtension == existingPattern.fileExtension &&
                $0.destinationPath == existingPattern.destinationPath
            }) {
                // Update existing pattern with new data
                existingPattern.recordNewOccurrence(confidenceScore: matchingNew.confidenceScore)
                updatedPatterns.append(existingPattern)
            } else {
                // Keep existing pattern as-is
                updatedPatterns.append(existingPattern)
            }
        }
        
        // Add genuinely new patterns (not in existing)
        for newPattern in newPatterns {
            let isNew = !existingPatterns.contains { existing in
                existing.fileExtension == newPattern.fileExtension &&
                existing.destinationPath == newPattern.destinationPath
            }
            
            if isNew {
                updatedPatterns.append(newPattern)
            }
        }
        
        return updatedPatterns
    }
    
    // MARK: - ML Training Data Extraction (Phase 3)
    
    /// Create training records from activity history for ML model training.
    ///
    /// Reuses existing parsing helpers to extract features without duplication.
    /// Only includes organization activities (fileOrganized, fileMoved, ruleApplied).
    ///
    /// - Parameter activities: Array of ActivityItem representing user actions
    /// - Returns: Array of DestinationTrainingRecord for ML training
    func makeTrainingRecords(from activities: [ActivityItem]) -> [DestinationTrainingRecord] {
        // Filter to organization activities only
        let relevantActivities = activities.filter {
            $0.activityType == .fileOrganized || 
            $0.activityType == .fileMoved || 
            $0.activityType == .ruleApplied
        }
        
        var records: [DestinationTrainingRecord] = []
        
        for activity in relevantActivities {
            let destination = extractDestination(from: activity.details)
            guard !destination.isEmpty else { continue }
            
            // Extract extension from activity or parse from fileName
            let ext = activity.fileExtension ?? parseExtension(from: activity.fileName)
            guard !ext.isEmpty else { continue }
            
            // Infer source location from activity details
            let sourceLocation = inferSourceLocation(from: activity.details)
            
            let record = DestinationTrainingRecord(
                fileName: activity.fileName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                fileExtension: ext,
                sourceLocation: sourceLocation,
                destinationPath: normalizePath(destination),
                timestamp: activity.timestamp,
                projectCluster: nil // Will be populated by DestinationPredictionService if needed
            )
            
            records.append(record)
        }
        
        return records
    }
    
    /// Record the outcome of an ML prediction for learning purposes.
    ///
    /// Creates ActivityItem entries and updates FileItem rejection tracking
    /// so negative learning continues to work with ML predictions.
    ///
    /// - Parameters:
    ///   - file: The FileItem that received a prediction
    ///   - predictedPath: The path predicted by the ML model
    ///   - outcome: The user's action on the prediction
    func recordPredictionOutcome(file: FileItem, predictedPath: String, outcome: PredictionOutcome) {
        // Note: In a full implementation, this would append ActivityItem to modelContext
        // For now, we update the FileItem rejection tracking for negative patterns
        
        switch outcome {
        case .overridden, .dismissed:
            // User rejected the prediction - update rejection tracking
            file.rejectedDestination = predictedPath
            file.rejectionCount += 1
            
        case .accepted:
            // Reset rejection tracking on acceptance
            file.rejectionCount = 0
            file.rejectedDestination = nil
            
        case .unknown:
            break
        }
    }
    
    // MARK: - Pattern Matching
    
    /// Find the first matching pattern for a given file
    ///
    /// Checks patterns in order (sorted by confidence), returning the first match.
    /// Handles both simple and multi-condition patterns.
    ///
    /// - Parameters:
    ///   - file: The file (Fileable) to match against
    ///   - patterns: Array of LearnedPattern objects to check
    /// - Returns: The first matching LearnedPattern, or nil if none match
    func findMatchingPattern<F: Fileable>(for file: F, in patterns: [LearnedPattern]) -> LearnedPattern? {
        // Iterate through patterns (should already be sorted by confidence)
        for pattern in patterns {
            // Skip negative patterns
            guard !pattern.isNegativePattern else { continue }
            
            // Skip rejected patterns
            guard pattern.rejectionCount < 3 else { continue }
            
            // Simple pattern: just check extension
            if pattern.conditions.count == 1, 
               case .fileExtension(let ext) = pattern.conditions[0] {
                if file.fileExtension.lowercased() == ext.lowercased() {
                    return pattern
                }
                continue
            }
            
            // Multi-condition pattern: check all conditions
            let allMatch = pattern.conditions.allSatisfy { condition in
                switch condition {
                case .fileExtension(let ext):
                    return file.fileExtension.lowercased() == ext.lowercased()
                    
                case .nameContains(let substring):
                    return file.name.lowercased().contains(substring.lowercased())
                    
                case .nameStartsWith(let prefix):
                    return file.name.lowercased().hasPrefix(prefix.lowercased())
                    
                case .nameEndsWith(let suffix):
                    return file.name.lowercased().hasSuffix(suffix.lowercased())
                    
                case .sizeRange(let minBytes, let maxBytes):
                    return file.sizeInBytes >= minBytes && file.sizeInBytes <= maxBytes
                    
                case .timeOfDay(let startHour, let endHour):
                    // Check current time
                    let calendar = Calendar.current
                    let now = Date()
                    let hour = calendar.component(.hour, from: now)
                    return hour >= startHour && hour < endHour
                    
                case .dayOfWeek(let days):
                    // Check current day of week
                    let calendar = Calendar.current
                    let now = Date()
                    let weekday = calendar.component(.weekday, from: now)
                    return days.contains(weekday)
                }
            }
            
            if allMatch {
                return pattern
            }
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    /// Extract destination path from activity details string
    ///
    /// Examples:
    /// - "Moved to Documents/Finance" → "Documents/Finance"
    /// - "Organized to ~/Pictures/Screenshots" → "~/Pictures/Screenshots"
    ///
    /// - Parameter details: The activity details string
    /// - Returns: Extracted destination path or empty string
    private func extractDestination(from details: String) -> String {
        // Common patterns in activity details
        let patterns = [
            "Moved to ",
            "Organized to ",
            "to "
        ]
        
        for pattern in patterns {
            if let range = details.range(of: pattern, options: .caseInsensitive) {
                let destination = String(details[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return destination
            }
        }
        
        return ""
    }

    /// Abbreviate a path for display purposes
    ///
    /// - Parameter path: The full path to abbreviate
    /// - Returns: Shortened path (e.g., "~/Documents/Work" or "…/Finance/Invoices")
    private func abbreviatePath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        var result = path
        if result.hasPrefix(homeDir) {
            result = "~" + result.dropFirst(homeDir.count)
        }

        // Truncate if too long
        if result.count > 35 {
            let components = result.split(separator: "/")
            if components.count > 2 {
                return "…/" + components.suffix(2).joined(separator: "/")
            }
        }

        return result
    }
    
    /// Parse file extension from filename
    private func parseExtension(from fileName: String) -> String {
        let url = URL(fileURLWithPath: fileName)
        return url.pathExtension
    }
    
    /// Infer source location from activity details
    /// Examples: "Added from Desktop", "Scanned from Downloads"
    private func inferSourceLocation(from details: String) -> String? {
        let lowercased = details.lowercased()
        
        if lowercased.contains("desktop") {
            return "Desktop"
        } else if lowercased.contains("downloads") {
            return "Downloads"
        } else if lowercased.contains("documents") {
            return "Documents"
        } else if lowercased.contains("pictures") {
            return "Pictures"
        }
        
        return nil
    }
    
    /// Normalize a destination path (tilde-ify home directory)
    private func normalizePath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        
        return path
    }
}
