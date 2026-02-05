import SwiftUI

struct StoragePanel: View {
    let analytics: StorageAnalytics
    let onCategoryTap: (FileTypeCategory) -> Void

    private let categories: [FileTypeCategory] = [.documents, .images, .videos, .audio, .archives]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {


            // Circular Chart
            StorageChart(analytics: analytics, size: 180)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, FormaSpacing.standard)

            // Legend
            VStack(spacing: FormaSpacing.tight) {
                ForEach(categories) { category in
                    StorageCategoryRow(
                        category: category,
                        analytics: analytics,
                        onTap: { onCategoryTap(category) }
                    )
                }
            }

            Spacer()
        }
        .padding(FormaSpacing.standard) // Reduced padding for tighter fit
        // Removed internal background and frame to allow parent control
    }
}


struct StorageCategoryRow: View {
    let category: FileTypeCategory
    let analytics: StorageAnalytics
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var rowBackground: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaBoneWhite.opacity(Color.FormaOpacity.strong)
    }

    private var rowBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.12)
            : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: FormaSpacing.tight) {
                // Color indicator
                Circle()
                    .fill(category.color)
                    .frame(width: FormaSpacing.tight, height: FormaSpacing.tight)

                // Category name
                Text(category.displayName)
                    .formaMetadataStyle()
                    .foregroundColor(.formaLabel)

                Spacer()

                // File count and size
                VStack(alignment: .trailing, spacing: FormaSpacing.micro / 2) {
                    Text("\(analytics.fileCountForCategory(category)) files")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabelHigh)

                    Text(analytics.formattedSizeForCategory(category))
                        .formaMetadataStyle()
                        .foregroundColor(.formaLabel)
                        .fontWeight(.medium)
                }
            }
            .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
            .padding(.horizontal, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                    .strokeBorder(rowBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(analytics.fileCountForCategory(category) > 0 ? 1.0 : Color.FormaOpacity.strong)
    }
}

// MARK: - Preview
#Preview {
    StoragePanel(
        analytics: StorageAnalytics(
            totalBytes: 158_273_331,
            categoryBreakdown: [
                .documents: 1_509_171,
                .images: 4_718_592,
                .videos: 0,
                .audio: 0,
                .archives: 152_043_520
            ],
            fileCount: 5,
            categoryFileCounts: [
                .documents: 2,
                .images: 1,
                .archives: 1
            ]
        ),
        onCategoryTap: { category in
            Log.debug("Preview tapped storage category: \(category.displayName)", category: .ui)
        }
    )
}
