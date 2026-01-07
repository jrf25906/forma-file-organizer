import SwiftUI

/// Displays active filters as dismissible chips above empty states
/// Helps users understand why they see no results and quickly clear filters
struct ActiveFiltersBar: View {
    let searchText: String
    let category: FileTypeCategory
    let secondaryFilter: SecondaryFilter

    let onClearSearch: () -> Void
    let onClearCategory: () -> Void
    let onClearSecondary: () -> Void
    let onClearAll: () -> Void

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || category != .all || secondaryFilter != .none
    }

    var body: some View {
        if hasActiveFilters {
            VStack(spacing: FormaSpacing.standard) {
                Text("Active Filters")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)

                HStack(spacing: FormaSpacing.tight) {
                    // Search filter chip
                    if !searchText.isEmpty {
                        FilterChip(
                            label: "Search: \"\(searchText)\"",
                            icon: "magnifyingglass",
                            onDismiss: onClearSearch
                        )
                    }

                    // Category filter chip
                    if category != .all {
                        FilterChip(
                            label: category.displayName,
                            icon: category.iconName,
                            onDismiss: onClearCategory
                        )
                    }

                    // Secondary filter chip
                    if secondaryFilter != .none {
                        FilterChip(
                            label: secondaryFilter.displayName,
                            icon: secondaryFilter.iconName,
                            onDismiss: onClearSecondary
                        )
                    }
                }

                // Clear all button (only show if multiple filters)
                let filterCount = (searchText.isEmpty ? 0 : 1) + (category == .all ? 0 : 1) + (secondaryFilter == .none ? 0 : 1)
                if filterCount > 1 {
                    Button(action: onClearAll) {
                        Text("Clear All Filters")
                            .font(.formaSmall)
                            .foregroundColor(.formaSteelBlue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, FormaSpacing.standard)
            .padding(.horizontal, FormaSpacing.generous)
            .background(Color.formaWarmOrange.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
            .formaCornerRadius(FormaRadius.control)
        }
    }
}

/// Individual dismissible filter chip
private struct FilterChip: View {
    let label: String
    let icon: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
            Image(systemName: icon)
                .font(.formaCaption)

            Text(label)
                .font(.formaSmall)
                .lineLimit(1)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.formaCompact)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .buttonStyle(.plain)
            .help("Remove this filter")
        }
        .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
        .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
        .background(Color.formaControlBackground)
        .formaCornerRadius(FormaRadius.control)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .stroke(Color.formaSeparator, lineWidth: 1)
        )
        .foregroundColor(.formaLabel)
    }
}

// MARK: - SecondaryFilter Extensions

extension SecondaryFilter {
    var iconName: String {
        switch self {
        case .none: return "line.3.horizontal.decrease"
        case .recent: return "clock"
        case .largeFiles: return "externaldrive"
        case .flagged: return "flag"
        }
    }
}
