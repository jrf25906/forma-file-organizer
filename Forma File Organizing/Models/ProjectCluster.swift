import Foundation
import SwiftData

/// Represents a detected cluster of related files that likely belong to the same project or context.
///
/// ProjectCluster uses various detection algorithms to identify files that should be organized together,
/// such as files with matching project codes, files created in the same work session, or files with similar names.
@Model
final class ProjectCluster {
    /// Unique identifier
    var id: UUID

    /// Raw storage for cluster type.
    /// SwiftData cannot reliably persist nested enums directly, so we store as String.
    /// Use the `clusterType` computed property for type-safe access.
    private var clusterTypeRaw: String

    /// Type-safe accessor for cluster type
    var clusterType: ClusterType {
        get { ClusterType(rawValue: clusterTypeRaw) ?? .nameSimilarity }
        set { clusterTypeRaw = newValue.rawValue }
    }

    /// The file paths of all files in this cluster
    var filePaths: [String]
    
    /// Confidence score (0.0-1.0) indicating how certain we are these files are related
    /// - 0.8+ (High): Strong signals (explicit project codes, tight temporal grouping)
    /// - 0.5-0.79 (Medium): Moderate signals (name similarity, loose temporal grouping)
    /// - <0.5 (Low): Weak signals (shouldn't normally reach user)
    var confidenceScore: Double {
        didSet {
            if confidenceScore < 0.0 || confidenceScore > 1.0 {
                Log.warning("ProjectCluster: confidenceScore \(confidenceScore) out of bounds [0.0-1.0], clamping", category: .analytics)
                confidenceScore = max(0.0, min(1.0, confidenceScore))
            }
        }
    }
    
    /// Suggested folder name for organizing these files
    var suggestedFolderName: String
    
    /// Optional pattern that was detected (e.g., "P-1024", "CLIENT_ABC")
    var detectedPattern: String?
    
    /// When this cluster was first detected
    var detectedDate: Date
    
    /// Whether the user has dismissed this suggestion
    var isDismissed: Bool
    
    /// Whether the user has acted on this cluster (organized the files)
    var isOrganized: Bool
    
    init(
        clusterType: ClusterType,
        filePaths: [String],
        confidenceScore: Double,
        suggestedFolderName: String,
        detectedPattern: String? = nil,
        detectedDate: Date = Date(),
        isDismissed: Bool = false,
        isOrganized: Bool = false
    ) {
        self.id = UUID()
        self.clusterTypeRaw = clusterType.rawValue
        self.filePaths = filePaths
        self.confidenceScore = confidenceScore
        self.suggestedFolderName = suggestedFolderName
        self.detectedPattern = detectedPattern
        self.detectedDate = detectedDate
        self.isDismissed = isDismissed
        self.isOrganized = isOrganized
    }
    
    // MARK: - Types
    
    /// The type of clustering algorithm used to detect this group
    enum ClusterType: String, Codable {
        /// Files containing matching project codes (e.g., P-1024, JIRA-456)
        case projectCode
        
        /// Files modified within a short time window (same work session)
        case temporal
        
        /// Files with similar names (versions, sequences)
        case nameSimilarity
        
        /// Files with matching date stamps in names
        case dateStamp
        
        var displayName: String {
            switch self {
            case .projectCode: return "Project Code"
            case .temporal: return "Work Session"
            case .nameSimilarity: return "Related Files"
            case .dateStamp: return "Date Group"
            }
        }
        
        var iconName: String {
            switch self {
            case .projectCode: return "number.square.fill"
            case .temporal: return "clock.fill"
            case .nameSimilarity: return "doc.on.doc.fill"
            case .dateStamp: return "calendar.badge.clock"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Number of files in this cluster
    var fileCount: Int {
        filePaths.count
    }
    
    /// Confidence level as a readable string
    var confidenceLevel: String {
        if confidenceScore >= 0.8 {
            return "High"
        } else if confidenceScore >= 0.5 {
            return "Medium"
        } else {
            return "Low"
        }
    }
    
    /// Whether this cluster should be shown to the user
    var shouldShow: Bool {
        // Don't show dismissed or already organized clusters
        guard !isDismissed && !isOrganized else { return false }
        
        // Only show medium or high confidence clusters
        guard confidenceScore >= 0.5 else { return false }
        
        // Need at least 3 files to be worth showing
        return fileCount >= 3
    }
    
    /// Description for UI display
    var displayDescription: String {
        let fileWord = fileCount == 1 ? "file" : "files"

        // Only show the pattern if it's meaningful to users
        // Skip raw numeric IDs that don't have recognizable structure
        if let pattern = detectedPattern, isDisplayablePattern(pattern) {
            return "\(fileCount) \(fileWord) related to \"\(pattern)\""
        } else {
            switch clusterType {
            case .projectCode:
                return "\(fileCount) \(fileWord) from the same project"
            case .temporal:
                return "\(fileCount) \(fileWord) from a recent work session"
            case .nameSimilarity:
                return "\(fileCount) related \(fileWord)"
            case .dateStamp:
                return "\(fileCount) \(fileWord) from the same date"
            }
        }
    }

    /// Check if a pattern is meaningful enough to display to users
    /// Filters out raw numeric IDs that look like internal identifiers
    private func isDisplayablePattern(_ pattern: String) -> Bool {
        // Date patterns are always displayable (YYYY-MM-DD, MM-DD-YYYY)
        if pattern.contains("-") && pattern.count >= 8 {
            return true
        }

        // Project codes with letters are displayable (P-1024, JIRA-456)
        if pattern.contains(where: { $0.isLetter }) {
            return true
        }

        // Pure numeric strings need to look like dates to be displayable
        // 8 digits starting with 20 or 19 (years 1900-2099)
        if pattern.count == 8 && pattern.allSatisfy({ $0.isNumber }) {
            let prefix = String(pattern.prefix(2))
            return prefix == "20" || prefix == "19"
        }

        // Otherwise, don't show raw numeric patterns
        return false
    }
    
    // MARK: - Methods
    
    /// Mark this cluster as dismissed by the user
    func dismiss() {
        isDismissed = true
    }
    
    /// Mark this cluster as organized
    func markAsOrganized() {
        isOrganized = true
    }
}

// MARK: - Mock Data

extension ProjectCluster {
    static var mocks: [ProjectCluster] {
        [
            ProjectCluster(
                clusterType: .projectCode,
                filePaths: [
                    "/Users/test/Downloads/P-1024_proposal.pdf",
                    "/Users/test/Downloads/P-1024_budget.xlsx",
                    "/Users/test/Downloads/P-1024_timeline.png"
                ],
                confidenceScore: 0.95,
                suggestedFolderName: "Project P-1024",
                detectedPattern: "P-1024"
            ),
            ProjectCluster(
                clusterType: .temporal,
                filePaths: [
                    "/Users/test/Desktop/design_v1.sketch",
                    "/Users/test/Desktop/design_v2.sketch",
                    "/Users/test/Desktop/design_v3.sketch",
                    "/Users/test/Desktop/client_feedback.txt"
                ],
                confidenceScore: 0.75,
                suggestedFolderName: "Design Work Session"
            ),
            ProjectCluster(
                clusterType: .nameSimilarity,
                filePaths: [
                    "/Users/test/Downloads/report_draft.docx",
                    "/Users/test/Downloads/report_final.docx",
                    "/Users/test/Downloads/report_revised.docx"
                ],
                confidenceScore: 0.85,
                suggestedFolderName: "Report Versions"
            )
        ]
    }
}
