import Foundation
import SwiftData

enum OrganizationRunOrigin: String, Sendable {
    case reviewDriven
    case automation
}

struct UndoBatchSummary: Equatable, Sendable {
    let origin: OrganizationRunOrigin
    let affectedFileCount: Int
    let timestamp: Date
}

struct OrganizationMemorySnapshot: Sendable {
    let fileName: String
    let fileExtension: String
    let fileTypeCategory: FileTypeCategory
    let sourceLocation: FileLocationKind
    let scanRootPath: String?
    let relativeParentPath: String?
    let suggestionSource: SuggestionSource?
    let suggestedDestination: Destination?
    let chosenDestination: Destination?
    let confidenceScore: Double?
    let matchedRuleID: UUID?
}

struct MetadataIdentitySnapshot: Sendable {
    let sourcePath: String
    let destinationPath: String
    let displayName: String
    let fileExtension: String
    let destinationDisplayName: String?
    let projectAssociationWriteContext: ProjectAssociationWriteContext?

    init(
        sourcePath: String,
        destinationPath: String,
        displayName: String,
        fileExtension: String,
        destinationDisplayName: String?,
        projectAssociationWriteContext: ProjectAssociationWriteContext? = nil
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.displayName = displayName
        self.fileExtension = fileExtension
        self.destinationDisplayName = destinationDisplayName
        self.projectAssociationWriteContext = projectAssociationWriteContext
    }
}

struct BulkMoveOperation: Sendable {
    let fileID: String
    let fromPath: String
    let toPath: String
    let originalStatus: FileItem.OrganizationStatus
    let memorySnapshot: OrganizationMemorySnapshot?
    let metadataSnapshot: MetadataIdentitySnapshot?

    init(
        fileID: String,
        fromPath: String,
        toPath: String,
        originalStatus: FileItem.OrganizationStatus,
        memorySnapshot: OrganizationMemorySnapshot?,
        metadataSnapshot: MetadataIdentitySnapshot? = nil
    ) {
        self.fileID = fileID
        self.fromPath = fromPath
        self.toPath = toPath
        self.originalStatus = originalStatus
        self.memorySnapshot = memorySnapshot
        self.metadataSnapshot = metadataSnapshot
    }
}

/// Protocol for undoable file organization commands
/// Uses the Command pattern to store only essential data (IDs and deltas) instead of full objects
/// Note: Methods are MainActor-isolated because they work with SwiftData types (ModelContext, FileItem)
protocol UndoableCommand {
    /// Unique identifier for the command
    var id: UUID { get }
    
    /// When the command was executed
    var timestamp: Date { get }
    
    /// Execute the command (for redo operations)
    @MainActor
    func execute(context: ModelContext?) async throws
    
    /// Undo the command (reverse the operation)
    @MainActor
    func undo(context: ModelContext?) throws
    
    /// Human-readable description of the command
    var description: String { get }
}

// MARK: - Concrete Commands

/// Command for moving a single file
struct MoveFileCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date

    // Lightweight storage - only essentials
    let fileID: String  // File path (unique identifier)
    let fromPath: String
    let toPath: String
    let originalStatus: FileItem.OrganizationStatus
    let originalDestination: Destination?
    let memorySnapshot: OrganizationMemorySnapshot?
    let metadataSnapshot: MetadataIdentitySnapshot?

    init(
        id: UUID,
        timestamp: Date,
        fileID: String,
        fromPath: String,
        toPath: String,
        originalStatus: FileItem.OrganizationStatus,
        originalDestination: Destination?,
        memorySnapshot: OrganizationMemorySnapshot?,
        metadataSnapshot: MetadataIdentitySnapshot? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.fileID = fileID
        self.fromPath = fromPath
        self.toPath = toPath
        self.originalStatus = originalStatus
        self.originalDestination = originalDestination
        self.memorySnapshot = memorySnapshot
        self.metadataSnapshot = metadataSnapshot
    }

    var description: String {
        "Move \(URL(fileURLWithPath: fromPath).lastPathComponent) to \(originalDestination?.displayName ?? "destination")"
    }
    
    func execute(context: ModelContext?) async throws {
        // Re-execute the move operation
        guard let ctx = context else {
            throw CommandError.noContext
        }
        
        // Find the file by ID
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { $0.path == fileID || $0.path == fromPath }
        )
        guard let file = try? ctx.fetch(descriptor).first else {
            throw CommandError.fileNotFound(fileID)
        }
        
        // Perform the move using secure file operations
        if FileManager.default.fileExists(atPath: fromPath) {
            let ops = FileOperationsService()
            try ops.secureMoveOnDisk(from: fromPath, to: toPath)
            _ = file.updatePath(toPath)
            file.status = .completed
            try ctx.save()
        }
    }
    
    func undo(context: ModelContext?) throws {
        // Reverse the move operation
        guard let ctx = context else {
            throw CommandError.noContext
        }

        // Find the file by either current or original path
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { $0.path == toPath || $0.path == fromPath }
        )
        guard let file = try? ctx.fetch(descriptor).first else {
            throw CommandError.fileNotFound(fileID)
        }

        // Move file back if it exists at destination
        if FileManager.default.fileExists(atPath: toPath) {
            let ops = FileOperationsService()
            try ops.secureMoveOnDisk(from: toPath, to: fromPath)
            _ = file.updatePath(fromPath)
        }

        // Restore original state
        file.status = originalStatus
        file.destination = originalDestination
        try ctx.save()
    }
}

/// Command for skipping a file
struct SkipFileCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date

    // Minimal storage
    let fileID: String
    let previousStatus: FileItem.OrganizationStatus
    let previousDestination: Destination?

    var description: String {
        "Skip \(URL(fileURLWithPath: fileID).lastPathComponent)"
    }

    func execute(context: ModelContext?) async throws {
        guard let ctx = context else {
            throw CommandError.noContext
        }

        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { $0.path == fileID }
        )
        guard let file = try? ctx.fetch(descriptor).first else {
            throw CommandError.fileNotFound(fileID)
        }

        file.status = .skipped
        try ctx.save()
    }

    func undo(context: ModelContext?) throws {
        guard let ctx = context else {
            throw CommandError.noContext
        }

        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { $0.path == fileID }
        )
        guard let file = try? ctx.fetch(descriptor).first else {
            throw CommandError.fileNotFound(fileID)
        }

        file.status = previousStatus
        file.destination = previousDestination
        try ctx.save()
    }
}

/// Command for bulk file operations
struct BulkMoveCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let origin: OrganizationRunOrigin
    
    // Array of lightweight move operations
    let operations: [BulkMoveOperation]
    
    init(
        id: UUID,
        timestamp: Date,
        origin: OrganizationRunOrigin = .reviewDriven,
        operations: [BulkMoveOperation]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.origin = origin
        self.operations = operations
    }

    var description: String {
        "Move \(operations.count) file\(operations.count == 1 ? "" : "s")"
    }

    var undoBatchSummary: UndoBatchSummary {
        UndoBatchSummary(
            origin: origin,
            affectedFileCount: operations.count,
            timestamp: timestamp
        )
    }
    
    func execute(context: ModelContext?) async throws {
        guard let ctx = context else {
            throw CommandError.noContext
        }
        
        let ops = FileOperationsService()
        for op in operations {
            let fileID = op.fileID
            let fromPath = op.fromPath
            
            let descriptor = FetchDescriptor<FileItem>(
                predicate: #Predicate<FileItem> { $0.path == fileID || $0.path == fromPath }
            )
            guard let file = try? ctx.fetch(descriptor).first else { continue }
            
            if FileManager.default.fileExists(atPath: op.fromPath) {
                try ops.secureMoveOnDisk(from: op.fromPath, to: op.toPath)
                _ = file.updatePath(op.toPath)
                file.status = .completed
            }
        }
        
        try ctx.save()
    }
    
    func undo(context: ModelContext?) throws {
        guard let ctx = context else {
            throw CommandError.noContext
        }
        
        let ops = FileOperationsService()
        for op in operations {
            let toPath = op.toPath
            let fromPath = op.fromPath
            
            let descriptor = FetchDescriptor<FileItem>(
                predicate: #Predicate<FileItem> { $0.path == toPath || $0.path == fromPath }
            )
            guard let file = try? ctx.fetch(descriptor).first else { continue }
            
            if FileManager.default.fileExists(atPath: op.toPath) {
                try ops.secureMoveOnDisk(from: op.toPath, to: op.fromPath)
                _ = file.updatePath(op.fromPath)
            }
            
            file.status = op.originalStatus
        }
        
        try ctx.save()
    }
}

// MARK: - Errors

enum CommandError: LocalizedError {
    case noContext
    case fileNotFound(String)
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noContext:
            return "No SwiftData context available for undo operation"
        case .fileNotFound(let fileID):
            return "File not found: \(fileID)"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        }
    }
}
