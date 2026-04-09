//
//  FormaZIndex.swift
//  Forma - Z-Index Layering
//
//  Explicit stacking order for overlapping UI elements.
//

import SwiftUI

enum FormaZIndex {
    /// Base content layer
    static let content: Double = 0
    /// Sticky headers, pinned elements
    static let sticky: Double = 10
    /// Floating action bars
    static let floating: Double = 20
    /// Dropdown menus, popovers
    static let dropdown: Double = 30
    /// Modal overlays
    static let modal: Double = 40
    /// Toast notifications
    static let toast: Double = 50
}
