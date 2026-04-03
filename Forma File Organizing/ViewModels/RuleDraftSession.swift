import Foundation

enum RuleDraftPresentation: Equatable {
    case panel
    case modal
}

enum RuleDraftReturnTarget: Equatable {
    case none
    case defaultPanel
    case inspector(filePath: String)
}

enum RuleDraftSource: Equatable {
    case genericNew
    case newFromFile
    case editExisting
    case suggestedPrompt
}

struct RuleDraftSession {
    var formState: RuleFormState
    var editingRule: Rule?
    var fileContext: FileItem?
    var suggestedNaturalLanguageText: String?
    var presentation: RuleDraftPresentation
    var returnTarget: RuleDraftReturnTarget
    var source: RuleDraftSource
}
