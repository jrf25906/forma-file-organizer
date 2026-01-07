import SwiftUI
import AppKit

/// A Finder-style expandable search field for the toolbar.
///
/// Behavior:
/// - **Collapsed**: Shows a compact native search field
/// - **Expanded**: Grows to a wider native search field on focus / text
/// - Auto-collapses when losing focus with empty text (and clears on Escape)
/// - Supports ⌘F keyboard shortcut via `shouldFocus` binding
struct ToolbarExpandableSearch: View {
    @Binding var text: String
    @Binding var shouldFocus: Bool
    var placeholder: String = "Search"
    var onSubmit: (() -> Void)?

    @State private var isExpanded: Bool = false
    @FocusState private var isFieldFocused: Bool

    private let collapsedWidth: CGFloat = 160
    private let expandedWidth: CGFloat = 240

    private var currentWidth: CGFloat {
        (isExpanded || isFieldFocused || !text.isEmpty) ? expandedWidth : collapsedWidth
    }

    var body: some View {
        NativeSearchField(
            text: $text,
            isFieldFocused: _isFieldFocused,
            placeholder: placeholder,
            onEscape: {
                collapseIfEmpty()
            },
            onSubmit: onSubmit
        )
        .frame(width: currentWidth)
        .animation(.easeInOut(duration: FormaAnimation.disclosureDuration), value: currentWidth)
        .onChange(of: shouldFocus) { _, newValue in
            if newValue {
                expand()
                shouldFocus = false
            }
        }
        .onChange(of: isFieldFocused) { _, focused in
            if !focused && text.isEmpty {
                withAnimation(.easeInOut(duration: FormaAnimation.disclosureDuration)) {
                    isExpanded = false
                }
            }
        }
    }

    private func expand() {
        isExpanded = true
        // Delay focus to allow animation to start
        DispatchQueue.main.asyncAfter(deadline: .now() + (FormaAnimation.microDuration / 3)) {
            isFieldFocused = true
        }
    }

    private func collapseIfEmpty() {
        if text.isEmpty {
            withAnimation(.easeInOut(duration: FormaAnimation.disclosureDuration)) {
                isExpanded = false
            }
        }
    }
}

/// Native NSSearchField wrapper with focus state support.
struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    @FocusState var isFieldFocused: Bool
    var placeholder: String
    var onEscape: (() -> Void)?
    var onSubmit: (() -> Void)?

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.bezelStyle = .roundedBezel
        searchField.controlSize = .small
        searchField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        searchField.focusRingType = .exterior
        context.coordinator.searchField = searchField
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }

        // Handle focus state
        if isFieldFocused && searchField.window?.firstResponder != searchField.currentEditor() {
            DispatchQueue.main.async {
                searchField.window?.makeFirstResponder(searchField)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: NativeSearchField
        weak var searchField: NSSearchField?

        init(_ parent: NativeSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            let newText = searchField.stringValue
            parent.text = newText
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.text = ""
                control.window?.makeFirstResponder(nil)
                parent.onEscape?()
                return true
            }
            return false
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            DispatchQueue.main.async {
                self.parent.isFieldFocused = true
            }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            DispatchQueue.main.async {
                self.parent.isFieldFocused = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var searchText = ""
        @State private var shouldFocus = false

        var body: some View {
            VStack(spacing: 20) {
                Text("Search text: \(searchText)")

                HStack {
                    Spacer()
                    ToolbarExpandableSearch(
                        text: $searchText,
                        shouldFocus: $shouldFocus
                    )
                }
                .padding()

                Button("Focus Search (⌘F)") {
                    shouldFocus = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            .padding()
            .frame(width: 400, height: 200)
        }
    }

    return PreviewWrapper()
}
