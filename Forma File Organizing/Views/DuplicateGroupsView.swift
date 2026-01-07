import SwiftUI

/// View for displaying detected duplicate file groups.
///
/// Shows duplicate groups organized by type (exact, version series, near-duplicate)
/// with actions to resolve them and display potential space savings.
struct DuplicateGroupsView: View {
    let groups: [DuplicateDetectionService.DuplicateGroup]
    var onKeepFile: (FileItem, DuplicateDetectionService.DuplicateGroup) -> Void
    var onRemoveFile: (FileItem, DuplicateDetectionService.DuplicateGroup) -> Void
    var onDismissGroup: (DuplicateDetectionService.DuplicateGroup) -> Void

    @State private var expandedGroupIds: Set<UUID> = []

    private let duplicateService = DuplicateDetectionService()

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            if groups.isEmpty {
                emptyState
            } else {
                header
                summaryCard
                groupsList
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.doc.fill")
                .font(.formaH2)
                .foregroundColor(.formaSteelBlue)

            VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                Text("Duplicate Files")
                    .font(.formaH3)
                    .foregroundColor(.formaLabel)

                Text("\(groups.count) group\(groups.count == 1 ? "" : "s") found")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()
        }
        .padding(.horizontal, FormaSpacing.large)
        .padding(.top, FormaSpacing.standard)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let totalSavings = duplicateService.totalPotentialSavings(from: groups)
        let exactCount = groups.filter { $0.type == .exactDuplicate }.count
        let versionCount = groups.filter { $0.type == .versionSeries }.count
        let nearCount = groups.filter { $0.type == .nearDuplicate }.count

        return HStack(spacing: FormaSpacing.large) {
            // Potential savings
            VStack(alignment: .leading, spacing: 4) {
                Text("Potential Savings")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
                Text(duplicateService.formatBytes(totalSavings))
                    .font(.formaH2)
                    .foregroundColor(.formaSage)
            }

            Divider()
                .frame(height: 40)

            // Breakdown by type
            HStack(spacing: FormaSpacing.standard) {
                if exactCount > 0 {
                    TypeBadge(type: .exactDuplicate, count: exactCount)
                }
                if versionCount > 0 {
                    TypeBadge(type: .versionSeries, count: versionCount)
                }
                if nearCount > 0 {
                    TypeBadge(type: .nearDuplicate, count: nearCount)
                }
            }

            Spacer()
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSage.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSage.opacity(Color.FormaOpacity.medium), lineWidth: 1)
        )
        .padding(.horizontal, FormaSpacing.large)
    }

    // MARK: - Groups List

    private var groupsList: some View {
        ScrollView {
            LazyVStack(spacing: FormaSpacing.standard) {
                ForEach(groups) { group in
                    DuplicateGroupCard(
                        group: group,
                        isExpanded: expandedGroupIds.contains(group.id),
                        onToggleExpand: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedGroupIds.contains(group.id) {
                                    expandedGroupIds.remove(group.id)
                                } else {
                                    expandedGroupIds.insert(group.id)
                                }
                            }
                        },
                        onKeepFile: { file in
                            onKeepFile(file, group)
                        },
                        onRemoveFile: { file in
                            onRemoveFile(file, group)
                        },
                        onDismiss: {
                            onDismissGroup(group)
                        }
                    )
                }
            }
            .padding(.horizontal, FormaSpacing.large)
            .padding(.vertical, FormaSpacing.standard)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FormaSpacing.standard) {
            Image(systemName: "checkmark.circle.fill")
                .font(.formaIcon)
                .foregroundColor(.formaSage)

            Text("No duplicates found")
                .font(.formaH3)
                .foregroundColor(.formaLabel)

            Text("Your files are well-organized with no duplicate content detected")
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FormaSpacing.huge)
    }
}

// MARK: - Type Badge

private struct TypeBadge: View {
    let type: DuplicateDetectionService.DuplicateType
    let count: Int

    var body: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: type.iconName)
                .font(.formaCompact)
            Text("\(count)")
                .font(.formaSmallSemibold)
        }
        .foregroundColor(typeColor)
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(
            Capsule()
                .fill(typeColor.opacity(Color.FormaOpacity.light))
        )
    }

    private var typeColor: Color {
        switch type {
        case .exactDuplicate: return .formaWarmOrange
        case .versionSeries: return .formaSteelBlue
        case .nearDuplicate: return .formaTertiaryLabel
        }
    }
}

// MARK: - Duplicate Group Card

private struct DuplicateGroupCard: View {
    let group: DuplicateDetectionService.DuplicateGroup
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onKeepFile: (FileItem) -> Void
    let onRemoveFile: (FileItem) -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            header
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleExpand)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, FormaSpacing.large)

                filesList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(isHovered ? Color.formaBoneWhite.opacity(Color.FormaOpacity.prominent) : Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(
                    isHovered ? typeColor.opacity(Color.FormaOpacity.overlay) : Color.formaSeparator.opacity(Color.FormaOpacity.strong),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.formaObsidian.opacity(
                isHovered ? (Color.FormaOpacity.ultraSubtle * 3) : (Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle)
            ),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: 2
        )
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Type icon
            Image(systemName: group.type.iconName)
                .font(.formaH2)
                .foregroundColor(typeColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(typeColor.opacity(Color.FormaOpacity.light))
                )

            // Info
            VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                Text(group.description)
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaLabel)

                HStack(spacing: FormaSpacing.tight) {
                    Text(typeDisplayName)
                        .font(.formaCaption)
                        .foregroundColor(typeColor)

                    Text("•")
                        .foregroundColor(.formaTertiaryLabel)

                    Text(DuplicateDetectionService().formatBytes(group.potentialSpaceSavings) + " savings")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }
            }

            Spacer()

            // Expand/collapse chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.formaCompact)
                .foregroundColor(.formaTertiaryLabel)

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.formaCompact)
                    .foregroundColor(.formaTertiaryLabel)
            }
            .buttonStyle(.plain)
            .help("Dismiss this group")
        }
        .padding(FormaSpacing.large)
    }

    // MARK: - Files List

    private var filesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(group.files.enumerated()), id: \.element.path) { index, file in
                DuplicateFileRow(
                    file: file,
                    isFirst: index == 0,
                    suggestedAction: group.suggestedAction,
                    onKeep: { onKeepFile(file) },
                    onRemove: { onRemoveFile(file) }
                )

                if index < group.files.count - 1 {
                    Divider()
                        .padding(.leading, FormaSpacing.extraLarge + (FormaSpacing.standard - FormaSpacing.micro))
                }
            }
        }
        .padding(.bottom, FormaSpacing.standard)
    }

    // MARK: - Computed Properties

    private var typeColor: Color {
        switch group.type {
        case .exactDuplicate: return .formaWarmOrange
        case .versionSeries: return .formaSteelBlue
        case .nearDuplicate: return .formaTertiaryLabel
        }
    }

    private var typeDisplayName: String {
        switch group.type {
        case .exactDuplicate: return "Exact copies"
        case .versionSeries: return "Version series"
        case .nearDuplicate: return "Similar files"
        }
    }
}

// MARK: - Duplicate File Row

private struct DuplicateFileRow: View {
    let file: FileItem
    let isFirst: Bool
    let suggestedAction: DuplicateDetectionService.DuplicateGroup.SuggestedAction
    let onKeep: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Recommended badge for first file
            if isFirst && suggestedAction != .review {
                Image(systemName: "star.fill")
                    .font(.formaSmall)
                    .foregroundColor(.formaWarmOrange)
                    .frame(width: 24)
            } else {
                Spacer()
                    .frame(width: 24)
            }

            // File icon
            Image(systemName: file.iconName)
                .font(.formaBodyLarge)
                .foregroundColor(.formaSteelBlue)
                .frame(width: 24)

            // File info
            VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                Text(file.name)
                    .font(.formaBody)
                    .foregroundColor(.formaLabel)
                    .lineLimit(1)

                HStack(spacing: FormaSpacing.tight) {
                    Text(file.size)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)

                    Text("•")
                        .foregroundColor(.formaTertiaryLabel)

                    Text(abbreviatePath(file.path))
                        .font(.formaMono)
                        .foregroundColor(.formaTertiaryLabel)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action buttons (visible on hover)
            if isHovered {
                HStack(spacing: FormaSpacing.tight) {
                    Button(action: onKeep) {
                        Text("Keep")
                            .font(.formaSmallSemibold)
                            .foregroundColor(.formaSage)
                            .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
                            .padding(.vertical, FormaSpacing.micro)
                            .background(
                                Capsule()
                                    .fill(Color.formaSage.opacity(Color.FormaOpacity.light))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onRemove) {
                        Text("Remove")
                            .font(.formaSmallSemibold)
                            .foregroundColor(.formaWarmOrange)
                            .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
                            .padding(.vertical, FormaSpacing.micro)
                            .background(
                                Capsule()
                                    .fill(Color.formaWarmOrange.opacity(Color.FormaOpacity.light))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, FormaSpacing.large)
        .padding(.vertical, FormaSpacing.standard)
        .background(isHovered ? Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func abbreviatePath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        var result = path
        if result.hasPrefix(homeDir) {
            result = "~" + result.dropFirst(homeDir.count)
        }

        // Get parent directory
        let url = URL(fileURLWithPath: result)
        return url.deletingLastPathComponent().path
    }
}

// MARK: - Preview

#Preview("With Duplicates") {
    DuplicateGroupsView(
        groups: DuplicateDetectionService.DuplicateGroup.mocks,
        onKeepFile: { file, group in
            Log.debug("Preview keep duplicate: \\(file.name)", category: .analytics)
        },
        onRemoveFile: { file, group in
            Log.debug("Preview remove duplicate: \\(file.name)", category: .analytics)
        },
        onDismissGroup: { group in
            Log.debug("Preview dismiss duplicate group: \\(group.description)", category: .analytics)
        }
    )
    .frame(width: 500, height: 600)
    .background(Color.formaBackground)
}

#Preview("Empty State") {
    DuplicateGroupsView(
        groups: [],
        onKeepFile: { _, _ in },
        onRemoveFile: { _, _ in },
        onDismissGroup: { _ in }
    )
    .frame(width: 500, height: 400)
    .background(Color.formaBackground)
}
