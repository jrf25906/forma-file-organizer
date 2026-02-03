import XCTest
@testable import Forma_File_Organizing

final class LoggingPolicyTests: XCTestCase {

    func testNoPrintCallsInServicesOrViewModels() throws {
        // Derive the project root from this test file's location or SRCROOT.
        let projectRoot: URL
        if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
            projectRoot = URL(fileURLWithPath: srcRoot)
        } else {
            let thisFileURL = URL(fileURLWithPath: #filePath)
            let testsDirectory = thisFileURL.deletingLastPathComponent()
            projectRoot = testsDirectory.deletingLastPathComponent()
        }
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

        func stripCommentsAndStrings(from source: String) -> String {
            var result = ""
            var i = source.startIndex
            var inSingleLineComment = false
            var inMultiLineComment = false
            var inString = false
            var inMultilineString = false
            var escape = false

            func advanceIndex(_ index: inout String.Index) {
                source.formIndex(after: &index)
            }

            while i < source.endIndex {
                let char = source[i]
                let next = source.index(after: i) < source.endIndex ? source[source.index(after: i)] : "\0"

                if inSingleLineComment {
                    if char == "\n" {
                        inSingleLineComment = false
                        result.append(char)
                    }
                    advanceIndex(&i)
                    continue
                }

                if inMultiLineComment {
                    if char == "*" && next == "/" {
                        inMultiLineComment = false
                        advanceIndex(&i)
                        advanceIndex(&i)
                        continue
                    }
                    advanceIndex(&i)
                    continue
                }

                if inMultilineString {
                    if char == "\"" && next == "\"" {
                        let thirdIndex = source.index(after: source.index(after: i))
                        if thirdIndex < source.endIndex && source[thirdIndex] == "\"" {
                            inMultilineString = false
                            advanceIndex(&i)
                            advanceIndex(&i)
                            advanceIndex(&i)
                            continue
                        }
                    }
                    advanceIndex(&i)
                    continue
                }

                if inString {
                    if escape {
                        escape = false
                        advanceIndex(&i)
                        continue
                    }
                    if char == "\\" {
                        escape = true
                        advanceIndex(&i)
                        continue
                    }
                    if char == "\"" {
                        inString = false
                    }
                    advanceIndex(&i)
                    continue
                }

                if char == "/" && next == "/" {
                    inSingleLineComment = true
                    advanceIndex(&i)
                    advanceIndex(&i)
                    continue
                }

                if char == "/" && next == "*" {
                    inMultiLineComment = true
                    advanceIndex(&i)
                    advanceIndex(&i)
                    continue
                }

                if char == "\"" && next == "\"" {
                    let thirdIndex = source.index(after: source.index(after: i))
                    if thirdIndex < source.endIndex && source[thirdIndex] == "\"" {
                        inMultilineString = true
                        advanceIndex(&i)
                        advanceIndex(&i)
                        advanceIndex(&i)
                        continue
                    }
                }

                if char == "\"" {
                    inString = true
                    advanceIndex(&i)
                    continue
                }

                result.append(char)
                advanceIndex(&i)
            }

            return result
        }

        for fileURL in filesToCheck {
            let contents = try String(contentsOf: fileURL)
            let sanitized = stripCommentsAndStrings(from: contents)
            if sanitized.contains("print(") {
                let relativePath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                XCTFail("Found forbidden 'print(' usage in \(relativePath). Use Log.debug/info/warning/error instead.")
            }
        }
    }
}
