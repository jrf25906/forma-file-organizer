import Foundation

enum WorkflowStepKind: String, Codable, Sendable, Hashable, CaseIterable {
    case rename
    case tag
    case projectAssociation
    case workflowStatus
    case move
    case log
    case notify
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
    case projectAssociationRestore(path: String, previousProjectAssociation: String?)
    case workflowStatusRestore(path: String, previousWorkflowStatus: MetadataWorkflowStatus?)
    case moveRollback(originalDestinationPath: String, rollbackPath: String)
}

struct WorkflowDefinition: Sendable, Hashable {
    let templateID: String
    let templateDisplayName: String
    let invocationContext: WorkflowInvocationContext
    let renamePreset: BuiltInWorkflowTemplate.RenamePreset?
    let tagPolicy: BuiltInWorkflowTemplate.TagPolicy?
    let projectAssociationPolicy: BuiltInWorkflowTemplate.ProjectAssociationPolicy?
    let workflowStatusPolicy: BuiltInWorkflowTemplate.WorkflowStatusPolicy?
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
    let projectAssociationTarget: String?
    let workflowStatusTarget: MetadataWorkflowStatus?
    let steps: [WorkflowSimulatedStep]
    let blockers: [WorkflowPlanBlockerReason]

    init(
        sourcePath: String,
        workingPath: String,
        finalDestinationPath: String?,
        renameTargetName: String,
        tagIntents: [String],
        projectAssociationTarget: String? = nil,
        workflowStatusTarget: MetadataWorkflowStatus? = nil,
        steps: [WorkflowSimulatedStep],
        blockers: [WorkflowPlanBlockerReason]
    ) {
        self.sourcePath = sourcePath
        self.workingPath = workingPath
        self.finalDestinationPath = finalDestinationPath
        self.renameTargetName = renameTargetName
        self.tagIntents = tagIntents
        self.projectAssociationTarget = projectAssociationTarget
        self.workflowStatusTarget = workflowStatusTarget
        self.steps = steps
        self.blockers = blockers
    }

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
