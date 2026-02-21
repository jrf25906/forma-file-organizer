import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Quick rule creation sheet that pre-fills form based on a matched file's conditions.
/// This provides a streamlined flow for creating rules directly from the review workflow.
struct QuickRuleCreationSheet: View {
    let file: FileItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    
    @State private var ruleName: String = ""
    @State private var destinationDisplayPath: String = ""
    @State private var destinationBookmarkData: Data?
    @State private var showFolderPicker = false
    @State private var validationError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Rule from Match")
                        .font(.formaH3)
                        .foregroundStyle(Color.formaLabel)

                    if let reasoning = file.matchReason {
                        Text(reasoning)
                            .font(.formaBody)
                            .foregroundStyle(Color.formaSecondaryLabel)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.formaH2)
                        .foregroundStyle(Color.formaSecondaryLabel)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, FormaSpacing.generous - FormaSpacing.micro)
            .background(Color.formaCardBackground)
            
            Divider()
            
            // Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: FormaSpacing.large) {
                    // File Preview
                    FileMatchPreview(file: file)
                    
                    // Rule Name
                    FormaTextField(
                        title: "Rule Name",
                        placeholder: "e.g., Invoice Organizer",
                        text: $ruleName,
                        hasError: validationError != nil
                    )
                    
                    // Destination Folder
                    FormaFolderPicker(
                        title: "Destination Folder",
                        displayPath: destinationDisplayPath,
                        hasSelection: destinationBookmarkData != nil,
                        hasError: validationError != nil,
                        onSelect: { showFolderPicker = true },
                        onClear: {
                            destinationBookmarkData = nil
                            destinationDisplayPath = ""
                        }
                    )
                    
                    // Conditions Preview (read-only)
                    if let reasoning = file.matchReason {
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            Text("Conditions")
                                .font(.formaBodySemibold)
                                .foregroundStyle(Color.formaSecondaryLabel)
                            
                            Text("These conditions will be copied from the matched file:")
                                .font(.formaCompact)
                                .foregroundStyle(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.prominent))
                            
                            ReasoningView(reasoning: reasoning, isExpanded: true)
                        }
                    }
                    
                    // Validation Error
                    if let error = validationError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.formaWarmOrange)
                            Text(error)
                                .font(.formaCompact)
                                .foregroundStyle(Color.formaLabel)
                        }
                        .padding(FormaSpacing.standard - FormaSpacing.micro)
                        .background(Color.formaWarmOrange.opacity(Color.FormaOpacity.light))
                        .formaCornerRadius(FormaRadius.control)
                    }
                }
                .padding(FormaSpacing.generous)
            }
            .background(Color.formaBackground)
            
            Divider()
            
            // Footer Actions
            HStack(spacing: 12) {
                FormaSecondaryButton(title: "Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                FormaPrimaryButton(title: "Create Rule") {
                    createRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, FormaSpacing.standard)
            .background(Color.formaCardBackground)
        }
        .frame(width: 540, height: 640)
        .background(Color.formaBackground)
        .onAppear {
            prefillForm()
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                handleFolderSelection(url)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private struct FileMatchPreview: View {
        let file: FileItem
        
        var body: some View {
            HStack(spacing: 12) {
                // File icon
                let icon = NSWorkspace.shared.icon(forFile: file.path)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.formaBodySemibold)
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(file.fileExtension.uppercased())
                            .font(.formaSmallMedium)
                            .foregroundStyle(file.category.color)
                        
                        Text("•")
                            .foregroundStyle(Color.formaTertiaryLabel)
                        
                        Text(file.size)
                            .font(.formaSmall)
                            .foregroundStyle(Color.formaSecondaryLabel)
                    }
                }
                
                Spacer()
            }
            .padding(FormaSpacing.standard - FormaSpacing.micro)
            .background(Color.formaCardBackground)
            .formaCornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Logic

    private var isValid: Bool {
        !ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        destinationBookmarkData != nil
    }

    private func handleFolderSelection(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            validationError = "Could not access the selected folder"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            destinationBookmarkData = bookmarkData
            destinationDisplayPath = url.lastPathComponent
        } catch {
            validationError = "Could not save folder access: \(error.localizedDescription)"
        }
    }

    private func prefillForm() {
        // Generate suggested rule name from file
        let ext = file.fileExtension.uppercased()
        if let reasoning = file.matchReason, reasoning.lowercased().contains("invoice") {
            ruleName = "Invoice Organizer"
        } else if let reasoning = file.matchReason, reasoning.lowercased().contains("screenshot") {
            ruleName = "Screenshot Manager"
        } else if !file.fileExtension.isEmpty {
            ruleName = "\(ext) File Organizer"
        } else {
            ruleName = "New Rule"
        }

        // Pre-fill destination from file's existing destination
        if let destination = file.destination {
            destinationDisplayPath = destination.displayName
            destinationBookmarkData = destination.bookmarkData
        }
    }

    private func createRule() {
        validationError = nil

        // Validate inputs
        guard !ruleName.isEmpty else {
            validationError = "Please enter a rule name"
            return
        }

        guard let bookmarkData = destinationBookmarkData else {
            validationError = "Please select a destination folder"
            return
        }

        // Build unified Destination
        let destination = Destination.folder(bookmark: bookmarkData, displayName: destinationDisplayPath)

        // For now, create a simple extension-based rule
        // In a full implementation, this would parse the matchReason to recreate conditions
        let rule = Rule(
            name: ruleName.trimmingCharacters(in: .whitespacesAndNewlines),
            conditionType: .fileExtension,
            conditionValue: file.fileExtension,
            actionType: .move,
            destination: destination,
            isEnabled: true
        )

        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.createRule(rule, source: .quickSheet)
            dismiss()
        } catch {
            validationError = "Failed to create rule: \(error.localizedDescription)"
        }
    }
}



#Preview {
    QuickRuleCreationSheet(file: FileItem.mocks[0])
        .environmentObject(DashboardViewModel())
}
