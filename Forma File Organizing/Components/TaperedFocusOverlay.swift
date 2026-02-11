import SwiftUI

/// A top-aligned gradient overlay that fades from the window background to clear.
/// The `solidHeight` portion stays fully opaque (covering the toolbar zone), then
/// a short `fadeLength` tail tapers to transparent below it.
struct TaperedFocusOverlay: View {
    /// Height of the fully opaque zone (typically the toolbar height).
    let solidHeight: CGFloat
    /// Length of the fade tail below the solid zone.
    let fadeLength: CGFloat

    init(solidHeight: CGFloat, fadeLength: CGFloat = 28) {
        self.solidHeight = solidHeight
        self.fadeLength = fadeLength
    }

    private var totalHeight: CGFloat { solidHeight + fadeLength }

    /// The fraction where the solid zone ends and the fade begins.
    private var fadeStart: CGFloat {
        guard totalHeight > 0 else { return 1.0 }
        return solidHeight / totalHeight
    }

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.formaBackground, location: 0.0),
                .init(color: Color.formaBackground, location: fadeStart),
                .init(color: Color.formaBackground.opacity(0.0), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: totalHeight)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack(alignment: .top) {
        ScrollView {
            VStack(spacing: FormaSpacing.generous) {
                ForEach(0..<20) { index in
                    RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                        .fill(Color.formaControlBackground)
                        .frame(height: 80)
                        .overlay(Text("Card \(index)"))
                }
            }
            .padding(.top, 60)
            .padding()
        }

        TaperedFocusOverlay(solidHeight: 42, fadeLength: 28)
    }
    .frame(width: 900, height: 600)
    .background(GradientBackdropView())
}
