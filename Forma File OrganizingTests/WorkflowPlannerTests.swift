import XCTest
@testable import Forma_File_Organizing

final class WorkflowPlannerTests: XCTestCase {
    private var sourceDirectory: TemporaryDirectory!
    private var destinationDirectory: TemporaryDirectory!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sourceDirectory = try TemporaryDirectory()
        destinationDirectory = try TemporaryDirectory()
    }

    override func tearDownWithError() throws {
        sourceDirectory?.cleanup()
        destinationDirectory?.cleanup()
        sourceDirectory = nil
        destinationDirectory = nil
        try super.tearDownWithError()
    }

    func testPlan_TemplateProducesRenameTagMoveStepsInOrder() throws {
        let sourceURL = try sourceDirectory.createFile(name: "April Receipt.pdf")
        let destinationURL = try destinationDirectory.createDirectory(name: "Receipts")
        let destination = try Destination.folder(from: destinationURL)
        let file = makeFile(path: sourceURL.path, destination: destination)

        let planner = WorkflowPlanner()
        let plan = planner.plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [file]
        )

        XCTAssertEqual(plan.definition.stepKinds, [.rename, .tag, .move])
        XCTAssertEqual(plan.files.count, 1)

        let plannedFile = try XCTUnwrap(plan.files.first)
        XCTAssertFalse(plannedFile.isBlocked)
        XCTAssertTrue(plannedFile.blockers.isEmpty)
        XCTAssertEqual(plannedFile.steps.map(\.kind), [.rename, .tag, .move])
        XCTAssertEqual(plannedFile.steps.map(\.disposition), [.planned, .planned, .planned])
        let tagStep = try XCTUnwrap(plannedFile.steps.first(where: { $0.kind == .tag }))
        XCTAssertEqual(
            tagStep.compensationPayload,
            .tagRemoval(path: plannedFile.workingPath, tagsToRemove: plannedFile.tagIntents)
        )
        XCTAssertEqual(plannedFile.sourcePath, sourceURL.path)
        XCTAssertNotEqual(plannedFile.workingPath, plannedFile.sourcePath)
        XCTAssertEqual(
            plannedFile.finalDestinationPath,
            destinationURL.appendingPathComponent(URL(fileURLWithPath: plannedFile.workingPath).lastPathComponent).path
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Planning must be read-only")
    }

    func testPlan_BlocksWhenRenameTargetCollides() throws {
        let sourceURL = try sourceDirectory.createFile(name: "Invoice.pdf")
        let destinationURL = try destinationDirectory.createDirectory(name: "Receipts")
        let destination = try Destination.folder(from: destinationURL)

        let creationDate = Date(timeIntervalSince1970: 1_712_620_800) // 2024-04-09T00:00:00Z
        let collidingName = "2024-04-09-Invoice.pdf"
        let collidingURL = try sourceDirectory.createFile(name: collidingName)

        let file = makeFile(
            path: sourceURL.path,
            creationDate: creationDate,
            destination: destination
        )

        let planner = WorkflowPlanner()
        let plan = planner.plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [file]
        )

        let plannedFile = try XCTUnwrap(plan.files.first)
        let simulatedFile = try XCTUnwrap(plan.simulation.files.first(where: { $0.sourcePath == sourceURL.path }))

        XCTAssertTrue(simulatedFile.isBlocked)
        XCTAssertTrue(
            simulatedFile.blockers.contains(.renameTargetCollision(path: collidingURL.path)),
            "Expected collision blocker for pre-existing rename target"
        )
        XCTAssertEqual(simulatedFile.steps.map(\.kind), [.rename, .tag, .move])
        XCTAssertEqual(simulatedFile.steps.map(\.disposition), [.blocked, .skipped, .skipped])
        XCTAssertTrue(plannedFile.isBlocked)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Planning must not rename source files")
        XCTAssertTrue(FileManager.default.fileExists(atPath: collidingURL.path), "Planning must not mutate colliding files")
    }

    func testPlan_BlocksWhenDestinationOrCompensationPreconditionsAreMissing() throws {
        let sourceWithMissingDestination = try sourceDirectory.createFile(name: "NoDestination.pdf")
        let sourceWithMissingCompensation = sourceDirectory.url(for: "missing/SourceThatDoesNotExist.pdf")

        let destinationURL = try destinationDirectory.createDirectory(name: "Receipts")
        let destination = try Destination.folder(from: destinationURL)

        let fileWithoutDestination = makeFile(
            path: sourceWithMissingDestination.path,
            destination: nil
        )
        let fileWithoutCompensationPrecondition = makeFile(
            path: sourceWithMissingCompensation.path,
            destination: destination
        )

        let planner = WorkflowPlanner()
        let plan = planner.plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [fileWithoutDestination, fileWithoutCompensationPrecondition]
        )

        XCTAssertEqual(plan.files.count, 2)
        XCTAssertEqual(plan.simulation.files.count, 2)

        let missingDestinationSimulation = try XCTUnwrap(plan.simulation.files.first(where: { $0.sourcePath == sourceWithMissingDestination.path }))
        XCTAssertTrue(missingDestinationSimulation.isBlocked)
        XCTAssertTrue(missingDestinationSimulation.blockers.contains(.destinationMissing))

        let missingCompensationSimulation = try XCTUnwrap(plan.simulation.files.first(where: { $0.sourcePath == sourceWithMissingCompensation.path }))
        XCTAssertTrue(missingCompensationSimulation.isBlocked)
        XCTAssertTrue(
            missingCompensationSimulation.blockers.contains(where: {
                guard case .compensationPreconditionMissing(stepKind: .rename, detail: _) = $0 else { return false }
                return true
            }),
            "Expected compensation precondition blocker when source snapshot cannot be trusted"
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceWithMissingDestination.path), "Planning must not mutate source files")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceWithMissingCompensation.path), "Planner must not create missing files")
    }

    func testPlan_UnknownTemplateIDBlocksWithoutDerivingRenameOrTagBehavior() throws {
        let sourceURL = try sourceDirectory.createFile(name: "Receipt.pdf")
        let destinationURL = try destinationDirectory.createDirectory(name: "Receipts")
        let destination = try Destination.folder(from: destinationURL)
        let file = makeFile(path: sourceURL.path, destination: destination)

        let planner = WorkflowPlanner()
        let plan = planner.plan(
            templateID: "builtin.workflow.unknown.v1",
            files: [file]
        )

        XCTAssertEqual(plan.definition.templateID, "builtin.workflow.unknown.v1")
        XCTAssertEqual(plan.definition.templateDisplayName, "Unknown Workflow Template")
        XCTAssertNil(plan.definition.renamePreset)
        XCTAssertNil(plan.definition.tagPolicy)
        XCTAssertEqual(plan.definition.stepKinds, [.rename, .tag, .move])

        let plannedFile = try XCTUnwrap(plan.files.first)
        let simulatedFile = try XCTUnwrap(plan.simulation.files.first)
        XCTAssertEqual(plannedFile.sourcePath, sourceURL.path)
        XCTAssertEqual(plannedFile.workingPath, sourceURL.path)
        XCTAssertEqual(plannedFile.renameTargetName, "Receipt.pdf")
        XCTAssertTrue(plannedFile.tagIntents.isEmpty)
        XCTAssertNil(plannedFile.finalDestinationPath)

        XCTAssertTrue(simulatedFile.isBlocked)
        XCTAssertTrue(
            simulatedFile.blockers.contains(.templateUnavailable(templateID: "builtin.workflow.unknown.v1"))
        )
        XCTAssertEqual(simulatedFile.steps.map(\.disposition), [.blocked, .skipped, .skipped])
    }

    func testPlan_BlocksWhenTwoBatchInputsCanonicalizeToSameWorkingPath() throws {
        let sourceA = try sourceDirectory.createFile(name: "Project Plan!.pdf")
        let sourceB = try sourceDirectory.createFile(name: "project-plan.pdf")

        let destinationURL = try destinationDirectory.createDirectory(name: "ProjectDrop")
        let destination = try Destination.folder(from: destinationURL)

        let fileA = makeFile(path: sourceA.path, destination: destination)
        let fileB = makeFile(path: sourceB.path, destination: destination)

        let planner = WorkflowPlanner()
        let plan = planner.plan(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            files: [fileA, fileB]
        )

        let expectedWorkingPath = sourceDirectory.url(for: "project-plan.pdf").path

        XCTAssertEqual(plan.simulation.files.count, 2)
        for simulationFile in plan.simulation.files {
            XCTAssertTrue(simulationFile.isBlocked)
            XCTAssertTrue(
                simulationFile.blockers.contains(.renameTargetCollision(path: expectedWorkingPath)),
                "Expected same-batch collision for canonical rename path"
            )
            XCTAssertEqual(simulationFile.steps.map(\.disposition), [.blocked, .skipped, .skipped])
        }
    }

    func testPlan_BlocksWhenFinalDestinationPathAlreadyExists() throws {
        let sourceURL = try sourceDirectory.createFile(name: "Invoice.pdf")
        let destinationURL = try destinationDirectory.createDirectory(name: "Receipts")
        let destination = try Destination.folder(from: destinationURL)

        let creationDate = Date(timeIntervalSince1970: 1_712_620_800) // 2024-04-09T00:00:00Z
        let existingFinalPath = destinationURL.appendingPathComponent("2024-04-09-Invoice.pdf").path
        _ = try destinationDirectory.createFile(name: "Receipts/2024-04-09-Invoice.pdf")

        let file = makeFile(
            path: sourceURL.path,
            creationDate: creationDate,
            destination: destination
        )

        let planner = WorkflowPlanner()
        let plan = planner.plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [file]
        )

        let simulationFile = try XCTUnwrap(plan.simulation.files.first)
        XCTAssertTrue(simulationFile.isBlocked)
        XCTAssertTrue(
            simulationFile.blockers.contains(.finalDestinationCollision(path: existingFinalPath)),
            "Expected destination collision blocker when target move path already exists"
        )
        XCTAssertEqual(simulationFile.steps.map(\.disposition), [.planned, .planned, .blocked])
    }

    func testPlan_DoesNotBlockWhenFileAlreadyOccupiesFinalDestinationPath() throws {
        let projectDropURL = try sourceDirectory.createDirectory(name: "ProjectDrop")
        let sourceURL = try sourceDirectory.createFile(name: "ProjectDrop/project-plan.pdf")
        let destination = try Destination.folder(from: projectDropURL)

        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)
        let file = makeFile(
            path: sourceURL.path,
            creationDate: creationDate,
            destination: destination
        )

        let planner = WorkflowPlanner()
        let plan = planner.plan(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            files: [file]
        )

        let plannedFile = try XCTUnwrap(plan.files.first)
        let simulationFile = try XCTUnwrap(plan.simulation.files.first)

        XCTAssertEqual(plannedFile.sourcePath, sourceURL.path)
        XCTAssertEqual(plannedFile.finalDestinationPath, sourceURL.path)
        XCTAssertFalse(simulationFile.isBlocked)
        XCTAssertFalse(
            simulationFile.blockers.contains(where: {
                if case .finalDestinationCollision = $0 { return true }
                return false
            }),
            "Self-occupancy at final destination should not be treated as a collision blocker"
        )
    }

    func testPlan_BlocksWhenTwoBatchFilesConvergeOnSameFinalDestinationPath() throws {
        let sourceA = try sourceDirectory.createFile(name: "A/Invoice.pdf")
        let sourceB = try sourceDirectory.createFile(name: "B/Invoice.pdf")

        let destinationURL = try destinationDirectory.createDirectory(name: "Receipts")
        let destination = try Destination.folder(from: destinationURL)

        let creationDate = Date(timeIntervalSince1970: 1_712_620_800) // 2024-04-09T00:00:00Z
        let fileA = makeFile(path: sourceA.path, creationDate: creationDate, destination: destination)
        let fileB = makeFile(path: sourceB.path, creationDate: creationDate, destination: destination)

        let planner = WorkflowPlanner()
        let plan = planner.plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [fileA, fileB]
        )

        let finalDestinationPath = destinationURL.appendingPathComponent("2024-04-09-Invoice.pdf").path

        XCTAssertEqual(plan.files.count, 2)
        XCTAssertEqual(plan.simulation.files.count, 2)
        XCTAssertNotEqual(plan.files[0].workingPath, plan.files[1].workingPath)
        XCTAssertEqual(plan.files[0].finalDestinationPath, finalDestinationPath)
        XCTAssertEqual(plan.files[1].finalDestinationPath, finalDestinationPath)

        for simulationFile in plan.simulation.files {
            XCTAssertTrue(simulationFile.isBlocked)
            XCTAssertTrue(
                simulationFile.blockers.contains(.finalDestinationCollision(path: finalDestinationPath)),
                "Expected same-batch collision on final destination path"
            )
            XCTAssertEqual(simulationFile.steps.map(\.disposition), [.planned, .planned, .blocked])
        }
    }

    private func makeFile(
        path: String,
        creationDate: Date = Date(timeIntervalSince1970: 1_712_620_800),
        destination: Destination?
    ) -> FileItem {
        FileItem(
            path: path,
            sizeInBytes: 1_024,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            destination: destination,
            status: .pending
        )
    }
}
