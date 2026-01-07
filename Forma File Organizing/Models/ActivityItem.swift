import Foundation
import SwiftData

@Model
final class ActivityItem {
    #Index<ActivityItem>([\.timestamp])

    var id: UUID
    var timestamp: Date

    /// Raw storage for activity type.
    /// SwiftData cannot reliably persist nested enums directly, so we store as String.
    /// Use the `activityType` computed property for type-safe access.
    private var activityTypeRaw: String

    /// Type-safe accessor for activity type
    var activityType: ActivityType {
        get { ActivityType(rawValue: activityTypeRaw) ?? .fileScanned }
        set { activityTypeRaw = newValue.rawValue }
    }

    var fileName: String
    var details: String
    var fileExtension: String?

    // Analytics tracking fields (v1.2.0)
    /// The UUID of the rule that was applied, if this is a ruleApplied activity.
    var ruleID: UUID?
    /// Number of files affected by the operation (for ruleApplied and bulkOrganized).
    var affectedFileCount: Int?

    init(
        activityType: ActivityType,
        fileName: String,
        details: String,
        fileExtension: String? = nil,
        ruleID: UUID? = nil,
        affectedFileCount: Int? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.activityTypeRaw = activityType.rawValue
        self.fileName = fileName
        self.details = details
        self.fileExtension = fileExtension
        self.ruleID = ruleID
        self.affectedFileCount = affectedFileCount
    }

    enum ActivityType: String, Codable {
        // File operations
        case fileScanned
        case fileOrganized
        case fileMoved
        case fileSkipped
        case fileDeleted
        case operationFailed

        // Rule operations
        case ruleCreated
        case ruleApplied
        case ruleDeleted
        case ruleUpdated

        // Onboarding & setup
        case onboardingCompleted
        case folderAccessGranted

        // Duplicate handling
        case duplicatesDetected
        case duplicateDeleted
        case duplicateKept

        // AI & learning
        case patternLearned
        case patternApplied
        case aiSuggestionAccepted
        case aiSuggestionRejected

        // Bulk operations
        case bulkOrganized
        case bulkUndone
        case bulkPartialFailure

        // Automation (v1.4)
        case automationScanCompleted
        case automationAutoOrganized
        case automationError
        case automationPaused
        case automationResumed

        var iconName: String {
            switch self {
            case .fileScanned: return "doc.badge.plus"
            case .fileOrganized: return "checkmark.circle.fill"
            case .fileMoved: return "arrow.right.circle.fill"
            case .fileSkipped: return "xmark.circle"
            case .fileDeleted: return "trash.fill"
            case .operationFailed: return "exclamationmark.triangle.fill"
            case .ruleCreated: return "plus.circle.fill"
            case .ruleApplied: return "wand.and.stars"
            case .ruleDeleted: return "trash.circle"
            case .ruleUpdated: return "pencil.circle.fill"
            case .onboardingCompleted: return "party.popper.fill"
            case .folderAccessGranted: return "folder.badge.plus"
            case .duplicatesDetected: return "doc.on.doc"
            case .duplicateDeleted: return "doc.badge.minus"
            case .duplicateKept: return "doc.badge.checkmark"
            case .patternLearned: return "brain"
            case .patternApplied: return "brain.head.profile"
            case .aiSuggestionAccepted: return "hand.thumbsup.fill"
            case .aiSuggestionRejected: return "hand.thumbsdown"
            case .bulkOrganized: return "square.stack.3d.up.fill"
            case .bulkUndone: return "arrow.uturn.backward.circle.fill"
            case .bulkPartialFailure: return "exclamationmark.circle.fill"
            case .automationScanCompleted: return "arrow.triangle.2.circlepath"
            case .automationAutoOrganized: return "wand.and.stars.inverse"
            case .automationError: return "exclamationmark.triangle.fill"
            case .automationPaused: return "pause.circle.fill"
            case .automationResumed: return "play.circle.fill"
            }
        }

        var displayName: String {
            switch self {
            case .fileScanned: return "Scanned"
            case .fileOrganized: return "Organized"
            case .fileMoved: return "Moved"
            case .fileSkipped: return "Skipped"
            case .fileDeleted: return "Deleted"
            case .operationFailed: return "Failed"
            case .ruleCreated: return "Rule Created"
            case .ruleApplied: return "Rule Applied"
            case .ruleDeleted: return "Rule Deleted"
            case .ruleUpdated: return "Rule Updated"
            case .onboardingCompleted: return "Setup Complete"
            case .folderAccessGranted: return "Access Granted"
            case .duplicatesDetected: return "Duplicates Found"
            case .duplicateDeleted: return "Duplicate Removed"
            case .duplicateKept: return "Original Kept"
            case .patternLearned: return "Pattern Learned"
            case .patternApplied: return "Pattern Applied"
            case .aiSuggestionAccepted: return "Suggestion Accepted"
            case .aiSuggestionRejected: return "Suggestion Rejected"
            case .bulkOrganized: return "Bulk Organized"
            case .bulkUndone: return "Bulk Undone"
            case .bulkPartialFailure: return "Partial Failure"
            case .automationScanCompleted: return "Auto-Scan Complete"
            case .automationAutoOrganized: return "Auto-Organized"
            case .automationError: return "Automation Error"
            case .automationPaused: return "Automation Paused"
            case .automationResumed: return "Automation Resumed"
            }
        }
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// Mock Data
extension ActivityItem {
    static var mocks: [ActivityItem] {
        [
            ActivityItem(
                activityType: .fileOrganized,
                fileName: "Invoice_2025_01.pdf",
                details: "Moved to Documents/Finance",
                fileExtension: "pdf"
            ),
            ActivityItem(
                activityType: .fileScanned,
                fileName: "Screenshot 2025-11-18.png",
                details: "Added from Desktop",
                fileExtension: "png"
            ),
            ActivityItem(
                activityType: .ruleCreated,
                fileName: "Screenshot Sweeper",
                details: "New rule for organizing screenshots"
            ),
            ActivityItem(
                activityType: .fileMoved,
                fileName: "Project_Proposal.docx",
                details: "Moved to Documents/Work",
                fileExtension: "docx"
            ),
            ActivityItem(
                activityType: .fileSkipped,
                fileName: "temp_file.txt",
                details: "Skipped by user",
                fileExtension: "txt"
            )
        ]
    }
}
