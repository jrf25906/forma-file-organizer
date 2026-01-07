import Foundation
import SwiftUI

// MARK: - RuleFormState

/// Consolidated form state for rule editing (used by both RuleEditorView and InlineRuleBuilderView).
///
/// Groups all form-related @State properties into a single source of truth.
/// This reduces the number of bindings SwiftUI tracks and makes state changes easier to reason about.
///
/// ## Design Notes
/// - **Unified**: Replaces both `RuleFormState` and `InlineRuleFormState` to eliminate duplication
/// - **Immutable Destination**: Uses `Destination` type for sandbox-safe file access
/// - **Compound Support**: Handles both single conditions and compound (multi-condition) rules
///
/// ## Usage
/// ```swift
/// @State private var formState = RuleFormState()
///
/// // Initialize from existing rule
/// formState = RuleFormState(from: existingRule)
///
/// // Initialize from file context (quick rule)
/// formState = RuleFormState(from: selectedFile)
/// ```
struct RuleFormState {
    var name: String = ""
    var conditionType: Rule.ConditionType = .fileExtension
    var conditionValue: String = ""
    var actionType: Rule.ActionType = .move
    var isEnabled: Bool = true

    // Category assignment
    /// The ID of the category this rule belongs to (nil = General)
    var categoryID: UUID?

    // Destination (unified system)
    /// Display path shown in the UI (e.g., "Documents/Work")
    var destinationDisplayPath: String = ""
    /// Security-scoped bookmark data from folder picker (required for sandboxed access)
    var destinationBookmarkData: Data?

    // Compound conditions
    var useCompoundConditions: Bool = false
    var conditions: [RuleCondition] = []
    var logicalOperator: Rule.LogicalOperator = .and

    // Exclusion conditions (exceptions) - used by RuleEditorView
    var exclusionConditions: [RuleCondition] = []
    var showExclusionConditions: Bool = false

    // MARK: - Computed Properties

    /// Whether this form has a bookmark-backed destination
    var hasBookmark: Bool {
        destinationBookmarkData != nil
    }

    /// Whether we have a valid destination (either bookmark or trash for delete action)
    var hasValidDestination: Bool {
        actionType == .delete || destinationBookmarkData != nil
    }

    // MARK: - Initializers

    /// Creates default empty form state for a new rule
    init() {}

    /// Populates form state from an existing rule for editing
    init(from rule: Rule) {
        name = rule.name
        actionType = rule.actionType
        isEnabled = rule.isEnabled
        categoryID = rule.category?.id
        logicalOperator = rule.logicalOperator

        // Extract destination info from unified Destination type
        if let destination = rule.destination {
            destinationDisplayPath = destination.displayName
            destinationBookmarkData = destination.bookmarkData
        }

        // Check if this is a compound rule
        if !rule.conditions.isEmpty {
            useCompoundConditions = true
            conditions = rule.conditions
            // Set legacy fields from first condition for compatibility
            if let first = rule.conditions.first {
                conditionType = first.type
                conditionValue = first.value
            }
        } else {
            useCompoundConditions = false
            conditionType = rule.conditionType
            conditionValue = rule.conditionValue
        }

        // Load exclusion conditions
        exclusionConditions = rule.exclusionConditions
        showExclusionConditions = !rule.exclusionConditions.isEmpty
    }

    /// Creates form state pre-filled from a file context (for quick rule creation)
    init(from file: FileItem) {
        name = "Organize .\(file.fileExtension.uppercased()) files"
        conditionType = .fileExtension
        conditionValue = file.fileExtension
        actionType = .move
        isEnabled = true
        logicalOperator = .single

        // If file has a destination, use it
        if let destination = file.destination {
            destinationDisplayPath = destination.displayName
            destinationBookmarkData = destination.bookmarkData
        } else {
            // Fallback to a default display path (no bookmark - user must pick folder)
            destinationDisplayPath = Self.defaultDestination(for: file)
        }
    }

    // MARK: - Methods

    /// Builds a Destination from the current form state
    func buildDestination() -> Destination? {
        if actionType == .delete {
            return .trash
        }

        guard let bookmarkData = destinationBookmarkData else {
            return nil
        }

        return .folder(bookmark: bookmarkData, displayName: destinationDisplayPath)
    }

    /// Clears bookmark data (for when user wants to select a different folder)
    mutating func clearBookmark() {
        destinationBookmarkData = nil
        destinationDisplayPath = ""
    }

    /// Default destination based on file category
    private static func defaultDestination(for file: FileItem) -> String {
        switch file.category {
        case .documents: return "Documents"
        case .images: return "Pictures"
        case .videos: return "Movies"
        case .audio: return "Music"
        case .archives: return "Downloads/Archives"
        case .all: return "Desktop"
        }
    }
}

// MARK: - Condition Display Helpers

/// Shared helper functions for displaying rule conditions.
/// Used by both RuleEditorView and InlineRuleBuilderView.
enum RuleConditionDisplay {
    /// Returns a human-readable display name for a condition type
    static func displayName(for type: Rule.ConditionType) -> String {
        switch type {
        case .fileExtension: return "File extension is"
        case .nameContains: return "Name contains"
        case .nameStartsWith: return "Name starts with"
        case .nameEndsWith: return "Name ends with"
        case .dateOlderThan: return "Date older than (days)"
        case .sizeLargerThan: return "Size larger than"
        case .dateModifiedOlderThan: return "Modified older than (days)"
        case .dateAccessedOlderThan: return "Not opened in (days)"
        case .fileKind: return "File kind is"
        case .sourceLocation: return "Source location is"
        }
    }

    /// Returns a placeholder string for a condition type input field
    static func placeholder(for type: Rule.ConditionType) -> String {
        switch type {
        case .fileExtension: return "pdf"
        case .nameContains: return "Invoice"
        case .nameStartsWith: return "Screenshot"
        case .nameEndsWith: return "_final"
        case .dateOlderThan: return "7"
        case .sizeLargerThan: return "100MB"
        case .dateModifiedOlderThan: return "30"
        case .dateAccessedOlderThan: return "90"
        case .fileKind: return "image"
        case .sourceLocation: return "desktop"
        }
    }

    /// Returns a hint string explaining the condition type
    static func hint(for type: Rule.ConditionType) -> String {
        switch type {
        case .fileExtension: return "Just the extension (no dot)"
        case .nameContains: return "Case insensitive matching"
        case .nameStartsWith: return "Case insensitive matching"
        case .nameEndsWith: return "Case insensitive matching"
        case .dateOlderThan: return "Number of days, or extension:days (e.g. dmg:7)"
        case .sizeLargerThan: return "e.g., 100MB, 1.5GB, 500KB"
        case .dateModifiedOlderThan: return "Number of days since last modification"
        case .dateAccessedOlderThan: return "Number of days since last opened"
        case .fileKind: return "Options: image, audio, video, document, spreadsheet, presentation, archive, code"
        case .sourceLocation: return "Options: desktop, downloads, documents, pictures, music, home"
        }
    }
}
