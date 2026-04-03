import CoreGraphics

enum MainWindowFrameValidator {
    static func validatedFrame(
        _ restoredFrame: CGRect,
        visibleFrames: [CGRect],
        minimumSize: CGSize
    ) -> CGRect {
        guard !visibleFrames.isEmpty else { return restoredFrame }

        if isFullyCoveredByVisibleFrames(restoredFrame, visibleFrames: visibleFrames) {
            return restoredFrame
        }

        let targetVisibleFrame = preferredVisibleFrame(
            for: restoredFrame,
            within: visibleFrames
        )

        let adjustedSize = adjustedWindowSize(
            for: restoredFrame.size,
            within: targetVisibleFrame,
            minimumSize: minimumSize
        )

        if intersectsAnyVisibleFrame(restoredFrame, visibleFrames: visibleFrames) {
            return CGRect(
                origin: clampedOrigin(
                    for: restoredFrame.origin,
                    size: adjustedSize,
                    within: targetVisibleFrame
                ),
                size: adjustedSize
            )
        }

        return CGRect(
            origin: CGPoint(
                x: targetVisibleFrame.midX - (adjustedSize.width / 2),
                y: targetVisibleFrame.midY - (adjustedSize.height / 2)
            ),
            size: adjustedSize
        )
    }

    private static func preferredVisibleFrame(
        for restoredFrame: CGRect,
        within visibleFrames: [CGRect]
    ) -> CGRect {
        if let intersectingFrame = visibleFrames
            .map({ frame in (frame: frame, area: intersectionArea(between: restoredFrame, and: frame)) })
            .filter({ $0.area > 0 })
            .max(by: { $0.area < $1.area })?.frame {
            return intersectingFrame
        }

        let restoredCenter = CGPoint(x: restoredFrame.midX, y: restoredFrame.midY)
        return visibleFrames.min(by: {
            squaredDistance(from: restoredCenter, to: CGPoint(x: $0.midX, y: $0.midY)) <
            squaredDistance(from: restoredCenter, to: CGPoint(x: $1.midX, y: $1.midY))
        }) ?? visibleFrames[0]
    }

    private static func adjustedWindowSize(
        for restoredSize: CGSize,
        within visibleFrame: CGRect,
        minimumSize: CGSize
    ) -> CGSize {
        let minimumWidth = min(minimumSize.width, visibleFrame.width)
        let minimumHeight = min(minimumSize.height, visibleFrame.height)

        return CGSize(
            width: min(max(restoredSize.width, minimumWidth), visibleFrame.width),
            height: min(max(restoredSize.height, minimumHeight), visibleFrame.height)
        )
    }

    private static func clampedOrigin(
        for origin: CGPoint,
        size: CGSize,
        within visibleFrame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
    }

    private static func intersectsAnyVisibleFrame(
        _ restoredFrame: CGRect,
        visibleFrames: [CGRect]
    ) -> Bool {
        visibleFrames.contains { intersectionArea(between: restoredFrame, and: $0) > 0 }
    }

    private static func isFullyCoveredByVisibleFrames(
        _ restoredFrame: CGRect,
        visibleFrames: [CGRect]
    ) -> Bool {
        guard !restoredFrame.isNull, !restoredFrame.isEmpty else { return true }

        var uncoveredRects = [restoredFrame]

        for visibleFrame in visibleFrames {
            uncoveredRects = uncoveredRects.flatMap { subtract(visibleFrame, from: $0) }
            if uncoveredRects.isEmpty {
                return true
            }
        }

        return uncoveredRects.isEmpty
    }

    private static func subtract(_ coveringFrame: CGRect, from rect: CGRect) -> [CGRect] {
        let intersection = rect.intersection(coveringFrame)
        guard !intersection.isNull, !intersection.isEmpty else { return [rect] }

        var fragments: [CGRect] = []

        if intersection.minY > rect.minY {
            fragments.append(
                CGRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: rect.width,
                    height: intersection.minY - rect.minY
                )
            )
        }

        if intersection.maxY < rect.maxY {
            fragments.append(
                CGRect(
                    x: rect.minX,
                    y: intersection.maxY,
                    width: rect.width,
                    height: rect.maxY - intersection.maxY
                )
            )
        }

        if intersection.minX > rect.minX {
            fragments.append(
                CGRect(
                    x: rect.minX,
                    y: intersection.minY,
                    width: intersection.minX - rect.minX,
                    height: intersection.height
                )
            )
        }

        if intersection.maxX < rect.maxX {
            fragments.append(
                CGRect(
                    x: intersection.maxX,
                    y: intersection.minY,
                    width: rect.maxX - intersection.maxX,
                    height: intersection.height
                )
            )
        }

        return fragments.filter { !$0.isNull && !$0.isEmpty }
    }

    private static func intersectionArea(between lhs: CGRect, and rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
    }

    private static func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }
}
