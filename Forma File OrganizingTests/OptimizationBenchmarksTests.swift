import XCTest
import Foundation
import CryptoKit
@testable import Forma_File_Organizing

@MainActor
final class OptimizationBenchmarksTests: XCTestCase {

    private struct BenchmarkResult {
        let name: String
        let baselineMs: Double
        let optimizedMs: Double

        var speedup: Double {
            guard optimizedMs > 0 else { return 0 }
            return baselineMs / optimizedMs
        }
    }

    func testCaptureOptimizationBenchmarks() throws {
        let searchResult = benchmarkSearchLookupPath()
        let scanResult = try benchmarkDirectoryScanPath()
        let duplicateResult = try benchmarkDuplicateDetectionPath()

        let results = [searchResult, scanResult, duplicateResult]
        for result in results {
            print(
                String(
                    format: "BENCHMARK|%@|baseline_ms=%.2f|optimized_ms=%.2f|speedup=%.2fx",
                    result.name,
                    result.baselineMs,
                    result.optimizedMs,
                    result.speedup
                )
            )
        }

        for result in results {
            XCTAssertGreaterThan(result.baselineMs, 0)
            XCTAssertGreaterThan(result.optimizedMs, 0)
        }
    }

    // MARK: - Search Lookup Benchmark

    private func benchmarkSearchLookupPath() -> BenchmarkResult {
        let totalVisibleCount = 20_000
        let totalMatchedCount = 4_000

        let visiblePaths = (0..<totalVisibleCount).map { "/Users/test/Documents/file-\($0).txt" }
        let matchedPaths = (0..<totalMatchedCount).map { "/Users/test/Documents/file-\($0 * 3).txt" }
        let matchedPathSet = Set(matchedPaths)

        let baselineMs = measureAverageMs(iterations: 12) {
            var hitCount = 0
            for path in visiblePaths {
                if matchedPaths.first(where: { $0 == path }) != nil {
                    hitCount += 1
                }
            }
            XCTAssertGreaterThan(hitCount, 0)
        }

        let optimizedMs = measureAverageMs(iterations: 12) {
            var hitCount = 0
            for path in visiblePaths {
                if matchedPathSet.contains(path) {
                    hitCount += 1
                }
            }
            XCTAssertGreaterThan(hitCount, 0)
        }

        return BenchmarkResult(
            name: "search_lookup_linear_vs_indexed",
            baselineMs: baselineMs,
            optimizedMs: optimizedMs
        )
    }

    // MARK: - Directory Scan Benchmark

    private func benchmarkDirectoryScanPath() throws -> BenchmarkResult {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let fileCount = 3_000
        for index in 0..<fileCount {
            _ = try tempDir.createFile(
                name: "scan-\(index).txt",
                size: 1_024,
                creationDate: Date(),
                modificationDate: Date()
            )
        }

        // Warm-up to reduce first-run skew.
        _ = try baselineDirectoryScan(at: tempDir.url)
        _ = try optimizedDirectoryScan(at: tempDir.url)

        let baselineMs = try measureAverageMs(iterations: 6) {
            let count = try baselineDirectoryScan(at: tempDir.url)
            XCTAssertEqual(count, fileCount)
        }

        let optimizedMs = try measureAverageMs(iterations: 6) {
            let count = try optimizedDirectoryScan(at: tempDir.url)
            XCTAssertEqual(count, fileCount)
        }

        return BenchmarkResult(
            name: "scan_syscalls_baseline_vs_prefetch",
            baselineMs: baselineMs,
            optimizedMs: optimizedMs
        )
    }

    private func baselineDirectoryScan(at directory: URL) throws -> Int {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var fileCount = 0
        for fileURL in contents {
            let flags = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if flags.isDirectory == true || flags.isSymbolicLink == true {
                continue
            }

            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            _ = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            _ = attributes[.creationDate] as? Date ?? Date()
            _ = attributes[.modificationDate] as? Date ?? Date()
            _ = (try? fileURL.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date()

            fileCount += 1
        }

        return fileCount
    }

    private func optimizedDirectoryScan(at directory: URL) throws -> Int {
        let fileManager = FileManager.default
        let prefetchedKeys: [URLResourceKey] = [
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
            .isDirectoryKey,
            .isSymbolicLinkKey
        ]
        let keySet = Set(prefetchedKeys)

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: prefetchedKeys,
            options: [.skipsHiddenFiles]
        )

        var fileCount = 0
        for fileURL in contents {
            let values = try fileURL.resourceValues(forKeys: keySet)
            if values.isDirectory == true || values.isSymbolicLink == true {
                continue
            }

            _ = Int64(values.fileSize ?? 0)
            _ = values.creationDate ?? Date()
            _ = values.contentModificationDate ?? Date()
            _ = values.contentAccessDate ?? Date()

            fileCount += 1
        }

        return fileCount
    }

    // MARK: - Duplicate Detection Benchmark

    private func benchmarkDuplicateDetectionPath() throws -> BenchmarkResult {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let files = try makeDuplicateBenchmarkFiles(in: tempDir)
        XCTAssertGreaterThan(files.count, 300)

        let service = DuplicateDetectionService()
        _ = service.detectDuplicates(in: files) // warm-up
        _ = baselineDetectDuplicates(in: files) // warm-up

        let baselineMs = measureAverageMs(iterations: 4) {
            let groups = baselineDetectDuplicates(in: files)
            XCTAssertFalse(groups.isEmpty)
        }

        let optimizedMs = measureAverageMs(iterations: 4) {
            let groups = service.detectDuplicates(in: files)
            XCTAssertFalse(groups.isEmpty)
        }

        return BenchmarkResult(
            name: "duplicate_detection_legacy_vs_optimized",
            baselineMs: baselineMs,
            optimizedMs: optimizedMs
        )
    }

    private func makeDuplicateBenchmarkFiles(in tempDir: TemporaryDirectory) throws -> [FileItem] {
        var fileItems: [FileItem] = []
        let now = Date()
        let fileManager = FileManager.default

        // Exact duplicates: same content across pairs.
        for index in 0..<60 {
            let sharedPayload = String(repeating: Character(UnicodeScalar(65 + (index % 26))!), count: 2_048)
            let fileA = try tempDir.createFile(name: "dup-\(index)-a.txt", contents: sharedPayload)
            let fileB = try tempDir.createFile(name: "dup-\(index)-b.txt", contents: sharedPayload)
            for url in [fileA, fileB] {
                let attrs = try fileManager.attributesOfItem(atPath: url.path)
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? 2_048
                let mod = attrs[.modificationDate] as? Date ?? now
                fileItems.append(FileItem(path: url.path, sizeInBytes: size, creationDate: now, modificationDate: mod, lastAccessedDate: now))
            }
        }

        // Version series groups.
        for index in 0..<70 {
            for version in 1...3 {
                let name = "project-\(index)_v\(version).txt"
                let payload = String(repeating: "project\(index)-v\(version)-", count: 80)
                let url = try tempDir.createFile(name: name, contents: payload)
                let attrs = try fileManager.attributesOfItem(atPath: url.path)
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? 2_000
                let mod = attrs[.modificationDate] as? Date ?? now
                fileItems.append(FileItem(path: url.path, sizeInBytes: size, creationDate: now, modificationDate: mod, lastAccessedDate: now))
            }
        }

        // Near duplicate names.
        for index in 0..<80 {
            let first = try tempDir.createFile(name: "meeting-notes-\(index).txt", contents: String(repeating: "notes-\(index)-", count: 90))
            let second = try tempDir.createFile(name: "meeting-note-\(index).txt", contents: String(repeating: "note-\(index)-", count: 90))

            for url in [first, second] {
                let attrs = try fileManager.attributesOfItem(atPath: url.path)
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? 2_000
                let mod = attrs[.modificationDate] as? Date ?? now
                fileItems.append(FileItem(path: url.path, sizeInBytes: size, creationDate: now, modificationDate: mod, lastAccessedDate: now))
            }
        }

        return fileItems
    }

    private func baselineDetectDuplicates(in files: [FileItem]) -> [Set<String>] {
        let minimumFileSize: Int64 = 1_024
        let threshold: Double = 0.85
        let relevantFiles = Array(files.filter { $0.sizeInBytes >= minimumFileSize }.prefix(5_000))

        var groups: [Set<String>] = []

        // Exact duplicates (size -> full hash with full-file reads).
        let sizeGroups = Dictionary(grouping: relevantFiles) { $0.sizeInBytes }
        for (_, sameSize) in sizeGroups where sameSize.count >= 2 {
            var hashGroups: [String: [FileItem]] = [:]
            for file in sameSize {
                guard let data = FileManager.default.contents(atPath: file.path) else { continue }
                let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                hashGroups[hash, default: []].append(file)
            }
            for (_, equalHashFiles) in hashGroups where equalHashFiles.count >= 2 {
                groups.append(Set(equalHashFiles.map(\.path)))
            }
        }

        // Version series with per-call regex compilation.
        let extensionGroups = Dictionary(grouping: relevantFiles) { $0.fileExtension }
        for (_, filesWithExt) in extensionGroups where filesWithExt.count >= 2 {
            var baseNameGroups: [String: [FileItem]] = [:]
            for file in filesWithExt {
                let basename = (file.name as NSString).deletingPathExtension
                let patterns = [
                    #"[\s_-]*v?\d+$"#,
                    #"[\s_-]*\(\d+\)$"#,
                    #"[\s_-]*copy[\s_-]*\d*$"#,
                    #"[\s_-]*\d{4}[-_]\d{2}[-_]\d{2}$"#,
                    #"[\s_-]*(draft|final|v\d+|rev\d*)$"#
                ]
                var stripped = basename
                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                        let range = NSRange(stripped.startIndex..., in: stripped)
                        stripped = regex.stringByReplacingMatches(in: stripped, range: range, withTemplate: "")
                    }
                }
                let key = stripped.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !key.isEmpty {
                    baseNameGroups[key, default: []].append(file)
                }
            }
            for (_, versionFiles) in baseNameGroups where versionFiles.count >= 2 {
                groups.append(Set(versionFiles.map(\.path)))
            }
        }

        // Near duplicates with full pairwise comparison.
        var processed: Set<String> = []
        for (_, filesWithExt) in extensionGroups where filesWithExt.count >= 2 {
            for i in 0..<filesWithExt.count {
                guard !processed.contains(filesWithExt[i].path) else { continue }
                let name1 = (filesWithExt[i].name as NSString).deletingPathExtension.lowercased()
                var cluster: [FileItem] = [filesWithExt[i]]
                for j in (i + 1)..<filesWithExt.count {
                    guard !processed.contains(filesWithExt[j].path) else { continue }
                    let name2 = (filesWithExt[j].name as NSString).deletingPathExtension.lowercased()
                    if nameSimilarityLegacy(name1, name2) >= threshold {
                        cluster.append(filesWithExt[j])
                    }
                }
                if cluster.count >= 2 {
                    cluster.forEach { processed.insert($0.path) }
                    groups.append(Set(cluster.map(\.path)))
                }
            }
        }

        return groups
    }

    private func nameSimilarityLegacy(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1.0 }
        if lhs.isEmpty || rhs.isEmpty { return 0.0 }

        let a = Array(lhs)
        let b = Array(rhs)
        let n = a.count
        let m = b.count
        if n == 0 { return 0.0 }
        if m == 0 { return 0.0 }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { matrix[i][0] = i }
        for j in 0...m { matrix[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                matrix[i][j] = min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost)
            }
        }

        let distance = matrix[n][m]
        let maxLen = max(n, m)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    // MARK: - Timing Helpers

    private func measureAverageMs(iterations: Int, _ block: () throws -> Void) rethrows -> Double {
        precondition(iterations > 0, "iterations must be > 0")
        var samples: [Double] = []
        samples.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            try block()
            let end = DispatchTime.now().uptimeNanoseconds
            let elapsedMs = Double(end - start) / 1_000_000.0
            samples.append(elapsedMs)
        }

        return samples.reduce(0, +) / Double(samples.count)
    }
}
