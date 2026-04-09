import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class ProjectSpaceAutomationCoordinatorTests: XCTestCase {
    private enum InjectedFailure: Error {
        case admissionWrite
        case recordRun
    }

    @MainActor
    private final class WorkflowExecutionSpy {
        private(set) var plannedTemplateIDs: [String] = []
        private(set) var plannedInvocationContexts: [WorkflowInvocationContext] = []
        private(set) var lastPlannedFilePaths: [String] = []
        private(set) var ranTemplateIDs: [String] = []
        private(set) var lastRunFilePaths: [String] = []
        var onRun: (() -> Void)?

        lazy var client = WorkflowExecutionClient(
            plan: { [weak self] templateID, files, invocationContext in
                self?.plannedTemplateIDs.append(templateID)
                self?.plannedInvocationContexts.append(invocationContext)
                self?.lastPlannedFilePaths = files.map(\.path)
                return WorkflowPlanner().plan(
                    templateID: templateID,
                    files: files,
                    invocationContext: invocationContext
                )
            },
            run: { [weak self] plan, _, scopeID, modelContext in
                await MainActor.run {
                    self?.ranTemplateIDs.append(plan.definition.templateID)
                    self?.lastRunFilePaths = plan.files.map(\.sourcePath)
                    self?.onRun?()
                }

                let run = WorkflowRunRecord(
                    scopeID: scopeID,
                    workflowTemplateID: plan.definition.templateID,
                    primaryStatus: .succeeded,
                    startedAt: Date(timeIntervalSince1970: 2_000),
                    endedAt: Date(timeIntervalSince1970: 2_005)
                )
                modelContext.insert(run)
                try modelContext.save()
                return run
            }
        )
    }

    private struct FailingAdmissionWriter: ProjectSpaceAutomationAdmissionWriting {
        func admitToProjectSpace(
            canonicalIdentity: String,
            projectLabel: String,
            detailsSummary: String,
            timestamp: Date
        ) throws {
            throw InjectedFailure.admissionWrite
        }
    }

    override func setUp() {
        super.setUp()
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        super.tearDown()
    }

    func testRecommendations_DeriveProjectPoliciesFromDominantProjectMemory() {
        let now = Date(timeIntervalSince1970: 4_000)
        let detail = makeProjectSpaceDetail(
            projectLabel: "Alpha",
            fileRows: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "identity-alpha",
                    path: "/tmp/alpha/spec.md",
                    displayName: "spec.md",
                    sourceFolderHint: "Alpha"
                )
            ],
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 4,
                    lastUsedAt: now.addingTimeInterval(-120)
                ),
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Reference",
                    eventCount: 1,
                    lastUsedAt: now.addingTimeInterval(-600)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "identity-alpha",
                    fileDisplayName: "spec.md",
                    eventKind: .organized,
                    timestamp: now.addingTimeInterval(-120),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "identity-beta",
                    fileDisplayName: "brief.md",
                    eventKind: .rekeyed,
                    timestamp: now.addingTimeInterval(-240),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                )
            ]
        )

        let recommendations = ProjectSpaceAutomationRecommendationService()
            .recommendedPolicies(for: detail, now: now)

        XCTAssertEqual(recommendations.count, 1)
        XCTAssertEqual(recommendations.first?.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
        XCTAssertEqual(recommendations.first?.triggerKinds, [ProjectSpaceAutomationTriggerKind.manual])
        XCTAssertEqual(recommendations.first?.admissionMode, .automatic)
    }

    func testRecommendations_DoNotCreatePoliciesWhenEvidenceIsTooWeak() {
        let now = Date(timeIntervalSince1970: 4_000)
        let detail = makeProjectSpaceDetail(
            projectLabel: "Alpha",
            fileRows: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "identity-alpha",
                    path: "/tmp/alpha/spec.md",
                    displayName: "spec.md",
                    sourceFolderHint: "Alpha"
                )
            ],
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 1,
                    lastUsedAt: now.addingTimeInterval(-120)
                ),
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Beta",
                    eventCount: 1,
                    lastUsedAt: now.addingTimeInterval(-180)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "identity-alpha",
                    fileDisplayName: "spec.md",
                    eventKind: .organized,
                    timestamp: now.addingTimeInterval(-120),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                )
            ]
        )

        let recommendations = ProjectSpaceAutomationRecommendationService()
            .recommendedPolicies(for: detail, now: now)

        XCTAssertTrue(recommendations.isEmpty)
    }

    func testExecutePolicy_StrongConfirmedAdmissionWritesProjectAssociationBeforeWorkflowRun() async throws {
        let environment = try makeEnvironment()
        defer { environment.sourceRoot.cleanup() }
        defer { environment.destinationRoot.cleanup() }

        let record = try insertMetadataRecord(
            in: environment.context,
            service: environment.metadataService,
            path: environment.file.path,
            displayName: environment.file.name,
            timestamp: environment.timestamp
        )
        let detail = makeProjectSpaceDetail(
            projectLabel: "Alpha",
            fileRows: [
                ProjectSpaceFileRow(
                    canonicalIdentity: record.canonicalIdentity,
                    path: environment.file.path,
                    displayName: environment.file.name,
                    sourceFolderHint: "Alpha"
                )
            ],
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 3,
                    lastUsedAt: environment.timestamp.addingTimeInterval(-60)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: record.canonicalIdentity,
                    fileDisplayName: environment.file.name,
                    eventKind: .organized,
                    timestamp: environment.timestamp.addingTimeInterval(-60),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "supporting-row",
                    fileDisplayName: "brief.md",
                    eventKind: .rekeyed,
                    timestamp: environment.timestamp.addingTimeInterval(-120),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Renamed into Alpha."
                )
            ]
        )

        environment.workflowExecution.onRun = {
            XCTAssertEqual(record.projectAssociation, "Alpha")
            let notedEntries = record.historyEntries.filter { $0.eventKind == .noted }
            XCTAssertEqual(notedEntries.count, 1)
            XCTAssertEqual(notedEntries.first?.detailsSummary, "Admitted to project space Alpha before policy execution.")
        }

        _ = try await environment.coordinator.executePolicy(
            environment.policy,
            detail: detail,
            files: [environment.file],
            triggerKind: ProjectSpaceAutomationTriggerKind.manual,
            now: environment.timestamp
        )

        XCTAssertEqual(environment.workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.projectDrop])
    }

    func testExecutePolicy_FailedAdmissionWritePreventsWorkflowExecution() async throws {
        let environment = try makeEnvironment(admissionWriter: FailingAdmissionWriter())
        defer { environment.sourceRoot.cleanup() }
        defer { environment.destinationRoot.cleanup() }

        let record = try insertMetadataRecord(
            in: environment.context,
            service: environment.metadataService,
            path: environment.file.path,
            displayName: environment.file.name,
            timestamp: environment.timestamp
        )
        let detail = makeProjectSpaceDetail(
            projectLabel: "Alpha",
            fileRows: [
                ProjectSpaceFileRow(
                    canonicalIdentity: record.canonicalIdentity,
                    path: environment.file.path,
                    displayName: environment.file.name,
                    sourceFolderHint: "Alpha"
                )
            ],
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 3,
                    lastUsedAt: environment.timestamp.addingTimeInterval(-60)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: record.canonicalIdentity,
                    fileDisplayName: environment.file.name,
                    eventKind: .organized,
                    timestamp: environment.timestamp.addingTimeInterval(-60),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "supporting-row",
                    fileDisplayName: "brief.md",
                    eventKind: .rekeyed,
                    timestamp: environment.timestamp.addingTimeInterval(-120),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Renamed into Alpha."
                )
            ]
        )

        do {
            _ = try await environment.coordinator.executePolicy(
                environment.policy,
                detail: detail,
                files: [environment.file],
                triggerKind: ProjectSpaceAutomationTriggerKind.manual,
                now: environment.timestamp
            )
            XCTFail("Expected admission write failure to prevent execution")
        } catch {
        }

        XCTAssertTrue(environment.workflowExecution.ranTemplateIDs.isEmpty)
        XCTAssertEqual(try environment.context.fetch(FetchDescriptor<ProjectSpaceAutomationRunRecord>()).count, 0)
    }

    func testExecutePolicy_PersistsPolicyRunSummaryLinkedToWorkflowRun() async throws {
        let environment = try makeEnvironment()
        defer { environment.sourceRoot.cleanup() }
        defer { environment.destinationRoot.cleanup() }

        let record = try insertMetadataRecord(
            in: environment.context,
            service: environment.metadataService,
            path: environment.file.path,
            displayName: environment.file.name,
            timestamp: environment.timestamp
        )
        let detail = makeProjectSpaceDetail(
            projectLabel: "Alpha",
            fileRows: [
                ProjectSpaceFileRow(
                    canonicalIdentity: record.canonicalIdentity,
                    path: environment.file.path,
                    displayName: environment.file.name,
                    sourceFolderHint: "Alpha"
                )
            ],
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 3,
                    lastUsedAt: environment.timestamp.addingTimeInterval(-60)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: record.canonicalIdentity,
                    fileDisplayName: environment.file.name,
                    eventKind: .organized,
                    timestamp: environment.timestamp.addingTimeInterval(-60),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "supporting-row",
                    fileDisplayName: "brief.md",
                    eventKind: .rekeyed,
                    timestamp: environment.timestamp.addingTimeInterval(-120),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Renamed into Alpha."
                )
            ]
        )

        let runRecord = try await environment.coordinator.executePolicy(
            environment.policy,
            detail: detail,
            files: [environment.file],
            triggerKind: ProjectSpaceAutomationTriggerKind.manual,
            now: environment.timestamp
        )

        let persistedAutomationRuns = try environment.context.fetch(FetchDescriptor<ProjectSpaceAutomationRunRecord>())
        let persistedWorkflowRuns = try environment.context.fetch(FetchDescriptor<WorkflowRunRecord>())

        XCTAssertEqual(persistedAutomationRuns.count, 1)
        XCTAssertEqual(persistedWorkflowRuns.count, 1)
        XCTAssertEqual(persistedAutomationRuns.first?.id, runRecord.id)
        XCTAssertEqual(persistedAutomationRuns.first?.workflowRunID, persistedWorkflowRuns.first?.id)
        XCTAssertEqual(persistedAutomationRuns.first?.status, .succeeded)
    }

    func testExecutePolicy_AutomaticAdmissionRunsOnlyEligibleFiles() async throws {
        let environment = try makeEnvironment()
        defer { environment.sourceRoot.cleanup() }
        defer { environment.destinationRoot.cleanup() }

        let existingURL = try environment.sourceRoot.createFile(name: "Alpha/existing.md", contents: "existing")
        let strongURL = try environment.sourceRoot.createFile(name: "Alpha/strong.md", contents: "strong")
        let insufficientURL = try environment.sourceRoot.createFile(name: "Misc/insufficient.md", contents: "insufficient")
        let unmatchedURL = try environment.sourceRoot.createFile(name: "Loose/unmatched.md", contents: "unmatched")
        let projectDestination = try Destination.folder(
            from: environment.destinationRoot.url.appendingPathComponent("Alpha"),
            displayName: "Alpha"
        )

        let existingFile = makeFileItem(
            path: existingURL.path,
            rootPath: environment.sourceRoot.url.path,
            relativeParentPath: "Alpha",
            timestamp: environment.timestamp,
            destination: projectDestination
        )
        let strongFile = makeFileItem(
            path: strongURL.path,
            rootPath: environment.sourceRoot.url.path,
            relativeParentPath: "Alpha",
            timestamp: environment.timestamp,
            destination: projectDestination
        )
        let insufficientFile = makeFileItem(path: insufficientURL.path, rootPath: environment.sourceRoot.url.path, relativeParentPath: "Misc", timestamp: environment.timestamp)
        let unmatchedFile = makeFileItem(path: unmatchedURL.path, rootPath: environment.sourceRoot.url.path, relativeParentPath: "Loose", timestamp: environment.timestamp)

        for file in [existingFile, strongFile, insufficientFile, unmatchedFile] {
            environment.context.insert(file)
        }

        let existingRecord = try insertMetadataRecord(
            in: environment.context,
            service: environment.metadataService,
            path: existingFile.path,
            displayName: existingFile.name,
            timestamp: environment.timestamp
        )
        existingRecord.projectAssociation = "Alpha"

        let strongRecord = try insertMetadataRecord(
            in: environment.context,
            service: environment.metadataService,
            path: strongFile.path,
            displayName: strongFile.name,
            timestamp: environment.timestamp
        )
        let insufficientRecord = try insertMetadataRecord(
            in: environment.context,
            service: environment.metadataService,
            path: insufficientFile.path,
            displayName: insufficientFile.name,
            timestamp: environment.timestamp
        )
        try environment.context.save()

        let detail = makeProjectSpaceDetail(
            projectLabel: "Alpha",
            fileRows: [
                ProjectSpaceFileRow(
                    canonicalIdentity: existingRecord.canonicalIdentity,
                    path: existingFile.path,
                    displayName: existingFile.name,
                    projectAssociation: "Alpha",
                    sourceFolderHint: "Alpha"
                ),
                ProjectSpaceFileRow(
                    canonicalIdentity: strongRecord.canonicalIdentity,
                    path: strongFile.path,
                    displayName: strongFile.name,
                    sourceFolderHint: "Alpha"
                ),
                ProjectSpaceFileRow(
                    canonicalIdentity: insufficientRecord.canonicalIdentity,
                    path: insufficientFile.path,
                    displayName: insufficientFile.name,
                    sourceFolderHint: nil
                )
            ],
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 3,
                    lastUsedAt: environment.timestamp.addingTimeInterval(-60)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: strongRecord.canonicalIdentity,
                    fileDisplayName: strongFile.name,
                    eventKind: .organized,
                    timestamp: environment.timestamp.addingTimeInterval(-60),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: existingRecord.canonicalIdentity,
                    fileDisplayName: existingFile.name,
                    eventKind: .rekeyed,
                    timestamp: environment.timestamp.addingTimeInterval(-120),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Renamed into Alpha."
                )
            ]
        )

        _ = try await environment.coordinator.executePolicy(
            environment.policy,
            detail: detail,
            files: [existingFile, strongFile, insufficientFile, unmatchedFile],
            triggerKind: .manual,
            now: environment.timestamp
        )

        XCTAssertEqual(
            environment.workflowExecution.lastPlannedFilePaths.sorted(),
            [existingFile.path, strongFile.path].sorted()
        )
        XCTAssertEqual(
            environment.workflowExecution.lastRunFilePaths.sorted(),
            [existingFile.path, strongFile.path].sorted()
        )
        XCTAssertEqual(existingRecord.projectAssociation, "Alpha")
        XCTAssertEqual(strongRecord.projectAssociation, "Alpha")
        XCTAssertNil(insufficientRecord.projectAssociation)
        XCTAssertTrue(existingRecord.historyEntries.filter { $0.eventKind == .noted }.isEmpty)
        XCTAssertEqual(strongRecord.historyEntries.filter { $0.eventKind == .noted }.count, 1)
        XCTAssertTrue(insufficientRecord.historyEntries.filter { $0.eventKind == .noted }.isEmpty)
    }

    func testExecutePolicy_AutomaticAdmissionRejectsStaleDominantDestinationEvidence() async throws {
        let environment = try makeEnvironment()
        defer { environment.sourceRoot.cleanup() }
        defer { environment.destinationRoot.cleanup() }

        let record = try insertMetadataRecord(
            in: environment.context,
            service: environment.metadataService,
            path: environment.file.path,
            displayName: environment.file.name,
            timestamp: environment.timestamp
        )

        let detail = makeProjectSpaceDetail(
            projectLabel: "Alpha",
            fileRows: [
                ProjectSpaceFileRow(
                    canonicalIdentity: record.canonicalIdentity,
                    path: environment.file.path,
                    displayName: environment.file.name,
                    sourceFolderHint: "Alpha"
                )
            ],
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 3,
                    lastUsedAt: environment.timestamp.addingTimeInterval(-(31 * 24 * 60 * 60))
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: record.canonicalIdentity,
                    fileDisplayName: environment.file.name,
                    eventKind: .organized,
                    timestamp: environment.timestamp.addingTimeInterval(-(31 * 24 * 60 * 60)),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Old move into Alpha."
                )
            ]
        )

        do {
            _ = try await environment.coordinator.executePolicy(
                environment.policy,
                detail: detail,
                files: [environment.file],
                triggerKind: .manual,
                now: environment.timestamp
            )
            XCTFail("Expected stale automatic-admission evidence to reject execution")
        } catch {
        }

        XCTAssertTrue(environment.workflowExecution.ranTemplateIDs.isEmpty)
        XCTAssertNil(record.projectAssociation)
        XCTAssertEqual(try environment.context.fetch(FetchDescriptor<ProjectSpaceAutomationRunRecord>()).count, 0)
    }

    func testExecutePolicy_PostSuccessRunRecordPersistenceFailureDoesNotCreateFailedAutomationRun() async throws {
        let environment = try makeEnvironment(
            recordRun: { _, _, _, _, _, _, _, _ in
                throw InjectedFailure.recordRun
            }
        )
        defer { environment.sourceRoot.cleanup() }
        defer { environment.destinationRoot.cleanup() }

        let record = try insertMetadataRecord(
            in: environment.context,
            service: environment.metadataService,
            path: environment.file.path,
            displayName: environment.file.name,
            timestamp: environment.timestamp
        )
        record.projectAssociation = "Alpha"
        try environment.context.save()

        let detail = makeProjectSpaceDetail(
            projectLabel: "Alpha",
            fileRows: [
                ProjectSpaceFileRow(
                    canonicalIdentity: record.canonicalIdentity,
                    path: environment.file.path,
                    displayName: environment.file.name,
                    projectAssociation: "Alpha",
                    sourceFolderHint: "Alpha"
                )
            ],
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 3,
                    lastUsedAt: environment.timestamp.addingTimeInterval(-60)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: record.canonicalIdentity,
                    fileDisplayName: environment.file.name,
                    eventKind: .organized,
                    timestamp: environment.timestamp.addingTimeInterval(-60),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                )
            ]
        )

        do {
            _ = try await environment.coordinator.executePolicy(
                environment.policy,
                detail: detail,
                files: [environment.file],
                triggerKind: .manual,
                now: environment.timestamp
            )
            XCTFail("Expected bookkeeping failure after successful workflow run")
        } catch {
        }

        XCTAssertEqual(environment.workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.projectDrop])
        XCTAssertEqual(try environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).count, 1)
        XCTAssertEqual(try environment.context.fetch(FetchDescriptor<ProjectSpaceAutomationRunRecord>()).count, 0)
    }

    private func makeEnvironment(
        admissionWriter: (any ProjectSpaceAutomationAdmissionWriting)? = nil,
        persistLatestRun: (@Sendable (WorkflowRunRecord, String, Date) throws -> Void)? = nil,
        recordRun: (@Sendable (UUID, String, ProjectSpaceAutomationTriggerKind, UUID?, ProjectSpaceAutomationRunStatus, Date, Date?, Date) throws -> ProjectSpaceAutomationRunRecord)? = nil
    ) throws -> (
        container: ModelContainer,
        context: ModelContext,
        metadataService: FileMetadataFoundationService,
        automationService: ProjectSpaceAutomationService,
        workflowExecution: WorkflowExecutionSpy,
        coordinator: ProjectSpaceAutomationCoordinator,
        policy: ProjectSpaceAutomationPolicy,
        file: FileItem,
        sourceRoot: TemporaryDirectory,
        destinationRoot: TemporaryDirectory,
        timestamp: Date
    ) {
        let schema = Schema([
            FileItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            ProjectSpaceWorkflowProfile.self,
            ProjectSpaceAutomationProfile.self,
            ProjectSpaceAutomationPolicy.self,
            ProjectSpaceAutomationRunRecord.self,
            WorkflowRunRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let metadataService = FileMetadataFoundationService(modelContext: context)
        let automationService = ProjectSpaceAutomationService(modelContext: context)
        let workflowExecution = WorkflowExecutionSpy()
        let timestamp = Date(timeIntervalSince1970: 5_000)
        let policy = try automationService.createOrUpdatePolicy(
            normalizedProjectLabel: "Alpha",
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            triggerKinds: [.manual],
            admissionMode: .automatic,
            state: .active,
            updatedAt: timestamp
        )

        let sourceRoot = try TemporaryDirectory(cleanupOnDeinit: false)
        let destinationRoot = try TemporaryDirectory(cleanupOnDeinit: false)
        let sourceURL = try sourceRoot.createFile(name: "Alpha/spec.md", contents: "spec")
        let destinationURL = try destinationRoot.createDirectory(name: "Alpha")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 32,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: "Alpha",
            destination: try Destination.folder(from: destinationURL, displayName: "Alpha"),
            status: .ready
        )
        context.insert(file)
        try context.save()

        let coordinator = ProjectSpaceAutomationCoordinator(
            modelContext: context,
            metadataAdmissionWriter: admissionWriter ?? metadataService,
            automationService: automationService,
            workflowExecution: workflowExecution.client,
            persistLatestRun: persistLatestRun,
            recordRun: recordRun
        )

        return (
            container,
            context,
            metadataService,
            automationService,
            workflowExecution,
            coordinator,
            policy,
            file,
            sourceRoot,
            destinationRoot,
            timestamp
        )
    }

    private func insertMetadataRecord(
        in context: ModelContext,
        service: FileMetadataFoundationService,
        path: String,
        displayName: String,
        timestamp: Date
    ) throws -> FileMetadataRecord {
        let record = try XCTUnwrap(
            service.upsertRecord(
                for: path,
                displayName: displayName,
                fileExtension: URL(fileURLWithPath: path).pathExtension,
                timestamp: timestamp
            )
        )
        try context.save()
        return record
    }

    private func makeFileItem(
        path: String,
        rootPath: String,
        relativeParentPath: String,
        timestamp: Date,
        destination: Destination? = nil
    ) -> FileItem {
        FileItem(
            path: path,
            sizeInBytes: 32,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: rootPath,
            relativeParentPath: relativeParentPath,
            destination: destination,
            status: .ready
        )
    }

    private func makeProjectSpaceDetail(
        projectLabel: String,
        fileRows: [ProjectSpaceFileRow],
        preferredDestinations: [ProjectSpacePreferredDestination],
        recentActivity: [ProjectSpaceRecentActivityRow]
    ) -> ProjectSpaceDetail {
        ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                normalizedLabel: projectLabel,
                fileCount: fileRows.count,
                lastActivityAt: recentActivity.map(\.timestamp).max() ?? .distantPast,
                sourceFolderHints: Array(Set(fileRows.compactMap(\.sourceFolderHint))).sorted()
            ),
            files: fileRows,
            overview: ProjectSpaceOverview(
                currentFileCount: fileRows.count,
                activeFolderCount: Array(Set(fileRows.compactMap(\.sourceFolderHint))).count,
                activeFolderHints: Array(Set(fileRows.compactMap(\.sourceFolderHint))).sorted(),
                preferredDestinationCount: preferredDestinations.count,
                recentActivityCount: recentActivity.count,
                lastActivityAt: recentActivity.map(\.timestamp).max()
            ),
            preferredDestinations: preferredDestinations,
            recentActivity: recentActivity
        )
    }
}
