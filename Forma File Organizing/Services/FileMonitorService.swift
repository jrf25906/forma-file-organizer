import Foundation
import CoreServices

struct WatchedFolderDescriptor: Equatable, Sendable {
    let location: FolderLocation
    let rootURL: URL
    let bookmarkData: Data?

    init(
        location: FolderLocation,
        rootURL: URL,
        bookmarkData: Data? = nil
    ) {
        self.location = location
        self.rootURL = rootURL.standardizedFileURL
        self.bookmarkData = bookmarkData
    }

    var standardizedRootPath: String {
        rootURL.standardizedFileURL.path
    }
}

@MainActor
protocol FileMonitoring: AnyObject {
    var isMonitoring: Bool { get }

    func startMonitoring(
        folders: [WatchedFolderDescriptor],
        onChange: @escaping @MainActor (Set<FolderLocation>) -> Void
    )

    func updateMonitoredFolders(_ folders: [WatchedFolderDescriptor])
    func stopMonitoring()
}

@MainActor
final class FileMonitorService: FileMonitoring {
    protocol EventStream: AnyObject {
        func setDispatchQueue(_ queue: DispatchQueue)
        func start() -> Bool
        func stop()
        func invalidate()
    }

    @MainActor
    struct Dependencies {
        let makeStream: (_ paths: [String], _ latency: TimeInterval, _ callback: FSEventStreamCallback, _ context: UnsafeMutablePointer<FSEventStreamContext>) -> EventStream?
        let startSecurityScopedAccess: (URL) -> Bool
        let stopSecurityScopedAccess: (URL) -> Void

        init(
            makeStream: @escaping (_ paths: [String], _ latency: TimeInterval, _ callback: FSEventStreamCallback, _ context: UnsafeMutablePointer<FSEventStreamContext>) -> EventStream?,
            startSecurityScopedAccess: @escaping (URL) -> Bool,
            stopSecurityScopedAccess: @escaping (URL) -> Void
        ) {
            self.makeStream = makeStream
            self.startSecurityScopedAccess = startSecurityScopedAccess
            self.stopSecurityScopedAccess = stopSecurityScopedAccess
        }

        @MainActor
        static let live = Dependencies(
            makeStream: { paths, latency, callback, context in
                guard let stream = FSEventStreamCreate(
                    kCFAllocatorDefault,
                    callback,
                    context,
                    paths as CFArray,
                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                    latency,
                    UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
                ) else {
                    return nil
                }
                return LiveEventStream(stream: stream)
            },
            startSecurityScopedAccess: { url in
                url.startAccessingSecurityScopedResource()
            },
            stopSecurityScopedAccess: { url in
                url.stopAccessingSecurityScopedResource()
            }
        )
    }

    private final class LiveEventStream: EventStream {
        private let stream: FSEventStreamRef

        init(stream: FSEventStreamRef) {
            self.stream = stream
        }

        deinit {
            FSEventStreamRelease(stream)
        }

        func setDispatchQueue(_ queue: DispatchQueue) {
            FSEventStreamSetDispatchQueue(stream, queue)
        }

        func start() -> Bool {
            FSEventStreamStart(stream)
        }

        func stop() {
            FSEventStreamStop(stream)
        }

        func invalidate() {
            FSEventStreamInvalidate(stream)
        }
    }

    private let debounceInterval: TimeInterval
    private let dependencies: Dependencies
    private let eventDispatchQueue = DispatchQueue(label: "com.forma.file-monitor", qos: .utility)

    private static let retainStreamContext: CFAllocatorRetainCallBack = { info in
        guard let info else { return nil }
        _ = Unmanaged<FileMonitorService>.fromOpaque(info).retain()
        return UnsafeRawPointer(info)
    }

    private static let releaseStreamContext: CFAllocatorReleaseCallBack = { info in
        guard let info else { return }
        Unmanaged<FileMonitorService>.fromOpaque(info).release()
    }

    private var currentFolders: [WatchedFolderDescriptor] = []
    private var foldersByRootPath: [String: WatchedFolderDescriptor] = [:]
    private var callback: (@MainActor (Set<FolderLocation>) -> Void)?
    private var stream: EventStream?
    private var securityScopedURLs: [URL] = []
    private var pendingRoots: Set<FolderLocation> = []
    private var debounceTask: Task<Void, Never>?

    init(
        debounceInterval: TimeInterval = FormaConfig.Automation.fileWatcherDebounceDurationSeconds,
        dependencies: Dependencies = .live
    ) {
        self.debounceInterval = debounceInterval
        self.dependencies = dependencies
    }

    var isMonitoring: Bool {
        stream != nil
    }

    func startMonitoring(
        folders: [WatchedFolderDescriptor],
        onChange: @escaping @MainActor (Set<FolderLocation>) -> Void
    ) {
        callback = onChange
        rebuildStream(with: folders)
    }

    func updateMonitoredFolders(_ folders: [WatchedFolderDescriptor]) {
        guard callback != nil else { return }
        guard folders != currentFolders else { return }
        rebuildStream(with: folders)
    }

    func stopMonitoring() {
        debounceTask?.cancel()
        debounceTask = nil
        pendingRoots.removeAll()
        currentFolders = []
        foldersByRootPath = [:]
        callback = nil

        teardownStream()
        releaseSecurityScopedAccess()
    }

    #if DEBUG
    func _testEmitChangedPaths(_ changedPaths: [String]) {
        handleChangedPaths(changedPaths)
    }
    #endif

    private func rebuildStream(with folders: [WatchedFolderDescriptor]) {
        debounceTask?.cancel()
        debounceTask = nil
        pendingRoots = pendingRoots.intersection(Set(folders.map(\.location)))
        teardownStream()
        releaseSecurityScopedAccess()

        let accessibleFolders = folders.filter(startAccessIfNeeded)
        currentFolders = accessibleFolders.sorted { $0.location.displayName < $1.location.displayName }
        foldersByRootPath = Dictionary(uniqueKeysWithValues: currentFolders.map { ($0.standardizedRootPath, $0) })

        guard !currentFolders.isEmpty else {
            pendingRoots.removeAll()
            return
        }

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: Self.retainStreamContext,
            release: Self.releaseStreamContext,
            copyDescription: nil
        )

        guard let stream = dependencies.makeStream(
            currentFolders.map(\.standardizedRootPath),
            debounceInterval,
            Self.handleEvents,
            &context
        ) else {
            Log.warning("FileMonitorService: Failed to create FSEvent stream", category: .automation)
            pendingRoots.removeAll()
            releaseSecurityScopedAccess()
            return
        }

        stream.setDispatchQueue(eventDispatchQueue)
        guard stream.start() else {
            Log.warning("FileMonitorService: Failed to start FSEvent stream", category: .automation)
            stream.invalidate()
            pendingRoots.removeAll()
            releaseSecurityScopedAccess()
            return
        }

        self.stream = stream
        schedulePendingRootDelivery()
    }

    private func startAccessIfNeeded(for folder: WatchedFolderDescriptor) -> Bool {
        guard folder.bookmarkData != nil else { return true }
        guard dependencies.startSecurityScopedAccess(folder.rootURL) else {
            Log.warning("FileMonitorService: Failed to access watched root \(folder.standardizedRootPath)", category: .automation)
            return false
        }
        securityScopedURLs.append(folder.rootURL)
        return true
    }

    private func handleChangedPaths(_ changedPaths: [String]) {
        guard !changedPaths.isEmpty else { return }

        let changedRoots = Set(changedPaths.compactMap(rootLocation(forChangedPath:)))
        guard !changedRoots.isEmpty else { return }

        pendingRoots.formUnion(changedRoots)
        schedulePendingRootDelivery()
    }

    private func rootLocation(forChangedPath path: String) -> FolderLocation? {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        for (rootPath, folder) in foldersByRootPath {
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            if standardizedPath == rootPath || standardizedPath.hasPrefix(prefix) {
                return folder.location
            }
        }
        return nil
    }

    private static let handleEvents: FSEventStreamCallback = { _, info, eventCount, eventPaths, _, _ in
        guard let info else { return }
        let service = Unmanaged<FileMonitorService>.fromOpaque(info).takeUnretainedValue()
        let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
        let prefixCount = min(paths.count, Int(eventCount))
        Task { @MainActor in
            service.handleChangedPaths(Array(paths.prefix(prefixCount)))
        }
    }

    private func teardownStream() {
        stream?.stop()
        stream?.invalidate()
        stream = nil
    }

    private func releaseSecurityScopedAccess() {
        for url in securityScopedURLs {
            dependencies.stopSecurityScopedAccess(url)
        }
        securityScopedURLs.removeAll()
    }

    private func schedulePendingRootDelivery() {
        debounceTask?.cancel()
        guard !pendingRoots.isEmpty else { return }

        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }

            let watchedLocations = Set(currentFolders.map(\.location))
            let roots = pendingRoots.intersection(watchedLocations)
            pendingRoots.removeAll()
            guard !roots.isEmpty else { return }
            callback?(roots)
        }
    }
}
