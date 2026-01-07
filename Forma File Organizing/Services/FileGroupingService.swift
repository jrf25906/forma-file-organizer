import Foundation
import Combine

/// Represents a group of files with a header
struct FileGroup: Identifiable, Equatable {
    // Stable identity: derive from header to avoid re-render churn
    var id: String { header.isEmpty ? "ungrouped" : header }
    let header: String
    let files: [FileItem]
    
    static func == (lhs: FileGroup, rhs: FileGroup) -> Bool {
        lhs.header == rhs.header && lhs.files.map { $0.path } == rhs.files.map { $0.path }
    }
}

/// Service for grouping files by date and detecting patterns
class FileGroupingService: ObservableObject {
    
    /// Group files by date (Today, Yesterday, This Week, This Month, Older)
    func groupFilesByDate(_ files: [FileItem]) -> [FileGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        // Define date boundaries
        let todayStart = calendar.startOfDay(for: now)
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            // Fallback: if date math fails, return a single group
            return files.isEmpty ? [] : [FileGroup(header: "All Files", files: files)]
        }
        
        // Sort files by creation date (newest first)
        let sortedFiles = files.sorted { $0.creationDate > $1.creationDate }
        
        // Group files into date buckets
        var todayFiles: [FileItem] = []
        var yesterdayFiles: [FileItem] = []
        var thisWeekFiles: [FileItem] = []
        var thisMonthFiles: [FileItem] = []
        var olderFiles: [FileItem] = []
        
        for file in sortedFiles {
            if file.creationDate >= todayStart {
                todayFiles.append(file)
            } else if file.creationDate >= yesterdayStart {
                yesterdayFiles.append(file)
            } else if file.creationDate >= thisWeekStart {
                thisWeekFiles.append(file)
            } else if file.creationDate >= thisMonthStart {
                thisMonthFiles.append(file)
            } else {
                olderFiles.append(file)
            }
        }
        
        // Build groups (only include non-empty groups)
        var groups: [FileGroup] = []
        
        if !todayFiles.isEmpty {
            groups.append(FileGroup(header: "Today", files: todayFiles))
        }
        if !yesterdayFiles.isEmpty {
            groups.append(FileGroup(header: "Yesterday", files: yesterdayFiles))
        }
        if !thisWeekFiles.isEmpty {
            groups.append(FileGroup(header: "This Week", files: thisWeekFiles))
        }
        if !thisMonthFiles.isEmpty {
            groups.append(FileGroup(header: "This Month", files: thisMonthFiles))
        }
        if !olderFiles.isEmpty {
            groups.append(FileGroup(header: "Older", files: olderFiles))
        }
        
        return groups
    }
    
    /// Detect pattern-based groups (screenshots, duplicates, large files, untitled)
    func detectPatterns(_ files: [FileItem]) -> [FileGroup] {
        var groups: [FileGroup] = []
        
        // Screenshots pattern - files with "screenshot", "screen shot", or "capture" in name
        let screenshots = files.filter { file in
            let lowercaseName = file.name.lowercased()
            return lowercaseName.contains("screenshot") ||
                   lowercaseName.contains("screen shot") ||
                   lowercaseName.contains("screen_shot") ||
                   lowercaseName.contains("capture")
        }
        
        if !screenshots.isEmpty {
            groups.append(FileGroup(header: "These look like screenshots", files: screenshots))
        }
        
        // Duplicates pattern - files with " copy", "(1)", "(2)", etc. in name
        let duplicates = files.filter { file in
            let lowercaseName = file.name.lowercased()
            return lowercaseName.contains(" copy") ||
                   lowercaseName.contains("copy ") ||
                   lowercaseName.range(of: #"\(\d+\)"#, options: .regularExpression) != nil
        }
        
        if !duplicates.isEmpty {
            groups.append(FileGroup(header: "Possible duplicates", files: duplicates))
        }
        
        // Large files pattern - files > 100MB (use raw bytes to avoid localized size parsing)
        let largeFiles = files.filter { file in
            file.sizeInBytes > 100 * 1024 * 1024
        }
        
        if !largeFiles.isEmpty {
            groups.append(FileGroup(header: "Large files", files: largeFiles))
        }
        
        // Untitled files pattern - files starting with "untitled", "document", "file"
        let untitled = files.filter { file in
            let lowercaseName = file.name.lowercased()
            return lowercaseName.hasPrefix("untitled") ||
                   lowercaseName.hasPrefix("document") ||
                   lowercaseName.hasPrefix("file ")
        }
        
        if !untitled.isEmpty {
            groups.append(FileGroup(header: "Untitled files", files: untitled))
        }
        
        return groups
    }
    
    /// Combine date and pattern grouping with priority to patterns
    func groupFiles(_ files: [FileItem], mode: GroupingMode = .date) -> [FileGroup] {
        switch mode {
        case .none:
            // Return all files in a single group with no header
            return files.isEmpty ? [] : [FileGroup(header: "", files: files)]
        case .date:
            return groupFilesByDate(files)
        case .patterns:
            return detectPatterns(files)
        case .combined:
            // First show pattern groups, then date groups for remaining files
            let patterns = detectPatterns(files)
            let patternFileIDs = Set(patterns.flatMap { $0.files.map { $0.id } })
            let remainingFiles = files.filter { !patternFileIDs.contains($0.id) }
            let dateGroups = groupFilesByDate(remainingFiles)
            return patterns + dateGroups
        }
    }
    
    enum GroupingMode {
        case none
        case date
        case patterns
        case combined
    }
}
