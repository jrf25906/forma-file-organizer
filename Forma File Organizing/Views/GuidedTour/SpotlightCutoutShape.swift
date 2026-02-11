import SwiftUI

/// A shape that draws a full-screen dimmed overlay with a rounded-rect cutout
/// (spotlight) around a target frame. Use with `.fill(style: FillStyle(eoFill: true))`
/// to punch the hole via the even-odd fill rule.
///
/// The cutout animates smoothly between target frames thanks to the custom
/// `Animatable` conformance that interpolates all four CGRect components.
struct SpotlightCutoutShape: Shape, Animatable {

    // MARK: - Properties

    /// The frame of the UI element to spotlight.
    var targetFrame: CGRect

    /// Extra breathing room around the target frame (default 8pt).
    var padding: CGFloat = 8

    /// Corner radius for the cutout rounded rect (matches `FormaRadius.card`).
    var cornerRadius: CGFloat = 12

    // MARK: - Animatable

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(targetFrame.origin.x, targetFrame.origin.y),
                AnimatablePair(targetFrame.size.width, targetFrame.size.height)
            )
        }
        set {
            targetFrame.origin.x = newValue.first.first
            targetFrame.origin.y = newValue.first.second
            targetFrame.size.width = newValue.second.first
            targetFrame.size.height = newValue.second.second
        }
    }

    // MARK: - Shape

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Outer rectangle — covers the entire overlay area.
        path.addRect(rect)

        // Inner rounded rect — expanded by `padding` on every side.
        let cutout = targetFrame.insetBy(dx: -padding, dy: -padding)
        path.addRoundedRect(
            in: cutout,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )

        return path
    }
}
