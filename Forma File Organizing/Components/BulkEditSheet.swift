import SwiftUI

struct BulkEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
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
                    .foregroundColor(.formaLabel)
                
                Text("Choose a destination for the selected files")
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }
            .padding(.top, FormaSpacing.large)
            
            Divider()
            
            // Current suggestions
            if !uniqueDestinations.isEmpty {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text("Current Suggestions:")
                        .font(.formaBody.weight(.semibold))
                        .foregroundColor(.formaLabel)
                    
                    ForEach(uniqueDestinations.prefix(3), id: \.self) { destination in
                        HStack(spacing: FormaSpacing.tight) {
                            Image(systemName: "arrow.right")
                                .font(.formaCaption)
                                .foregroundColor(.formaSecondaryLabelHigh)
                            Text(destination)
                                .font(.formaSmall)
                                .foregroundColor(.formaSecondaryLabelHigh)
                        }
                    }
                    
                    if uniqueDestinations.count > 3 {
                        Text("+ \(uniqueDestinations.count - 3) more")
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FormaSpacing.standard)
                .background(colorScheme == .dark ? Color.formaControlBackground.opacity(0.38) : Color.formaBoneWhite.opacity(0.68))
                .formaCornerRadius(FormaRadius.control)
            }
            
            // Destination picker
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("Override with:")
                    .font(.formaBody.weight(.semibold))
                    .foregroundColor(.formaLabel)
                
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
                    .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
            }
            
            // Create rules checkbox
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Toggle(isOn: $createRules) {
                    VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                        Text("Apply this rule to future files")
                            .font(.formaBody.weight(.medium))
                            .foregroundColor(.formaLabel)
                        
                        if createRules && !fileTypeGroups.isEmpty {
                            Text("Will create rules for: \(fileTypeGroups.map { ".\($0.0)" }.joined(separator: ", "))")
                                .font(.formaSmall)
                                .foregroundColor(.formaSecondaryLabelHigh)
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
        .frame(minWidth: 500, idealWidth: 540, maxWidth: 620, minHeight: 520, idealHeight: 550, maxHeight: 680)
        .background(Color.formaBackground)
    }
}

#Preview {
    BulkEditSheet(
        selectedFiles: FileItem.mocks.prefix(3).map { $0 },
        onSave: { _, _ in }
    )
}
