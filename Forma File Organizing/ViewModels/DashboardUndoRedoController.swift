import Foundation
import SwiftData

/// Isolated undo/redo orchestration for DashboardViewModel.
@MainActor
final class DashboardUndoRedoController {

    private let coordinator: FileOrganizationCoordinator

    init(coordinator: FileOrganizationCoordinator) {
        self.coordinator = coordinator
    }

    var undoStack: [any UndoableCommand] { coordinator.undoStack }
    var redoStack: [any UndoableCommand] { coordinator.redoStack }

    func canUndo() -> Bool {
        coordinator.canUndo()
    }

    func canRedo() -> Bool {
        coordinator.canRedo()
    }

    func undoLastAction(
        allFiles: [FileItem],
        context: ModelContext?,
        onUnavailable: () -> Void,
        onComplete: @escaping () -> Void
    ) {
        if context == nil,
           let lastCommand = coordinator.undoStack.last,
           !(lastCommand is SkipFileCommand) {
            onUnavailable()
            return
        }

        coordinator.undoLastAction(allFiles: allFiles, context: context, onComplete: onComplete)
    }

    func redoLastAction(
        allFiles: [FileItem],
        context: ModelContext?,
        onUnavailable: () -> Void,
        onComplete: @escaping () -> Void
    ) async {
        if context == nil,
           let lastCommand = coordinator.redoStack.last,
           !(lastCommand is SkipFileCommand) {
            onUnavailable()
            return
        }

        await coordinator.redoLastAction(allFiles: allFiles, context: context, onComplete: onComplete)
    }
}
