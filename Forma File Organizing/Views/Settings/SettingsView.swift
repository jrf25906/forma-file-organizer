import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            RulesManagerSection()
                .tabItem {
                    Label("Rules", systemImage: "flowchart")
                }

            CustomFoldersSection()
                .tabItem {
                    Label("Folders", systemImage: "folder.badge.plus")
                }

            SmartFeaturesSection()
                .tabItem {
                    Label("Smart Features", systemImage: "brain")
                }

            GeneralSettingsSection()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AboutSection()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 700, height: 550)
        .background(Color.formaBoneWhite)
    }
}
