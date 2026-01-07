import Foundation

/// Represents different organization system templates users can choose from.
///
/// Each template provides a proven organization methodology with pre-configured
/// folder structures and rules tailored to specific workflows and user personas.
enum OrganizationTemplate: String, Codable, CaseIterable {
    /// PARA Method (Projects, Areas, Resources, Archive)
    /// Best for: Knowledge workers, general productivity
    case para
    
    /// Johnny Decimal System (10-19, 20-29, etc.)
    /// Best for: Systematic filers who want structure
    case johnnyDecimal
    
    /// Creative Professional workflow (Client/Project/Status)
    /// Best for: Designers, photographers, video editors
    case creativeProf
    
    /// Minimal approach (Inbox, Keep, Archive)
    /// Best for: Casual users, pilers, simplicity seekers
    case minimal
    
    /// Academic/Research organization (Literature, Research, Writing)
    /// Best for: Researchers, academics, students (advanced)
    case academic
    
    /// Chronological/Date-based (Year/Month or Year/Quarter)
    /// Best for: Legal, accounting, compliance professionals
    case chronological
    
    /// Student organization (Classes, Assignments, Projects)
    /// Best for: High school and undergraduate students
    case student
    
    /// Custom template (user-defined rules)
    case custom
    
    // MARK: - Display Properties
    
    /// Human-readable name for the template
    var displayName: String {
        switch self {
        case .para:
            return "PARA Method"
        case .johnnyDecimal:
            return "Johnny Decimal"
        case .creativeProf:
            return "Creative Professional"
        case .minimal:
            return "Minimal"
        case .academic:
            return "Academic & Research"
        case .chronological:
            return "Chronological"
        case .student:
            return "Student"
        case .custom:
            return "Custom"
        }
    }
    
    /// Short description of the template
    var description: String {
        switch self {
        case .para:
            return "Organize by actionability: Projects, Areas, Resources, and Archive"
        case .johnnyDecimal:
            return "Numeric categorization system with 10 main categories (10-19, 20-29, etc.)"
        case .creativeProf:
            return "Client and project-based structure for creative work"
        case .minimal:
            return "Simple three-folder system: Inbox, Keep, and Archive"
        case .academic:
            return "Research-focused: Literature, Research, Writing, and References"
        case .chronological:
            return "Date-based organization by Year/Month or Year/Quarter"
        case .student:
            return "Class-based organization for assignments, projects, and study materials"
        case .custom:
            return "Create your own organization system"
        }
    }
    
    /// Icon name for the template
    var iconName: String {
        switch self {
        case .para:
            return "square.grid.2x2"
        case .johnnyDecimal:
            return "number.square"
        case .creativeProf:
            return "paintbrush.pointed"
        case .minimal:
            return "square.stack.3d.up"
        case .academic:
            return "book.closed"
        case .chronological:
            return "calendar"
        case .student:
            return "graduationcap"
        case .custom:
            return "gearshape"
        }
    }
    
    /// Target user persona
    var targetPersona: String {
        switch self {
        case .para:
            return "Knowledge workers, general productivity"
        case .johnnyDecimal:
            return "Systematic filers who want structure"
        case .creativeProf:
            return "Designers, photographers, video editors"
        case .minimal:
            return "Casual users, pilers, simplicity seekers"
        case .academic:
            return "Researchers, academics, PhD students"
        case .chronological:
            return "Legal, accounting, compliance professionals"
        case .student:
            return "High school and undergraduate students"
        case .custom:
            return "Users with unique workflows"
        }
    }
    
    /// Folder structure preview (top-level folders)
    var folderStructure: [String] {
        switch self {
        case .para:
            return ["Projects", "Areas", "Resources", "Archive"]
        case .johnnyDecimal:
            return ["10-19 Finance", "20-29 Work", "30-39 Personal", "40-49 Creative", "50-59 Reference"]
        case .creativeProf:
            return ["Clients", "Projects", "Archive"]
        case .minimal:
            return ["Inbox", "Keep", "Archive"]
        case .academic:
            return ["Literature", "Research", "Writing", "References"]
        case .chronological:
            return ["\(currentYear)", "\(currentYear - 1)", "Archive"]
        case .student:
            return ["Classes", "Projects", "Resources", "Personal"]
        case .custom:
            return ["Custom Structure"]
        }
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    // MARK: - Rule Generation
    
    /// Generates the default rules for this template.
    /// - Parameter baseDocumentsPath: The base Documents folder path for destination folders
    /// - Returns: Array of Rule objects configured for this template
    func generateRules(baseDocumentsPath: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "") -> [Rule] {
        switch self {
        case .para:
            return generatePARARules(basePath: baseDocumentsPath)
        case .johnnyDecimal:
            return generateJohnnyDecimalRules(basePath: baseDocumentsPath)
        case .creativeProf:
            return generateCreativeProfRules(basePath: baseDocumentsPath)
        case .minimal:
            return generateMinimalRules(basePath: baseDocumentsPath)
        case .academic:
            return generateAcademicRules(basePath: baseDocumentsPath)
        case .chronological:
            return generateChronologicalRules(basePath: baseDocumentsPath)
        case .student:
            return generateStudentRules(basePath: baseDocumentsPath)
        case .custom:
            return [] // Custom template has no default rules
        }
    }
}
