import Foundation
import Combine

@MainActor
final class DashboardContentSearchController: ObservableObject {
    @Published private(set) var state: ContentSearchService.SearchState = .idle
    @Published private(set) var results: [ContentSearchService.SearchResult] = []

    private var resultsByPath: [String: ContentSearchService.SearchResult] = [:]
    private var searchTask: Task<Void, Never>?
    private var lastCompletedInput: SearchInputSnapshot?

    private let contentSearchService: ContentSearchServing

    private static let debounceDelay: Duration = .milliseconds(300)

    private struct SearchInputSnapshot: Equatable {
        struct FileSignature: Equatable {
            let path: String
            let sizeInBytes: Int64
            let modificationReferenceTime: TimeInterval
        }

        let normalizedQuery: String
        let files: [FileSignature]
    }

    init(contentSearchService: ContentSearchServing) {
        self.contentSearchService = contentSearchService
    }

    deinit {
        searchTask?.cancel()
    }

    func triggerSearch(
        query: String,
        filesProvider: @escaping @MainActor () -> [FileItem],
        onMatchedPathsUpdated: @escaping @MainActor (Set<String>) -> Void
    ) {
        searchTask?.cancel()
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedQuery.isEmpty else {
            reset(onMatchedPathsUpdated: onMatchedPathsUpdated)
            return
        }

        let currentInput = makeSearchInputSnapshot(
            normalizedQuery: normalizedQuery,
            files: filesProvider()
        )
        if lastCompletedInput == currentInput {
            return
        }

        state = .searching(progress: 0.0)

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.debounceDelay)
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }

            let files = filesProvider()
            let snapshot = self.makeSearchInputSnapshot(
                normalizedQuery: normalizedQuery,
                files: files
            )
            if self.lastCompletedInput == snapshot {
                return
            }

            let searchResults = await self.contentSearchService.search(query: normalizedQuery, in: files)
            guard !Task.isCancelled else { return }

            self.results = searchResults
            self.resultsByPath = Dictionary(
                uniqueKeysWithValues: searchResults.map { ($0.file.path, $0) }
            )
            self.state = .complete(resultCount: searchResults.count)
            onMatchedPathsUpdated(Set(self.resultsByPath.keys))
            self.lastCompletedInput = snapshot
        }
    }

    func matchType(for file: FileItem) -> ContentSearchService.MatchType? {
        resultsByPath[file.path]?.matchType
    }

    func contentSnippet(for file: FileItem) -> String? {
        resultsByPath[file.path]?.contentSnippet
    }

    var resultCount: Int {
        results.count
    }

    private func reset(onMatchedPathsUpdated: @MainActor (Set<String>) -> Void) {
        state = .idle
        results = []
        resultsByPath = [:]
        lastCompletedInput = nil
        onMatchedPathsUpdated([])
    }

    private func makeSearchInputSnapshot(
        normalizedQuery: String,
        files: [FileItem]
    ) -> SearchInputSnapshot {
        let fingerprints = files.map {
            SearchInputSnapshot.FileSignature(
                path: $0.path,
                sizeInBytes: $0.sizeInBytes,
                modificationReferenceTime: $0.modificationDate.timeIntervalSinceReferenceDate
            )
        }

        return SearchInputSnapshot(
            normalizedQuery: normalizedQuery,
            files: fingerprints
        )
    }
}
