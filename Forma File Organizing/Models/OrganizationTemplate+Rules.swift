import Foundation

// MARK: - Rule Generation for Organization Templates

extension OrganizationTemplate {

    // MARK: - Helper

    /// Creates a folder destination with a placeholder bookmark.
    /// Real bookmarks will be created when user selects folders via picker.
    private func dest(_ displayName: String) -> Destination {
        .folder(bookmark: Data(), displayName: displayName)
    }

    // MARK: - PARA Method Rules

    /// Generates rules for the PARA Method (Projects, Areas, Resources, Archive)
    func generatePARARules(basePath: String) -> [Rule] {
        let projectsPath = "\(basePath)/Projects"
        let areasPath = "\(basePath)/Areas"
        let resourcesPath = "\(basePath)/Resources"
        let archivePath = "\(basePath)/Archive"

        return [
            // Active project files (with "project" keyword)
            Rule(name: "Active Projects", conditionType: .nameContains, conditionValue: "project", actionType: .move, destination: dest(projectsPath)),

            // Areas - Ongoing responsibilities
            Rule(name: "Finance Documents", conditionType: .nameContains, conditionValue: "invoice", actionType: .move, destination: dest("\(areasPath)/Finance")),
            Rule(name: "Health Records", conditionType: .nameContains, conditionValue: "health", actionType: .move, destination: dest("\(areasPath)/Health")),
            Rule(name: "Tax Documents", conditionType: .nameContains, conditionValue: "tax", actionType: .move, destination: dest("\(areasPath)/Finance/Taxes")),

            // Resources - Reference materials
            Rule(name: "PDF References", conditionType: .fileExtension, conditionValue: "pdf", actionType: .move, destination: dest("\(resourcesPath)/Documents")),
            Rule(name: "E-books", conditionType: .fileExtension, conditionValue: "epub", actionType: .move, destination: dest("\(resourcesPath)/Books")),
            Rule(name: "Templates", conditionType: .nameContains, conditionValue: "template", actionType: .move, destination: dest("\(resourcesPath)/Templates")),

            // Archive - Old files (6 months+)
            Rule(name: "Archive Old Documents", conditionType: .dateModifiedOlderThan, conditionValue: "180", actionType: .move, destination: dest(archivePath)),
            Rule(name: "Archive Completed", conditionType: .nameContains, conditionValue: "completed", actionType: .move, destination: dest(archivePath)),
            Rule(name: "Archive Final", conditionType: .nameContains, conditionValue: "final", actionType: .move, destination: dest(archivePath))
        ]
    }
    
    // MARK: - Johnny Decimal Rules

    /// Generates rules for Johnny Decimal system
    func generateJohnnyDecimalRules(basePath: String) -> [Rule] {
        return [
            // 10-19: Finance
            Rule(name: "10-19: Invoices", conditionType: .nameContains, conditionValue: "invoice", actionType: .move, destination: dest("\(basePath)/10-19 Finance/11 Invoices")),
            Rule(name: "10-19: Receipts", conditionType: .nameContains, conditionValue: "receipt", actionType: .move, destination: dest("\(basePath)/10-19 Finance/12 Receipts")),
            Rule(name: "10-19: Bank Statements", conditionType: .nameContains, conditionValue: "statement", actionType: .move, destination: dest("\(basePath)/10-19 Finance/13 Banking")),

            // 20-29: Work
            Rule(name: "20-29: Presentations", conditionType: .fileExtension, conditionValue: "key", actionType: .move, destination: dest("\(basePath)/20-29 Work/21 Presentations")),
            Rule(name: "20-29: Spreadsheets", conditionType: .fileExtension, conditionValue: "xlsx", actionType: .move, destination: dest("\(basePath)/20-29 Work/22 Data")),
            Rule(name: "20-29: Reports", conditionType: .nameContains, conditionValue: "report", actionType: .move, destination: dest("\(basePath)/20-29 Work/23 Reports")),

            // 30-39: Personal
            Rule(name: "30-39: Photos", conditionType: .fileExtension, conditionValue: "jpg", actionType: .move, destination: dest("\(basePath)/30-39 Personal/31 Photos")),
            Rule(name: "30-39: Videos", conditionType: .fileExtension, conditionValue: "mp4", actionType: .move, destination: dest("\(basePath)/30-39 Personal/32 Videos")),

            // 40-49: Creative
            Rule(name: "40-49: Design Files", conditionType: .fileExtension, conditionValue: "psd", actionType: .move, destination: dest("\(basePath)/40-49 Creative/41 Design")),
            Rule(name: "40-49: Vector Graphics", conditionType: .fileExtension, conditionValue: "svg", actionType: .move, destination: dest("\(basePath)/40-49 Creative/42 Vectors")),

            // 50-59: Reference
            Rule(name: "50-59: Documentation", conditionType: .fileExtension, conditionValue: "pdf", actionType: .move, destination: dest("\(basePath)/50-59 Reference/51 Docs")),
            Rule(name: "50-59: Archives", conditionType: .fileExtension, conditionValue: "zip", actionType: .move, destination: dest("\(basePath)/50-59 Reference/52 Archives"))
        ]
    }
    
    // MARK: - Creative Professional Rules

    /// Generates rules for Creative Professional workflow
    func generateCreativeProfRules(basePath: String) -> [Rule] {
        let clientsPath = "\(basePath)/Clients"
        let projectsPath = "\(basePath)/Projects"
        let archivePath = "\(basePath)/Archive"

        return [
            // Raw assets
            Rule(name: "RAW Photos", conditionType: .fileExtension, conditionValue: "cr2", actionType: .move, destination: dest("\(projectsPath)/Active/Raw Imports")),
            Rule(name: "RAW Photos (NEF)", conditionType: .fileExtension, conditionValue: "nef", actionType: .move, destination: dest("\(projectsPath)/Active/Raw Imports")),

            // Design files
            Rule(name: "Photoshop Files", conditionType: .fileExtension, conditionValue: "psd", actionType: .move, destination: dest("\(projectsPath)/Active/Working Files")),
            Rule(name: "Illustrator Files", conditionType: .fileExtension, conditionValue: "ai", actionType: .move, destination: dest("\(projectsPath)/Active/Working Files")),
            Rule(name: "Figma Exports", conditionType: .nameContains, conditionValue: "figma", actionType: .move, destination: dest("\(projectsPath)/Active/Design")),

            // Delivered work
            Rule(name: "Final Deliverables", conditionType: .nameContains, conditionValue: "final", actionType: .move, destination: dest("\(projectsPath)/Delivered")),
            Rule(name: "Client Approved", conditionType: .nameContains, conditionValue: "approved", actionType: .move, destination: dest("\(projectsPath)/Delivered")),

            // Video production
            Rule(name: "Video Projects", conditionType: .fileExtension, conditionValue: "prproj", actionType: .move, destination: dest("\(projectsPath)/Active/Video")),
            Rule(name: "Rendered Videos", conditionType: .fileExtension, conditionValue: "mov", actionType: .move, destination: dest("\(projectsPath)/Delivered")),

            // Archive old projects
            Rule(name: "Archive Old Projects", conditionType: .dateModifiedOlderThan, conditionValue: "365", actionType: .move, destination: dest(archivePath)),

            // Client-specific (generic)
            Rule(name: "Client Files", conditionType: .nameContains, conditionValue: "client", actionType: .move, destination: dest(clientsPath))
        ]
    }
    
    // MARK: - Minimal Rules

    /// Generates rules for Minimal system
    func generateMinimalRules(basePath: String) -> [Rule] {
        // Note: inboxPath not used in rules - users manually move to Inbox
        _ = "\(basePath)/Inbox"
        let keepPath = "\(basePath)/Keep"
        let archivePath = "\(basePath)/Archive"

        return [
            // Everything starts in Inbox (users manually move to Keep)
            // Auto-archive old files from Inbox
            Rule(name: "Archive Old Inbox Items", conditionType: .dateModifiedOlderThan, conditionValue: "90", actionType: .move, destination: dest(archivePath)),

            // Auto-file common types to Keep
            Rule(name: "Keep Important Docs", conditionType: .nameContains, conditionValue: "important", actionType: .move, destination: dest(keepPath)),
            Rule(name: "Keep Contracts", conditionType: .nameContains, conditionValue: "contract", actionType: .move, destination: dest(keepPath)),
            Rule(name: "Keep Invoices", conditionType: .nameContains, conditionValue: "invoice", actionType: .move, destination: dest(keepPath)),

            // Delete temporary files
            Rule(name: "Delete Temp Files", conditionType: .nameStartsWith, conditionValue: "temp", actionType: .delete),
            Rule(name: "Delete DMG Files", conditionType: .fileExtension, conditionValue: "dmg", actionType: .delete),

            // Clean up old archives
            Rule(name: "Delete Very Old Archives", conditionType: .dateModifiedOlderThan, conditionValue: "730", actionType: .delete)
        ]
    }
    
    // MARK: - Academic/Research Rules

    /// Generates rules for Academic & Research workflow
    func generateAcademicRules(basePath: String) -> [Rule] {
        let literaturePath = "\(basePath)/Literature"
        let researchPath = "\(basePath)/Research"
        let writingPath = "\(basePath)/Writing"
        let referencesPath = "\(basePath)/References"

        return [
            // Literature/Papers
            Rule(name: "Academic Papers", conditionType: .fileExtension, conditionValue: "pdf", actionType: .move, destination: dest("\(literaturePath)/Papers")),
            Rule(name: "Books & Chapters", conditionType: .fileExtension, conditionValue: "epub", actionType: .move, destination: dest("\(literaturePath)/Books")),
            Rule(name: "Literature Notes", conditionType: .nameContains, conditionValue: "notes", actionType: .move, destination: dest("\(literaturePath)/Notes")),

            // Research Data
            Rule(name: "Research Data (CSV)", conditionType: .fileExtension, conditionValue: "csv", actionType: .move, destination: dest("\(researchPath)/Data")),
            Rule(name: "Research Data (Excel)", conditionType: .fileExtension, conditionValue: "xlsx", actionType: .move, destination: dest("\(researchPath)/Data")),
            Rule(name: "Analysis Scripts", conditionType: .fileExtension, conditionValue: "py", actionType: .move, destination: dest("\(researchPath)/Analysis")),
            Rule(name: "R Scripts", conditionType: .fileExtension, conditionValue: "r", actionType: .move, destination: dest("\(researchPath)/Analysis")),

            // Writing
            Rule(name: "Draft Papers", conditionType: .nameContains, conditionValue: "draft", actionType: .move, destination: dest("\(writingPath)/Drafts")),
            Rule(name: "LaTeX Files", conditionType: .fileExtension, conditionValue: "tex", actionType: .move, destination: dest("\(writingPath)/LaTeX")),
            Rule(name: "Published Papers", conditionType: .nameContains, conditionValue: "published", actionType: .move, destination: dest("\(writingPath)/Published")),

            // References
            Rule(name: "Citation Files", conditionType: .fileExtension, conditionValue: "bib", actionType: .move, destination: dest(referencesPath)),
            Rule(name: "RIS Citations", conditionType: .fileExtension, conditionValue: "ris", actionType: .move, destination: dest(referencesPath))
        ]
    }
    
    // MARK: - Chronological Rules

    /// Generates rules for Chronological/Date-based system
    func generateChronologicalRules(basePath: String) -> [Rule] {
        let currentYear = Calendar.current.component(.year, from: Date())
        // Note: currentMonth used for quarter calculation via currentQuarter property
        _ = Calendar.current.component(.month, from: Date())
        let currentYearPath = "\(basePath)/\(currentYear)"
        let lastYearPath = "\(basePath)/\(currentYear - 1)"
        let archivePath = "\(basePath)/Archive"

        return [
            // Current year - by document type
            Rule(name: "\(currentYear): Invoices", conditionType: .nameContains, conditionValue: "invoice", actionType: .move, destination: dest("\(currentYearPath)/Q\(currentQuarter)/Financial")),
            Rule(name: "\(currentYear): Contracts", conditionType: .nameContains, conditionValue: "contract", actionType: .move, destination: dest("\(currentYearPath)/Q\(currentQuarter)/Legal")),
            Rule(name: "\(currentYear): Reports", conditionType: .nameContains, conditionValue: "report", actionType: .move, destination: dest("\(currentYearPath)/Q\(currentQuarter)/Reports")),

            // Tax documents
            Rule(name: "\(currentYear): Tax Documents", conditionType: .nameContains, conditionValue: "tax", actionType: .move, destination: dest("\(currentYearPath)/Tax")),

            // Last year
            Rule(name: "\(currentYear - 1): Old Invoices", conditionType: .nameContains, conditionValue: "\(currentYear - 1)", actionType: .move, destination: dest(lastYearPath)),

            // Archive very old files (2+ years)
            Rule(name: "Archive Files Older Than 2 Years", conditionType: .dateModifiedOlderThan, conditionValue: "730", actionType: .move, destination: dest(archivePath)),

            // Financial compliance (7 year retention)
            Rule(name: "Keep Financial Records 7 Years", conditionType: .nameContains, conditionValue: "financial", actionType: .move, destination: dest("\(basePath)/\(currentYear)/Financial"))
        ]
    }
    
    private var currentQuarter: Int {
        let month = Calendar.current.component(.month, from: Date())
        return (month - 1) / 3 + 1
    }
    
    // MARK: - Student Rules

    /// Generates rules for Student workflow
    func generateStudentRules(basePath: String) -> [Rule] {
        let classesPath = "\(basePath)/Classes"
        let projectsPath = "\(basePath)/Projects"
        let resourcesPath = "\(basePath)/Resources"

        return [
            // Class materials
            Rule(name: "Lecture Slides", conditionType: .nameContains, conditionValue: "lecture", actionType: .move, destination: dest("\(classesPath)/Current")),
            Rule(name: "Syllabus", conditionType: .nameContains, conditionValue: "syllabus", actionType: .move, destination: dest("\(classesPath)/Current")),

            // Assignments
            Rule(name: "Homework", conditionType: .nameContains, conditionValue: "homework", actionType: .move, destination: dest("\(classesPath)/Current/Assignments")),
            Rule(name: "Assignment Files", conditionType: .nameContains, conditionValue: "assignment", actionType: .move, destination: dest("\(classesPath)/Current/Assignments")),
            Rule(name: "Lab Reports", conditionType: .nameContains, conditionValue: "lab", actionType: .move, destination: dest("\(classesPath)/Current/Labs")),

            // Exams
            Rule(name: "Study Guides", conditionType: .nameContains, conditionValue: "study guide", actionType: .move, destination: dest("\(classesPath)/Current/Exams")),
            Rule(name: "Practice Exams", conditionType: .nameContains, conditionValue: "practice", actionType: .move, destination: dest("\(classesPath)/Current/Exams")),

            // Projects
            Rule(name: "Group Projects", conditionType: .nameContains, conditionValue: "group", actionType: .move, destination: dest("\(projectsPath)/Current")),
            Rule(name: "Final Projects", conditionType: .nameContains, conditionValue: "final project", actionType: .move, destination: dest("\(projectsPath)/Current")),
            Rule(name: "Completed Projects", conditionType: .nameContains, conditionValue: "completed", actionType: .move, destination: dest("\(projectsPath)/Completed")),

            // Resources
            Rule(name: "Textbook PDFs", conditionType: .nameContains, conditionValue: "textbook", actionType: .move, destination: dest("\(resourcesPath)/Textbooks")),
            Rule(name: "Study Materials", conditionType: .nameContains, conditionValue: "study", actionType: .move, destination: dest("\(resourcesPath)/Study Guides")),

            // Archive completed semester
            Rule(name: "Archive Old Semester", conditionType: .dateModifiedOlderThan, conditionValue: "120", actionType: .move, destination: dest("\(classesPath)/Completed"))
        ]
    }
}
