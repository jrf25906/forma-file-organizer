import XCTest
import SwiftData
@testable import Forma_File_Organizing

/// Tests for per-folder template category creation and scoping
@MainActor
final class PerFolderTemplateCategoryTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container with all required models
        let schema = Schema([
            Rule.self,
            RuleCategory.self,
            FileItem.self,
            ActivityItem.self,
            CustomFolder.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - RuleCategory Creation Tests

    func testCreateCategoryWithFolderScope() throws {
        // Given - Create mock bookmark data (simulating a real bookmark)
        let mockBookmarkData = Data("mock_bookmark_for_desktop".utf8)

        let scopedFolder = CategoryScope.ScopedFolder(
            bookmark: mockBookmarkData,
            displayName: "Desktop"
        )

        // When
        let category = RuleCategory(
            name: "Desktop",
            colorHex: "#5B7FA3",
            iconName: "desktopcomputer",
            scope: .folders([scopedFolder]),
            isEnabled: true,
            sortOrder: 0,
            isDefault: false
        )

        modelContext.insert(category)
        try modelContext.save()

        // Then
        let fetchDescriptor = FetchDescriptor<RuleCategory>()
        let categories = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "Desktop")
        XCTAssertFalse(categories.first?.scope.isGlobal ?? true)
        XCTAssertEqual(categories.first?.scope.scopedFolders.count, 1)
        XCTAssertEqual(categories.first?.scope.scopedFolders.first?.displayName, "Desktop")
    }

    func testCreateMultipleFolderScopedCategories() throws {
        // Given
        let folders: [(name: String, colorHex: String, iconName: String)] = [
            ("Desktop", "#5B7FA3", "desktopcomputer"),
            ("Downloads", "#8AA789", "arrow.down.circle.fill"),
            ("Pictures", "#D4915C", "photo.fill")
        ]

        // When
        for (index, folder) in folders.enumerated() {
            let mockBookmark = Data("mock_bookmark_\(folder.name)".utf8)
            let scopedFolder = CategoryScope.ScopedFolder(
                bookmark: mockBookmark,
                displayName: folder.name
            )

            let category = RuleCategory(
                name: folder.name,
                colorHex: folder.colorHex,
                iconName: folder.iconName,
                scope: .folders([scopedFolder]),
                isEnabled: true,
                sortOrder: index,
                isDefault: false
            )

            modelContext.insert(category)
        }

        try modelContext.save()

        // Then
        let fetchDescriptor = FetchDescriptor<RuleCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(categories.count, 3)
        XCTAssertEqual(categories[0].name, "Desktop")
        XCTAssertEqual(categories[0].sortOrder, 0)
        XCTAssertEqual(categories[1].name, "Downloads")
        XCTAssertEqual(categories[1].sortOrder, 1)
        XCTAssertEqual(categories[2].name, "Pictures")
        XCTAssertEqual(categories[2].sortOrder, 2)
    }

    // MARK: - Rule-Category Association Tests

    func testAssignRulesToCategory() throws {
        // Given
        let mockBookmark = Data("mock_bookmark".utf8)
        let scopedFolder = CategoryScope.ScopedFolder(
            bookmark: mockBookmark,
            displayName: "Desktop"
        )

        let category = RuleCategory(
            name: "Desktop",
            colorHex: "#5B7FA3",
            iconName: "desktopcomputer",
            scope: .folders([scopedFolder]),
            isEnabled: true,
            sortOrder: 0
        )
        modelContext.insert(category)

        // Create rules from minimal template
        let rules = OrganizationTemplate.minimal.generateRules()

        // When
        for rule in rules {
            rule.category = category
            modelContext.insert(rule)
        }

        try modelContext.save()

        // Then
        let ruleFetch = FetchDescriptor<Rule>()
        let savedRules = try modelContext.fetch(ruleFetch)

        XCTAssertGreaterThan(savedRules.count, 0)

        // All rules should be associated with the category
        for rule in savedRules {
            XCTAssertEqual(rule.category?.name, "Desktop")
        }
    }

    func testDifferentTemplatesForDifferentCategories() throws {
        // Given - Create two categories
        let desktopCategory = createTestCategory(
            name: "Desktop",
            colorHex: "#5B7FA3",
            sortOrder: 0
        )
        let downloadsCategory = createTestCategory(
            name: "Downloads",
            colorHex: "#8AA789",
            sortOrder: 1
        )

        modelContext.insert(desktopCategory)
        modelContext.insert(downloadsCategory)

        // Apply different templates to each category
        let minimalRules = OrganizationTemplate.minimal.generateRules()
        for rule in minimalRules {
            rule.category = desktopCategory
            modelContext.insert(rule)
        }

        let paraRules = OrganizationTemplate.para.generateRules()
        for rule in paraRules {
            rule.category = downloadsCategory
            modelContext.insert(rule)
        }

        try modelContext.save()

        // Then
        let ruleFetch = FetchDescriptor<Rule>()
        let allRules = try modelContext.fetch(ruleFetch)

        let desktopRules = allRules.filter { $0.category?.name == "Desktop" }
        let downloadsRules = allRules.filter { $0.category?.name == "Downloads" }

        // Minimal template has 7 rules, PARA has 10
        XCTAssertEqual(desktopRules.count, 7, "Desktop should have minimal template rules")
        XCTAssertEqual(downloadsRules.count, 10, "Downloads should have PARA template rules")
    }

    // MARK: - CategoryScope Matching Tests

    func testGlobalScopeMatchesAllFiles() {
        let globalScope = CategoryScope.global

        let desktopFile = URL(fileURLWithPath: "/Users/test/Desktop/file.txt")
        let downloadsFile = URL(fileURLWithPath: "/Users/test/Downloads/file.zip")
        let documentsFile = URL(fileURLWithPath: "/Users/test/Documents/report.pdf")

        XCTAssertTrue(globalScope.matches(fileURL: desktopFile))
        XCTAssertTrue(globalScope.matches(fileURL: downloadsFile))
        XCTAssertTrue(globalScope.matches(fileURL: documentsFile))
    }

    func testScopeDisplayDescription() {
        // Global scope
        let globalScope = CategoryScope.global
        XCTAssertEqual(globalScope.displayDescription, "All locations")

        // Empty folders scope
        let emptyScope = CategoryScope.folders([])
        XCTAssertEqual(emptyScope.displayDescription, "No folders selected")

        // Single folder scope
        let singleFolder = CategoryScope.ScopedFolder(
            bookmark: Data(),
            displayName: "Desktop"
        )
        let singleScope = CategoryScope.folders([singleFolder])
        XCTAssertEqual(singleScope.displayDescription, "Desktop")

        // Multiple folders scope
        let folder1 = CategoryScope.ScopedFolder(bookmark: Data(), displayName: "Desktop")
        let folder2 = CategoryScope.ScopedFolder(bookmark: Data(), displayName: "Downloads")
        let multiScope = CategoryScope.folders([folder1, folder2])
        XCTAssertEqual(multiScope.displayDescription, "2 folders")
    }

    func testScopeIsGlobal() {
        let globalScope = CategoryScope.global
        XCTAssertTrue(globalScope.isGlobal)

        let folderScope = CategoryScope.folders([])
        XCTAssertFalse(folderScope.isGlobal)
    }

    func testScopedFoldersProperty() {
        let folder1 = CategoryScope.ScopedFolder(bookmark: Data(), displayName: "Desktop")
        let folder2 = CategoryScope.ScopedFolder(bookmark: Data(), displayName: "Downloads")

        let globalScope = CategoryScope.global
        XCTAssertTrue(globalScope.scopedFolders.isEmpty)

        let folderScope = CategoryScope.folders([folder1, folder2])
        XCTAssertEqual(folderScope.scopedFolders.count, 2)
        XCTAssertEqual(folderScope.scopedFolders[0].displayName, "Desktop")
        XCTAssertEqual(folderScope.scopedFolders[1].displayName, "Downloads")
    }

    // MARK: - CategoryScope Codable Tests

    func testCategoryScopeCodableGlobal() throws {
        let scope = CategoryScope.global

        let encoder = JSONEncoder()
        let data = try encoder.encode(scope)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CategoryScope.self, from: data)

        XCTAssertEqual(decoded, scope)
        XCTAssertTrue(decoded.isGlobal)
    }

    func testCategoryScopeCodableFolders() throws {
        let folder = CategoryScope.ScopedFolder(
            bookmark: Data("test_bookmark".utf8),
            displayName: "TestFolder"
        )
        let scope = CategoryScope.folders([folder])

        let encoder = JSONEncoder()
        let data = try encoder.encode(scope)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CategoryScope.self, from: data)

        XCTAssertEqual(decoded, scope)
        XCTAssertFalse(decoded.isGlobal)
        XCTAssertEqual(decoded.scopedFolders.count, 1)
        XCTAssertEqual(decoded.scopedFolders.first?.displayName, "TestFolder")
    }

    // MARK: - OnboardingFolder Properties Tests

    func testOnboardingFolderHasColorHex() {
        for folder in OnboardingFolder.allCases {
            XCTAssertFalse(
                folder.colorHex.isEmpty,
                "\(folder) should have a colorHex"
            )
            XCTAssertTrue(
                folder.colorHex.hasPrefix("#"),
                "\(folder) colorHex should start with #"
            )
            XCTAssertEqual(
                folder.colorHex.count,
                7,
                "\(folder) colorHex should be 7 characters (#RRGGBB)"
            )
        }
    }

    func testOnboardingFolderHasIconName() {
        for folder in OnboardingFolder.allCases {
            XCTAssertFalse(
                folder.iconName.isEmpty,
                "\(folder) should have an iconName"
            )
        }
    }

    func testOnboardingFolderColorsAreDistinct() {
        var colors = Set<String>()
        for folder in OnboardingFolder.allCases {
            colors.insert(folder.colorHex)
        }
        XCTAssertEqual(
            colors.count,
            OnboardingFolder.allCases.count,
            "All folders should have distinct colors"
        )
    }

    // MARK: - Integration Test: Full Category Setup Flow

    func testFullCategorySetupWithTemplateRules() throws {
        // Simulate onboarding completing with per-folder templates

        // Given - User selections
        let folderConfigs: [(folder: OnboardingFolder, template: OrganizationTemplate)] = [
            (.desktop, .minimal),
            (.downloads, .para),
            (.pictures, .chronological)
        ]

        // When - Create categories with their rules
        for (index, config) in folderConfigs.enumerated() {
            let category = createTestCategory(
                name: config.folder.title,
                colorHex: config.folder.colorHex,
                iconName: config.folder.iconName,
                sortOrder: index
            )
            modelContext.insert(category)

            let rules = config.template.generateRules()
            for rule in rules {
                rule.category = category
                modelContext.insert(rule)
            }
        }

        try modelContext.save()

        // Then - Verify complete setup
        let categoryFetch = FetchDescriptor<RuleCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = try modelContext.fetch(categoryFetch)

        XCTAssertEqual(categories.count, 3)

        // Verify each category has the correct rule count
        let ruleFetch = FetchDescriptor<Rule>()
        let allRules = try modelContext.fetch(ruleFetch)

        let desktopRules = allRules.filter { $0.category?.name == "Desktop" }
        let downloadsRules = allRules.filter { $0.category?.name == "Downloads" }
        let picturesRules = allRules.filter { $0.category?.name == "Pictures" }

        XCTAssertEqual(desktopRules.count, 7, "Desktop (minimal) should have 7 rules")
        XCTAssertEqual(downloadsRules.count, 10, "Downloads (PARA) should have 10 rules")
        XCTAssertEqual(picturesRules.count, 7, "Pictures (chronological) should have 7 rules")
    }

    // MARK: - Helper Methods

    private func createTestCategory(
        name: String,
        colorHex: String = "#3B82F6",
        iconName: String = "folder.fill",
        sortOrder: Int = 0
    ) -> RuleCategory {
        let mockBookmark = Data("mock_bookmark_\(name)".utf8)
        let scopedFolder = CategoryScope.ScopedFolder(
            bookmark: mockBookmark,
            displayName: name
        )

        return RuleCategory(
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            scope: .folders([scopedFolder]),
            isEnabled: true,
            sortOrder: sortOrder,
            isDefault: false
        )
    }
}
