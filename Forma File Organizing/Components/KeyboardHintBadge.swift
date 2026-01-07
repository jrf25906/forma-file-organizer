import SwiftUI

/// Small badge showing keyboard shortcut hints
struct KeyboardHintBadge: View {
    let key: String
    
    var body: some View {
        Text(key)
            .font(.formaMonoSmall)
            .padding(.horizontal, FormaSpacing.tight - (FormaSpacing.micro / 2))
            .padding(.vertical, FormaSpacing.micro / 2)
            .background(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.light))
            .formaCornerRadius(FormaRadius.micro)
            .foregroundColor(.formaSecondaryLabel)
    }
}

#Preview {
    HStack(spacing: FormaSpacing.standard - FormaSpacing.micro) {
        KeyboardHintBadge(key: "↵")
        KeyboardHintBadge(key: "S")
        KeyboardHintBadge(key: "Space")
        KeyboardHintBadge(key: "Cmd+Enter")
    }
    .padding()
}
