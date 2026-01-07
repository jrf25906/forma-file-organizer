import Foundation
import SwiftData
import Combine

/// Service responsible for managing `RuleCategory` entities.
///
/// This is the **single source of truth** for all category operations. All category creation,
/// updates, and deletions should go through this service to ensure:
/// - Consistent behavior (e.g., General category cannot be deleted)
/// - Automatic rule reassignment when categories are deleted
/// - Proper persistence handling
///
/// ## Usage
/// ```swift
/// let categoryService = CategoryService(modelContext: context)
/// let workCategory = try categoryService.createCategory(name: "Work", preset: .work)
/// ```
@MainActor
class CategoryService: ObservableObject {

    // MARK: - Types

    /// Events published when categories change
    enum CategoryChangeEvent {
        case created(RuleCategory)
        case updated(RuleCategory)
        case deleted(categoryName: String)
        case rulesReassigned(count: Int, fromCategory: String, toCategory: String)
    }

    /// Errors specific to category operations
    enum CategoryError: LocalizedError {
        case cannotDeleteDefaultCategory
        case cannotRenameDefaultCategory
        case categoryNotFound
        case duplicateName(String)

        var errorDescription: String? {
            switch self {
            case .cannotDeleteDefaultCategory:
                return "The General category cannot be deleted."
            case .cannotRenameDefaultCategory:
                return "The General category cannot be renamed."
            case .categoryNotFound:
                return "Category not found."
            case .duplicateName(let name):
                return "A category named '\(name)' already exists."
            }
        }
    }

    // MARK: - Properties

    private let modelContext: ModelContext

    /// Publisher for category change events. Views can subscribe to react to changes.
    let categoryChanges = PassthroughSubject<CategoryChangeEvent, Never>()

    /// Published category count for SwiftUI observation
    @Published private(set) var categoryCount: Int = 0

    // MARK: - Initialization

    /// Initializes the service with a SwiftData model context.
    /// - Parameter modelContext: The context used for database operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        updateCategoryCount()
    }

    // MARK: - Fetch

    /// Fetches all categories from the database, sorted by sortOrder.
    /// - Returns: An array of `RuleCategory` objects.
    /// - Throws: An error if the fetch fails.
    func fetchCategories() throws -> [RuleCategory] {
        let descriptor = FetchDescriptor<RuleCategory>(
            sortBy: [
                SortDescriptor(\RuleCategory.sortOrder, order: .forward),
                SortDescriptor(\RuleCategory.creationDate, order: .forward)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches only enabled categories.
    /// - Returns: An array of enabled `RuleCategory` objects.
    /// - Throws: An error if the fetch fails.
    func fetchEnabledCategories() throws -> [RuleCategory] {
        let descriptor = FetchDescriptor<RuleCategory>(
            predicate: #Predicate<RuleCategory> { $0.isEnabled },
            sortBy: [
                SortDescriptor(\RuleCategory.sortOrder, order: .forward),
                SortDescriptor(\RuleCategory.creationDate, order: .forward)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches the default "General" category.
    ///
    /// If the General category doesn't exist, it will be created automatically.
    /// - Returns: The default RuleCategory.
    /// - Throws: An error if the fetch or creation fails.
    func fetchDefaultCategory() throws -> RuleCategory {
        let descriptor = FetchDescriptor<RuleCategory>(
            predicate: #Predicate<RuleCategory> { $0.isDefault }
        )
        let results = try modelContext.fetch(descriptor)

        if let defaultCategory = results.first {
            return defaultCategory
        }

        // Create the default category if it doesn't exist
        return try createDefaultCategoryIfNeeded()
    }

    /// Fetches a category by its ID.
    /// - Parameter id: The UUID of the category.
    /// - Returns: The category, or nil if not found.
    /// - Throws: An error if the fetch fails.
    func fetchCategory(by id: UUID) throws -> RuleCategory? {
        // Work around a Swift compiler assertion triggered by capturing external values
        // inside `#Predicate` for SwiftData. Categories are a small dataset, so fetching
        // and filtering in-memory is acceptable here.
        return try fetchCategories().first { $0.id == id }
    }

    // MARK: - Create

    /// Creates a new category.
    ///
    /// - Parameters:
    ///   - name: The display name for the category.
    ///   - colorHex: Hex color string (default: blue).
    ///   - iconName: SF Symbol name (default: folder.fill).
    ///   - scope: Where rules in this category apply (default: global).
    /// - Returns: The created category.
    /// - Throws: `CategoryError.duplicateName` if a category with this name exists.
    func createCategory(
        name: String,
        colorHex: String = "#3B82F6",
        iconName: String = "folder.fill",
        scope: CategoryScope = .global
    ) throws -> RuleCategory {
        // Check for duplicate name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if try categoryExists(named: trimmedName) {
            throw CategoryError.duplicateName(trimmedName)
        }

        // Get the next sort order
        let categories = try fetchCategories()
        let nextSortOrder = (categories.map(\.sortOrder).max() ?? -1) + 1

        let category = RuleCategory(
            name: trimmedName,
            colorHex: colorHex,
            iconName: iconName,
            scope: scope,
            isEnabled: true,
            sortOrder: nextSortOrder,
            isDefault: false
        )

        modelContext.insert(category)
        try modelContext.save()

        updateCategoryCount()
        categoryChanges.send(.created(category))

        Log.info("Created category: \(trimmedName)", category: .pipeline)

        return category
    }

    /// Creates a category from a preset.
    ///
    /// - Parameter preset: The preset to use for initial values.
    /// - Returns: The created category.
    /// - Throws: An error if creation fails.
    func createCategory(from preset: RuleCategory.Preset) throws -> RuleCategory {
        try createCategory(
            name: preset.name,
            colorHex: preset.colorHex,
            iconName: preset.iconName,
            scope: .global
        )
    }

    /// Creates the default "General" category if it doesn't exist.
    ///
    /// This is called automatically during app initialization and when
    /// fetching the default category if it's missing.
    ///
    /// - Returns: The default category.
    /// - Throws: An error if creation fails.
    @discardableResult
    func createDefaultCategoryIfNeeded() throws -> RuleCategory {
        // Check if default already exists
        let descriptor = FetchDescriptor<RuleCategory>(
            predicate: #Predicate<RuleCategory> { $0.isDefault }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        // Create the default category
        let defaultCategory = RuleCategory.createDefault()
        modelContext.insert(defaultCategory)
        try modelContext.save()

        updateCategoryCount()
        Log.info("Created default General category", category: .pipeline)

        return defaultCategory
    }

    // MARK: - Update

    /// Updates a category's properties.
    ///
    /// - Parameters:
    ///   - category: The category to update.
    ///   - name: New name (optional).
    ///   - colorHex: New color (optional).
    ///   - iconName: New icon (optional).
    ///   - scope: New scope (optional).
    ///   - isEnabled: New enabled state (optional).
    /// - Throws: `CategoryError.cannotRenameDefaultCategory` if trying to rename General.
    func updateCategory(
        _ category: RuleCategory,
        name: String? = nil,
        colorHex: String? = nil,
        iconName: String? = nil,
        scope: CategoryScope? = nil,
        isEnabled: Bool? = nil
    ) throws {
        // Prevent renaming the default category
        if let newName = name, category.isDefault && newName != category.name {
            throw CategoryError.cannotRenameDefaultCategory
        }

        // Check for duplicate name if renaming
        if let newName = name {
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName != category.name {
                let exists = try categoryExists(named: trimmedName)
                if exists {
                    throw CategoryError.duplicateName(trimmedName)
                }
            }
            category.name = trimmedName
        }

        if let colorHex = colorHex {
            category.colorHex = colorHex
        }

        if let iconName = iconName {
            category.iconName = iconName
        }

        if let scope = scope {
            category.scope = scope
        }

        if let isEnabled = isEnabled {
            category.isEnabled = isEnabled
        }

        try modelContext.save()
        categoryChanges.send(.updated(category))

        Log.info("Updated category: \(category.name)", category: .pipeline)
    }

    /// Updates the sort order of multiple categories atomically.
    ///
    /// Use this when reordering categories via drag-and-drop in the UI.
    /// Each category's sortOrder is updated to match its position in the provided array.
    ///
    /// - Parameter categories: Categories in their new priority order (index 0 = highest priority).
    /// - Throws: An error if saving fails.
    func updateCategoryPriorities(_ categories: [RuleCategory]) throws {
        for (index, category) in categories.enumerated() {
            category.sortOrder = index
        }

        try modelContext.save()
        Log.info("Updated category priorities for \(categories.count) categories", category: .pipeline)
    }

    // MARK: - Delete

    /// Deletes a category and reassigns its rules to the default category.
    ///
    /// - Parameter category: The category to delete.
    /// - Throws: `CategoryError.cannotDeleteDefaultCategory` if trying to delete General.
    func deleteCategory(_ category: RuleCategory) throws {
        guard !category.isDefault else {
            throw CategoryError.cannotDeleteDefaultCategory
        }

        let categoryName = category.name

        // Get rules in this category and reassign to General
        let defaultCategory = try fetchDefaultCategory()
        let rulesDescriptor = FetchDescriptor<Rule>()
        let allRules = try modelContext.fetch(rulesDescriptor)
        let rulesInCategory = allRules.filter { $0.category?.id == category.id }

        let reassignedCount = rulesInCategory.count
        for rule in rulesInCategory {
            rule.category = defaultCategory
        }

        // Delete the category
        modelContext.delete(category)
        try modelContext.save()

        updateCategoryCount()
        categoryChanges.send(.deleted(categoryName: categoryName))

        if reassignedCount > 0 {
            categoryChanges.send(.rulesReassigned(
                count: reassignedCount,
                fromCategory: categoryName,
                toCategory: defaultCategory.name
            ))
            Log.info("Reassigned \(reassignedCount) rules from '\(categoryName)' to 'General'", category: .pipeline)
        }

        Log.info("Deleted category: \(categoryName)", category: .pipeline)
    }

    // MARK: - Rule Assignment

    /// Assigns a rule to a category.
    ///
    /// - Parameters:
    ///   - rule: The rule to assign.
    ///   - category: The category to assign to (nil = General).
    /// - Throws: An error if saving fails.
    func assignRule(_ rule: Rule, to category: RuleCategory?) throws {
        rule.category = category
        try modelContext.save()

        let categoryName = category?.name ?? "General"
        Log.info("Assigned rule '\(rule.name)' to category '\(categoryName)'", category: .pipeline)
    }

    /// Assigns multiple rules to a category.
    ///
    /// - Parameters:
    ///   - rules: The rules to assign.
    ///   - category: The category to assign to (nil = General).
    /// - Throws: An error if saving fails.
    func assignRules(_ rules: [Rule], to category: RuleCategory?) throws {
        for rule in rules {
            rule.category = category
        }
        try modelContext.save()

        let categoryName = category?.name ?? "General"
        Log.info("Assigned \(rules.count) rules to category '\(categoryName)'", category: .pipeline)
    }

    // MARK: - Helpers

    /// Checks if a category with the given name exists.
    /// - Parameter name: The name to check.
    /// - Returns: True if a category with this name exists.
    func categoryExists(named name: String) throws -> Bool {
        let categories = try fetchCategories()
        return categories.contains { $0.name.lowercased() == name.lowercased() }
    }

    /// Updates the published category count.
    private func updateCategoryCount() {
        do {
            let descriptor = FetchDescriptor<RuleCategory>()
            categoryCount = try modelContext.fetchCount(descriptor)
        } catch {
            Log.error("Failed to update category count: \(error)", category: .pipeline)
        }
    }

    // MARK: - Migration

    /// Migrates existing rules to the default category.
    ///
    /// This should be called once during app initialization after the default
    /// category is created. It assigns all rules without a category to General.
    ///
    /// - Returns: The number of rules migrated.
    @discardableResult
    func migrateExistingRulesToDefaultCategory() throws -> Int {
        let defaultCategory = try fetchDefaultCategory()

        let rulesDescriptor = FetchDescriptor<Rule>()
        let allRules = try modelContext.fetch(rulesDescriptor)
        let uncategorizedRules = allRules.filter { $0.category == nil }

        guard !uncategorizedRules.isEmpty else {
            return 0
        }

        for rule in uncategorizedRules {
            rule.category = defaultCategory
        }

        try modelContext.save()
        Log.info("Migrated \(uncategorizedRules.count) existing rules to General category", category: .pipeline)

        return uncategorizedRules.count
    }
}
