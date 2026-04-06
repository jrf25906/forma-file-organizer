import XCTest
@testable import Forma_File_Organizing

final class MetadataContentTagResolverTests: XCTestCase {
    private let resolver = MetadataContentTagResolver()

    func testExplicitAlias_ScreenshotsMapsToScreenshotTag() {
        XCTAssertEqual(resolver.resolveExplicitTag(forAlias: "Screenshots"), .screenshot)
        XCTAssertEqual(resolver.resolveExplicitTag(forAlias: "Invoices"), .invoice)
        XCTAssertEqual(resolver.resolveExplicitTag(forAlias: "Slides"), .presentation)
    }

    func testInference_UsesOnlyObviousFilenameAndExtensionSignals() {
        let screenshotTags = resolver.inferTags(
            fileName: "Screenshot 2024-04-01.png",
            fileExtension: "png",
            fileCategory: .images
        )
        XCTAssertEqual(screenshotTags, [.screenshot])

        let invoiceTags = resolver.inferTags(
            fileName: "invoice_042024.pdf",
            fileExtension: "pdf",
            fileCategory: .documents
        )
        XCTAssertEqual(invoiceTags, [.invoice])

        let presentationTags = resolver.inferTags(
            fileName: "Quarterly Slides.key",
            fileExtension: "key",
            fileCategory: .documents
        )
        XCTAssertEqual(presentationTags, [.presentation])

        let agreementTags = resolver.inferTags(
            fileName: "Services Agreement.pdf",
            fileExtension: "pdf",
            fileCategory: .documents
        )
        XCTAssertEqual(agreementTags, [.contract])

        let ndaTags = resolver.inferTags(
            fileName: "Mutual NDA.pdf",
            fileExtension: "pdf",
            fileCategory: .documents
        )
        XCTAssertEqual(ndaTags, [.contract])

        let ambiguousTags = resolver.inferTags(
            fileName: "IMG_1042.png",
            fileExtension: "png",
            fileCategory: .images
        )
        XCTAssertTrue(ambiguousTags.isEmpty)
    }

    func testResolveNewTags_UnionWithCapPrefersExplicitCandidates() {
        let tags = resolver.resolveNewTags(
            existingRawValues: [],
            explicitCandidates: [.invoice, .screenshot],
            inferredCandidates: [.receipt, .statement]
        )

        XCTAssertEqual(tags, [.invoice, .screenshot, .receipt])
    }

    func testResolveNewTags_DoesNotReturnDuplicateBuiltInTags() {
        let tags = resolver.resolveNewTags(
            existingRawValues: [MetadataContentTag.invoice.rawValue],
            explicitCandidates: [.invoice, .receipt, .invoice],
            inferredCandidates: [.receipt, .presentation, .presentation]
        )

        XCTAssertEqual(tags, [.invoice, .receipt, .presentation])
        XCTAssertEqual(Set(tags.map(\.rawValue)).count, tags.count)
    }
}
