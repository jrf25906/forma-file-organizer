import XCTest
@testable import Forma_File_Organizing

/// Security tests for symlink attack prevention
/// Tests both scanning and file operation layers for symlink handling
///
/// NOTE: These tests use POSIX APIs directly to test low-level security behavior.
/// They don't require the full FileSystemService or FileOperationsService.
final class SymlinkSecurityTests: XCTestCase {

    var testDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FormaSymlinkTests_\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    override func tearDownWithError() throws {
        // Clean up test directory
        if let testDir = testDirectory {
            try? FileManager.default.removeItem(at: testDir)
        }

        testDirectory = nil

        try super.tearDownWithError()
    }

    // MARK: - Layer 1: Scanning Tests

    /// Test that symlinks are detected and skipped during directory scanning
    func testSymlinkDetectionDuringScan() throws {
        // Create a regular file
        let regularFile = testDirectory.appendingPathComponent("regular.txt")
        try "Regular content".write(to: regularFile, atomically: true, encoding: .utf8)

        // Create a target file for symlink
        let targetFile = testDirectory.appendingPathComponent("target.txt")
        try "Target content".write(to: targetFile, atomically: true, encoding: .utf8)

        // Create symlink to target file
        let symlink = testDirectory.appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: targetFile
        )

        // Verify symlink was created
        let symlinkAttributes = try FileManager.default.attributesOfItem(atPath: symlink.path)
        XCTAssertEqual(
            symlinkAttributes[.type] as? FileAttributeType,
            .typeSymbolicLink,
            "Symlink should be created"
        )

        // Scan directory - should only find regular file, not symlink
        let files = try FileManager.default.contentsOfDirectory(
            at: testDirectory,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        // Manually filter as FileSystemService would do
        var regularFiles: [URL] = []
        for fileURL in files {
            let resourceValues = try fileURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey
            ])

            if resourceValues.isDirectory == false && resourceValues.isSymbolicLink == false {
                regularFiles.append(fileURL)
            }
        }

        // Assertions
        XCTAssertEqual(regularFiles.count, 2, "Should find 2 regular files (regular.txt and target.txt)")
        XCTAssertTrue(
            regularFiles.contains(where: { $0.lastPathComponent == "regular.txt" }),
            "Should include regular file"
        )
        XCTAssertTrue(
            regularFiles.contains(where: { $0.lastPathComponent == "target.txt" }),
            "Should include target file"
        )
        XCTAssertFalse(
            regularFiles.contains(where: { $0.lastPathComponent == "symlink.txt" }),
            "Should NOT include symlink"
        )
    }

    /// Test that symlinks pointing outside home directory are detected
    func testSymlinkOutsideHomeDirDetected() throws {
        // Create symlink to system file
        let systemSymlink = testDirectory.appendingPathComponent("etc_passwd.txt")
        try FileManager.default.createSymbolicLink(
            at: systemSymlink,
            withDestinationURL: URL(fileURLWithPath: "/etc/passwd")
        )

        // Verify symlink properties
        let resourceValues = try systemSymlink.resourceValues(forKeys: [.isSymbolicLinkKey])
        XCTAssertTrue(resourceValues.isSymbolicLink == true, "Should be a symlink")

        // Resolve symlink and verify it escapes home directory
        let resolvedURL = systemSymlink.resolvingSymlinksInPath()
        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        XCTAssertFalse(
            resolvedURL.path.hasPrefix(homeDir.path),
            "Symlink should point outside home directory"
        )
        XCTAssertEqual(
            resolvedURL.path,
            "/etc/passwd",
            "Symlink should resolve to /etc/passwd"
        )
    }

    // MARK: - Layer 2: File Operations Tests

    /// Test that O_NOFOLLOW prevents symlink following during file operations
    func testSecureValidateFileRejectsSymlinks() throws {
        // Create target file
        let targetFile = testDirectory.appendingPathComponent("target.pdf")
        try "PDF content".write(to: targetFile, atomically: true, encoding: .utf8)

        // Create symlink
        let symlink = testDirectory.appendingPathComponent("invoice.pdf")
        try FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: targetFile
        )

        // Test using POSIX API directly (simulating secureValidateFile behavior)
        let fd = open(symlink.path, O_RDONLY | O_NOFOLLOW)

        if fd >= 0 {
            close(fd)
            XCTFail("O_NOFOLLOW should reject symlinks (errno should be ELOOP)")
        } else {
            let err = errno
            XCTAssertEqual(err, ELOOP, "Should return ELOOP when O_NOFOLLOW encounters symlink")
        }
    }

    /// Test that regular files pass validation
    func testSecureValidateFileAcceptsRegularFiles() throws {
        // Create regular file
        let regularFile = testDirectory.appendingPathComponent("document.pdf")
        try "Document content".write(to: regularFile, atomically: true, encoding: .utf8)

        // Test using POSIX API (simulating secureValidateFile behavior)
        let fd = open(regularFile.path, O_RDONLY | O_NOFOLLOW)

        XCTAssertTrue(fd >= 0, "Should successfully open regular file")

        if fd >= 0 {
            // Verify it's a regular file
            var fileStat = stat()
            XCTAssertEqual(fstat(fd, &fileStat), 0, "fstat should succeed")

            let fileType = fileStat.st_mode & S_IFMT
            XCTAssertEqual(fileType, S_IFREG, "Should be a regular file (S_IFREG)")

            close(fd)
        }
    }

    /// Test that hard links are treated as regular files (safe to move)
    func testHardLinksAreTreatedAsRegularFiles() throws {
        // Create original file
        let originalFile = testDirectory.appendingPathComponent("original.txt")
        try "Original content".write(to: originalFile, atomically: true, encoding: .utf8)

        // Create hard link
        let hardLink = testDirectory.appendingPathComponent("hardlink.txt")
        try FileManager.default.linkItem(at: originalFile, to: hardLink)

        // Check resource values
        let resourceValues = try hardLink.resourceValues(forKeys: [.isSymbolicLinkKey])
        XCTAssertFalse(
            resourceValues.isSymbolicLink == true,
            "Hard link should NOT be a symlink"
        )

        // Test with O_NOFOLLOW
        let fd = open(hardLink.path, O_RDONLY | O_NOFOLLOW)
        XCTAssertTrue(fd >= 0, "Hard link should open successfully with O_NOFOLLOW")

        if fd >= 0 {
            var fileStat = stat()
            XCTAssertEqual(fstat(fd, &fileStat), 0, "fstat should succeed")

            let fileType = fileStat.st_mode & S_IFMT
            XCTAssertEqual(fileType, S_IFREG, "Hard link should be a regular file")

            close(fd)
        }
    }

    /// Test that non-regular files (FIFOs, sockets) are rejected
    func testNonRegularFilesRejected() throws {
        // Create FIFO (named pipe)
        let fifoPath = testDirectory.appendingPathComponent("test.fifo")
        let fifoResult = mkfifo(fifoPath.path, 0o644)
        XCTAssertEqual(fifoResult, 0, "FIFO should be created successfully")

        defer {
            try? FileManager.default.removeItem(at: fifoPath)
        }

        // Test with O_NOFOLLOW and O_NONBLOCK (to avoid blocking on FIFO)
        let fd = open(fifoPath.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)

        if fd >= 0 {
            var fileStat = stat()
            XCTAssertEqual(fstat(fd, &fileStat), 0, "fstat should succeed")

            let fileType = fileStat.st_mode & S_IFMT
            XCTAssertEqual(fileType, S_IFIFO, "Should be a FIFO")
            XCTAssertNotEqual(fileType, S_IFREG, "FIFO should NOT be a regular file")

            close(fd)
        }
    }

    // MARK: - TOCTOU Race Condition Tests

    /// Test that file descriptor validation prevents TOCTOU attacks
    func testTOCTOUProtection() throws {
        // This test simulates a TOCTOU race condition where:
        // 1. Check if file exists (time-of-check)
        // 2. Attacker replaces file with symlink
        // 3. Operate on file (time-of-use)
        //
        // With O_NOFOLLOW, the operation fails safely

        let filePath = testDirectory.appendingPathComponent("toctou_test.txt")
        try "Initial content".write(to: filePath, atomically: true, encoding: .utf8)

        // Simulate check phase
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: filePath.path),
            "File should exist during check phase"
        )

        // Simulate attacker replacing file with symlink
        try FileManager.default.removeItem(at: filePath)
        let targetPath = testDirectory.appendingPathComponent("attack_target.txt")
        try "Attack target".write(to: targetPath, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: filePath, withDestinationURL: targetPath)

        // Simulate use phase with O_NOFOLLOW (should fail)
        let fd = open(filePath.path, O_RDONLY | O_NOFOLLOW)

        if fd >= 0 {
            close(fd)
            XCTFail("Should not open symlink with O_NOFOLLOW")
        } else {
            XCTAssertEqual(errno, ELOOP, "Should return ELOOP for symlink")
        }
    }

    // MARK: - Security Boundary Tests

    /// Test that symlinks are validated against home directory boundary
    func testSymlinkBoundaryValidation() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        // Test 1: Symlink within home directory
        let internalTarget = homeDir.appendingPathComponent("Documents/safe_file.txt")
        let internalSymlink = testDirectory.appendingPathComponent("internal_symlink.txt")

        // Create target (if directory exists)
        if FileManager.default.fileExists(atPath: homeDir.appendingPathComponent("Documents").path) {
            try? "Safe content".write(to: internalTarget, atomically: true, encoding: .utf8)
            try? FileManager.default.createSymbolicLink(
                at: internalSymlink,
                withDestinationURL: internalTarget
            )

            if FileManager.default.fileExists(atPath: internalSymlink.path) {
                let resolvedURL = internalSymlink.resolvingSymlinksInPath()
                XCTAssertTrue(
                    resolvedURL.path.hasPrefix(homeDir.path),
                    "Internal symlink should resolve within home directory"
                )
            }
        }

        // Test 2: Symlink to system directory
        let externalSymlink = testDirectory.appendingPathComponent("external_symlink.txt")
        try FileManager.default.createSymbolicLink(
            at: externalSymlink,
            withDestinationURL: URL(fileURLWithPath: "/etc/hosts")
        )

        let resolvedURL = externalSymlink.resolvingSymlinksInPath()
        XCTAssertFalse(
            resolvedURL.path.hasPrefix(homeDir.path),
            "External symlink should NOT be within home directory"
        )
        XCTAssertTrue(
            resolvedURL.path.hasPrefix("/etc"),
            "External symlink should point to /etc"
        )
    }
}
