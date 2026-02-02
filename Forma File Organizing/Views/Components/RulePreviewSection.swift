import SwiftUI

struct RulePreviewSection: View {
    let onPreview: () -> Void

    var body: some View {
        Button(action: onPreview) {
            HStack(spacing: 4) {
                Image(systemName: "eye")
                Text("Preview matches")
            }
            .font(.formaSmall)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
