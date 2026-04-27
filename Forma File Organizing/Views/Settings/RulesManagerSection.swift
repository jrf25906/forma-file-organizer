import SwiftUI
import SwiftData

struct RulesManagerSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var rules: [Rule]

    private var sortedRules: [Rule] {
        visibleRules.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @State private var showingEditor = false
    @State private var editingRule: Rule?
    @State private var pendingDeletionRuleIDs: Set<UUID> = []
    @Namespace private var ruleButtonNamespace
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var visibleRules: [Rule] {
        rules.filter { !pendingDeletionRuleIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            HStack(alignment: .top, spacing: FormaSpacing.large) {
                SettingsPageHeader(
                    "Organization Rules",
                    subtitle: "Create and manage rules that organize matching files automatically."
                )
                Spacer()

                Button(action: {
                    editingRule = nil
                    withAnimation(reduceMotion ? .linear(duration: 0.12) : FormaAnimation.quickEnter) {
                        showingEditor = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.formaBodySemibold)
                        Text("Add Rule")
                            .font(.formaBodyBold)
                    }
                    .foregroundColor(.formaBoneWhite)
                    .padding(.horizontal, FormaSpacing.large)
                    .padding(.vertical, FormaSpacing.tight)
                }
                .buttonStyle(.plain)
                .background(Color.formaSteelBlue)
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.formaObsidian.opacity(0.24)
                        : Color.formaObsidian.opacity(Color.FormaOpacity.light),
                    radius: 3,
                    x: 0,
                    y: 1
                )
                .matchedGeometryEffect(id: "ruleButton", in: ruleButtonNamespace, isSource: !showingEditor)
                .hoverLift(scale: 1.03, shadowRadius: 8)
            }
            .padding(.top, FormaSpacing.standard)

            if sortedRules.isEmpty {
                FormaEmptyState(
                    title: "No Rules Yet",
                    message: "Create your first rule to automatically organize files.",
                    actionTitle: "Create Rule",
                    action: {
                        editingRule = nil
                        showingEditor = true
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: FormaSpacing.standard) {
                        ForEach(sortedRules) { rule in
                            ruleCard(for: rule)
                        }
                    }
                    .padding(.bottom, FormaSpacing.generous)
                }
            }
        }
        .background(Color.clear)
        .onChange(of: rules.map(\.id)) { _, remainingRuleIDs in
            pendingDeletionRuleIDs.formIntersection(Set(remainingRuleIDs))
        }
        .sheet(isPresented: $showingEditor) {
            RuleEditorView(rule: editingRule, buttonNamespace: editingRule == nil ? ruleButtonNamespace : nil)
        }
    }

    private func ruleCard(for rule: Rule) -> some View {
        let snapshot = RuleManagementCard.Snapshot(rule: rule)

        return RuleManagementCard(
            snapshot: snapshot,
            onEdit: {
                guard let liveRule = liveRule(withID: snapshot.id) else { return }
                editingRule = liveRule
                showingEditor = true
            },
            onDelete: {
                deleteRule(id: snapshot.id, fallbackName: snapshot.name)
            },
            onToggle: {
                toggleRule(id: snapshot.id)
            }
        )
    }

    private func liveRule(withID id: UUID) -> Rule? {
        rules.first { $0.id == id }
    }

    private func toggleRule(id: UUID) {
        guard let rule = liveRule(withID: id) else { return }
        rule.isEnabled.toggle()
        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.updateRule(rule)
        } catch {
            Log.error("RulesManagerSection: Failed to toggle rule '\(rule.name)' - \(error.localizedDescription)", category: .analytics)
            rule.isEnabled.toggle() // Revert on failure
        }
    }

    private func deleteRule(id: UUID, fallbackName: String) {
        guard let rule = liveRule(withID: id) else { return }

        pendingDeletionRuleIDs.insert(id)
        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.deleteRule(rule)
        } catch {
            pendingDeletionRuleIDs.remove(id)
            Log.error("RulesManagerSection: Failed to delete rule '\(fallbackName)' - \(error.localizedDescription)", category: .analytics)
        }
    }
}
