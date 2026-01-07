import SwiftUI
import SwiftData

/// View for displaying learned patterns as rule suggestions to the user.
///
/// Shows patterns detected from user behavior with confidence indicators
/// and allows one-click conversion to permanent rules.
struct RuleSuggestionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPatterns: [LearnedPattern]
    
    var onCreateRule: (LearnedPattern) -> Void
    var onDismiss: (LearnedPattern) -> Void
    
    // Filter to only show patterns that should be suggested
    private var suggestablePatterns: [LearnedPattern] {
        sortedPatterns.filter { $0.shouldSuggest }
    }

    private var sortedPatterns: [LearnedPattern] {
        allPatterns.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    var body: some View {
        // Only render content when patterns exist - empty state is handled
        // at the parent level to avoid "No suggestions" vs "TOP SUGGESTION" contradiction
        if !suggestablePatterns.isEmpty {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                header
                patternsList
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        // Sub-section label (lighter weight - parent shows "SUGGESTIONS" header)
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: "wand.and.stars")
                .font(.formaCaption)
            Text("Smart Rules")
                .font(.formaCompactMedium)
        }
        .foregroundStyle(Color.formaTertiaryLabel)
        .padding(.top, FormaSpacing.tight)
    }
    
    // MARK: - Patterns List
    
    private var patternsList: some View {
        ScrollView {
            LazyVStack(spacing: FormaSpacing.standard) {
                ForEach(suggestablePatterns) { pattern in
                    PatternCard(
                        pattern: pattern,
                        onCreateRule: {
                            onCreateRule(pattern)
                        },
                        onDismiss: {
                            pattern.recordRejection()
                            onDismiss(pattern)
                            do {
                                try modelContext.save()
                            } catch {
                                Log.error("Failed to save pattern rejection: \\(error.localizedDescription)", category: .analytics)
                            }
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
            Image(systemName: "sparkles")
                .font(.formaIcon)
                .foregroundColor(.formaTertiaryLabel)

            Text("No suggestions yet")
                .font(.formaH3)
                .foregroundColor(.formaLabel)
            
            Text("Keep organizing files manually and I'll learn your patterns")
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FormaSpacing.huge)
    }
}

// MARK: - Pattern Card

private struct PatternCard: View {
    let pattern: LearnedPattern
    let onCreateRule: () -> Void
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header with confidence badge
            HStack(spacing: FormaSpacing.standard) {
                // File type icon
                Image(systemName: extensionIcon(pattern.fileExtension))
                    .font(.formaH1)
                    .foregroundColor(extensionColor(pattern.fileExtension))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(extensionColor(pattern.fileExtension).opacity(Color.FormaOpacity.light))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.patternDescription)
                        .font(.formaBodyMedium)
                        .foregroundColor(.formaLabel)
                        .lineLimit(2)

                    HStack(spacing: FormaSpacing.tight) {
                        // Confidence badge
                        HStack(spacing: FormaSpacing.micro) {
                            Image(systemName: confidenceIcon)
                                .font(.formaCaptionSemibold)
                            Text(pattern.confidenceLevel)
                                .font(.formaSmallSemibold)
                        }
                        .foregroundColor(confidenceColor)
                        .padding(.horizontal, FormaSpacing.tight)
                        .padding(.vertical, FormaSpacing.micro)
                        .background(
                            Capsule()
                                .fill(confidenceColor.opacity(Color.FormaOpacity.light))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(confidenceColor.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                        )

                        Text("•")
                            .foregroundColor(.formaTertiaryLabel)
                            .font(.formaCaption)
                        
                        Text("\(pattern.occurrenceCount) times")
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }
                
                Spacer()
            }
            
            // Destination preview
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "arrow.right")
                    .font(.formaCompact)
                    .foregroundColor(.formaSecondaryLabel)

                HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                    Image(systemName: "folder.fill")
                        .font(.formaSmall)
                        .foregroundColor(.formaSteelBlue)

                    Text(abbreviatePath(pattern.destinationPath))
                        .font(.formaMono)
                        .foregroundColor(.formaLabel)
                        .lineLimit(1)
                }
                .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
                .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
                .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                .formaCornerRadius(FormaRadius.small)
            }
            .padding(.leading, FormaSpacing.extraLarge + FormaSpacing.micro) // Align with text above
            
            // Action buttons
            HStack(spacing: FormaSpacing.tight) {
                Button(action: onCreateRule) {
                    HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                        Image(systemName: "plus.circle.fill")
                            .font(.formaBodySemibold)
                        Text("Create Rule")
                            .font(.formaBodySemibold)
                    }
                    .foregroundColor(.formaBoneWhite)
                    .padding(.horizontal, FormaSpacing.large)
                    .padding(.vertical, FormaSpacing.Button.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                            .fill(Color.formaSteelBlue)
                    )
                    .shadow(color: Color.formaSteelBlue.opacity(Color.FormaOpacity.medium), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.formaBodyMedium)
                        .foregroundColor(.formaSecondaryLabel)
                        .padding(.horizontal, FormaSpacing.large)
                        .padding(.vertical, FormaSpacing.Button.vertical)
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                .strokeBorder(Color.formaSeparator, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.top, FormaSpacing.tight)
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(
                    isHovered
                        ? Color.formaBoneWhite.opacity(Color.FormaOpacity.prominent)
                        : Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(
                    isHovered ? Color.formaSteelBlue.opacity(Color.FormaOpacity.medium) : Color.formaSeparator.opacity(Color.FormaOpacity.strong),
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
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // MARK: - Computed Properties
    
    private var confidenceIcon: String {
        switch pattern.confidenceScore {
        case 0.7...:
            return "checkmark.shield.fill"
        case 0.5..<0.7:
            return "checkmark.circle.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var confidenceColor: Color {
        switch pattern.confidenceScore {
        case 0.7...:
            return .formaSage
        case 0.5..<0.7:
            return .formaSteelBlue
        default:
            return .formaWarmOrange
        }
    }
    
    // MARK: - Helper Functions
    
    private func extensionIcon(_ ext: String) -> String {
        let category = FileTypeCategory.category(for: ext)
        return category.iconName
    }
    
    private func extensionColor(_ ext: String) -> Color {
        let category = FileTypeCategory.category(for: ext)
        return category.color
    }
    
    private func abbreviatePath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        
        // Truncate if too long
        if path.count > 40 {
            let components = path.split(separator: "/")
            if components.count > 2 {
                return "…/" + components.suffix(2).joined(separator: "/")
            }
        }
        
        return path
    }
}

// MARK: - Preview

@MainActor
private enum RuleSuggestionViewPreview {
    static func withPatterns() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: LearnedPattern.self,
            configurations: config
        )

        LearnedPattern.mocks.forEach { container.mainContext.insert($0) }

        return RuleSuggestionView(
            onCreateRule: { pattern in
                Log.debug("Preview create rule for: \\(pattern.patternDescription)", category: .analytics)
            },
            onDismiss: { pattern in
                Log.debug("Preview dismissed pattern: \\(pattern.patternDescription)", category: .analytics)
            }
        )
        .modelContainer(container)
        .frame(width: 400, height: 600)
        .background(Color.formaBackground)
    }

    static func emptyState() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: LearnedPattern.self,
            configurations: config
        )

        return RuleSuggestionView(
            onCreateRule: { _ in },
            onDismiss: { _ in }
        )
        .modelContainer(container)
        .frame(width: 400, height: 600)
        .background(Color.formaBackground)
    }
}

#Preview("With Patterns") {
    RuleSuggestionViewPreview.withPatterns()
}

#Preview("Empty State") {
    RuleSuggestionViewPreview.emptyState()
}
