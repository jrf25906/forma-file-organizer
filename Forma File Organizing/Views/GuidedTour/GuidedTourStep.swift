import SwiftUI

// MARK: - TooltipPlacement

enum TooltipPlacement {
    case leading
    case trailing
    case top
    case bottom
}

// MARK: - GuidedTourRegion

enum GuidedTourRegion: String, CaseIterable, Sendable {
    case sidebarLocations
    case mainFileList
    case newRuleButton
    case organizeButton
}

// MARK: - Feature Hint

struct FeatureHintIcon: Sendable {
    let name: String
    let color: Color
}

struct FeatureHint: Sendable {
    let icons: [FeatureHintIcon]
    let label: String
    let useMonoFont: Bool
}

// MARK: - GuidedTourStep

enum GuidedTourStep: CaseIterable, Sendable {
    case watchedFolders
    case yourFiles
    case createRule
    case organize

    // MARK: - Properties

    var title: String {
        switch self {
        case .watchedFolders:    return "Watched Folders"
        case .yourFiles:         return "Your Files"
        case .createRule:        return "Create a Rule"
        case .organize:          return "Organize"
        }
    }

    var body: String {
        switch self {
        case .watchedFolders:
            return "Forma continuously monitors these folders for new files. When something appears, it's automatically detected and ready to organize."
        case .yourFiles:
            return "Files are grouped by type \u{2014} documents, images, archives, and more. Select any file to preview it in the right panel."
        case .createRule:
            return "Rules tell Forma where files should go. Match by file type, name pattern, or date \u{2014} then Forma applies them every time."
        case .organize:
            return "Move all matched files to their destinations with one click. Every move is logged and can be undone instantly."
        }
    }

    var featureHint: FeatureHint {
        switch self {
        case .watchedFolders:
            return FeatureHint(
                icons: [
                    FeatureHintIcon(name: "desktopcomputer", color: .formaSteelBlue),
                    FeatureHintIcon(name: "arrow.down.circle.fill", color: .formaSage),
                    FeatureHintIcon(name: "doc.fill", color: .formaMutedBlue),
                ],
                label: "Desktop \u{00b7} Downloads \u{00b7} Documents",
                useMonoFont: false
            )
        case .yourFiles:
            return FeatureHint(
                icons: [
                    FeatureHintIcon(name: "doc.text.fill", color: .formaMutedBlue),
                    FeatureHintIcon(name: "photo.fill", color: .formaWarmOrange),
                    FeatureHintIcon(name: "archivebox.fill", color: .formaSoftGreen),
                    FeatureHintIcon(name: "music.note", color: .formaSage),
                ],
                label: "Sorted by type automatically",
                useMonoFont: false
            )
        case .createRule:
            return FeatureHint(
                icons: [
                    FeatureHintIcon(name: "doc.text.fill", color: .formaMutedBlue),
                    FeatureHintIcon(name: "arrow.right", color: .formaSecondaryLabel),
                    FeatureHintIcon(name: "folder.fill", color: .formaSage),
                ],
                label: "PDFs \u{2192} Documents/Invoices",
                useMonoFont: true
            )
        case .organize:
            return FeatureHint(
                icons: [
                    FeatureHintIcon(name: "checkmark.circle.fill", color: .formaSage),
                ],
                label: "Every move is reversible",
                useMonoFont: false
            )
        }
    }

    var icon: String {
        switch self {
        case .watchedFolders:    return "folder.fill"
        case .yourFiles:         return "doc.on.doc.fill"
        case .createRule:        return "plus.rectangle.on.rectangle.fill"
        case .organize:          return "arrow.right.doc.on.clipboard"
        }
    }

    var region: GuidedTourRegion {
        switch self {
        case .watchedFolders:    return .sidebarLocations
        case .yourFiles:         return .mainFileList
        case .createRule:        return .newRuleButton
        case .organize:          return .organizeButton
        }
    }

    var tooltipPlacement: TooltipPlacement {
        switch self {
        case .watchedFolders:    return .trailing
        case .yourFiles:         return .bottom
        case .createRule:        return .trailing
        case .organize:          return .leading
        }
    }

    // MARK: - Static Helpers

    static var allSteps: [GuidedTourStep] {
        return Self.allCases
    }

    var stepIndex: Int {
        return Self.allSteps.firstIndex(of: self) ?? 0
    }

    var isLastStep: Bool {
        return self == Self.allSteps.last
    }
}
