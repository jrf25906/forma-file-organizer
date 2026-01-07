import SwiftUI

/// A treemap visualization for storage breakdown.
struct TreemapChart: View {
    let rootNode: TreemapNode
    var onNodeTap: ((TreemapNode) -> Void)?

    @State private var selectedNode: TreemapNode?

    var body: some View {
        GeometryReader { geometry in
            let rects = computeTreemapLayout(
                node: rootNode,
                rect: CGRect(origin: .zero, size: geometry.size)
            )

            ZStack(alignment: .topLeading) {
                ForEach(rects) { item in
                    TreemapCell(
                        node: item.node,
                        rect: item.rect,
                        isSelected: selectedNode?.id == item.node.id,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedNode?.id == item.node.id {
                                    selectedNode = nil
                                } else {
                                    selectedNode = item.node
                                    onNodeTap?(item.node)
                                }
                            }
                        }
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
    }

    /// Compute squarified treemap layout.
    private func computeTreemapLayout(node: TreemapNode, rect: CGRect) -> [TreemapLayoutItem] {
        guard !node.children.isEmpty else {
            // Leaf node
            return [TreemapLayoutItem(node: node, rect: rect)]
        }

        // Sort children by size (descending) for better squarification
        let sortedChildren = node.children.sorted { $0.bytes > $1.bytes }
        let totalBytes = Double(max(1, sortedChildren.map(\.bytes).reduce(0, +)))

        var results: [TreemapLayoutItem] = []
        var remainingRect = rect
        var remainingChildren = sortedChildren

        while !remainingChildren.isEmpty {
            // Squarified layout: process rows
            let (row, remaining) = squarify(
                children: remainingChildren,
                totalBytes: totalBytes,
                rect: remainingRect
            )

            // Layout the row
            let rowResults = layoutRow(row: row, totalBytes: totalBytes, rect: remainingRect)
            results.append(contentsOf: rowResults.flatMap { item in
                // Recursively layout children
                computeTreemapLayout(node: item.node, rect: item.rect)
            })

            // Update remaining rect
            let rowBytes = Double(row.map(\.bytes).reduce(0, +))
            let rowRatio = rowBytes / totalBytes

            if remainingRect.width > remainingRect.height {
                let rowWidth = remainingRect.width * rowRatio
                remainingRect = CGRect(
                    x: remainingRect.minX + rowWidth,
                    y: remainingRect.minY,
                    width: remainingRect.width - rowWidth,
                    height: remainingRect.height
                )
            } else {
                let rowHeight = remainingRect.height * rowRatio
                remainingRect = CGRect(
                    x: remainingRect.minX,
                    y: remainingRect.minY + rowHeight,
                    width: remainingRect.width,
                    height: remainingRect.height - rowHeight
                )
            }

            remainingChildren = remaining
        }

        return results
    }

    /// Squarify algorithm: determine the best row of children.
    private func squarify(
        children: [TreemapNode],
        totalBytes: Double,
        rect: CGRect
    ) -> (row: [TreemapNode], remaining: [TreemapNode]) {
        guard let first = children.first else {
            return ([], [])
        }

        var row = [first]
        var remaining = Array(children.dropFirst())
        var currentWorst = worstAspectRatio(row: row, totalBytes: totalBytes, rect: rect)

        while let next = remaining.first {
            let testRow = row + [next]
            let testWorst = worstAspectRatio(row: testRow, totalBytes: totalBytes, rect: rect)

            if testWorst <= currentWorst {
                row = testRow
                remaining = Array(remaining.dropFirst())
                currentWorst = testWorst
            } else {
                break
            }
        }

        return (row, remaining)
    }

    /// Calculate worst aspect ratio in a row.
    private func worstAspectRatio(row: [TreemapNode], totalBytes: Double, rect: CGRect) -> Double {
        guard !row.isEmpty else { return .infinity }

        let rowBytes = Double(row.map(\.bytes).reduce(0, +))
        let rowRatio = rowBytes / totalBytes

        let isHorizontal = rect.width > rect.height
        let rowSize = isHorizontal ? rect.width * rowRatio : rect.height * rowRatio
        let crossSize = isHorizontal ? rect.height : rect.width

        var worst = 0.0

        for node in row {
            let nodeRatio = Double(node.bytes) / rowBytes
            let nodeSize = crossSize * nodeRatio
            let aspect = max(rowSize / nodeSize, nodeSize / rowSize)
            worst = max(worst, aspect)
        }

        return worst
    }

    /// Layout a row of nodes.
    private func layoutRow(
        row: [TreemapNode],
        totalBytes: Double,
        rect: CGRect
    ) -> [TreemapLayoutItem] {
        guard !row.isEmpty else { return [] }

        let rowBytes = Double(row.map(\.bytes).reduce(0, +))
        let rowRatio = rowBytes / totalBytes

        let isHorizontal = rect.width > rect.height
        let rowSize = isHorizontal ? rect.width * rowRatio : rect.height * rowRatio

        var results: [TreemapLayoutItem] = []
        var offset: CGFloat = 0

        for node in row {
            let nodeRatio = Double(node.bytes) / rowBytes
            let nodeSize = (isHorizontal ? rect.height : rect.width) * nodeRatio

            let nodeRect: CGRect
            if isHorizontal {
                nodeRect = CGRect(
                    x: rect.minX,
                    y: rect.minY + offset,
                    width: rowSize,
                    height: nodeSize
                )
            } else {
                nodeRect = CGRect(
                    x: rect.minX + offset,
                    y: rect.minY,
                    width: nodeSize,
                    height: rowSize
                )
            }

            results.append(TreemapLayoutItem(node: node, rect: nodeRect))
            offset += nodeSize
        }

        return results
    }
}

// MARK: - Layout Item

private struct TreemapLayoutItem: Identifiable {
    let id = UUID()
    let node: TreemapNode
    let rect: CGRect
}

// MARK: - Treemap Cell

private struct TreemapCell: View {
    let node: TreemapNode
    let rect: CGRect
    let isSelected: Bool
    let onTap: () -> Void

    private var backgroundColor: Color {
        if let category = node.category {
            return category.color.opacity(0.6)
        }
        return Color.formaSteelBlue.opacity(0.4)
    }

    private var showLabel: Bool {
        // Only show label if cell is large enough
        rect.width > 60 && rect.height > 40
    }

    private var showSize: Bool {
        rect.width > 80 && rect.height > 50
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.formaBoneWhite.opacity(0.3), lineWidth: 1)
                    )

                if node.isLeaf {
                    VStack(spacing: 2) {
                        if showLabel {
                            Text(node.label)
                                .font(.formaSmallSemibold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }

                        if showSize {
                            Text(node.formattedSize)
                                .font(.formaMicro)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: rect.width - 2, height: rect.height - 2)
        .position(x: rect.midX, y: rect.midY)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(
            color: isSelected ? Color.black.opacity(0.2) : Color.clear,
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Preview

#Preview("Treemap Chart") {
    let sampleTree = TreemapNode(
        label: "Storage",
        bytes: 50_000_000_000,
        children: [
            TreemapNode(label: "Videos", bytes: 20_000_000_000, category: .videos),
            TreemapNode(
                label: "Documents",
                bytes: 15_000_000_000,
                children: [
                    TreemapNode(label: "ProjectA.pdf", bytes: 5_000_000_000, category: .documents),
                    TreemapNode(label: "Other Documents", bytes: 10_000_000_000, category: .documents)
                ],
                category: .documents
            ),
            TreemapNode(label: "Images", bytes: 10_000_000_000, category: .images),
            TreemapNode(label: "Archives", bytes: 3_000_000_000, category: .archives),
            TreemapNode(label: "Other", bytes: 2_000_000_000, category: .all)
        ]
    )

    VStack(alignment: .leading) {
        Text("Storage Breakdown")
            .font(.formaH2)
            .foregroundColor(.formaObsidian)

        TreemapChart(rootNode: sampleTree) { node in
            print("Tapped: \(node.label)")
        }
        .frame(height: 300)
    }
    .padding()
    .background(Color.formaBoneWhite)
}
