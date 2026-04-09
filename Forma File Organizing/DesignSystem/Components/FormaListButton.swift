//
//  FormaListButton.swift
//  Forma - List Button Component
//
//  A list-style action button for navigation and settings rows
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

// MARK: - List Action Button

/// A list-style action button with icon, title, optional subtitle, and chevron.
/// Used for navigation items, settings rows, and action lists.
///
/// Usage:
/// ```swift
/// FormaListButton(
///     icon: "folder",
///     title: "Choose Folder",
///     action: { showFolderPicker() }
/// )
///
/// FormaListButton(
///     icon: "gear",
///     title: "Settings",
///     subtitle: "Configure app preferences",
///     action: { openSettings() }
/// )
/// ```
struct FormaListButton: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var iconColor: Color = .formaSteelBlue
    var showChevron: Bool = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.standard) {
                // Icon
                Image(systemName: icon)
                    .font(.formaBody)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.formaBodyMedium)
                        .foregroundColor(.formaLabel)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }

                Spacer()

                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.formaSmall)
                        .foregroundColor(.formaTertiaryLabel)
                }
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight + FormaSpacing.micro)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(isHovered ? Color.formaObsidian.opacity(Color.FormaOpacity.subtle) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview Helpers

#Preview("FormaListButton") {
    VStack(spacing: 0) {
        FormaListButton(
            icon: "folder",
            title: "Choose Folder",
            action: {}
        )

        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

        FormaListButton(
            icon: "gear",
            title: "Settings",
            subtitle: "Configure app preferences",
            action: {}
        )

        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

        FormaListButton(
            icon: "arrow.triangle.2.circlepath",
            title: "Sync Status",
            subtitle: "Last synced 5 minutes ago",
            iconColor: .formaSage,
            action: {}
        )

        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

        FormaListButton(
            icon: "questionmark.circle",
            title: "Help & Support",
            showChevron: false,
            action: {}
        )
    }
    .padding()
    .background(Color.formaBackground)
    .frame(width: 320)
}
