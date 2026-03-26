import AppKit

@MainActor
final class FormaApplicationDelegate: NSObject, NSApplicationDelegate {
    private let finderServicesProvider = FinderServicesProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification

        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        let providerName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Forma"
        NSApp.servicesProvider = finderServicesProvider
        NSRegisterServicesProvider(finderServicesProvider, providerName)
        FinderServicesRegistrationController.shared.refreshRegistrationIfNeeded()
    }
}
