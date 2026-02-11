# SwiftUI macOS Patterns Reference

Code-oriented reference for macOS-specific SwiftUI patterns and techniques.

---

## Scene Types

### WindowGroup
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .defaultPosition(.center)
    }
}
```

### Settings
```swift
Settings {
    TabView {
        GeneralSettingsView()
            .tabItem { Label("General", systemImage: "gear") }
        AppearanceSettingsView()
            .tabItem { Label("Appearance", systemImage: "paintbrush") }
    }
    .frame(width: 450)
}
```
- Opens with Cmd+, automatically.
- Use `TabView` for multi-pane preferences.

### MenuBarExtra
```swift
MenuBarExtra("Status", systemImage: "folder.fill") {
    MenuBarView()
}
.menuBarExtraStyle(.window) // or .menu for simple menus
```

### DocumentGroup
```swift
DocumentGroup(newDocument: MyDocument()) { file in
    DocumentEditorView(document: file.$document)
}
```

---

## NavigationSplitView

### Two-Column
```swift
NavigationSplitView {
    SidebarView(selection: $selectedItem)
} detail: {
    DetailView(item: selectedItem)
}
.navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
```

### Three-Column
```swift
NavigationSplitView {
    SidebarView(selection: $selectedCategory)
} content: {
    ContentListView(category: selectedCategory, selection: $selectedItem)
} detail: {
    DetailView(item: selectedItem)
}
.navigationSplitViewStyle(.balanced)
```

### Column Visibility
```swift
@State private var columnVisibility: NavigationSplitViewVisibility = .all

NavigationSplitView(columnVisibility: $columnVisibility) {
    // sidebar
} detail: {
    // detail
}
```
- `.all` — both columns visible
- `.doubleColumn` — sidebar + detail (or content + detail)
- `.detailOnly` — detail only, sidebar collapsed

---

## Toolbar Patterns

### Placement
```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("Organize", action: organize)
    }
    ToolbarItem(placement: .secondaryAction) {
        Menu("Sort") { /* sort options */ }
    }
    ToolbarItem(placement: .navigation) {
        Button(action: goBack) {
            Image(systemName: "chevron.left")
        }
    }
    ToolbarItemGroup(placement: .automatic) {
        ViewModePicker(selection: $viewMode)
    }
}
```

### Toolbar Styles
```swift
.windowToolbarStyle(.unified)           // Title merged into toolbar
.windowToolbarStyle(.unifiedCompact)    // Compact unified
.windowToolbarStyle(.automatic)         // System default
.windowToolbarStyle(.expanded)          // Separate title bar + toolbar
```

### Search in Toolbar
```swift
.searchable(text: $searchText, placement: .toolbar)
.searchSuggestions {
    ForEach(suggestions) { suggestion in
        Text(suggestion.title).searchCompletion(suggestion.query)
    }
}
```

---

## Table (macOS)

```swift
Table(items, selection: $selection, sortOrder: $sortOrder) {
    TableColumn("Name", value: \.name) { item in
        Label(item.name, systemImage: item.icon)
    }
    .width(min: 150, ideal: 200)

    TableColumn("Date Modified", value: \.dateModified) { item in
        Text(item.dateModified, style: .date)
    }
    .width(120)

    TableColumn("Size", value: \.fileSize) { item in
        Text(item.formattedSize)
    }
    .width(80)
}
.contextMenu(forSelectionType: Item.ID.self) { selection in
    Button("Delete") { delete(selection) }
}
```

---

## List Patterns

### Sidebar List
```swift
List(selection: $selectedItem) {
    Section("Favorites") {
        ForEach(favorites) { item in
            Label(item.name, systemImage: item.icon)
                .tag(item.id)
        }
    }
    Section("Categories") {
        ForEach(categories) { category in
            Label(category.name, systemImage: category.icon)
                .badge(category.count)
                .tag(category.id)
        }
    }
}
.listStyle(.sidebar)
```

### Inset Grouped
```swift
List {
    Section("Account") {
        // rows
    }
}
.listStyle(.insetGrouped)  // macOS Ventura+
```

---

## NSViewRepresentable Recipes

### Visual Effect (Blur) Background
```swift
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
```

### Window Access
```swift
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Usage
.background(WindowAccessor { window in
    window?.titlebarAppearsTransparent = true
    window?.isMovableByWindowBackground = true
})
```

### Native Search Field
```swift
struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text = field.stringValue
        }
    }
}
```

---

## Keyboard Shortcuts

### Standard Shortcuts
```swift
Button("New Item") { createItem() }
    .keyboardShortcut("n", modifiers: .command)

Button("Delete") { deleteSelected() }
    .keyboardShortcut(.delete, modifiers: .command)

Button("OK") { confirm() }
    .keyboardShortcut(.defaultAction)  // Return key

Button("Cancel") { dismiss() }
    .keyboardShortcut(.cancelAction)   // Escape key
```

### Menu Commands
```swift
.commands {
    CommandGroup(replacing: .newItem) {
        Button("New Document") { newDocument() }
            .keyboardShortcut("n", modifiers: .command)
    }
    CommandMenu("Organize") {
        Button("Run Rules") { runRules() }
            .keyboardShortcut("r", modifiers: [.command, .shift])
    }
}
```

---

## Focus Management

```swift
@FocusState private var focusedField: Field?

enum Field { case name, path, description }

VStack {
    TextField("Name", text: $name)
        .focused($focusedField, equals: .name)
    TextField("Path", text: $path)
        .focused($focusedField, equals: .path)
}
.onSubmit { advanceFocus() }
.defaultFocus($focusedField, .name)
```

### Focusable Views
```swift
Text("Custom focusable")
    .focusable()
    .onMoveCommand { direction in
        handleArrowKey(direction)
    }
    .onExitCommand {
        clearSelection()
    }
```

---

## Drag and Drop

### Draggable
```swift
ForEach(items) { item in
    FileRowView(item: item)
        .draggable(item.url) {
            // Preview while dragging
            Label(item.name, systemImage: "doc")
        }
}
```

### Drop Target
```swift
.dropDestination(for: URL.self) { urls, location in
    handleDrop(urls: urls)
    return true
} isTargeted: { isTargeted in
    self.isDropTargeted = isTargeted
}
```

### With UTType
```swift
import UniformTypeIdentifiers

.dropDestination(for: Data.self, action: { items, location in
    // handle
}, isTargeted: { targeted in })

// Explicit UTType
.onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
    // handle NSItemProvider array
    return true
}
```

---

## Popovers, Sheets, and Alerts

### Popover (macOS Preferred)
```swift
.popover(isPresented: $showPopover, arrowEdge: .bottom) {
    PopoverContent()
        .frame(width: 300, height: 200)
}
```
- Popovers are non-modal on macOS. They dismiss when clicking outside.
- Preferred over sheets for contextual, non-blocking secondary UI.

### Sheet
```swift
.sheet(isPresented: $showSheet) {
    SheetView()
        .frame(minWidth: 400, minHeight: 300)
}
```
- Sheets on macOS slide down from the title bar and are modal to the window.
- They do not cover the full screen (unlike iOS).

### Alert
```swift
.alert("Delete Item?", isPresented: $showAlert) {
    Button("Cancel", role: .cancel) { }
    Button("Delete", role: .destructive) { deleteItem() }
} message: {
    Text("This action cannot be undone.")
}
```

### Confirmation Dialog
```swift
.confirmationDialog("Choose Format", isPresented: $showDialog) {
    Button("PDF") { export(.pdf) }
    Button("CSV") { export(.csv) }
    Button("JSON") { export(.json) }
}
```

---

## Environment Values (macOS-Relevant)

```swift
@Environment(\.colorScheme) var colorScheme                    // .light or .dark
@Environment(\.controlActiveState) var controlActiveState      // .active, .inactive, .key
@Environment(\.controlSize) var controlSize                    // .mini, .small, .regular, .large
@Environment(\.isEnabled) var isEnabled
@Environment(\.accessibilityReduceMotion) var reduceMotion
@Environment(\.accessibilityReduceTransparency) var reduceTransparency
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
@Environment(\.openWindow) var openWindow                      // Open new windows
@Environment(\.dismiss) var dismiss                            // Dismiss sheets/windows
@Environment(\.undoManager) var undoManager                    // System undo manager
```

### Control Active State
```swift
// Dim content when window is inactive (standard macOS behavior)
.opacity(controlActiveState == .active ? 1.0 : 0.6)
```

---

## Window Management

### Open Additional Windows
```swift
// In App struct:
WindowGroup(id: "inspector", for: Item.ID.self) { $id in
    InspectorView(itemID: id)
}

// To open:
@Environment(\.openWindow) var openWindow
openWindow(id: "inspector", value: selectedItem.id)
```

### Window Sizing
```swift
WindowGroup {
    ContentView()
}
.defaultSize(width: 1400, height: 970)
.windowResizability(.contentSize)      // Fixed to content
.windowResizability(.contentMinSize)   // Content sets minimum
.windowResizability(.automatic)        // User resizable
```

### Minimum Size
```swift
ContentView()
    .frame(minWidth: 600, minHeight: 400)
```
