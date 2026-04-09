//
//  FormaFocusRing.swift
//  Forma - Keyboard Focus Ring
//
//  Consistent focus indicators for keyboard navigation accessibility.
//

import SwiftUI

enum FormaFocusRing {
    /// Focus ring color — steel blue at medium opacity
    static let color: Color = .formaSteelBlue.opacity(Color.FormaOpacity.medium)
    /// Focus ring width
    static let width: CGFloat = 2.0
    /// Focus ring offset from content edge
    static let offset: CGFloat = 2.0
    /// Focus ring corner radius padding (added to content radius)
    static let radiusPadding: CGFloat = 2.0
}

extension View {
    /// Apply Forma's standard keyboard focus ring.
    func formaFocusRing(
        isFocused: Bool,
        cornerRadius: CGFloat = FormaRadius.control
    ) -> some View {
        self.overlay(
            RoundedRectangle(
                cornerRadius: cornerRadius + FormaFocusRing.radiusPadding,
                style: .continuous
            )
            .stroke(FormaFocusRing.color, lineWidth: FormaFocusRing.width)
            .padding(-FormaFocusRing.offset)
            .opacity(isFocused ? 1 : 0)
        )
    }
}
