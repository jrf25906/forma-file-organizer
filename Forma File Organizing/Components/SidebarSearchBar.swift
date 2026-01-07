import SwiftUI
import AppKit

/// A full-width search bar designed for the sidebar bottom.
/// Uses native NSSearchField for proper macOS appearance and behavior.
struct SidebarSearchBar: View {
    @Binding var text: String
    @Binding var shouldFocus: Bool
    var placeholder: String = "Search files..."
    var onSubmit: (() -> Void)?

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        SidebarNativeSearchField(
            text: $text,
            isFieldFocused: _isFieldFocused,
            placeholder: placeholder,
            onEscape: {
                text = ""
            },
            onSubmit: onSubmit
        )
        .frame(height: FormaLayout.SidebarSearch.height)
        .onChange(of: shouldFocus) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isFieldFocused = true
                    shouldFocus = false
                }
            }
        }
    }
}

/// Native NSSearchField wrapper for sidebar with full-width styling.
struct SidebarNativeSearchField: NSViewRepresentable {
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
        searchField.controlSize = .regular
        searchField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        searchField.focusRingType = .none

        // Use auto layout for full-width behavior
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)

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
        var parent: SidebarNativeSearchField
        weak var searchField: NSSearchField?

        init(_ parent: SidebarNativeSearchField) {
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

#if DEBUG
struct SidebarSearchBar_Previews: PreviewProvider {
    static var previews: some View {
        struct PreviewWrapper: View {
            @State private var searchText = ""
            @State private var shouldFocus = false

            var body: some View {
                VStack {
                    Spacer()

                    SidebarSearchBar(
                        text: $searchText,
                        shouldFocus: $shouldFocus
                    )
                    .padding(.horizontal, FormaLayout.Sidebar.expandedHorizontalPadding)
                    .padding(.bottom, FormaSpacing.standard)
                }
                .frame(width: FormaLayout.Dashboard.sidebarExpandedWidth, height: 400)
                .background(.regularMaterial)
            }
        }

        return PreviewWrapper()
            .previewDisplayName("Sidebar Search Bar")
    }
}
#endif
