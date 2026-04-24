import Foundation

enum TrustedAutomationScopeBoundaryDescriptor: Codable, Equatable, Hashable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case rule
        case source
        case destination
        case fileTypeCategoryRaw
    }

    private enum Kind: String, Codable {
        case rule
        case folder
        case category
    }

    struct SourceBoundary: Codable, Equatable, Hashable, Sendable {
        let sourceLocation: FileLocationKind
        let scanRootPath: String?
        let relativeParentPath: String?

        init(
            sourceLocation: FileLocationKind,
            scanRootPath: String?,
            relativeParentPath: String?
        ) {
            self.sourceLocation = sourceLocation
            self.scanRootPath = Self.normalizedPath(scanRootPath)
            self.relativeParentPath = Self.normalizedRelativeParentPath(relativeParentPath)
        }

        var isAmbiguousSubtreeWithoutRootIdentity: Bool {
            scanRootPath == nil && relativeParentPath != nil
        }

        var specificityScore: Int {
            let rootScore: Int
            if scanRootPath != nil {
                rootScore = 10_000
            } else if sourceLocation != .unknown {
                rootScore = 1_000
            } else {
                rootScore = 0
            }

            let relativeDepth = relativeParentPath?
                .split(separator: "/")
                .count ?? 0

            return rootScore + relativeDepth
        }

        var identityKey: String {
            let rootIdentity = scanRootPath ?? "location:\(sourceLocation.rawValue)"
            let relativeIdentity = relativeParentPath ?? "<root>"
            return "\(rootIdentity)|\(relativeIdentity)"
        }

        var displayName: String {
            if let relativeParentPath {
                return relativeParentPath.split(separator: "/").last.map(String.init) ?? sourceLocation.displayName
            }

            if let scanRootPath, !scanRootPath.isEmpty {
                return URL(fileURLWithPath: scanRootPath).lastPathComponent
            }

            return sourceLocation.displayName
        }

        func matches(file: FileItem) -> Bool {
            guard !isAmbiguousSubtreeWithoutRootIdentity else {
                return false
            }

            if let scanRootPath {
                guard Self.normalizedPath(file.scanRootPath) == scanRootPath else {
                    return false
                }
            } else if sourceLocation != .unknown {
                guard file.location == sourceLocation else {
                    return false
                }
            }

            guard Self.relativePath(file.relativeParentPath, isWithin: relativeParentPath) else {
                return false
            }

            if let scanRootPath {
                guard Self.resolvedFilePath(file.path, isWithinScanRoot: scanRootPath, relativeScope: relativeParentPath) else {
                    Log.error(
                        "SECURITY: Trusted automation source boundary rejected symlink escape. File: \(file.path), Scan root: \(scanRootPath), Relative scope: \(relativeParentPath ?? "<root>")",
                        category: .security
                    )
                    return false
                }
            }

            return true
        }

        private static func normalizedPath(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return URL(fileURLWithPath: value).standardizedFileURL.path
        }

        private static func normalizedRelativeParentPath(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }

            let components = value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: { $0 == "/" || $0 == "\\" })
                .map(String.init)
                .filter { !$0.isEmpty && $0 != "." }

            guard !components.isEmpty else { return nil }
            return components.joined(separator: "/")
        }

        private static func relativePath(_ candidate: String?, isWithin scope: String?) -> Bool {
            guard let scope = normalizedRelativeParentPath(scope) else {
                return true
            }

            guard let candidate = normalizedRelativeParentPath(candidate) else {
                return false
            }

            return candidate == scope || candidate.hasPrefix("\(scope)/")
        }

        private static func resolvedFilePath(
            _ filePath: String,
            isWithinScanRoot scanRootPath: String,
            relativeScope: String?
        ) -> Bool {
            guard
                let resolvedScanRootPath = resolvedPath(scanRootPath),
                let scopeRoot = scopeRootPath(scanRootPath: scanRootPath, relativeScope: relativeScope),
                let resolvedFilePath = resolvedPath(filePath)
            else {
                return false
            }

            return isPath(scopeRoot, inside: resolvedScanRootPath)
                && isPath(resolvedFilePath, inside: scopeRoot)
        }

        private static func scopeRootPath(scanRootPath: String, relativeScope: String?) -> String? {
            guard let relativeScope = normalizedRelativeParentPath(relativeScope) else {
                return resolvedPath(scanRootPath)
            }

            let scopeURL = URL(fileURLWithPath: scanRootPath)
                .appendingPathComponent(relativeScope)

            return resolvedPath(scopeURL.path)
        }

        private static func resolvedPath(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return URL(fileURLWithPath: value)
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path
        }

        private static func isPath(_ path: String, inside rootPath: String) -> Bool {
            let rootWithSeparator = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
            return path == rootPath || path.hasPrefix(rootWithSeparator)
        }
    }

    struct RuleBoundary: Codable, Equatable, Hashable, Sendable {
        let id: UUID
        let name: String
    }

    struct DestinationSnapshot: Codable, Equatable, Hashable, Sendable {
        enum Kind: String, Codable, Sendable {
            case trash
            case folder
        }

        let kind: Kind
        let displayName: String
        let bookmarkData: Data?
        let resolvedPath: String?

        init(_ destination: Destination) {
            switch destination {
            case .trash:
                self.kind = .trash
                self.displayName = destination.displayName
                self.bookmarkData = nil
                self.resolvedPath = nil
            case .folder(let bookmarkData, let displayName):
                self.kind = .folder
                self.displayName = displayName
                self.bookmarkData = bookmarkData
                self.resolvedPath = destination.resolve()?.url.standardizedFileURL.path
            }
        }

        var identityKey: String {
            switch kind {
            case .trash:
                return "trash"
            case .folder:
                if let resolvedPath {
                    return "folder:\(resolvedPath)"
                }

                if let bookmarkData {
                    return "folder-bookmark:\(Self.fnv1a64(bookmarkData))"
                }

                return "folder-name:\(displayName)"
            }
        }

        func matches(_ destination: Destination?) -> Bool {
            guard let destination else {
                return false
            }

            switch (kind, destination) {
            case (.trash, .trash):
                return true
            case (.folder, .trash), (.trash, .folder):
                return false
            case (.folder, .folder(let bookmarkData, _)):
                if self.bookmarkData == bookmarkData {
                    return true
                }

                guard let resolvedPath else {
                    return false
                }

                return destination.resolve()?.url.standardizedFileURL.path == resolvedPath
            }
        }

        private static func fnv1a64(_ data: Data) -> String {
            var hash: UInt64 = 14_695_981_039_346_656_037
            for byte in data {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
            return String(hash, radix: 16)
        }
    }

    case rule(rule: RuleBoundary, source: SourceBoundary, destination: DestinationSnapshot)
    case folder(source: SourceBoundary, destination: DestinationSnapshot)
    case category(fileTypeCategory: FileTypeCategory, source: SourceBoundary, destination: DestinationSnapshot)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .rule:
            self = .rule(
                rule: try container.decode(RuleBoundary.self, forKey: .rule),
                source: try container.decode(SourceBoundary.self, forKey: .source),
                destination: try container.decode(DestinationSnapshot.self, forKey: .destination)
            )
        case .folder:
            self = .folder(
                source: try container.decode(SourceBoundary.self, forKey: .source),
                destination: try container.decode(DestinationSnapshot.self, forKey: .destination)
            )
        case .category:
            let rawValue = try container.decode(String.self, forKey: .fileTypeCategoryRaw)
            let fileTypeCategory = FileTypeCategory(rawValue: rawValue) ?? .documents
            self = .category(
                fileTypeCategory: fileTypeCategory,
                source: try container.decode(SourceBoundary.self, forKey: .source),
                destination: try container.decode(DestinationSnapshot.self, forKey: .destination)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .rule(let rule, let source, let destination):
            try container.encode(Kind.rule, forKey: .kind)
            try container.encode(rule, forKey: .rule)
            try container.encode(source, forKey: .source)
            try container.encode(destination, forKey: .destination)
        case .folder(let source, let destination):
            try container.encode(Kind.folder, forKey: .kind)
            try container.encode(source, forKey: .source)
            try container.encode(destination, forKey: .destination)
        case .category(let fileTypeCategory, let source, let destination):
            try container.encode(Kind.category, forKey: .kind)
            try container.encode(fileTypeCategory.rawValue, forKey: .fileTypeCategoryRaw)
            try container.encode(source, forKey: .source)
            try container.encode(destination, forKey: .destination)
        }
    }

    var scopeType: TrustedAutomationScopeType {
        switch self {
        case .rule:
            return .rule
        case .folder:
            return .folder
        case .category:
            return .category
        }
    }

    var sourceBoundary: SourceBoundary {
        switch self {
        case .rule(_, let source, _), .folder(let source, _), .category(_, let source, _):
            return source
        }
    }

    var destinationSnapshot: DestinationSnapshot {
        switch self {
        case .rule(_, _, let destination), .folder(_, let destination), .category(_, _, let destination):
            return destination
        }
    }

    var identityScopeKey: String {
        switch self {
        case .rule(let rule, _, _):
            return "rule:\(rule.id.uuidString)"
        case .folder(let source, _):
            return source.identityKey
        case .category(let fileTypeCategory, let source, let destination):
            return "\(fileTypeCategory.rawValue)|\(source.identityKey)|\(destination.identityKey)"
        }
    }

    var matchingSpecificityScore: Int {
        switch self {
        case .rule(_, let source, _):
            return 100_000 + source.specificityScore
        case .folder(let source, _):
            return source.specificityScore
        case .category(_, let source, _):
            return source.specificityScore
        }
    }

    var boundarySummary: String {
        switch self {
        case .rule(let rule, _, let destination):
            return "\(rule.name) -> \(destination.displayName)"
        case .folder(let source, let destination):
            return "\(source.displayName) -> \(destination.displayName)"
        case .category(let fileTypeCategory, _, let destination):
            return "\(fileTypeCategory.displayName) -> \(destination.displayName)"
        }
    }

    func matches(candidate file: FileItem, destination: Destination?) -> Bool {
        guard destinationSnapshot.matches(destination) else {
            return false
        }

        switch self {
        case .rule(let rule, let source, _):
            return source.matches(file: file) && file.matchedRuleID == rule.id
        case .folder(let source, _):
            return source.matches(file: file)
        case .category(let fileTypeCategory, let source, _):
            return source.matches(file: file) && fileTypeCategory.matches(fileExtension: file.fileExtension)
        }
    }
}
