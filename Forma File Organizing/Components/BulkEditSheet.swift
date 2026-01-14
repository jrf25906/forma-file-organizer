import SwiftUI

struct BulkEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let selectedFiles: [FileItem]
    let onSave: (String, Bool) -> Void
    
    @State private var selectedDestination: String = ""
    @State private var createRules: Bool = false
    @State private var showingFolderPicker: Bool = false
    
    private var uniqueDestinations: [String] {
        Array(Set(selectedFiles.compactMap { $0.destination?.displayName })).sorted()
    }
    
    private var fileTypeGroups: [(String, Int)] {
        let groups = Dictionary(grouping: selectedFiles, by: { $0.fileExtension })
        return groups.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        VStack(spacing: FormaSpacing.generous) {
            // Header
            VStack(spacing: FormaSpacing.tight) {
                Text("Edit Destination for \(selectedFiles.count) \(selectedFiles.count == 1 ? "File" : "Files")")
                    .font(.formaH1)
                    .foregroundColor(.formaObsidian)
                
                Text("Choose a destination for the selected files")
                    .font(.formaBody)
                    .foregroundColor(.formaObsidian.opacity(Color.FormaOpacity.high))
            }
            .padding(.top, FormaSpacing.large)
            
            Divider()
            
            // Current suggestions
            if !uniqueDestinations.isEmpty {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text("Current Suggestions:")
                        .font(.formaBody.weight(.semibold))
                        .foregroundColor(.formaObsidian.opacity(Color.FormaOpacity.prominent))
                    
                    ForEach(uniqueDestinations.prefix(3), id: \.self) { destination in
                        HStack(spacing: FormaSpacing.tight) {
                            Image(systemName: "arrow.right")
                                .font(.formaCaption)
                                .foregroundColor(.formaObsidian.opacity(Color.FormaOpacity.strong - Color.FormaOpacity.light))
                            Text(destination)
                                .font(.formaSmall)
                                .foregroundColor(.formaObsidian.opacity(Color.FormaOpacity.high))
                        }
                    }
                    
                    if uniqueDestinations.count > 3 {
                        Text("+ \(uniqueDestinations.count - 3) more")
                            .font(.formaSmall)
                            .foregroundColor(.formaObsidian.opacity(Color.FormaOpacity.strong))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FormaSpacing.standard)
                .background(Color.formaObsidian.opacity(Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle))
                .formaCornerRadius(FormaRadius.control)
            }
            
            // Destination picker
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("Override with:")
                    .font(.formaBody.weight(.semibold))
                    .foregroundColor(.formaObsidian)
                
                Picker("Destination", selection: $selectedDestination) {
                    Text("Select...").tag("")
                    Divider()
                    Text("Documents").tag("~/Documents")
                    Text("Downloads").tag("~/Downloads")
                    Text("Desktop").tag("~/Desktop")
                    Text("Pictures").tag("~/Pictures")
                    Text("Music").tag("~/Music")
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                
                Button(action: { showingFolderPicker = true }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Browse...")
                    }
                    .font(.formaBody)
                    .foregroundColor(.formaSteelBlue)
                }
                .buttonStyle(.plain)
            }
            
            // Create rules checkbox
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Toggle(isOn: $createRules) {
                    VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                        Text("Apply this rule to future files")
                            .font(.formaBody.weight(.medium))
                            .foregroundColor(.formaObsidian)
                        
                        if createRules && !fileTypeGroups.isEmpty {
                            Text("Will create rules for: \(fileTypeGroups.map { ".\($0.0)" }.joined(separator: ", "))")
                                .font(.formaSmall)
                                .foregroundColor(.formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }
            .padding(FormaSpacing.standard)
            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle))
            .formaCornerRadius(FormaRadius.control)
            
            Spacer()
            
            // Actions
            HStack(spacing: FormaSpacing.standard) {
                SecondaryButton("Cancel") {
                    dismiss()
                }
                
                PrimaryButton("Move All (\(selectedFiles.count))", icon: "folder") {
                    onSave(selectedDestination, createRules)
                    dismiss()
                }
                .disabled(selectedDestination.isEmpty)
            }
            .padding(.bottom, FormaSpacing.large)
        }
        .padding(.horizontal, FormaSpacing.generous)
        .frame(width: 500, height: 550)
        .background(Color.formaBoneWhite)
    }
}

#Preview {
    BulkEditSheet(
        selectedFiles: FileItem.mocks.prefix(3).map { $0 },
        onSave: { _, _ in }
    )
}
