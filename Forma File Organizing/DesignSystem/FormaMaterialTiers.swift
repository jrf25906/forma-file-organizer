import SwiftUI

enum FormaMaterialTier: String, Sendable {
    case base
    case raised
    case overlay
}

struct FormaMaterialSurface: View {
    let tier: FormaMaterialTier
    let cornerRadius: CGFloat
    let tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.controlActiveState) private var controlActiveState

    init(
        tier: FormaMaterialTier,
        cornerRadius: CGFloat = FormaRadius.card,
        tint: Color? = nil
    ) {
        self.tier = tier
        self.cornerRadius = cornerRadius
        self.tint = tint
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        baseSurface(shape: shape)
            .overlay(tintOverlay(shape: shape))
            .overlay(specularOverlay(shape: shape))
            .overlay(rimOverlay(shape: shape))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
            .accessibilityHidden(true)
    }

    private var isWindowActive: Bool {
        controlActiveState != .inactive
    }

    @ViewBuilder
    private func baseSurface(shape: RoundedRectangle) -> some View {
        if reduceTransparency {
            shape.fill(Color.formaControlBackground.opacity(Color.FormaOpacity.prominent + Color.FormaOpacity.light))
        } else if #available(macOS 26.0, *) {
            if let tint {
                shape.glassEffect(.regular.tint(tint.opacity(glassTintOpacity)))
            } else {
                shape.glassEffect(.regular)
            }
        } else {
            VisualEffectView(material: fallbackEffectMaterial, blendingMode: .withinWindow)
                .clipShape(shape)
        }
    }

    @ViewBuilder
    private func tintOverlay(shape: RoundedRectangle) -> some View {
        if reduceTransparency {
            EmptyView()
        } else if #available(macOS 26.0, *) {
            EmptyView()
        } else if let tint {
            shape
                .fill(tint.opacity(fallbackTintOpacity))
                .blendMode(.plusLighter)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func specularOverlay(shape: RoundedRectangle) -> some View {
        if reduceTransparency || specularOpacity <= 0.0 {
            EmptyView()
        } else {
            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(Color.FormaOpacity.strong - (Color.FormaOpacity.ultraSubtle * 2)),
                    Color.formaBoneWhite.opacity(Color.FormaOpacity.light),
                    Color.formaBoneWhite.opacity(Color.FormaOpacity.ultraSubtle - Color.FormaOpacity.ultraSubtle),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(specularOpacity)
            .clipShape(shape)
            .blendMode(.screen)
        }
    }

    @ViewBuilder
    private func rimOverlay(shape: RoundedRectangle) -> some View {
        let rim = FormaRimStyle.forTier(tier, isWindowActive: isWindowActive)
        shape
            .strokeBorder(rim.outerColor, lineWidth: rim.outerLineWidth)
            .overlay(
                shape
                    .inset(by: rim.innerInset)
                    .stroke(rim.innerColor, lineWidth: rim.innerLineWidth)
            )
    }

    private var fallbackEffectMaterial: NSVisualEffectView.Material {
        switch tier {
        case .base:
            return .contentBackground
        case .raised:
            return .popover
        case .overlay:
            return .hudWindow
        }
    }

    private var glassTintOpacity: Double {
        let base: Double
        switch tier {
        case .base:
            base = Color.FormaOpacity.medium - Color.FormaOpacity.ultraSubtle
        case .raised:
            base = Color.FormaOpacity.overlay - Color.FormaOpacity.ultraSubtle
        case .overlay:
            base = Color.FormaOpacity.overlay + (Color.FormaOpacity.ultraSubtle * 2)
        }
        return base * (isWindowActive ? (Color.FormaOpacity.prominent + Color.FormaOpacity.medium) : Color.FormaOpacity.high)
    }

    private var fallbackTintOpacity: Double {
        let base: Double
        switch tier {
        case .base:
            base = Color.FormaOpacity.subtle
        case .raised:
            base = Color.FormaOpacity.light
        case .overlay:
            base = Color.FormaOpacity.light
        }
        return base * (isWindowActive ? (Color.FormaOpacity.prominent + Color.FormaOpacity.medium) : (Color.FormaOpacity.high - Color.FormaOpacity.subtle))
    }

    private var specularOpacity: Double {
        guard isWindowActive else { return 0.0 }

        switch tier {
        case .base:
            return Color.FormaOpacity.light
        case .raised:
            return Color.FormaOpacity.light + (Color.FormaOpacity.ultraSubtle * 3)
        case .overlay:
            return Color.FormaOpacity.medium + Color.FormaOpacity.ultraSubtle
        }
    }

    private var shadowColor: Color {
        guard !reduceTransparency else { return .clear }
        let base: Double
        switch tier {
        case .base:
            base = Color.FormaOpacity.ultraSubtle - Color.FormaOpacity.ultraSubtle
        case .raised:
            base = Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle
        case .overlay:
            base = Color.FormaOpacity.subtle
        }
        return Color.formaObsidian.opacity(
            base * (isWindowActive ? (Color.FormaOpacity.prominent + Color.FormaOpacity.medium) : Color.FormaOpacity.high)
        )
    }

    private var shadowRadius: CGFloat {
        switch tier {
        case .base:
            return 0
        case .raised:
            return 2
        case .overlay:
            return 3
        }
    }

    private var shadowYOffset: CGFloat {
        switch tier {
        case .base:
            return 0
        case .raised:
            return 1
        case .overlay:
            return 2
        }
    }
}

private struct FormaRimStyle: Sendable {
    let innerColor: Color
    let outerColor: Color
    let innerLineWidth: CGFloat
    let outerLineWidth: CGFloat
    let innerInset: CGFloat

    static func forTier(_ tier: FormaMaterialTier, isWindowActive: Bool) -> Self {
        let activeFactor: Double = isWindowActive ? (Color.FormaOpacity.prominent + Color.FormaOpacity.medium) : Color.FormaOpacity.high

        let innerOpacity: Double
        let outerOpacity: Double
        switch tier {
        case .base:
            innerOpacity = Color.FormaOpacity.medium - Color.FormaOpacity.ultraSubtle
            outerOpacity = Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle
        case .raised:
            innerOpacity = Color.FormaOpacity.medium + Color.FormaOpacity.ultraSubtle
            outerOpacity = Color.FormaOpacity.light
        case .overlay:
            innerOpacity = Color.FormaOpacity.overlay - Color.FormaOpacity.ultraSubtle
            outerOpacity = Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle
        }

        return FormaRimStyle(
            innerColor: Color.formaBoneWhite.opacity(innerOpacity * activeFactor),
            outerColor: Color.formaObsidian.opacity(outerOpacity * activeFactor),
            innerLineWidth: 1,
            outerLineWidth: 1,
            innerInset: 0.5
        )
    }
}

extension View {
    func formaMaterialTier(
        _ tier: FormaMaterialTier,
        cornerRadius: CGFloat = FormaRadius.card,
        tint: Color? = nil
    ) -> some View {
        background(
            FormaMaterialSurface(
                tier: tier,
                cornerRadius: cornerRadius,
                tint: tint
            )
        )
    }
}
