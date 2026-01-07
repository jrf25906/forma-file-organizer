import SwiftUI
import SwiftData

/// View modifier that adds Phase 2 keyboard shortcuts for selection and bulk operations
struct DashboardKeyboardShortcuts: ViewModifier {
    @ObservedObject var viewModel: DashboardViewModel
    let context: ModelContext?
    
    func body(content: Content) -> some View {
        content
            .background(
                // Use hidden buttons to capture keyboard shortcuts
                Group {
                    // Select All: Cmd+A
                    Button("") { viewModel.selectAll() }
                        .keyboardShortcut("a", modifiers: .command)
                        .hidden()
                    
                    // Deselect: Cmd+D
                    Button("") { viewModel.deselectAll() }
                        .keyboardShortcut("d", modifiers: .command)
                        .hidden()
                    
                    // Undo: Cmd+Z
                    Button("") { 
                        if viewModel.canUndo() {
                            viewModel.undoLastAction(context: context)
                        }
                    }
                    .keyboardShortcut("z", modifiers: .command)
                    .hidden()
                    
                    // Redo: Cmd+Shift+Z
                    Button("") {
                        if viewModel.canRedo() {
                            viewModel.redoLastAction(context: context)
                        }
                    }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .hidden()
                    
                    // View Mode: Cmd+1 (Grid)
                    Button("") { viewModel.currentViewMode = .grid }
                        .keyboardShortcut("1", modifiers: .command)
                        .hidden()
                    
                    // View Mode: Cmd+2 (List)
                    Button("") { viewModel.currentViewMode = .list }
                        .keyboardShortcut("2", modifiers: .command)
                        .hidden()
                    
                    // View Mode: Cmd+3 (Card)
                    Button("") { viewModel.currentViewMode = .card }
                        .keyboardShortcut("3", modifiers: .command)
                        .hidden()
                    
                    // Organize Selected: Cmd+Return (only in selection mode)
                    if viewModel.isSelectionMode {
                        Button("") { viewModel.organizeSelectedFiles(context: context) }
                            .keyboardShortcut(.return, modifiers: .command)
                            .hidden()
                        
                        // Skip Selected: Cmd+Delete
                        Button("") { viewModel.skipSelectedFiles() }
                            .keyboardShortcut(.delete, modifiers: .command)
                            .hidden()
                        
                        // Bulk Edit: Cmd+E
                        Button("") { viewModel.showBulkEditSheet = true }
                            .keyboardShortcut("e", modifiers: .command)
                            .hidden()
                    }
                }
            )
    }
}

extension View {
    func dashboardKeyboardShortcuts(viewModel: DashboardViewModel, context: ModelContext?) -> some View {
        modifier(DashboardKeyboardShortcuts(viewModel: viewModel, context: context))
    }
}
