import SwiftUI
import SwiftData

struct FullListView: View {
    var selection: NavigationSelection
    @Query private var files: [FileItem]

    init(category: FileTypeCategory?) {
        if let cat = category {
            self.selection = .category(cat)
        } else {
            self.selection = .home // Default to home/all for nil category
        }
        
        let sel = self.selection
        _files = Query(
            filter: MainContentView.makePredicate(selection: sel, searchText: "", activeChips: []),
            sort: [SortDescriptor(\FileItem.creationDate, order: .reverse)]
        )
    }

    var body: some View {
        List(files) { file in
            FileRow(file: file)
        }
        .listStyle(.inset)
        .navigationTitle(title)
    }
    
    private var title: String {
        if case .category(let cat) = selection {
            return cat.displayName
        }
        return "All Files"
    }
}
