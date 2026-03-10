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

    var body: some View {
        MenuBarSurface(
            tier: .base,
            tint: cardTint,
            cornerRadius: FormaRadius.card,
            padding: FormaSpacing.standard
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                fileHeaderRow
                destinationSummary
                actionButtonsRow
                paginationRow
            }
        }
        .id(file.path)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
    }

    private var cardTint: Color {
        if file.hasDestination {
            return Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.18 : 0.12)
        }

        return Color.formaWarning.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }

    private var accentTint: Color {
        file.hasDestination ? .formaSteelBlue : .formaWarning
    }

    private var fileHeaderRow: some View {
        HStack(alignment: .top, spacing: FormaSpacing.tight) {
            FormaChromeSurface(
                cornerRadius: FormaRadius.control,
                fill: colorScheme == .dark
                    ? Color.formaControlBackground.opacity(0.82)
                    : Color.formaBoneWhite.opacity(0.94),
                tint: accentTint,
                elevation: .raised
            )
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: file.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accentTint)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
                    .lineLimit(2)

                Text(file.size)
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer(minLength: 0)

            FormaStatusPill(status: file.status)
        }
    }

    private var destinationSummary: some View {
        MenuBarSurface(
            tier: .base,
            tint: accentTint.opacity(colorScheme == .dark ? 0.18 : 0.10),
            cornerRadius: FormaRadius.control,
            padding: FormaSpacing.tight
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                HStack(alignment: .top, spacing: FormaSpacing.tight) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.formaCaptionSemibold)
                        .foregroundColor(.formaSecondaryLabel)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.destinationDisplayName ?? "No destination assigned")
                            .font(.formaBody)
                            .foregroundColor(file.hasDestination ? .formaLabel : .formaSecondaryLabel)
                            .lineLimit(2)

                        Text(file.hasDestination ? "Destination" : "Needs a destination before organizing")
                            .font(.formaMenuMetadata)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }

                if let matchReason = file.matchReason, !matchReason.isEmpty {
                    HStack(alignment: .top, spacing: FormaSpacing.tight) {
                        Image(systemName: "sparkles")
                            .font(.formaCaptionSemibold)
                            .foregroundColor(.formaSteelBlue)
                            .padding(.top, 2)

                        Text(matchReason)
                            .font(.formaMenuMetadata)
                            .foregroundColor(.formaSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var actionButtonsRow: some View {
        HStack(spacing: FormaSpacing.tight) {
            Button(action: onSkip) {
                Text("Skip")
                    .font(.formaBody)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MenuBarButtonStyle(kind: .secondary(nil)))

            Button(action: onOrganize) {
                Group {
                    if isOrganizing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.formaBoneWhite)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Organize")
                            .font(.formaBodySemibold)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(MenuBarButtonStyle(kind: .primary(.formaSage)))
            .disabled(isOrganizing || !file.hasDestination)
            .help(file.hasDestination ? "Move this file to its destination" : "Set a destination before organizing")
        }
    }

    private var paginationRow: some View {
        HStack(spacing: FormaSpacing.tight) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.formaCaptionSemibold)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(MenuBarButtonStyle(kind: .utility))
            .disabled(!canGoBack)
            .accessibilityLabel("Previous file")

            Spacer(minLength: 0)

            Text(paginationText)
                .font(.formaMenuMetadata)
                .foregroundColor(.formaTertiaryLabel)
                .monospacedDigit()

            Spacer(minLength: 0)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.formaCaptionSemibold)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(MenuBarButtonStyle(kind: .utility))
            .disabled(!canGoForward)
            .accessibilityLabel("Next file")
        }
    }
}

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

    VStack(spacing: FormaSpacing.standard) {
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
