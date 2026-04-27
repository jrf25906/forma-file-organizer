import SwiftUI

/// Shared semantic styling for file surfaces before view-specific metrics are applied.
struct FileSurfaceStyle: Equatable {
    enum InteractionState: String, CaseIterable {
        case rest
        case hover
        case selected
        case focused
    }

    enum ActivityState: String, CaseIterable {
        case none
        case pending
        case processing
        case error
    }

    enum SurfaceKind: String, Equatable {
        case listRow
        case card
    }

    enum FillToken: String, Equatable {
        case listRowBackground
        case cardBackground
    }

    enum OverlayToken: String, Equatable {
        case hover
        case selected
        case pending
        case processing
        case error
    }

    enum BorderToken: String, Equatable {
        case rest
        case hover
        case selected
        case focused
        case pending
        case processing
        case error
    }

    struct Context: Equatable {
        let kind: SurfaceKind
        var isHovered: Bool = false
        var isSelected: Bool = false
        var isFocused: Bool = false
        var activity: ActivityState = .none
    }

    let interactionState: InteractionState
    let activityState: ActivityState
    let fillToken: FillToken
    let overlayTokens: [OverlayToken]
    let primaryBorderToken: BorderToken
    let accentBorderToken: BorderToken?

    var fillColor: Color {
        switch fillToken {
        case .listRowBackground:
            return .formaListRowBackground
        case .cardBackground:
            return .formaSurfaceWork
        }
    }

    var overlayColors: [Color] {
        overlayTokens.map { token in
            switch token {
            case .hover:
                return .formaFileSurfaceHoverOverlay
            case .selected:
                return .formaFileSurfaceSelectionOverlay
            case .pending:
                return .formaFileSurfacePendingOverlay
            case .processing:
                return .formaFileSurfaceProcessingOverlay
            case .error:
                return .formaFileSurfaceErrorOverlay
            }
        }
    }

    var primaryBorderColor: Color {
        borderColor(for: primaryBorderToken)
    }

    var accentBorderColor: Color? {
        guard let accentBorderToken else { return nil }
        return borderColor(for: accentBorderToken)
    }

    static func resolve(_ context: Context) -> FileSurfaceStyle {
        let interactionState = resolveInteractionState(for: context)
        let activityState = context.activity

        return FileSurfaceStyle(
            interactionState: interactionState,
            activityState: activityState,
            fillToken: fillToken(for: context.kind),
            overlayTokens: overlayTokens(
                interactionState: interactionState,
                activityState: activityState
            ),
            primaryBorderToken: primaryBorderToken(
                interactionState: interactionState,
                activityState: activityState
            ),
            accentBorderToken: accentBorderToken(
                interactionState: interactionState,
                activityState: activityState
            )
        )
    }

    private static func resolveInteractionState(for context: Context) -> InteractionState {
        if context.isFocused {
            return .focused
        }
        if context.isSelected {
            return .selected
        }
        if context.isHovered {
            return .hover
        }
        return .rest
    }

    private static func fillToken(for kind: SurfaceKind) -> FillToken {
        switch kind {
        case .listRow:
            return .listRowBackground
        case .card:
            return .cardBackground
        }
    }

    private static func overlayTokens(
        interactionState: InteractionState,
        activityState: ActivityState
    ) -> [OverlayToken] {
        var tokens: [OverlayToken] = []

        if let interactionOverlay = interactionOverlayToken(for: interactionState) {
            tokens.append(interactionOverlay)
        }

        if let activityOverlay = activityOverlayToken(for: activityState) {
            tokens.append(activityOverlay)
        }

        return tokens
    }

    private static func primaryBorderToken(
        interactionState: InteractionState,
        activityState: ActivityState
    ) -> BorderToken {
        if interactionState != .rest {
            return borderToken(for: interactionState)
        }
        return borderToken(for: activityState)
    }

    private static func accentBorderToken(
        interactionState: InteractionState,
        activityState: ActivityState
    ) -> BorderToken? {
        guard interactionState != .rest, activityState != .none else {
            return nil
        }
        return borderToken(for: activityState)
    }

    private static func interactionOverlayToken(for state: InteractionState) -> OverlayToken? {
        switch state {
        case .rest:
            return nil
        case .hover:
            return .hover
        case .selected, .focused:
            return .selected
        }
    }

    private static func activityOverlayToken(for state: ActivityState) -> OverlayToken? {
        switch state {
        case .none:
            return nil
        case .pending:
            return .pending
        case .processing:
            return .processing
        case .error:
            return .error
        }
    }

    private static func borderToken(for state: InteractionState) -> BorderToken {
        switch state {
        case .rest:
            return .rest
        case .hover:
            return .hover
        case .selected:
            return .selected
        case .focused:
            return .focused
        }
    }

    private static func borderToken(for state: ActivityState) -> BorderToken {
        switch state {
        case .none:
            return .rest
        case .pending:
            return .pending
        case .processing:
            return .processing
        case .error:
            return .error
        }
    }

    private func borderColor(for token: BorderToken) -> Color {
        switch token {
        case .rest:
            return .formaFileSurfaceBorder
        case .hover:
            return .formaFileSurfaceHoverBorder
        case .selected:
            return .formaFileSurfaceSelectedBorder
        case .focused:
            return .formaFileSurfaceFocusedBorder
        case .pending:
            return .formaFileSurfacePendingBorder
        case .processing:
            return .formaFileSurfaceProcessingBorder
        case .error:
            return .formaFileSurfaceErrorBorder
        }
    }
}
