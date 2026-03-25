import SwiftUI

struct MenuBarFileReviewCard: View {
    struct Snapshot {
        let destinationTitle: String
        let destinationName: String
        let destinationDetail: String
        let destinationIconName: String
        let destinationTint: Color
        let matchReason: String?

        init(file: FileItem) {
            self.destinationTitle = "Destination"
            self.destinationName = file.destinationDisplayName ?? "No destination assigned"
            self.destinationDetail = file.hasDestination
                ? "Ready to move now"
                : "Set a destination in the main app to organize this file."
            self.destinationIconName = "arrow.turn.down.right"
            self.destinationTint = file.hasDestination ? .formaSteelBlue : .formaWarning
            self.matchReason = file.matchReason.flatMap { reason in
                reason.isEmpty ? nil : reason
            }
        }
    }

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

    private var snapshot: Snapshot {
        Snapshot(file: file)
    }

    var body: some View {
        MenuBarSurface(
            tier: .raised,
            tint: cardTint,
            cornerRadius: FormaRadius.card,
            padding: FormaSpacing.tight
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                fileHeaderRow
                metadataBlock
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
            return Color.formaSteelBlue.opacity(colorScheme == .dark ? 0.10 : 0.05)
        }

        return Color.formaWarning.opacity(colorScheme == .dark ? 0.10 : 0.05)
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
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: file.iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(accentTint)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)
                    .lineLimit(1)

                Text(file.size)
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer(minLength: 0)

            FormaStatusPill(status: file.status)
        }
    }

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            destinationRow

            if let matchReason = snapshot.matchReason {
                HStack(alignment: .top, spacing: FormaSpacing.tight) {
                    Image(systemName: "sparkles")
                        .font(.formaCaptionSemibold)
                        .foregroundColor(.formaSteelBlue)
                        .padding(.top, 2)

                    Text(matchReason)
                        .font(.formaMenuMetadata)
                        .foregroundColor(.formaSecondaryLabelHigh)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 20)
            }
        }
        .padding(.top, 2)
    }

    private var destinationRow: some View {
        HStack(alignment: .top, spacing: FormaSpacing.tight) {
            Image(systemName: snapshot.destinationIconName)
                .font(.formaCaptionSemibold)
                .foregroundColor(snapshot.destinationTint)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.destinationName)
                    .font(.formaBody)
                    .foregroundColor(.formaLabel)
                    .lineLimit(2)

                Text(snapshot.destinationDetail)
                    .font(.formaMenuMetadata)
                    .foregroundColor(file.hasDestination ? .formaSecondaryLabel : .formaWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private var actionButtonsRow: some View {
        HStack(spacing: FormaSpacing.tight) {
            Button(action: onSkip) {
                Text("Skip")
                    .font(.formaCompactSemibold)
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
                            .font(.formaCompactSemibold)
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
        VStack(spacing: 6) {
            MenuBarDivider()

            HStack(spacing: FormaSpacing.tight) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.formaCaptionSemibold)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(MenuBarButtonStyle(kind: .utility))
                .disabled(!canGoBack)
                .accessibilityLabel("Previous file")

                Spacer(minLength: 0)

                Text(paginationText)
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaTertiaryLabelHigh)
                    .monospacedDigit()

                Spacer(minLength: 0)

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.formaCaptionSemibold)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(MenuBarButtonStyle(kind: .utility))
                .disabled(!canGoForward)
                .accessibilityLabel("Next file")
            }
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
