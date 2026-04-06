import Foundation

struct MetadataContentTagResolver: Sendable {
    private static let aliasTable: [String: MetadataContentTag] = [
        "screenshot": .screenshot,
        "screenshots": .screenshot,
        "screen shot": .screenshot,
        "screen shots": .screenshot,
        "invoice": .invoice,
        "invoices": .invoice,
        "receipt": .receipt,
        "receipts": .receipt,
        "contract": .contract,
        "contracts": .contract,
        "statement": .statement,
        "statements": .statement,
        "bank statement": .statement,
        "bank statements": .statement,
        "presentation": .presentation,
        "presentations": .presentation,
        "slide": .presentation,
        "slides": .presentation,
        "slide deck": .presentation,
        "slide decks": .presentation,
        "deck": .presentation,
        "decks": .presentation
    ]

    private static let contractFilenameTokens: [String] = [
        "contract",
        "agreement",
        "nda"
    ]

    func resolveExplicitTag(forAlias alias: String) -> MetadataContentTag? {
        Self.aliasTable[normalized(alias)]
    }

    func inferTags(fileName: String, fileExtension: String, fileCategory: FileTypeCategory?) -> [MetadataContentTag] {
        let normalizedFileName = normalized(fileName)
        let filenameTokens = tokenized(normalizedFileName)
        let extensionLowercased = fileExtension.lowercased()
        var tags: [MetadataContentTag] = []

        if fileCategory == .images,
           normalizedFileName.contains("screenshot") || normalizedFileName.contains("screen shot") {
            appendIfNeeded(.screenshot, to: &tags)
        }

        if fileCategory == .documents {
            if normalizedFileName.contains("invoice") { appendIfNeeded(.invoice, to: &tags) }
            if normalizedFileName.contains("receipt") { appendIfNeeded(.receipt, to: &tags) }
            if Self.contractFilenameTokens.contains(where: filenameTokens.contains) {
                appendIfNeeded(.contract, to: &tags)
            }
            if normalizedFileName.contains("statement") { appendIfNeeded(.statement, to: &tags) }
        }

        if fileCategory == .documents,
           (normalizedFileName.contains("presentation") ||
            normalizedFileName.contains("slides") ||
            normalizedFileName.contains("slide deck") ||
            ["ppt", "pptx", "key", "keynote"].contains(extensionLowercased)) {
            appendIfNeeded(.presentation, to: &tags)
        }

        return tags
    }

    func resolveNewTags(
        existingRawValues: [String],
        explicitCandidates: [MetadataContentTag],
        inferredCandidates: [MetadataContentTag]
    ) -> [MetadataContentTag] {
        let storedRawValues = Set(existingRawValues.compactMap { rawValue in
            MetadataContentTag(rawValue: normalized(rawValue))?.rawValue
        })
        var newCandidates: [MetadataContentTag] = []
        var seen = Set<String>()

        for candidate in explicitCandidates + inferredCandidates {
            guard newCandidates.count < 3 else { break }
            guard !storedRawValues.contains(candidate.rawValue) else { continue }
            guard seen.insert(candidate.rawValue).inserted else { continue }
            newCandidates.append(candidate)
        }

        return newCandidates
    }

    private func normalized(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func tokenized(_ string: String) -> [String] {
        string
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func appendIfNeeded(_ tag: MetadataContentTag, to tags: inout [MetadataContentTag]) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
    }
}
