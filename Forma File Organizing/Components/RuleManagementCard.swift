import Foundation
import SwiftUI

// MARK: - Rule Management Card

struct RuleManagementCard: View {
    struct Snapshot: Identifiable {
        struct CategoryBadge {
            let name: String
            let color: Color
        }

        enum Description {
            case legacy(typeLabel: String, value: String)
            case compound
        }

        let id: UUID
        let name: String
        let isEnabled: Bool
        let iconName: String
        let description: Description
        let actionType: Rule.ActionType
        let destinationDisplayText: String
        let lastTriggeredDate: Date?
        let health: RuleHealthService.RuleHealth
        let categoryBadge: CategoryBadge?
        let scopeDetailMessage: String?

        @MainActor
        init(rule: Rule, health: RuleHealthService.RuleHealth? = nil) {
            let category = rule.category

            self.id = rule.id
            self.name = rule.name
            self.isEnabled = rule.isEnabled
            self.iconName = RuleManagementCard.icon(for: rule.conditionType)
            self.description = rule.logicalOperator == .single
                ? .legacy(
                    typeLabel: rule.conditionType.rawValue.camelCaseToTitleCase(),
                    value: rule.conditionValue
                )
                : .compound
            self.actionType = rule.actionType
            self.destinationDisplayText = rule.actionType == .delete ? "Delete" : rule.destinationDisplayText
            self.lastTriggeredDate = rule.lastTriggeredDate
            self.health = health ?? RuleManagementCard.fallbackHealth(for: rule)

            if let category, !category.isDefault || !category.scope.isGlobal {
                self.categoryBadge = CategoryBadge(name: category.name, color: category.color)
            } else {
                self.categoryBadge = nil
            }

            if let category, !category.scope.isGlobal {
                self.scopeDetailMessage = "Applies to \(category.scope.displayDescription)"
            } else {
                self.scopeDetailMessage = nil
            }
        }
    }

    static let verticalPadding: CGFloat = FormaSpacing.tight
    private static let destinationResolver = DestinationResolver()

    let snapshot: Snapshot
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingDeleteConfirmation = false
    @State private var isHovered = false
    private let isUITesting = CommandLine.arguments.contains("--uitesting")
    
    // Helper to map type to icon
    private static func icon(for type: Rule.ConditionType) -> String {
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
            switch snapshot.description {
            case .legacy(let typeLabel, let value):
                HStack(spacing: 0) {
                    Text("If ")
                        .foregroundColor(secondaryTextColor)
                    Text(typeLabel)
                        .foregroundColor(.formaLabel)
                    Text(" is ")
                        .foregroundColor(secondaryTextColor)
                    Text(value)
                        .foregroundColor(.formaLabel)
                }
            case .compound:
                HStack(spacing: 0) {
                    Text("Matches ")
                        .foregroundColor(secondaryTextColor)
                    Text("multiple conditions")
                        .foregroundColor(.formaLabel)
                }
            }
        }
    }
    
    private var actionIcon: String {
        switch snapshot.actionType {
        case .move: return "folder.fill"
        case .copy: return "plus.square.on.square.fill"
        case .delete: return "trash.fill"
        }
    }

    private var resolvedHealth: RuleHealthService.RuleHealth {
        snapshot.health
    }

    private var healthAccentColor: Color {
        switch resolvedHealth.kind {
        case .duplicate:
            return .formaError
        case .overlap, .needsPermission:
            return .formaWarmOrange
        case .willCreate:
            return .formaSteelBlue
        case .ready:
            return .formaSage
        case .disabled:
            return secondaryTextColor
        }
    }

    private var healthBadgeBackground: Color {
        switch resolvedHealth.kind {
        case .duplicate:
            return Color.formaError.opacity(0.14)
        case .overlap, .needsPermission:
            return Color.formaWarmOrange.opacity(0.15)
        case .willCreate:
            return Color.formaSteelBlue.opacity(0.14)
        case .ready:
            return Color.formaSage.opacity(0.14)
        case .disabled:
            return disabledBadgeBackground
        }
    }

    private var destinationStatusIconName: String? {
        switch resolvedHealth.kind {
        case .needsPermission:
            return "exclamationmark.triangle.fill"
        case .willCreate:
            return "folder.badge.plus"
        default:
            return nil
        }
    }

    private var healthDetailIconName: String {
        switch resolvedHealth.kind {
        case .duplicate:
            return "doc.on.doc.fill"
        case .overlap:
            return "arrow.triangle.branch"
        case .needsPermission:
            return "exclamationmark.triangle.fill"
        case .willCreate:
            return "folder.badge.plus"
        case .ready:
            return "checkmark.circle.fill"
        case .disabled:
            return "pause.circle.fill"
        }
    }

    private var healthDetailMessage: String? {
        switch resolvedHealth.kind {
        case .ready:
            return nil
        case .duplicate, .overlap, .needsPermission, .willCreate, .disabled:
            return resolvedHealth.message
        }
    }

    private var scopeDetailMessage: String? {
        snapshot.scopeDetailMessage
    }

    private var showsCategoryBadge: Bool {
        snapshot.categoryBadge != nil
    }

    private var destinationTextColor: Color {
        switch resolvedHealth.kind {
        case .needsPermission:
            return .formaWarmOrange
        case .willCreate:
            return .formaSteelBlue
        default:
            return secondaryTextColor
        }
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
                
                Image(systemName: snapshot.iconName)
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
                    Text(snapshot.name)
                        .font(.formaBodyBold)
                        .foregroundColor(snapshot.isEnabled ? .formaLabel : secondaryTextColor)

                    if let badgeLabel = resolvedHealth.badgeLabel {
                        Text(badgeLabel)
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundColor(healthAccentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(healthBadgeBackground)
                            .cornerRadius(4)
                            .help(resolvedHealth.message ?? badgeLabel)
                    }

                    if showsCategoryBadge, let categoryBadge = snapshot.categoryBadge {
                        Text(categoryBadge.name)
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundColor(categoryBadge.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryBadge.color.opacity(0.15))
                            .cornerRadius(4)
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

                    if let destinationStatusIconName {
                        Image(systemName: destinationStatusIconName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(healthAccentColor)
                    }

                    Text(snapshot.destinationDisplayText)
                        .font(.formaSmall)
                        .foregroundColor(destinationTextColor)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let lastTriggered = snapshot.lastTriggeredDate {
                        Spacer().frame(width: 4)

                        Text("·")
                            .foregroundColor(tertiaryTextColor)

                        Text(lastTriggered.relativeRuleTimestamp)
                            .font(.formaCaption)
                            .foregroundColor(tertiaryTextColor)
                            .lineLimit(1)
                    }
                }

                if let scopeDetailMessage {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 10, weight: .semibold))
                        Text(scopeDetailMessage)
                            .font(.formaCaption)
                            .lineLimit(1)
                    }
                    .foregroundColor(tertiaryTextColor)
                }

                if let healthDetailMessage {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: healthDetailIconName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(healthDetailMessage)
                            .font(.formaCaption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundColor(healthAccentColor)
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
                            .fill(snapshot.isEnabled ? Color.formaSteelBlue : offToggleTrackColor)
                            .frame(width: 32, height: 18)
                        
                        Circle()
                            .fill(toggleThumbColor)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .offset(x: snapshot.isEnabled ? 7 : -7)
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: snapshot.isEnabled)
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
            Text("Are you sure you want to delete \"\(snapshot.name)\"? This action cannot be undone.")
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

    private static func fallbackHealth(for rule: Rule) -> RuleHealthService.RuleHealth {
        if !rule.isEnabled {
            return RuleHealthService.RuleHealth(kind: .disabled, badgeLabel: "Disabled", message: "This rule is turned off.")
        }

        if let category = rule.category, !category.isEnabled {
            return RuleHealthService.RuleHealth(
                kind: .disabled,
                badgeLabel: "Category Off",
                message: "The '\(category.name)' category is disabled."
            )
        }

        guard rule.actionType != .delete,
              let destination = rule.destination else {
            return RuleHealthService.RuleHealth(kind: .ready, badgeLabel: nil, message: nil)
        }

        if destination.bookmarkData != nil {
            switch destination.validate() {
            case .valid, .stale:
                return RuleHealthService.RuleHealth(kind: .ready, badgeLabel: nil, message: nil)
            case .invalid(let reason):
                return RuleHealthService.RuleHealth(kind: .needsPermission, badgeLabel: "Needs Permission", message: reason)
            }
        }

        switch destinationResolver.checkResolvability(destination) {
        case .valid:
            return RuleHealthService.RuleHealth(kind: .ready, badgeLabel: nil, message: nil)
        case .resolvable(let parentFolder):
            return RuleHealthService.RuleHealth(
                kind: .willCreate,
                badgeLabel: "Will Create",
                message: "Forma can create this folder inside \(parentFolder) when you save."
            )
        case .unresolvable(let reason):
            return RuleHealthService.RuleHealth(kind: .needsPermission, badgeLabel: "Needs Permission", message: reason)
        }
    }
}

// MARK: - Date Formatting for Rule Cards

private extension Date {
    /// Compact relative timestamp for rule cards (e.g., "2m ago", "3h ago", "Yesterday")
    var relativeRuleTimestamp: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 172800 {
            return "Yesterday"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
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
