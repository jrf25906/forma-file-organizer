//
//  FormaStatusPill.swift
//  Forma - Reusable UI Components
//
//  Implementation of Forma brand UI components
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

// MARK: - Status Pill

/// A compact pill-shaped indicator showing file organization status.
/// Used in FileRow to communicate the current state of a file to users.
///
/// Usage:
/// ```swift
/// FormaStatusPill(status: file.status)
/// ```
struct FormaStatusPill: View {
    let status: FileItem.OrganizationStatus

    private var config: (text: String, icon: String, color: Color) {
        switch status {
        case .pending:
            // Using muted blue instead of warm orange - calmer "needs attention" state
            // that doesn't feel alarming or compete with media category color
            return ("Needs Destination", "questionmark.circle", .formaTertiaryLabel)
        case .ready:
            return ("Ready", "checkmark.circle", .formaSage)
        case .completed:
            return ("Organized", "checkmark.seal.fill", .formaSage.opacity(Color.FormaOpacity.high))
        case .skipped:
            return ("Skipped", "forward.fill", .formaSecondaryLabel)
        }
    }

    var body: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: config.icon)
                .font(.formaMicro)
                .fontWeight(.semibold)
            Text(config.text)
                .font(.formaCaption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(config.color)
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(config.color.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle))
        .clipShape(Capsule())
    }
}

#Preview("Status Pills") {
    VStack(spacing: 12) {
        FormaStatusPill(status: .pending)
        FormaStatusPill(status: .ready)
        FormaStatusPill(status: .completed)
        FormaStatusPill(status: .skipped)
    }
    .padding()
    .background(Color.formaBackground)
}
