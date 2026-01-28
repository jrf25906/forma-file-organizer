//
//  ManageCategoriesSheet.swift
//  Forma - Category Management UI
//
//  Sheet for managing rule categories: create, edit, delete, and reorder.
//  Uses consistent Forma design system patterns.
//

import SwiftUI
import SwiftData

/// Sheet view for managing rule categories.
///
/// Provides CRUD operations for categories with:
/// - List of all categories with drag-to-reorder
/// - Quick-start presets for common category types
/// - Category editor for name, color, icon, and scope
/// - Protection for the default "General" category
struct ManageCategoriesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var categories: [RuleCategory]

    private var sortedCategories: [RuleCategory] {
        categories.sortedByOrder
    }

    @State private var selectedCategory: RuleCategory?
    @State private var isCreatingNew = false
    @State private var showDeleteConfirmation = false
    @State private var categoryToDelete: RuleCategory?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()

            // Content
            HStack(spacing: 0) {
                // Categories list
                categoriesList
                    .frame(width: 280)

                Divider()

                // Editor panel
                editorPanel
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 720, height: 520)
        .background(Color.formaBackground)
        .alert("Delete Category?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    deleteCategory(category)
                }
            }
        } message: {
            if let category = categoryToDelete {
                let ruleCount = countRulesInCategory(category)
                if ruleCount > 0 {
                    Text("\(ruleCount) rule(s) will be moved to the General category.")
                } else {
                    Text("This category has no rules and will be permanently deleted.")
                }
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Manage Categories")
                    .font(.formaH2)
                    .foregroundColor(.formaObsidian)

                Text("\(categories.count) categories")
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(FormaSpacing.generous)
    }

    // MARK: - Categories List

    private var categoriesList: some View {
        VStack(spacing: 0) {
            // List header with add button
            HStack {
                Text("Categories")
                    .font(.formaSmallSemibold)
                    .foregroundColor(.formaSecondaryLabel)

                Spacer()

                Menu {
                    Button {
                        isCreatingNew = true
                        selectedCategory = nil
                    } label: {
                        Label("Custom Category", systemImage: "plus")
                    }

                    Divider()

                    Text("Quick Start Presets")

                    ForEach(RuleCategory.Preset.allCases, id: \.name) { preset in
                        Button {
                            createCategoryFromPreset(preset)
                        } label: {
                            Label(preset.name, systemImage: preset.iconName)
                        }
                        .disabled(categoryExists(named: preset.name))
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.formaH3)
                        .foregroundColor(.formaSteelBlue)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)

            Divider()

            // Categories
            ScrollView {
                LazyVStack(spacing: FormaSpacing.tight) {
                    ForEach(sortedCategories) { category in
                        CategoryRow(
                            category: category,
                            isSelected: selectedCategory?.id == category.id,
                            onSelect: {
                                isCreatingNew = false
                                selectedCategory = category
                            },
                            onDelete: {
                                categoryToDelete = category
                                showDeleteConfirmation = true
                            }
                        )
                        .draggable(category.id.uuidString) {
                            CategoryRow(
                                category: category,
                                isSelected: true,
                                onSelect: {},
                                onDelete: {}
                            )
                            .opacity(Color.FormaOpacity.prominent)
                            .frame(width: 240)
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard let draggedId = items.first,
                                  let draggedUUID = UUID(uuidString: draggedId),
                                  draggedUUID != category.id else {
                                return false
                            }
                            reorderCategory(draggedId: draggedUUID, targetId: category.id)
                            return true
                        }
                    }
                }
                .padding(FormaSpacing.tight)
            }

            // Reorder hint
            if categories.count > 1 {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.formaCaption)
                    Text("Drag to set priority")
                        .font(.formaCaption)
                }
                .foregroundColor(.formaSecondaryLabel)
                .padding(.vertical, FormaSpacing.tight)
            }
        }
        .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
    }

    // MARK: - Editor Panel

    private var editorPanel: some View {
        Group {
            if isCreatingNew {
                CategoryEditorView(
                    mode: .create,
                    onSave: { name, colorHex, iconName, scope in
                        createCategory(name: name, colorHex: colorHex, iconName: iconName, scope: scope)
                        isCreatingNew = false
                    },
                    onCancel: {
                        isCreatingNew = false
                    }
                )
            } else if let category = selectedCategory {
                CategoryEditorView(
                    mode: .edit(category),
                    onSave: { name, colorHex, iconName, scope in
                        updateCategory(category, name: name, colorHex: colorHex, iconName: iconName, scope: scope)
                    },
                    onCancel: {
                        selectedCategory = nil
                    }
                )
            } else {
                // Empty state
                VStack(spacing: FormaSpacing.standard) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.formaIcon)
                        .foregroundColor(.formaSecondaryLabel)

                    Text("Select a Category")
                        .font(.formaH3)
                        .foregroundColor(.formaSecondaryLabel)

                    Text("Choose a category from the list to edit, or create a new one.")
                        .font(.formaBody)
                        .foregroundColor(.formaSecondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func createCategory(name: String, colorHex: String, iconName: String, scope: CategoryScope) {
        let categoryService = CategoryService(modelContext: modelContext)
        do {
            let newCategory = try categoryService.createCategory(
                name: name,
                colorHex: colorHex,
                iconName: iconName,
                scope: scope
            )
            selectedCategory = newCategory
        } catch {
            Log.error("Failed to create category: \(error.localizedDescription)", category: .pipeline)
        }
    }

    private func createCategoryFromPreset(_ preset: RuleCategory.Preset) {
        let categoryService = CategoryService(modelContext: modelContext)
        do {
            let newCategory = try categoryService.createCategory(from: preset)
            selectedCategory = newCategory
            isCreatingNew = false
        } catch {
            Log.error("Failed to create category from preset: \(error.localizedDescription)", category: .pipeline)
        }
    }

    private func updateCategory(_ category: RuleCategory, name: String, colorHex: String, iconName: String, scope: CategoryScope) {
        let categoryService = CategoryService(modelContext: modelContext)
        do {
            try categoryService.updateCategory(
                category,
                name: name,
                colorHex: colorHex,
                iconName: iconName,
                scope: scope
            )
        } catch {
            Log.error("Failed to update category: \(error.localizedDescription)", category: .pipeline)
        }
    }

    private func deleteCategory(_ category: RuleCategory) {
        let categoryService = CategoryService(modelContext: modelContext)
        do {
            try categoryService.deleteCategory(category)
            if selectedCategory?.id == category.id {
                selectedCategory = nil
            }
            categoryToDelete = nil
        } catch {
            Log.error("Failed to delete category: \(error.localizedDescription)", category: .pipeline)
        }
    }

    private func reorderCategory(draggedId: UUID, targetId: UUID) {
        guard let draggedIndex = sortedCategories.firstIndex(where: { $0.id == draggedId }),
              let targetIndex = sortedCategories.firstIndex(where: { $0.id == targetId }) else {
            return
        }

        var reorderedCategories = sortedCategories
        let draggedCategory = reorderedCategories.remove(at: draggedIndex)
        reorderedCategories.insert(draggedCategory, at: targetIndex)

        let categoryService = CategoryService(modelContext: modelContext)
        do {
            try categoryService.updateCategoryPriorities(reorderedCategories)
        } catch {
            Log.error("Failed to reorder categories: \(error.localizedDescription)", category: .pipeline)
        }
    }

    private func categoryExists(named name: String) -> Bool {
        categories.contains { $0.name.lowercased() == name.lowercased() }
    }

    private func countRulesInCategory(_ category: RuleCategory) -> Int {
        let descriptor = FetchDescriptor<Rule>()
        do {
            let allRules = try modelContext.fetch(descriptor)
            return allRules.filter { $0.category?.id == category.id }.count
        } catch {
            return 0
        }
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: RuleCategory
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FormaSpacing.tight) {
                // Color & icon indicator
                ZStack {
                    Circle()
                        .fill(category.color.opacity(Color.FormaOpacity.medium))
                        .frame(width: 32, height: 32)

                    Image(systemName: category.iconName)
                        .font(.formaBodySemibold)
                        .foregroundColor(category.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(category.name)
                            .font(.formaBodyMedium)
                            .foregroundColor(.formaObsidian)

                        if category.isDefault {
                            Text("Default")
                                .font(.formaMicro)
                                .foregroundColor(.formaSecondaryLabel)
                                .padding(.horizontal, FormaSpacing.micro)
                                .padding(.vertical, FormaSpacing.micro / 2)
                                .background(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.light))
                                .clipShape(Capsule())
                        }

                        if !category.isEnabled {
                            Image(systemName: "eye.slash")
                                .font(.formaCaption)
                                .foregroundColor(.formaSecondaryLabel)
                        }
                    }

                    Text(category.scope.displayDescription)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }

                Spacer()

                // Delete button (not for default category)
                if !category.isDefault && isHovered {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.formaCompact)
                            .foregroundColor(.formaError)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(
                        isSelected
                            ? category.color.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle)
                            : (isHovered ? Color.formaObsidian.opacity(Color.FormaOpacity.subtle) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .stroke(isSelected ? category.color.opacity(Color.FormaOpacity.strong) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Category Editor View

private struct CategoryEditorView: View {
    enum Mode {
        case create
        case edit(RuleCategory)

        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }

        var existingCategory: RuleCategory? {
            if case .edit(let category) = self { return category }
            return nil
        }
    }

    let mode: Mode
    let onSave: (String, String, String, CategoryScope) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var colorHex: String = "#3B82F6"
    @State private var iconName: String = "folder.fill"
    @State private var scope: CategoryScope = .global
    @State private var isEnabled: Bool = true

    // Available icons for selection
    private let availableIcons = [
        "folder.fill", "briefcase.fill", "house.fill", "archivebox.fill",
        "photo.fill", "doc.fill", "music.note", "film.fill",
        "gear", "star.fill", "heart.fill", "bookmark.fill",
        "tag.fill", "flag.fill", "paperclip", "tray.fill"
    ]

    // Available colors for selection
    private let availableColors = [
        "#3B82F6", "#10B981", "#F59E0B", "#EC4899",
        "#8B5CF6", "#EF4444", "#06B6D4", "#6B7280"
    ]

    private var isDefault: Bool {
        mode.existingCategory?.isDefault ?? false
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            // Title
            Text(mode.isEditing ? "Edit Category" : "New Category")
                .font(.formaH3)
                .foregroundColor(.formaObsidian)

            // Form fields
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                // Name field
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Name")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaSecondaryLabel)

                    TextField("Category name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.formaBody)
                        .padding(FormaSpacing.tight)
                        .background(Color.formaControlBackground)
                        .formaCornerRadius(FormaRadius.control)
                        .disabled(isDefault)
                        .opacity(isDefault ? (Color.FormaOpacity.strong + Color.FormaOpacity.light) : 1)

                    if isDefault {
                        Text("The default category cannot be renamed.")
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }

                // Color picker
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Color")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaSecondaryLabel)

                    HStack(spacing: FormaSpacing.tight) {
                        ForEach(availableColors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .formaSteelBlue)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.formaBoneWhite, lineWidth: 2)
                                            .opacity(colorHex == hex ? 1 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Icon picker
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Icon")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaSecondaryLabel)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: FormaSpacing.tight), count: 8), spacing: FormaSpacing.tight) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.formaBodyLarge)
                                    .foregroundColor(iconName == icon ? .formaBoneWhite : .formaSecondaryLabel)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                                            .fill(iconName == icon ? (Color(hex: colorHex) ?? .formaSteelBlue) : Color.formaControlBackground)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Scope selector
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Apply to")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaSecondaryLabel)

                    HStack(spacing: FormaSpacing.tight) {
                        ScopeButton(
                            title: "All Locations",
                            subtitle: "Rules apply everywhere",
                            icon: "globe",
                            isSelected: scope.isGlobal
                        ) {
                            scope = .global
                        }

                        ScopeButton(
                            title: "Specific Folders",
                            subtitle: scope.scopedFolders.isEmpty ? "Add folders..." : "\(scope.scopedFolders.count) folder(s)",
                            icon: "folder.badge.gearshape",
                            isSelected: !scope.isGlobal
                        ) {
                            // TODO: Show folder picker
                            scope = .folders([])
                        }
                    }
                    .disabled(isDefault)
                    .opacity(isDefault ? 0.6 : 1)

                    if isDefault {
                        Text("The default category always applies to all locations.")
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack {
                FormaSecondaryButton(title: "Cancel", action: onCancel)
                    .frame(width: 100)

                Spacer()

                FormaPrimaryButton(
                    title: mode.isEditing ? "Save Changes" : "Create Category",
                    action: {
                        onSave(name, colorHex, iconName, scope)
                    },
                    isEnabled: isValid
                )
                .frame(width: 160)
            }
        }
        .padding(FormaSpacing.generous)
        .onAppear {
            if let category = mode.existingCategory {
                name = category.name
                colorHex = category.colorHex
                iconName = category.iconName
                scope = category.scope
                isEnabled = category.isEnabled
            }
        }
        .onChange(of: mode.existingCategory?.id) { _, _ in
            if let category = mode.existingCategory {
                name = category.name
                colorHex = category.colorHex
                iconName = category.iconName
                scope = category.scope
                isEnabled = category.isEnabled
            }
        }
    }
}

// MARK: - Scope Button

private struct ScopeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: icon)
                    .font(.formaH2)
                    .foregroundColor(isSelected ? .formaSteelBlue : .formaSecondaryLabel)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.formaBodyMedium)
                        .foregroundColor(isSelected ? .formaObsidian : .formaSecondaryLabel)

                    Text(subtitle)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }

                Spacer()
            }
            .padding(FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light) : Color.formaControlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .stroke(isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong) : Color.formaSeparator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Manage Categories") {
    ManageCategoriesSheet()
        .modelContainer(for: [RuleCategory.self, Rule.self], inMemory: true)
}
