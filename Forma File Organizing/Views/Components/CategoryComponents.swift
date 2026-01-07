import SwiftUI

// MARK: - Create Category Popover

/// Small popover for creating a new category with name and color picker.
///
/// Used by both RuleEditorView and InlineRuleBuilderView for inline category creation.
///
/// ## Usage
/// ```swift
/// .popover(isPresented: $showCreateCategory) {
///     CreateCategoryPopover(
///         name: $newCategoryName,
///         color: $newCategoryColor,
///         onSave: { saveCategory() },
///         onCancel: { showCreateCategory = false }
///     )
/// }
/// ```
struct CreateCategoryPopover: View {
    @Binding var name: String
    @Binding var color: Color
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool

    /// Preset colors for quick selection
    private let presetColors: [Color] = [
        .formaSteelBlue,
        .formaSage,
        .formaWarmOrange,
        .formaMutedBlue,
        .formaSoftGreen,
        .formaSecondaryLabel
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header
            Text("New Category")
                .font(.formaBodySemibold)
                .foregroundColor(.formaLabel)

            // Name field
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text("Name")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)

                TextField("e.g., Work, Personal", text: $name)
                    .textFieldStyle(.plain)
                    .padding(FormaSpacing.tight + (FormaSpacing.micro / 2))
                    .background(Color.formaControlBackground)
                    .cornerRadius(FormaRadius.control)
                    .focused($isNameFocused)
            }

            // Color picker
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text("Color")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)

                HStack(spacing: FormaSpacing.tight) {
                    ForEach(presetColors, id: \.self) { presetColor in
                        Button(action: {
                            color = presetColor
                        }) {
                            Circle()
                                .fill(presetColor)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(color == presetColor ? Color.formaLabel : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Preview
            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.formaSmallMedium)
                    Text(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.formaSmallMedium)
                }
                .foregroundColor(.formaBoneWhite)
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.vertical, FormaSpacing.tight)
                .background(Capsule().fill(color))
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.formaSecondaryLabel)

                Spacer()

                Button(action: onSave) {
                    Text("Create")
                        .font(.formaBodySemibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.formaSteelBlue)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(FormaSpacing.standard)
        .frame(width: 220)
        .onAppear {
            isNameFocused = true
        }
    }
}

// MARK: - Category Pill Component

/// A compact pill-shaped button for selecting a rule category.
///
/// Shows the category icon, name, and uses the category's color when selected.
/// Supports different text font sizes for various contexts (standard editor vs compact inline builder).
///
/// ## Usage
/// ```swift
/// ForEach(categories) { category in
///     CategoryPill(
///         category: category,
///         isSelected: selectedCategoryID == category.id,
///         action: { selectedCategoryID = category.id }
///     )
/// }
///
/// // With compact font for inline contexts:
/// CategoryPill(
///     category: category,
///     isSelected: isSelected,
///     textFont: .formaCompactMedium,
///     action: { ... }
/// )
/// ```
struct CategoryPill: View {
    let category: RuleCategory
    let isSelected: Bool
    var textFont: Font = .formaSmallMedium
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.formaSmallMedium)

                Text(category.name)
                    .font(textFont)
            }
            .foregroundColor(isSelected ? .formaBoneWhite : category.color)
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : category.color.opacity(isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : category.color.opacity(Color.FormaOpacity.medium), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Previews

#Preview("Create Category Popover") {
    CreateCategoryPopover(
        name: .constant("Work"),
        color: .constant(.formaSteelBlue),
        onSave: {},
        onCancel: {}
    )
}

#Preview("Category Pills") {
    HStack {
        CategoryPill(
            category: RuleCategory.createDefault(),
            isSelected: false,
            action: {}
        )
        CategoryPill(
            category: RuleCategory.createDefault(),
            isSelected: true,
            action: {}
        )
    }
    .padding()
}
