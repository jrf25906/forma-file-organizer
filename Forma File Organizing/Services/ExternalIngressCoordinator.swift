import AppKit
import Combine
import Foundation
import SwiftData

enum ExternalIngressSource: String, Codable, Sendable {
    case finderService
    case spotlightIntent
}

enum ExternalIngressItemKind: String, Codable, Sendable {
    case fileURL
    case folderURL
}

enum ExternalIngressExecutionMode: String, Codable, Hashable, Sendable {
    case immediate
    case reviewFirst
}

enum ExternalIngressSkipReason: String, Codable, Sendable {
    case unsupportedSelection
    case packageSelection
    case aliasSelection
    case inaccessibleSelection
}

struct ExternalIngressSkippedItem: Codable, Hashable, Sendable {
    let path: String
    let reason: ExternalIngressSkipReason
    let message: String
}

struct ExternalIngressOutcomeSummary: Codable, Equatable, Sendable {
    let source: ExternalIngressSource
    let workflowTemplateID: String?
    let autoOrganizedCount: Int
    let reviewCount: Int
    let skippedCount: Int
    let reauthorizationRequiredCount: Int

    var statusText: String {
        if reauthorizationRequiredCount > 0,
           autoOrganizedCount == 0,
           reviewCount == 0,
           skippedCount == reauthorizationRequiredCount {
            return "Forma needs you to run Organize with Forma again to restore access to the selected items."
        }

        var parts: [String] = []

        if autoOrganizedCount > 0 {
            parts.append("organized \(autoOrganizedCount) item" + (autoOrganizedCount == 1 ? "" : "s"))
        }
        if reviewCount > 0 {
            parts.append("\(reviewCount) need review")
        }
        if skippedCount > 0 {
            parts.append("skipped \(skippedCount)")
        }

        if parts.isEmpty {
            return "Forma didn't find anything to organize."
        }

        return "Forma " + parts.joined(separator: ", ") + "."
    }

    static func inferred(
        source: ExternalIngressSource,
        workflowTemplateID: String?,
        autoOrganizedCount: Int = 0,
        reviewPaths: [String],
        skippedItems: [ExternalIngressSkippedItem]
    ) -> ExternalIngressOutcomeSummary {
        ExternalIngressOutcomeSummary(
            source: source,
            workflowTemplateID: workflowTemplateID,
            autoOrganizedCount: autoOrganizedCount,
            reviewCount: reviewPaths.count,
            skippedCount: skippedItems.count,
            reauthorizationRequiredCount: skippedItems.filter { $0.reason == .inaccessibleSelection }.count
        )
    }
}

struct ExplicitSelectionScanResult: Sendable {
    let files: [FileMetadata]
    let skippedItems: [ExternalIngressSkippedItem]
    let scannedRootPaths: [String]

    var scannedPaths: [String] {
        files.map(\.path)
    }
}

struct ExternalIngressRequestItem: Codable, Hashable, Sendable {
    let path: String
    let bookmarkData: Data?
    let bookmarkCreationFailed: Bool
    let kind: ExternalIngressItemKind
}

struct ExternalIngressRequest: Codable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let source: ExternalIngressSource
    let items: [ExternalIngressRequestItem]
    let workflowTemplateID: String?
    let executionMode: ExternalIngressExecutionMode

    init(
        id: UUID,
        createdAt: Date,
        source: ExternalIngressSource,
        items: [ExternalIngressRequestItem],
        workflowTemplateID: String?,
        executionMode: ExternalIngressExecutionMode = .immediate
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.items = items
        self.workflowTemplateID = workflowTemplateID
        self.executionMode = executionMode
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case source
        case items
        case workflowTemplateID
        case executionMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        source = try container.decode(ExternalIngressSource.self, forKey: .source)
        items = try container.decode([ExternalIngressRequestItem].self, forKey: .items)
        workflowTemplateID = try container.decodeIfPresent(String.self, forKey: .workflowTemplateID)
        executionMode = try container.decodeIfPresent(ExternalIngressExecutionMode.self, forKey: .executionMode) ?? .immediate
    }
}

struct ExternalReviewSession: Codable, Equatable, Sendable {
    let requestID: UUID
    let source: ExternalIngressSource
    let reviewPaths: [String]
    let scannedRootPaths: [String]
    let skippedItems: [ExternalIngressSkippedItem]
    let summary: ExternalIngressOutcomeSummary
    let promotionCandidate: ExternalReviewPromotionCandidate?

    var statusText: String {
        summary.statusText
    }

    init(
        requestID: UUID,
        source: ExternalIngressSource,
        reviewPaths: [String],
        scannedRootPaths: [String],
        skippedItems: [ExternalIngressSkippedItem],
        summary: ExternalIngressOutcomeSummary,
        promotionCandidate: ExternalReviewPromotionCandidate? = nil
    ) {
        self.requestID = requestID
        self.source = source
        self.reviewPaths = reviewPaths
        self.scannedRootPaths = scannedRootPaths
        self.skippedItems = skippedItems
        self.summary = summary
        self.promotionCandidate = promotionCandidate
    }

    init(
        requestID: UUID,
        source: ExternalIngressSource,
        reviewPaths: [String],
        scannedRootPaths: [String],
        skippedItems: [ExternalIngressSkippedItem],
        statusText: String,
        promotionCandidate: ExternalReviewPromotionCandidate? = nil
    ) {
        _ = statusText
        self.init(
            requestID: requestID,
            source: source,
            reviewPaths: reviewPaths,
            scannedRootPaths: scannedRootPaths,
            skippedItems: skippedItems,
            summary: .inferred(
                source: source,
                workflowTemplateID: nil,
                reviewPaths: reviewPaths,
                skippedItems: skippedItems
            ),
            promotionCandidate: promotionCandidate
        )
    }
}

struct ExternalReviewPromotionCandidate: Codable, Equatable, Sendable {
    let folderType: BookmarkFolder.FolderType
    let bookmarkData: Data
}

struct ExternalIngressResult: Equatable, Sendable {
    let autoOrganizedCount: Int
    let needsReviewPaths: [String]
    let skippedItems: [ExternalIngressSkippedItem]
    let didRequireOnboarding: Bool
    let summary: ExternalIngressOutcomeSummary
    let scannedPaths: [String]
    let scannedRootPaths: [String]

    var statusText: String {
        summary.statusText
    }
}

enum ExternalIngressDisposition: Sendable {
    case noPendingRequest
    case needsOnboarding(ExternalIngressRequest)
    case processed(ExternalIngressResult)
    case notConfigured
}

enum ExternalIngressError: LocalizedError {
    case emptySelection
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "No files or folders were selected."
        case .notConfigured:
            return "Forma is still starting up. Try again in a moment."
        }
    }
}

enum ExternalReviewSessionNotificationUserInfo {
    static let session = "session"
}

extension Notification.Name {
    static let externalReviewSessionDidChange = Notification.Name("externalReviewSessionDidChange")
}

@MainActor
final class ExternalReviewSessionStore: ObservableObject {
    static let shared = ExternalReviewSessionStore()

    @Published private(set) var currentSession: ExternalReviewSession?

    func publish(_ session: ExternalReviewSession?) {
        currentSession = session
        NotificationCenter.default.post(
            name: .externalReviewSessionDidChange,
            object: nil,
            userInfo: [ExternalReviewSessionNotificationUserInfo.session: session as Any]
        )
    }
}

@MainActor
final class ExternalIngressCoordinator {
    static let shared = ExternalIngressCoordinator()

    private enum Keys {
        static let pendingRequest = "externalIngress.pendingRequest"
    }

    private struct ResolvedRequestItems {
        let authorizedURLs: [(url: URL, startedSecurityScope: Bool)]
        let reauthorizationItems: [ExternalIngressSkippedItem]
    }

    private let defaults: UserDefaults
    private let activateApp: @MainActor () -> Void
    private let publishReviewSession: @MainActor (ExternalReviewSession?) -> Void
    private let eligibleFilesForAutoOrganize: @MainActor ([FileItem]) -> [FileItem]
    private let organizeFile: @MainActor (FileItem, ModelContext, String?, WorkflowInvocationContext) async -> Bool
    private let createBookmarkData: @MainActor (URL) throws -> Data?

    private var modelContext: ModelContext?
    private var fileSystemService: FileSystemServiceProtocol?
    private var fileScanPipeline: FileScanPipelineProtocol?
    private var ruleEngine: RuleEngine?

    init(
        defaults: UserDefaults = .standard,
        activateApp: @escaping @MainActor () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        },
        publishReviewSession: @escaping @MainActor (ExternalReviewSession?) -> Void = { session in
            ExternalReviewSessionStore.shared.publish(session)
        },
        eligibleFilesForAutoOrganize: @escaping @MainActor ([FileItem]) -> [FileItem] = { files in
            DashboardFileScanProvider.autoOrganizeEligibleFiles(from: files)
        },
        organizeFile: @escaping @MainActor (FileItem, ModelContext, String?, WorkflowInvocationContext) async -> Bool = { file, _, workflowTemplateID, invocationContext in
            await FormaActions.shared.organizeFile(
                file,
                workflowTemplateID: workflowTemplateID,
                invocationContext: invocationContext
            )
        },
        createBookmarkData: @escaping @MainActor (URL) throws -> Data? = { url in
            try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    ) {
        self.defaults = defaults
        self.activateApp = activateApp
        self.publishReviewSession = publishReviewSession
        self.eligibleFilesForAutoOrganize = eligibleFilesForAutoOrganize
        self.organizeFile = organizeFile
        self.createBookmarkData = createBookmarkData
    }

    var pendingRequest: ExternalIngressRequest? {
        loadPendingRequest()
    }

    func configure(
        modelContext: ModelContext,
        fileSystemService: FileSystemServiceProtocol,
        fileScanPipeline: FileScanPipelineProtocol,
        ruleEngine: RuleEngine
    ) {
        self.modelContext = modelContext
        self.fileSystemService = fileSystemService
        self.fileScanPipeline = fileScanPipeline
        self.ruleEngine = ruleEngine
    }

    @discardableResult
    func queueRequest(
        source: ExternalIngressSource,
        urls: [URL],
        workflowTemplateID: String? = nil,
        executionMode: ExternalIngressExecutionMode = .immediate
    ) throws -> ExternalIngressRequest {
        guard !urls.isEmpty else {
            throw ExternalIngressError.emptySelection
        }

        let items = urls.map(makeRequestItem(from:))
        let request = ExternalIngressRequest(
            id: UUID(),
            createdAt: Date(),
            source: source,
            items: items,
            workflowTemplateID: WorkflowTemplateSelectionStore.validatedTemplateID(workflowTemplateID),
            executionMode: executionMode
        )
        savePendingRequest(request)
        return request
    }

    func handleRequest(
        source: ExternalIngressSource,
        urls: [URL],
        workflowTemplateID: String? = nil,
        executionMode: ExternalIngressExecutionMode = .immediate
    ) async throws -> ExternalIngressDisposition {
        _ = try queueRequest(
            source: source,
            urls: urls,
            workflowTemplateID: workflowTemplateID,
            executionMode: executionMode
        )
        return await processPendingRequestIfPossible()
    }

    func processPendingRequestIfPossible() async -> ExternalIngressDisposition {
        guard let request = pendingRequest else {
            publishReviewSession(nil)
            return .noPendingRequest
        }

        guard defaults.bool(forKey: "hasCompletedOnboarding") else {
            activateApp()
            return .needsOnboarding(request)
        }

        guard let modelContext,
              let fileSystemService,
              let fileScanPipeline,
              let ruleEngine else {
            return .notConfigured
        }

        let resolvedSelection = resolvedURLs(for: request.items)
        let resolvedURLs = resolvedSelection.authorizedURLs
        defer {
            stopAccessingSecurityScopedResources(for: resolvedURLs)
        }

        if resolvedURLs.isEmpty {
            let skippedItems = resolvedSelection.reauthorizationItems
            let result = ExternalIngressResult(
                autoOrganizedCount: 0,
                needsReviewPaths: [],
                skippedItems: skippedItems,
                didRequireOnboarding: false,
                summary: .inferred(
                    source: request.source,
                    workflowTemplateID: request.workflowTemplateID,
                    reviewPaths: [],
                    skippedItems: skippedItems
                ),
                scannedPaths: [],
                scannedRootPaths: []
            )
            presentResultInAppIfNeeded(request: request, result: result)
            clearPendingRequest()
            return .processed(result)
        }

        let explicitSelection: ExplicitSelectionScanResult
        do {
            explicitSelection = try await fileSystemService.scanExplicitSelection(
                urls: resolvedURLs.map(\.url),
                options: FileScanOptions.defaults
            )
        } catch {
            let skippedItems = uniqueSkippedItems(
                resolvedSelection.reauthorizationItems + request.items.map(makeReauthorizationSkippedItem(for:))
            )
            let result = ExternalIngressResult(
                autoOrganizedCount: 0,
                needsReviewPaths: [],
                skippedItems: skippedItems,
                didRequireOnboarding: false,
                summary: .inferred(
                    source: request.source,
                    workflowTemplateID: request.workflowTemplateID,
                    reviewPaths: [],
                    skippedItems: skippedItems
                ),
                scannedPaths: [],
                scannedRootPaths: []
            )
            presentResultInAppIfNeeded(request: request, result: result)
            clearPendingRequest()
            return .processed(result)
        }

        let rules = fetchEnabledRules(from: modelContext)
        let pipelineResult = await fileScanPipeline.evaluateAndPersistExplicitFiles(
            files: explicitSelection.files,
            scannedRootPaths: explicitSelection.scannedRootPaths,
            reconcileMissingFiles: false,
            ruleEngine: ruleEngine,
            rules: rules,
            context: modelContext
        )

        let eligibleFiles = eligibleFilesForAutoOrganize(pipelineResult.files)
        var autoOrganizedCount = 0

        let invocationContext = workflowInvocationContext(for: request.source)
        for file in eligibleFiles {
            if await organizeFile(
                file,
                modelContext,
                request.workflowTemplateID,
                invocationContext
            ) {
                autoOrganizedCount += 1
            }
        }

        let reviewPaths = pipelineResult.files
            .filter { file in
                file.status == .pending || file.status == .ready
            }
            .map(\.path)

        let skippedItems = uniqueSkippedItems(
            resolvedSelection.reauthorizationItems + explicitSelection.skippedItems
        )

        let result = ExternalIngressResult(
            autoOrganizedCount: autoOrganizedCount,
            needsReviewPaths: reviewPaths,
            skippedItems: skippedItems,
            didRequireOnboarding: false,
            summary: .inferred(
                source: request.source,
                workflowTemplateID: request.workflowTemplateID,
                autoOrganizedCount: autoOrganizedCount,
                reviewPaths: reviewPaths,
                skippedItems: skippedItems
            ),
            scannedPaths: pipelineResult.files.map(\.path),
            scannedRootPaths: pipelineResult.scannedRootPaths
        )

        publishDashboardUpdate(from: result)
        presentResultInAppIfNeeded(request: request, result: result)

        clearPendingRequest()
        return .processed(result)
    }

    private func fetchEnabledRules(from context: ModelContext) -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate { $0.isEnabled },
            sortBy: [SortDescriptor<Rule>(\.sortOrder, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            Log.error("ExternalIngressCoordinator: Failed to load rules - \(error.localizedDescription)", category: .pipeline)
            return []
        }
    }

    private func publishDashboardUpdate(from result: ExternalIngressResult) {
        NotificationCenter.default.post(
            name: .automationScanDidPersist,
            object: nil,
            userInfo: [
                AutomationScanNotificationUserInfo.scannedPaths: result.scannedPaths,
                AutomationScanNotificationUserInfo.updatedPaths: result.scannedPaths,
                AutomationScanNotificationUserInfo.removedPaths: [],
                AutomationScanNotificationUserInfo.scannedRootPaths: result.scannedRootPaths,
                AutomationScanNotificationUserInfo.replacesAllFiles: false,
                AutomationScanNotificationUserInfo.requiresClusterRefresh: false,
                AutomationScanNotificationUserInfo.errorSummary: Optional<String>.none as Any
            ]
        )
    }

    private func workflowInvocationContext(for source: ExternalIngressSource) -> WorkflowInvocationContext {
        switch source {
        case .finderService:
            return .finderService
        case .spotlightIntent:
            return .spotlightIntent
        }
    }

    private func makeRequestItem(from url: URL) -> ExternalIngressRequestItem {
        let standardizedURL = url.standardizedFileURL
        let kind: ExternalIngressItemKind = isDirectoryURL(standardizedURL) ? .folderURL : .fileURL
        let bookmarkData: Data?
        let bookmarkCreationFailed: Bool
        do {
            bookmarkData = try createBookmarkData(standardizedURL)
            bookmarkCreationFailed = false
        } catch {
            bookmarkData = nil
            bookmarkCreationFailed = true
            Log.warning(
                "ExternalIngressCoordinator: Failed to capture bookmark for \(standardizedURL.path) - \(error.localizedDescription)",
                category: .bookmark
            )
        }

        return ExternalIngressRequestItem(
            path: standardizedURL.path,
            bookmarkData: bookmarkData,
            bookmarkCreationFailed: bookmarkCreationFailed,
            kind: kind
        )
    }

    private func isDirectoryURL(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) {
            return values.isDirectory ?? false
        }

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private func loadPendingRequest() -> ExternalIngressRequest? {
        guard let data = defaults.data(forKey: Keys.pendingRequest) else {
            return nil
        }

        return try? JSONDecoder().decode(ExternalIngressRequest.self, from: data)
    }

    private func savePendingRequest(_ request: ExternalIngressRequest) {
        guard let data = try? JSONEncoder().encode(request) else { return }
        defaults.set(data, forKey: Keys.pendingRequest)
    }

    private func clearPendingRequest() {
        defaults.removeObject(forKey: Keys.pendingRequest)
    }

    private func resolvedURLs(for items: [ExternalIngressRequestItem]) -> ResolvedRequestItems {
        var authorizedURLs: [(url: URL, startedSecurityScope: Bool)] = []
        var reauthorizationItems: [ExternalIngressSkippedItem] = []

        for item in items {
            if item.bookmarkCreationFailed {
                reauthorizationItems.append(makeReauthorizationSkippedItem(for: item))
                continue
            }

            guard let bookmarkData = item.bookmarkData else {
                authorizedURLs.append((URL(fileURLWithPath: item.path).standardizedFileURL, false))
                continue
            }

            var isStale = false
            let resolvedURL: URL
            do {
                resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ).standardizedFileURL
            } catch {
                reauthorizationItems.append(makeReauthorizationSkippedItem(for: item))
                continue
            }

            guard !isStale, resolvedURL.startAccessingSecurityScopedResource() else {
                reauthorizationItems.append(makeReauthorizationSkippedItem(for: item))
                continue
            }

            authorizedURLs.append((resolvedURL, true))
        }

        return ResolvedRequestItems(
            authorizedURLs: authorizedURLs,
            reauthorizationItems: uniqueSkippedItems(reauthorizationItems)
        )
    }

    private func stopAccessingSecurityScopedResources(
        for urls: [(url: URL, startedSecurityScope: Bool)]
    ) {
        for entry in urls where entry.startedSecurityScope {
            entry.url.stopAccessingSecurityScopedResource()
        }
    }

    private func makeReauthorizationSkippedItem(for item: ExternalIngressRequestItem) -> ExternalIngressSkippedItem {
        let selectionDescription = item.kind == .folderURL ? "folder" : "item"
        return ExternalIngressSkippedItem(
            path: item.path,
            reason: .inaccessibleSelection,
            message: "Forma needs you to run Organize with Forma again to restore access to this \(selectionDescription)."
        )
    }

    private func uniqueSkippedItems(_ items: [ExternalIngressSkippedItem]) -> [ExternalIngressSkippedItem] {
        var seen = Set<ExternalIngressSkippedItem>()
        var uniqueItems: [ExternalIngressSkippedItem] = []

        for item in items where seen.insert(item).inserted {
            uniqueItems.append(item)
        }

        return uniqueItems
    }

    private func presentResultInAppIfNeeded(
        request: ExternalIngressRequest,
        result: ExternalIngressResult
    ) {
        let shouldPresentInApp: Bool
        switch request.executionMode {
        case .immediate:
            shouldPresentInApp = !result.needsReviewPaths.isEmpty || !result.skippedItems.isEmpty
        case .reviewFirst:
            shouldPresentInApp = !result.needsReviewPaths.isEmpty
        }

        if shouldPresentInApp {
            activateApp()
            publishReviewSession(
                ExternalReviewSession(
                    requestID: request.id,
                    source: request.source,
                    reviewPaths: result.needsReviewPaths,
                    scannedRootPaths: result.scannedRootPaths,
                    skippedItems: result.skippedItems,
                    summary: result.summary,
                    promotionCandidate: makePromotionCandidate(for: request, scannedRootPaths: result.scannedRootPaths)
                )
            )
        } else {
            publishReviewSession(nil)
        }
    }

    private func makePromotionCandidate(
        for request: ExternalIngressRequest,
        scannedRootPaths: [String]
    ) -> ExternalReviewPromotionCandidate? {
        guard request.items.count == 1,
              let folderItem = request.items.first,
              folderItem.kind == .folderURL,
              !folderItem.bookmarkCreationFailed,
              let bookmarkData = folderItem.bookmarkData else {
            return nil
        }

        let normalizedRootPaths = Set(
            scannedRootPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        )
        let normalizedFolderPath = URL(fileURLWithPath: folderItem.path).standardizedFileURL.path
        guard normalizedRootPaths.contains(normalizedFolderPath),
              let folderType = BookmarkFolder.FolderType.inferredFromRootPath(normalizedFolderPath) else {
            return nil
        }

        return ExternalReviewPromotionCandidate(
            folderType: folderType,
            bookmarkData: bookmarkData
        )
    }

}

@MainActor
final class FinderServicesRegistrationController {
    static let shared = FinderServicesRegistrationController()

    typealias CommandRunner = @MainActor (_ path: String, _ arguments: [String]) throws -> Void

    private enum Keys {
        static let registeredVersion = "finderServices.registeredVersion"
        static let lastRefreshDate = "finderServices.lastRefreshDate"
    }

    private enum ToolPaths {
        static let launchServicesRegister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        static let pasteboardServer = "/System/Library/CoreServices/pbs"
    }

    private enum RegistrationCommandError: LocalizedError {
        case commandFailed(path: String, status: Int32, errorOutput: String)

        var errorDescription: String? {
            switch self {
            case let .commandFailed(path, status, errorOutput):
                if errorOutput.isEmpty {
                    return "\(path) exited with status \(status)."
                }
                return "\(path) exited with status \(status): \(errorOutput)"
            }
        }
    }

    struct Status: Sendable {
        let currentVersion: String
        let registeredVersion: String?
        let lastRefreshDate: Date?

        var needsRefresh: Bool {
            registeredVersion != currentVersion
        }

        var statusText: String {
            if needsRefresh {
                return "Finder Services registration needs a refresh for this build."
            }

            if let lastRefreshDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return "Finder Services were refreshed on \(formatter.string(from: lastRefreshDate))."
            }

            return "Finder Services are registered for this build."
        }
    }

    private let defaults: UserDefaults
    private let bundle: Bundle
    private let runCommand: CommandRunner
    private let updateDynamicServices: () -> Void
    private let isTestingProcess: () -> Bool
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        runCommand: @escaping CommandRunner = FinderServicesRegistrationController.defaultRunCommand,
        updateDynamicServices: @escaping () -> Void = { NSUpdateDynamicServices() },
        isTestingProcess: @escaping () -> Bool = {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        },
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.runCommand = runCommand
        self.updateDynamicServices = updateDynamicServices
        self.isTestingProcess = isTestingProcess
        self.now = now
    }

    func refreshRegistrationIfNeeded(force: Bool = false) {
        let status = currentStatus()
        guard force || status.needsRefresh else { return }

        let refreshDate = now()

        guard !isTestingProcess() else {
            defaults.set(status.currentVersion, forKey: Keys.registeredVersion)
            defaults.set(refreshDate, forKey: Keys.lastRefreshDate)
            return
        }

        do {
            try rebuildServicesRegistration()
        } catch {
            Log.error(
                "FinderServicesRegistrationController: Failed to rebuild Finder Services registration - \(error.localizedDescription)",
                category: .automation
            )
            updateDynamicServices()
        }

        defaults.set(status.currentVersion, forKey: Keys.registeredVersion)
        defaults.set(refreshDate, forKey: Keys.lastRefreshDate)
    }

    func currentStatus() -> Status {
        Status(
            currentVersion: currentVersionIdentifier(),
            registeredVersion: defaults.string(forKey: Keys.registeredVersion),
            lastRefreshDate: defaults.object(forKey: Keys.lastRefreshDate) as? Date
        )
    }

    private func currentVersionIdentifier() -> String {
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(shortVersion) (\(buildVersion))"
    }

    private func rebuildServicesRegistration() throws {
        try runCommand(
            ToolPaths.launchServicesRegister,
            ["-f", "-R", "-trusted", bundle.bundleURL.path]
        )
        try runCommand(ToolPaths.pasteboardServer, ["-flush"])
        try runCommand(ToolPaths.pasteboardServer, ["-update"])
        updateDynamicServices()
    }

    private static func defaultRunCommand(path: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let standardError = Pipe()
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(
                data: standardError.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            throw RegistrationCommandError.commandFailed(
                path: path,
                status: process.terminationStatus,
                errorOutput: errorOutput
            )
        }
    }
}

@MainActor
final class FinderServicesProvider: NSObject {
    @objc(organizeWithForma:userData:error:)
    func organizeWithForma(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        _ = userData

        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]

        guard let urls, !urls.isEmpty else {
            error.pointee = "No files or folders were selected for Forma." as NSString
            return
        }

        Task { @MainActor in
            do {
                _ = try await ExternalIngressCoordinator.shared.handleRequest(
                    source: .finderService,
                    urls: urls
                )
            } catch {
                Log.error("FinderServicesProvider: Failed to handle service request - \(error.localizedDescription)", category: .automation)
            }
        }
    }
}
