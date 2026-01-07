import SwiftUI

/// A top-aligned, material-based blur overlay that fades out vertically.
/// Use to create a "cards coming into focus" effect as content scrolls underneath.
struct TaperedFocusOverlay: View {
    let height: CGFloat

    init(height: CGFloat = FormaLayout.Content.taperedFocusHeight) {
        self.height = height
    }

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(maskGradient)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var maskGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.formaBoneWhite.opacity(Color.FormaOpacity.prominent + Color.FormaOpacity.medium), location: 0.0),
                .init(color: Color.formaBoneWhite.opacity(Color.FormaOpacity.prominent + Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle), location: 0.12),
                .init(color: Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.subtle), location: 0.28),
                .init(color: Color.formaBoneWhite.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle), location: 0.52),
                .init(color: Color.formaBoneWhite.opacity(Color.FormaOpacity.ultraSubtle - Color.FormaOpacity.ultraSubtle), location: 0.74),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
            .padding(.top, FormaSpacing.tight)
            .padding()
        }

        TaperedFocusOverlay(height: 200)
    }
    .frame(width: 900, height: 600)
    .background(GradientBackdropView())
}
