import SwiftUI
import SwiftData
import QuickLook

/// Inspector mode of the right panel showing file details, preview, and organization actions
struct FileInspectorView: View {
    let files: [FileItem]
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaSpacing.large) {
                if files.count == 1, let file = files.first {
                    singleFileInspector(file)
                } else {
                    multipleFilesInspector()
                }
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.top, FormaSpacing.generous)
            .padding(.bottom, FormaSpacing.generous)
        }
        .background(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
    }
    
    // MARK: - Single File Inspector
    
    @ViewBuilder
    private func singleFileInspector(_ file: FileItem) -> some View {
        // Header
        Text("File Inspector")
            .font(.formaH3)
            .foregroundColor(.formaLabel)
            .padding(.bottom, FormaSpacing.tight)
        
        // Preview
        filePreviewCard(file)
        
        // Metadata
        metadataCard(file)
        
        // Organization Section
        if let destination = file.destination {
            organizationCard(file, destination: destination.displayName)
            
            // Match Reasoning Section (if available)
            if file.matchReason != nil || file.confidenceScore != nil {
                matchReasoningCard(file)
            }
        } else {
            noSuggestionCard(file)
        }
        
        // Action Buttons
        actionButtons(file)
        
        // Similar Files
        if let similarFiles = findSimilarFiles(to: file), !similarFiles.isEmpty {
            similarFilesSection(similarFiles)
        }
    }
    
    // MARK: - Multiple Files Inspector
    
    @ViewBuilder
    private func multipleFilesInspector() -> some View {
        // Header
        Text("Selection")
            .font(.formaH3)
            .foregroundColor(.formaLabel)
            .padding(.bottom, FormaSpacing.tight)
        
        // Summary Card
        selectionSummaryCard()
        
        // Preview Grid
        previewGridCard()
        
        // Common Pattern Detection
        if let pattern = detectCommonPattern() {
            patternDetectionCard(pattern)
        }
        
        // Bulk Actions
        bulkActionsCard()
    }
    
    // MARK: - Single File Components
    
    private func filePreviewCard(_ file: FileItem) -> some View {
        VStack(spacing: 0) {
            // Preview area
            ZStack {
                Color.formaCardBackground
                
                if file.category == .images {
                    // Image preview using CGImageSource for better reliability
                    if let cgImage = createThumbnail(path: file.path, maxSize: 200) {
                        Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                    } else {
                        VStack {
                            previewPlaceholder(file)
                            Text("Preview unavailable")
                                .font(.formaMicro)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    previewPlaceholder(file)
                }
            }
            .frame(height: 200)
            .formaCornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
            )
            
            // Quick Look button
            Button(action: {
                dashboardViewModel.showQuickLook(for: file)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.formaCompactSemibold)
                    Text("Quick Look")
                        .font(.formaBodyMedium)
                }
                .foregroundColor(.formaSteelBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.tight)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, FormaSpacing.tight)
        }
    }
    
    private func previewPlaceholder(_ file: FileItem) -> some View {
        VStack(spacing: FormaSpacing.standard) {
            Image(systemName: file.category.iconName)
                .font(.formaIcon)
                .foregroundColor(file.category.color.opacity(Color.FormaOpacity.strong))
            
            Text(file.fileExtension.uppercased())
                .font(.formaCaption)
                .foregroundColor(.formaSecondaryLabel)
        }
    }
    
    private func createThumbnail(path: String, maxSize: CGFloat) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize
        ]
        
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }
    
    private func metadataCard(_ file: FileItem) -> some View {
        CollapsibleSection(title: "Details", icon: "info.circle", storageKey: "inspector.details") {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                metadataRow(label: "Name", value: file.name)
                metadataRow(label: "Size", value: file.size)
                metadataRow(label: "Type", value: file.category.rawValue.capitalized)
                metadataRow(label: "Created", value: formatDate(file.creationDate))
                metadataRow(label: "Location", value: abbreviatePath(file.path))
            }
        }
    }
    
    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: FormaSpacing.standard) {
            Text(label)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .frame(minWidth: 60, alignment: .leading)
            
            Text(value)
                .font(.formaSmall)
                .foregroundColor(.formaLabel)
                .lineLimit(2)
            
            Spacer()
        }
    }
    
    private func organizationCard(_ file: FileItem, destination: String) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Organization")
                .font(.formaBodySemibold)
                .tracking(0.5)
                .foregroundColor(.formaSecondaryLabel)

            // Suggested destination
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.formaSteelBlue)
                    .font(.formaBodyLarge)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested Destination")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                    
                    Text(destination)
                        .font(.formaSmall)
                        .foregroundColor(.formaLabel)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(FormaSpacing.standard)
            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
            .formaCornerRadius(FormaRadius.small)
            
            // Why this suggestion?
            if let matchingRules = dashboardViewModel.getMatchingRules(for: file).first {
                Button(action: {}) {
                    HStack(spacing: FormaSpacing.micro) {
                        Image(systemName: "info.circle")
                            .font(.formaCompact)
                        Text("Based on rule: \"\(matchingRules.name)\"")
                            .font(.formaCaption)
                    }
                    .foregroundColor(.formaSteelBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
    
    private func matchReasoningCard(_ file: FileItem) -> some View {
        CollapsibleSection(title: "Why This Suggestion?", icon: "lightbulb", storageKey: "inspector.matchReasoning") {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                // Confidence indicator
                if let confidence = file.confidenceScore {
                    HStack(spacing: FormaSpacing.standard) {
                        confidenceIcon(for: confidence)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Confidence")
                                .font(.formaCaption)
                                .foregroundColor(.formaSecondaryLabel)

                            HStack(spacing: 6) {
                                Text(confidenceLabel(for: confidence))
                                    .font(.formaBodySemibold)
                                    .foregroundColor(confidenceColor(for: confidence))

                                Text("(\(Int(confidence * 100))%)")
                                    .font(.formaCaption)
                                    .foregroundColor(.formaSecondaryLabel)
                            }
                        }

                        Spacer()
                    }
                }

                // Match reason explanation
                if let reason = file.matchReason, !reason.isEmpty {
                    Divider()
                        .background(Color.formaSeparator)

                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.formaCompact)
                                .foregroundColor(.formaSteelBlue.opacity(Color.FormaOpacity.high))

                            Text("Match Details")
                                .font(.formaCaption)
                                .foregroundColor(.formaSecondaryLabel)
                        }

                        Text(reason)
                            .font(.formaSmall)
                            .foregroundColor(.formaLabel)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(FormaSpacing.standard)
            .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
            .formaCornerRadius(FormaRadius.control)
        }
    }
    
    private func noSuggestionCard(_ file: FileItem) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.formaWarmOrange)
                Text("No organization rule matches this file")
                    .font(.formaSmall)
                    .foregroundColor(.formaLabel)
            }
            
            Button(action: {
                dashboardViewModel.showRuleBuilderPanel(fileContext: file)
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create Rule for This File")
                        .font(.formaSmall)
                }
                .foregroundColor(.formaSteelBlue)
                .padding(.vertical, FormaSpacing.tight)
                .padding(.horizontal, FormaSpacing.standard)
                .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                .formaCornerRadius(FormaRadius.small)
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
    
    private func actionButtons(_ file: FileItem) -> some View {
        VStack(spacing: FormaSpacing.standard) {
            // Primary action: Organize
            if file.destination != nil {
                PrimaryButton("Organize", icon: "checkmark.circle.fill") {
                    dashboardViewModel.organizeFile(file, context: modelContext)
                }
            }
            
            // Secondary actions
            HStack(spacing: FormaSpacing.standard) {
                SecondaryButton("Skip", icon: "xmark.circle") {
                    dashboardViewModel.skipFile(file)
                    dashboardViewModel.deselectAll()
                }
                
                Button(action: {
                    // Delete action - would need confirmation
                }) {
                        Image(systemName: "trash")
                            .font(.formaBody)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FormaSpacing.tight) // Match SecondaryButton height
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .stroke(Color.formaWarmOrange.opacity(Color.FormaOpacity.strong), lineWidth: 1)
                    )
                    .foregroundColor(.formaWarmOrange)
                    .help("Delete File")
            }
            
            // Tertiary: Create rule from this
            Button(action: {
                dashboardViewModel.showRuleBuilderPanel(fileContext: file)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.formaBodySemibold)
                    Text("Create Rule from This")
                        .font(.formaBodyLarge)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.formaSteelBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.standard - FormaSpacing.micro)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.strong), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func similarFilesSection(_ similarFiles: [FileItem]) -> some View {
        CollapsibleSection(title: "Similar Files", icon: "doc.on.doc", storageKey: "inspector.similarFiles", defaultExpanded: false) {
            VStack(spacing: FormaSpacing.tight) {
                ForEach(similarFiles.prefix(3)) { similarFile in
                    similarFileRow(similarFile)
                }
            }

            if similarFiles.count > 1 {
                Button(action: {
                    // Select all similar files
                    for file in similarFiles {
                        if !dashboardViewModel.isSelected(file) {
                            dashboardViewModel.toggleSelection(for: file)
                        }
                    }
                }) {
                    Text("Select all \(similarFiles.count) similar files")
                        .font(.formaSmall)
                        .foregroundColor(.formaSteelBlue)
                }
                .buttonStyle(.plain)
                .padding(.top, FormaSpacing.tight)
            }
        }
    }
    
    private func similarFileRow(_ file: FileItem) -> some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: file.category.iconName)
                .foregroundColor(file.category.color)
                .font(.formaBodySemibold)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.formaSmall)
                    .foregroundColor(.formaLabel)
                    .lineLimit(1)
                
                Text(file.size)
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
            }
            
            Spacer()
        }
        .padding(.vertical, FormaSpacing.micro)
    }
    
    // MARK: - Multiple Files Components
    
    private func selectionSummaryCard() -> some View {
        let totalSize = files.reduce(0) { $0 + $1.sizeInBytes }
        let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        
        return VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.formaSteelBlue)
                    .font(.formaH2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(files.count) \(files.count == 1 ? "file" : "files") selected")
                        .font(.formaBodyBold)
                        .foregroundColor(.formaLabel)
                    
                    Text(formattedSize)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
                
                Spacer()
                
                Button(action: {
                    dashboardViewModel.deselectAll()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.formaSecondaryLabel)
                        .font(.formaH2)
                }
                .buttonStyle(.plain)
                .help("Clear Selection")
            }
        }
        .padding(FormaSpacing.large)
        .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSteelBlue.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
    
    private func previewGridCard() -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Preview")
                .font(.formaBodySemibold)
                .tracking(0.5)
                .foregroundColor(.formaSecondaryLabel)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FormaSpacing.tight) {
                ForEach(files.prefix(9)) { file in
                    previewThumbnail(file)
                }
            }
            
            if files.count > 9 {
                Text("+\(files.count - 9) more")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
            }
        }
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
    
    private func previewThumbnail(_ file: FileItem) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Color.formaControlBackground

                Image(systemName: file.category.iconName)
                    .foregroundColor(file.category.color)
                    .font(.formaH2)
            }
            .frame(width: 80, height: 80)
            .formaCornerRadius(FormaRadius.small)
            
            Text(file.fileExtension.uppercased())
                .font(.formaCaption)
                .foregroundColor(.formaSecondaryLabel)
        }
    }
    
    private func patternDetectionCard(_ pattern: String) -> some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: "sparkles")
                .foregroundColor(.formaSteelBlue)
            
            Text(pattern)
                .font(.formaSmall)
                .foregroundColor(.formaLabel)
            
            Spacer()
        }
        .padding(FormaSpacing.large)
        .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSteelBlue.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
    
    private func bulkActionsCard() -> some View {
        VStack(spacing: FormaSpacing.standard) {
            // Check if all have destinations
            let filesWithDestinations = files.filter { $0.destination != nil }
            let allHaveDestinations = filesWithDestinations.count == files.count
            let sameDest = allHaveDestinations && Set(filesWithDestinations.compactMap { $0.destination?.displayName }).count == 1

            if sameDest, let firstFile = filesWithDestinations.first, let destination = firstFile.destination?.displayName {
                PrimaryButton("Organize All to \(destination)", icon: "checkmark.circle.fill") {
                    dashboardViewModel.organizeSelectedFiles(context: modelContext)
                }
            }
            
            // Skip All button
            SecondaryButton("Skip All", icon: "xmark.circle") {
                dashboardViewModel.skipSelectedFiles()
            }
            
            Button(action: {
                dashboardViewModel.showRuleBuilderPanel()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.formaBodySemibold)
                    Text("Create Rule for These")
                        .font(.formaBodyLarge)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.formaSteelBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.standard - FormaSpacing.micro)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.strong), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
    
    // MARK: - Confidence Helpers
    
    private func confidenceIcon(for score: Double) -> some View {
        let config: (icon: String, color: Color) = {
            if score >= 0.9 {
                return ("checkmark.shield.fill", .formaSage)
            } else if score >= 0.6 {
                return ("checkmark.circle.fill", .formaSteelBlue)
            } else {
                return ("exclamationmark.triangle.fill", .formaWarmOrange)
            }
        }()
        
        return Image(systemName: config.icon)
            .font(.formaH1)
            .foregroundColor(config.color)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(config.color.opacity(Color.FormaOpacity.light))
            )
    }
    
    private func confidenceLabel(for score: Double) -> String {
        if score >= 0.9 {
            return "High"
        } else if score >= 0.6 {
            return "Medium"
        } else {
            return "Low"
        }
    }
    
    private func confidenceColor(for score: Double) -> Color {
        if score >= 0.9 {
            return .formaSage
        } else if score >= 0.6 {
            return .formaSteelBlue
        } else {
            return .formaWarmOrange
        }
    }
    
    // MARK: - Helpers
    
    private func findSimilarFiles(to file: FileItem) -> [FileItem]? {
        // Find files with same extension
        let similar = dashboardViewModel.allFiles.filter { otherFile in
            otherFile.fileExtension == file.fileExtension &&
            otherFile.path != file.path &&
            otherFile.status != .completed
        }
        
        return similar.isEmpty ? nil : Array(similar.prefix(5))
    }
    
    private func detectCommonPattern() -> String? {
        // Check if all files have same extension
        let extensions = Set(files.map { $0.fileExtension })
        if extensions.count == 1, let ext = extensions.first {
            return "All are \(ext.uppercased()) files"
        }
        
        // Check if all are screenshots
        let screenshots = files.filter {
            $0.name.localizedCaseInsensitiveContains("screenshot")
        }
        if screenshots.count == files.count {
            return "All are screenshots"
        }
        
        // Check if all are from same location
        let locations = Set(files.map { ($0.path as NSString).deletingLastPathComponent })
        if locations.count == 1 {
            return "All from same folder"
        }
        
        return nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func abbreviatePath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        return path
    }
}

@MainActor
private enum FileInspectorViewPreviews {
    static func singleFile() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: FileItem.self, Rule.self, ActivityItem.self, CustomFolder.self, configurations: config)

        let file = FileItem(
            path: "/Users/test/Downloads/Invoice_2025.pdf",
            sizeInBytes: 2_411_724,
            creationDate: Date(),
            destination: .folder(bookmark: Data(), displayName: "Documents/Finance"),
            status: .ready
        )

        return FileInspectorView(files: [file])
            .environmentObject(DashboardViewModel())
            .modelContainer(container)
            .frame(width: 360, height: 800)
    }

    static func multipleFiles() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: FileItem.self, Rule.self, ActivityItem.self, CustomFolder.self, configurations: config)

        let screenshotsDest = Destination.folder(bookmark: Data(), displayName: "Pictures/Screenshots")
        let files = [
            FileItem(path: "/Users/test/Desktop/Screenshot 1.png", sizeInBytes: 1_258_291, creationDate: Date(), destination: screenshotsDest, status: .ready),
            FileItem(path: "/Users/test/Desktop/Screenshot 2.png", sizeInBytes: 1_010_842, creationDate: Date(), destination: screenshotsDest, status: .ready),
            FileItem(path: "/Users/test/Desktop/Screenshot 3.png", sizeInBytes: 1_572_864, creationDate: Date(), destination: screenshotsDest, status: .ready)
        ]

        return FileInspectorView(files: files)
            .environmentObject(DashboardViewModel())
            .modelContainer(container)
            .frame(width: 360, height: 800)
    }
}

#Preview("Single File") {
    FileInspectorViewPreviews.singleFile()
}

#Preview("Multiple Files") {
    FileInspectorViewPreviews.multipleFiles()
}
