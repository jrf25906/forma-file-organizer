import Foundation

enum WorkflowStepKind: String, Codable, Sendable, Hashable, CaseIterable {
    case rename
    case tag
    case move
}

enum WorkflowStepDisposition: String, Codable, Sendable, Hashable {
    case planned
    case blocked
    case skipped
}

enum WorkflowPlanBlockerReason: Sendable, Hashable {
    case templateUnavailable(templateID: String)
    case sourceFileMissing(path: String)
    case renameTargetCollision(path: String)
    case finalDestinationCollision(path: String)
    case destinationMissing
    case destinationUnavailable(displayName: String)
    case compensationPreconditionMissing(stepKind: WorkflowStepKind, detail: String)
}

enum WorkflowCompensationPayloadDescriptor: Sendable, Hashable {
    case renameRollback(originalPath: String, renamedPath: String)
    case tagRemoval(path: String, tagsToRemove: [String])
    case moveRollback(originalDestinationPath: String, rollbackPath: String)
}

struct WorkflowDefinition: Sendable, Hashable {
    let templateID: String
    let templateDisplayName: String
    let renamePreset: BuiltInWorkflowTemplate.RenamePreset?
    let tagPolicy: BuiltInWorkflowTemplate.TagPolicy?
    let stepKinds: [WorkflowStepKind]
}

struct WorkflowSimulatedStep: Sendable, Hashable {
    let kind: WorkflowStepKind
    let disposition: WorkflowStepDisposition
    let blocker: WorkflowPlanBlockerReason?
    let compensationPayload: WorkflowCompensationPayloadDescriptor?
}

struct WorkflowPlannedFile: Sendable, Hashable {
    let sourcePath: String
    let workingPath: String
    let finalDestinationPath: String?
    let renameTargetName: String
    let tagIntents: [String]
    let steps: [WorkflowSimulatedStep]
    let blockers: [WorkflowPlanBlockerReason]

    var isBlocked: Bool {
        !blockers.isEmpty
    }
}

struct WorkflowFileSimulation: Sendable, Hashable {
    let sourcePath: String
    let blockers: [WorkflowPlanBlockerReason]
    let steps: [WorkflowSimulatedStep]

    var isBlocked: Bool {
        !blockers.isEmpty
    }
}

struct WorkflowSimulationReport: Sendable, Hashable {
    let files: [WorkflowFileSimulation]

    var hasBlockers: Bool {
        files.contains(where: \.isBlocked)
    }
}

struct WorkflowPlan: Sendable, Hashable {
    let definition: WorkflowDefinition
    let files: [WorkflowPlannedFile]
    let simulation: WorkflowSimulationReport

    var hasBlockers: Bool {
        simulation.hasBlockers
    }
}
