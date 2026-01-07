import SwiftUI

struct ToastView: View {
    let message: String
    let canUndo: Bool
    let isError: Bool
    let onUndo: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? Color.formaError : Color.formaSage)
            VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                Text(message)
                    .formaBodyStyle()
                    .foregroundColor(Color.formaLabel)
            }
            Spacer()
            if canUndo, let onUndo = onUndo {
                Button("Undo") {
                    onUndo()
                    onDismiss()
                }
                .buttonStyle(.plain)
                .formaBodyStyle()
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.formaCaptionBold)
                    .foregroundColor(Color.formaSecondaryLabel)
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaControlBackground)
        .formaCornerRadius(FormaRadius.control)
        .shadow(
            color: Color.formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

struct ToastHost<Content: View>: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ViewBuilder var content: () -> Content

    @State private var isVisible: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content()
            if let toast = viewModel.toastState, toast.isVisible {
                ToastView(
                    message: toast.message,
                    canUndo: toast.canUndo,
                    isError: toast.isError,
                    onUndo: toast.action,
                    onDismiss: {
                        viewModel.toastState?.isVisible = false
                    }
                )
                .padding(FormaSpacing.extraLarge)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: viewModel.toastState?.isVisible ?? false) { _, newValue in
            isVisible = newValue
        }
    }
}
