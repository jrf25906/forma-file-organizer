import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class AutomationEngineRealtimeMonitoringTests: XCTestCase {

    private struct EngineHarness {
        let engine: AutomationEngine
        let container: ModelContainer
    }

    private final class MockNotificationService: AutomationNotificationServing {
        func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int) {}
        func notifyBacklogReminder(pendingCount: Int, oldestAgeDays: Int?) {}
        func notifyAutomationError(type: AutomationErrorType, message: String) {}
        func notifyFolderHealthAlert(folderType: BookmarkFolder.FolderType, currentBytes: Int64, thresholdBytes: Int64) {}
        func notifyStaleRulesAlert(ruleNames: [String], thresholdDays: Int) {}
        func clearFolderHealthAlert(folderType: BookmarkFolder.FolderType) {}
        func clearStaleRulesAlert() {}
    }

    private final class MockFileMonitor: FileMonitoring {
        private(set) var startCalls: [[WatchedFolderDescriptor]] = []
        private(set) var updateCalls: [[WatchedFolderDescriptor]] = []
        private(set) var stopCallCount = 0

        private var onChange: (@MainActor (Set<FolderLocation>) -> Void)?

        var isMonitoring: Bool {
            !startCalls.isEmpty && stopCallCount == 0
        }

        func startMonitoring(
            folders: [WatchedFolderDescriptor],
            onChange: @escaping @MainActor (Set<FolderLocation>) -> Void
        ) {
            startCalls.append(folders)
            self.onChange = onChange
        }

        func updateMonitoredFolders(_ folders: [WatchedFolderDescriptor]) {
            updateCalls.append(folders)
        }

        func stopMonitoring() {
            stopCallCount += 1
        }

        func emitChange(_ folders: Set<FolderLocation>) {
            onChange?(folders)
        }
    }

    private final class RecordingScanProvider: FileScanProvider {
        private(set) var requestedBaseFolders: [[FolderLocation]?] = []
        private(set) var getEligibleFilesCallCount = 0

        var scanResult = FileScanResult(
            totalScanned: 0,
            pendingCount: 0,
            readyCount: 0,
            organizedCount: 0,
            skippedCount: 0,
            oldestPendingAgeDays: nil,
            scannedRootPaths: []
        )

        var suspendFirstScan = false
        private let firstScanStarted = XCTestExpectation(description: "first scan started")
        private let secondScanStarted = XCTestExpectation(description: "second scan started")
        private var scanContinuation: CheckedContinuation<Void, Never>?

        func scanFiles(
            context: ModelContext,
            baseFolders: [FolderLocation]?
        ) async throws -> FileScanResult {
            requestedBaseFolders.append(baseFolders?.sorted { $0.displayName < $1.displayName })

            if requestedBaseFolders.count == 1 {
                firstScanStarted.fulfill()
                if suspendFirstScan {
                    await withCheckedContinuation { continuation in
                        scanContinuation = continuation
                    }
                }
            } else if requestedBaseFolders.count == 2 {
                secondScanStarted.fulfill()
            }

            return scanResult
        }

        func getAutoOrganizeEligibleFiles(
            context: ModelContext,
            confidenceThreshold: Double
        ) async throws -> [FileItem] {
            getEligibleFilesCallCount += 1
            return []
        }

        func waitForFirstScan(testCase: XCTestCase) async {
            await testCase.fulfillment(of: [firstScanStarted], timeout: 1.0)
        }

        func waitForSecondScan(testCase: XCTestCase) async {
            await testCase.fulfillment(of: [secondScanStarted], timeout: 1.0)
        }

        func resumeFirstScan() {
            scanContinuation?.resume()
            scanContinuation = nil
        }
    }

    func testStartBeginsWatchingConfiguredFolders() throws {
        let monitor = MockFileMonitor()
        let provider = RecordingScanProvider()
        let harness = try makeEngine(
            monitor: monitor,
            provider: provider,
            watchedFolders: [
                WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop")),
                WatchedFolderDescriptor(location: .downloads, rootURL: URL(fileURLWithPath: "/Users/test/Downloads"))
            ]
        )
        let engine = harness.engine

        engine.start()

        XCTAssertEqual(monitor.startCalls.count, 1)
        XCTAssertEqual(monitor.startCalls.first?.map(\.location), [.desktop, .downloads])
        XCTAssertTrue(engine.state.isWatchingFolders)
    }

    func testRealtimeChangeTriggersTargetedScan() async throws {
        let monitor = MockFileMonitor()
        let provider = RecordingScanProvider()
        let harness = try makeEngine(
            monitor: monitor,
            provider: provider,
            watchedFolders: [
                WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop")),
                WatchedFolderDescriptor(location: .downloads, rootURL: URL(fileURLWithPath: "/Users/test/Downloads"))
            ]
        )
        let engine = harness.engine
        engine.start()

        monitor.emitChange([.downloads, .desktop])
        await provider.waitForFirstScan(testCase: self)

        XCTAssertEqual(provider.requestedBaseFolders, [[.desktop, .downloads]])
    }

    func testRealtimeChangeQueuedDuringActiveScanRunsFollowUpRescan() async throws {
        let monitor = MockFileMonitor()
        let provider = RecordingScanProvider()
        provider.suspendFirstScan = true
        let harness = try makeEngine(
            monitor: monitor,
            provider: provider,
            watchedFolders: [
                WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop")),
                WatchedFolderDescriptor(location: .downloads, rootURL: URL(fileURLWithPath: "/Users/test/Downloads"))
            ],
            mode: .scanOnly
        )
        let engine = harness.engine
        engine.start()

        monitor.emitChange([.desktop])
        await provider.waitForFirstScan(testCase: self)

        monitor.emitChange([.downloads])
        XCTAssertEqual(provider.requestedBaseFolders.count, 1)

        provider.resumeFirstScan()
        await provider.waitForSecondScan(testCase: self)

        XCTAssertEqual(provider.requestedBaseFolders, [[.desktop], [.downloads]])
    }

    func testQueuedRealtimeRootsDroppedWhenFolderStopsBeingWatched() async throws {
        let monitor = MockFileMonitor()
        let provider = RecordingScanProvider()
        provider.suspendFirstScan = true
        let desktop = WatchedFolderDescriptor(location: .desktop, rootURL: URL(fileURLWithPath: "/Users/test/Desktop"))
        let downloads = WatchedFolderDescriptor(location: .downloads, rootURL: URL(fileURLWithPath: "/Users/test/Downloads"))
        var watchedFolders = [desktop, downloads]

        let harness = try makeEngine(
            monitor: monitor,
            provider: provider,
            watchedFoldersProvider: { watchedFolders },
            mode: .scanOnly
        )
        let engine = harness.engine
        engine.start()

        monitor.emitChange([.desktop])
        await provider.waitForFirstScan(testCase: self)

        monitor.emitChange([.downloads])
        XCTAssertEqual(provider.requestedBaseFolders.count, 1)

        watchedFolders = [desktop]
        engine.refreshPolicy()

        provider.resumeFirstScan()
        try? await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(provider.requestedBaseFolders, [[.desktop]])
        XCTAssertEqual(monitor.updateCalls.last?.map(\.location), [.desktop])
    }

    private func makeEngine(
        monitor: MockFileMonitor,
        provider: RecordingScanProvider,
        watchedFolders: [WatchedFolderDescriptor],
        mode: AutomationMode = .scanOnly
    ) throws -> EngineHarness {
        try makeEngine(
            monitor: monitor,
            provider: provider,
            watchedFoldersProvider: { watchedFolders },
            mode: mode
        )
    }

    private func makeEngine(
        monitor: MockFileMonitor,
        provider: RecordingScanProvider,
        watchedFoldersProvider: @escaping @MainActor () -> [WatchedFolderDescriptor],
        mode: AutomationMode = .scanOnly
    ) throws -> EngineHarness {
        let policy = AutomationPolicy(
            userMode: mode,
            effectiveMode: mode,
            scanIntervalMinutes: 30,
            scanOnLaunch: false,
            backlogThreshold: FormaConfig.Automation.backlogThreshold,
            ageThresholdDays: FormaConfig.Automation.ageThresholdDays,
            mlConfidenceThreshold: FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum,
            maxConsecutiveFailures: FormaConfig.Automation.maxConsecutiveFailures,
            notificationsEnabled: false,
            backlogReminderCooldownHours: FormaConfig.Automation.backlogReminderCooldownHours,
            errorNotificationCooldownMinutes: FormaConfig.Automation.errorNotificationCooldownMinutes
        )

        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let engine = AutomationEngine(
            notificationService: MockNotificationService(),
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            policyResolver: { policy },
            fileMonitor: monitor,
            watchedFoldersProvider: watchedFoldersProvider
        )
        engine.configure(
            modelContext: container.mainContext,
            organizationCoordinator: FileOrganizationCoordinator(),
            scanProvider: provider
        )
        return EngineHarness(engine: engine, container: container)
    }
}
