import SwiftUI

/// Rule button with dropdown menu showing matching rules and create new option
struct RuleButtonWithMenu: View {
    let file: FileItem
    let matchingRules: [Rule]
    let onCreateRule: () -> Void
    let onApplyRule: (Rule) -> Void
    
    private var hasRule: Bool {
        file.destination != nil
    }
    
    var body: some View {
        Menu {
            // Create New Rule (always first, blue accent)
            Button(action: onCreateRule) {
                Label("+ Create New Rule...", systemImage: "plus.circle")
            }
            .keyboardShortcut("r", modifiers: .command)
            
            if !matchingRules.isEmpty {
                Divider()
                
                // Show matching rules
                ForEach(matchingRules) { rule in
                    Button(action: { onApplyRule(rule) }) {
                        Label {
                            VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                                Text(rule.name)
                                    .font(.formaBodyMedium)
                                if let displayName = rule.destination?.displayName {
                                    Text(displayName)
                                        .font(.formaSmall)
                                        .foregroundColor(.formaSecondaryLabel)
                                }
                            }
                        } icon: {
                            Image(systemName: rule.iconName)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                Image(systemName: hasRule ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.formaCompactMedium)
                Text(hasRule ? "Has Rule" : "No Rule")
                    .font(.formaCompactMedium)
            }
            .foregroundColor(hasRule ? Color.formaSuccess : Color.formaWarning)
            .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
            .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                    .stroke(
                        hasRule ? Color.formaSuccess : Color.formaSeparator,
                        lineWidth: 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .fill(Color.formaBoneWhite)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .help(hasRule ? "View or change rule" : "Create a rule for this file")
    }
}

// Extension to get icon name for Rule
extension Rule {
    var iconName: String {
        // Return appropriate icon based on rule conditions
        // This is a simple implementation - you can enhance based on your needs
        return "arrow.right.circle"
    }
}

#Preview {
    VStack(spacing: FormaSpacing.standard) {
        // With rule
        RuleButtonWithMenu(
            file: FileItem(
                path: "/Users/test/Desktop/Document.pdf",
                sizeInBytes: 2_621_440,
                creationDate: Date(),
                destination: .folder(bookmark: Data(), displayName: "Documents"),
                status: .ready
            ),
            matchingRules: [],
            onCreateRule: {},
            onApplyRule: { _ in }
        )
        
        // Without rule
        RuleButtonWithMenu(
            file: FileItem(
                path: "/Users/test/Desktop/Untitled.txt",
                sizeInBytes: 1024,
                creationDate: Date(),
                destination: nil,
                status: .pending
            ),
            matchingRules: [],
            onCreateRule: {},
            onApplyRule: { _ in }
        )
    }
    .padding()
    .background(Color.formaBoneWhite)
}
