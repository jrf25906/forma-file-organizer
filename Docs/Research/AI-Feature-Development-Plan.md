# Forma AI Feature Development Plan

> **Strategic plan for enhancing Forma's existing AI capabilities with advanced intelligence features**
>
> **Created:** December 1, 2025  
> **Status:** Partially Implemented (Phases 1 & 2 Complete)
> **Last Updated:** December 1, 2025
> **Foundation:** Builds on existing `LearningService`, `LearnedPattern`, and `RuleSuggestionView`

---

## Executive Summary

Forma already has a **solid AI foundation** with smart rule suggestions, pattern learning, and confidence scoring. This plan outlines how to evolve from basic pattern detection to advanced, context-aware intelligence that differentiates Forma from competitors.

**Key Insight:** We don't need to build AI from scratch—we need to **deepen and expand** the existing learning capabilities.

---

## Current AI Capabilities ✅

### What We Already Have

| Component | Status | Purpose |
|-----------|--------|---------|
| `LearnedPattern` model | ✅ Built | Stores detected user behavior patterns |
| `LearningService` | ✅ Built | Detects patterns from ActivityItem history |
| `RuleSuggestionView` | ✅ Built | Shows pattern suggestions with confidence |
| Confidence scoring | ✅ Built | Frequency-based (0.5-1.0 range) |
| Rejection tracking | ✅ Built | Suppresses patterns after 3 rejections |
| Pattern → Rule conversion | ✅ Built | One-click rule creation |
| Match reasoning | ✅ Built | `matchReason` in FileItem |

### How It Works Today

```
User organizes files manually
    ↓
ActivityItem records actions
    ↓
LearningService detects patterns (3+ occurrences)
    ↓
LearnedPattern created with confidence score
    ↓
RuleSuggestionView shows suggestion
    ↓
User clicks "Create Rule" → Permanent automation
```

**Current Algorithm:**
```swift
// Basic frequency-based pattern detection
if (occurrenceCount >= 3) {
    confidence = occurrenceCount / totalMovesForExtension
    if (confidence >= 0.5) {
        suggestPattern()
    }
}
```

---

## Enhancement Roadmap

### Phase 1: Intelligent Pattern Detection ✅ COMPLETE

**Goal:** Make pattern detection smarter and more context-aware

**Implementation Status:** All Phase 1 features have been implemented.

---

#### Feature 1.1: Multi-Condition Pattern Detection ✅

**Current Limitation:** Only detects single-condition patterns (extension → destination)

**Enhancement:** Detect compound patterns with multiple attributes

**Example:**
```
Current:
  "PDF → Documents/Finance" (5 times)
  
Enhanced:
  "PDF + name contains 'invoice' → Documents/Finance/Invoices" (5 times)
  "PDF + name contains 'contract' → Documents/Legal" (4 times)
```

**Implementation:**

```swift
// Enhanced LearnedPattern model
@Model
final class LearnedPattern {
    // Existing fields...
    
    // NEW: Support compound conditions
    var conditions: [PatternCondition]
    var logicalOperator: Rule.LogicalOperator
}

enum PatternCondition: Codable {
    case fileExtension(String)
    case nameContains(String)
    case nameStartsWith(String)
    case sizeRange(min: Int64, max: Int64)
    case dateRange(olderThan: Int, newerThan: Int)
}
```

**LearningService Enhancement:**

```swift
class LearningService {
    // NEW: Analyze filename patterns within extension groups
    func detectAdvancedPatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        let extensionGroups = Dictionary(grouping: activities) { $0.fileExtension }
        
        for (ext, activities) in extensionGroups {
            // Extract common filename patterns
            let namePatterns = extractNamePatterns(from: activities)
            
            // Group by (extension + namePattern + destination)
            for pattern in namePatterns {
                let matchingActivities = activities.filter { 
                    $0.fileName.contains(pattern, options: .caseInsensitive) 
                }
                
                if matchingActivities.count >= 3 {
                    // Create compound pattern
                    createCompoundPattern(
                        extension: ext,
                        namePattern: pattern,
                        destination: mostCommonDestination(matchingActivities)
                    )
                }
            }
        }
    }
    
    private func extractNamePatterns(from activities: [ActivityItem]) -> [String] {
        // Find common keywords in filenames
        // E.g., ["invoice", "receipt", "contract", "screenshot", "IMG_"]
    }
}
```

**Files Modified:**
- `Models/LearnedPattern.swift` - ✅ Added `PatternCondition` enum with `.fileExtension`, `.nameContains`, `.nameStartsWith`, `.sizeRange`, `.dateRange` cases
- `Models/LearnedPattern.swift` - ✅ Added `conditions: [PatternCondition]` array and `logicalOperator` property
- `Services/LearningService.swift` - ✅ Added `detectMultiConditionPatterns()` method with keyword extraction

**Time Estimate:** 3-4 days → ✅ Completed

**Success Metric:** 30% of suggestions use multiple conditions

---

#### Feature 1.2: Temporal Pattern Analysis ✅

**Current Limitation:** Patterns are detected purely by frequency, ignoring time

**Enhancement:** Detect time-based patterns and work session relationships

**Examples:**
```
Pattern: "Files created during work hours (9-5) → Work folder"
Pattern: "Files created on weekends → Personal folder"
Pattern: "Files modified within 10 minutes of each other → Same project"
```

**Implementation:**

```swift
struct TemporalCluster {
    var files: [FileItem]
    var sessionStart: Date
    var sessionEnd: Date
    var commonAttributes: [String: Any]
}

class LearningService {
    // NEW: Detect work sessions
    func detectWorkSessions(from activities: [ActivityItem]) -> [TemporalCluster] {
        // Sort by timestamp
        let sorted = activities.sorted { $0.timestamp < $1.timestamp }
        
        var clusters: [TemporalCluster] = []
        var currentCluster: [ActivityItem] = []
        
        for activity in sorted {
            if let last = currentCluster.last {
                let timeDiff = activity.timestamp.timeIntervalSince(last.timestamp)
                
                // Files within 10 minutes are part of same session
                if timeDiff < 600 { // 10 minutes
                    currentCluster.append(activity)
                } else {
                    // Session ended, analyze cluster
                    if currentCluster.count >= 3 {
                        clusters.append(analyzeCluster(currentCluster))
                    }
                    currentCluster = [activity]
                }
            } else {
                currentCluster.append(activity)
            }
        }
        
        return clusters
    }
    
    // NEW: Detect time-of-day patterns
    func detectTimePatterns(from activities: [ActivityItem]) -> [TimePattern] {
        let calendar = Calendar.current
        
        // Group by hour of day
        let hourGroups = Dictionary(grouping: activities) { activity in
            calendar.component(.hour, from: activity.timestamp)
        }
        
        // Detect "work hours" vs "personal time" patterns
        let workHours = hourGroups.filter { hour, _ in (9...17).contains(hour) }
        let personalHours = hourGroups.filter { hour, _ in !(9...17).contains(hour) }
        
        // Analyze destination patterns for each time period
    }
}

struct TimePattern {
    var timeRange: String // "9am-5pm", "Weekends", "Evenings"
    var commonDestination: String
    var occurrenceCount: Int
    var confidence: Double
}
```

**Files Modified:**
- `Models/LearnedPattern.swift` - ✅ Added `TemporalContext` struct with `timeOfDay`, `dayOfWeek`, `isWorkHours`, `isWeekend` properties
- `Models/LearnedPattern.swift` - ✅ Added `temporalContext: TemporalContext?` to LearnedPattern
- `Services/LearningService.swift` - ✅ Added `detectTemporalPatterns()` method analyzing work hours (9-17), weekends, and time-of-day patterns
- `Views/AIInsightsView.swift` - ✅ Integrated temporal patterns into unified insights view

**Time Estimate:** 3-4 days → ✅ Completed

**Success Metric:** Detect 70%+ of related files within work sessions

---

#### Feature 1.3: Negative Pattern Learning ✅

**Current Limitation:** Only learns what users DO, not what they DON'T do

**Enhancement:** Track rejected suggestions and anti-patterns

**Example:**
```
Pattern: User NEVER moves screenshots to Documents
Confidence: 100% (0/15 times)

Action: Suppress any rules suggesting screenshots → Documents
```

**Implementation:**

```swift
@Model
final class LearnedPattern {
    // Existing fields...
    
    // NEW: Track negative patterns
    var negativePattern: Bool = false
    var suppressedRuleIds: [UUID] = []
}

class LearningService {
    // NEW: Detect anti-patterns
    func detectNegativePatterns(
        from rejections: [RejectedSuggestion],
        existingPatterns: [LearnedPattern]
    ) -> [LearnedPattern] {
        // Group rejections by (extension + destination)
        let rejectionGroups = Dictionary(grouping: rejections) { rejection in
            "\(rejection.fileExtension)->\(rejection.suggestedDestination)"
        }
        
        var antiPatterns: [LearnedPattern] = []
        
        for (key, rejectionList) in rejectionGroups where rejectionList.count >= 3 {
            // User has consistently rejected this suggestion
            let antiPattern = LearnedPattern(
                patternDescription: "Never move \(extension) to \(destination)",
                fileExtension: rejectionList[0].fileExtension,
                destinationPath: rejectionList[0].suggestedDestination,
                occurrenceCount: rejectionList.count,
                confidenceScore: 1.0,
                negativePattern: true
            )
            
            antiPatterns.append(antiPattern)
        }
        
        return antiPatterns
    }
    
    // NEW: Filter suggestions using negative patterns
    func filterSuggestions(
        _ patterns: [LearnedPattern],
        negativePatterns: [LearnedPattern]
    ) -> [LearnedPattern] {
        return patterns.filter { pattern in
            !negativePatterns.contains { negative in
                negative.fileExtension == pattern.fileExtension &&
                negative.destinationPath == pattern.destinationPath
            }
        }
    }
}

// NEW: Track rejections
struct RejectedSuggestion {
    var fileExtension: String
    var suggestedDestination: String
    var timestamp: Date
    var userReason: String? // Optional: "Not relevant", "Wrong folder", etc.
}
```

**Files Modified:**
- `Models/LearnedPattern.swift` - ✅ Added `isNegativePattern: Bool`, `suppressedRuleIds: [UUID]`, and `shouldSuppress()` methods
- `Services/LearningService.swift` - ✅ Added `detectNegativePatterns()` method that analyzes rejections and creates anti-patterns
- `Services/LearningService.swift` - ✅ Added `filterSuggestions()` method to exclude patterns matching negative patterns

**Time Estimate:** 2-3 days → ✅ Completed

**Success Metric:** 90% reduction in repeatedly rejected suggestions

---

### Phase 2: Context-Aware Intelligence ✅ COMPLETE

**Goal:** Understand file relationships and project context

**Implementation Status:** All Phase 2 features have been implemented.

---

#### Feature 2.1: Project/Client Detection ✅

**Current Limitation:** Files treated individually, no understanding of relationships

**Enhancement:** Detect when multiple files belong to same project/client

**Detection Strategies:**

1. **Common Naming Prefixes**
```
ClientABC_proposal.docx
ClientABC_invoice.pdf
ClientABC_contract.pdf
→ Detected project: "ClientABC" (3 files)
```

2. **Ticket/Issue Numbers**
```
JIRA-123_bugfix.swift
JIRA-123_tests.swift
JIRA-123_screenshot.png
→ Detected project: "JIRA-123" (3 files)
```

3. **Date-Based Grouping**
```
2024-03-15_meeting_notes.docx
2024-03-15_presentation.pptx
2024-03-15_budget.xlsx
→ Detected project: "2024-03-15 Meeting" (3 files)
```

**Implementation:**

```swift
@Model
final class ProjectCluster {
    var id: UUID
    var projectName: String
    var detectionMethod: DetectionMethod
    var files: [String] // File paths
    var suggestedFolderStructure: String
    var confidence: Double
    var firstDetected: Date
    
    enum DetectionMethod: String, Codable {
        case namePrefix      // "ClientABC_"
        case ticketNumber    // "JIRA-123"
        case dateGrouping    // "2024-03-15"
        case temporal        // Modified within same session
    }
}

class ContextDetectionService {
    // Regex patterns for common project naming
    private let projectPatterns = [
        #"P-\d{4}"#,              // P-1024
        #"CLIENT[_-][A-Z]+"#,     // CLIENT_ABC
        #"\d{4}-\d{2}-\d{2}"#,    // 2024-03-15
        #"[A-Z]{2,5}-\d{2,4}"#,   // JIRA-456, ABC-123
    ]
    
    func detectProjects(from files: [FileItem]) -> [ProjectCluster] {
        var clusters: [ProjectCluster] = []
        
        // Strategy 1: Name prefix detection
        let prefixClusters = detectByPrefix(files)
        clusters.append(contentsOf: prefixClusters)
        
        // Strategy 2: Regex pattern matching
        let patternClusters = detectByPattern(files)
        clusters.append(contentsOf: patternClusters)
        
        // Strategy 3: Temporal clustering (from Feature 1.2)
        let temporalClusters = detectByTiming(files)
        clusters.append(contentsOf: temporalClusters)
        
        // Filter: Only keep clusters with 3+ files
        return clusters.filter { $0.files.count >= 3 }
    }
    
    private func detectByPrefix(_ files: [FileItem]) -> [ProjectCluster] {
        // Find common prefixes before first underscore or hyphen
        let prefixGroups = Dictionary(grouping: files) { file in
            extractPrefix(from: file.name)
        }
        
        return prefixGroups.compactMap { prefix, files in
            guard files.count >= 3 else { return nil }
            
            return ProjectCluster(
                projectName: prefix,
                detectionMethod: .namePrefix,
                files: files.map { $0.path },
                suggestedFolderStructure: "\(prefix)/",
                confidence: calculatePrefixConfidence(prefix, files: files),
                firstDetected: Date()
            )
        }
    }
    
    private func extractPrefix(from filename: String) -> String {
        // Extract text before first underscore, hyphen, or space
        let separators = CharacterSet(charactersIn: "_- ")
        return filename.components(separatedBy: separators).first ?? ""
    }
}
```

**UI Integration:**

```swift
struct ProjectClusterCard: View {
    let cluster: ProjectCluster
    let onOrganize: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.title2)
                    .foregroundColor(.formaSteelBlue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project detected: \(cluster.projectName)")
                        .font(.formaH3)
                    
                    Text("\(cluster.files.count) related files")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }
                
                Spacer()
                
                ConfidenceBadge(score: cluster.confidence)
            }
            
            // Preview files
            ForEach(cluster.files.prefix(3), id: \.self) { path in
                HStack {
                    Image(systemName: "doc.fill")
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.formaSmall)
                        .lineLimit(1)
                }
            }
            
            if cluster.files.count > 3 {
                Text("+ \(cluster.files.count - 3) more files")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
            }
            
            // Action
            Button(action: onOrganize) {
                HStack {
                    Image(systemName: "folder.fill.badge.plus")
                    Text("Create \"\(cluster.projectName)\" folder & organize")
                }
                .font(.formaBodySemibold)
                .foregroundColor(.white)
                .padding()
                .background(Color.formaSteelBlue)
                .cornerRadius(FormaRadius.control)
            }
        }
        .padding()
        .background(Color.white.opacity(0.6))
        .cornerRadius(FormaRadius.card)
    }
}
```

**Files Created:**
- `Models/ProjectCluster.swift` - ✅ Created with `ClusterType` enum (`.projectCode`, `.temporal`, `.nameSimilarity`, `.dateStamp`)
- `Services/ContextDetectionService.swift` - ✅ Created with prefix detection, regex pattern matching, and temporal clustering
- `Views/ProjectClusterView.swift` - ✅ Created with expandable cluster cards showing related files
- `Views/AIInsightsView.swift` - ✅ Integrated project clusters into unified insights view

**Time Estimate:** 5-6 days → ✅ Completed

**Success Metric:** Detect 80%+ of obvious project relationships

---

#### Feature 2.2: Duplicate & Similar File Detection ✅

**Current Limitation:** No awareness of duplicate or near-duplicate files

**Enhancement:** Detect exact and similar files, suggest cleanup

**Detection Strategies:**

1. **Exact Duplicates** (SHA-256 hash)
2. **Near-Duplicates** (filename similarity)
3. **Version Detection** (file_v1.pdf, file_v2.pdf, file_final.pdf)
4. **Image Similarity** (perceptual hashing for photos)

**Implementation:**

```swift
struct DuplicateGroup {
    var originalFile: FileItem
    var duplicates: [DuplicateCandidate]
    var groupType: DuplicateType
    var recommendedAction: RecommendedAction
    
    enum DuplicateType {
        case exactCopy        // Identical hash
        case versionSeries    // file_v1, file_v2, file_final
        case similarName      // 90%+ name similarity
        case nearDuplicate    // Similar but not identical (images)
    }
    
    enum RecommendedAction {
        case keepNewest
        case keepLargest
        case keepBestQuality // For images
        case manualReview
    }
}

struct DuplicateCandidate {
    var file: FileItem
    var similarity: Double // 0.0-1.0
    var reason: String // "Identical content" / "Similar name" / "Version suffix"
}

class DuplicateDetectionService {
    // Strategy 1: Hash-based exact duplicates
    func findExactDuplicates(_ files: [FileItem]) async -> [DuplicateGroup] {
        var hashGroups: [String: [FileItem]] = [:]
        
        for file in files {
            let hash = await calculateSHA256(for: file.path)
            hashGroups[hash, default: []].append(file)
        }
        
        return hashGroups.values.compactMap { group in
            guard group.count > 1 else { return nil }
            
            let sorted = group.sorted { $0.creationDate > $1.creationDate }
            return DuplicateGroup(
                originalFile: sorted[0],
                duplicates: sorted.dropFirst().map {
                    DuplicateCandidate(file: $0, similarity: 1.0, reason: "Identical content")
                },
                groupType: .exactCopy,
                recommendedAction: .keepNewest
            )
        }
    }
    
    // Strategy 2: Version series detection
    func findVersionSeries(_ files: [FileItem]) -> [DuplicateGroup] {
        // Look for patterns: _v1, _v2, _final, _draft, _FINAL, etc.
        let versionPatterns = [
            #"_v\d+$"#,           // _v1, _v2
            #"_final$"#,          // _final
            #"_draft$"#,          // _draft
            #" \(\d+\)$"#,        // (1), (2) - macOS copy suffix
        ]
        
        // Group files with same base name
        let baseNameGroups = Dictionary(grouping: files) { file in
            removeVersionSuffix(from: file.name)
        }
        
        return baseNameGroups.compactMap { baseName, versionFiles in
            guard versionFiles.count > 1 else { return nil }
            
            // Determine which is "final" version
            let final = selectFinalVersion(from: versionFiles)
            let others = versionFiles.filter { $0.id != final.id }
            
            return DuplicateGroup(
                originalFile: final,
                duplicates: others.map {
                    DuplicateCandidate(
                        file: $0,
                        similarity: 0.95,
                        reason: "Earlier version of \(final.name)"
                    )
                },
                groupType: .versionSeries,
                recommendedAction: .keepNewest
            )
        }
    }
    
    // Strategy 3: Name similarity (Levenshtein distance)
    func findSimilarNames(_ files: [FileItem]) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        
        for (i, file1) in files.enumerated() {
            var similarFiles: [DuplicateCandidate] = []
            
            for file2 in files.dropFirst(i + 1) {
                let similarity = calculateSimilarity(file1.name, file2.name)
                
                if similarity > 0.85 { // 85%+ similar
                    similarFiles.append(DuplicateCandidate(
                        file: file2,
                        similarity: similarity,
                        reason: "Similar name (\(Int(similarity * 100))% match)"
                    ))
                }
            }
            
            if !similarFiles.isEmpty {
                groups.append(DuplicateGroup(
                    originalFile: file1,
                    duplicates: similarFiles,
                    groupType: .similarName,
                    recommendedAction: .manualReview
                ))
            }
        }
        
        return groups
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        // Levenshtein distance algorithm
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func selectFinalVersion(from files: [FileItem]) -> FileItem {
        // Priority: "final" > "FINAL" > highest version number > newest
        if let final = files.first(where: { $0.name.lowercased().contains("final") }) {
            return final
        }
        
        // Extract version numbers and return highest
        let versioned = files.compactMap { file -> (FileItem, Int)? in
            if let version = extractVersionNumber(from: file.name) {
                return (file, version)
            }
            return nil
        }
        
        if let highest = versioned.max(by: { $0.1 < $1.1 }) {
            return highest.0
        }
        
        // Fallback: newest file
        return files.max { $0.creationDate < $1.creationDate } ?? files[0]
    }
}
```

**UI Integration:**

```swift
struct DuplicatesView: View {
    let groups: [DuplicateGroup]
    let onCleanup: ([FileItem]) -> Void
    
    var totalDuplicates: Int {
        groups.reduce(0) { $0 + $1.duplicates.count }
    }
    
    var reclaimableSpace: Int64 {
        groups.reduce(0) { total, group in
            total + group.duplicates.reduce(0) { $0 + $1.file.sizeInBytes }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with stats
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .font(.title2)
                    .foregroundColor(.formaWarmOrange)
                
                VStack(alignment: .leading) {
                    Text("\(totalDuplicates) duplicate files found")
                        .font(.formaH3)
                    
                    Text("Reclaim \(formatBytes(reclaimableSpace)) of space")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }
                
                Spacer()
                
                Button("Clean Up All") {
                    let toDelete = groups.flatMap { $0.duplicates.map { $0.file } }
                    onCleanup(toDelete)
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Groups
            ForEach(groups, id: \.originalFile.id) { group in
                DuplicateGroupCard(group: group)
            }
        }
    }
}
```

**Files Created:**
- `Services/DuplicateDetectionService.swift` - ✅ Created with `DuplicateType` enum (`.exactDuplicate`, `.versionSeries`, `.nearDuplicate`)
- `Services/DuplicateDetectionService.swift` - ✅ Implemented SHA-256 hash-based exact duplicate detection
- `Services/DuplicateDetectionService.swift` - ✅ Implemented Levenshtein distance for filename similarity detection
- `Services/DuplicateDetectionService.swift` - ✅ Implemented version series detection (v1, v2, _final, etc.)
- `Views/DuplicateGroupsView.swift` - ✅ Created with expandable duplicate group cards and keep/remove actions
- `Views/AIInsightsView.swift` - ✅ Integrated duplicates into unified insights view with space savings display

**Time Estimate:** 4-5 days → ✅ Completed

**Success Metric:** Detect 95%+ of obvious duplicates, <5% false positives

---

### Phase 3: Predictive Intelligence (Weeks 5-6) — Not Started

**Goal:** Predict destinations without explicit rules using ML

---

#### Feature 3.1: Destination Prediction Model

**Current Limitation:** Without matching rule, files remain "pending"

**Enhancement:** ML model predicts destination based on file attributes + history

**Approach:** Use Core ML with Create ML for training

**Training Data:**
```swift
struct TrainingExample {
    // Input features
    var fileExtension: String
    var fileNameKeywords: [String]
    var fileSize: Int64
    var creationHour: Int       // 0-23
    var creationDayOfWeek: Int  // 1-7
    var sourceFolder: String
    
    // Output (label)
    var destination: String
}
```

**Model Training Flow:**

```swift
class DestinationPredictionService {
    private var model: MLModel?
    
    // Train model from user's history
    func trainModel(from activities: [ActivityItem]) async throws {
        // Convert activities to training examples
        let trainingData = activities.compactMap { activity -> TrainingExample? in
            guard let destination = extractDestination(from: activity.details) else {
                return nil
            }
            
            return TrainingExample(
                fileExtension: activity.fileExtension ?? "",
                fileNameKeywords: extractKeywords(from: activity.fileName),
                fileSize: activity.fileSize ?? 0,
                creationHour: Calendar.current.component(.hour, from: activity.timestamp),
                creationDayOfWeek: Calendar.current.component(.weekday, from: activity.timestamp),
                sourceFolder: extractSourceFolder(from: activity.details),
                destination: destination
            )
        }
        
        // Need at least 50 examples to train
        guard trainingData.count >= 50 else {
            throw PredictionError.insufficientData
        }
        
        // Create Core ML training data
        let mlDataTable = createMLDataTable(from: trainingData)
        
        // Train classifier
        let classifier = try MLTextClassifier(
            trainingData: mlDataTable,
            textColumn: "fileNameKeywords",
            labelColumn: "destination"
        )
        
        // Save model
        let modelURL = try classifier.write(to: modelDirectory())
        self.model = try MLModel(contentsOf: modelURL)
    }
    
    // Predict destination for a file
    func predictDestination(for file: FileItem) async -> PredictedDestination? {
        guard let model = model else { return nil }
        
        // Extract features
        let features = extractFeatures(from: file)
        
        // Run prediction
        let prediction = try? model.prediction(from: features)
        
        guard let destination = prediction?.featureValue(for: "destination")?.stringValue,
              let confidence = prediction?.featureValue(for: "confidence")?.doubleValue else {
            return nil
        }
        
        return PredictedDestination(
            path: destination,
            confidence: confidence,
            reasoning: generateReasoning(for: file, destination: destination)
        )
    }
    
    // Retrain periodically as user creates more data
    func shouldRetrain(lastTrainingDate: Date, newActivitiesCount: Int) -> Bool {
        let daysSinceTraining = Date().timeIntervalSince(lastTrainingDate) / 86400
        
        // Retrain if:
        // - More than 30 days since last training, OR
        // - User has 20+ new organization actions
        return daysSinceTraining > 30 || newActivitiesCount >= 20
    }
}

struct PredictedDestination {
    var path: String
    var confidence: Double
    var reasoning: String
    var basedOn: [String] // ["Similar to 15 past files", "Common for PDFs"]
}
```

**UI Integration:**

```swift
struct FileRowWithPrediction: View {
    let file: FileItem
    let prediction: PredictedDestination?
    
    var body: some View {
        HStack {
            FileIcon(file: file)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.formaBody)
                
                if let pred = prediction {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.formaSmall)
                            .foregroundColor(.formaSteelBlue)
                        
                        Text("AI suggests: \(pred.path)")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabel)
                        
                        ConfidenceBadge(score: pred.confidence)
                    }
                }
            }
            
            Spacer()
            
            if prediction != nil {
                Button("Accept") {
                    // Use AI suggestion
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
```

**Files to Create:**
- `Services/DestinationPredictionService.swift` - ML training & prediction
- `Models/PredictedDestination.swift` - Prediction result
- `Services/MLModelManager.swift` - Model lifecycle management

**Time Estimate:** 6-7 days

**Success Metric:** 70%+ accuracy on test set, 60%+ user acceptance rate

---

#### Feature 3.2: Natural Language Rule Creation

**Current Limitation:** Users must use UI form to create rules

**Enhancement:** Type rules in plain English, auto-convert to structured rule

**Examples:**
```
"Move PDFs older than 30 days to Archive"
→ Condition: extension = pdf AND dateOlderThan = 30
→ Action: move to ~/Archive

"Delete screenshots from last week"  
→ Condition: extension = png AND nameContains = "Screenshot" AND dateOlderThan = 7
→ Action: delete

"Organize work documents by month"
→ Condition: nameContains = "work"
→ Action: move to ~/Documents/Work/{YYYY-MM}/
```

**Implementation using Natural Language Framework:**

```swift
import NaturalLanguage

class NaturalLanguageRuleParser {
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
    
    func parse(_ text: String) -> ParsedRule? {
        tagger.string = text
        
        var parsedRule = ParsedRule()
        
        // Extract action (move, delete, copy, organize)
        parsedRule.action = extractAction(from: text)
        
        // Extract file types
        parsedRule.fileTypes = extractFileTypes(from: text)
        
        // Extract time constraints
        parsedRule.timeConstraints = extractTimeConstraints(from: text)
        
        // Extract destination
        parsedRule.destination = extractDestination(from: text)
        
        // Extract name patterns
        parsedRule.namePatterns = extractNamePatterns(from: text)
        
        // Validate completeness
        guard parsedRule.isValid else { return nil }
        
        return parsedRule
    }
    
    private func extractAction(from text: String) -> Rule.ActionType? {
        let lowercased = text.lowercased()
        
        if lowercased.contains("move") || lowercased.contains("organize") {
            return .move
        } else if lowercased.contains("copy") {
            return .copy
        } else if lowercased.contains("delete") || lowercased.contains("trash") {
            return .delete
        }
        
        return nil
    }
    
    private func extractFileTypes(from text: String) -> [String] {
        // Look for file extensions
        let extensionPattern = #"\b(pdf|docx?|xlsx?|pptx?|png|jpe?g|mp4|mp3|zip)\b"#
        let regex = try? NSRegularExpression(pattern: extensionPattern, options: .caseInsensitive)
        
        var extensions: [String] = []
        if let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text) {
                    extensions.append(String(text[range]))
                }
            }
        }
        
        // Also look for generic terms
        if text.lowercased().contains("screenshot") {
            extensions.append("png")
        }
        if text.lowercased().contains("document") {
            extensions.append(contentsOf: ["pdf", "docx", "txt"])
        }
        if text.lowercased().contains("image") {
            extensions.append(contentsOf: ["png", "jpg", "jpeg"])
        }
        
        return extensions
    }
    
    private func extractTimeConstraints(from text: String) -> [TimeConstraint] {
        var constraints: [TimeConstraint] = []
        
        // Pattern: "older than X days/weeks/months"
        let olderPattern = #"older than (\d+) (day|week|month)s?"#
        if let regex = try? NSRegularExpression(pattern: olderPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            
            if let numberRange = Range(match.range(at: 1), in: text),
               let unitRange = Range(match.range(at: 2), in: text),
               let number = Int(text[numberRange]) {
                
                let unit = String(text[unitRange]).lowercased()
                let days = convertToDays(number: number, unit: unit)
                
                constraints.append(.olderThan(days: days))
            }
        }
        
        // Pattern: "from last week/month"
        if text.lowercased().contains("last week") {
            constraints.append(.olderThan(days: 7))
        } else if text.lowercased().contains("last month") {
            constraints.append(.olderThan(days: 30))
        }
        
        return constraints
    }
    
    private func extractDestination(from text: String) -> String? {
        // Look for "to [folder]" or "into [folder]"
        let destinationPattern = #"(?:to|into)\s+([A-Z]\w+(?:/\w+)*)"#
        
        if let regex = try? NSRegularExpression(pattern: destinationPattern, options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            
            return String(text[range])
        }
        
        return nil
    }
    
    private func convertToDays(number: Int, unit: String) -> Int {
        switch unit {
        case "day": return number
        case "week": return number * 7
        case "month": return number * 30
        default: return number
        }
    }
}

struct ParsedRule {
    var action: Rule.ActionType?
    var fileTypes: [String] = []
    var timeConstraints: [TimeConstraint] = []
    var destination: String?
    var namePatterns: [String] = []
    var confidence: Double = 0.0
    
    var isValid: Bool {
        // Need at least an action and a file type or name pattern
        return action != nil && (!fileTypes.isEmpty || !namePatterns.isEmpty)
    }
    
    func toRule() -> Rule? {
        guard isValid else { return nil }
        
        // Convert to RuleCondition array
        var conditions: [RuleCondition] = []
        
        // Add file type conditions
        for ext in fileTypes {
            conditions.append(.fileExtension(ext))
        }
        
        // Add time constraints
        for constraint in timeConstraints {
            switch constraint {
            case .olderThan(let days):
                conditions.append(.dateOlderThan(days: days, extension: nil))
            }
        }
        
        // Add name patterns
        for pattern in namePatterns {
            conditions.append(.nameContains(pattern))
        }
        
        let logicalOp: Rule.LogicalOperator = conditions.count > 1 ? .and : .single
        
        return Rule(
            name: "Natural language rule",
            conditions: conditions,
            logicalOperator: logicalOp,
            actionType: action!,
            destinationFolder: destination
        )
    }
}

enum TimeConstraint {
    case olderThan(days: Int)
    case newerThan(days: Int)
}
```

**UI Integration:**

```swift
struct NaturalLanguageRuleView: View {
    @State private var ruleText = ""
    @State private var parsedRule: ParsedRule?
    @State private var showPreview = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Describe your rule in plain English")
                .font(.formaH3)
            
            TextField("e.g., Move PDFs older than 30 days to Archive", text: $ruleText)
                .textFieldStyle(.roundedBorder)
                .font(.formaBody)
                .onChange(of: ruleText) { _, newValue in
                    parseRule(newValue)
                }
            
            if let parsed = parsedRule, showPreview {
                RulePreviewCard(parsedRule: parsed) {
                    // Create rule
                    if let rule = parsed.toRule() {
                        createRule(rule)
                    }
                }
            }
        }
    }
    
    private func parseRule(_ text: String) {
        let parser = NaturalLanguageRuleParser()
        parsedRule = parser.parse(text)
        showPreview = parsedRule != nil
    }
}
```

**Files to Create:**
- `Services/NaturalLanguageRuleParser.swift` - NLP parsing
- `Views/NaturalLanguageRuleView.swift` - Text input UI
- `Components/RulePreviewCard.swift` - Show parsed result

**Time Estimate:** 5-6 days

**Success Metric:** 70%+ successful parse rate, 80%+ user satisfaction

---

### Phase 4: Advanced Features (Weeks 7-8)

**Goal:** Content analysis and bulk intelligence

---

#### Feature 4.1: Content-Based File Categorization

**Enhancement:** Analyze file contents using macOS frameworks

**Capabilities:**

1. **Image Analysis (Vision Framework)**
   - Detect screenshots vs photos
   - Identify receipts/documents in photos
   - Detect faces for photo organization

2. **Document Analysis (NLP)**
   - Extract keywords from PDFs/documents
   - Classify document types (invoice, contract, report)

3. **Audio Analysis**
   - Detect music vs podcasts vs voice memos

**Implementation:**

```swift
import Vision
import NaturalLanguage

class FileContentAnalyzer {
    // Image analysis
    func analyzeImage(at path: String) async throws -> ImageAnalysis {
        guard let image = NSImage(contentsOfFile: path) else {
            throw AnalysisError.invalidImage
        }
        
        // Detect if it's a screenshot
        let isScreenshot = detectScreenshot(image)
        
        // Detect text in image (receipts, documents)
        let containsText = try await detectTextInImage(image)
        
        // Detect scene/objects
        let objects = try await detectObjects(image)
        
        return ImageAnalysis(
            isScreenshot: isScreenshot,
            containsText: containsText,
            detectedObjects: objects,
            suggestedCategory: categorizeImage(
                isScreenshot: isScreenshot,
                containsText: containsText,
                objects: objects
            )
        )
    }
    
    private func detectScreenshot(_ image: NSImage) -> Bool {
        // Screenshots often have specific aspect ratios
        // and pixel-perfect edges
        let size = image.size
        let aspectRatio = size.width / size.height
        
        // Common monitor aspect ratios
        let commonRatios = [16.0/9.0, 16.0/10.0, 4.0/3.0, 21.0/9.0]
        
        return commonRatios.contains { abs($0 - aspectRatio) < 0.01 }
    }
    
    private func detectTextInImage(_ image: NSImage) async throws -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results else { return false }
        
        // If >10 text regions detected, likely contains significant text
        return observations.count > 10
    }
    
    private func detectObjects(_ image: NSImage) async throws -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        let request = VNClassifyImageRequest()
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results as? [VNClassificationObservation] else {
            return []
        }
        
        // Return top 5 classifications with confidence > 0.5
        return observations
            .filter { $0.confidence > 0.5 }
            .prefix(5)
            .map { $0.identifier }
    }
    
    // Document analysis
    func analyzeDocument(at path: String) async throws -> DocumentAnalysis {
        // Read text from PDF or document
        let text = try extractText(from: path)
        
        // Extract keywords
        let keywords = extractKeywords(from: text)
        
        // Classify document type
        let classification = classifyDocument(text: text, keywords: keywords)
        
        return DocumentAnalysis(
            keywords: keywords,
            documentType: classification,
            suggestedDestination: suggestDestination(for: classification)
        )
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                keywords.append(String(text[range]))
            }
            return true
        }
        
        return keywords
    }
    
    private func classifyDocument(text: String, keywords: [String]) -> DocumentType {
        let lowercased = text.lowercased()
        
        if lowercased.contains("invoice") || keywords.contains("invoice") {
            return .invoice
        } else if lowercased.contains("contract") || lowercased.contains("agreement") {
            return .contract
        } else if lowercased.contains("receipt") {
            return .receipt
        } else if lowercased.contains("report") {
            return .report
        }
        
        return .generic
    }
}

struct ImageAnalysis {
    var isScreenshot: Bool
    var containsText: Bool
    var detectedObjects: [String]
    var suggestedCategory: String
}

struct DocumentAnalysis {
    var keywords: [String]
    var documentType: DocumentType
    var suggestedDestination: String
}

enum DocumentType {
    case invoice
    case contract
    case receipt
    case report
    case generic
}
```

**Integration with FileItem:**

```swift
extension FileItem {
    var contentAnalysis: ContentAnalysis?
    
    // Analyze file contents on-demand
    func analyzeContents() async throws {
        let analyzer = FileContentAnalyzer()
        
        if isImage {
            let imageAnalysis = try await analyzer.analyzeImage(at: path)
            self.contentAnalysis = .image(imageAnalysis)
        } else if isDocument {
            let docAnalysis = try await analyzer.analyzeDocument(at: path)
            self.contentAnalysis = .document(docAnalysis)
        }
    }
}

enum ContentAnalysis: Codable {
    case image(ImageAnalysis)
    case document(DocumentAnalysis)
    case audio(AudioAnalysis)
}
```

**Time Estimate:** 6-7 days

**Success Metric:** 85%+ accurate categorization

---

#### Feature 4.2: Bulk Folder Structure Suggestions

**Enhancement:** Analyze entire folders and suggest optimal organization

**Implementation:**

```swift
class BulkOrganizationService {
    func analyzeFolder(at path: String) async throws -> FolderAnalysis {
        // Scan all files
        let files = try await scanAllFiles(at: path)
        
        // Detect clusters
        let projectClusters = detectProjects(from: files)
        let typeClusters = groupByType(files)
        let dateClusters = groupByDate(files)
        
        // Suggest optimal structure
        let suggestedStructure = buildStructure(
            projects: projectClusters,
            types: typeClusters,
            dates: dateClusters
        )
        
        return FolderAnalysis(
            totalFiles: files.count,
            clusters: projectClusters + typeClusters + dateClusters,
            suggestedStructure: suggestedStructure,
            estimatedTimeToOrganize: calculateTime(for: files.count),
            spaceSavings: calculateDuplicates(files)
        )
    }
    
    private func buildStructure(
        projects: [ProjectCluster],
        types: [TypeCluster],
        dates: [DateCluster]
    ) -> FolderStructure {
        // Determine optimal hierarchy
        // Priority: Projects > Types > Dates
        
        var structure = FolderStructure()
        
        // Top level: Projects (if significant)
        if projects.count >= 3 {
            for project in projects {
                structure.addFolder(project.projectName, atLevel: 0)
            }
        }
        
        // Second level: Types
        for type in types {
            structure.addFolder(type.category.rawValue, atLevel: 1)
        }
        
        return structure
    }
}

struct FolderAnalysis {
    var totalFiles: Int
    var clusters: [any Cluster]
    var suggestedStructure: FolderStructure
    var estimatedTimeToOrganize: TimeInterval
    var spaceSavings: Int64
}

struct FolderStructure {
    var hierarchy: [FolderNode]
    
    mutating func addFolder(_ name: String, atLevel level: Int) {
        // Build tree structure
    }
    
    func preview() -> String {
        // Generate text preview of folder structure
    }
}
```

**Time Estimate:** 5-6 days

**Success Metric:** 75%+ user acceptance of suggested structures

---

## Implementation Timeline

### Quick Reference

| Phase | Features | Duration | Status |
|-------|----------|----------|--------|
| **Phase 1** | Enhanced pattern detection | 2 weeks | ✅ Complete |
| **Phase 2** | Context-aware intelligence | 2 weeks | ✅ Complete |
| **Phase 3** | Predictive intelligence | 2 weeks | Not Started |
| **Phase 4** | Advanced analysis | 2 weeks | Not Started |

**Total Estimated Time:** 8 weeks (4 weeks remaining)

---

## Success Metrics

### Overall AI System

| Metric | Target | Measurement |
|--------|--------|-------------|
| Automation rate | 70% | % of files organized via AI suggestions |
| Suggestion acceptance | 75% | % of AI suggestions accepted by user |
| False positive rate | <10% | % of incorrect suggestions |
| Time savings | 60% | Reduction in manual organization time |

### Feature-Specific

| Feature | Key Metric | Target |
|---------|------------|--------|
| Multi-condition patterns | Suggestion precision | 80%+ |
| Temporal clustering | Session detection accuracy | 70%+ |
| Project detection | Cluster accuracy | 80%+ |
| Duplicate detection | Exact duplicate accuracy | 99%+ |
| Destination prediction | Prediction accuracy | 70%+ |
| NL rule parsing | Successful parse rate | 70%+ |
| Content analysis | Categorization accuracy | 85%+ |

---

## Privacy & Performance

### Privacy-First Design

All AI features use **on-device processing only**:
- ✅ Core ML (on-device)
- ✅ Vision Framework (on-device)
- ✅ Natural Language Framework (on-device)
- ✅ No cloud API calls
- ✅ No data leaves the Mac
- ✅ Fully sandboxed

### Performance Considerations

1. **Async Processing:** All analysis runs asynchronously
2. **Background Queues:** Heavy processing on background threads
3. **Caching:** Cache analysis results in SwiftData
4. **Incremental Learning:** Don't retrain models on every file
5. **Progressive Enhancement:** App works without AI, better with it

---

## Risk Assessment

| Feature | Risk Level | Mitigation |
|---------|-----------|------------|
| Multi-condition patterns | Low | Builds on existing foundation |
| Temporal clustering | Medium | Conservative thresholds |
| Project detection | Medium | Easy dismiss, manual review |
| Duplicate detection | Low | User confirmation required |
| ML prediction | High | Require 50+ training examples |
| NL parsing | Medium | Show preview before creation |
| Content analysis | Medium | Fallback to extension-based |
| Bulk organization | High | Preview + undo support |

---

## Architecture Impact

### New Services

```
Services/
├── AI/
│   ├── LearningService.swift (✅ enhanced with multi-condition, temporal, negative patterns)
│   ├── ContextDetectionService.swift (✅ created - project/client detection)
│   ├── DuplicateDetectionService.swift (✅ created - duplicate detection)
│   ├── DestinationPredictionService.swift (planned - Phase 3)
│   ├── NaturalLanguageRuleParser.swift (planned - Phase 3)
│   ├── FileContentAnalyzer.swift (planned - Phase 4)
│   └── BulkOrganizationService.swift (planned - Phase 4)
```

### New Views

```
Views/
├── AIInsightsView.swift (✅ created - unified AI insights panel)
├── DuplicateGroupsView.swift (✅ created - duplicate management)
├── ProjectClusterView.swift (✅ created - project clustering)
```

### Model Extensions

```swift
// LearnedPattern enhancements (✅ IMPLEMENTED)
@Model class LearnedPattern {
    var conditions: [PatternCondition]      // ✅ Added
    var logicalOperator: Rule.LogicalOperator // ✅ Added
    var temporalContext: TemporalContext?   // ✅ Added
    var isNegativePattern: Bool             // ✅ Added
    var suppressedRuleIds: [UUID]           // ✅ Added
}

// Supporting types (✅ IMPLEMENTED)
enum PatternCondition: Codable { }           // ✅ Created (top-level)
struct TemporalContext: Codable { }          // ✅ Created (top-level)

// New models (✅ IMPLEMENTED)
@Model class ProjectCluster { }              // ✅ Created
struct DuplicateGroup { }                    // ✅ Created (in DuplicateDetectionService)

// FileItem enhancements (planned - Phase 3/4)
extension FileItem {
    var contentAnalysis: ContentAnalysis?    // Planned
    var predictedDestination: PredictedDestination? // Planned
    var clusterMembership: [UUID]            // Planned
}

// Future models (planned)
@Model class MLTrainingHistory { }           // Planned - Phase 3
```

---

## Next Steps

### Completed
1. ✅ Review and approve this plan
2. ✅ Phase 1: Multi-condition pattern detection
3. ✅ Phase 1: Temporal pattern analysis
4. ✅ Phase 1: Negative pattern learning
5. ✅ Phase 2: Project/Client detection (ContextDetectionService)
6. ✅ Phase 2: Duplicate & similar file detection
7. ✅ Create unified AIInsightsView for all AI features

### In Progress
8. [ ] Integration testing of Phase 1 & 2 features
9. [ ] Wire AI insights into main app navigation

### Future Work (Phase 3 & 4 - Deferred)
10. [ ] ML-based destination prediction (requires Core ML training)
11. [ ] Natural language rule parsing
12. [ ] Content-based file categorization (Vision/NLP frameworks)
13. [ ] Bulk folder organization suggestions

---

## Appendix: Competitive Positioning

### AI Capabilities Comparison

| Capability | Hazel | Sparkle | AI File Sorter | **Forma** |
|------------|-------|---------|----------------|-----------|
| Pattern learning | ❌ | ❌ | Basic | ✅ Advanced |
| Multi-condition patterns | ❌ | ❌ | ❌ | ✅ |
| Project detection | ❌ | ❌ | ❌ | ✅ |
| Duplicate detection | Basic | ❌ | ❌ | ✅ Advanced |
| ML prediction | ❌ | ❌ | ❌ | ✅ |
| Natural language | ❌ | ❌ | ❌ | ✅ |
| Content analysis | ❌ | ❌ | Basic | ✅ Advanced |
| On-device AI | N/A | N/A | ❌ Cloud | ✅ |

### Unique Value Proposition

> "Forma learns how you work, understands your projects, and gets smarter over time—all on your Mac, with complete privacy."

**Key Differentiators:**
1. **Learning System** - Converts manual actions into automation
2. **Context-Aware** - Understands projects and relationships
3. **Predictive** - Suggests destinations without explicit rules
4. **Privacy-First** - All AI runs on-device
5. **Transparent** - Shows reasoning for every suggestion
6. **Progressive** - Works immediately, improves with use

---

*Document created December 1, 2025*
*Based on existing Forma codebase analysis and AI capabilities assessment*
