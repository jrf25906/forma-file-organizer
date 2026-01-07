import SwiftUI

/// Component that displays detailed reasoning for why a file matched a rule.
/// Shows matched conditions in a human-readable format with proper visual hierarchy.
struct ReasoningView: View {
    let reasoning: String
    var isExpanded: Bool = true
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                Image(systemName: "lightbulb.fill")
                    .font(.formaSmallSemibold)
                    .foregroundStyle(Color.formaSteelBlue)
                
                Text("Why this matched:")
                    .font(.formaSmallSemibold)
                    .foregroundStyle(Color.formaSecondaryLabel)
            }
            
            if isExpanded {
                Text(reasoning)
                    .font(.formaCompact)
                    .foregroundStyle(Color.formaLabel.opacity(Color.FormaOpacity.prominent))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, FormaSpacing.standard + (FormaSpacing.micro / 4)) // Align with icon + spacing
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
        .padding(.vertical, FormaSpacing.tight + (FormaSpacing.micro / 2))
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isExpanded)
    }
}

/// Compact inline version of reasoning display for tooltips and badges
struct InlineReasoningBadge: View {
    let reasoning: String
    var maxLength: Int = 50
    
    private var truncatedReasoning: String {
        if reasoning.count <= maxLength {
            return reasoning
        }
        return String(reasoning.prefix(maxLength)) + "..."
    }
    
    var body: some View {
        HStack(spacing: FormaSpacing.micro + (FormaSpacing.micro / 4)) {
            Image(systemName: "info.circle.fill")
                .font(.formaCaption)
                .fontWeight(.medium)
            Text(truncatedReasoning)
                .font(.formaSmall)
                .lineLimit(1)
        }
        .foregroundStyle(Color.formaSecondaryLabel)
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(
            Capsule()
                .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
        )
        .help(reasoning) // Full text in tooltip
    }
}

// MARK: - Preview

#Preview("ReasoningView") {
    VStack(spacing: FormaSpacing.standard) {
        ReasoningView(
            reasoning: "Extension is .pdf AND Name contains 'invoice'",
            isExpanded: true
        )
        
        ReasoningView(
            reasoning: "File kind is document AND Not modified in 30 days",
            isExpanded: false
        )
        
        InlineReasoningBadge(
            reasoning: "Extension is .pdf AND Name contains 'invoice' AND Larger than 1MB"
        )
    }
    .padding(FormaSpacing.generous)
    .background(Color.formaBackground)
    .frame(width: 500)
}
