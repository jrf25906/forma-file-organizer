import SwiftUI

// MARK: - Forma Section

struct FormaSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(title)
                .font(.formaBodySemibold)
                .foregroundColor(.formaSecondaryLabel)
                .padding(.leading, FormaSpacing.micro)
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color.formaControlBackground)
            .formaCornerRadius(FormaRadius.card)
        }
        .padding(.bottom, FormaSpacing.standard)
    }
}
