import Foundation

enum AutomationScanNotificationUserInfo {
    static let scannedPaths = "scannedPaths"
    static let updatedPaths = "updatedPaths"
    static let removedPaths = "removedPaths"
    static let scannedRootPaths = "scannedRootPaths"
    static let replacesAllFiles = "replacesAllFiles"
    static let requiresClusterRefresh = "requiresClusterRefresh"
    static let errorSummary = "errorSummary"
}

extension Notification.Name {
    static let automationScanDidPersist = Notification.Name("automationScanDidPersist")
}
