//
//  FormaDesignSystemView.swift
//  Forma - Design System Catalog
//
//  A Storybook-style component catalog showcasing all Forma design tokens,
//  components, and usage examples. Use this view during development to
//  ensure consistency and discover available components.
//
//  Access via: Window > Design System (Cmd+Shift+D)
//

import SwiftUI

// MARK: - Main Catalog View

struct FormaDesignSystemView: View {
    @State private var selectedSection: DesignSystemSection = .colors

    enum DesignSystemSection: String, CaseIterable, Identifiable {
        case colors = "Colors"
        case typography = "Typography"
        case spacing = "Spacing & Radius"
        case buttons = "Buttons"
        case cards = "Cards"
        case controls = "Controls"
        case examples = "Usage Examples"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .colors: return "paintpalette"
            case .typography: return "textformat"
            case .spacing: return "ruler"
            case .buttons: return "rectangle.and.hand.point.up.left"
            case .cards: return "rectangle.on.rectangle"
            case .controls: return "slider.horizontal.3"
            case .examples: return "doc.text"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(DesignSystemSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Design System")
        } detail: {
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: FormaSpacing.extraLarge) {
                    switch selectedSection {
                    case .colors:
                        ColorTokensSection()
                    case .typography:
                        TypographyTokensSection()
                    case .spacing:
                        SpacingRadiusSection()
                    case .buttons:
                        ButtonComponentsSection()
                    case .cards:
                        CardComponentsSection()
                    case .controls:
                        ControlComponentsSection()
                    case .examples:
                        UsageExamplesSection()
                    }
                }
                .padding(FormaSpacing.generous)
            }
            .background(Color.formaBackground)
            .navigationTitle(selectedSection.rawValue)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

// MARK: - Catalog Section Header

private struct CatalogSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(title)
                .font(.formaH1)
                .foregroundColor(.formaObsidian)

            Text(subtitle)
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(.bottom, FormaSpacing.standard)
    }
}

// MARK: - Token Row

private struct TokenRow<Content: View>: View {
    let name: String
    let value: String
    let content: Content

    init(name: String, value: String, @ViewBuilder content: () -> Content) {
        self.name = name
        self.value = value
        self.content = content()
    }

    var body: some View {
        HStack(spacing: FormaSpacing.large) {
            content
                .frame(width: 80, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaObsidian)

                Text(value)
                    .font(.formaMono)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()

            // Copy button
            Button(action: { copyToClipboard(name) }) {
                Image(systemName: "doc.on.doc")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .buttonStyle(.plain)
            .help("Copy token name")
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaControlBackground)
        .cornerRadius(FormaRadius.control)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Color Tokens Section

private struct ColorTokensSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            CatalogSectionHeader(
                title: "Color Tokens",
                subtitle: "Semantic color tokens for consistent theming. Always use these instead of hardcoded colors."
            )

            // Primary Colors
            GroupBox("Primary Brand Colors") {
                VStack(spacing: FormaSpacing.tight) {
                    ColorTokenRow(name: "formaObsidian", color: .formaObsidian, hex: "#1A1A1A")
                    ColorTokenRow(name: "formaBoneWhite", color: .formaBoneWhite, hex: "#FAF9F6")
                    ColorTokenRow(name: "formaSteelBlue", color: .formaSteelBlue, hex: "#4A7C9B")
                }
            }

            // Accent Colors
            GroupBox("Accent Colors") {
                VStack(spacing: FormaSpacing.tight) {
                    ColorTokenRow(name: "formaSage", color: .formaSage, hex: "#7D9B76")
                    ColorTokenRow(name: "formaWarmOrange", color: .formaWarmOrange, hex: "#D4864A")
                    ColorTokenRow(name: "formaMutedBlue", color: .formaMutedBlue, hex: "#6B8BA4")
                }
            }

            // Semantic Colors
            GroupBox("Semantic Colors") {
                VStack(spacing: FormaSpacing.tight) {
                    ColorTokenRow(name: "formaLabel", color: .formaLabel, hex: "Primary text")
                    ColorTokenRow(name: "formaSecondaryLabel", color: .formaSecondaryLabel, hex: "Secondary text")
                    ColorTokenRow(name: "formaTertiaryLabel", color: .formaTertiaryLabel, hex: "Tertiary text")
                    ColorTokenRow(name: "formaError", color: .formaError, hex: "Error states")
                }
            }

            // Background Colors
            GroupBox("Background Colors") {
                VStack(spacing: FormaSpacing.tight) {
                    ColorTokenRow(name: "formaBackground", color: .formaBackground, hex: "App background")
                    ColorTokenRow(name: "formaCardBackground", color: .formaCardBackground, hex: "Card surfaces")
                    ColorTokenRow(name: "formaControlBackground", color: .formaControlBackground, hex: "Input fields")
                    ColorTokenRow(name: "formaSeparator", color: .formaSeparator, hex: "Dividers")
                }
            }

            // Code Example
            CodeExample(
                title: "Usage",
                code: """
                // Text colors
                Text("Primary")
                    .foregroundColor(.formaLabel)

                // Background
                .background(Color.formaBackground)

                // Accent
                .fill(Color.formaSteelBlue)
                """
            )
        }
    }
}

private struct ColorTokenRow: View {
    let name: String
    let color: Color
    let hex: String

    var body: some View {
        TokenRow(name: name, value: hex) {
            RoundedRectangle(cornerRadius: FormaRadius.small)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.small)
                        .strokeBorder(Color.formaSeparator, lineWidth: 1)
                )
        }
    }
}

// MARK: - Typography Tokens Section

private struct TypographyTokensSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            CatalogSectionHeader(
                title: "Typography Tokens",
                subtitle: "Font styles based on SF Pro. Use semantic names for consistent hierarchy."
            )

            // Headlines
            GroupBox("Headlines") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    TypographyTokenRow(name: "formaH1", font: .formaH1, size: "32pt Bold")
                    TypographyTokenRow(name: "formaH2", font: .formaH2, size: "24pt Semibold")
                    TypographyTokenRow(name: "formaH3", font: .formaH3, size: "20pt Semibold")
                }
            }

            // Body Text
            GroupBox("Body Text") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    TypographyTokenRow(name: "formaBody", font: .formaBody, size: "14pt Regular")
                    TypographyTokenRow(name: "formaBodyMedium", font: .formaBodyMedium, size: "14pt Medium")
                    TypographyTokenRow(name: "formaBodySemibold", font: .formaBodySemibold, size: "14pt Semibold")
                    TypographyTokenRow(name: "formaBodyBold", font: .formaBodyBold, size: "14pt Bold")
                }
            }

            // Compact Text
            GroupBox("Compact Text") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    TypographyTokenRow(name: "formaCompact", font: .formaCompact, size: "12pt Regular")
                    TypographyTokenRow(name: "formaCompactMedium", font: .formaCompactMedium, size: "12pt Medium")
                    TypographyTokenRow(name: "formaCompactSemibold", font: .formaCompactSemibold, size: "12pt Semibold")
                }
            }

            // Small & Caption
            GroupBox("Small & Caption") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    TypographyTokenRow(name: "formaSmall", font: .formaSmall, size: "11pt Regular")
                    TypographyTokenRow(name: "formaSmallSemibold", font: .formaSmallSemibold, size: "11pt Semibold")
                    TypographyTokenRow(name: "formaCaption", font: .formaCaption, size: "10pt Regular")
                    TypographyTokenRow(name: "formaCaptionSemibold", font: .formaCaptionSemibold, size: "10pt Semibold")
                }
            }

            // Special
            GroupBox("Special") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    TypographyTokenRow(name: "formaMono", font: .formaMono, size: "12pt Mono")
                    TypographyTokenRow(name: "formaPrimaryButton", font: .formaPrimaryButton, size: "14pt Semibold")
                    TypographyTokenRow(name: "formaSecondaryButton", font: .formaSecondaryButton, size: "14pt Medium")
                }
            }

            CodeExample(
                title: "Usage",
                code: """
                // Direct font application
                Text("Headline")
                    .font(.formaH2)

                // Style modifiers
                Text("Body text")
                    .formaBodyStyle()

                // With color
                Text("Secondary")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
                """
            )
        }
    }
}

private struct TypographyTokenRow: View {
    let name: String
    let font: Font
    let size: String

    var body: some View {
        HStack {
            Text("The quick brown fox")
                .font(font)
                .foregroundColor(.formaObsidian)
                .frame(width: 200, alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(name)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaObsidian)

                Text(size)
                    .font(.formaMono)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Button(action: { copyToClipboard(".\(name)") }) {
                Image(systemName: "doc.on.doc")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .buttonStyle(.plain)
            .help("Copy token")
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaControlBackground)
        .cornerRadius(FormaRadius.control)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Spacing & Radius Section

private struct SpacingRadiusSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            CatalogSectionHeader(
                title: "Spacing & Radius",
                subtitle: "Consistent spacing based on 8pt grid. Use tokens for predictable layouts."
            )

            // Spacing
            GroupBox("Spacing (FormaSpacing)") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    SpacingTokenRow(name: "tight", value: 4)
                    SpacingTokenRow(name: "standard", value: 8)
                    SpacingTokenRow(name: "large", value: 16)
                    SpacingTokenRow(name: "generous", value: 24)
                    SpacingTokenRow(name: "extraLarge", value: 32)
                    SpacingTokenRow(name: "huge", value: 48)
                }
            }

            // Corner Radius
            GroupBox("Corner Radius (FormaRadius)") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    RadiusTokenRow(name: "none", value: 0)
                    RadiusTokenRow(name: "micro", value: 4)
                    RadiusTokenRow(name: "small", value: 6)
                    RadiusTokenRow(name: "control", value: 8)
                    RadiusTokenRow(name: "card", value: 12)
                    RadiusTokenRow(name: "large", value: 16)
                    RadiusTokenRow(name: "pill", value: 999)
                }
            }

            CodeExample(
                title: "Usage",
                code: """
                // Spacing
                .padding(FormaSpacing.large)
                .spacing(FormaSpacing.standard)

                // Corner Radius
                .cornerRadius(FormaRadius.card)
                RoundedRectangle(cornerRadius: FormaRadius.control)

                // Clip shape (preferred)
                .clipShape(RoundedRectangle(
                    cornerRadius: FormaRadius.card,
                    style: .continuous
                ))
                """
            )
        }
    }
}

private struct SpacingTokenRow: View {
    let name: String
    let value: CGFloat

    var body: some View {
        HStack(spacing: FormaSpacing.large) {
            Rectangle()
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay))
                .frame(width: value, height: 24)
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.formaSteelBlue, lineWidth: 1)
                )

            Text("FormaSpacing.\(name)")
                .font(.formaBodySemibold)
                .foregroundColor(.formaObsidian)

            Spacer()

            Text("\(Int(value))pt")
                .font(.formaMono)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaControlBackground)
        .cornerRadius(FormaRadius.control)
    }
}

private struct RadiusTokenRow: View {
    let name: String
    let value: CGFloat

    var body: some View {
        HStack(spacing: FormaSpacing.large) {
            RoundedRectangle(cornerRadius: value, style: .continuous)
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay))
                .frame(width: 48, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: value, style: .continuous)
                        .strokeBorder(Color.formaSteelBlue, lineWidth: 1)
                )

            Text("FormaRadius.\(name)")
                .font(.formaBodySemibold)
                .foregroundColor(.formaObsidian)

            Spacer()

            Text(value == 999 ? "Full" : "\(Int(value))pt")
                .font(.formaMono)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaControlBackground)
        .cornerRadius(FormaRadius.control)
    }
}

// MARK: - Button Components Section

private struct ButtonComponentsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            CatalogSectionHeader(
                title: "Button Components",
                subtitle: "Standardized button components with consistent styling and accessibility."
            )

            // Primary Buttons
            GroupBox("FormaPrimaryButton") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Use for primary actions. Blue background, white text.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    HStack(spacing: FormaSpacing.large) {
                        FormaPrimaryButton(title: "Default", action: {})
                            .frame(width: 140)

                        FormaPrimaryButton(title: "With Icon", icon: "sparkles", action: {})
                            .frame(width: 160)

                        FormaPrimaryButton(title: "Disabled", action: {}, isEnabled: false)
                            .frame(width: 140)
                    }
                }
                .padding(FormaSpacing.standard)
            }

            // Secondary Buttons
            GroupBox("FormaSecondaryButton") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Use for secondary actions. Outlined style.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    HStack(spacing: FormaSpacing.large) {
                        FormaSecondaryButton(title: "Default", action: {})
                            .frame(width: 140)

                        FormaSecondaryButton(title: "With Icon", icon: "xmark", action: {})
                            .frame(width: 160)

                        FormaSecondaryButton(title: "Disabled", action: {}, isEnabled: false)
                            .frame(width: 140)
                    }
                }
                .padding(FormaSpacing.standard)
            }

            // Legacy Buttons (with icons)
            GroupBox("PrimaryButton / SecondaryButton (Legacy)") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Alternative API with positional icon parameter. Consider using Forma versions.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    HStack(spacing: FormaSpacing.large) {
                        PrimaryButton("Organize All", icon: "sparkles", action: {})
                            .frame(width: 180)

                        SecondaryButton("Skip", icon: "xmark.circle", action: {})
                            .frame(width: 140)
                    }
                }
                .padding(FormaSpacing.standard)
            }

            CodeExample(
                title: "Usage",
                code: """
                // Primary action
                FormaPrimaryButton(
                    title: "Organize Now",
                    icon: "sparkles",  // optional
                    action: { /* handler */ }
                )

                // Secondary action
                FormaSecondaryButton(
                    title: "Cancel",
                    action: { /* handler */ }
                )

                // Disabled state
                FormaPrimaryButton(
                    title: "Submit",
                    action: {},
                    isEnabled: false
                )
                """
            )
        }
    }
}

// MARK: - Card Components Section

private struct CardComponentsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            CatalogSectionHeader(
                title: "Card Components",
                subtitle: "Container components for grouping related content."
            )

            // FormaCard
            GroupBox("FormaCard") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Standard card container with optional selection state.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    HStack(spacing: FormaSpacing.large) {
                        FormaCard {
                            VStack(alignment: .leading) {
                                Text("Default Card")
                                    .font(.formaBodySemibold)
                                Text("Unselected state")
                                    .font(.formaSmall)
                                    .foregroundColor(.formaSecondaryLabel)
                            }
                        }
                        .frame(width: 200)

                        FormaCard(isSelected: true) {
                            VStack(alignment: .leading) {
                                Text("Selected Card")
                                    .font(.formaBodySemibold)
                                Text("With blue border")
                                    .font(.formaSmall)
                                    .foregroundColor(.formaSecondaryLabel)
                            }
                        }
                        .frame(width: 200)
                    }
                }
                .padding(FormaSpacing.standard)
            }

            // FormaListCard
            GroupBox("formaListCard Modifier") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Lightweight card style for list items with hover states.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    VStack(spacing: FormaSpacing.tight) {
                        ListCardExample(label: "Default", isSelected: false, isHovered: false)
                        ListCardExample(label: "Hovered", isSelected: false, isHovered: true)
                        ListCardExample(label: "Selected", isSelected: true, isHovered: false)
                    }
                }
                .padding(FormaSpacing.standard)
            }

            CodeExample(
                title: "Usage",
                code: """
                // Standard card
                FormaCard {
                    Text("Card content")
                }

                // Selected card
                FormaCard(isSelected: true) {
                    Text("Selected content")
                }

                // List card modifier
                HStack { /* row content */ }
                    .formaListCard(
                        isSelected: isSelected,
                        isHovered: isHovered
                    )
                """
            )
        }
    }
}

private struct ListCardExample: View {
    let label: String
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.formaBody)
            Spacer()
            Text(isSelected ? "Selected" : (isHovered ? "Hovered" : "Default"))
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(FormaSpacing.standard)
        .formaListCard(isSelected: isSelected, isHovered: isHovered)
    }
}

// MARK: - Control Components Section

private struct ControlComponentsSection: View {
    @State private var progress: Double = 0.6
    @State private var toggleValue = true

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            CatalogSectionHeader(
                title: "Control Components",
                subtitle: "Form controls and indicators styled for Forma."
            )

            // Progress Bar
            GroupBox("FormaProgressBar") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Minimal progress indicator for loading states.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    VStack(spacing: FormaSpacing.standard) {
                        HStack {
                            Text("0%")
                                .font(.formaSmall)
                            FormaProgressBar(progress: 0)
                            Text("Empty")
                                .font(.formaSmall)
                                .foregroundColor(.formaSecondaryLabel)
                        }

                        HStack {
                            Text("60%")
                                .font(.formaSmall)
                            FormaProgressBar(progress: 0.6)
                            Text("Partial")
                                .font(.formaSmall)
                                .foregroundColor(.formaSecondaryLabel)
                        }

                        HStack {
                            Text("100%")
                                .font(.formaSmall)
                            FormaProgressBar(progress: 1.0)
                            Text("Complete")
                                .font(.formaSmall)
                                .foregroundColor(.formaSecondaryLabel)
                        }
                    }
                }
                .padding(FormaSpacing.standard)
            }

            // File Badge
            GroupBox("FormaFileBadge") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Pill-shaped count badge for file counts.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    HStack(spacing: FormaSpacing.large) {
                        FormaFileBadge(count: 3)
                        FormaFileBadge(count: 12)
                        FormaFileBadge(count: 99)
                    }
                }
                .padding(FormaSpacing.standard)
            }

            // Success Indicator
            GroupBox("FormaSuccessIndicator") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Large checkmark for completion states.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    FormaSuccessIndicator()
                }
                .padding(FormaSpacing.standard)
            }

            // Empty State
            GroupBox("FormaEmptyState") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Placeholder for empty content areas.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    FormaEmptyState(
                        title: "No Files Found",
                        message: "Your scanned folders are empty.",
                        actionTitle: "Scan Now",
                        action: {}
                    )
                    .frame(height: 250)
                }
                .padding(FormaSpacing.standard)
            }

            CodeExample(
                title: "Usage",
                code: """
                // Progress
                FormaProgressBar(progress: 0.6)

                // Badge
                FormaFileBadge(count: 12)

                // Empty state with action
                FormaEmptyState(
                    title: "No Rules Yet",
                    message: "Create your first rule.",
                    actionTitle: "Create Rule",
                    action: { /* handler */ }
                )
                """
            )
        }
    }
}

// MARK: - Usage Examples Section

private struct UsageExamplesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            CatalogSectionHeader(
                title: "Usage Examples",
                subtitle: "Common patterns and best practices for using the Forma design system."
            )

            // File Row Example
            GroupBox("File Row Pattern") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Common layout for file list items.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    CodeExample(
                        title: "Implementation",
                        code: """
                        HStack(spacing: FormaSpacing.standard) {
                            // Icon
                            Image(systemName: "doc.fill")
                                .font(.formaBody)
                                .foregroundColor(.formaSteelBlue)
                                .frame(width: 32, height: 32)
                                .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                                .cornerRadius(FormaRadius.small)

                            // Content
                            VStack(alignment: .leading, spacing: 2) {
                                Text("document.pdf")
                                    .font(.formaBodyMedium)
                                    .foregroundColor(.formaLabel)

                                Text("2.4 MB")
                                    .font(.formaSmall)
                                    .foregroundColor(.formaSecondaryLabel)
                            }

                            Spacer()

                            // Action
                            Image(systemName: "chevron.right")
                                .font(.formaCompact)
                                .foregroundColor(.formaTertiaryLabel)
                        }
                        .padding(FormaSpacing.standard)
                        .background(Color.formaControlBackground)
                        .cornerRadius(FormaRadius.card)
                        """
                    )
                }
                .padding(FormaSpacing.standard)
            }

            // Section Header Pattern
            GroupBox("Section Header Pattern") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Consistent section headers throughout the app.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    CodeExample(
                        title: "Implementation",
                        code: """
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            Text("SECTION TITLE")
                                .font(.formaCaptionSemibold)
                                .tracking(0.5)
                                .foregroundColor(.formaSecondaryLabel)

                            // Section content...
                        }
                        """
                    )
                }
                .padding(FormaSpacing.standard)
            }

            // Action Bar Pattern
            GroupBox("Action Bar Pattern") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Floating action bars with pill-shaped containers.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)

                    CodeExample(
                        title: "Implementation",
                        code: """
                        HStack(spacing: FormaSpacing.standard) {
                            FormaPrimaryButton(
                                title: "Accept All",
                                icon: "checkmark.circle.fill",
                                action: {}
                            )

                            FormaSecondaryButton(
                                title: "Skip",
                                action: {}
                            )
                        }
                        .padding(FormaSpacing.large)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(
                            cornerRadius: FormaRadius.pill,
                            style: .continuous
                        ))
                        .formaShadow(.floating)
                        """
                    )
                }
                .padding(FormaSpacing.standard)
            }

            // Best Practices
            GroupBox("Best Practices") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    BestPracticeRow(
                        icon: "checkmark.circle.fill",
                        color: .formaSage,
                        title: "Use semantic tokens",
                        description: "Always use .formaLabel instead of .black or hardcoded colors."
                    )

                    BestPracticeRow(
                        icon: "checkmark.circle.fill",
                        color: .formaSage,
                        title: "Use .continuous corners",
                        description: "Apple-style smooth corners: RoundedRectangle(cornerRadius: r, style: .continuous)"
                    )

                    BestPracticeRow(
                        icon: "checkmark.circle.fill",
                        color: .formaSage,
                        title: "Respect accessibility",
                        description: "Check @Environment(\\.accessibilityReduceMotion) before animations."
                    )

                    BestPracticeRow(
                        icon: "xmark.circle.fill",
                        color: .formaError,
                        title: "Avoid inline fonts",
                        description: "Never use system fonts directly. Use Forma typography tokens."
                    )

                    BestPracticeRow(
                        icon: "xmark.circle.fill",
                        color: .formaError,
                        title: "Avoid hardcoded spacing",
                        description: "Use FormaSpacing tokens instead of magic numbers."
                    )
                }
                .padding(FormaSpacing.standard)
            }
        }
    }
}

private struct BestPracticeRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: FormaSpacing.standard) {
            Image(systemName: icon)
                .font(.formaBody)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaObsidian)

                Text(description)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
            }
        }
    }
}

// MARK: - Code Example View

private struct CodeExample: View {
    let title: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack {
                Text(title)
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaSecondaryLabel)

                Spacer()

                Button(action: { copyToClipboard(code) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.formaMono)
                    .foregroundColor(.formaObsidian)
                    .padding(FormaSpacing.standard)
            }
            .background(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
            .cornerRadius(FormaRadius.control)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Preview

#Preview("Design System Catalog") {
    FormaDesignSystemView()
}

#Preview("Colors Only") {
    ScrollView {
        ColorTokensSection()
            .padding()
    }
    .frame(width: 600, height: 800)
}

#Preview("Typography Only") {
    ScrollView {
        TypographyTokensSection()
            .padding()
    }
    .frame(width: 600, height: 800)
}
