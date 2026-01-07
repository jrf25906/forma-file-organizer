import Foundation

/// A test helper that creates a temporary directory and provides utilities
/// for setting up test file structures. Automatically cleans up on deinit.
final class TemporaryDirectory {
    let url: URL
    private let fileManager = FileManager.default
    
    /// Creates a new temporary directory with a unique name
    init() throws {
        url = fileManager.temporaryDirectory
            .appendingPathComponent("FormaTests-\(UUID().uuidString)")
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    /// Removes the temporary directory and all its contents
    func cleanup() {
        try? fileManager.removeItem(at: url)
    }
    
    /// Creates a file with the given name and contents
    /// - Parameters:
    ///   - name: File name (can include subdirectory path like "subdir/file.txt")
    ///   - contents: File contents as a string
    /// - Returns: URL of the created file
    @discardableResult
    func createFile(name: String, contents: String = "test content") throws -> URL {
        let fileURL = url.appendingPathComponent(name)
        
        // Create parent directory if needed
        let parentDir = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Creates a file with specific file attributes (size, dates)
    /// - Parameters:
    ///   - name: File name
    ///   - size: File size in bytes (file will be filled with dummy data)
    ///   - creationDate: Optional creation date
    ///   - modificationDate: Optional modification date
    /// - Returns: URL of the created file
    @discardableResult
    func createFile(
        name: String,
        size: Int64,
        creationDate: Date? = nil,
        modificationDate: Date? = nil
    ) throws -> URL {
        let fileURL = url.appendingPathComponent(name)
        
        // Create file with specified size
        let dummyData = Data(count: Int(size))
        try dummyData.write(to: fileURL)
        
        // Set dates if provided
        var attributes: [FileAttributeKey: Any] = [:]
        if let creation = creationDate {
            attributes[.creationDate] = creation
        }
        if let modification = modificationDate {
            attributes[.modificationDate] = modification
        }
        
        if !attributes.isEmpty {
            try fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
        }
        
        return fileURL
    }
    
    /// Creates a directory at the specified path
    /// - Parameter name: Directory name (can include nested paths like "subdir/nested")
    /// - Returns: URL of the created directory
    @discardableResult
    func createDirectory(name: String) throws -> URL {
        let dirURL = url.appendingPathComponent(name)
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }
    
    /// Creates multiple test files with common extensions
    /// - Parameter extensions: Array of file extensions (without dot)
    /// - Returns: Array of created file URLs
    @discardableResult
    func createFiles(withExtensions extensions: [String]) throws -> [URL] {
        try extensions.map { ext in
            try createFile(name: "test.\(ext)", contents: "Test file for .\(ext)")
        }
    }
    
    /// Checks if a file exists at the given relative path
    /// - Parameter relativePath: Path relative to the temporary directory
    /// - Returns: True if the file exists
    func fileExists(at relativePath: String) -> Bool {
        let fileURL = url.appendingPathComponent(relativePath)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Gets the full URL for a relative path
    /// - Parameter relativePath: Path relative to the temporary directory
    /// - Returns: Full URL
    func url(for relativePath: String) -> URL {
        url.appendingPathComponent(relativePath)
    }
    
    deinit {
        cleanup()
    }
}
