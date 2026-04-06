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
        let extensionLowercased = fileExtension.lowercased()
        var tags: [MetadataContentTag] = []

        if fileCategory == .images,
           normalizedFileName.contains("screenshot") || normalizedFileName.contains("screen shot") {
            appendIfNeeded(.screenshot, to: &tags)
        }

        if fileCategory == .documents {
            if normalizedFileName.contains("invoice") { appendIfNeeded(.invoice, to: &tags) }
            if normalizedFileName.contains("receipt") { appendIfNeeded(.receipt, to: &tags) }
            if Self.contractFilenameTokens.contains(where: normalizedFileName.contains) {
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
        var resolved = normalize(existingRawValues)
        var seen = Set(resolved.map(\.rawValue))
        var newCandidates: [MetadataContentTag] = []

        for candidate in explicitCandidates + inferredCandidates {
            guard newCandidates.count < 3 else { break }
            guard seen.insert(candidate.rawValue).inserted else { continue }
            newCandidates.append(candidate)
        }

        resolved.append(contentsOf: newCandidates)
        return resolved
    }

    private func normalize(_ rawValues: [String]) -> [MetadataContentTag] {
        var tags: [MetadataContentTag] = []
        var seen = Set<String>()

        for rawValue in rawValues {
            guard let tag = MetadataContentTag(rawValue: rawValue),
                  seen.insert(tag.rawValue).inserted else {
                continue
            }
            tags.append(tag)
        }

        return tags
    }

    private func normalized(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func appendIfNeeded(_ tag: MetadataContentTag, to tags: inout [MetadataContentTag]) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
    }
}
