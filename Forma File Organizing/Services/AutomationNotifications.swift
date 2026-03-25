import Foundation

enum AutomationScanNotificationUserInfo {
    static let scannedPaths = "scannedPaths"
    static let scannedRootPaths = "scannedRootPaths"
    static let replacesAllFiles = "replacesAllFiles"
    static let errorSummary = "errorSummary"
}

extension Notification.Name {
    static let automationScanDidPersist = Notification.Name("automationScanDidPersist")
}
