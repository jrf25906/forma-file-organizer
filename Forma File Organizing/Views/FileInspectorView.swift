import SwiftUI
import SwiftData
import QuickLook

/// Inspector mode of the right panel showing file details, preview, and organization actions
struct FileInspectorView: View {
    let files: [FileItem]
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var nav: NavigationViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    private let isUITesting = CommandLine.arguments.contains("--uitesting")
    private let sectionSpacing: CGFloat = FormaSpacing.large
    private let inspectorPadding: CGFloat = FormaSpacing.generous
    private let previewHeight: CGFloat = 200
    @State private var pendingTrashFile: FileItem?
    @State private var ruleSimulationSummary: RuleEngine.RuleSimulationSummary?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                if files.count == 1, let file = files.first {
                    singleFileInspector(file)
                } else {
                    multipleFilesInspector()
                }
            }
            .padding(.horizontal, inspectorPadding)
            .padding(.top, inspectorPadding)
            .padding(.bottom, inspectorPadding)
        }
        .background(Color.clear)
        .accessibilityIdentifier("fileInspectorView")
        .task(id: ruleSimulationRefreshToken) {
            refreshRuleSimulation()
        }
        .overlay(alignment: .topLeading) {
            if isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("inspectorContrastProbe")
                    .accessibilityLabel(
                        "titleOnCard=\(String(format: "%.2f", inspectorTitleContrastRatio));secondaryOnCard=\(String(format: "%.2f", inspectorSecondaryContrastRatio));quickLook=\(String(format: "%.2f", inspectorQuickLookContrastRatio));sectionSpacing=\(Int(sectionSpacing));panelPadding=\(Int(inspectorPadding));previewHeight=\(Int(previewHeight))"
                    )
                    .accessibilityValue(
                        "titleOnCard=\(String(format: "%.2f", inspectorTitleContrastRatio));secondaryOnCard=\(String(format: "%.2f", inspectorSecondaryContrastRatio));quickLook=\(String(format: "%.2f", inspectorQuickLookContrastRatio));sectionSpacing=\(Int(sectionSpacing));panelPadding=\(Int(inspectorPadding));previewHeight=\(Int(previewHeight))"
                    )
            }
        }
        .confirmationDialog(
            "Move file to Trash?",
            isPresented: Binding(
                get: { pendingTrashFile != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingTrashFile = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                guard let pendingTrashFile else { return }
                moveToTrash(pendingTrashFile)
                self.pendingTrashFile = nil
            }

            Button("Cancel", role: .cancel) {
                pendingTrashFile = nil
            }
        } message: {
            if let pendingTrashFile {
                Text("\"\(pendingTrashFile.name)\" will be moved to Trash.")
            }
        }
    }
    
    // MARK: - Single File Inspector
    
    @ViewBuilder
    private func singleFileInspector(_ file: FileItem) -> some View {
        let matchingRule = matchingRule(for: file)

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
            organizationCard(file, destination: destination.displayName, matchingRule: matchingRule)
            
            // Match Reasoning Section (if available)
            if file.matchReason != nil || file.confidenceScore != nil || matchingRule != nil {
                matchReasoningCard(file, matchingRule: matchingRule)
            }
        } else {
            noSuggestionCard(file)
        }
        
        // Action Buttons
        actionButtons(file)

        if FeatureFlagService.shared.isEnabled(.metadataFoundation) {
            MetadataFoundationProofSection(filePath: file.path)
        }
        
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
                            .frame(maxHeight: previewHeight)
                    } else {
                        VStack {
                            previewPlaceholder(file)
                            Text("Preview unavailable")
                                .font(.formaMicro)
                                .foregroundColor(inspectorSecondaryTextColor)
                        }
                    }
                } else {
                    previewPlaceholder(file)
                }
            }
            .frame(height: previewHeight)
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
                .foregroundColor(quickLookButtonTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.tight)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                        .fill(quickLookButtonBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                        .stroke(
                            quickLookBorderColor,
                            lineWidth: 1
                        )
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
                .foregroundColor(inspectorSecondaryTextColor)
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
                .foregroundColor(inspectorSecondaryTextColor)
                .frame(minWidth: 60, alignment: .leading)
            
            Text(value)
                .font(.formaSmall)
                .foregroundColor(.formaLabel)
                .lineLimit(2)
            
            Spacer()
        }
    }
    
    private func organizationCard(_ file: FileItem, destination: String, matchingRule: Rule?) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Organization")
                .font(.formaBodySemibold)
                .tracking(0.5)
                .foregroundColor(inspectorSecondaryTextColor)

            // Suggested destination
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.formaSteelBlue)
                    .font(.formaBodyLarge)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested Destination")
                        .font(.formaCaption)
                        .foregroundColor(inspectorSecondaryTextColor)
                    
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
            if let matchingRule {
                Button(action: {
                    openRuleEditor(for: matchingRule, file: file)
                }) {
                    HStack(spacing: FormaSpacing.micro) {
                        Image(systemName: "info.circle")
                            .font(.formaCompact)
                        Text("Why this matched: \"\(matchingRule.name)\"")
                            .font(.formaCaption)
                    }
                    .foregroundColor(.formaSteelBlue)
                }
                .buttonStyle(.plain)
                .help("Open the rule behind this match")
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
    
    private func matchReasoningCard(_ file: FileItem, matchingRule: Rule?) -> some View {
        CollapsibleSection(title: "Why This Matched", icon: "lightbulb", storageKey: "inspector.matchReasoning") {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                // Confidence indicator
                if let confidence = file.confidenceScore {
                    HStack(spacing: FormaSpacing.standard) {
                        confidenceIcon(for: confidence)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Confidence")
                                .font(.formaCaption)
                                .foregroundColor(inspectorSecondaryTextColor)

                            HStack(spacing: 6) {
                                Text(confidenceLabel(for: confidence))
                                    .font(.formaBodySemibold)
                                    .foregroundColor(confidenceColor(for: confidence))

                                Text("(\(Int(confidence * 100))%)")
                                    .font(.formaCaption)
                                    .foregroundColor(inspectorSecondaryTextColor)
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

                            Text("Why it matched")
                                .font(.formaCaption)
                                .foregroundColor(inspectorSecondaryTextColor)
                        }

                        Text(reason)
                            .font(.formaSmall)
                            .foregroundColor(.formaLabel)
                            .lineSpacing(2)
                    }
                }

                if let matchingRule, let summary = ruleSimulationSummary {
                    Divider()
                        .background(Color.formaSeparator)

                    ruleSimulationSection(summary, matchingRule: matchingRule)
                }
            }
            .padding(FormaSpacing.standard)
            .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
            .formaCornerRadius(FormaRadius.control)
        }
    }

    private func ruleSimulationSection(
        _ summary: RuleEngine.RuleSimulationSummary,
        matchingRule: Rule
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .font(.formaCompact)
                    .foregroundColor(.formaSteelBlue.opacity(Color.FormaOpacity.high))

                Text("What will happen")
                    .font(.formaCaption)
                    .foregroundColor(inspectorSecondaryTextColor)
            }

            Text("Rule \"\(matchingRule.name)\" would catch \(summary.matchCount) of \(summary.evaluatedCount) scanned \(summary.evaluatedCount == 1 ? "file" : "files").")
                .font(.formaSmall)
                .foregroundColor(.formaLabel)

            if !summary.examples.isEmpty {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    ForEach(Array(summary.examples.prefix(3).enumerated()), id: \.offset) { example in
                        ruleSimulationExampleRow(example.element)
                    }
                }
            }

            Text("Preview only. Rule-driven suggestions do not move anything until you run a review pass or automatic pass.")
                .font(.formaCaption)
                .foregroundColor(inspectorSecondaryTextColor)
        }
    }

    private func ruleSimulationExampleRow(_ example: RuleEngine.RuleSimulationExample) -> some View {
        HStack(alignment: .top, spacing: FormaSpacing.tight) {
            Circle()
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.medium))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(example.fileName)
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaLabel)
                    .lineLimit(1)

                if let destination = example.suggestedDestination {
                    Text(destination)
                        .font(.formaCaption)
                        .foregroundColor(inspectorSecondaryTextColor)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }
    
    private func noSuggestionCard(_ file: FileItem) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.formaWarmOrange)
                Text("No rule matches this file yet")
                    .font(.formaSmall)
                    .foregroundColor(.formaLabel)
            }
            
            Button(action: {
                openRuleBuilderPanel(
                    fileContext: file,
                    returnTarget: .inspector(filePath: file.path)
                )
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create Rule for Future Matches")
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
    
    @ViewBuilder
    private func actionButtons(_ file: FileItem) -> some View {
        let matchingRule = matchingRule(for: file)

        VStack(spacing: FormaSpacing.standard) {
            // Primary action: Organize
            if file.destination != nil {
                PrimaryButton("Organize", icon: "checkmark.circle.fill") {
                    dashboardViewModel.organizeFile(file, context: modelContext, sourceSurface: .inspector)
                }
            }
            
            // Secondary actions
            HStack(spacing: FormaSpacing.standard) {
                SecondaryButton("Skip", icon: "xmark.circle") {
                    dashboardViewModel.skipFile(file)
                    dashboardViewModel.deselectAll()
                }
                
                Button(action: {
                    pendingTrashFile = file
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
            
            if file.destination != nil {
                Button(action: {
                    openRuleBuilderPanel(
                        fileContext: file,
                        returnTarget: .inspector(filePath: file.path)
                    )
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: matchingRule == nil ? "wand.and.stars" : "slider.horizontal.3")
                            .font(.formaBodySemibold)
                        Text(matchingRule == nil ? "Create Rule from This" : "Adjust This Rule")
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
                    .foregroundColor(inspectorSecondaryTextColor)
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
                        .foregroundColor(inspectorSecondaryTextColor)
                }
                
                Spacer()
                
                Button(action: {
                    dashboardViewModel.deselectAll()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(inspectorSecondaryTextColor)
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
                .foregroundColor(inspectorSecondaryTextColor)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FormaSpacing.tight) {
                ForEach(files.prefix(9)) { file in
                    previewThumbnail(file)
                }
            }
            
            if files.count > 9 {
                Text("+\(files.count - 9) more")
                    .font(.formaCaption)
                    .foregroundColor(inspectorSecondaryTextColor)
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
                .foregroundColor(inspectorSecondaryTextColor)
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
                openRuleBuilderPanel(returnTarget: .defaultPanel)
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

    private var inspectorSecondaryTextColor: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.82) : .formaSecondaryLabel
    }

    private var quickLookButtonTextColor: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.92) : .formaSteelBlue
    }

    private var quickLookButtonBackgroundColor: Color {
        colorScheme == .dark
            ? Color.formaSteelBlue.opacity(0.5)
            : Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
    }

    private var quickLookBorderColor: Color {
        colorScheme == .dark
            ? Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent)
            : Color.formaSteelBlue.opacity(Color.FormaOpacity.medium)
    }

    private var inspectorTitleContrastRatio: Double {
        FormaContrastMetrics.contrastRatio(
            foreground: .formaLabel,
            background: .formaCardBackground,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var inspectorSecondaryContrastRatio: Double {
        FormaContrastMetrics.contrastRatio(
            foreground: inspectorSecondaryTextColor,
            background: .formaCardBackground,
            colorScheme: colorScheme,
            baseBackground: colorScheme == .dark ? .formaObsidian : .formaBoneWhite
        )
    }

    private var inspectorQuickLookContrastRatio: Double {
        FormaContrastMetrics.contrastRatio(
            foreground: quickLookButtonTextColor,
            background: quickLookButtonBackgroundColor,
            colorScheme: colorScheme,
            baseBackground: .formaCardBackground
        )
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

    private var ruleSimulationRefreshToken: FileInspectorRuleSimulationRefreshToken {
        let rule = files.count == 1 ? files.first.flatMap { matchingRule(for: $0) } : nil
        return FileInspectorRuleSimulationRefreshToken(
            selectedFiles: files,
            matchingRule: rule,
            allFiles: dashboardViewModel.allFiles
        )
    }

    private func matchingRule(for file: FileItem) -> Rule? {
        dashboardViewModel.getMatchingRules(for: file).first
    }

    private func refreshRuleSimulation() {
        guard files.count == 1,
              let file = files.first,
              let matchingRule = matchingRule(for: file) else {
            ruleSimulationSummary = nil
            return
        }

        ruleSimulationSummary = RuleEngine().simulateRule(
            matchingRule,
            across: dashboardViewModel.allFiles,
            exampleLimit: 3
        )
    }

    private func openRuleEditor(for rule: Rule, file: FileItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            nav.beginRuleDraft(
                editingRule: rule,
                fileContext: file,
                presentation: .modal,
                returnTarget: .inspector(filePath: file.path)
            )
        }
    }

    private func openRuleBuilderPanel(
        editingRule: Rule? = nil,
        fileContext: FileItem? = nil,
        returnTarget: RuleDraftReturnTarget
    ) {
        nav.beginRuleDraft(
            editingRule: editingRule,
            fileContext: fileContext,
            presentation: .panel,
            returnTarget: returnTarget
        )
        if case .inspector = returnTarget, let fileContext {
            dashboardViewModel.showRuleBuilderPanelForInspector(fileContext, editingRule: editingRule)
        } else {
            dashboardViewModel.showRuleBuilderPanel(editingRule: editingRule, fileContext: fileContext)
        }
    }

    private func moveToTrash(_ file: FileItem) {
        dashboardViewModel.updateDestination(for: file, to: .trash)
        dashboardViewModel.organizeFile(file, context: modelContext, sourceSurface: .inspector)
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

private struct MetadataFoundationProofSection: View {
    let filePath: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var summary: FileMetadataInspectorSummary?

    var body: some View {
        Group {
            if let summary {
                metadataProofSection(summary)
            }
        }
        .task(id: filePath) {
            await loadSummary()
        }
    }

    private func loadSummary() async {
        guard FeatureFlagService.shared.isEnabled(.metadataFoundation) else {
            summary = nil
            return
        }

        summary = nil
        summary = FileMetadataFoundationService(modelContext: modelContext).inspectorSummary(for: filePath)
    }

    private func metadataProofSection(_ summary: FileMetadataInspectorSummary) -> some View {
        let historyRows = Array(summary.recentHistoryRows.prefix(3))

        return CollapsibleSection(
            title: "Metadata foundation",
            icon: "archivebox",
            storageKey: "inspector.metadataFoundation",
            defaultExpanded: false
        ) {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text("Durable organization summary")
                        .font(.formaCaptionSemibold)
                        .foregroundColor(inspectorSecondaryTextColor)

                    ForEach(summary.durableSummaryLines, id: \.self) { line in
                        Text(line)
                            .font(.formaSmall)
                            .foregroundColor(.formaLabel)
                    }
                }

                if summary.hasProjectAssociationSummary {
                    metadataRow(label: "Project", value: summary.projectAssociationSummary)
                }

                if let sourceSummary = summary.projectAssociationSourceSummary, !sourceSummary.isEmpty {
                    metadataRow(label: "Source", value: sourceSummary)
                }

                if summary.hasTagsSummary {
                    metadataRow(label: "Tags", value: summary.tagsSummary)
                }

                if summary.hasRecentHistoryRows {
                    Divider()
                        .background(Color.formaSeparator)

                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        Text("Recent history")
                            .font(.formaCaptionSemibold)
                            .foregroundColor(inspectorSecondaryTextColor)

                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            ForEach(historyRows.indices, id: \.self) { index in
                                metadataFoundationHistoryRow(historyRows[index])

                                if index < historyRows.count - 1 {
                                    Divider()
                                        .background(Color.formaSeparator)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: FormaSpacing.standard) {
            Text(label)
                .font(.formaSmall)
                .foregroundColor(inspectorSecondaryTextColor)
                .frame(minWidth: 60, alignment: .leading)

            Text(value)
                .font(.formaSmall)
                .foregroundColor(.formaLabel)
                .lineLimit(2)

            Spacer()
        }
    }

    private func metadataFoundationHistoryRow(_ row: FileMetadataInspectorSummary.HistoryRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(row.timestampSummary) • \(row.eventKind.capitalized) • \(row.sourceSurface.capitalized)")
                .font(.formaCaption)
                .foregroundColor(.formaLabel)
                .lineLimit(2)

            if let destination = row.destinationDisplayName, !destination.isEmpty {
                Text("Destination: \(destination)")
                    .font(.formaCaption)
                    .foregroundColor(inspectorSecondaryTextColor)
                    .lineLimit(1)
            }

            if let details = row.detailsSummary, !details.isEmpty {
                Text(details)
                    .font(.formaCaption)
                    .foregroundColor(inspectorSecondaryTextColor)
                    .lineSpacing(1)
            }
        }
    }

    private var inspectorSecondaryTextColor: Color {
        colorScheme == .dark ? Color.formaBoneWhite.opacity(0.82) : .formaSecondaryLabel
    }
}

struct FileInspectorRuleSimulationRefreshToken: Hashable {
    let selectedFileCount: Int
    let selectedFileFingerprint: Int?
    let matchingRuleFingerprint: Int?
    let allFilesFingerprint: Int

    init<F: Fileable, R: Ruleable>(
        selectedFiles: [F],
        matchingRule: R?,
        allFiles: [F]
    ) {
        selectedFileCount = selectedFiles.count
        selectedFileFingerprint = selectedFiles.count == 1 ? Self.fileFingerprint(selectedFiles[0]) : nil
        if selectedFiles.count == 1, let matchingRule {
            matchingRuleFingerprint = Self.ruleFingerprint(matchingRule)
        } else {
            matchingRuleFingerprint = nil
        }
        allFilesFingerprint = selectedFiles.count == 1 ? Self.collectionFingerprint(allFiles) : 0
    }

    private static func collectionFingerprint<F: Fileable>(_ files: [F]) -> Int {
        var hasher = Hasher()
        hasher.combine(files.count)
        for file in files {
            hasher.combine(fileFingerprint(file))
        }
        return hasher.finalize()
    }

    private static func fileFingerprint<F: Fileable>(_ file: F) -> Int {
        var hasher = Hasher()
        hasher.combine(file.path)
        hasher.combine(file.name)
        hasher.combine(file.fileExtension)
        hasher.combine(file.destinationDisplayName)
        hasher.combine(file.status.rawValue)
        hasher.combine(file.matchReason)
        hasher.combine(file.confidenceScore ?? -1)
        hasher.combine(file.matchedRuleID)
        hasher.combine(file.creationDate.timeIntervalSinceReferenceDate)
        hasher.combine(file.modificationDate.timeIntervalSinceReferenceDate)
        hasher.combine(file.lastAccessedDate.timeIntervalSinceReferenceDate)
        hasher.combine(file.sizeInBytes)
        hasher.combine(file.location.rawValue)
        return hasher.finalize()
    }

    private static func ruleFingerprint<R: Ruleable>(_ rule: R) -> Int {
        var hasher = Hasher()
        hasher.combine(rule.id)
        hasher.combine(rule.conditionsSummary)
        hasher.combine(rule.destinationDisplayText)
        hasher.combine(rule.actionType.rawValue)
        hasher.combine(rule.logicalOperator.rawValue)
        hasher.combine(rule.isEnabled)
        hasher.combine(rule.sortOrder)
        for condition in rule.conditions {
            hasher.combine(condition)
        }
        for exclusion in rule.exclusionConditions {
            hasher.combine(exclusion)
        }
        return hasher.finalize()
    }
}

@MainActor
private enum FileInspectorViewPreviews {
    static func singleFile() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: FileItem.self, Rule.self, ActivityItem.self, configurations: config)

        let file = FileItem(
            path: "/Users/test/Downloads/Invoice_2025.pdf",
            sizeInBytes: 2_411_724,
            creationDate: Date(),
            destination: .folder(bookmark: Data(), displayName: "Documents/Finance"),
            status: .ready
        )

        return FileInspectorView(files: [file])
            .environmentObject(DashboardViewModel())
            .environmentObject(NavigationViewModel())
            .modelContainer(container)
            .frame(width: 360, height: 800)
    }

    static func multipleFiles() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: FileItem.self, Rule.self, ActivityItem.self, configurations: config)

        let screenshotsDest = Destination.folder(bookmark: Data(), displayName: "Pictures/Screenshots")
        let files = [
            FileItem(path: "/Users/test/Desktop/Screenshot 1.png", sizeInBytes: 1_258_291, creationDate: Date(), destination: screenshotsDest, status: .ready),
            FileItem(path: "/Users/test/Desktop/Screenshot 2.png", sizeInBytes: 1_010_842, creationDate: Date(), destination: screenshotsDest, status: .ready),
            FileItem(path: "/Users/test/Desktop/Screenshot 3.png", sizeInBytes: 1_572_864, creationDate: Date(), destination: screenshotsDest, status: .ready)
        ]

        return FileInspectorView(files: files)
            .environmentObject(DashboardViewModel())
            .environmentObject(NavigationViewModel())
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
