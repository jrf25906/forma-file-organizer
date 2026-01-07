import SwiftUI

// MARK: - FolderTemplateSelection Data Model

/// Tracks per-folder template choices during onboarding.
/// Each folder can have a different organization template assigned.
struct FolderTemplateSelection: Codable, Equatable {
    var desktop: OrganizationTemplate?
    var downloads: OrganizationTemplate?
    var documents: OrganizationTemplate?
    var pictures: OrganizationTemplate?
    var music: OrganizationTemplate?

    /// Returns template for a given folder, using personality-suggested default
    func template(
        for folder: OnboardingFolder,
        personality: OrganizationPersonality?
    ) -> OrganizationTemplate {
        let explicit: OrganizationTemplate? = switch folder {
        case .desktop: desktop
        case .downloads: downloads
        case .documents: documents
        case .pictures: pictures
        case .music: music
        }
        return explicit ?? personality?.suggestedTemplate ?? .minimal
    }

    /// Sets template for a specific folder
    mutating func setTemplate(_ template: OrganizationTemplate, for folder: OnboardingFolder) {
        switch folder {
        case .desktop: desktop = template
        case .downloads: downloads = template
        case .documents: documents = template
        case .pictures: pictures = template
        case .music: music = template
        }
    }

    /// Storage key for persisting selections
    static let storageKey = "onboardingFolderTemplateSelection"

    func save() {
        do {
            let encoded = try JSONEncoder().encode(self)
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        } catch {
            Log.warning("FolderTemplateSelection: Failed to encode template selection - \(error.localizedDescription)", category: .general)
        }
    }

    static func load() -> FolderTemplateSelection {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return FolderTemplateSelection()
        }

        do {
            let selection = try JSONDecoder().decode(FolderTemplateSelection.self, from: data)
            return selection
        } catch {
            Log.warning("FolderTemplateSelection: Failed to decode template selection - \(error.localizedDescription)", category: .general)
            return FolderTemplateSelection()
        }
    }

    /// Applies default template to all folders that don't have one set
    mutating func applyDefaults(personality: OrganizationPersonality?, selectedFolders: OnboardingFolderSelection) {
        let defaultTemplate = personality?.suggestedTemplate ?? .minimal

        if selectedFolders.desktop && desktop == nil { desktop = defaultTemplate }
        if selectedFolders.downloads && downloads == nil { downloads = defaultTemplate }
        if selectedFolders.documents && documents == nil { documents = defaultTemplate }
        if selectedFolders.pictures && pictures == nil { pictures = defaultTemplate }
        if selectedFolders.music && music == nil { music = defaultTemplate }
    }
}

// MARK: - Template Dropdown

/// Dropdown component for selecting an organization template
struct TemplateDropdown: View {
    @Binding var selection: OrganizationTemplate
    let recommendedTemplate: OrganizationTemplate?

    @State private var isExpanded = false
    @State private var isHovered = false

    private let availableTemplates = OrganizationTemplate.allCases.filter { $0 != .custom }

    var body: some View {
        Menu {
            ForEach(availableTemplates, id: \.self) { template in
                Button(action: { selection = template }) {
                    HStack {
                        Image(systemName: template.iconName)
                        Text(template.displayName)

                        if template == recommendedTemplate {
                            Spacer()
                            Text("Recommended")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if selection == template {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: selection.iconName)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaSteelBlue)

                Text(selection.displayName)
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaLabel)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(
                        isHovered
                            ? Color.formaControlBackground
                            : Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .stroke(Color.formaSeparator, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Folder Structure Preview

/// Displays a visual tree of the folder structure for a template
struct FolderStructurePreview: View {
    let rootFolderName: String
    let template: OrganizationTemplate
    let showAnnotations: Bool
    let accentColor: Color

    init(
        rootFolderName: String,
        template: OrganizationTemplate,
        showAnnotations: Bool = false,
        accentColor: Color = .formaSteelBlue
    ) {
        self.rootFolderName = rootFolderName
        self.template = template
        self.showAnnotations = showAnnotations
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Root folder
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "folder.fill")
                    .font(.formaBodySemibold)
                    .foregroundColor(accentColor)

                Text(rootFolderName)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)

                Text("(\(template.displayName))")
                    .font(.formaCompact)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .padding(.bottom, FormaSpacing.tight)

            // Folder structure
            VStack(alignment: .leading, spacing: 2) {
                let folders = template.folderStructure
                ForEach(Array(folders.enumerated()), id: \.offset) { index, folder in
                    let isLast = index == folders.count - 1
                    FolderTreeRow(
                        folderName: folder,
                        isLast: isLast,
                        annotation: showAnnotations ? annotation(for: folder, template: template) : nil,
                        accentColor: accentColor.opacity(Color.FormaOpacity.high)
                    )
                }
            }
            .padding(.leading, FormaSpacing.standard)
        }
    }

    private func annotation(for folder: String, template: OrganizationTemplate) -> String? {
        switch template {
        case .minimal:
            switch folder {
            case "Inbox": return "New files land here"
            case "Keep": return "Important stuff"
            case "Archive": return "Older than 90 days"
            default: return nil
            }
        case .para:
            switch folder {
            case "Projects": return "Active work"
            case "Areas": return "Ongoing responsibilities"
            case "Resources": return "Reference materials"
            case "Archive": return "Completed"
            default: return nil
            }
        case .chronological:
            if folder.contains(String(Calendar.current.component(.year, from: Date()))) {
                return "This year's files"
            } else if folder == "Archive" {
                return "Older files"
            }
            return nil
        default:
            return nil
        }
    }
}

/// Single row in the folder tree display
struct FolderTreeRow: View {
    let folderName: String
    let isLast: Bool
    let annotation: String?
    let accentColor: Color

    var body: some View {
        HStack(spacing: FormaSpacing.tight) {
            // Tree connector
            HStack(spacing: 0) {
                Text(isLast ? "└── " : "├── ")
                    .font(.formaMonoSmall)
                    .foregroundColor(.formaSecondaryLabel.opacity(Color.FormaOpacity.strong))
            }

            Image(systemName: "folder.fill")
                .font(.formaSmall)
                .foregroundColor(accentColor)

            Text(folderName)
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)

            if let annotation = annotation {
                Text("← \(annotation)")
                    .font(.formaSmall)
                    .foregroundColor(.formaTertiaryLabel)
                    .italic()
            }
        }
    }
}

// MARK: - Folder Template Card

/// Expandable card for assigning a template to a specific folder
struct FolderTemplateCard: View {
    let folder: OnboardingFolder
    @Binding var selectedTemplate: OrganizationTemplate
    let personality: OrganizationPersonality?

    @State private var isExpanded = false
    @State private var isHovered = false

    private var recommendedTemplate: OrganizationTemplate {
        personality?.suggestedTemplate ?? .minimal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - always visible
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                HStack(spacing: FormaSpacing.standard) {
                    // Folder icon with color indicator
                    ZStack {
                        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                            .fill(folder.color.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle))
                            .frame(width: FormaSpacing.large + FormaSpacing.tight, height: FormaSpacing.large + FormaSpacing.tight)

                        Image(systemName: "folder.fill")
                            .font(.formaH3)
                            .foregroundColor(folder.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.title)
                            .font(.formaBodyLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(.formaLabel)

                        Text(selectedTemplate.description)
                            .font(.formaCompact)
                            .foregroundColor(.formaSecondaryLabel)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Template selector
                    TemplateDropdown(
                        selection: $selectedTemplate,
                        recommendedTemplate: recommendedTemplate
                    )
                    .frame(width: 180)

                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.formaCompactSemibold)
                        .foregroundColor(.formaSecondaryLabel)
                        .frame(width: 24)
                }
                .padding(FormaSpacing.standard)
            }
            .buttonStyle(.plain)

            // Expanded content - folder structure preview
            if isExpanded {
                Divider()
                    .padding(.horizontal, FormaSpacing.standard)

                FolderStructurePreview(
                    rootFolderName: folder.title,
                    template: selectedTemplate,
                    showAnnotations: true,
                    accentColor: folder.color
                )
                .padding(FormaSpacing.standard)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(
                    isHovered
                        ? Color.formaControlBackground
                        : Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(
                    Color.formaSeparator.opacity(
                        isHovered
                            ? Color.FormaOpacity.prominent
                            : Color.FormaOpacity.overlay + Color.FormaOpacity.light
                    ),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview Helpers

#Preview("Template Dropdown") {
    VStack(spacing: 20) {
        TemplateDropdown(
            selection: .constant(.minimal),
            recommendedTemplate: .minimal
        )
        .frame(width: 200)

        TemplateDropdown(
            selection: .constant(.para),
            recommendedTemplate: .minimal
        )
        .frame(width: 200)
    }
    .padding()
    .background(Color.formaBackground)
}

#Preview("Folder Structure Preview") {
    VStack(alignment: .leading, spacing: 20) {
        FolderStructurePreview(
            rootFolderName: "Pictures",
            template: .chronological,
            showAnnotations: true,
            accentColor: .formaWarmOrange
        )

        FolderStructurePreview(
            rootFolderName: "Desktop",
            template: .minimal,
            showAnnotations: true,
            accentColor: .formaSteelBlue
        )

        FolderStructurePreview(
            rootFolderName: "Downloads",
            template: .para,
            showAnnotations: true,
            accentColor: .formaSage
        )
    }
    .padding()
    .background(Color.formaBackground)
}

// MARK: - Folder Template Step View (Step 4 in new flow)

/// Step view for assigning templates to each selected folder
struct FolderTemplateStepView: View {
    @Binding var folderSelection: OnboardingFolderSelection
    @Binding var templateSelection: FolderTemplateSelection
    let personality: OrganizationPersonality?
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var useGlobalTemplate = false

    private var selectedFolders: [OnboardingFolder] {
        var folders: [OnboardingFolder] = []
        if folderSelection.desktop { folders.append(.desktop) }
        if folderSelection.downloads { folders.append(.downloads) }
        if folderSelection.documents { folders.append(.documents) }
        if folderSelection.pictures { folders.append(.pictures) }
        if folderSelection.music { folders.append(.music) }
        return folders
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: FormaSpacing.generous) {
                    // Header
                    VStack(spacing: FormaSpacing.standard) {
                        OnboardingGeometricIcon(style: .system)
                            .frame(width: 64, height: 64)

                        Text("Customize Each Space")
                            .font(.formaH1)
                            .foregroundColor(.formaLabel)

                        Text("Different folders deserve different organization.\nTell us how you'd like each one organized.")
                            .font(.formaBodyLarge)
                            .foregroundColor(.formaSecondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, FormaSpacing.huge)

                    // Per-folder cards
                    VStack(spacing: FormaSpacing.standard) {
                        ForEach(selectedFolders, id: \.self) { folder in
                            FolderTemplateCard(
                                folder: folder,
                                selectedTemplate: binding(for: folder),
                                personality: personality
                            )
                        }
                    }
                    .padding(.horizontal, FormaSpacing.large)

                    // Use same template toggle
                    HStack(spacing: FormaSpacing.tight) {
                        Button(action: applyGlobalTemplate) {
                            HStack(spacing: FormaSpacing.tight) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.formaCompact)
                                Text("Use same template for all folders")
                                    .font(.formaBody)
                            }
                            .foregroundColor(.formaSteelBlue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, FormaSpacing.tight)

                    // Tip box
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "lightbulb.fill")
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaWarmOrange)

                        Text("Tip: You can change these anytime in Settings")
                            .font(.formaBody)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                    .padding(FormaSpacing.standard)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaWarmOrange.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                    )
                    .padding(.horizontal, FormaSpacing.large)
                }
                .padding(.bottom, FormaSpacing.extraLarge)
            }

            // Footer
            OnboardingFooter(
                primaryTitle: "Preview Your System",
                primaryEnabled: true,
                primaryAction: onContinue,
                secondaryTitle: "Back",
                secondaryAction: onBack
            )
        }
    }

    private func binding(for folder: OnboardingFolder) -> Binding<OrganizationTemplate> {
        Binding(
            get: { templateSelection.template(for: folder, personality: personality) },
            set: { newValue in
                var updated = templateSelection
                updated.setTemplate(newValue, for: folder)
                templateSelection = updated
            }
        )
    }

    private func applyGlobalTemplate() {
        let defaultTemplate = personality?.suggestedTemplate ?? .minimal
        var updated = templateSelection
        for folder in selectedFolders {
            updated.setTemplate(defaultTemplate, for: folder)
        }
        templateSelection = updated
    }
}

// MARK: - Preview Step View (Step 5 in new flow)

/// Final preview step showing the complete folder structure
struct PreviewStepView: View {
    let folderSelection: OnboardingFolderSelection
    let templateSelection: FolderTemplateSelection
    let personality: OrganizationPersonality?
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var animateIn = false

    private var selectedFolders: [OnboardingFolder] {
        var folders: [OnboardingFolder] = []
        if folderSelection.desktop { folders.append(.desktop) }
        if folderSelection.downloads { folders.append(.downloads) }
        if folderSelection.documents { folders.append(.documents) }
        if folderSelection.pictures { folders.append(.pictures) }
        if folderSelection.music { folders.append(.music) }
        return folders
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: FormaSpacing.generous) {
                    // Header with celebration
                    VStack(spacing: FormaSpacing.standard) {
                        Text("✨")
                            .font(.formaIcon)
                            .scaleEffect(animateIn ? 1.0 : 0.5)
                            .opacity(animateIn ? 1.0 : 0)

                        Text("Your Organization System")
                            .font(.formaH1)
                            .foregroundColor(.formaLabel)
                            .opacity(animateIn ? 1.0 : 0)
                            .offset(y: animateIn ? 0 : 10)

                        Text("Here's how Forma will organize your files.\nFolders are created automatically when files need them.")
                            .font(.formaBodyLarge)
                            .foregroundColor(.formaSecondaryLabel)
                            .multilineTextAlignment(.center)
                            .opacity(animateIn ? 1.0 : 0)
                            .offset(y: animateIn ? 0 : 10)
                    }
                    .padding(.top, FormaSpacing.huge)

                    // Complete folder structure preview
                    VStack(alignment: .leading, spacing: FormaSpacing.generous) {
                        ForEach(Array(selectedFolders.enumerated()), id: \.element) { index, folder in
                            let template = templateSelection.template(for: folder, personality: personality)
                            FolderStructurePreview(
                                rootFolderName: folder.title,
                                template: template,
                                showAnnotations: true,
                                accentColor: folder.color
                            )
                            .padding(FormaSpacing.standard)
                            .background(
                                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                    .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                    .stroke(folder.color.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                            )
                            .opacity(animateIn ? 1.0 : 0)
                            .offset(y: animateIn ? 0 : 20)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.1),
                                value: animateIn
                            )
                        }
                    }
                    .padding(.horizontal, FormaSpacing.large)

                    // Note about lazy folder creation
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "sparkles")
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaSage)

                        Text("These folders will be created as files are sorted.\nNo empty folders—just what you need, when needed.")
                            .font(.formaBody)
                            .foregroundColor(.formaSecondaryLabel)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(FormaSpacing.standard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaSage.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                    )
                    .padding(.horizontal, FormaSpacing.large)
                    .opacity(animateIn ? 1.0 : 0)
                }
                .padding(.bottom, FormaSpacing.extraLarge)
            }

            // Footer with celebration button
            OnboardingFooter(
                primaryTitle: "🎉 Start Organizing",
                primaryEnabled: true,
                primaryAction: onComplete,
                secondaryTitle: "Back",
                secondaryAction: onBack
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Folder Template Card") {
    VStack(spacing: 12) {
        FolderTemplateCard(
            folder: .pictures,
            selectedTemplate: .constant(.chronological),
            personality: nil
        )

        FolderTemplateCard(
            folder: .desktop,
            selectedTemplate: .constant(.minimal),
            personality: nil
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color.formaBackground)
}

#Preview("Folder Template Step") {
    FolderTemplateStepView(
        folderSelection: .constant(OnboardingFolderSelection(
            desktop: true,
            downloads: true,
            documents: false,
            pictures: true,
            music: false
        )),
        templateSelection: .constant(FolderTemplateSelection()),
        personality: nil,
        onContinue: {},
        onBack: {}
    )
    .frame(width: 650, height: 720)
    .background(Color.formaBackground)
}

#Preview("Preview Step") {
    PreviewStepView(
        folderSelection: OnboardingFolderSelection(
            desktop: true,
            downloads: true,
            documents: false,
            pictures: true,
            music: false
        ),
        templateSelection: FolderTemplateSelection(
            desktop: .minimal,
            downloads: .para,
            pictures: .chronological
        ),
        personality: nil,
        onComplete: {},
        onBack: {}
    )
    .frame(width: 650, height: 720)
    .background(Color.formaBackground)
}
