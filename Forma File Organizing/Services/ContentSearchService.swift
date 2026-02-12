import Foundation

// MARK: - Security-Scoped Bookmark Access

/// Bookmark keys for monitored source folders
private let sourceFolderBookmarks: [String: String] = [
    "Desktop": "DesktopFolderBookmark",
    "Downloads": "DownloadsFolderBookmark",
    "Documents": "DocumentsFolderBookmark",
    "Pictures": "PicturesFolderBookmark",
    "Music": "MusicFolderBookmark"
]

/// Searches file contents with direct file reading for supported text formats.
///
/// Heavy scanning work runs off the main actor to keep typing and scrolling responsive.
@MainActor
protocol ContentSearchServing {
    func search(query: String, in files: [FileItem]) async -> [ContentSearchService.SearchResult]
}

final class ContentSearchService {

    // MARK: - Types

    /// Represents how a file matched the search query
    enum MatchType: Equatable, Hashable {
        case filename           // Matched in filename only
        case content            // Matched in file content only
        case both               // Matched in both filename and content
    }

    /// A search result with match details
    struct SearchResult: Identifiable {
        let id: String          // File path as unique ID
        let file: FileItem
        let matchType: MatchType
        let contentSnippet: String?
        let matchRanges: [Range<String.Index>]?

        init(file: FileItem, matchType: MatchType, contentSnippet: String? = nil, matchRanges: [Range<String.Index>]? = nil) {
            self.id = file.path
            self.file = file
            self.matchType = matchType
            self.contentSnippet = contentSnippet
            self.matchRanges = matchRanges
        }
    }

    /// Search state for UI feedback
    enum SearchState: Equatable {
        case idle
        case searching(progress: Double)  // 0.0 to 1.0
        case complete(resultCount: Int)
    }

    // MARK: - Singleton

    @MainActor static let shared = ContentSearchService()

    // MARK: - Configuration

    /// Maximum file size to scan content (10 MB default)
    var maxFileSizeForContentScan: Int64 = 10 * 1024 * 1024

    /// Snippet context length (characters before and after match)
    var snippetContextLength: Int = 40

    /// File extensions eligible for content search consideration
    private let searchableExtensions: Set<String> = [
        // Text files
        "txt", "md", "markdown", "rtf", "csv", "json", "xml", "yaml", "yml",
        // Code files
        "swift", "py", "js", "ts", "html", "css", "java", "c", "cpp", "h", "m",
        // Documents (filename-only today; reserved for future Spotlight integration)
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "keynote"
    ]

    /// Extensions that can be read as plain text directly
    private let plainTextExtensions: Set<String> = [
        "txt", "md", "markdown", "rtf", "csv", "json", "xml", "yaml", "yml",
        "swift", "py", "js", "ts", "html", "css", "java", "c", "cpp", "h", "m"
    ]

    private init() {}

    // MARK: - Public Interface

    /// Searches files for the given query, combining filename and content matches.
    ///
    /// - Parameters:
    ///   - query: The search string
    ///   - files: The files to search within
    /// - Returns: Array of search results with match type and snippets
    func search(query: String, in files: [FileItem]) async -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty, !files.isEmpty else {
            return []
        }

        let configuration = SearchConfiguration(
            maxFileSizeForContentScan: maxFileSizeForContentScan,
            snippetContextLength: snippetContextLength,
            searchableExtensions: searchableExtensions,
            plainTextExtensions: plainTextExtensions
        )

        let searchableFiles = files.map(SearchableFile.init)

        let hits = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let computedHits = Self.searchHits(
                    query: trimmedQuery,
                    files: searchableFiles,
                    configuration: configuration
                )
                continuation.resume(returning: computedHits)
            }
        }

        guard !Task.isCancelled, !hits.isEmpty else {
            return []
        }

        let filesByPath = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0) })

        return hits.compactMap { hit in
            guard let file = filesByPath[hit.path] else {
                return nil
            }

            let matchType: MatchType
            switch (hit.filenameMatched, hit.contentSnippet != nil) {
            case (true, true):
                matchType = .both
            case (true, false):
                matchType = .filename
            case (false, true):
                matchType = .content
            case (false, false):
                return nil
            }

            return SearchResult(
                file: file,
                matchType: matchType,
                contentSnippet: hit.contentSnippet,
                matchRanges: nil
            )
        }
    }

    // MARK: - Background Search Model

    private struct SearchableFile: Sendable {
        let path: String
        let lowercasedName: String
        let fileExtension: String
        let sizeInBytes: Int64
        let displayName: String

        init(file: FileItem) {
            self.path = file.path
            self.lowercasedName = file.name.lowercased()
            self.fileExtension = file.fileExtension.lowercased()
            self.sizeInBytes = file.sizeInBytes
            self.displayName = file.name
        }
    }

    private struct SearchHit: Sendable {
        let path: String
        let filenameMatched: Bool
        let contentSnippet: String?
    }

    private struct SearchConfiguration: Sendable {
        let maxFileSizeForContentScan: Int64
        let snippetContextLength: Int
        let searchableExtensions: Set<String>
        let plainTextExtensions: Set<String>
    }

    private struct CustomFolderBookmark: Sendable {
        let key: String
        let folderPath: String
    }

    private struct ContentMatch: Sendable {
        let snippet: String
    }

    // MARK: - Background Search Execution

    private static func searchHits(
        query: String,
        files: [SearchableFile],
        configuration: SearchConfiguration
    ) -> [SearchHit] {
        let customFolderBookmarks = loadCustomFolderBookmarks()

        var hits: [SearchHit] = []
        hits.reserveCapacity(min(files.count, 256))

        for file in files {
            if Task.isCancelled {
                break
            }

            let filenameMatched = file.lowercasedName.contains(query)
            let contentMatch = searchFileContent(
                file: file,
                query: query,
                configuration: configuration,
                customFolderBookmarks: customFolderBookmarks
            )

            if filenameMatched || contentMatch != nil {
                hits.append(SearchHit(
                    path: file.path,
                    filenameMatched: filenameMatched,
                    contentSnippet: contentMatch?.snippet
                ))
            }
        }

        return hits
    }

    private static func searchFileContent(
        file: SearchableFile,
        query: String,
        configuration: SearchConfiguration,
        customFolderBookmarks: [CustomFolderBookmark]
    ) -> ContentMatch? {
        // Skip files that are too large
        guard file.sizeInBytes <= configuration.maxFileSizeForContentScan else {
            return nil
        }

        // Skip non-searchable file types
        guard configuration.searchableExtensions.contains(file.fileExtension) else {
            return nil
        }

        // Only plain text is directly read today
        guard configuration.plainTextExtensions.contains(file.fileExtension) else {
            return nil
        }

        let scopeURL = establishSecurityScope(for: file.path, customFolderBookmarks: customFolderBookmarks)
        defer { releaseSecurityScope(for: scopeURL) }

        do {
            let fileURL = URL(fileURLWithPath: file.path)
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lowercasedContent = content.lowercased()

            guard let range = lowercasedContent.range(of: query) else {
                return nil
            }

            let snippet = createSnippet(
                from: content,
                matchRange: range,
                contextLength: configuration.snippetContextLength
            )
            return ContentMatch(snippet: snippet)
        } catch {
            Log.debug(
                "Content search skipped for \(file.displayName): \(error.localizedDescription)",
                category: .general
            )
            return nil
        }
    }

    // MARK: - Security Scope Helpers

    private static func loadCustomFolderBookmarks() -> [CustomFolderBookmark] {
        let customFolderPrefix = "CustomFolder_"
        let keychainKeys = BookmarkStoreProvider.shared.listAllBookmarkKeys()

        var customBookmarks: [CustomFolderBookmark] = []
        customBookmarks.reserveCapacity(keychainKeys.count)

        for key in keychainKeys where key.hasPrefix(customFolderPrefix) {
            guard let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: key) else {
                continue
            }

            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                continue
            }

            customBookmarks.append(CustomFolderBookmark(key: key, folderPath: url.path))
        }

        return customBookmarks
    }

    /// Finds the bookmark key for a file's parent monitored folder
    private static func findMonitoredFolderBookmarkKey(
        for path: String,
        customFolderBookmarks: [CustomFolderBookmark]
    ) -> String? {
        let homeDir = realHomeDirectoryPath()

        for (folderName, bookmarkKey) in sourceFolderBookmarks {
            let folderPath = "\(homeDir)/\(folderName)"
            if path.hasPrefix(folderPath + "/") || path == folderPath {
                return bookmarkKey
            }
        }

        for customBookmark in customFolderBookmarks {
            if path.hasPrefix(customBookmark.folderPath + "/") || path == customBookmark.folderPath {
                return customBookmark.key
            }
        }

        return nil
    }

    /// Establishes security-scoped access for a file's parent monitored folder
    private static func establishSecurityScope(
        for path: String,
        customFolderBookmarks: [CustomFolderBookmark]
    ) -> URL? {
        guard let bookmarkKey = findMonitoredFolderBookmarkKey(
            for: path,
            customFolderBookmarks: customFolderBookmarks
        ) else {
            return nil
        }

        guard let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }

        return url
    }

    /// Releases security-scoped access for a folder URL
    private static func releaseSecurityScope(for url: URL?) {
        url?.stopAccessingSecurityScopedResource()
    }

    private static func realHomeDirectoryPath() -> String {
        if let pw = getpwuid(getuid()), let homeDirPointer = pw.pointee.pw_dir {
            return String(cString: homeDirPointer)
        }
        return NSHomeDirectory()
    }

    // MARK: - Snippet Helpers

    /// Creates a snippet of text around the match location
    private static func createSnippet(
        from content: String,
        matchRange: Range<String.Index>,
        contextLength: Int
    ) -> String {
        let snippetStart = content.index(
            matchRange.lowerBound,
            offsetBy: -contextLength,
            limitedBy: content.startIndex
        ) ?? content.startIndex
        let snippetEnd = content.index(
            matchRange.upperBound,
            offsetBy: contextLength,
            limitedBy: content.endIndex
        ) ?? content.endIndex

        var snippet = String(content[snippetStart..<snippetEnd])

        snippet = snippet.replacingOccurrences(of: "\n", with: " ")
        snippet = snippet.replacingOccurrences(of: "\r", with: "")
        snippet = snippet.trimmingCharacters(in: .whitespaces)

        if snippetStart != content.startIndex {
            snippet = "..." + snippet
        }
        if snippetEnd != content.endIndex {
            snippet += "..."
        }

        return snippet
    }
}

extension ContentSearchService: ContentSearchServing {}
