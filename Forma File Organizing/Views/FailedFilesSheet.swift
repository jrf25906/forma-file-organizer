//
//  FailedFilesSheet.swift
//  Forma - Failed Files Display
//
//  Shows files that failed organization with their specific error reasons.
//  Users can retry or dismiss individual failures.
//

import SwiftUI
import AppKit

/// Sheet showing files that failed to organize, with error details.
///
/// Displays each failed file with:
/// - File name and icon
/// - The specific error that caused the failure
/// - Retry/dismiss actions
struct FailedFilesSheet: View {
    let failedFiles: [FileItem]
    let onRetry: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()

            // Failed files list
            if failedFiles.isEmpty {
                emptyState
            } else {
                filesList
            }

            Divider()

            // Footer with actions
            sheetFooter
        }
        .frame(minWidth: 540, idealWidth: 560, maxWidth: 680, minHeight: 360, idealHeight: min(560, CGFloat(180 + failedFiles.count * 96)), maxHeight: 680)
        .background(Color.formaBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("failedFilesSheet")
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.formaWarning)

                    Text("Organization Failed")
                        .font(.formaH2)
                        .foregroundColor(.formaLabel)
                }

                Text("\(failedFiles.count) file\(failedFiles.count == 1 ? "" : "s") couldn't be organized")
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()

            Button {
                dismiss()
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.formaSecondaryLabel)
                    .frame(width: 40, height: 40)
                    .contentShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close failed files")
            .accessibilityHint("Dismiss this dialog.")
        }
        .padding(.horizontal, FormaSpacing.generous)
        .padding(.vertical, FormaSpacing.standard)
    }

    // MARK: - Files List

    private var filesList: some View {
        ScrollView {
            LazyVStack(spacing: FormaSpacing.tight) {
                ForEach(failedFiles, id: \.path) { file in
                    FailedFileRow(file: file)
                }
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, FormaSpacing.standard)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FormaSpacing.standard) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.green)

            Text("All issues resolved")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
            // Help text
            Text("Fix the issues above and retry, or dismiss to skip these files.")
                .font(.formaCaption)
                .foregroundColor(.formaSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Actions
            HStack(spacing: FormaSpacing.standard) {
                Button("Dismiss") {
                    dismiss()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                .frame(minHeight: 40)
                .accessibilityHint("Close this dialog and keep these files unchanged.")

                Button("Retry All") {
                    dismiss()
                    onRetry()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(failedFiles.isEmpty)
                .frame(minHeight: 40)
                .help("Retry organizing all listed files")
                .accessibilityHint("Try organizing these files again.")
            }
        }
        .padding(.horizontal, FormaSpacing.generous)
        .padding(.vertical, FormaSpacing.standard)
    }
}

// MARK: - Failed File Row

/// A single row showing a failed file and its error.
private struct FailedFileRow: View {
    let file: FileItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: FormaSpacing.standard) {
            // File icon
            Image(systemName: file.iconName)
                .font(.system(size: 24))
                .foregroundColor(.formaSecondaryLabel)
                .frame(width: 32)

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaLabel)
                    .lineLimit(2)

                // Error reason
                if let error = file.lastOrganizeError, !error.isEmpty {
                    Text(formatError(error))
                        .font(.formaCaption)
                        .foregroundColor(.formaError)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                } else {
                    Text("Unknown error")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }

                // Destination
                if let destination = file.destination?.displayName {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                        Text(destination)
                            .lineLimit(1)
                    }
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
                }

                Text(file.path)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.formaSecondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: FormaSpacing.tight)

            Button {
                copyDetailsToPasteboard()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .frame(width: 40, height: 40)
                    .contentShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Copy failure details")
            .accessibilityLabel("Copy failure details for \(file.name)")
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(colorScheme == .dark ? Color.formaControlBackground.opacity(0.38) : Color.formaBoneWhite.opacity(0.70))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.26 : 0.12), lineWidth: FormaBorderWidth.thin)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    /// Formats the error message for display.
    /// Extracts the key information without verbose technical details.
    private func formatError(_ error: String) -> String {
        let lowercasedError = error.lowercased()

        // Common patterns to make more user-friendly
        if lowercasedError.contains("requires folder access") {
            return "Destination folder not accessible - grant access in Settings"
        }
        if lowercasedError.contains("no such file or directory") {
            return "File no longer exists at original location"
        }
        if lowercasedError.contains("permission denied") {
            return "Permission denied - check folder permissions"
        }
        if lowercasedError.contains("not enough space") || lowercasedError.contains("disk is full") {
            return "Not enough disk space"
        }
        if lowercasedError.contains("already exists") || lowercasedError.contains("file exists") {
            return "A matching file already exists at the destination. This file may already be organized."
        }

        // Return original if no pattern matched, but truncate if too long
        if error.count > 140 {
            return String(error.prefix(137)) + "..."
        }
        return error
    }

    private var accessibilitySummary: String {
        var parts = ["\(file.name)."]
        if let error = file.lastOrganizeError, !error.isEmpty {
            parts.append("\(formatError(error)).")
        } else {
            parts.append("Unknown error.")
        }
        if let destination = file.destination?.displayName {
            parts.append("Destination \(destination).")
        }
        return parts.joined(separator: " ")
    }

    private func copyDetailsToPasteboard() {
        let errorText = file.lastOrganizeError.map(formatError) ?? "Unknown error"
        let destination = file.destination?.displayName ?? "Not set"
        let details = """
        File: \(file.name)
        Source: \(file.path)
        Destination: \(destination)
        Error: \(errorText)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(details, forType: .string)
    }
}

// MARK: - Preview

#Preview {
    FailedFilesSheet(
        failedFiles: FileItem.mocks.prefix(3).map { file in
            let item = FileItem(
                path: file.path,
                sizeInBytes: file.sizeInBytes,
                creationDate: file.creationDate,
                destination: file.destination,
                status: .ready
            )
            item.lastOrganizeError = "Destination 'Screenshots' requires folder access - please select the folder in Settings"
            return item
        },
        onRetry: {},
        onDismiss: {}
    )
}
