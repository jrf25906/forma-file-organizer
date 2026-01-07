# Testing Guide

This document explains the testing infrastructure and best practices for Forma.

## Test Architecture

Forma uses a **hybrid testing approach**:

### 1. Mock-Based Unit Tests (Fast)
**Use for**: ViewModels, RuleEngine, business logic

- **Mock services** via protocols (`MockFileSystemService`)
- **No filesystem I/O** or user interaction required
- **Protocol-based test doubles** for RuleEngine (`TestFileItem`, `TestRule`)
- Tests run in milliseconds
- No MainActor concerns for most tests

**Example**:
```swift
func testDashboardScansFiles() async {
    let mockService = MockFileSystemService()
    mockService.mockFiles = [/* test data */]
    let viewModel = DashboardViewModel(fileSystemService: mockService)
    
    await viewModel.scanAllFiles()
    XCTAssertEqual(viewModel.files.count, mockService.mockFiles.count)
}
```

### 2. Integration Tests with Real Filesystem (Thorough)
**Use for**: File operations, FileSystemService, end-to-end workflows

- **Real filesystem operations** in temporary directories
- Tests actual file I/O, permissions, edge cases
- Automatically cleaned up after each test
- Tests the full stack including security-scoped bookmarks

**Example**:
```swift
func testMoveFile_Success() async throws {
    let sourceURL = try tempSourceDir.createFile(name: "test.pdf")
    let fileItem = createFileItem(name: "test.pdf", path: sourceURL.path, destination: "Documents")
    
    let result = try await service.moveFile(fileItem)
    
    XCTAssertTrue(result.success)
    XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
}
```

## Test Infrastructure

### TemporaryDirectory Helper

Located in: `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift`

**Purpose**: Create isolated test directories that are automatically cleaned up.

**Key Features**:
- Unique directory per test (`/tmp/FormaTests-UUID`)
- Auto-cleanup on `deinit` (no manual cleanup needed)
- Helper methods for common file/directory operations
- Support for custom file attributes (size, dates)

**Usage**:
```swift
func testExample() throws {
    let tempDir = try TemporaryDirectory()
    
    // Create files
    try tempDir.createFile(name: "test.pdf", contents: "content")
    try tempDir.createFile(name: "large.zip", size: 1024 * 1024 * 100) // 100MB
    
    // Create directories
    try tempDir.createDirectory(name: "Documents/Work")
    
    // Create multiple files by extension
    try tempDir.createFiles(withExtensions: ["pdf", "jpg", "mp4"])
    
    // Check existence
    XCTAssertTrue(tempDir.fileExists(at: "test.pdf"))
    
    // Get full URL
    let fileURL = tempDir.url(for: "test.pdf")
    
    // Cleanup is automatic via deinit
}
```

**Advanced Usage**:
```swift
// File with specific attributes
try tempDir.createFile(
    name: "old_document.pdf",
    size: 1024 * 50, // 50KB
    creationDate: Date(timeIntervalSince1970: 1000000),
    modificationDate: Date(timeIntervalSince1970: 2000000)
)

// Nested directories and files
try tempDir.createFile(name: "Projects/2024/report.pdf")
```

## Test Files

### FileOperationsServiceTests
**Location**: `Forma File OrganizingTests/FileOperationsServiceTests.swift`

Tests real file operations:
- Moving files to destinations
- Creating intermediate directories
- Error handling (source not found, destination exists)
- Batch operations with partial failures
- Activity tracking

**Setup**:
- Creates two temporary directories (source and destination)
- Sets up in-memory SwiftData container
- Creates security-scoped bookmarks for testing

**Key Tests**:
- `testMoveFile_Success()` - Basic move operation
- `testMoveFile_CreatesIntermediateDirectories()` - Subdirectory creation
- `testMoveFile_SourceNotFound()` - Error handling
- `testMoveFiles_MultiplFiles()` - Batch operations
- `testMoveFile_TracksActivity()` - SwiftData integration

### FileSystemServiceTests
**Location**: `Forma File OrganizingTests/FileSystemServiceTests.swift`

**Note**: These are currently **skeleton tests** demonstrating patterns.

**Challenge**: `FileSystemService.scanDirectory()` is private and uses security-scoped bookmarks, making it hard to test directly.

**Options to make these tests work**:
1. Make `scanDirectory()` internal (visible to tests)
2. Add test-only initializer that accepts a URL
3. Refactor to separate scanning logic from permission management

**Current tests show patterns for**:
- File counting and filtering
- Hidden file exclusion
- Directory exclusion
- File metadata extraction
- Bookmark resolution

## Best Practices

### When to Use Mock vs. Real Filesystem

✅ **Use Mocks** for:
- ViewModel logic
- Rule evaluation (RuleEngine)
- UI state management
- Fast iteration during development

✅ **Use Real Filesystem** for:
- File I/O operations
- Permission handling
- Edge cases (file locks, disk space, etc.)
- Integration/acceptance tests

### SwiftData in Tests

The app automatically uses **in-memory storage** when tests are running:

```swift
// In Forma_File_OrganizingApp.swift
if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
    // In tests - use in-memory storage
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(for: schema, configurations: [config])
}
```

For explicit test containers:
```swift
let schema = Schema([FileItem.self, ActivityItem.self])
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: schema, configurations: [config])
let context = container.mainContext // @MainActor!
```

### MainActor Considerations

SwiftData's `mainContext` is `@MainActor` isolated. Mark test methods accordingly:

```swift
@MainActor
override func setUp() {
    super.setUp()
    modelContext = modelContainer?.mainContext
}

func testWithContext() async throws {
    guard let context = modelContext else { return }
    // Use context...
}
```

### ⚠️ Swift 6 Actor-Isolated Deinit Pitfall

**Problem**: Tests crash instantly (0.000 seconds) with `signal abrt` and memory corruption errors like `POINTER_BEING_FREED_WAS_NOT_ALLOCATED` when testing classes that are stored inside `@MainActor` types.

**Root Cause**: In Swift 6 strict concurrency, when a `@MainActor` class stores another class as a property, Swift infers that the stored class needs an "actor-isolated deinit." This means deallocation must happen on the main actor. When tests create/destroy these objects outside of a MainActor context, the runtime attempts to hop to MainActor during deinit, causing Task-local storage corruption.

**Example of the Problem**:
```swift
// ViewModel is @MainActor
@MainActor
final class NaturalLanguageRuleViewModel: ObservableObject {
    private let parser = NaturalLanguageRuleParser()  // ← This class gets actor-isolated deinit
}

// Parser was a class
final class NaturalLanguageRuleParser {
    func parse(_ text: String) -> NLParsedRule { ... }
}

// Tests crash because:
// 1. Test creates NaturalLanguageRuleParser()
// 2. Test ends, parser gets deallocated
// 3. Swift tries to run actor-isolated deinit on MainActor
// 4. But we're not on MainActor → memory corruption → crash
```

**Solution**: Use `struct` instead of `class` for stateless services.

Structs don't have `deinit`, so there's no actor isolation issue. This is also more idiomatic Swift for types that don't need reference semantics.

```swift
// ✅ Fixed: Struct has no deinit, no actor-isolation issue
struct NaturalLanguageRuleParser {
    func parse(_ text: String) -> NLParsedRule { ... }
}
```

**When to Apply This Fix**:
- The type is **stateless** (no stored properties, or only constant configuration)
- The type doesn't need **reference semantics** (identity, mutation across references)
- The type is stored in a `@MainActor` class (ViewModels, SwiftData `@Model` types, etc.)

**Symptoms to Watch For**:
- Tests crash at exactly 0.000 seconds (before any test code runs)
- Stack trace includes `__deallocating_deinit` and `swift::TaskLocal`
- Error: `malloc: double free` or `POINTER_BEING_FREED_WAS_NOT_ALLOCATED`
- Crash only happens in tests, not when running the app

**Prevention Checklist**:
- [ ] Is this type stateless? → Consider using `struct`
- [ ] Does this type need reference semantics? → If no, use `struct`
- [ ] Will this type be stored in a `@MainActor` context? → Must be `struct` or `Sendable` class

### Error Handling Tests

Since `FileOperationError` is not `Equatable`, use pattern matching:

```swift
// ❌ Won't compile
XCTAssertEqual(error, .sourceNotFound)

// ✅ Use pattern matching
do {
    try await service.moveFile(fileItem)
    XCTFail("Expected error")
} catch let error as FileOperationsService.FileOperationError {
    if case .sourceNotFound = error {
        // Success
    } else {
        XCTFail("Wrong error type")
    }
}
```

## Running Tests

### All Tests
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" -destination "platform=macOS"
```

### Specific Test Class
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -only-testing:Forma_File_OrganizingTests/FileOperationsServiceTests \
  -destination "platform=macOS"
```

### Specific Test Method
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -only-testing:Forma_File_OrganizingTests/FileOperationsServiceTests/testMoveFile_Success \
  -destination "platform=macOS"
```

### In Xcode
- Press `Cmd+U` to run all tests
- Click the diamond icon in the gutter next to a test method to run individually
- Use Test Navigator (`Cmd+6`) to see all tests

## Test Organization

```
Forma File OrganizingTests/
├── TestHelpers/
│   └── TemporaryDirectory.swift       # Filesystem test helper
├── MockFileSystemService.swift        # Mock for unit tests
├── TestModels.swift                   # Protocol-based test doubles
├── DashboardViewModelTests.swift      # Mock-based ViewModel tests
├── RuleEngineTests.swift              # Protocol-based logic tests
├── RuleServiceTests.swift             # Service tests
├── FileSystemServiceTests.swift       # Filesystem integration (skeleton)
└── FileOperationsServiceTests.swift   # Filesystem integration (full)
```

## Future Improvements

1. **Make FileSystemService more testable**
   - Extract scanning logic into separate component
   - Add dependency injection for bookmark provider
   - Make `scanDirectory()` internal for testing

2. **Add more integration tests**
   - End-to-end workflow tests (scan → evaluate → organize)
   - Custom folder scanning
   - Bookmark staleness handling

3. **Performance tests**
   - Large file counts (1000+ files)
   - Deep directory hierarchies
   - Concurrent operations

4. **UI tests**
   - Rule creation workflows
   - File organization flows
   - Permission request flows

## Resources

- **RuleEngine Architecture**: `Docs/Architecture/RuleEngine-Architecture.md`
- **Development Guide**: `Docs/Development/DEVELOPMENT.md`
- **Project Structure**: `README.md`
