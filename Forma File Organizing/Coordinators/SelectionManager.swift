import Foundation
import Combine

/// Manages file selection state, keyboard navigation, and selection operations.
@MainActor
class SelectionManager: ObservableObject {
    // MARK: - Published State
    
    /// IDs of currently selected files
    @Published var selectedFileIDs: Set<String> = []
    
    /// Whether selection mode is active
    @Published var isSelectionMode: Bool = false
    
    /// Path of the currently focused file (for keyboard navigation)
    @Published var focusedFilePath: String?
    
    /// Whether user is navigating with keyboard
    @Published var isKeyboardNavigating: Bool = false
    
    // MARK: - Selection Operations
    
    /// Toggle selection for a file
    func toggleSelection(for file: FileItem) {
        if selectedFileIDs.contains(file.path) {
            selectedFileIDs.remove(file.path)
        } else {
            selectedFileIDs.insert(file.path)
        }
        updateSelectionMode()
    }
    
    /// Select all visible files
    func selectAll(visibleFiles: [FileItem]) {
        selectedFileIDs = Set(visibleFiles.map { $0.path })
        updateSelectionMode()
    }
    
    /// Deselect all files
    func deselectAll() {
        selectedFileIDs.removeAll()
        updateSelectionMode()
    }
    
    /// Select a range of files
    func selectRange(from startFile: FileItem, to endFile: FileItem, in visibleFiles: [FileItem]) {
        guard let startIndex = visibleFiles.firstIndex(where: { $0.path == startFile.path }),
              let endIndex = visibleFiles.firstIndex(where: { $0.path == endFile.path }) else {
            return
        }
        
        let range = min(startIndex, endIndex)...max(startIndex, endIndex)
        for index in range {
            selectedFileIDs.insert(visibleFiles[index].path)
        }
        updateSelectionMode()
    }
    
    /// Check if a file is selected
    func isSelected(_ file: FileItem) -> Bool {
        selectedFileIDs.contains(file.path)
    }
    
    /// Get currently selected files from all files
    func getSelectedFiles(from allFiles: [FileItem]) -> [FileItem] {
        allFiles.filter { selectedFileIDs.contains($0.path) }
    }
    
    /// Check if all selected files can be organized together
    func canOrganizeAllSelected(from allFiles: [FileItem]) -> Bool {
        let files = getSelectedFiles(from: allFiles)
        guard !files.isEmpty else { return false }
        
        // All files must have a destination
        guard files.allSatisfy({ $0.destination != nil }) else {
            return false
        }

        // All files should have the same destination for "Organize All"
        let destinations = Set(files.compactMap { $0.destination?.displayName })
        return destinations.count == 1
    }
    
    // MARK: - Keyboard Navigation
    
    /// Move focus to the next file
    func focusNextFile(in visibleFiles: [FileItem]) {
        guard !visibleFiles.isEmpty else { return }
        isKeyboardNavigating = true
        
        if let index = focusedIndex(in: visibleFiles) {
            let next = min(index + 1, visibleFiles.count - 1)
            focusedFilePath = visibleFiles[next].path
        } else {
            focusedFilePath = visibleFiles.first?.path
        }
    }
    
    /// Move focus to the previous file
    func focusPreviousFile(in visibleFiles: [FileItem]) {
        guard !visibleFiles.isEmpty else { return }
        isKeyboardNavigating = true
        
        if let index = focusedIndex(in: visibleFiles) {
            let prev = max(index - 1, 0)
            focusedFilePath = visibleFiles[prev].path
        } else {
            focusedFilePath = visibleFiles.first?.path
        }
    }
    
    /// Get the currently focused file
    func getFocusedFile(in visibleFiles: [FileItem]) -> FileItem? {
        if let index = focusedIndex(in: visibleFiles) {
            return visibleFiles[index]
        }
        return visibleFiles.first
    }
    
    // MARK: - Private Helpers
    
    private func updateSelectionMode() {
        isSelectionMode = !selectedFileIDs.isEmpty
    }
    
    private func focusedIndex(in files: [FileItem]) -> Int? {
        guard let path = focusedFilePath else { return nil }
        return files.firstIndex { $0.path == path }
    }
}
