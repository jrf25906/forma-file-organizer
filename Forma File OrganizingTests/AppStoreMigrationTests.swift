import XCTest
import SwiftData
@testable import Forma_File_Organizing

private enum PreMetadataAppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Rule.self,
            RuleCategory.self,
            FileItem.self,
            LearnedPattern.self,
            ProjectCluster.self,
            StorageSnapshot.self,
            ActivityItem.self,
            MLTrainingHistory.self
        ]
    }

    @Model
    final class FileItem {
        @Attribute(.unique) private(set) var path: String
        private var locationRaw: String?
        var scanRootPath: String?
        var relativeParentPath: String?
        private(set) var name: String
        private(set) var fileExtension: String
        private(set) var sizeInBytes: Int64
        private(set) var creationDate: Date
        private(set) var modificationDate: Date
        private(set) var lastAccessedDate: Date
        private var _destinationIsTrash: Bool = false
        private var _destinationBookmarkData: Data?
        private var _destinationDisplayName: String?
        private(set) var statusRaw: String
        var matchReason: String?
        var confidenceScore: Double?
        var rejectedDestination: String?
        var rejectionCount: Int
        var lastOrganizeError: String?
        var suggestionSourceRaw: String?
        var matchedRuleID: UUID?

        init(
            path: String,
            locationRaw: String?,
            scanRootPath: String?,
            relativeParentPath: String?,
            name: String,
            fileExtension: String,
            sizeInBytes: Int64,
            creationDate: Date,
            modificationDate: Date,
            lastAccessedDate: Date,
            destinationBookmarkData: Data?,
            destinationDisplayName: String?,
            statusRaw: String,
            matchReason: String?,
            confidenceScore: Double?,
            rejectedDestination: String?,
            rejectionCount: Int,
            lastOrganizeError: String?,
            suggestionSourceRaw: String?,
            matchedRuleID: UUID?
        ) {
            self.path = path
            self.locationRaw = locationRaw
            self.scanRootPath = scanRootPath
            self.relativeParentPath = relativeParentPath
            self.name = name
            self.fileExtension = fileExtension
            self.sizeInBytes = sizeInBytes
            self.creationDate = creationDate
            self.modificationDate = modificationDate
            self.lastAccessedDate = lastAccessedDate
            self._destinationBookmarkData = destinationBookmarkData
            self._destinationDisplayName = destinationDisplayName
            self.statusRaw = statusRaw
            self.matchReason = matchReason
            self.confidenceScore = confidenceScore
            self.rejectedDestination = rejectedDestination
            self.rejectionCount = rejectionCount
            self.lastOrganizeError = lastOrganizeError
            self.suggestionSourceRaw = suggestionSourceRaw
            self.matchedRuleID = matchedRuleID
        }
    }

    @Model
    final class LearnedPattern {
        var id: UUID
        var patternDescription: String
        var fileExtension: String
        var destinationPath: String
        var destinationBookmarkData: Data?
        private var destinationData: Data?
        var occurrenceCount: Int
        var confidenceScore: Double
        var lastSeenDate: Date
        var rejectionCount: Int
        var convertedToRule: Bool
        var convertedRuleId: UUID?
        var conditions: [PatternCondition]
        private var logicalOperatorRaw: String
        var isNegativePattern: Bool
        var suppressedRuleIds: [UUID]
        var extractedKeywords: [String]
        var temporalContexts: [TemporalContext]
        private var timeCategoryRaw: String

        init(
            id: UUID = UUID(),
            patternDescription: String,
            fileExtension: String,
            destinationPath: String,
            destinationBookmarkData: Data?,
            destinationData: Data?,
            occurrenceCount: Int,
            confidenceScore: Double,
            lastSeenDate: Date,
            rejectionCount: Int,
            convertedToRule: Bool,
            convertedRuleId: UUID?,
            conditions: [PatternCondition],
            logicalOperatorRaw: String,
            isNegativePattern: Bool,
            suppressedRuleIds: [UUID],
            extractedKeywords: [String],
            temporalContexts: [TemporalContext],
            timeCategoryRaw: String
        ) {
            self.id = id
            self.patternDescription = patternDescription
            self.fileExtension = fileExtension
            self.destinationPath = destinationPath
            self.destinationBookmarkData = destinationBookmarkData
            self.destinationData = destinationData
            self.occurrenceCount = occurrenceCount
            self.confidenceScore = confidenceScore
            self.lastSeenDate = lastSeenDate
            self.rejectionCount = rejectionCount
            self.convertedToRule = convertedToRule
            self.convertedRuleId = convertedRuleId
            self.conditions = conditions
            self.logicalOperatorRaw = logicalOperatorRaw
            self.isNegativePattern = isNegativePattern
            self.suppressedRuleIds = suppressedRuleIds
            self.extractedKeywords = extractedKeywords
            self.temporalContexts = temporalContexts
            self.timeCategoryRaw = timeCategoryRaw
        }
    }

    @Model
    final class ProjectCluster {
        var id: UUID
        private var clusterTypeRaw: String
        var filePaths: [String]
        var confidenceScore: Double
        var suggestedFolderName: String
        var detectedPattern: String?
        var detectedDate: Date
        var isDismissed: Bool
        var isOrganized: Bool

        init(
            id: UUID = UUID(),
            clusterTypeRaw: String,
            filePaths: [String],
            confidenceScore: Double,
            suggestedFolderName: String,
            detectedPattern: String?,
            detectedDate: Date,
            isDismissed: Bool,
            isOrganized: Bool
        ) {
            self.id = id
            self.clusterTypeRaw = clusterTypeRaw
            self.filePaths = filePaths
            self.confidenceScore = confidenceScore
            self.suggestedFolderName = suggestedFolderName
            self.detectedPattern = detectedPattern
            self.detectedDate = detectedDate
            self.isDismissed = isDismissed
            self.isOrganized = isOrganized
        }
    }
}

final class AppStoreMigrationTests: XCTestCase {
    @MainActor
    func testAppSchemaOpensPreMetadataStoreAndPreservesLegacyRows() throws {
        let tempDir = try TemporaryDirectory(cleanupOnDeinit: false)
        // Intentionally preserve the backing store for this regression test.
        // SwiftData/SQLite teardown is not synchronous here, and deleting the directory
        // during test cleanup races live file handles and pollutes later test logs.
        let storeURL = tempDir.url.appendingPathComponent("pre-metadata.store")

        let downloadsRoot = tempDir.url.appendingPathComponent("Downloads", isDirectory: true)
        let invoicesRoot = tempDir.url.appendingPathComponent("Invoices", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: invoicesRoot, withIntermediateDirectories: true)

        let bookmarkData = try invoicesRoot.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let filePath = downloadsRoot.appendingPathComponent("invoice.pdf").path

        autoreleasepool {
            do {
                let legacySchema = Schema(versionedSchema: PreMetadataAppSchemaV1.self)
                let legacyConfiguration = ModelConfiguration(
                    schema: legacySchema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
                let legacyContainer = try ModelContainer(for: legacySchema, configurations: [legacyConfiguration])
                let legacyContext = ModelContext(legacyContainer)

                legacyContext.insert(
                    PreMetadataAppSchemaV1.FileItem(
                        path: filePath,
                        locationRaw: FileLocationKind.downloads.rawValue,
                        scanRootPath: downloadsRoot.path,
                        relativeParentPath: nil,
                        name: "invoice.pdf",
                        fileExtension: "pdf",
                        sizeInBytes: 2_048,
                        creationDate: Date(timeIntervalSince1970: 1_700_000_000),
                        modificationDate: Date(timeIntervalSince1970: 1_700_000_100),
                        lastAccessedDate: Date(timeIntervalSince1970: 1_700_000_200),
                        destinationBookmarkData: bookmarkData,
                        destinationDisplayName: "Invoices",
                        statusRaw: FileItem.OrganizationStatus.pending.rawValue,
                        matchReason: "Legacy test fixture",
                        confidenceScore: 0.82,
                        rejectedDestination: nil,
                        rejectionCount: 0,
                        lastOrganizeError: nil,
                        suggestionSourceRaw: SuggestionSource.rule.rawValue,
                        matchedRuleID: nil
                    )
                )

                legacyContext.insert(
                    PreMetadataAppSchemaV1.LearnedPattern(
                        patternDescription: "PDF files -> Invoices",
                        fileExtension: "pdf",
                        destinationPath: "Invoices",
                        destinationBookmarkData: bookmarkData,
                        destinationData: nil,
                        occurrenceCount: 4,
                        confidenceScore: 0.75,
                        lastSeenDate: Date(timeIntervalSince1970: 1_700_000_300),
                        rejectionCount: 0,
                        convertedToRule: false,
                        convertedRuleId: nil,
                        conditions: [.fileExtension("pdf")],
                        logicalOperatorRaw: Rule.LogicalOperator.single.rawValue,
                        isNegativePattern: false,
                        suppressedRuleIds: [],
                        extractedKeywords: [],
                        temporalContexts: [],
                        timeCategoryRaw: LearnedPattern.TimeCategory.anyTime.rawValue
                    )
                )

                legacyContext.insert(
                    PreMetadataAppSchemaV1.ProjectCluster(
                        clusterTypeRaw: ProjectCluster.ClusterType.projectCode.rawValue,
                        filePaths: [filePath],
                        confidenceScore: 0.91,
                        suggestedFolderName: "Client A",
                        detectedPattern: "CLIENT_A",
                        detectedDate: Date(timeIntervalSince1970: 1_700_000_400),
                        isDismissed: false,
                        isOrganized: false
                    )
                )

                try legacyContext.save()
            } catch {
                XCTFail("Failed to create legacy store fixture: \(error)")
                return
            }

            do {
                let currentConfiguration = ModelConfiguration(
                    schema: Forma_File_OrganizingApp.appSchema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
                let currentContainer = try ModelContainer(
                    for: Forma_File_OrganizingApp.appSchema,
                    configurations: [currentConfiguration]
                )

                let currentContext = ModelContext(currentContainer)

                let migratedFile = try XCTUnwrap(try currentContext.fetch(FetchDescriptor<Forma_File_Organizing.FileItem>()).first)
                XCTAssertEqual(migratedFile.path, filePath)
                XCTAssertEqual(migratedFile.scanRootPath, downloadsRoot.path)
                XCTAssertEqual(migratedFile.suggestionSource, .rule)
                XCTAssertNil(migratedFile.originalSuggestedDestination)

                let migratedPattern = try XCTUnwrap(try currentContext.fetch(FetchDescriptor<Forma_File_Organizing.LearnedPattern>()).first)
                XCTAssertEqual(migratedPattern.fileExtension, "pdf")
                XCTAssertEqual(migratedPattern.source, .activityHistory)

                let migratedCluster = try XCTUnwrap(try currentContext.fetch(FetchDescriptor<Forma_File_Organizing.ProjectCluster>()).first)
                XCTAssertEqual(migratedCluster.filePaths, [filePath])
                XCTAssertTrue(migratedCluster.containsStoredFilePath(filePath))
                _ = migratedCluster.rebuildFilePathsSearchBlobIfNeeded()
                XCTAssertFalse(migratedCluster.filePathsSearchBlob.isEmpty)
            } catch {
                XCTFail("Failed to open migrated app store: \(error)")
            }
        }

    }
}
