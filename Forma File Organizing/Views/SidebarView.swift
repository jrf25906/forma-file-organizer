import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var nav: NavigationViewModel
    @Environment(\.openSettings) private var openSettings
    @Binding var isCollapsed: Bool
    @State private var showingRuleEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo Area
            HStack(spacing: DesignSystem.Spacing.standard) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusMedium)
                        .fill(DesignSystem.Colors.steelBlue)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                if !isCollapsed {
                    Text("Forma")
                        .font(DesignSystem.Typography.formaH2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .padding(.horizontal, isCollapsed ? 18 : DesignSystem.Spacing.generous)
            .padding(.vertical, DesignSystem.Spacing.generous)
            
            // Navigation
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                    // Locations
                    sectionHeader("LOCATIONS")
                    
                    sidebarItem("Home", icon: "house", selection: .home)
                    sidebarItem("Desktop", icon: "display", selection: .desktop)
                    sidebarItem("Downloads", icon: "arrow.down.circle", selection: .downloads)
                    
                    // Categories
                    sectionHeader("CATEGORIES")
                    
                    ForEach(FileTypeCategory.allCases, id: \.self) { category in
                        if category != .all { 
                            sidebarItem(category.displayName, icon: category.iconName, selection: .category(category))
                        }
                    }
                    
                    // Rules
                    sectionHeader("SMART RULES")
                    
                    Button(action: { showingRuleEditor = true }) {
                        HStack(spacing: DesignSystem.Spacing.standard) {
                            ZStack {
                                Circle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3]))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(width: 18, height: 18)
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .frame(width: 20)
                            
                            if !isCollapsed {
                                Text("Create Rule")
                                    .font(DesignSystem.Typography.formaBody)
                            }
                            Spacer()
                        }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, isCollapsed ? 8 : DesignSystem.Spacing.large)
            }
            
            Spacer()
            
            // Bottom Actions
            VStack(spacing: 4) {
                Divider()
                    .overlay(DesignSystem.Colors.border)
                    .padding(.bottom, DesignSystem.Spacing.large)
                
                Button(action: { openSettings() }) {
                    HStack(spacing: DesignSystem.Spacing.standard) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17))
                            .frame(width: 20)
                        
                        if !isCollapsed {
                            Text("Settings")
                                .font(DesignSystem.Typography.formaBody)
                        }
                        Spacer()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isCollapsed ? 8 : DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.large)
        }
        .background(DesignSystem.Colors.sidebarBackground)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignSystem.Colors.sidebarBorder),
            alignment: .trailing
        )
        .sheet(isPresented: $showingRuleEditor) {
            RuleEditorView()
                .presentationBackground(.ultraThinMaterial)
        }
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        if !isCollapsed {
            Text(title)
                .font(DesignSystem.Typography.formaCaption)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .tracking(1.0)
                .padding(.horizontal, 16)
                .padding(.top, DesignSystem.Spacing.large)
                .padding(.bottom, DesignSystem.Spacing.tight)
        }
    }
    
    @ViewBuilder
    private func sidebarItem(_ title: String, icon: String, selection: NavigationSelection) -> some View {
        Button(action: { nav.select(selection) }) {
            HStack(spacing: DesignSystem.Spacing.standard) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: 20, alignment: .center)
                
                if !isCollapsed {
                    Text(title)
                        .font(DesignSystem.Typography.formaBody)
                }
                Spacer()
            }
            .foregroundColor(nav.selection == selection ? DesignSystem.Colors.sidebarTextActive : DesignSystem.Colors.sidebarText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusMedium)
                    .fill(nav.selection == selection ? DesignSystem.Colors.sidebarBackgroundActive : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
