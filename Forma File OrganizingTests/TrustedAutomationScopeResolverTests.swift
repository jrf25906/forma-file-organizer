import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class TrustedAutomationScopeResolverTests: XCTestCase {

    private func makeServices() throws -> (ModelContainer, ModelContext, TrustedAutomationScopeService, TrustedAutomationScopeResolver) {
        let schema = Schema([TrustedAutomationScope.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (
            container,
            context,
            TrustedAutomationScopeService(modelContext: context),
            TrustedAutomationScopeResolver(modelContext: context)
        )
    }

    private func withServices(
        _ body: (_ context: ModelContext, _ service: TrustedAutomationScopeService, _ resolver: TrustedAutomationScopeResolver) throws -> Void
    ) throws {
        let (container, context, service, resolver) = try makeServices()
        try withExtendedLifetime(container) {
            try body(context, service, resolver)
        }
    }

    func testResolveMatch_RequiresActiveScopeAndDestinationAlignment() throws {
        let trustedDestinationRoot = try TemporaryDirectory()
        let otherDestinationRoot = try TemporaryDirectory()
        let trustedDestination = try Destination.folder(from: try trustedDestinationRoot.createDirectory(name: "Images"))
        let otherDestination = try Destination.folder(from: try otherDestinationRoot.createDirectory(name: "Images"))

        try withServices { _, service, resolver in
            let scope = try service.createOrReactivateScope(
                scopeType: .category,
                scopeKey: FileTypeCategory.images.rawValue,
                displayName: FileTypeCategory.images.displayName,
                boundaryDescriptor: .category(
                    fileTypeCategory: .images,
                    source: .init(
                        sourceLocation: .unknown,
                        scanRootPath: nil,
                        relativeParentPath: nil
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Images are trusted for automatic organization.",
                allowedActions: [.move]
            )
            let candidate = makeCandidateFile(
                path: "/Users/example/Downloads/Screen Shot.png",
                fileExtension: "png",
                sourceLocation: .downloads
            )

            XCTAssertNil(try resolver.resolveMatch(for: candidate, destination: otherDestination))
            XCTAssertEqual(try resolver.resolveMatch(for: candidate, destination: trustedDestination)?.id, scope.id)

            try service.pauseScope(id: scope.id)
            XCTAssertNil(try resolver.resolveMatch(for: candidate, destination: trustedDestination))

            try service.resumeScope(id: scope.id)
            try service.removeScope(id: scope.id)
            XCTAssertNil(try resolver.resolveMatch(for: candidate, destination: trustedDestination))
        }
    }

    func testResolveMatch_PrefersRuleOverFolderOverCategory() throws {
        let destinationRoot = try TemporaryDirectory()
        let trustedDestination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Receipts"))
        let ruleID = UUID()

        try withServices { _, service, resolver in
            let ruleScope = try service.createOrReactivateScope(
                scopeType: .rule,
                scopeKey: "rule:\(ruleID.uuidString)",
                displayName: "Receipt Rule",
                boundaryDescriptor: .rule(
                    rule: .init(id: ruleID, name: "Receipt Rule"),
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Projects/Receipts"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .explicitRule,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.95,
                rationaleSummary: "Explicit receipt rule is trusted.",
                allowedActions: [.move]
            )
            let folderScope = try service.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Projects/Receipts",
                displayName: "Receipts",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Projects/Receipts"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Receipts subtree is trusted.",
                allowedActions: [.move]
            )
            let categoryScope = try service.createOrReactivateScope(
                scopeType: .category,
                scopeKey: FileTypeCategory.documents.rawValue,
                displayName: FileTypeCategory.documents.displayName,
                boundaryDescriptor: .category(
                    fileTypeCategory: .documents,
                    source: .init(
                        sourceLocation: .unknown,
                        scanRootPath: nil,
                        relativeParentPath: nil
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.89,
                rationaleSummary: "Documents are trusted.",
                allowedActions: [.move]
            )
            let candidate = makeCandidateFile(
                path: "/Users/example/Downloads/Projects/Receipts/2026/Receipt.pdf",
                fileExtension: "pdf",
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Projects/Receipts/2026",
                matchedRuleID: ruleID
            )

            XCTAssertEqual(try resolver.resolveMatch(for: candidate, destination: trustedDestination)?.id, ruleScope.id)

            try service.pauseScope(id: ruleScope.id)
            XCTAssertEqual(try resolver.resolveMatch(for: candidate, destination: trustedDestination)?.id, folderScope.id)

            try service.pauseScope(id: folderScope.id)
            XCTAssertEqual(try resolver.resolveMatch(for: candidate, destination: trustedDestination)?.id, categoryScope.id)
        }
    }

    func testResolveMatch_PrefersNarrowerFolderWhenMultipleFoldersMatch() throws {
        let destinationRoot = try TemporaryDirectory()
        let trustedDestination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Receipts"))

        try withServices { _, service, resolver in
            let broaderScope = try service.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Projects",
                displayName: "Projects",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Projects"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Projects subtree is trusted.",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 100)
            )
            let narrowerScope = try service.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Projects/Receipts",
                displayName: "Receipts",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Projects/Receipts"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.95,
                rationaleSummary: "Receipt subtree is trusted.",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 200)
            )
            let candidate = makeCandidateFile(
                path: "/Users/example/Downloads/Projects/Receipts/2026/Receipt.pdf",
                fileExtension: "pdf",
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Projects/Receipts/2026"
            )

            XCTAssertEqual(try resolver.resolveMatch(for: candidate, destination: trustedDestination)?.id, narrowerScope.id)
            XCTAssertNotEqual(broaderScope.id, narrowerScope.id)
        }
    }

    func testResolveMatch_EnforcesPersistedSourceBoundaryForCategoryAndRule() throws {
        let destinationRoot = try TemporaryDirectory()
        let trustedDestination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Shared"))
        let ruleID = UUID()

        try withServices { _, service, resolver in
            let categoryScope = try service.createOrReactivateScope(
                scopeType: .category,
                scopeKey: FileTypeCategory.images.rawValue,
                displayName: FileTypeCategory.images.displayName,
                boundaryDescriptor: .category(
                    fileTypeCategory: .images,
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Screenshots"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Screenshots are trusted for automatic organization.",
                allowedActions: [.move]
            )
            let ruleScope = try service.createOrReactivateScope(
                scopeType: .rule,
                scopeKey: "rule:\(ruleID.uuidString)",
                displayName: "Receipt Rule",
                boundaryDescriptor: .rule(
                    rule: .init(id: ruleID, name: "Receipt Rule"),
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Receipts"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .explicitRule,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.95,
                rationaleSummary: "Receipt rule is trusted.",
                allowedActions: [.move]
            )

            let matchingCategoryCandidate = makeCandidateFile(
                path: "/Users/example/Downloads/Screenshots/Screen Shot.png",
                fileExtension: "png",
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Screenshots"
            )
            let mismatchedCategoryCandidate = makeCandidateFile(
                path: "/Users/example/Downloads/Misc/Screen Shot.png",
                fileExtension: "png",
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Misc"
            )
            let matchingRuleCandidate = makeCandidateFile(
                path: "/Users/example/Downloads/Receipts/Receipt.pdf",
                fileExtension: "pdf",
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                matchedRuleID: ruleID
            )
            let mismatchedRuleCandidate = makeCandidateFile(
                path: "/Users/example/Downloads/Other/Receipt.pdf",
                fileExtension: "pdf",
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Other",
                matchedRuleID: ruleID
            )

            XCTAssertEqual(try resolver.resolveMatch(for: matchingCategoryCandidate, destination: trustedDestination)?.id, categoryScope.id)
            XCTAssertNil(try resolver.resolveMatch(for: mismatchedCategoryCandidate, destination: trustedDestination))
            XCTAssertEqual(try resolver.resolveMatch(for: matchingRuleCandidate, destination: trustedDestination)?.id, ruleScope.id)
            XCTAssertNil(try resolver.resolveMatch(for: mismatchedRuleCandidate, destination: trustedDestination))
        }
    }

    func testResolveMatch_DoesNotTrustAmbiguousRootlessFolderBoundary() throws {
        let destinationRoot = try TemporaryDirectory()
        let trustedDestination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Exports"))

        try withServices { _, service, resolver in
            let scope = try service.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "location:downloads|Clients/Acme",
                displayName: "Acme",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: nil,
                        relativeParentPath: "Clients/Acme"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Acme subtree is trusted.",
                allowedActions: [.move]
            )
            let candidate = makeCandidateFile(
                path: "/Users/example/Downloads/Clients/Acme/Report.csv",
                fileExtension: "csv",
                sourceLocation: .downloads,
                scanRootPath: nil,
                relativeParentPath: "Clients/Acme"
            )

            XCTAssertNil(
                try resolver.resolveMatch(for: candidate, destination: trustedDestination),
                "Rootless nested folder scopes should stay inert rather than trust same-name folders interchangeably."
            )
            XCTAssertEqual(scope.scopeKey, "location:downloads|Clients/Acme")
        }
    }

    func testResolveMatch_RejectsSymlinkEscapeFromPersistedSourceBoundary() throws {
        let sourceRoot = try TemporaryDirectory()
        let outsideRoot = try TemporaryDirectory()
        let destinationRoot = try TemporaryDirectory()
        let trustedDestination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Exports"))

        let trustedSubtree = try sourceRoot.createDirectory(name: "Trusted")
        let outsideFile = try outsideRoot.createFile(name: "Escaped.pdf")
        let symlink = trustedSubtree.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outsideRoot.url)

        let candidatePath = symlink.appendingPathComponent(outsideFile.lastPathComponent).path

        try withServices { _, service, resolver in
            let scope = try service.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "\(sourceRoot.url.path)|Trusted",
                displayName: "Trusted",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .custom,
                        scanRootPath: sourceRoot.url.path,
                        relativeParentPath: "Trusted"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Trusted subtree should not include symlink escapes.",
                allowedActions: [.move]
            )
            let candidate = makeCandidateFile(
                path: candidatePath,
                fileExtension: "pdf",
                sourceLocation: .custom,
                scanRootPath: sourceRoot.url.path,
                relativeParentPath: "Trusted/escape"
            )

            XCTAssertNil(try resolver.resolveMatch(for: candidate, destination: trustedDestination))
            XCTAssertEqual(scope.displayName, "Trusted")
        }
    }

    func testResolveMatch_RejectsSymlinkedScopeRootEscapingScanRoot() throws {
        let sourceRoot = try TemporaryDirectory()
        let outsideRoot = try TemporaryDirectory()
        let destinationRoot = try TemporaryDirectory()
        let trustedDestination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Exports"))

        let outsideFile = try outsideRoot.createFile(name: "Escaped.pdf")
        let symlinkedScopeRoot = sourceRoot.url.appendingPathComponent("Trusted")
        try FileManager.default.createSymbolicLink(at: symlinkedScopeRoot, withDestinationURL: outsideRoot.url)

        let candidatePath = symlinkedScopeRoot.appendingPathComponent(outsideFile.lastPathComponent).path

        try withServices { _, service, resolver in
            let scope = try service.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "\(sourceRoot.url.path)|Trusted",
                displayName: "Trusted",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .custom,
                        scanRootPath: sourceRoot.url.path,
                        relativeParentPath: "Trusted"
                    ),
                    destination: .init(trustedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Trusted scope root should stay inside scan root.",
                allowedActions: [.move]
            )
            let candidate = makeCandidateFile(
                path: candidatePath,
                fileExtension: "pdf",
                sourceLocation: .custom,
                scanRootPath: sourceRoot.url.path,
                relativeParentPath: "Trusted"
            )

            XCTAssertNil(try resolver.resolveMatch(for: candidate, destination: trustedDestination))
            XCTAssertEqual(scope.displayName, "Trusted")
        }
    }

    func testSourceBoundaryMatch_PreservesDecodedLexicalSymlinkScanRootIdentity() throws {
        let sourceRoot = try TemporaryDirectory()
        let aliasParent = try TemporaryDirectory()
        let aliasRoot = aliasParent.url.appendingPathComponent("ScannedAlias")
        try FileManager.default.createSymbolicLink(at: aliasRoot, withDestinationURL: sourceRoot.url)
        _ = try sourceRoot.createFile(name: "Trusted/Receipt.pdf")

        let boundaryData = try JSONSerialization.data(withJSONObject: [
            "sourceLocation": "custom",
            "scanRootPath": aliasRoot.path,
            "relativeParentPath": "Trusted"
        ])
        let sourceBoundary = try JSONDecoder().decode(
            TrustedAutomationScopeBoundaryDescriptor.SourceBoundary.self,
            from: boundaryData
        )
        let candidate = makeCandidateFile(
            path: aliasRoot.appendingPathComponent("Trusted/Receipt.pdf").path,
            fileExtension: "pdf",
            sourceLocation: .custom,
            scanRootPath: aliasRoot.path,
            relativeParentPath: "Trusted"
        )

        XCTAssertTrue(sourceBoundary.matches(file: candidate))
        XCTAssertTrue(sourceBoundary.identityKey.hasPrefix(aliasRoot.standardizedFileURL.path))
        XCTAssertFalse(sourceBoundary.identityKey.hasPrefix(sourceRoot.url.resolvingSymlinksInPath().standardizedFileURL.path))
    }

    private func makeCandidateFile(
        path: String,
        fileExtension: String,
        sourceLocation: FileLocationKind,
        scanRootPath: String? = nil,
        relativeParentPath: String? = nil,
        matchedRuleID: UUID? = nil
    ) -> FileItem {
        let file = FileItem(
            path: path,
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 100),
            modificationDate: Date(timeIntervalSince1970: 200),
            lastAccessedDate: Date(timeIntervalSince1970: 300),
            location: sourceLocation,
            scanRootPath: scanRootPath,
            relativeParentPath: relativeParentPath
        )
        file.matchedRuleID = matchedRuleID
        file.suggestionSource = .rule
        XCTAssertEqual(file.fileExtension.lowercased(), fileExtension.lowercased())
        return file
    }
}
