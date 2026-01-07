import Foundation
import Combine

// MARK: - Security-Scoped Bookmark Access

/// Bookmark keys for monitored source folders
private let sourceFolderBookmarks: [String: String] = [
    "Desktop": "DesktopFolderBookmark",
    "Downloads": "DownloadsFolderBookmark",
    "Documents": "DocumentsFolderBookmark",
    "Pictures": "PicturesFolderBookmark",
    "Music": "MusicFolderBookmark"
]

/// Searches file contents using Spotlight metadata and direct file reading.
///
/// This service provides content-aware search capabilities beyond filename matching:
/// - Uses NSMetadataQuery (Spotlight) for fast indexed content search
/// - Falls back to direct file reading for non-indexed files
/// - Returns rich results with match type indicators and content snippets
///
/// Performance considerations:
/// - Skips files larger than `maxFileSizeForContentScan` (default: 10MB)
/// - Uses debouncing at the FilterManager level (300ms recommended for content search)
/// - Cancels previous searches when new queries start
@MainActor
final class ContentSearchService: ObservableObject {

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

    // MARK: - Published State

    @Published private(set) var searchState: SearchState = .idle
    @Published private(set) var results: [SearchResult] = []

    // MARK: - Configuration

    /// Maximum file size to scan content (10 MB default)
    var maxFileSizeForContentScan: Int64 = 10 * 1024 * 1024

    /// Snippet context length (characters before and after match)
    var snippetContextLength: Int = 40

    /// File extensions that support content search
    private let searchableExtensions: Set<String> = [
        // Text files
        "txt", "md", "markdown", "rtf", "csv", "json", "xml", "yaml", "yml",
        // Code files
        "swift", "py", "js", "ts", "html", "css", "java", "c", "cpp", "h", "m",
        // Documents (Spotlight-indexed)
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "keynote"
    ]

    // MARK: - Private State

    private var currentSearchTask: Task<Void, Never>?

    // MARK: - Security Scope Helpers

    /// Finds the bookmark key for a file's parent monitored folder
    private func findMonitoredFolderBookmarkKey(for path: String) -> String? {
        // Get real home directory (not sandboxed container path)
        let homeDir: String
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
            homeDir = String(cString: home)
        } else {
            homeDir = NSHomeDirectory()
        }

        for (folderName, bookmarkKey) in sourceFolderBookmarks {
            let folderPath = "\(homeDir)/\(folderName)"
            if path.hasPrefix(folderPath) {
                return bookmarkKey
            }
        }

        // Check for custom folder bookmarks
        let customFolderPrefix = "CustomFolder_"
        let keychainKeys = SecureBookmarkStore.listAllBookmarkKeys()
        for key in keychainKeys where key.hasPrefix(customFolderPrefix) {
            if let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: key) {
                var isStale = false
                if let url = try? URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ), path.hasPrefix(url.path) {
                    return key
                }
            }
        }

        return nil
    }

    /// Establishes security-scoped access for a file's parent monitored folder
    private func establishSecurityScope(for path: String) -> URL? {
        guard let bookmarkKey = findMonitoredFolderBookmarkKey(for: path) else {
            return nil
        }

        guard let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) else {
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
    private func releaseSecurityScope(for url: URL?) {
        url?.stopAccessingSecurityScopedResource()
    }

    // MARK: - Singleton

    static let shared = ContentSearchService()

    private init() {}

    // MARK: - Public Interface

    /// Searches files for the given query, combining filename and content matches.
    ///
    /// - Parameters:
    ///   - query: The search string
    ///   - files: The files to search within
    /// - Returns: Array of search results with match type and snippets
    func search(query: String, in files: [FileItem]) async -> [SearchResult] {
        // Cancel any existing search
        currentSearchTask?.cancel()

        guard !query.isEmpty else {
            searchState = .idle
            results = []
            return []
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else {
            searchState = .idle
            results = []
            return []
        }

        searchState = .searching(progress: 0.0)

        var searchResults: [SearchResult] = []
        let totalFiles = files.count

        // Create a task that can be cancelled
        let task = Task { @MainActor [weak self] in
            guard let self else { return }

            for (index, file) in files.enumerated() {
                // Check for cancellation
                if Task.isCancelled { break }

                // Update progress periodically (every 10 files or at end)
                if index % 10 == 0 || index == totalFiles - 1 {
                    let progress = Double(index + 1) / Double(totalFiles)
                    self.searchState = .searching(progress: progress)
                }

                // Check filename match
                let filenameMatches = file.name.lowercased().contains(trimmedQuery)

                // Check content match (if eligible)
                let contentMatch = await self.searchFileContent(file: file, query: trimmedQuery)

                // Determine match type and create result
                if filenameMatches && contentMatch != nil {
                    searchResults.append(SearchResult(
                        file: file,
                        matchType: .both,
                        contentSnippet: contentMatch?.snippet,
                        matchRanges: contentMatch?.ranges
                    ))
                } else if filenameMatches {
                    searchResults.append(SearchResult(
                        file: file,
                        matchType: .filename
                    ))
                } else if let contentMatch = contentMatch {
                    searchResults.append(SearchResult(
                        file: file,
                        matchType: .content,
                        contentSnippet: contentMatch.snippet,
                        matchRanges: contentMatch.ranges
                    ))
                }
            }

            if !Task.isCancelled {
                self.searchState = .complete(resultCount: searchResults.count)
                self.results = searchResults
            }
        }

        currentSearchTask = task
        await task.value

        return Task.isCancelled ? [] : searchResults
    }

    /// Cancels the current search operation
    func cancelSearch() {
        currentSearchTask?.cancel()
        searchState = .idle
    }

    // MARK: - Private Methods

    private struct ContentMatch {
        let snippet: String
        let ranges: [Range<String.Index>]?
    }

    /// Searches file content for the query string
    private func searchFileContent(file: FileItem, query: String) async -> ContentMatch? {
        // Skip files that are too large
        guard file.sizeInBytes <= maxFileSizeForContentScan else {
            return nil
        }

        // Skip non-searchable file types
        guard searchableExtensions.contains(file.fileExtension.lowercased()) else {
            return nil
        }

        let fileURL = URL(fileURLWithPath: file.path)

        // Try to read file content
        // For plain text files, read directly
        // For documents (PDF, etc.), Spotlight should handle - we skip direct read
        let plainTextExtensions: Set<String> = [
            "txt", "md", "markdown", "rtf", "csv", "json", "xml", "yaml", "yml",
            "swift", "py", "js", "ts", "html", "css", "java", "c", "cpp", "h", "m"
        ]

        guard plainTextExtensions.contains(file.fileExtension.lowercased()) else {
            // For non-plain-text files, we'd use Spotlight's kMDItemTextContent
            // For now, skip content search for these (filename search still works)
            return nil
        }

        // Establish security-scoped access for sandboxed file reading
        let scopeURL = establishSecurityScope(for: file.path)
        defer { releaseSecurityScope(for: scopeURL) }

        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lowercasedContent = content.lowercased()

            // Find the first match
            guard let range = lowercasedContent.range(of: query) else {
                return nil
            }

            // Create snippet around match
            let snippet = createSnippet(from: content, matchRange: range, query: query)

            return ContentMatch(snippet: snippet, ranges: [range])
        } catch {
            // File couldn't be read (permissions, encoding, etc.)
            Log.debug("Content search skipped for \(file.name): \(error.localizedDescription)", category: .general)
            return nil
        }
    }

    /// Creates a snippet of text around the match location
    private func createSnippet(from content: String, matchRange: Range<String.Index>, query: String) -> String {
        let contextLength = snippetContextLength

        // Get the actual match text in original case
        let matchStartIndex = matchRange.lowerBound
        let matchEndIndex = matchRange.upperBound

        // Calculate snippet bounds
        let snippetStart = content.index(matchStartIndex, offsetBy: -contextLength, limitedBy: content.startIndex) ?? content.startIndex
        let snippetEnd = content.index(matchEndIndex, offsetBy: contextLength, limitedBy: content.endIndex) ?? content.endIndex

        var snippet = String(content[snippetStart..<snippetEnd])

        // Clean up the snippet
        snippet = snippet.replacingOccurrences(of: "\n", with: " ")
        snippet = snippet.replacingOccurrences(of: "\r", with: "")
        snippet = snippet.trimmingCharacters(in: .whitespaces)

        // Add ellipsis if truncated
        if snippetStart != content.startIndex {
            snippet = "..." + snippet
        }
        if snippetEnd != content.endIndex {
            snippet = snippet + "..."
        }

        return snippet
    }
}

// MARK: - Search Result Lookup

extension ContentSearchService {
    /// Lookup table to get search results by file path
    /// Use this to display match indicators in file rows
    func result(for file: FileItem) -> SearchResult? {
        results.first { $0.file.path == file.path }
    }

    /// Quick check if a file has any search match
    func hasMatch(for file: FileItem) -> Bool {
        results.contains { $0.file.path == file.path }
    }

    /// Get match type for a file (nil if no match)
    func matchType(for file: FileItem) -> MatchType? {
        result(for: file)?.matchType
    }

    /// Get content snippet for a file (nil if no content match)
    func snippet(for file: FileItem) -> String? {
        result(for: file)?.contentSnippet
    }
}
