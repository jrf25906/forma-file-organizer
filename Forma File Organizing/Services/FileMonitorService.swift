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

struct WatchedFolderChangeSet: Equatable, Sendable {
    var touchedRoots: Set<String>
    var updatedPaths: Set<String>
    var removedPaths: Set<String>
    var requiresFallbackRootScan: Bool

    init(
        touchedRoots: Set<String> = [],
        updatedPaths: Set<String> = [],
        removedPaths: Set<String> = [],
        requiresFallbackRootScan: Bool = false
    ) {
        self.touchedRoots = touchedRoots
        self.updatedPaths = updatedPaths
        self.removedPaths = removedPaths
        self.requiresFallbackRootScan = requiresFallbackRootScan
    }

    static let empty = WatchedFolderChangeSet()

    var isEmpty: Bool {
        touchedRoots.isEmpty && updatedPaths.isEmpty && removedPaths.isEmpty && !requiresFallbackRootScan
    }

    var uniqueAffectedPathCount: Int {
        updatedPaths.union(removedPaths).count
    }

    mutating func recordUpdatedPath(_ path: String) {
        updatedPaths.insert(path)
        removedPaths.remove(path)
    }

    mutating func recordRemovedPath(_ path: String) {
        removedPaths.insert(path)
        updatedPaths.remove(path)
    }

    mutating func formUnion(_ other: WatchedFolderChangeSet) {
        touchedRoots.formUnion(other.touchedRoots)
        requiresFallbackRootScan = requiresFallbackRootScan || other.requiresFallbackRootScan

        for path in other.updatedPaths {
            recordUpdatedPath(path)
        }

        for path in other.removedPaths {
            recordRemovedPath(path)
        }
    }

    func filtered(to allowedRootPaths: Set<String>) -> WatchedFolderChangeSet {
        let allowedRoots = touchedRoots.intersection(allowedRootPaths)
        guard !allowedRoots.isEmpty else { return .empty }

        func belongsToAllowedRoot(_ path: String) -> Bool {
            let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
            return allowedRoots.contains { rootPath in
                let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
                return standardizedPath == rootPath || standardizedPath.hasPrefix(prefix)
            }
        }

        return WatchedFolderChangeSet(
            touchedRoots: allowedRoots,
            updatedPaths: Set(updatedPaths.filter(belongsToAllowedRoot)),
            removedPaths: Set(removedPaths.filter(belongsToAllowedRoot)),
            requiresFallbackRootScan: requiresFallbackRootScan
        )
    }
}

struct WatchedFolderFileEvent: Equatable, Sendable {
    let path: String
    let flags: FSEventStreamEventFlags
}

@MainActor
protocol FileMonitoring: AnyObject {
    var isMonitoring: Bool { get }

    func startMonitoring(
        folders: [WatchedFolderDescriptor],
        onChange: @escaping @MainActor (WatchedFolderChangeSet) -> Void
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
    private var callback: (@MainActor (WatchedFolderChangeSet) -> Void)?
    private var stream: EventStream?
    private var securityScopedURLs: [URL] = []
    private var pendingChangeSet: WatchedFolderChangeSet = .empty
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
        onChange: @escaping @MainActor (WatchedFolderChangeSet) -> Void
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
        pendingChangeSet = .empty
        currentFolders = []
        foldersByRootPath = [:]
        callback = nil

        teardownStream()
        releaseSecurityScopedAccess()
    }

    #if DEBUG
    func _testEmitChangedPaths(_ changedPaths: [String]) {
        handleChangedEvents(
            changedPaths.map {
                WatchedFolderFileEvent(
                    path: $0,
                    flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)
                )
            }
        )
    }

    func _testEmitEvents(_ events: [WatchedFolderFileEvent]) {
        handleChangedEvents(events)
    }
    #endif

    private func rebuildStream(with folders: [WatchedFolderDescriptor]) {
        debounceTask?.cancel()
        debounceTask = nil
        pendingChangeSet = pendingChangeSet.filtered(
            to: Set(folders.map(\.standardizedRootPath))
        )
        teardownStream()
        releaseSecurityScopedAccess()

        let accessibleFolders = folders.filter(startAccessIfNeeded)
        currentFolders = accessibleFolders.sorted { $0.location.displayName < $1.location.displayName }
        foldersByRootPath = Dictionary(uniqueKeysWithValues: currentFolders.map { ($0.standardizedRootPath, $0) })

        guard !currentFolders.isEmpty else {
            pendingChangeSet = .empty
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
            pendingChangeSet = .empty
            releaseSecurityScopedAccess()
            return
        }

        stream.setDispatchQueue(eventDispatchQueue)
        guard stream.start() else {
            Log.warning("FileMonitorService: Failed to start FSEvent stream", category: .automation)
            stream.invalidate()
            pendingChangeSet = .empty
            releaseSecurityScopedAccess()
            return
        }

        self.stream = stream
        schedulePendingChangeDelivery()
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

    private func handleChangedEvents(_ events: [WatchedFolderFileEvent]) {
        guard !events.isEmpty else { return }

        var coalescedChanges = WatchedFolderChangeSet()
        for event in events {
            let standardizedPath = URL(fileURLWithPath: event.path).standardizedFileURL.path
            guard let folder = rootDescriptor(forChangedPath: standardizedPath) else { continue }

            coalescedChanges.touchedRoots.insert(folder.standardizedRootPath)
            if requiresFallbackRootScan(
                flags: event.flags,
                standardizedPath: standardizedPath,
                rootPath: folder.standardizedRootPath
            ) {
                coalescedChanges.requiresFallbackRootScan = true
                continue
            }

            if classifiesAsRemoved(flags: event.flags) {
                coalescedChanges.recordRemovedPath(standardizedPath)
            } else if classifiesAsUpdated(flags: event.flags) {
                coalescedChanges.recordUpdatedPath(standardizedPath)
            } else {
                coalescedChanges.requiresFallbackRootScan = true
            }
        }

        guard !coalescedChanges.isEmpty else { return }
        pendingChangeSet.formUnion(coalescedChanges)
        schedulePendingChangeDelivery()
    }

    private func rootDescriptor(forChangedPath path: String) -> WatchedFolderDescriptor? {
        for (rootPath, folder) in foldersByRootPath {
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            if path == rootPath || path.hasPrefix(prefix) {
                return folder
            }
        }
        return nil
    }

    private func requiresFallbackRootScan(
        flags: FSEventStreamEventFlags,
        standardizedPath: String,
        rootPath: String
    ) -> Bool {
        if standardizedPath == rootPath {
            return true
        }

        let fallbackFlags = FSEventStreamEventFlags(
            kFSEventStreamEventFlagMustScanSubDirs |
            kFSEventStreamEventFlagUserDropped |
            kFSEventStreamEventFlagKernelDropped |
            kFSEventStreamEventFlagRootChanged |
            kFSEventStreamEventFlagEventIdsWrapped |
            kFSEventStreamEventFlagItemRenamed |
            kFSEventStreamEventFlagItemIsDir
        )

        return (flags & fallbackFlags) != 0
    }

    private func classifiesAsUpdated(flags: FSEventStreamEventFlags) -> Bool {
        let updateFlags = FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemCreated |
            kFSEventStreamEventFlagItemModified |
            kFSEventStreamEventFlagItemInodeMetaMod |
            kFSEventStreamEventFlagItemFinderInfoMod |
            kFSEventStreamEventFlagItemChangeOwner |
            kFSEventStreamEventFlagItemXattrMod
        )
        return (flags & updateFlags) != 0
    }

    private func classifiesAsRemoved(flags: FSEventStreamEventFlags) -> Bool {
        (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
    }

    private static let handleEvents: FSEventStreamCallback = { _, info, eventCount, eventPaths, eventFlags, _ in
        guard let info else { return }
        let service = Unmanaged<FileMonitorService>.fromOpaque(info).takeUnretainedValue()
        let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
        let prefixCount = min(paths.count, Int(eventCount))
        let events = zip(
            Array(paths.prefix(prefixCount)),
            UnsafeBufferPointer(start: eventFlags, count: prefixCount)
        ).map { path, flags in
            WatchedFolderFileEvent(path: path, flags: flags)
        }
        Task { @MainActor in
            service.handleChangedEvents(events)
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

    private func schedulePendingChangeDelivery() {
        debounceTask?.cancel()
        guard !pendingChangeSet.isEmpty else { return }

        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }

            let changeSet = pendingChangeSet.filtered(
                to: Set(currentFolders.map(\.standardizedRootPath))
            )
            pendingChangeSet = .empty
            guard !changeSet.isEmpty else { return }
            callback?(changeSet)
        }
    }
}
