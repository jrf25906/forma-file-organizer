import SwiftUI
import SwiftData

struct MainContentView: View {
    @Binding var isSidebarCollapsed: Bool
    @EnvironmentObject var nav: NavigationViewModel
    
    @Query private var files: [FileItem]
    
    init(isSidebarCollapsed: Binding<Bool>, selection: NavigationSelection, searchText: String, activeChips: Set<FileFilterChip>) {
        _isSidebarCollapsed = isSidebarCollapsed
        
        let predicate = MainContentView.makePredicate(selection: selection, searchText: searchText, activeChips: activeChips)
        _files = Query(filter: predicate, sort: [SortDescriptor(\FileItem.creationDate, order: .reverse)])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DesignSystem.Spacing.large) {
                // Toggle Sidebar
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isSidebarCollapsed.toggle() } }) {
                    Image(systemName: isSidebarCollapsed ? "chevron.right" : "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(DesignSystem.Colors.panelBackground)
                        .cornerRadius(DesignSystem.Layout.cornerRadiusLarge)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusLarge)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    TextField("Search files...", text: Binding(get: { nav.searchText }, set: { nav.searchText = $0 }))
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.formaBody)
                }
                .padding(.horizontal, DesignSystem.Spacing.large)
                .frame(height: 44)
                .background(DesignSystem.Colors.background)
                .cornerRadius(DesignSystem.Layout.cornerRadiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusLarge)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
                
                Spacer()
                
                // Scan Files Button (Functional)
                // Note: In a real app, you'd use the DashboardViewModel to trigger scan.
                // Since we don't have the VM injected here directly (it's in DashboardView?), 
                // we might need to pass the action or use environment.
                // For now, I'll placeholder it.
                Button(action: { 
                    // Scan logic to be wired
                }) {
                    HStack {
                        Image(systemName: "clock")
                        Text("Scan Files")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .frame(height: 72)
            .background(DesignSystem.Colors.panelBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.Colors.border),
                alignment: .bottom
            )
            
            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.tight) {
                    FilterChip(label: "Recent", chip: .recent, activeChips: Binding(get: { nav.activeChips }, set: { nav.activeChips = $0 }))
                    FilterChip(label: "Large Files", chip: .largeFiles, activeChips: Binding(get: { nav.activeChips }, set: { nav.activeChips = $0 }))
                    FilterChip(label: "Flagged", chip: .flagged, activeChips: Binding(get: { nav.activeChips }, set: { nav.activeChips = $0 }))
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.standard)
            }
            .background(DesignSystem.Colors.panelBackground)
            
            // Content
            if files.isEmpty {
                VStack(spacing: DesignSystem.Spacing.standard) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                    Text("No files found")
                        .font(DesignSystem.Typography.formaH3)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.background)
            } else {
                List(files) { file in
                    FileRow(file: file)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .background(DesignSystem.Colors.background)
            }
        }
    }
    
    static func makePredicate(selection: NavigationSelection, searchText: String, activeChips: Set<FileFilterChip>) -> Predicate<FileItem> {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasSearch = !search.isEmpty
        
        let hasRecent = activeChips.contains(.recent)
        let recentDate = Date().addingTimeInterval(-86400 * 7) // 7 days
        
        let hasLarge = activeChips.contains(.largeFiles)
        let largeSize: Int64 = 50 * 1024 * 1024 // 50 MB
        
        switch selection {
        case .home:
            return #Predicate<FileItem> { file in
                (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .desktop:
            return #Predicate<FileItem> { file in
                file.path.contains("/Desktop/")
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .downloads:
            return #Predicate<FileItem> { file in
                file.path.contains("/Downloads/")
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .category(let cat):
            let exts = cat.extensions
            return #Predicate<FileItem> { file in
                exts.contains(file.fileExtension)
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        }
    }
}

struct FilterChip: View {
    let label: String
    let chip: FileFilterChip
    @Binding var activeChips: Set<FileFilterChip>
    
    var isActive: Bool { activeChips.contains(chip) }
    
    var body: some View {
        Text(label)
            .font(DesignSystem.Typography.formaCaption)
            .padding(.horizontal, DesignSystem.Spacing.standard)
            .padding(.vertical, DesignSystem.Spacing.tight)
            .background(
                Capsule()
                    .fill(isActive ? DesignSystem.Colors.steelBlue.opacity(0.15) : DesignSystem.Colors.background)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? DesignSystem.Colors.steelBlue : DesignSystem.Colors.border, lineWidth: 1)
            )
            .foregroundStyle(isActive ? DesignSystem.Colors.steelBlue : DesignSystem.Colors.textSecondary)
            .onTapGesture {
                if isActive {
                    activeChips.remove(chip)
                } else {
                    activeChips.insert(chip)
                }
            }
    }
}
