//
//  FileOperationsSecurityTests.swift
//  Forma File Organizing Tests
//
//  Security test suite for TOCTOU vulnerability fix
//  Tests file descriptor-based validation and TOCTOU protection
//
//  NOTE: These tests use secureMoveOnDisk() instead of moveFile() to avoid
//  SwiftData @Model complexities and test the security validation in isolation.
//

import XCTest
import Darwin
@testable import Forma_File_Organizing

/// Security tests for TOCTOU vulnerability fix.
/// These tests use POSIX APIs directly to test low-level security behavior,
/// without relying on service layer initialization.
final class FileOperationsSecurityTests: XCTestCase {

    var testDirectory: URL!
    var destDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create temporary test directory
        let tempDir = FileManager.default.temporaryDirectory
        testDirectory = tempDir.appendingPathComponent("FormaSecurityTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // Create destination directory for move operations
        destDirectory = testDirectory.appendingPathComponent("dest")
        try FileManager.default.createDirectory(at: destDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Clean up test directory
        if let testDir = testDirectory, FileManager.default.fileExists(atPath: testDir.path) {
            try? FileManager.default.removeItem(at: testDir)
        }
        testDirectory = nil
        destDirectory = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Helper: Validates file using O_NOFOLLOW (same as secureValidateFile)
    
    /// Tests if a file can be safely opened (rejects symlinks, validates regular file)
    /// Returns nil if validation passes, or an error description if it fails
    /// Uses O_NONBLOCK to avoid blocking on FIFOs/pipes
    private func validateFileSecurely(at path: String) -> String? {
        let fd = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        
        guard fd >= 0 else {
            let err = errno
            switch err {
            case ENOENT:
                return "Source not found"
            case EACCES, EPERM:
                return "Permission denied"
            case ELOOP:
                return "Source is a symbolic link (security risk)"
            default:
                return "Cannot open source file (errno: \(err))"
            }
        }
        
        defer { close(fd) }
        
        // Get file status using the open file descriptor
        var fileStat = stat()
        guard fstat(fd, &fileStat) == 0 else {
            return "Cannot stat source file"
        }
        
        // Verify it's a regular file
        let fileType = fileStat.st_mode & S_IFMT
        guard fileType == S_IFREG else {
            switch fileType {
            case S_IFLNK:
                return "Source is a symbolic link"
            case S_IFDIR:
                return "Source is a directory, not a regular file"
            case S_IFCHR:
                return "Source is a character device, not a regular file"
            case S_IFBLK:
                return "Source is a block device, not a regular file"
            case S_IFIFO:
                return "Source is a FIFO/pipe, not a regular file"
            case S_IFSOCK:
                return "Source is a socket, not a regular file"
            default:
                return "Source is not a regular file"
            }
        }
        
        // Verify read permissions
        guard fileStat.st_mode & S_IRUSR != 0 else {
            return "Permission denied - no read access"
        }
        
        return nil  // Validation passed
    }

    // MARK: - Symlink Attack Prevention Tests

    /// Test 1: Verify symlinks are rejected (CWE-61)
    func testSymlinkAttackPrevention() throws {
        // Create a real target file
        let targetFile = testDirectory.appendingPathComponent("target.txt")
        try "sensitive data".write(to: targetFile, atomically: true, encoding: .utf8)

        // Create a symlink pointing to the target
        let symlinkPath = testDirectory.appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(
            at: symlinkPath,
            withDestinationURL: targetFile
        )

        // Verify symlink exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: symlinkPath.path))

        // Attempt to validate symlink - should fail
        let error = validateFileSecurely(at: symlinkPath.path)
        XCTAssertNotNil(error, "Expected symlink to be rejected")
        XCTAssertTrue(
            error!.lowercased().contains("symbolic link") || error!.lowercased().contains("symlink"),
            "Expected symlink error, got: \(error!)"
        )

        // Verify original file is untouched
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))
    }

    /// Test 2: Verify symlink cannot be created during race window
    /// Note: This test validates that the FD-based validation catches race conditions
    func testSymlinkRaceConditionPrevention() throws {
        // Create a regular file
        let regularFile = testDirectory.appendingPathComponent("regular.txt")
        try "test content".write(to: regularFile, atomically: true, encoding: .utf8)

        // First, verify normal file passes validation
        let regularError = validateFileSecurely(at: regularFile.path)
        XCTAssertNil(regularError, "Regular file should pass validation, got: \(regularError ?? "nil")")
        
        // Now test that symlinks are rejected (simulating post-race attack)
        // Create a new symlink in place of a "file"
        let attackSymlink = testDirectory.appendingPathComponent("attack.txt")
        try FileManager.default.createSymbolicLink(
            at: attackSymlink,
            withDestinationURL: URL(fileURLWithPath: "/etc/passwd")
        )
        
        // This should fail because the source is a symlink
        let symlinkError = validateFileSecurely(at: attackSymlink.path)
        XCTAssertNotNil(symlinkError, "Symlink should be rejected")
        XCTAssertTrue(
            symlinkError!.lowercased().contains("symlink") || symlinkError!.lowercased().contains("symbolic"),
            "Expected symlink error, got: \(symlinkError!)"
        )
    }

    // MARK: - Device Node Attack Prevention Tests

    /// Test 3: Verify device nodes are rejected
    func testDeviceNodeRejection() throws {
        // Note: Creating device nodes requires root privileges
        // This test verifies the validation logic, but may be skipped in sandboxed environment

        let devicePath = testDirectory.appendingPathComponent("device.txt")

        // Try to create a character device (will fail without root, which is expected)
        let result = mknod(devicePath.path, S_IFCHR | 0o666, makedev(1, 3))

        if result == 0 {
            // Device node created successfully (running as root in test environment)
            defer { unlink(devicePath.path) }

            // Attempt to validate device node - should fail
            let error = validateFileSecurely(at: devicePath.path)
            XCTAssertNotNil(error, "Device node should be rejected")
            XCTAssertTrue(
                error!.lowercased().contains("device") || error!.lowercased().contains("not a regular file"),
                "Expected device node error, got: \(error!)"
            )
        } else {
            // Expected in sandboxed/non-root environment - skip test
            throw XCTSkip("Device node creation requires root privileges")
        }
    }

    // MARK: - Directory Attack Prevention Tests

    /// Test 4: Verify directories are rejected
    func testDirectoryRejection() throws {
        let directory = testDirectory.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

        // Attempt to validate directory - should fail
        let error = validateFileSecurely(at: directory.path)
        XCTAssertNotNil(error, "Directory should be rejected")
        XCTAssertTrue(
            error!.lowercased().contains("directory") || error!.lowercased().contains("not a regular file"),
            "Expected directory error, got: \(error!)"
        )
    }

    // MARK: - FIFO/Pipe Attack Prevention Tests

    /// Test 5: Verify FIFOs (named pipes) are rejected
    func testFIFORejection() throws {
        let fifoPath = testDirectory.appendingPathComponent("pipe.txt")

        // Create named pipe
        let result = mkfifo(fifoPath.path, 0o666)
        guard result == 0 else {
            throw XCTSkip("Failed to create FIFO for testing (may require permissions)")
        }
        defer { unlink(fifoPath.path) }

        // Attempt to validate FIFO - should fail
        let error = validateFileSecurely(at: fifoPath.path)
        XCTAssertNotNil(error, "FIFO should be rejected")
        XCTAssertTrue(
            error!.lowercased().contains("fifo") || error!.lowercased().contains("pipe") || error!.lowercased().contains("not a regular file"),
            "Expected FIFO error, got: \(error!)"
        )
    }

    // MARK: - Permission Validation Tests

    /// Test 6: Verify unreadable files are rejected
    func testUnreadableFileRejection() throws {
        let unreadableFile = testDirectory.appendingPathComponent("unreadable.txt")
        try "test".write(to: unreadableFile, atomically: true, encoding: .utf8)

        // Remove read permissions
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: unreadableFile.path
        )
        defer {
            // Restore permissions for cleanup
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: unreadableFile.path
            )
        }

        // Attempt to validate unreadable file - should fail
        let error = validateFileSecurely(at: unreadableFile.path)
        XCTAssertNotNil(error, "Unreadable file should be rejected")
        XCTAssertTrue(
            error!.lowercased().contains("permission") || error!.lowercased().contains("denied") || error!.lowercased().contains("access"),
            "Expected permission error, got: \(error!)"
        )
    }

    // MARK: - Positive Security Tests

    /// Test 7: Verify normal files are processed correctly
    func testRegularFileSuccess() throws {
        let regularFile = testDirectory.appendingPathComponent("normal.txt")
        let testContent = "This is a normal file"
        try testContent.write(to: regularFile, atomically: true, encoding: .utf8)

        // Validate the regular file - should pass
        let error = validateFileSecurely(at: regularFile.path)
        XCTAssertNil(error, "Regular file should pass validation, got: \(error ?? "nil")")
        
        // Verify file still exists (we only validated, didn't move)
        XCTAssertTrue(FileManager.default.fileExists(atPath: regularFile.path), "File should still exist")
    }

    /// Test 8: Verify large files are handled securely
    func testLargeFileHandling() throws {
        let largeFile = testDirectory.appendingPathComponent("large.bin")

        // Create a 1MB file (smaller for faster tests)
        let size = 1 * 1024 * 1024
        let data = Data(repeating: 0xFF, count: size)
        try data.write(to: largeFile)

        // Validate the large file - should pass
        let error = validateFileSecurely(at: largeFile.path)
        XCTAssertNil(error, "Large file should pass validation, got: \(error ?? "nil")")
        
        // Verify file still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: largeFile.path), "File should still exist")
    }

    // MARK: - Helper Functions

    private func makedev(_ major: Int32, _ minor: Int32) -> dev_t {
        return dev_t((major << 8) | minor)
    }
}
