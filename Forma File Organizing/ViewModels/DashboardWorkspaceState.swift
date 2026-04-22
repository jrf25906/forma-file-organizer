import CoreGraphics
import Foundation

enum DashboardWorkspaceDestination: Equatable {
    case home
    case analytics
    case rules
}

struct DashboardHomeWorkspaceSnapshot: Equatable {
    let isRightPanelVisible: Bool
    let rightPanelWidth: CGFloat
    let rightPanelMode: PanelStateManager.RightPanelMode
}
