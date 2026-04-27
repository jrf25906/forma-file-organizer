import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    var body: some View {
        TabView {
            SettingsTabShell {
                RulesManagerSection()
            }
                .tabItem {
                    Label("Rules", systemImage: "flowchart")
                }

            SettingsTabShell {
                CustomFoldersSection()
            }
                .tabItem {
                    Label("Folders", systemImage: "folder.badge.plus")
                }

            SettingsTabShell {
                SmartFeaturesSection()
            }
                .tabItem {
                    Label("Smart Features", systemImage: "brain")
                }

            SettingsTabShell {
                GeneralSettingsSection()
            }
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            SettingsTabShell {
                AboutSection()
            }
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 720, idealWidth: 760, maxWidth: 860, minHeight: 560, idealHeight: 600, maxHeight: 720)
        .background(Color.clear)
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
    }
}
