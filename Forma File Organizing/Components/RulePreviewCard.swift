import SwiftUI

/// Compact, structured preview of a parsed natural-language rule.
/// Shows action, conditions, destination, confidence, and uncertainty.
struct RulePreviewCard: View {
    let parsedRule: NLParsedRule
    var onApplyToEditor: ((NLParsedRule) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Track which conditions the user has chosen to remove in the preview.
    @State private var removedConditionIndices: Set<Int> = []

    private var actionText: String {
        guard let action = parsedRule.primaryAction else { return "No action" }
        switch action {
        case .move: return "Move"
        case .copy: return "Copy"
        case .delete: return "Delete"
        }
    }

    private var confidenceLabel: String {
        switch parsedRule.overallConfidence {
        case 0.75...:
            return "High confidence"
        case 0.5..<0.75:
            return "Medium confidence"
        default:
            return "Low confidence"
        }
    }

    private var confidenceColor: Color {
        switch parsedRule.overallConfidence {
        case 0.75...:
            return .formaSage
        case 0.5..<0.75:
            return .formaSteelBlue
        default:
            return .formaWarmOrange
        }
    }

    private var hasWarnings: Bool {
        parsedRule.issues.contains { $0.severity == .warning }
    }

    private var hasErrors: Bool {
        parsedRule.issues.contains { $0.severity == .error }
    }

    private func label(for condition: RuleCondition) -> String {
        switch condition {
        case .fileExtension(let ext):
            return "." + ext
        case .nameContains(let text):
            return "name contains ‘\(text)’"
        case .nameStartsWith(let text):
            return "name starts with ‘\(text)’"
        case .nameEndsWith(let text):
            return "name ends with ‘\(text)’"
        case .dateOlderThan(let days, let ext):
            if let ext = ext {
                return ".\(ext) older than \(days)d"
            }
            return "older than \(days)d"
        case .sizeLargerThan(let bytes):
            return "> " + ByteSizeFormatterUtil.format(bytes)
        case .dateModifiedOlderThan(let days):
            return "modified > \(days)d ago"
        case .dateAccessedOlderThan(let days):
            return "not opened in \(days)d"
        case .fileKind(let kind):
            return kind.capitalized + " files"
        case .sourceLocation(let location):
            return "from \(location.displayName)"
        case .not(let inner):
            return "NOT " + label(for: inner)
        }
    }

    private var destinationLabel: String {
        guard let dest = parsedRule.destinationPath, !dest.isEmpty else {
            if parsedRule.primaryAction == .delete {
                return "Trash"
            }
            return "No destination"
        }
        return dest
    }

    private var effectiveConditions: [RuleCondition] {
        parsedRule.candidateConditions.enumerated().compactMap { index, condition in
            removedConditionIndices.contains(index) ? nil : condition
        }
    }

    private var canApply: Bool {
        !effectiveConditions.isEmpty && !parsedRule.hasBlockingError && parsedRule.primaryAction != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header: action + confidence
            HStack(spacing: FormaSpacing.tight) {
                HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                    Image(systemName: iconForAction())
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaSteelBlue)
                    Text(actionText)
                        .font(.formaBodyBold)
                        .foregroundColor(.formaLabel)
                }

                Spacer()

                HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 8, height: 8)
                    Text(confidenceLabel)
                        .font(.formaCaption)
                        .foregroundColor(confidenceColor)
                }
                .padding(.horizontal, FormaSpacing.tight)
                .padding(.vertical, FormaSpacing.micro)
                .background(confidenceColor.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                .clipShape(Capsule())
            }

            // Conditions chips
            if !parsedRule.candidateConditions.isEmpty {
                VStack(alignment: .leading, spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                    Text("When file matches:")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)

                    FlexibleChipRow(labels: parsedRule.candidateConditions.enumerated().map { index, condition in
                        (index, label(for: condition))
                    },
                    removedIndices: $removedConditionIndices)
                }
            }

            // Destination row
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: parsedRule.primaryAction == .delete ? "trash" : "folder.fill")
                    .font(.formaSmall)
                    .foregroundColor(parsedRule.primaryAction == .delete ? .formaError : .formaSteelBlue)

                Text(destinationLabel)
                    .font(.formaMono)
                    .foregroundColor(.formaLabel)
                    .lineLimit(1)

                Spacer()
            }
            .padding(FormaSpacing.tight)
            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.ultraSubtle * 3))
            .formaCornerRadius(FormaRadius.control)

            // Issues / Uncertainty
            if hasWarnings || hasErrors {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: hasErrors ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                        .font(.formaSmall)
                        .foregroundColor(hasErrors ? .formaWarmOrange : .formaSteelBlue)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(parsedRule.issues.indices, id: \.self) { idx in
                            let issue = parsedRule.issues[idx]
                            Text(issue.message)
                                .font(.formaCaption)
                                .foregroundColor(.formaSecondaryLabel)
                        }
                    }
                }
                .padding(FormaSpacing.tight)
                .background(Color.formaWarmOrange.opacity(Color.FormaOpacity.subtle))
                .formaCornerRadius(FormaRadius.control)
            }

            // Apply button
            if let onApplyToEditor {
                HStack {
                    Spacer()
                    Button {
                        let modified = NLParsedRule(
                            originalText: parsedRule.originalText,
                            clauses: parsedRule.clauses,
                            timeConstraints: parsedRule.timeConstraints,
                            candidateConditions: effectiveConditions,
                            primaryAction: parsedRule.primaryAction,
                            destinationPath: parsedRule.destinationPath,
                            logicalOperator: parsedRule.logicalOperator,
                            overallConfidence: parsedRule.overallConfidence,
                            issues: parsedRule.issues
                        )
                        onApplyToEditor(modified)
                    } label: {
                        HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Apply to fields")
                        }
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaBoneWhite)
                        .padding(.horizontal, FormaSpacing.large)
                        .padding(.vertical, FormaSpacing.Button.vertical)
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                .fill(canApply ? Color.formaSteelBlue : Color.formaSecondaryLabel)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canApply)
                }
                .padding(.top, FormaSpacing.standard)
            }
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.prominent))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light), lineWidth: 1)
        )
        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 2), radius: 6, x: 0, y: 3)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: parsedRule.overallConfidence)
    }

    private func iconForAction() -> String {
        switch parsedRule.primaryAction {
        case .move?: return "arrow.right.circle.fill"
        case .copy?: return "doc.on.doc.fill"
        case .delete?: return "trash.fill"
        case nil: return "questionmark.circle.fill"
        }
    }
}

/// Simple chip row that wraps onto multiple lines.
/// Each chip is clickable: users can toggle it off to exclude that condition
/// before applying the rule to the editor.
private struct FlexibleChipRow: View {
    let labels: [(index: Int, text: String)]
    @Binding var removedIndices: Set<Int>

    var body: some View {
        FlowLayout(alignment: .leading, spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
            ForEach(labels, id: \.index) { item in
                let isRemoved = removedIndices.contains(item.index)
                Button {
                    if isRemoved {
                        removedIndices.remove(item.index)
                    } else {
                        removedIndices.insert(item.index)
                    }
                } label: {
                    HStack(spacing: FormaSpacing.micro) {
                        Text(item.text)
                            .strikethrough(isRemoved, color: .formaSecondaryLabel)
                        Image(systemName: isRemoved ? "arrow.uturn.backward" : "xmark")
                            .font(.formaMicro)
                            .fontWeight(.semibold)
                    }
                    .font(.formaCaption)
                    .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
                    .padding(.vertical, FormaSpacing.micro)
                    .background(
                        isRemoved
                            ? Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle)
                            : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 3)
                    )
                    .clipShape(Capsule())
                    .foregroundColor(isRemoved ? .formaSecondaryLabel : .formaLabel)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Proper flow layout using the Layout protocol for correct intrinsic sizing.
/// This fixes the clipping issue caused by the old GeometryReader-based approach.
private struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = FormaSpacing.tight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        return result.bounds
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        )
        for row in result.rows {
            let rowXOffset: CGFloat
            switch alignment {
            case .leading:
                rowXOffset = bounds.minX
            case .trailing:
                rowXOffset = bounds.maxX - row.frame.width
            default:
                rowXOffset = bounds.minX + (bounds.width - row.frame.width) / 2
            }
            for item in row.items {
                let x = rowXOffset + item.x
                let y = bounds.minY + row.frame.minY + item.y
                subviews[item.index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            }
        }
    }

    struct FlowResult {
        var bounds: CGSize = .zero
        var rows: [Row] = []

        struct Row {
            var items: [Item] = []
            var frame: CGRect = .zero
        }

        struct Item {
            let index: Int
            let x: CGFloat
            let y: CGFloat
            let size: CGSize
        }

        init(in maxWidth: CGFloat, subviews: Subviews, alignment: HorizontalAlignment, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var currentRowHeight: CGFloat = 0
            var currentRow = Row()

            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)

                // Check if we need to wrap to the next row
                if currentX + size.width > maxWidth && !currentRow.items.isEmpty {
                    // Finalize current row
                    currentRow.frame = CGRect(x: 0, y: currentY, width: currentX - spacing, height: currentRowHeight)
                    rows.append(currentRow)

                    // Start new row
                    currentY += currentRowHeight + spacing
                    currentX = 0
                    currentRowHeight = 0
                    currentRow = Row()
                }

                // Add item to current row
                currentRow.items.append(Item(index: index, x: currentX, y: 0, size: size))
                currentX += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }

            // Finalize last row if it has items
            if !currentRow.items.isEmpty {
                currentRow.frame = CGRect(x: 0, y: currentY, width: currentX - spacing, height: currentRowHeight)
                rows.append(currentRow)
            }

            // Calculate total bounds
            bounds = CGSize(
                width: maxWidth,
                height: rows.isEmpty ? 0 : rows.last!.frame.maxY
            )
        }
    }
}
