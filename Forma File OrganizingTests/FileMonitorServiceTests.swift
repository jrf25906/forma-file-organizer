import XCTest
import CoreServices
@testable import Forma_File_Organizing

@MainActor
final class FileMonitorServiceTests: XCTestCase {

    private final class MockEventStream: FileMonitorService.EventStream {
        let startResult: Bool
        private(set) var dispatchQueueLabel: String?
        private(set) var stopped = false
        private(set) var invalidated = false

        init(startResult: Bool) {
            self.startResult = startResult
        }

        func setDispatchQueue(_ queue: DispatchQueue) {
            dispatchQueueLabel = queue.label
        }

        func start() -> Bool {
            startResult
        }

        func stop() {
            stopped = true
        }

        func invalidate() {
            invalidated = true
        }
    }

    func testCoalescesBurstyEventsIntoSingleChangeSetCallback() async throws {
        let service = FileMonitorService(debounceInterval: 0.05)
        let desktop = WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop"))
        let downloads = WatchedFolderDescriptor(location: .downloads, rootURL: URL(fileURLWithPath: "/Users/test/Downloads"))
        let changeExpectation = expectation(description: "coalesced change callback")

        var receivedChangeSets: [WatchedFolderChangeSet] = []
        service.startMonitoring(folders: [desktop, downloads]) { changeSet in
            receivedChangeSets.append(changeSet)
            changeExpectation.fulfill()
        }

        service._testEmitEvents([
            .init(path: "/Users/test/Desktop/a.txt", flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)),
            .init(path: "/Users/test/Downloads/b.txt", flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)),
            .init(path: "/Users/test/Desktop/nested/c.txt", flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod))
        ])

        await fulfillment(of: [changeExpectation], timeout: 1.0)
        let changeSet = try XCTUnwrap(receivedChangeSets.first)
        XCTAssertEqual(changeSet.touchedRoots, [desktop.standardizedRootPath, downloads.standardizedRootPath])
        XCTAssertEqual(
            changeSet.updatedPaths,
            [
                "/Users/test/Desktop/a.txt",
                "/Users/test/Desktop/nested/c.txt",
                "/Users/test/Downloads/b.txt"
            ]
        )
        XCTAssertTrue(changeSet.removedPaths.isEmpty)
        XCTAssertFalse(changeSet.requiresFallbackRootScan)
    }

    func testIgnoresPathsOutsideWatchedRoots() async {
        let service = FileMonitorService(debounceInterval: 0.05)
        let desktop = WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop"))

        service.startMonitoring(folders: [desktop]) { _ in
            XCTFail("Unexpected callback for non-watched path")
        }

        service._testEmitEvents([
            .init(path: "/Users/test/Documents/ignore.txt", flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated))
        ])
        try? await Task.sleep(for: .milliseconds(120))
    }

    func testRebuildCancelsPendingDebounceForRemovedRoots() async {
        let service = FileMonitorService(debounceInterval: 0.05)
        let desktop = WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop"))
        let downloads = WatchedFolderDescriptor(location: .downloads, rootURL: URL(fileURLWithPath: "/Users/test/Downloads"))
        let staleCallback = expectation(description: "no stale callback")
        staleCallback.isInverted = true

        service.startMonitoring(folders: [desktop, downloads]) { changeSet in
            if changeSet.touchedRoots.contains(desktop.standardizedRootPath) {
                staleCallback.fulfill()
            }
        }

        service._testEmitEvents([
            .init(path: "/Users/test/Desktop/a.txt", flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated))
        ])
        service.updateMonitoredFolders([downloads])

        await fulfillment(of: [staleCallback], timeout: 0.15)
    }

    func testDeleteEventsPopulateRemovedPaths() async {
        let service = FileMonitorService(debounceInterval: 0.05)
        let desktop = WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop"))
        let changeExpectation = expectation(description: "removed change callback")

        var receivedChangeSet: WatchedFolderChangeSet?
        service.startMonitoring(folders: [desktop]) { changeSet in
            receivedChangeSet = changeSet
            changeExpectation.fulfill()
        }

        service._testEmitEvents([
            .init(path: "/Users/test/Desktop/deleted.txt", flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved))
        ])

        await fulfillment(of: [changeExpectation], timeout: 1.0)
        XCTAssertEqual(receivedChangeSet?.updatedPaths, [])
        XCTAssertEqual(receivedChangeSet?.removedPaths, ["/Users/test/Desktop/deleted.txt"])
        XCTAssertFalse(receivedChangeSet?.requiresFallbackRootScan ?? true)
    }

    func testAmbiguousDirectoryEventsRequestFallbackRootScan() async {
        let service = FileMonitorService(debounceInterval: 0.05)
        let desktop = WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop"))
        let changeExpectation = expectation(description: "fallback change callback")

        var receivedChangeSet: WatchedFolderChangeSet?
        service.startMonitoring(folders: [desktop]) { changeSet in
            receivedChangeSet = changeSet
            changeExpectation.fulfill()
        }

        service._testEmitEvents([
            .init(
                path: "/Users/test/Desktop/Subfolder",
                flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemIsDir)
            )
        ])

        await fulfillment(of: [changeExpectation], timeout: 1.0)
        XCTAssertEqual(receivedChangeSet?.touchedRoots, [desktop.standardizedRootPath])
        XCTAssertTrue(receivedChangeSet?.updatedPaths.isEmpty ?? false)
        XCTAssertTrue(receivedChangeSet?.removedPaths.isEmpty ?? false)
        XCTAssertTrue(receivedChangeSet?.requiresFallbackRootScan ?? false)
    }

    func testCreateStreamFailureReleasesSecurityScopedAccess() {
        let rootURL = URL(fileURLWithPath: "/Users/test/Desktop")
        let desktop = WatchedFolderDescriptor(
            location: .desktop,
            rootURL: rootURL,
            bookmarkData: Data([0x01])
        )
        var started: [URL] = []
        var stopped: [URL] = []

        let service = FileMonitorService(
            debounceInterval: 0.05,
            dependencies: .init(
                makeStream: { _, _, _, _ in nil },
                startSecurityScopedAccess: { url in
                    started.append(url)
                    return true
                },
                stopSecurityScopedAccess: { url in
                    stopped.append(url)
                }
            )
        )

        service.startMonitoring(folders: [desktop]) { _ in }

        XCTAssertEqual(started, [rootURL.standardizedFileURL])
        XCTAssertEqual(stopped, [rootURL.standardizedFileURL])
        XCTAssertFalse(service.isMonitoring)
    }

    func testStartStreamFailureReleasesSecurityScopedAccess() {
        let rootURL = URL(fileURLWithPath: "/Users/test/Desktop")
        let desktop = WatchedFolderDescriptor(
            location: .desktop,
            rootURL: rootURL,
            bookmarkData: Data([0x01])
        )
        var started: [URL] = []
        var stopped: [URL] = []
        let stream = MockEventStream(startResult: false)

        let service = FileMonitorService(
            debounceInterval: 0.05,
            dependencies: .init(
                makeStream: { _, _, _, _ in stream },
                startSecurityScopedAccess: { url in
                    started.append(url)
                    return true
                },
                stopSecurityScopedAccess: { url in
                    stopped.append(url)
                }
            )
        )

        service.startMonitoring(folders: [desktop]) { _ in }

        XCTAssertEqual(stream.dispatchQueueLabel, "com.forma.file-monitor")
        XCTAssertTrue(stream.invalidated)
        XCTAssertEqual(started, [rootURL.standardizedFileURL])
        XCTAssertEqual(stopped, [rootURL.standardizedFileURL])
        XCTAssertFalse(service.isMonitoring)
    }

    func testStreamContextRetainsServiceUntilRelease() {
        let desktop = WatchedFolderDescriptor(
            location: .desktop,
            rootURL: URL(fileURLWithPath: "/Users/test/Desktop")
        )
        let stream = MockEventStream(startResult: true)
        var capturedContext: FSEventStreamContext?

        var service: FileMonitorService? = FileMonitorService(
            debounceInterval: 0.05,
            dependencies: .init(
                makeStream: { _, _, _, context in
                    capturedContext = context.pointee
                    return stream
                },
                startSecurityScopedAccess: { _ in true },
                stopSecurityScopedAccess: { _ in }
            )
        )
        weak var weakService = service

        service?.startMonitoring(folders: [desktop]) { _ in }

        guard let context = capturedContext else {
            return XCTFail("Expected stream context")
        }
        guard let info = context.info else {
            return XCTFail("Expected context info")
        }
        guard let retainedInfo = context.retain?(info) else {
            return XCTFail("Expected retain callback to keep the service alive")
        }

        service = nil
        XCTAssertNotNil(weakService)

        context.release?(retainedInfo)
        XCTAssertNil(weakService)
    }
}
