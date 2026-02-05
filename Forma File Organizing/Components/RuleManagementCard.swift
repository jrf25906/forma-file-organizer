import Foundation
import SwiftUI

// MARK: - Rule Management Card

struct RuleManagementCard: View {
    static let verticalPadding: CGFloat = FormaSpacing.tight

    let rule: Rule
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    private let destinationResolver = DestinationResolver()
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingDeleteConfirmation = false
    @State private var isHovered = false
    private let isUITesting = CommandLine.arguments.contains("--uitesting")
    
    // Icon based on primary condition
    private var ruleIcon: String {
        if let firstCondition = rule.conditions.first {
            return icon(for: firstCondition.type)
        }
        // Fallback or legacy single condition
        return icon(for: rule.conditionType)
    }
    
    // Helper to map type to icon
    private func icon(for type: Rule.ConditionType) -> String {
        switch type {
        case .fileExtension: return "doc.text"
        case .nameContains, .nameStartsWith, .nameEndsWith: return "text.quote"
        case .sizeLargerThan: return "archivebox"
        case .dateOlderThan, .dateModifiedOlderThan, .dateAccessedOlderThan: return "calendar"
        case .fileKind: return "square.grid.2x2"
        case .sourceLocation: return "folder"
        }
    }
    
    // Formatted "Sentence" description
    private var descriptionText: some View {
        Group {
            if rule.conditions.isEmpty {
                // Legacy single
                HStack(spacing: 0) {
                    Text("If ")
                        .foregroundColor(secondaryTextColor)
                    Text(rule.conditionType.rawValue.camelCaseToTitleCase())
                        .foregroundColor(.formaLabel)
                    Text(" is ")
                        .foregroundColor(secondaryTextColor)
                    Text(rule.conditionValue)
                        .foregroundColor(.formaLabel)
                }
            } else {
                // Compound
                let count = rule.conditions.count
                HStack(spacing: 0) {
                    Text("Matches ")
                        .foregroundColor(secondaryTextColor)
                    Text("\(count) conditions")
                        .foregroundColor(.formaLabel)
                }
            }
        }
    }
    
    private var actionIcon: String {
        switch rule.actionType {
        case .move: return "folder.fill"
        case .copy: return "plus.square.on.square.fill"
        case .delete: return "trash.fill"
        }
    }

    private var destinationWarning: DestinationResolver.ResolvabilityStatus? {
        guard rule.actionType != .delete,
              let destination = rule.destination else {
            return nil
        }

        let status = destinationResolver.checkResolvability(destination)
        if case .unresolvable = status {
            return status
        }
        return nil
    }

    private var destinationWarningMessage: String? {
        guard let destinationWarning else { return nil }
        switch destinationWarning {
        case .unresolvable(let reason):
            return reason
        default:
            return nil
        }
    }

    private var destinationTextColor: Color {
        destinationWarning == nil ? secondaryTextColor : .formaWarmOrange
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel
    }

    private var iconCircleBackground: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.08) : .formaControlBackground
    }

    private var iconCircleBorder: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaSeparator.opacity(0.5)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.06) : .formaBoneWhite
    }

    private var cardBorder: Color {
        if isHovered {
            return colorScheme == .dark
                ? Color.formaSteelBlue.opacity(0.45)
                : Color.formaSteelBlue.opacity(0.3)
        }
        return colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaSeparator.opacity(0.5)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(isHovered ? 0.22 : 0.12)
            : Color.black.opacity(isHovered ? 0.08 : 0.02)
    }

    private var disabledBadgeBackground: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.1) : .formaControlBackground
    }

    private var offToggleTrackColor: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.18) : .formaControlBackground
    }

    private var toggleThumbColor: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.95) : .white
    }

    private var titleOnCardContrastRatio: Double {
        FormaContrastMetrics.contrastRatio(
            foreground: .formaLabel,
            background: cardBackground,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var secondaryOnCardContrastRatio: Double {
        FormaContrastMetrics.contrastRatio(
            foreground: secondaryTextColor,
            background: cardBackground,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }
    
    var body: some View {
        HStack(spacing: FormaSpacing.tight) {
            // 1. Leading Icon
            ZStack {
                Circle()
                    .fill(iconCircleBackground)
                    .frame(width: 36, height: 36)
                
                Image(systemName: ruleIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.formaSteelBlue)
            }
            .overlay(
                Circle()
                    .strokeBorder(iconCircleBorder, lineWidth: 1)
            )
            
            // 2. Main Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    Text(rule.name)
                        .font(.formaBodyBold)
                        .foregroundColor(rule.isEnabled ? .formaLabel : secondaryTextColor)

                    if !rule.isEnabled {
                        Text("Disabled")
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(disabledBadgeBackground)
                            .cornerRadius(4)
                    }

                    if let warningMessage = destinationWarningMessage {
                        Text("Needs Access")
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundColor(.formaWarmOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.formaWarmOrange.opacity(0.15))
                            .cornerRadius(4)
                            .help(warningMessage)
                    }
                }
                
                HStack(spacing: 4) {
                    descriptionText
                        .font(.formaSmall)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(tertiaryTextColor.opacity(0.7))
                        .padding(.horizontal, 2)
                    
                    Image(systemName: actionIcon)
                        .font(.formaCompact)
                        .foregroundColor(secondaryTextColor)

                    if destinationWarningMessage != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.formaWarmOrange)
                    }

                    Text(rule.actionType == .delete ? "Delete" : rule.destinationDisplayText)
                        .font(.formaSmall)
                        .foregroundColor(destinationTextColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            // 3. Actions (Hover or Toggle)
            // 3. Actions (Hover) and 4. Toggle
            HStack(spacing: 8) {
                if isHovered {
                    HStack(spacing: 4) {
                        IconButton(icon: "pencil", color: .formaSecondaryLabel) {
                            onEdit()
                        }
                        .help("Edit Rule")
                        
                        IconButton(icon: "trash", color: .formaError) {
                            showingDeleteConfirmation = true
                        }
                        .help("Delete Rule")
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                
                // Toggle Indicator (Always Visible)
                Button(action: onToggle) {
                    ZStack {
                        Capsule()
                            .fill(rule.isEnabled ? Color.formaSteelBlue : offToggleTrackColor)
                            .frame(width: 32, height: 18)
                        
                        Circle()
                            .fill(toggleThumbColor)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .offset(x: rule.isEnabled ? 7 : -7)
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: rule.isEnabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, Self.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .shadow(
            color: cardShadowColor,
            radius: isHovered ? 8 : 2,
            x: 0,
            y: isHovered ? 2 : 1
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .alert("Delete Rule", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(rule.name)\"? This action cannot be undone.")
        }
        .accessibilityIdentifier("ruleManagementCard")
        .accessibilityLabel(
            isUITesting
                ? "titleOnCard=\(String(format: "%.2f", titleOnCardContrastRatio));secondaryOnCard=\(String(format: "%.2f", secondaryOnCardContrastRatio))"
                : ""
        )
        .accessibilityValue(
            isUITesting
                ? "titleOnCard=\(String(format: "%.2f", titleOnCardContrastRatio));secondaryOnCard=\(String(format: "%.2f", secondaryOnCardContrastRatio))"
                : ""
        )
        .overlay {
            if isUITesting {
                Color.clear
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("ruleManagementCardProbe")
                    .accessibilityLabel(
                        "titleOnCard=\(String(format: "%.2f", titleOnCardContrastRatio));secondaryOnCard=\(String(format: "%.2f", secondaryOnCardContrastRatio))"
                    )
            }
        }
    }
}

// Helper for hover buttons
private struct IconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryColor: Color {
        colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovered ? color : secondaryColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovered ? color.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
