//
//  MenuBarFileReviewCard.swift
//  Forma - Menu Bar File Review Card
//
//  A self-contained file review card for the Forma menu bar mini app.
//  Shows one file at a time with organize/skip actions and pagination.
//

import SwiftUI

struct MenuBarFileReviewCard: View {
    let file: FileItem
    let paginationText: String
    let isOrganizing: Bool
    let canGoBack: Bool
    let canGoForward: Bool

    let onOrganize: () -> Void
    let onSkip: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Adaptive Colors

    private var cardBackground: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.06) : .formaBoneWhite
    }

    private var cardBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaSeparator.opacity(0.5)
    }

    private var cardShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.12)
            : Color.black.opacity(0.04)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            // Row 1: File icon + file name
            fileHeaderRow

            // Row 2: Destination display name
            destinationRow

            // Row 3: Rule badge (optional)
            if let matchReason = file.matchReason {
                ruleBadge(matchReason)
            }

            // Row 4: Action buttons
            actionButtonsRow

            // Row 5: Pagination
            paginationRow
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .shadow(color: cardShadow, radius: 3, x: 0, y: 1)
        .id(file.path)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
    }

    private var iconCircleBackground: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.08) : .formaControlBackground
    }

    private var iconCircleBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaSeparator.opacity(0.5)
    }

    // MARK: - Row 1: File Header

    private var fileHeaderRow: some View {
        HStack(spacing: FormaSpacing.tight) {
            ZStack {
                Circle()
                    .fill(iconCircleBackground)
                    .frame(width: 32, height: 32)

                Image(systemName: file.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.formaSteelBlue)
            }
            .overlay(
                Circle()
                    .strokeBorder(iconCircleBorder, lineWidth: 1)
            )

            Text(file.name)
                .font(.formaMenuTitle)
                .foregroundColor(.formaLabel)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Row 2: Destination

    private var destinationRow: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: "arrow.right")
                .font(.formaMenuMetadata)
                .foregroundColor(.formaTertiaryLabel)

            Text(file.destinationDisplayName ?? "No destination")
                .font(.formaMenuMetadata)
                .foregroundColor(.formaSecondaryLabel)
                .lineLimit(1)
        }
    }

    // MARK: - Row 3: Rule Badge

    private func ruleBadge(_ reason: String) -> some View {
        Text(reason)
            .font(.formaMenuMetadata)
            .foregroundColor(.formaSecondaryLabel)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(Color.formaLabel.opacity(0.06))
            .formaCornerRadius(FormaRadius.pill)
    }

    // MARK: - Row 4: Action Buttons

    private var skipButtonBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.18)
            : Color.formaObsidian.opacity(0.15)
    }

    private var actionButtonsRow: some View {
        HStack(spacing: FormaSpacing.tight) {
            // Skip button (secondary style with border)
            Button(action: onSkip) {
                Text("Skip")
                    .font(.formaMenuItem)
                    .foregroundColor(.formaSecondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.tight)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                            .strokeBorder(skipButtonBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // Organize button (primary style)
            Button(action: onOrganize) {
                Group {
                    if isOrganizing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.formaBoneWhite)
                    } else {
                        Text("Organize")
                            .font(.formaMenuTitle)
                            .foregroundColor(.formaBoneWhite)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.tight)
            }
            .buttonStyle(.plain)
            .background(Color.formaSage)
            .formaCornerRadius(FormaRadius.control)
            .contentShape(Rectangle())
            .disabled(isOrganizing)
        }
    }

    // MARK: - Row 5: Pagination

    private var paginationRow: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.formaMenuMetadata)
                    .foregroundColor(canGoBack ? .formaSecondaryLabel : .formaTertiaryLabel)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            Spacer()

            Text(paginationText)
                .font(.formaMenuMetadata)
                .foregroundColor(.formaTertiaryLabel)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.formaMenuMetadata)
                    .foregroundColor(canGoForward ? .formaSecondaryLabel : .formaTertiaryLabel)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
    }
}

// MARK: - Preview

#Preview("MenuBarFileReviewCard") {
    let mockFile: FileItem = {
        let item = FileItem(
            path: "/Users/test/Downloads/Invoice_2026_Q1.pdf",
            sizeInBytes: 1_258_291,
            creationDate: Date(),
            destination: FileItem.mockDestination(displayName: "Documents/Finance"),
            status: .ready
        )
        item.matchReason = "Matched: PDF invoices rule"
        return item
    }()

    VStack(spacing: 16) {
        // Standard state
        MenuBarFileReviewCard(
            file: mockFile,
            paginationText: "1 of 5",
            isOrganizing: false,
            canGoBack: false,
            canGoForward: true,
            onOrganize: {},
            onSkip: {},
            onPrevious: {},
            onNext: {}
        )

        // Organizing state
        MenuBarFileReviewCard(
            file: mockFile,
            paginationText: "1 of 5",
            isOrganizing: true,
            canGoBack: false,
            canGoForward: true,
            onOrganize: {},
            onSkip: {},
            onPrevious: {},
            onNext: {}
        )

        // No destination, no rule
        MenuBarFileReviewCard(
            file: FileItem(
                path: "/Users/test/Downloads/random_file.zip",
                sizeInBytes: 50_000,
                creationDate: Date(),
                destination: nil,
                status: .pending
            ),
            paginationText: "3 of 8",
            isOrganizing: false,
            canGoBack: true,
            canGoForward: true,
            onOrganize: {},
            onSkip: {},
            onPrevious: {},
            onNext: {}
        )
    }
    .padding()
    .frame(width: 320)
    .background(Color.formaBackground)
}
