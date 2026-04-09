//
//  FormaFormControls.swift
//  Forma - Form Control Components
//
//  Text fields, folder pickers, and other form input controls
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

// MARK: - Form Controls

/// A standard text field matching the Forma design system
struct FormaTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var hasError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(title)
                .font(.formaBodySemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(FormaSpacing.standard - FormaSpacing.micro)
                .background(Color.formaCardBackground)
                .formaCornerRadius(FormaRadius.control)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .strokeBorder(
                            hasError ? Color.formaWarmOrange : Color.formaSeparator.opacity(Color.FormaOpacity.strong),
                            lineWidth: 1
                        )
                )
        }
    }
}

/// A standard folder picker control matching the Forma design system
struct FormaFolderPicker: View {
    let title: String
    let displayPath: String
    let hasSelection: Bool
    var hasError: Bool = false
    let onSelect: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(title)
                .font(.formaBodySemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: hasSelection ? "folder.fill" : "folder.badge.plus")
                        .font(.formaBodyLarge)
                        .foregroundStyle(hasSelection ? Color.formaSteelBlue : Color.formaSecondaryLabel)

                    Text(displayPath.isEmpty ? "Select a folder…" : displayPath)
                        .font(.formaBodySemibold)
                        .foregroundStyle(hasSelection ? Color.formaLabel : Color.formaSecondaryLabel)

                    Spacer()

                    if hasSelection {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.formaSecondaryLabel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(FormaSpacing.standard - FormaSpacing.micro)
                .background(Color.formaCardBackground)
                .formaCornerRadius(FormaRadius.control)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .strokeBorder(
                            hasError ? Color.formaWarmOrange : (hasSelection ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong) : Color.formaSeparator.opacity(Color.FormaOpacity.strong)),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}
