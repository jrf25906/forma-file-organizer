import SwiftUI

// MARK: - GuidedTourRegionFrame

struct GuidedTourRegionFrame: Equatable {
    let region: GuidedTourRegion
    let frame: CGRect
}

// MARK: - GuidedTourRegionPreferenceKey

struct GuidedTourRegionPreferenceKey: PreferenceKey {
    static var defaultValue: [GuidedTourRegionFrame] { [] }

    static func reduce(value: inout [GuidedTourRegionFrame], nextValue: () -> [GuidedTourRegionFrame]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - GuidedTourRegionModifier

private struct GuidedTourRegionModifier: ViewModifier {
    let region: GuidedTourRegion

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: GuidedTourRegionPreferenceKey.self,
                            value: [GuidedTourRegionFrame(region: region, frame: proxy.frame(in: .global))]
                        )
                }
            )
    }
}

// MARK: - View Extension

extension View {
    func guidedTourRegion(_ region: GuidedTourRegion) -> some View {
        modifier(GuidedTourRegionModifier(region: region))
    }
}
