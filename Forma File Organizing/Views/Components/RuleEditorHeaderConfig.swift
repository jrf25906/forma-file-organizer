import Foundation

enum RuleEditorHeaderStyle {
    case fullEditor
    case inline
}

struct RuleEditorHeaderConfig {
    let icon: String
    let title: String
    let subtitle: String?

    static func make(editingRule: Rule?, fileContext: FileItem?, style: RuleEditorHeaderStyle) -> RuleEditorHeaderConfig {
        if editingRule != nil {
            switch style {
            case .fullEditor:
                return RuleEditorHeaderConfig(
                    icon: "slider.horizontal.3",
                    title: "Edit Rule",
                    subtitle: "Advanced conditions & actions"
                )
            case .inline:
                return RuleEditorHeaderConfig(
                    icon: "slider.horizontal.3",
                    title: "Edit Rule",
                    subtitle: "Modify conditions & destination"
                )
            }
        }

        if fileContext != nil {
            return RuleEditorHeaderConfig(
                icon: "bolt.fill",
                title: "Quick Rule",
                subtitle: "From this file's pattern"
            )
        }

        switch style {
        case .fullEditor:
            return RuleEditorHeaderConfig(
                icon: "slider.horizontal.3",
                title: "Rule Editor",
                subtitle: "Advanced conditions & actions"
            )
        case .inline:
            return RuleEditorHeaderConfig(
                icon: "wand.and.stars",
                title: "New Rule",
                subtitle: nil
            )
        }
    }
}
