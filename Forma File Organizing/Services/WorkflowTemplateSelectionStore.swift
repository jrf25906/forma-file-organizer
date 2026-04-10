import Foundation

struct WorkflowTemplateSelectionStore {
    enum Keys {
        static let manualTemplateID = "workflowEngineV2.manualTemplateID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedTemplateID: String? {
        get {
            let storedTemplateID = defaults.string(forKey: Keys.manualTemplateID)
            guard let validatedTemplateID = Self.validatedTemplateID(storedTemplateID) else {
                if storedTemplateID != nil {
                    defaults.removeObject(forKey: Keys.manualTemplateID)
                }
                return nil
            }
            return validatedTemplateID
        }
        nonmutating set {
            guard let validatedTemplateID = Self.validatedTemplateID(newValue) else {
                defaults.removeObject(forKey: Keys.manualTemplateID)
                return
            }
            defaults.set(validatedTemplateID, forKey: Keys.manualTemplateID)
        }
    }

    func resolvedTemplateID(explicitTemplateID: String?) -> String? {
        Self.validatedTemplateID(explicitTemplateID) ?? selectedTemplateID
    }

    static func validatedTemplateID(_ rawValue: String?) -> String? {
        guard let normalizedTemplateID = WorkflowRunRecord.normalizedOptionalText(rawValue),
              WorkflowTemplateCatalog.template(for: normalizedTemplateID) != nil else {
            return nil
        }
        return normalizedTemplateID
    }
}
