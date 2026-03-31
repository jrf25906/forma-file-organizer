import SwiftUI

/// Shared semantic styling for file surfaces before view-specific metrics are applied.
struct FileSurfaceStyle: Equatable {
    enum State: String, CaseIterable {
        case rest
        case hover
        case selected
        case focused
        case pending
        case processing
        case error
    }

    enum SurfaceKind: String, Equatable {
        case listRow
        case card
    }

    enum Activity: String, Equatable {
        case none
        case pending
        case processing
        case error
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
        var activity: Activity = .none
    }

    let state: State
    let fillToken: FillToken
    let overlayToken: OverlayToken?
    let borderToken: BorderToken

    var fillColor: Color {
        switch fillToken {
        case .listRowBackground:
            return .formaListRowBackground
        case .cardBackground:
            return .formaCardBackground
        }
    }

    var overlayColor: Color? {
        switch overlayToken {
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
        case nil:
            return nil
        }
    }

    var borderColor: Color {
        switch borderToken {
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

    static func resolve(_ context: Context) -> FileSurfaceStyle {
        let state = resolveState(for: context)

        return FileSurfaceStyle(
            state: state,
            fillToken: fillToken(for: context.kind),
            overlayToken: overlayToken(for: state),
            borderToken: borderToken(for: state)
        )
    }

    private static func resolveState(for context: Context) -> State {
        switch context.activity {
        case .error:
            return .error
        case .processing:
            return .processing
        case .pending:
            return .pending
        case .none:
            break
        }

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

    private static func overlayToken(for state: State) -> OverlayToken? {
        switch state {
        case .rest:
            return nil
        case .hover:
            return .hover
        case .selected, .focused:
            return .selected
        case .pending:
            return .pending
        case .processing:
            return .processing
        case .error:
            return .error
        }
    }

    private static func borderToken(for state: State) -> BorderToken {
        switch state {
        case .rest:
            return .rest
        case .hover:
            return .hover
        case .selected:
            return .selected
        case .focused:
            return .focused
        case .pending:
            return .pending
        case .processing:
            return .processing
        case .error:
            return .error
        }
    }
}
