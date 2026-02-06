import SwiftUI

/// Rule button with dropdown menu showing matching rules and create new option
struct RuleButtonWithMenu: View {
    let file: FileItem
    let matchingRules: [Rule]
    let onCreateRule: () -> Void
    let onApplyRule: (Rule) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var hasRule: Bool {
        file.destination != nil
    }

    private var pillBackground: Color {
        if hasRule {
            return colorScheme == .dark
                ? Color.formaSoftGreen.opacity(0.28)
                : Color.formaSoftGreen.opacity(0.16)
        }
        return colorScheme == .dark
            ? Color.formaWarning.opacity(0.30)
            : Color.formaWarning.opacity(0.16)
    }

    private var pillBorder: Color {
        if hasRule {
            return colorScheme == .dark
                ? Color.formaSoftGreen.opacity(0.70)
                : Color.formaSoftGreen.opacity(0.58)
        }
        return colorScheme == .dark
            ? Color.formaWarning.opacity(0.70)
            : Color.formaWarning.opacity(0.62)
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
                Image(systemName: hasRule ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.formaCompactMedium)
                    .foregroundColor(hasRule ? Color.formaSuccess : Color.formaWarning)
                Text("Rule")
                    .font(.formaCompactMedium)
                    .foregroundColor(.formaLabel)
            }
            .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
            .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                    .stroke(pillBorder, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .fill(pillBackground)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .help(hasRule ? "View or change matching rules" : "Create a rule for this file")
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
