import XCTest
@testable import Forma_File_Organizing

final class LoggingPolicyTests: XCTestCase {

    func testNoPrintCallsInServicesOrViewModels() throws {
        // Derive the project root from this test file's location.
        let thisFileURL = URL(fileURLWithPath: #file)
        let testsDirectory = thisFileURL.deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        let appRoot = projectRoot.appendingPathComponent("Forma File Organizing")

        let servicesDir = appRoot.appendingPathComponent("Services")
        let viewModelsDir = appRoot.appendingPathComponent("ViewModels")

        let fileManager = FileManager.default

        func assertDirectoryExists(_ url: URL, name: String) {
            var isDir: ObjCBool = false
            XCTAssertTrue(
                fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue,
                "\(name) directory not found at expected path: \(url.path)"
            )
        }

        assertDirectoryExists(servicesDir, name: "Services")
        assertDirectoryExists(viewModelsDir, name: "ViewModels")

        func swiftFiles(in directory: URL) -> [URL] {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            var result: [URL] = []
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "swift" {
                    result.append(fileURL)
                }
            }
            return result
        }

        let filesToCheck = swiftFiles(in: servicesDir) + swiftFiles(in: viewModelsDir)
        XCTAssertFalse(filesToCheck.isEmpty, "No Swift files found in Services/ViewModels; check paths in LoggingPolicyTests.")

        for fileURL in filesToCheck {
            let contents = try String(contentsOf: fileURL)
            if contents.contains("print(") {
                let relativePath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                XCTFail("Found forbidden 'print(' usage in \(relativePath). Use Log.debug/info/warning/error instead.")
            }
        }
    }
}
