# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Forma is a native macOS file organization app built with SwiftUI that helps users organize files from Desktop, Downloads, and other folders using intelligent rule-based automation. The app uses SwiftData for persistence and requires macOS 14.0+.

## Commands

### Building
```bash
# Build the project
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build

# Clean build
xcodebuild clean -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing"

# Deep clean (removes all derived data)
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Running
Open `Forma File Organizing.xcodeproj` in Xcode and press `Cmd+R`, or use Xcode's standard run commands.

### Testing
```bash
# Run all tests
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination "platform=macOS"

# Run specific test suite
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -only-testing:Forma_File_OrganizingTests/RuleEngineTests

# Run specific test method
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -only-testing:Forma_File_OrganizingTests/RuleEngineTests/testExtensionMatch

# Run UI tests only
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination "platform=macOS" -only-testing:Forma_File_OrganizingUITests
```

In Xcode: Press `Cmd+U` to run all tests, or click test diamonds in the gutter next to individual test methods.

## Architecture

### Pattern: MVVM with Service Layer
- **Views**: SwiftUI views in `Views/` and `Components/`
- **ViewModels**: `@MainActor` classes in `ViewModels/` with `@Published` properties for reactive UI
- **Models**: SwiftData models (`@Model` classes) in `Models/`
- **Services**: Business logic layer in `Services/` that ViewModels orchestrate

### Data Flow
```
User → View → ViewModel → Service Layer → File System/SwiftData
                ↓
         @Published properties trigger UI updates via Combine
```

### Protocol-Based Architecture (RuleEngine)
The `RuleEngine` uses protocol-based generics (`Fileable` and `Ruleable`) to decouple business logic from SwiftData models. This allows:
- **Testing without SwiftData**: Tests use simple structs (`TestFileItem`, `TestRule`) instead of `@Model` classes
- **No MainActor in tests**: Tests are synchronous and fast
- **Separation of concerns**: Business logic is independent of persistence layer

**Key files**: 
- `Models/FileProtocols.swift` and `Models/RuleProtocols.swift` define the protocols
- `Services/RuleEngine.swift` uses generic constraints: `func evaluateFile<F: Fileable, R: Ruleable>(...)`
- `Forma File OrganizingTests/TestModels.swift` contains test doubles
- See `Docs/Architecture/RuleEngine-Architecture.md` for detailed explanation

### Security & Permissions
The app is fully sandboxed and uses **security-scoped bookmarks** for persistent folder access:
- All folder access requires user permission via `NSOpenPanel`
- Bookmarks are saved to `UserDefaults` and resolved on subsequent launches
- Must call `startAccessingSecurityScopedResource()` before file operations and `stopAccessingSecurityScopedResource()` after
- Services handle this automatically; manual file operations must follow this pattern

### Key Components

**FileSystemService**: Scans directories and manages security-scoped bookmarks
- Methods: `scanDesktop()`, `scanDownloads()`, `requestDesktopAccess()`, etc.
- Protocol: `FileSystemServiceProtocol` for testing (see `MockFileSystemService`)

**RuleEngine**: Evaluates files against rules using protocol-based generics
- Condition types: `.fileExtension`, `.nameStartsWith`, `.nameContains`, `.nameEndsWith`
- Returns files with `suggestedDestination` and `status` set

**FileOperationsService**: Executes file operations (move/copy/delete)
- Handles security-scoped access and subdirectory creation
- Requests destination folder permissions on-demand

**DashboardViewModel**: Main state management
- Three-column layout: Sidebar (navigation), Main (file grid), Right Panel (analytics)
- Manages permissions state and onboarding flow
- Coordinates file scanning, rule evaluation, and storage analytics

### SwiftData Models
All models are defined as `@Model` classes:
- **FileItem**: File representation with metadata, category, status
- **Rule**: Organization rule with conditions and actions
- **ActivityItem**: Activity tracking for the timeline
- **CustomFolder**: User-added scan locations

Models auto-conform to their respective protocols (`Fileable`, `Ruleable`) for use with RuleEngine.

### Test Environment
The app detects test execution via `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]` and automatically creates an in-memory `ModelContainer` to avoid side effects. See `Forma_File_OrganizingApp.swift` init.

## File Categories
The app categorizes files into 6 types with specific extensions, colors, and icons:
- **Documents** (Steel Blue): pdf, doc, docx, txt, rtf, pages, xls, xlsx, csv, ppt, pptx, keynote
- **Images** (Sage Green): jpg, jpeg, png, heic, gif, svg, psd, ai, raw, cr2, nef
- **Videos** (Clay): mp4, mov, avi, mkv, wmv, flv, webm
- **Audio** (Terracotta): mp3, wav, aac, flac, m4a, ogg, wma
- **Archives** (Amber): zip, rar, 7z, tar, gz, dmg, pkg, iso
- **All** (filter): Shows all file types

See `FileTypeCategory` enum for implementation.

## Design System
Centralized design tokens in `DesignSystem/DesignSystem.swift`:

**Colors**: Obsidian (dark), Bone White (light bg), Steel Blue (primary), Sage (success), Clay, Terracotta, Amber
- Access via `DesignSystem.Colors.steelBlue` or `.steelBlue` (Color extension)

**Typography**: 
- Headings: `.formaHero`, `.formaH1`, `.formaH2`, `.formaH3`
- Body: `.formaBody`, `.formaBodyBold`, `.formaSmall`, `.formaCaption`, `.formaMono`

**Spacing**: `.micro` (4px), `.tight` (8px), `.standard` (12px), `.large` (16px), `.generous` (24px), `.xl` (32px), `.xxl` (48px)

**Layout**: Corner radii (`.cornerRadiusSmall`, `.cornerRadiusMedium`, etc.) and shadows

Always use these tokens instead of hardcoded values.

## Development Practices

### Testing
The project uses XCTest for both unit and UI testing. Tests are located in:
- `Forma File OrganizingTests/` - Unit and integration tests
- `Forma File OrganizingUITests/` - UI tests

#### Testing Framework & Requirements
**Test Setup:**
- All test classes inherit from `XCTestCase`
- Use `setUpWithError()` or `setUp()` for test initialization
- Use `tearDownWithError()` or `tearDown()` for cleanup
- ViewModels requiring MainActor must mark test classes with `@MainActor`

**In-Memory Storage:**
- The app automatically detects test execution via `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]`
- SwiftData automatically uses in-memory `ModelContainer` during tests
- No manual test database setup required

**Protocol-Based Testing:**
- Use protocol-based test doubles from `TestModels.swift` for RuleEngine tests:
  - `TestFileItem` (conforms to `Fileable`) - no SwiftData required
  - `TestRule` (conforms to `Ruleable`) - simple struct, no MainActor
- For ViewModels requiring services, inject `MockFileSystemService` via `FileSystemServiceProtocol`
- This approach avoids SwiftData and MainActor complications, making tests synchronous and fast

**Test Categories:**
1. **Unit Tests** (Business Logic):
   - RuleEngine: `RuleEngineTests.swift` - uses `TestFileItem` and `TestRule`
   - Services: `FileSystemServiceTests.swift`, `FileOperationsServiceTests.swift`, etc.
   - Models: Test individual model behaviors

2. **ViewModel Tests** (State Management):
   - Mark test class with `@MainActor`
   - Inject mock services via dependency injection
   - Test `@Published` property updates and async operations
   - Example: `DashboardViewModelTests.swift`

3. **Security Tests** (TOCTOU, Symlinks, File Operations):
   - Use `FileOperationsSecurityTests.swift` as reference
   - Test symlink rejection, device node prevention, FIFO rejection
   - Use temporary directories (`FileManager.default.temporaryDirectory`)
   - Clean up in `tearDownWithError()`

4. **UI Tests** (User Interactions):
   - Use `XCUIApplication` with launch arguments
   - Set `app.launchArguments = ["--uitesting"]` for test mode
   - Use `XCTSkip` for unreliable tests (e.g., hover detection)
   - Example: `FileRowUITests.swift`, `MicroInteractionsUITests.swift`

**Writing New Tests - Checklist:**
- [ ] Choose appropriate test type (unit/ViewModel/security/UI)
- [ ] For RuleEngine logic: Use `TestFileItem` and `TestRule` (no SwiftData)
- [ ] For ViewModels: Mark class `@MainActor`, inject mock services
- [ ] For file operations: Create temp directories, clean up in tearDown
- [ ] For security: Test symlink/FIFO/device node rejection patterns
- [ ] For UI: Use `XCUIApplication`, set `--uitesting` launch arg
- [ ] Use descriptive test method names: `testFeatureBehaviorExpectation()`
- [ ] Follow AAA pattern: Arrange (Given), Act (When), Assert (Then)
- [ ] Clean up resources in `tearDown` or with `defer`

**Async Testing:**
```swift
@MainActor
func testAsyncOperation() async throws {
    // Given
    viewModel.mockService.shouldSucceed = true
    
    // When
    await viewModel.loadData()
    
    // Then
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertEqual(viewModel.items.count, 5)
}
```

**Error Testing:**
```swift
func testSecurityValidation() throws {
    // Create malicious symlink
    let symlink = testDirectory.appendingPathComponent("link.txt")
    try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: targetFile)
    
    // Should throw security error
    XCTAssertThrowsError(
        try fileOperationsService.secureMoveOnDisk(from: symlink.path, to: destPath)
    ) { error in
        let errorString = error.localizedDescription.lowercased()
        XCTAssertTrue(errorString.contains("symlink") || errorString.contains("security"))
    }
}
```

**Required Test Coverage:**
When adding new features, you MUST add tests for:
- Core business logic (RuleEngine conditions, file matching)
- ViewModel state changes and user interactions
- Security validations (if touching file operations)
- Error handling and edge cases
- Integration between services and ViewModels

### ViewModels
- Always mark as `@MainActor` since they interact with SwiftUI
- Use `@Published` for properties that drive UI
- Accept services via dependency injection for testability
- Example: `init(fileSystemService: FileSystemServiceProtocol = FileSystemService())`

### File Operations
When adding new file operations:
1. Always use security-scoped bookmarks
2. Wrap operations in `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`
3. Use `defer` to ensure cleanup even if errors occur
4. See `FileSystemService.scanDesktop()` for the pattern

### Adding New Rules
Rule conditions are defined in `Rule.ConditionType` enum. To add a new condition:
1. Add case to enum in `Models/Rule.swift`
2. Update `RuleEngine.matches()` switch statement
3. Add tests to `RuleEngineTests.swift`
4. Update UI in rule editor views

### SwiftData Queries
Use `FetchDescriptor` with `#Predicate` for queries:
```swift
let descriptor = FetchDescriptor<FileItem>(
    predicate: #Predicate<FileItem> { $0.status == .pending }
)
let files = try? context.fetch(descriptor)
```

### Permissions
The app requires these core permissions (tracked in `DashboardViewModel`):
- Desktop, Downloads, Documents, Pictures, Music (via security-scoped bookmarks)
- Destination folders (requested on-demand when organizing files)

Onboarding flow shows until all core permissions are granted.

## Project Structure
```
Forma File Organizing/
├── Models/                 # SwiftData models + protocols
├── ViewModels/             # State management (@MainActor classes)
├── Views/                  # Main screens
├── Components/             # Reusable UI components
├── Services/               # Business logic layer
├── DesignSystem/           # Design tokens
└── Assets.xcassets         # Images and icons

Forma File OrganizingTests/    # Unit & Integration Tests
├── RuleEngineTests.swift           # Protocol-based RuleEngine tests
├── DashboardViewModelTests.swift   # MainActor ViewModel tests
├── ReviewViewModelTests.swift
├── RuleServiceTests.swift
├── FileSystemServiceTests.swift
├── FileOperationsServiceTests.swift
├── StorageServiceTests.swift
├── InsightsServiceTests.swift
├── ContextDetectionServiceTests.swift
├── FileFilterManagerTests.swift
├── FileScanPipelineTests.swift
├── FileOperationsSecurityTests.swift  # TOCTOU, symlink, security tests
├── BookmarkValidationSecurityTests.swift
├── SecureBookmarkStoreTests.swift
├── SymlinkSecurityTests.swift
├── RuleConditionTypeSafetyTests.swift
├── RateLimitingTests.swift
├── LoggingPolicyTests.swift
├── OrganizationPersonalityTests.swift
├── OrganizationTemplateTests.swift
├── EnhancedReviewFeatureTests.swift
├── InlineRuleBuilderTests.swift
├── FileRowTests.swift
├── MockFileSystemService.swift        # Mock for dependency injection
└── TestModels.swift                   # Protocol-based test doubles

Forma File OrganizingUITests/      # UI Tests
├── FileRowUITests.swift
├── MicroInteractionsUITests.swift
└── Forma_File_OrganizingUITestsLaunchTests.swift

Docs/
├── Architecture/           # Architecture documentation
├── Development/           # Development guides
└── README.md             # Main project documentation
```

## Common Patterns

### Scanning Files
```swift
let files = try await fileSystemService.scanDesktop()
let filesWithRules = ruleEngine.evaluateFiles(files, rules: rules)
// Save to SwiftData
for file in filesWithRules {
    context.insert(file)
}
try? context.save()
```

### Rule Evaluation
The RuleEngine accepts any type conforming to `Fileable` and `Ruleable`:
```swift
let result = ruleEngine.evaluateFile(fileItem, rules: rules)
// result.suggestedDestination is set if a rule matched
// result.status is .ready or .pending
```

### ViewModel Pattern
```swift
@MainActor
class MyViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service: ServiceProtocol
    
    init(service: ServiceProtocol = RealService()) {
        self.service = service
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await service.fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Phase 3: Testing AI Features

### ML Destination Prediction Testing

Phase 3 introduces ML-based destination prediction. Testing this feature requires understanding its architecture and lifecycle.

#### Testing DestinationPredictionService

**Key Test Files:**
- `DestinationPredictionPerformanceTests.swift` - Performance benchmarks
- `DestinationPredictionGatingTests.swift` - Regression tests for gating logic
- `FileScanPipelinePrecedenceTests.swift` - Integration tests for pipeline ordering

**Synthetic Dataset Generation:**
Use built-in generators for consistent benchmarking:
```swift
// Generate training data
let records = generateSyntheticTrainingData(
    count: 1000,
    destinations: ["Documents/Work", "Archive", "Documents/Personal"]
)

// Convert to ActivityItems
let activityItems = convertRecordsToActivityItems(records)
```

**Performance Benchmarking:**
```swift
@MainActor
func testPredictionLatency() async throws {
    let file = createTestFile(name: "invoice.pdf", ext: "pdf")
    let context = PredictionContext()
    
    measure {
        Task {
            let result = await service.predictDestination(
                for: file,
                context: context,
                negativePatterns: []
            )
        }
    }
}
```

**Testing Gating Logic:**
Test cold-start behavior, confidence thresholds, and negative pattern blocking:
```swift
func testColdStart_InsufficientData() async throws {
    // Create only 30 activity items (below minimum of 50)
    let activityItems = createSyntheticActivityItems(
        count: 30,
        destinations: ["Documents/Work", "Archive"]
    )
    
    await service.scheduleTrainingIfNeeded(activityItems: activityItems)
    
    // Verify no model was trained
    let metadata = await service.currentModelMetadata()
    XCTAssertNil(metadata, "No model should be trained with < 50 examples")
}
```

**Testing Pipeline Precedence:**
Verify RuleEngine → LearnedPattern → ML ordering:
```swift
func testPrecedence_RulesOverPatterns() async throws {
    // Create rule: PDFs → Documents/Work
    let rule = Rule(...)
    modelContext.insert(rule)
    
    // Create conflicting pattern: PDFs → Archive
    let pattern = LearnedPattern(...)
    pattern.destinationFolder = "Archive"
    modelContext.insert(pattern)
    
    let result = await pipeline.scanAndPersist(...)
    
    // Verify rule won over pattern
    XCTAssertEqual(result.files.first?.suggestedDestination, "Documents/Work")
    XCTAssertEqual(result.files.first?.suggestionSource, .rule)
}
```

### Natural Language Rule Parser Testing

**Key Test File:**
- `NaturalLanguageRuleParserEdgeCaseTests.swift`

**Testing Ambiguity Detection:**
```swift
func testAmbiguousTimePhrase_LastWeek() throws {
    let result = parser.parse("Move PDFs from last week to Archive")
    
    XCTAssertTrue(result.isAmbiguous, "Parse should be marked as ambiguous")
    
    let timeClause = result.clauses.first { $0.kind == .timeConstraint }
    XCTAssertTrue(
        timeClause?.ambiguityTags.contains(.ambiguousTimePhrase) ?? false,
        "Time phrase should be flagged as ambiguous"
    )
}
```

**Testing Error Handling:**
```swift
func testInvalidSyntax_NoAction() throws {
    let result = parser.parse("PDFs to Archive") // Missing action
    
    XCTAssertTrue(result.hasBlockingError, "Should have blocking error")
    XCTAssertNil(result.primaryAction, "No action should be parsed")
    
    let errors = result.issues.filter { $0.severity == .error }
    XCTAssertFalse(errors.isEmpty, "Should have at least one error")
}
```

**Testing Rule Conversion:**
```swift
func testRuleConversion_DefaultName() throws {
    let result = parser.parse("Move PDFs to Archive")
    
    let rule = result.toRule()
    XCTAssertNotNil(rule, "Should convert to rule")
    XCTAssertFalse(rule?.name.isEmpty ?? true, "Rule should have a name")
}
```

### Debugging Prediction Behavior

**Enable Debug Logging:**
```swift
Log.debug("ML prediction failed: \(error.localizedDescription)", category: .analytics)
```

**Inspect Training History:**
```swift
let descriptor = FetchDescriptor<MLTrainingHistory>(
    sortBy: [SortDescriptor(\.trainedAt, order: .reverse)]
)
let history = try? modelContext.fetch(descriptor)
// Check accuracy, FPR, accepted status
```

**Test with Synthetic Data:**
1. Generate 100+ synthetic ActivityItems
2. Trigger training via `scheduleTrainingIfNeeded`
3. Check `MLTrainingHistory` for results
4. Verify predictions on test files

**Common Issues:**
- **No predictions**: Check if 50+ examples and 3+ destinations threshold met
- **Low accuracy**: Review training data quality and label distribution
- **Drift detected**: Check acceptance/override rates in sliding window
- **Model not loading**: Verify file exists at model URL and permissions are correct

### Performance Targets (Milestone 5)

**Prediction Latency:**
- Target: ≤5-20ms per file
- Test: `DestinationPredictionPerformanceTests.testPredictionLatency_NoModel()`

**Training Time:**
- 100 examples: ≤1 second
- 500 examples: ≤2 seconds
- 1000 examples: ≤4 seconds (**key criterion**)
- 5000 examples: ≤10 seconds
- Test: `DestinationPredictionPerformanceTests.testTrainingLatency_1000Examples()`

**Running Performance Tests:**
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -only-testing:Forma_File_OrganizingTests/DestinationPredictionPerformanceTests
```

### Adding New NL Patterns

To extend the NaturalLanguageRuleParser with new patterns:

1. **Add detection logic** in `NaturalLanguageRuleParser.swift`:
```swift
private func extractNewPattern(from text: String, lower: String) -> PatternResult {
    // Use regex or keyword matching
    let pattern = #"your regex pattern here"#
    if let regex = try? NSRegularExpression(pattern: pattern) {
        // Extract and create RuleCondition
    }
    return PatternResult(...)
}
```

2. **Update `parse()` method** to call new extraction:
```swift
let newResult = extractNewPattern(from: trimmed, lower: lower)
clauses.append(contentsOf: newResult.clauses)
conditions.append(contentsOf: newResult.conditions)
```

3. **Add tests** in `NaturalLanguageRuleParserEdgeCaseTests.swift`:
```swift
func testNewPattern_BasicCase() throws {
    let result = parser.parse("Your test input")
    XCTAssertTrue(result.candidateConditions.contains { /* verify condition */ })
}
```

4. **Update documentation** in `Phase3-Architecture.md`

## Documentation
- `README.md`: Feature overview and project structure
- `Docs/Architecture/ARCHITECTURE.md`: System architecture and component relationships
- `Docs/Architecture/RuleEngine-Architecture.md`: Protocol-based architecture deep dive
- `Docs/Architecture/Phase3-Architecture.md`: Phase 3 AI features architecture
- `Docs/Development/DEVELOPMENT.md`: Development workflows and debugging
