import SwiftUI
import AppKit

enum FileIdentityLayout {
    case card
    case list
    case grid

    var titleFont: Font {
        switch self {
        case .card:
            return .system(size: 15, weight: .semibold)
        case .list:
            return .formaBodySemibold
        case .grid:
            return .formaCompactSemibold
        }
    }

    var titleLineLimit: Int {
        switch self {
        case .grid:
            return 2
        case .card, .list:
            return 1
        }
    }

    var verticalSpacing: CGFloat {
        switch self {
        case .card:
            return 5
        case .list:
            return 2
        case .grid:
            return 5
        }
    }

    var titleSpacing: CGFloat {
        switch self {
        case .card, .list:
            return FormaSpacing.tight - 2
        case .grid:
            return FormaSpacing.micro + 1
        }
    }

    var categoryMarkerSize: CGFloat {
        switch self {
        case .card, .list:
            return 7
        case .grid:
            return 5
        }
    }

    var metaDensity: FileMetaStripDensity {
        switch self {
        case .card:
            return .regular
        case .list:
            return .compact
        case .grid:
            return .regular
        }
    }

    var destinationPlacement: FileMetaDestinationPlacement {
        switch self {
        case .list:
            return .inline
        case .card, .grid:
            return .block
        }
    }

    var showsContentSnippet: Bool {
        self == .card
    }

    var headerAlignment: VerticalAlignment {
        switch self {
        case .grid:
            return .top
        case .card, .list:
            return .firstTextBaseline
        }
    }

    var titleMinHeight: CGFloat? {
        switch self {
        case .grid:
            return 34
        case .card, .list:
            return nil
        }
    }
}

extension FileSurfaceStyle {
    static func resolved(
        kind: SurfaceKind,
        isHovered: Bool,
        isSelected: Bool,
        isFocused: Bool,
        activity: ActivityState = .none
    ) -> FileSurfaceStyle {
        resolve(
            .init(
                kind: kind,
                isHovered: isHovered,
                isSelected: isSelected,
                isFocused: isFocused,
                activity: activity
            )
        )
    }
}

struct FileSurfaceBackground: View {
    let style: FileSurfaceStyle

    var body: some View {
        ZStack {
            style.fillColor

            ForEach(Array(style.overlayColors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
    }
}

struct FileSurfaceBorder: View {
    let style: FileSurfaceStyle
    let cornerRadius: CGFloat
    let primaryLineWidth: CGFloat
    var accentLineWidth: CGFloat = 1
    var accentInset: CGFloat = 3
    var innerBorderColor: Color? = nil
    var innerBorderWidth: CGFloat = 0.75
    var innerBorderInset: CGFloat = 1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(style.primaryBorderColor, lineWidth: primaryLineWidth)
            .overlay {
                if let accentBorderColor = style.accentBorderColor {
                    RoundedRectangle(
                        cornerRadius: FormaNestedRadius.inset(cornerRadius, by: accentInset),
                        style: .continuous
                    )
                    .stroke(accentBorderColor, lineWidth: accentLineWidth)
                }
            }
            .overlay {
                if let innerBorderColor {
                    RoundedRectangle(
                        cornerRadius: FormaNestedRadius.inset(cornerRadius, by: innerBorderInset),
                        style: .continuous
                    )
                    .stroke(innerBorderColor, lineWidth: innerBorderWidth)
                }
            }
    }
}

struct FileIdentityBlock: View {
    let file: FileItem
    let layout: FileIdentityLayout
    var searchMatchType: ContentSearchService.MatchType? = nil
    var contentSnippet: String? = nil
    var onSetDestination: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: layout.verticalSpacing) {
            HStack(alignment: layout.headerAlignment, spacing: layout.titleSpacing) {
                FileCategoryMarker(color: file.category.color, size: layout.categoryMarkerSize)
                    .help("Category: \(file.category.displayName)")

                Text(file.name)
                    .font(layout.titleFont)
                    .foregroundStyle(Color.formaLabel)
                    .lineLimit(layout.titleLineLimit)
                    .truncationMode(.middle)
                    .minimumScaleFactor(layout == .grid ? 0.92 : 1.0)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let matchType = searchMatchType {
                    SearchMatchBadge(matchType: matchType)
                }
            }
            .frame(minHeight: layout.titleMinHeight, alignment: .topLeading)

            FileMetaStrip(
                file: file,
                density: layout.metaDensity,
                destinationPlacement: layout.destinationPlacement,
                onSetDestination: onSetDestination
            )

            if layout.showsContentSnippet, let contentSnippet {
                ContentSnippetView(snippet: contentSnippet)
            }
        }
    }
}

private struct FileCategoryMarker: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color.opacity(Color.FormaOpacity.high))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(Color.FormaOpacity.medium + Color.FormaOpacity.subtle), lineWidth: 1)
            )
    }
}

enum FileAccessoryActionsLayout {
    case card
    case compact
    case overlay
}

struct FileAccessoryActions: View {
    let file: FileItem
    let layout: FileAccessoryActionsLayout
    let primaryActionKind: FilePrimaryActionKind
    var showsPrimaryAction: Bool
    var showsOverflowMenu: Bool
    var matchingRules: [Rule] = []
    var availableDestinations: [Destination] = []
    var onPrimaryAction: () -> Void
    var onEditDestination: () -> Void
    var onSkip: () -> Void
    var onQuickLook: () -> Void
    var onCreateRule: (() -> Void)? = nil
    var onApplyRule: ((Rule) -> Void)? = nil
    var onChangeDestination: ((Destination) -> Void)? = nil
    var disablesPrimaryAction: Bool = false
    var disablesEdit: Bool = false
    var disablesSkip: Bool = false

    var body: some View {
        switch layout {
        case .card:
            VStack(alignment: .trailing, spacing: FormaSpacing.micro + 2) {
                if showsPrimaryAction {
                    PrimaryActionButton(
                        label: primaryActionKind.label,
                        icon: primaryActionKind.icon,
                        color: primaryActionKind.color,
                        action: onPrimaryAction
                    )
                    .disabled(disablesPrimaryAction)
                }

                if showsOverflowMenu {
                    overflowMenuLabel(style: .card)
                }
            }
        case .compact:
            HStack(spacing: FormaSpacing.micro) {
                if showsPrimaryAction {
                    compactActionButton(
                        icon: primaryActionKind.compactIcon,
                        foreground: compactPrimaryActionForeground,
                        background: compactPrimaryActionBackground,
                        border: compactPrimaryActionBorder,
                        helpText: primaryActionKind.helpText,
                        action: onPrimaryAction
                    )
                    .disabled(disablesPrimaryAction)
                }

                if showsOverflowMenu {
                    overflowMenuLabel(style: .compact)
                }
            }
        case .overlay:
            HStack(spacing: FormaSpacing.tight) {
                if showsPrimaryAction {
                    compactActionButton(
                        icon: primaryActionKind.compactIcon,
                        foreground: .white,
                        background: Color.white.opacity(Color.FormaOpacity.medium),
                        border: Color.white.opacity(Color.FormaOpacity.overlay + Color.FormaOpacity.subtle),
                        helpText: primaryActionKind.helpText,
                        action: onPrimaryAction
                    )
                    .disabled(disablesPrimaryAction)
                }

                if showsOverflowMenu {
                    overflowMenuLabel(style: .overlay)
                }
            }
        }
    }

    private var compactPrimaryActionForeground: Color {
        if primaryActionKind == .organize {
            return .formaBoneWhite
        }
        return primaryActionKind.color
    }

    private var compactPrimaryActionBackground: Color {
        if primaryActionKind == .organize {
            return .formaSteelBlue
        }
        return primaryActionKind.color.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle)
    }

    private var compactPrimaryActionBorder: Color {
        if primaryActionKind == .organize {
            return .formaSteelBlue.opacity(Color.FormaOpacity.strong)
        }
        return primaryActionKind.color.opacity(Color.FormaOpacity.medium + Color.FormaOpacity.subtle)
    }

    private enum OverflowButtonStyle {
        case card
        case compact
        case overlay
    }

    @ViewBuilder
    private func overflowMenuLabel(style: OverflowButtonStyle) -> some View {
        Menu {
            FileActionMenuContent(
                file: file,
                primaryActionKind: primaryActionKind,
                matchingRules: matchingRules,
                availableDestinations: availableDestinations,
                onPrimaryAction: onPrimaryAction,
                onEditDestination: onEditDestination,
                onSkip: onSkip,
                onQuickLook: onQuickLook,
                onCreateRule: onCreateRule,
                onApplyRule: onApplyRule,
                onChangeDestination: onChangeDestination,
                disablesPrimaryAction: disablesPrimaryAction,
                disablesEdit: disablesEdit,
                disablesSkip: disablesSkip
            )
        } label: {
            switch style {
            case .card:
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis")
                        .font(.formaCompactMedium)
                    Text("More")
                        .font(.formaSmall)
                }
                .foregroundStyle(Color.formaSecondaryLabelHigh)
                .padding(.horizontal, FormaSpacing.tight)
                .padding(.vertical, FormaSpacing.micro + 2)
                .background(
                    FormaChromeSurface(
                        cornerRadius: FormaRadius.pill,
                        fill: Color.formaCardBackground,
                        elevation: .resting
                    )
                )
            case .compact:
                Image(systemName: "ellipsis")
                    .font(.formaCompactMedium)
                    .foregroundStyle(Color.formaSecondaryLabelHigh)
                    .frame(width: 26, height: 26)
                    .background(
                        FormaChromeSurface(
                            cornerRadius: FormaRadius.pill,
                            fill: Color.formaListRowBackground,
                            elevation: .resting
                        )
                    )
            case .overlay:
                Image(systemName: "ellipsis")
                    .font(.formaCompactSemibold)
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 28)
                    .background(
                        FormaChromeSurface(
                            cornerRadius: FormaRadius.pill,
                            fill: Color.white.opacity(0.16),
                            tint: .white,
                            elevation: .raised
                        )
                    )
            }
        }
        .menuStyle(.borderlessButton)
        .help("More Actions")
    }

    private func compactActionButton(
        icon: String,
        foreground: Color,
        background: Color,
        border: Color,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.formaSmallSemibold)
                .foregroundStyle(foreground)
                .frame(width: layout == .overlay ? 28 : 26, height: layout == .overlay ? 28 : 26)
                .background(
                    FormaChromeSurface(
                        cornerRadius: FormaRadius.pill,
                        fill: background,
                        tint: border,
                        elevation: layout == .overlay ? .raised : .resting
                    )
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

struct FileActionMenuContent: View {
    let file: FileItem
    let primaryActionKind: FilePrimaryActionKind
    var matchingRules: [Rule] = []
    var availableDestinations: [Destination] = []
    var onPrimaryAction: () -> Void
    var onEditDestination: () -> Void
    var onSkip: () -> Void
    var onQuickLook: () -> Void
    var onCreateRule: (() -> Void)? = nil
    var onApplyRule: ((Rule) -> Void)? = nil
    var onChangeDestination: ((Destination) -> Void)? = nil
    var disablesPrimaryAction: Bool = false
    var disablesEdit: Bool = false
    var disablesSkip: Bool = false

    private var quickDestinationChoices: [Destination] {
        availableDestinations
            .filter { $0 != file.destination }
    }

    var body: some View {
        Group {
            Button(action: onPrimaryAction) {
                Label(primaryActionKind.label, systemImage: primaryActionKind.icon)
            }
            .disabled(disablesPrimaryAction)

            if let currentDestination = file.destination {
                Divider()

                Label(currentDestination.displayName, systemImage: currentDestination.isTrash ? "trash" : "folder")
                    .foregroundStyle(Color.formaSecondaryLabel)
            }

            if let onChangeDestination, !quickDestinationChoices.isEmpty {
                ForEach(Array(quickDestinationChoices.prefix(6)), id: \.self) { destination in
                    Button(action: { onChangeDestination(destination) }) {
                        Label(destination.displayName, systemImage: destination.isTrash ? "trash" : "folder")
                    }
                }
            }

            Divider()

            Button(action: onEditDestination) {
                Label(file.destination == nil ? "Browse Destination" : "Edit Destination", systemImage: "pencil")
            }
            .disabled(disablesEdit)

            Button(action: onSkip) {
                Label("Skip", systemImage: "forward")
            }
            .disabled(disablesSkip)

            Divider()

            Button(action: onQuickLook) {
                Label("Quick Look", systemImage: "eye")
            }

            if let onCreateRule {
                Divider()

                Button(action: onCreateRule) {
                    Label("Create Rule", systemImage: "plus.circle")
                }
            }

            if let onApplyRule, !matchingRules.isEmpty {
                Divider()

                ForEach(Array(matchingRules.prefix(3)), id: \.id) { rule in
                    Button(action: { onApplyRule(rule) }) {
                        Label(rule.name, systemImage: rule.iconName)
                    }
                }
            }
        }
    }
}

struct FileRowActionConfig {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    static func resolve(
        file: FileItem,
        onOrganize: @escaping (FileItem) -> Void,
        onEditDestination: ((FileItem) -> Void)?,
        onCreateRule: ((FileItem) -> Void)?
    ) -> FileRowActionConfig {
        let kind = FilePrimaryActionKind.resolve(for: file)
        return FileRowActionConfig(
            label: kind.label,
            icon: kind.icon,
            color: kind.color,
            action: {
                switch kind {
                case .organize:
                    onOrganize(file)
                case .review:
                    if let onEditDestination {
                        onEditDestination(file)
                    } else {
                        onOrganize(file)
                    }
                case .setDestination:
                    if let onEditDestination {
                        onEditDestination(file)
                    } else {
                        onCreateRule?(file)
                    }
                }
            }
        )
    }
}

enum FilePrimaryActionKind {
    case organize
    case review
    case setDestination

    static func resolve(for file: FileItem) -> FilePrimaryActionKind {
        guard file.destination != nil else { return .setDestination }
        return file.status == .ready ? .organize : .review
    }

    var label: String {
        switch self {
        case .organize:
            return "Organize"
        case .review:
            return "Review"
        case .setDestination:
            return "Choose Destination"
        }
    }

    var icon: String {
        switch self {
        case .organize:
            return "checkmark.circle.fill"
        case .review:
            return "slider.horizontal.3"
        case .setDestination:
            return "folder.badge.plus"
        }
    }

    var compactIcon: String {
        switch self {
        case .organize:
            return "checkmark"
        case .review:
            return "slider.horizontal.3"
        case .setDestination:
            return "folder.badge.plus"
        }
    }

    var color: Color {
        switch self {
        case .organize:
            return .formaSteelBlue
        case .review:
            return .formaSecondaryLabelHigh
        case .setDestination:
            return .formaWarmOrange
        }
    }

    var helpText: String {
        switch self {
        case .organize:
            return "Organize"
        case .review:
            return "Review suggestion"
        case .setDestination:
            return "Choose destination"
        }
    }
}

struct PrimaryActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.formaSmallSemibold)
                Text(label)
                    .font(.formaSmallSemibold)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                FormaChromeSurface(
                    cornerRadius: FormaRadius.pill,
                    fill: Color.formaCardBackground,
                    tint: color,
                    elevation: isPressed ? .inset : (isHovered ? .raised : .resting)
                )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isPressed)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

struct SearchMatchBadge: View {
    let matchType: ContentSearchService.MatchType

    private var config: (icon: String, label: String, color: Color) {
        switch matchType {
        case .filename:
            return ("textformat", "Name", .formaSteelBlue)
        case .content:
            return ("doc.text.magnifyingglass", "Content", .formaWarmOrange)
        case .both:
            return ("checkmark.circle.fill", "Name + Content", .formaSage)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: config.icon)
                .font(.formaMicro)
            Text(config.label)
                .font(.formaCaptionSemibold)
        }
        .foregroundStyle(config.color)
        .padding(.horizontal, FormaSpacing.tight - (FormaSpacing.micro / 2))
        .padding(.vertical, FormaSpacing.micro / 2)
        .background(config.color.opacity(Color.FormaOpacity.medium))
        .overlay(
            Capsule()
                .strokeBorder(config.color.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

struct ContentSnippetView: View {
    let snippet: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "text.quote")
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabelHigh)

            Text(snippet)
                .font(.formaSmall)
                .foregroundStyle(Color.formaSecondaryLabelHigh)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(Color.formaObsidian.opacity(Color.FormaOpacity.light))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous))
    }
}
