import SwiftUI

/// Legacy wrapper for FormaCheckbox
/// This maintains backward compatibility while using the unified component
struct SelectionCheckbox: View {
    let isSelected: Bool
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        FormaCheckbox.selection(
            isSelected: isSelected,
            isVisible: isVisible,
            action: action
        )
    }
}

#Preview {
    VStack(spacing: FormaSpacing.standard) {
        SelectionCheckbox(isSelected: false, isVisible: true, action: {})
        SelectionCheckbox(isSelected: true, isVisible: true, action: {})
    }
    .padding()
}
