import Foundation
import SwiftUI
import Combine

/// Manages file selection state and keyboard navigation.
/// Responsible for:
/// - Multi-select operations (select all, range select, toggle)
/// - Keyboard navigation (up/down arrow keys)
/// - Focus management
/// - Selection state tracking
@MainActor
class SelectionViewModel: ObservableObject {
    // MARK: - Published Properties

    /// IDs of currently selected files
    @Published var selectedFileIDs: Set<String> = []

    /// Whether selection mode is active (one or more files selected)
    @Published private(set) var isSelectionMode: Bool = false

    /// Path of the currently focused file (for keyboard navigation)
    @Published var focusedFilePath: String?

    /// Whether user is navigating with keyboard
    @Published var isKeyboardNavigating: Bool = false

    // MARK: - Dependencies

    private let selectionManager: SelectionManager

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(selectionManager: SelectionManager = SelectionManager()) {
        self.selectionManager = selectionManager
        setupSelectionForwarding()
    }

    // MARK: - Selection Operations

    /// Toggle selection for a file
    func toggleSelection(for file: FileItem) {
        selectionManager.toggleSelection(for: file)
        syncFromSelectionManager()
    }

    /// Select all visible files
    func selectAll(visibleFiles: [FileItem]) {
        selectionManager.selectAll(visibleFiles: visibleFiles)
        syncFromSelectionManager()
    }

    /// Deselect all files
    func deselectAll() {
        selectionManager.deselectAll()
        syncFromSelectionManager()
    }

    /// Select a range of files (Shift+Click)
    func selectRange(from startFile: FileItem, to endFile: FileItem, in visibleFiles: [FileItem]) {
        selectionManager.selectRange(from: startFile, to: endFile, in: visibleFiles)
        syncFromSelectionManager()
    }

    /// Check if a file is selected
    func isSelected(_ file: FileItem) -> Bool {
        selectionManager.isSelected(file)
    }

    /// Get currently selected files
    func getSelectedFiles(from allFiles: [FileItem]) -> [FileItem] {
        selectionManager.getSelectedFiles(from: allFiles)
    }

    /// Check if all selected files can be organized
    func canOrganizeAllSelected(from allFiles: [FileItem]) -> Bool {
        selectionManager.canOrganizeAllSelected(from: allFiles)
    }

    // MARK: - Keyboard Navigation

    /// Move focus to next file (Down Arrow)
    func focusNextFile(in visibleFiles: [FileItem]) {
        selectionManager.focusNextFile(in: visibleFiles)
        syncFromSelectionManager()
    }

    /// Move focus to previous file (Up Arrow)
    func focusPreviousFile(in visibleFiles: [FileItem]) {
        selectionManager.focusPreviousFile(in: visibleFiles)
        syncFromSelectionManager()
    }

    /// Get the currently focused file
    func getFocusedFile(in visibleFiles: [FileItem]) -> FileItem? {
        selectionManager.getFocusedFile(in: visibleFiles)
    }

    /// Clear keyboard navigation state
    func clearKeyboardNavigation() {
        isKeyboardNavigating = false
        focusedFilePath = nil
    }

    // MARK: - Computed Properties

    /// Selected files (convenience accessor)
    func selectedFiles(from allFiles: [FileItem]) -> [FileItem] {
        getSelectedFiles(from: allFiles)
    }

    /// Selection count
    var selectionCount: Int {
        selectedFileIDs.count
    }

    /// Whether any files are selected
    var hasSelection: Bool {
        !selectedFileIDs.isEmpty
    }

    // MARK: - Private Helpers

    /// Sync state from SelectionManager
    private func syncFromSelectionManager() {
        selectedFileIDs = selectionManager.selectedFileIDs
        isSelectionMode = selectionManager.isSelectionMode
        focusedFilePath = selectionManager.focusedFilePath
        isKeyboardNavigating = selectionManager.isKeyboardNavigating
    }

    /// Setup forwarding from SelectionManager
    private func setupSelectionForwarding() {
        selectionManager.objectWillChange
            .sink { [weak self] _ in
                self?.syncFromSelectionManager()
            }
            .store(in: &cancellables)

        // Initial sync
        syncFromSelectionManager()
    }
}
