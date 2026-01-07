import SwiftUI

/// Modal overlay showing all keyboard shortcuts grouped by context
struct KeyboardShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.formaObsidian.opacity(Color.FormaOpacity.overlay)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Help card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "keyboard")
                        .font(.formaH1)
                        .foregroundColor(.formaSteelBlue)
                    
                    Text("Keyboard Shortcuts")
                        .font(.formaH2)
                        .foregroundColor(.formaLabel)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.formaH1)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                    .buttonStyle(.plain)
                }
                .padding(FormaSpacing.generous)
                .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: FormaSpacing.generous) {
                        // Navigation section
                        ShortcutGroup(title: "Navigation") {
                            ShortcutRow(keys: ["J"], or: "↓", description: "Next file")
                            ShortcutRow(keys: ["K"], or: "↑", description: "Previous file")
                            ShortcutRow(keys: ["Space"], description: "Quick Look")
                        }
                        
                        // Actions section
                        ShortcutGroup(title: "Actions") {
                            ShortcutRow(keys: ["Enter"], description: "Organize focused file")
                            ShortcutRow(keys: ["Cmd", "Enter"], description: "Organize and advance")
                            ShortcutRow(keys: ["S"], description: "Skip")
                            ShortcutRow(keys: ["E"], description: "Edit destination")
                            ShortcutRow(keys: ["R"], description: "Create rule")
                        }
                        
                        // Selection section
                        ShortcutGroup(title: "Selection") {
                            ShortcutRow(keys: ["Click"], description: "Toggle file")
                            ShortcutRow(keys: ["Cmd", "A"], description: "Select all")
                            ShortcutRow(keys: ["Cmd", "D"], description: "Deselect all")
                            ShortcutRow(keys: ["Shift", "Click"], description: "Range select")
                        }
                        
                        // View section
                        ShortcutGroup(title: "View") {
                            ShortcutRow(keys: ["Cmd", "1"], description: "Grid view")
                            ShortcutRow(keys: ["Cmd", "2"], description: "List view")
                            ShortcutRow(keys: ["Cmd", "3"], description: "Card view")
                        }
                        
                        // Other section
                        ShortcutGroup(title: "Other") {
                            ShortcutRow(keys: ["Cmd", "Z"], description: "Undo")
                            ShortcutRow(keys: ["Cmd", "Shift", "Z"], description: "Redo")
                            ShortcutRow(keys: ["?"], description: "Show this help")
                            ShortcutRow(keys: ["Esc"], description: "Close this help")
                        }
                    }
                    .padding(FormaSpacing.generous)
                }
            }
            .frame(width: 600, height: 650)
            .background(Color.formaBackground)
            .formaCornerRadius(FormaRadius.large)
            .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.overlay), radius: 20, x: 0, y: 10)
        }
    }
}

/// Group of related shortcuts
private struct ShortcutGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text(title)
                .font(.formaBodyBold)
                .foregroundColor(.formaLabel)
                .padding(.bottom, FormaSpacing.micro)
            
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                content()
            }
            .padding(.leading, FormaSpacing.standard)
        }
    }
}

/// Individual shortcut row
private struct ShortcutRow: View {
    let keys: [String]
    var or: String? = nil
    let description: String
    
    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Keys display
            HStack(spacing: FormaSpacing.micro) {
                ForEach(keys, id: \.self) { key in
                    KeyCapView(key)
                }
                
                if let or = or {
                    Text("or")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                    
                    KeyCapView(or)
                }
            }
            .frame(minWidth: 180, alignment: .leading)
            
            // Description
            Text(description)
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
            
            Spacer()
        }
    }
}

/// Key cap visual representation
private struct KeyCapView: View {
    let key: String
    
    init(_ key: String) {
        self.key = key
    }
    
    var body: some View {
        Text(key)
            .font(.formaMonoSmall)
            .fontWeight(.medium)
            .foregroundColor(.formaLabel)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                    .fill(Color.formaControlBackground)
                    .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.light), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                    .strokeBorder(Color.formaSeparator, lineWidth: 1)
            )
    }
}

#Preview {
    KeyboardShortcutsHelpView()
}
