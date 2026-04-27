import SwiftUI
import SwiftData

/// Quick rule creation sheet that pre-fills form based on a matched file's conditions.
/// This provides a streamlined flow for creating rules directly from the review workflow.
struct QuickRuleCreationSheet: View {
    let file: FileItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    
    @State private var ruleName: String = ""
    @State private var destinationDisplayPath: String = ""
    @State private var destinationBookmarkData: Data?
    @State private var isChoosingDestination = false
    @State private var validationError: String?
    private let destinationResolver = DestinationResolver()
    
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
                            .foregroundStyle(Color.formaSecondaryLabelHigh)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.formaH2)
                        .foregroundStyle(Color.formaSecondaryLabel)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.vertical, FormaSpacing.generous - FormaSpacing.micro)
            .background(Color.formaSurfaceAnchor)
            
            Divider()
            
            // Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: FormaSpacing.large) {
                    // File Preview
                    FileMatchPreview(file: file)
                    
                    // Rule Name
                    quickSectionCard(
                        step: "1",
                        title: "Rule",
                        subtitle: "Name the behavior Forma should remember.",
                        tint: .formaSteelBlue
                    ) {
                        FormaTextField(
                            title: "Rule Name",
                            placeholder: "e.g., Invoice Organizer",
                            text: $ruleName,
                            hasError: validationError != nil
                        )
                    }
                    
                    // Destination Folder
                    quickSectionCard(
                        step: "2",
                        title: "Destination",
                        subtitle: "Choose where future matches should move.",
                        tint: .formaSage
                    ) {
                        FormaFolderPicker(
                            title: "Destination Folder",
                            displayPath: destinationDisplayPath,
                            hasSelection: destinationBookmarkData != nil,
                            hasError: validationError != nil,
                            onSelect: requestDestinationAccess,
                            onClear: {
                                destinationBookmarkData = nil
                                destinationDisplayPath = ""
                            }
                        )
                    }
                    
                    // Conditions Preview (read-only)
                    if let reasoning = file.matchReason {
                        quickSectionCard(
                            step: "REVIEW",
                            title: "Conditions",
                            subtitle: "These conditions will be copied from the matched file.",
                            tint: .formaWarmOrange
                        ) {
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
            .background(Color.formaSurfaceChrome)
            
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
            .background(Color.formaSurfaceFloating)
        }
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 680, minHeight: 600, idealHeight: 640, maxHeight: 760)
        .background(Color.formaSurfaceChrome)
        .onAppear {
            prefillForm()
        }
    }
    
    // MARK: - Helper Views

    private func quickSectionCard<Content: View>(
        step: String,
        title: String,
        subtitle: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(alignment: .top, spacing: FormaSpacing.tight) {
                FormaBadge(text: step, color: tint, size: .small, style: .subtle)

                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text(title)
                        .font(.formaBodyBold)
                        .foregroundStyle(Color.formaLabel)
                    Text(subtitle)
                        .font(.formaSmall)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                }
            }

            content()
        }
        .padding(FormaSpacing.large)
        .background(Color.formaSurfaceWork)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.46 : 0.32), lineWidth: FormaBorderWidth.thin)
        )
        .shadow(color: Color.formaObsidian.opacity(colorScheme == .dark ? 0.16 : 0.05), radius: 3, x: 0, y: 1)
    }
    
    private struct FileMatchPreview: View {
        let file: FileItem
        @Environment(\.colorScheme) private var colorScheme
        
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
            .background(Color.formaSurfaceWork)
            .formaCornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(Color.formaSeparator.opacity(colorScheme == .dark ? 0.52 : 0.34), lineWidth: FormaBorderWidth.thin)
            )
        }
    }
    
    // MARK: - Logic

    private var isValid: Bool {
        !ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        destinationBookmarkData != nil
    }

    private func requestDestinationAccess() {
        guard !isChoosingDestination else { return }

        isChoosingDestination = true
        validationError = nil

        Task { @MainActor in
            defer { isChoosingDestination = false }

            do {
                let destination = try await destinationResolver.requestDestinationAccess(
                    forSuggestedPath: destinationDisplayPath
                )
                destinationBookmarkData = destination.bookmarkData
                destinationDisplayPath = destination.displayName
            } catch DestinationResolver.AccessGrantError.cancelled {
                return
            } catch {
                validationError = "Could not grant folder access: \(error.localizedDescription)"
            }
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
