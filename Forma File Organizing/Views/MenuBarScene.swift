import SwiftUI
import SwiftData

struct MenuBarScene: Scene {
    let container: ModelContainer
    let isTesting: Bool

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarLabelView()
        }
        .menuBarExtraStyle(.window) // Use .window for custom SwiftUI content
    }

    private struct MenuBarLabelView: View {
        @Environment(\.openWindow) private var openWindow
        @State private var didAutoOpenMainWindow = false

        var body: some View {
            Label("Forma", image: "MenuBarIcon")
                .task {
                    guard !didAutoOpenMainWindow else { return }
                    let arguments = ProcessInfo.processInfo.arguments
                    guard arguments.contains("--uitesting") ||
                            arguments.contains("--perf-signpost-harness") else {
                        return
                    }
                    didAutoOpenMainWindow = true
                    openWindow(id: "main")
                }
        }
    }
}
