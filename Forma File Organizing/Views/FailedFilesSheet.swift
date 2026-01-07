//
//  FailedFilesSheet.swift
//  Forma - Failed Files Display
//
//  Shows files that failed organization with their specific error reasons.
//  Users can retry or dismiss individual failures.
//

import SwiftUI

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
        .frame(width: 480, height: min(400, CGFloat(100 + failedFiles.count * 72)))
        .background(Color.formaBackground)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("Organization Failed")
                        .font(.formaH2)
                        .foregroundColor(.formaObsidian)
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
            }
            .buttonStyle(.plain)
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
                .lineLimit(2)

            Spacer()

            // Actions
            HStack(spacing: FormaSpacing.standard) {
                Button("Dismiss") {
                    dismiss()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Retry All") {
                    dismiss()
                    onRetry()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(failedFiles.isEmpty)
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

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            // File icon
            Image(systemName: file.iconName)
                .font(.system(size: 24))
                .foregroundColor(.formaSecondaryLabel)
                .frame(width: 32)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaObsidian)
                    .lineLimit(1)

                // Error reason
                if let error = file.lastOrganizeError {
                    Text(formatError(error))
                        .font(.formaCaption)
                        .foregroundColor(.orange)
                        .lineLimit(2)
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
            }

            Spacer()
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaCardBackground)
        .cornerRadius(FormaRadius.small)
    }

    /// Formats the error message for display.
    /// Extracts the key information without verbose technical details.
    private func formatError(_ error: String) -> String {
        // Common patterns to make more user-friendly
        if error.contains("requires folder access") {
            return "Destination folder not accessible - grant access in Settings"
        }
        if error.contains("No such file or directory") {
            return "File no longer exists at original location"
        }
        if error.contains("Permission denied") {
            return "Permission denied - check folder permissions"
        }
        if error.contains("not enough space") || error.contains("disk is full") {
            return "Not enough disk space"
        }
        if error.contains("file exists") {
            return "A file with this name already exists at destination"
        }

        // Return original if no pattern matched, but truncate if too long
        if error.count > 80 {
            return String(error.prefix(77)) + "..."
        }
        return error
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
