import SwiftUI

struct FilterTabBar: View {
    @Binding var selectedCategory: FileTypeCategory
    let categoryFileCounts: [FileTypeCategory: Int]

    var body: some View {
        HStack(spacing: FormaSpacing.tight) {
            ForEach(FileTypeCategory.allCases, id: \.self) { category in
                FilterTab(
                    category: category,
                    isSelected: selectedCategory == category,
                    fileCount: categoryFileCounts[category] ?? 0,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                )
            }
            Spacer()
        }
        .padding(.horizontal, FormaSpacing.extraLarge)
        .padding(.vertical, FormaSpacing.tight)
        .background(Color.formaBoneWhite)
    }
}

struct FilterTab: View {
    let category: FileTypeCategory
    let isSelected: Bool
    let fileCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                Image(systemName: category.iconName)
                    .font(.formaCompact)
                    .foregroundColor(isSelected ? .formaBoneWhite : Color.formaObsidian)

                Text(category.displayName)
                    .formaBodyStyle()
                    .foregroundColor(isSelected ? .formaBoneWhite : Color.formaObsidian)

                // Badge with file count - only show if has files
                if fileCount > 0 {
                    Text("\(fileCount)")
                        .font(.formaCaption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? Color.formaSteelBlue : .formaBoneWhite)
                        .padding(.horizontal, FormaSpacing.tight - (FormaSpacing.micro / 2))
                        .padding(.vertical, FormaSpacing.micro / 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .formaBoneWhite : Color.formaSteelBlue)
                        )
                }
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
            .background(
                Capsule()
                    .fill(isSelected ? Color.formaSteelBlue : Color.formaBoneWhite)
            )
            .overlay(
                Capsule()
                    .stroke(Color.formaSteelBlue.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                    .opacity(isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: FormaSpacing.generous - FormaSpacing.micro) {
        FilterTabBar(
            selectedCategory: .constant(.all),
            categoryFileCounts: [
                .all: 42,
                .documents: 15,
                .images: 8,
                .videos: 3,
                .audio: 5,
                .archives: 11
            ]
        )

        FilterTabBar(
            selectedCategory: .constant(.images),
            categoryFileCounts: [
                .all: 42,
                .documents: 15,
                .images: 8,
                .videos: 3,
                .audio: 5,
                .archives: 11
            ]
        )
    }
    .frame(width: 800)
}
