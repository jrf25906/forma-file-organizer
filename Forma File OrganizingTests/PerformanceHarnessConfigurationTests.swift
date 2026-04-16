import XCTest
@testable import Forma_File_Organizing

final class PerformanceHarnessConfigurationTests: XCTestCase {

    func testIsEnabledReturnsTrueWhenFlagPresent() {
        let isEnabled = PerformanceHarnessConfiguration.isEnabled(
            arguments: ["Forma", "--perf-signpost-harness"],
            environment: [:]
        )

        XCTAssertTrue(isEnabled)
    }

    func testIsEnabledReturnsTrueWhenEnvironmentRequestsHarness() {
        let isEnabled = PerformanceHarnessConfiguration.isEnabled(
            arguments: ["Forma"],
            environment: ["FORMA_PERF_SIGNPOST_HARNESS": "1"]
        )

        XCTAssertTrue(isEnabled)
    }

    func testEventsFilePrefersFlagOverEnvironment() {
        let path = PerformanceHarnessConfiguration.eventsFilePath(
            arguments: ["Forma", "--perf-harness-events-file", "/tmp/flag.jsonl"],
            environment: ["FORMA_PERF_HARNESS_EVENTS_FILE": "/tmp/env.jsonl"]
        )

        XCTAssertEqual(path, "/tmp/flag.jsonl")
    }
}
