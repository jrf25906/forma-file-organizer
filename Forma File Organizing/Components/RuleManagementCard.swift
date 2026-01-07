import SwiftUI

// MARK: - Rule Management Card

struct RuleManagementCard: View {
    let rule: Rule
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var isHovered = false
    
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
                        .foregroundColor(.formaSecondaryLabel)
                    Text(rule.conditionType.rawValue.camelCaseToTitleCase())
                        .foregroundColor(.formaLabel)
                    Text(" is ")
                        .foregroundColor(.formaSecondaryLabel)
                    Text(rule.conditionValue)
                        .foregroundColor(.formaLabel)
                }
            } else {
                // Compound
                let count = rule.conditions.count
                HStack(spacing: 0) {
                    Text("Matches ")
                        .foregroundColor(.formaSecondaryLabel)
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
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Leading Icon
            ZStack {
                Circle()
                    .fill(Color.formaControlBackground)
                    .frame(width: 36, height: 36)
                
                Image(systemName: ruleIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.formaSteelBlue)
            }
            .overlay(
                Circle()
                    .strokeBorder(Color.formaSeparator.opacity(0.5), lineWidth: 1)
            )
            
            // 2. Main Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    Text(rule.name)
                        .font(.formaBodyBold)
                        .foregroundColor(rule.isEnabled ? .formaObsidian : .formaSecondaryLabel)
                    
                    if !rule.isEnabled {
                        Text("Disabled")
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundColor(.formaSecondaryLabel)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.formaControlBackground)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 4) {
                    descriptionText
                        .font(.formaSmall)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.formaSecondaryLabel.opacity(0.5))
                        .padding(.horizontal, 2)
                    
                    Image(systemName: actionIcon)
                        .font(.formaCompact)
                        .foregroundColor(.formaSecondaryLabel)
                    
                    Text(rule.actionType == .delete ? "Delete" : rule.destinationDisplayText)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
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
                            .fill(rule.isEnabled ? Color.formaSteelBlue : Color.formaControlBackground)
                            .frame(width: 32, height: 18)
                        
                        Circle()
                            .fill(.white)
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
        .padding(.vertical, 10) // Tighter vertical padding
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaBoneWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(
                    isHovered
                        ? Color.formaSteelBlue.opacity(0.3)
                        : Color.formaSeparator.opacity(0.5),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(isHovered ? 0.08 : 0.02),
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
    }
}

// Helper for hover buttons
private struct IconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovered ? color : .formaSecondaryLabel)
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
