import Foundation

enum AutomationScanNotificationUserInfo {
    static let scannedPaths = "scannedPaths"
    static let errorSummary = "errorSummary"
}

extension Notification.Name {
    static let automationScanDidPersist = Notification.Name("automationScanDidPersist")
}
