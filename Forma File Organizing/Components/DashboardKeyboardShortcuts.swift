import SwiftUI
import SwiftData

/// View modifier that adds Phase 2 keyboard shortcuts for selection and bulk operations
struct DashboardKeyboardShortcuts: ViewModifier {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var filterViewModel: FilterViewModel
    @ObservedObject var selectionViewModel: SelectionViewModel
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
                    Button("") { filterViewModel.currentViewMode = .grid }
                        .keyboardShortcut("1", modifiers: .command)
                        .hidden()
                    
                    // View Mode: Cmd+2 (List)
                    Button("") { filterViewModel.currentViewMode = .list }
                        .keyboardShortcut("2", modifiers: .command)
                        .hidden()
                    
                    // View Mode: Cmd+3 (Card)
                    Button("") { filterViewModel.currentViewMode = .card }
                        .keyboardShortcut("3", modifiers: .command)
                        .hidden()

                    // Organize Selected: Cmd+Return (only in selection mode)
                    if selectionViewModel.isSelectionMode {
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
    func dashboardKeyboardShortcuts(
        viewModel: DashboardViewModel,
        filterViewModel: FilterViewModel,
        selectionViewModel: SelectionViewModel,
        context: ModelContext?
    ) -> some View {
        modifier(
            DashboardKeyboardShortcuts(
                viewModel: viewModel,
                filterViewModel: filterViewModel,
                selectionViewModel: selectionViewModel,
                context: context
            )
        )
    }
}
