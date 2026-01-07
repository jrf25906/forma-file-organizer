import SwiftUI

/// Command palette (⌘K) - searchable list of all available commands
/// Inspired by Linear, Notion, and modern productivity apps
struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedIndex = 0

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.formaObsidian.opacity(Color.FormaOpacity.overlay)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Palette card
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: FormaSpacing.standard) {
                    Image(systemName: "magnifyingglass")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabel)

                    TextField("Search commands...", text: $searchText)
                        .font(.formaBodyLarge)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onSubmit {
                            executeSelectedCommand()
                        }

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.formaBody)
                                .foregroundColor(.formaSecondaryLabel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(FormaSpacing.generous)
                .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))

                Divider()

                // Command list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                                CommandRow(
                                    command: command,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    executeCommand(command)
                                }
                                .onHover { hovering in
                                    if hovering {
                                        selectedIndex = index
                                    }
                                }
                            }
                        }
                        .padding(.vertical, FormaSpacing.tight)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .frame(maxHeight: 400)

                // Footer hint
                HStack {
                    Text("↑↓ Navigate")
                    Text("•")
                    Text("↵ Execute")
                    Text("•")
                    Text("esc Close")
                }
                .font(.formaSmall)
                .foregroundColor(.formaTertiaryLabel)
                .padding(FormaSpacing.standard)
                .frame(maxWidth: .infinity)
                .background(Color.formaControlBackground.opacity(Color.FormaOpacity.medium))
            }
            .frame(width: 500)
            .background(Color.formaBackground)
            .formaCornerRadius(FormaRadius.large)
            .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.overlay), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(filteredCommands.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    // MARK: - Commands

    private var allCommands: [Command] {
        [
            // View commands
            Command(
                id: "grid-view",
                name: "Switch to Grid View",
                shortcut: "⌘1",
                category: .view,
                icon: "square.grid.2x2"
            ) {
                dashboardViewModel.currentViewMode = .grid
            },
            Command(
                id: "list-view",
                name: "Switch to List View",
                shortcut: "⌘2",
                category: .view,
                icon: "list.bullet"
            ) {
                dashboardViewModel.currentViewMode = .list
            },
            Command(
                id: "tile-view",
                name: "Switch to Tile View",
                shortcut: "⌘3",
                category: .view,
                icon: "rectangle.grid.1x2"
            ) {
                dashboardViewModel.currentViewMode = .card
            },

            // Filter commands
            Command(
                id: "show-pending",
                name: "Show Pending Files",
                shortcut: nil,
                category: .filter,
                icon: "tray"
            ) {
                dashboardViewModel.reviewFilterMode = .needsReview
            },
            Command(
                id: "show-all",
                name: "Show All Files",
                shortcut: nil,
                category: .filter,
                icon: "folder"
            ) {
                dashboardViewModel.reviewFilterMode = .all
            },

            // Action commands
            Command(
                id: "organize-file",
                name: "Organize Focused File",
                shortcut: "↵",
                category: .action,
                icon: "checkmark.circle"
            ) {
                dashboardViewModel.organizeFocusedFile(context: modelContext)
            },
            Command(
                id: "organize-advance",
                name: "Organize and Advance",
                shortcut: "⌘↵",
                category: .action,
                icon: "checkmark.circle.badge.arrow.right"
            ) {
                dashboardViewModel.organizeFocusedFile(context: modelContext)
                dashboardViewModel.focusNextFile()
            },
            Command(
                id: "skip-file",
                name: "Skip File",
                shortcut: "S",
                category: .action,
                icon: "forward"
            ) {
                dashboardViewModel.skipFocusedFile()
            },
            Command(
                id: "edit-destination",
                name: "Edit Destination",
                shortcut: "E",
                category: .action,
                icon: "pencil"
            ) {
                dashboardViewModel.editDestinationForFocusedFile()
            },
            Command(
                id: "create-rule",
                name: "Create Rule from File",
                shortcut: "R",
                category: .action,
                icon: "plus.rectangle.on.rectangle"
            ) {
                if let focusedPath = dashboardViewModel.focusedFilePath,
                   let focused = dashboardViewModel.visibleFiles.first(where: { $0.path == focusedPath }) {
                    nav.ruleEditorFileContext = focused
                    nav.isShowingRuleEditor = true
                }
            },
            Command(
                id: "quick-look",
                name: "Quick Look",
                shortcut: "Space",
                category: .action,
                icon: "eye"
            ) {
                dashboardViewModel.quickLookFocusedFile()
            },

            // Navigation commands
            Command(
                id: "next-file",
                name: "Next File",
                shortcut: "J / ↓",
                category: .navigation,
                icon: "chevron.down"
            ) {
                dashboardViewModel.focusNextFile()
            },
            Command(
                id: "previous-file",
                name: "Previous File",
                shortcut: "K / ↑",
                category: .navigation,
                icon: "chevron.up"
            ) {
                dashboardViewModel.focusPreviousFile()
            },

            // Selection commands
            Command(
                id: "select-all",
                name: "Select All",
                shortcut: "⌘A",
                category: .selection,
                icon: "checkmark.square"
            ) {
                dashboardViewModel.selectAll()
            },
            Command(
                id: "deselect-all",
                name: "Deselect All",
                shortcut: "⌘D",
                category: .selection,
                icon: "square"
            ) {
                dashboardViewModel.deselectAll()
            },

            // Utility commands
            Command(
                id: "undo",
                name: "Undo",
                shortcut: "⌘Z",
                category: .utility,
                icon: "arrow.uturn.backward"
            ) {
                dashboardViewModel.undoLastAction(context: modelContext)
            },
            Command(
                id: "redo",
                name: "Redo",
                shortcut: "⌘⇧Z",
                category: .utility,
                icon: "arrow.uturn.forward"
            ) {
                dashboardViewModel.redoLastAction(context: modelContext)
            },
        ]
    }

    private var filteredCommands: [Command] {
        if searchText.isEmpty {
            return allCommands
        }
        return allCommands.filter { command in
            command.name.localizedCaseInsensitiveContains(searchText) ||
            command.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func executeSelectedCommand() {
        guard !filteredCommands.isEmpty, selectedIndex < filteredCommands.count else { return }
        executeCommand(filteredCommands[selectedIndex])
    }

    private func executeCommand(_ command: Command) {
        command.action()
        dismiss()
    }
}

// MARK: - Command Model

struct Command: Identifiable {
    let id: String
    let name: String
    let shortcut: String?
    let category: CommandCategory
    let icon: String
    let action: () -> Void

    enum CommandCategory: String, CaseIterable {
        case view = "View"
        case filter = "Filter"
        case action = "Action"
        case navigation = "Navigation"
        case selection = "Selection"
        case utility = "Utility"
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let command: Command
    let isSelected: Bool

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Icon
            Image(systemName: command.icon)
                .font(.formaBody)
                .foregroundColor(isSelected ? .formaSteelBlue : .formaSecondaryLabel)
                .frame(width: 20)

            // Name
            Text(command.name)
                .font(.formaBody)
                .foregroundColor(.formaLabel)

            Spacer()

            // Category badge
            Text(command.category.rawValue)
                .font(.formaSmallMedium)
                .foregroundColor(.formaTertiaryLabel)
                .padding(.horizontal, FormaSpacing.tight)
                .padding(.vertical, FormaSpacing.micro)
                .background(Color.formaControlBackground.opacity(Color.FormaOpacity.medium))
                .formaCornerRadius(FormaRadius.micro)

            // Shortcut
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.formaMonoSmall)
                    .foregroundColor(.formaSecondaryLabel)
                    .padding(.horizontal, FormaSpacing.tight)
                    .padding(.vertical, FormaSpacing.micro)
                    .background(Color.formaControlBackground)
                    .formaCornerRadius(FormaRadius.micro)
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                            .strokeBorder(Color.formaSeparator, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, FormaSpacing.generous)
        .padding(.vertical, FormaSpacing.standard)
        .background(isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light) : Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview {
    CommandPaletteView()
        .environmentObject(DashboardViewModel(services: AppServices()))
        .environmentObject(NavigationViewModel())
}
