import SwiftUI

/// Component that displays a collapsible group of files with the same suggested destination.
/// Provides batch actions for accepting or skipping all files in the group.
struct DestinationGroupView: View {
    let destination: String
    let files: [FileItem]
    var confidenceLevel: ConfidenceLevel? = nil
    var isExpanded: Bool = true
    var onToggle: () -> Void = {}
    var onAcceptAll: ([FileItem]) -> Void = { _ in }
    var onSkipAll: ([FileItem]) -> Void = { _ in }
    var onOrganizeFile: (FileItem) -> Void = { _ in }
    var onSkipFile: (FileItem) -> Void = { _ in }
    var onCreateRule: (FileItem) -> Void = { _ in }
    
    enum ConfidenceLevel: Hashable {
        case high, medium, low
        
        var displayName: String {
            switch self {
            case .high: return "High Confidence"
            case .medium: return "Medium Confidence"
            case .low: return "Low Confidence"
            }
        }
        
        var icon: String {
            switch self {
            case .high: return "checkmark.shield.fill"
            case .medium: return "checkmark.circle.fill"
            case .low: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .high: return .formaSage
            case .medium: return .formaSteelBlue
            case .low: return .formaWarmOrange
            }
        }
    }
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isHovered = false
    
    private var totalSize: Int64 {
        files.reduce(0) { $0 + $1.sizeInBytes }
    }
    
    private var averageConfidence: Double {
        let scores = files.compactMap { $0.confidenceScore }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private var computedConfidenceInfo: (label: String, color: Color) {
        let score = averageConfidence
        if score >= 0.9 {
            return ("High Confidence", .formaSage)
        } else if score >= 0.6 {
            return ("Medium Confidence", .formaSteelBlue)
        } else {
            return ("Low Confidence", .formaWarmOrange)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Group Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Expand/Collapse Icon
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.formaCompactSemibold)
                        .foregroundStyle(Color.formaSecondaryLabel)
                        .frame(width: 20)

                    // Folder Icon
                    Image(systemName: "folder.fill")
                        .font(.formaBodyMedium)
                        .foregroundStyle(Color.formaSteelBlue)

                    // Destination Path
                    VStack(alignment: .leading, spacing: 2) {
                        Text(truncatePath(destination))
                            .font(.formaBodySemibold)
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            // Confidence Badge (prominent)
                            if let level = confidenceLevel {
                                HStack(spacing: 4) {
                                    Image(systemName: level.icon)
                                        .font(.formaCaptionSemibold)
                                    Text(level.displayName)
                                        .font(.formaSmallSemibold)
                                }
                                .foregroundStyle(level.color)
                                .padding(.horizontal, FormaSpacing.tight)
                                .padding(.vertical, FormaSpacing.micro)
                                .background(level.color.opacity(Color.FormaOpacity.light))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(level.color.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                                )

                                Text("•")
                                    .font(.formaCaption)
                                    .foregroundStyle(Color.formaTertiaryLabel.opacity(Color.FormaOpacity.strong))
                            }

                            Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                                .font(.formaSmall)
                                .foregroundStyle(Color.formaSecondaryLabel)

                            Text("•")
                                .font(.formaCaption)
                                .foregroundStyle(Color.formaTertiaryLabel.opacity(Color.FormaOpacity.strong))

                            Text(formatBytes(totalSize))
                                .font(.formaSmall)
                                .foregroundStyle(Color.formaSecondaryLabel)
                        }
                    }
                    
                    Spacer()
                    
                    // Batch Actions (visible on hover)
                    if isHovered || isExpanded {
                        HStack(spacing: 8) {
                            Button(action: { onSkipAll(files) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "forward.fill")
                                        .font(.formaSmallSemibold)
                                    Text("Skip All")
                                        .font(.formaCompactMedium)
                                }
                                .foregroundStyle(Color.formaSecondaryLabel)
                                .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
                                .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
                                .background(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(action: { onAcceptAll(files) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.formaSmallSemibold)
                                    Text("Accept All (\(files.count))")
                                        .font(.formaCompactSemibold)
                                }
                                .foregroundStyle(Color.formaBoneWhite)
                                .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
                                .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
                                .background(Color.formaSage)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .padding(.horizontal, FormaSpacing.large)
                .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                .background(isHovered ? Color.formaCardBackground : Color.formaBackground)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            
            // File List (expandable)
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(files) { file in
                        FileRow(
                            file: file,
                            onOrganize: { onOrganizeFile($0) },
                            onSkip: { onSkipFile($0) },
                            onCreateRule: { onCreateRule($0) }
                        )
                        .padding(.horizontal, FormaSpacing.large)
                        
                        if file.id != files.last?.id {
                            Divider()
                                .padding(.leading, FormaSpacing.extraLarge + FormaSpacing.generous)
                        }
                    }
                }
                .padding(.vertical, FormaSpacing.tight)
                .background(Color.formaBackground)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.formaBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle), radius: 4, x: 0, y: 2)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isExpanded)
    }
    
    // MARK: - Helper Methods
    
    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        guard components.count > 3, let first = components.first else {
            return path
        }
        let last = components.suffix(2).joined(separator: "/")
        return "\(first)/…/\(last)"
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

#Preview("DestinationGroupView") {
    VStack(spacing: FormaSpacing.large) {
        DestinationGroupView(
            destination: "Documents/Finance/Invoices",
            files: [FileItem.mocks[0], FileItem.mocks[2]],
            isExpanded: true
        )

        DestinationGroupView(
            destination: "Pictures/Screenshots",
            files: [FileItem.mocks[1]],
            isExpanded: false
        )
    }
    .padding(FormaSpacing.generous)
    .background(Color.formaBackground)
    .frame(width: 800)
}
