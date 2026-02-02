import SwiftUI
import SwiftData

struct MenuBarScene: Scene {
    let container: ModelContainer
    let isTesting: Bool

    var body: some Scene {
        MenuBarExtra("Forma", image: "MenuBarIcon") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window) // Use .window for custom SwiftUI content
    }
}
