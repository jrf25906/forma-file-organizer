import Foundation

final class WorkflowPlanner {
    private let fileManager: FileManager
    private let canonicalStepKinds: [WorkflowStepKind] = [.rename, .tag, .move]

    private struct PreliminaryPlannedFile {
        let sourcePath: String
        let workingPath: String
        let finalDestinationPath: String?
        let renameTargetName: String
        let tagIntents: [String]
        var blockers: [WorkflowPlanBlockerReason]
    }

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func plan(templateID: String, files: [FileItem]) -> WorkflowPlan {
        let template = WorkflowTemplateCatalog.template(for: templateID)
        let definition = makeDefinition(templateID: templateID, template: template)

        var preliminaryFiles = files.map { file in
            makePreliminaryPlannedFile(file: file, template: template, definition: definition)
        }

        if definition.renamePreset != nil {
            var indicesByWorkingPath: [String: [Int]] = [:]
            for (index, preliminaryFile) in preliminaryFiles.enumerated() {
                indicesByWorkingPath[preliminaryFile.workingPath, default: []].append(index)
            }

            for (workingPath, indices) in indicesByWorkingPath where indices.count > 1 {
                for index in indices {
                    preliminaryFiles[index].blockers.append(.renameTargetCollision(path: workingPath))
                }
            }
        }

        var indicesByFinalDestinationPath: [String: [Int]] = [:]
        for (index, preliminaryFile) in preliminaryFiles.enumerated() {
            guard let finalDestinationPath = preliminaryFile.finalDestinationPath else {
                continue
            }
            indicesByFinalDestinationPath[finalDestinationPath, default: []].append(index)
        }

        for (finalDestinationPath, indices) in indicesByFinalDestinationPath where indices.count > 1 {
            for index in indices {
                preliminaryFiles[index].blockers.append(.finalDestinationCollision(path: finalDestinationPath))
            }
        }

        for index in preliminaryFiles.indices {
            guard let finalDestinationPath = preliminaryFiles[index].finalDestinationPath else {
                continue
            }
            if fileManager.fileExists(atPath: finalDestinationPath) {
                if pathsReferToSameItem(
                    preliminaryFiles[index].sourcePath,
                    finalDestinationPath
                ) {
                    continue
                }
                preliminaryFiles[index].blockers.append(.finalDestinationCollision(path: finalDestinationPath))
            }
        }

        let plannedFiles = preliminaryFiles.map { preliminaryFile in
            let uniqueBlockers = uniqueBlockers(preliminaryFile.blockers)
            let steps = simulatedSteps(
                blockers: uniqueBlockers,
                sourcePath: preliminaryFile.sourcePath,
                workingPath: preliminaryFile.workingPath,
                finalDestinationPath: preliminaryFile.finalDestinationPath,
                tagIntents: preliminaryFile.tagIntents
            )

            return WorkflowPlannedFile(
                sourcePath: preliminaryFile.sourcePath,
                workingPath: preliminaryFile.workingPath,
                finalDestinationPath: preliminaryFile.finalDestinationPath,
                renameTargetName: preliminaryFile.renameTargetName,
                tagIntents: preliminaryFile.tagIntents,
                steps: steps,
                blockers: uniqueBlockers
            )
        }
        let simulation = WorkflowSimulationReport(
            files: plannedFiles.map { plannedFile in
                WorkflowFileSimulation(
                    sourcePath: plannedFile.sourcePath,
                    blockers: plannedFile.blockers,
                    steps: plannedFile.steps
                )
            }
        )

        return WorkflowPlan(
            definition: definition,
            files: plannedFiles,
            simulation: simulation
        )
    }

    private func makeDefinition(
        templateID: String,
        template: BuiltInWorkflowTemplate?
    ) -> WorkflowDefinition {
        WorkflowDefinition(
            templateID: templateID,
            templateDisplayName: template?.displayName ?? "Unknown Workflow Template",
            renamePreset: template?.renamePreset,
            tagPolicy: template?.tagPolicy,
            stepKinds: canonicalStepKinds
        )
    }

    private func makePreliminaryPlannedFile(
        file: FileItem,
        template: BuiltInWorkflowTemplate?,
        definition: WorkflowDefinition
    ) -> PreliminaryPlannedFile {
        let sourcePath = URL(fileURLWithPath: file.path).standardizedFileURL.path
        let sourceDirectoryPath = URL(fileURLWithPath: sourcePath)
            .deletingLastPathComponent()
            .standardizedFileURL
            .path
        let plannedRenameTargetName: String
        let workingPath: String
        let plannedTagIntents: [String]
        if let renamePreset = definition.renamePreset {
            plannedRenameTargetName = renameTargetName(for: file, preset: renamePreset)
            workingPath = URL(fileURLWithPath: sourceDirectoryPath)
                .appendingPathComponent(plannedRenameTargetName)
                .standardizedFileURL
                .path
        } else {
            plannedRenameTargetName = URL(fileURLWithPath: sourcePath).lastPathComponent
            workingPath = sourcePath
        }

        if let tagPolicy = definition.tagPolicy {
            plannedTagIntents = tagIntents(for: tagPolicy)
        } else {
            plannedTagIntents = []
        }

        var blockers: [WorkflowPlanBlockerReason] = []

        if template == nil {
            blockers.append(.templateUnavailable(templateID: definition.templateID))
        }

        if !fileManager.fileExists(atPath: sourcePath) {
            blockers.append(.sourceFileMissing(path: sourcePath))
            blockers.append(
                .compensationPreconditionMissing(
                    stepKind: .rename,
                    detail: "Source file must exist before rollback payloads can be trusted."
                )
            )
        }

        if definition.renamePreset != nil &&
            sourcePath != workingPath &&
            fileManager.fileExists(atPath: workingPath) {
            blockers.append(.renameTargetCollision(path: workingPath))
        }

        let finalDestinationPath: String?
        if definition.renamePreset != nil && definition.tagPolicy != nil {
            finalDestinationPath = plannedDestinationPath(
                for: file,
                renameTargetName: plannedRenameTargetName,
                blockers: &blockers
            )
        } else {
            finalDestinationPath = nil
        }

        var sourceParentIsDirectory = ObjCBool(false)
        if !fileManager.fileExists(atPath: sourceDirectoryPath, isDirectory: &sourceParentIsDirectory) || !sourceParentIsDirectory.boolValue {
            blockers.append(
                .compensationPreconditionMissing(
                    stepKind: .move,
                    detail: "Source parent folder is unavailable for move rollback."
                )
            )
        }

        return PreliminaryPlannedFile(
            sourcePath: sourcePath,
            workingPath: workingPath,
            finalDestinationPath: finalDestinationPath,
            renameTargetName: plannedRenameTargetName,
            tagIntents: plannedTagIntents,
            blockers: blockers
        )
    }

    private func plannedDestinationPath(
        for file: FileItem,
        renameTargetName: String,
        blockers: inout [WorkflowPlanBlockerReason]
    ) -> String? {
        guard let destination = file.destination else {
            blockers.append(.destinationMissing)
            return nil
        }

        guard !destination.isTrash else {
            blockers.append(
                .compensationPreconditionMissing(
                    stepKind: .move,
                    detail: "Workflow move step requires a folder destination with stable rollback."
                )
            )
            return nil
        }

        guard let resolved = destination.resolve() else {
            blockers.append(.destinationUnavailable(displayName: destination.displayName))
            return nil
        }

        let destinationFolderPath = resolved.url.standardizedFileURL.path
        return URL(fileURLWithPath: destinationFolderPath)
            .appendingPathComponent(renameTargetName)
            .standardizedFileURL
            .path
    }

    private func simulatedSteps(
        blockers: [WorkflowPlanBlockerReason],
        sourcePath: String,
        workingPath: String,
        finalDestinationPath: String?,
        tagIntents: [String]
    ) -> [WorkflowSimulatedStep] {
        var earlierStepBlocker: WorkflowPlanBlockerReason?

        return canonicalStepKinds.map { stepKind in
            let directBlocker = blockers.first(where: { blocker in
                blockerAffectsStep(blocker, stepKind: stepKind)
            })

            if let earlierStepBlocker {
                return WorkflowSimulatedStep(
                    kind: stepKind,
                    disposition: .skipped,
                    blocker: earlierStepBlocker,
                    compensationPayload: nil
                )
            }

            if let directBlocker {
                earlierStepBlocker = directBlocker
                return WorkflowSimulatedStep(
                    kind: stepKind,
                    disposition: .blocked,
                    blocker: directBlocker,
                    compensationPayload: nil
                )
            }

            return WorkflowSimulatedStep(
                kind: stepKind,
                disposition: .planned,
                blocker: nil,
                compensationPayload: compensationPayloadDescriptor(
                    for: stepKind,
                    disposition: .planned,
                    sourcePath: sourcePath,
                    workingPath: workingPath,
                    finalDestinationPath: finalDestinationPath,
                    tagIntents: tagIntents
                )
            )
        }
    }

    private func blockerAffectsStep(
        _ blocker: WorkflowPlanBlockerReason,
        stepKind: WorkflowStepKind
    ) -> Bool {
        switch blocker {
        case .templateUnavailable, .sourceFileMissing:
            return true
        case .renameTargetCollision:
            return stepKind == .rename
        case .finalDestinationCollision, .destinationMissing, .destinationUnavailable:
            return stepKind == .move
        case .compensationPreconditionMissing(let blockerStepKind, _):
            return blockerStepKind == stepKind
        }
    }

    private func compensationPayloadDescriptor(
        for stepKind: WorkflowStepKind,
        disposition: WorkflowStepDisposition,
        sourcePath: String,
        workingPath: String,
        finalDestinationPath: String?,
        tagIntents: [String]
    ) -> WorkflowCompensationPayloadDescriptor? {
        guard disposition == .planned else {
            return nil
        }

        switch stepKind {
        case .rename:
            return .renameRollback(originalPath: sourcePath, renamedPath: workingPath)
        case .tag:
            return .tagRemoval(path: workingPath, tagsToRemove: tagIntents)
        case .move:
            guard let finalDestinationPath else {
                return nil
            }
            return .moveRollback(
                originalDestinationPath: finalDestinationPath,
                rollbackPath: workingPath
            )
        }
    }

    private func renameTargetName(
        for file: FileItem,
        preset: BuiltInWorkflowTemplate.RenamePreset
    ) -> String {
        let sourceURL = URL(fileURLWithPath: file.path)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let extensionName = sourceURL.pathExtension

        let renamedBase: String
        switch preset {
        case .keepBaseNameWithDatePrefix:
            let datePrefix = dayFormatter.string(from: file.creationDate)
            let sanitized = FilenameUtilities.sanitizeForMacOS(baseName)
            renamedBase = "\(datePrefix)-\(sanitized)"
        case .screenshotTimestamp:
            let timestamp = timestampFormatter.string(from: file.creationDate)
            renamedBase = "Screenshot-\(timestamp)"
        case .projectIntakeSlug:
            let slug = slugify(baseName)
            renamedBase = slug.isEmpty ? "project-file" : slug
        }

        if extensionName.isEmpty {
            return renamedBase
        }
        return "\(renamedBase).\(extensionName)"
    }

    private func tagIntents(for policy: BuiltInWorkflowTemplate.TagPolicy) -> [String] {
        switch policy {
        case .financialDocuments:
            return ["finance", "receipt", "document"]
        case .visualReference:
            return ["visual-reference", "screenshot", "reference"]
        case .projectContext:
            return ["project", "context", "intake"]
        }
    }

    private func slugify(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let lowercased = folded.lowercased()
        let alphanumerics = CharacterSet.alphanumerics

        var scalars: [UnicodeScalar] = []
        var previousWasDash = false

        for scalar in lowercased.unicodeScalars {
            if alphanumerics.contains(scalar) {
                scalars.append(scalar)
                previousWasDash = false
            } else if !previousWasDash {
                scalars.append("-")
                previousWasDash = true
            }
        }

        let rawSlug = String(String.UnicodeScalarView(scalars))
        return rawSlug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func uniqueBlockers(_ blockers: [WorkflowPlanBlockerReason]) -> [WorkflowPlanBlockerReason] {
        var seen = Set<WorkflowPlanBlockerReason>()
        var result: [WorkflowPlanBlockerReason] = []
        for blocker in blockers where seen.insert(blocker).inserted {
            result.append(blocker)
        }
        return result
    }

    private func pathsReferToSameItem(_ lhsPath: String, _ rhsPath: String) -> Bool {
        normalizedPath(lhsPath) == normalizedPath(rhsPath)
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
