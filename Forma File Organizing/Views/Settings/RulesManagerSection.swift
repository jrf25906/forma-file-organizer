import SwiftUI
import SwiftData

struct RulesManagerSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [Rule]

    private var sortedRules: [Rule] {
        rules.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @State private var showingEditor = false
    @State private var editingRule: Rule?
    @Namespace private var ruleButtonNamespace
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Organization Rules")
                    .font(.formaH2)
                    .foregroundColor(.formaObsidian)
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
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.medium), radius: 4, x: 0, y: 2)
                .matchedGeometryEffect(id: "ruleButton", in: ruleButtonNamespace, isSource: !showingEditor)
                .hoverLift(scale: 1.03, shadowRadius: 8)
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.top, FormaSpacing.generous)

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
                            RuleManagementCard(
                                rule: rule,
                                onEdit: {
                                    editingRule = rule
                                    showingEditor = true
                                },
                                onDelete: {
                                    deleteRule(rule)
                                },
                                onToggle: {
                                    toggleRule(rule)
                                }
                            )
                        }
                    }
                    .padding(FormaSpacing.generous)
                }
            }
        }
        .background(Color.formaBoneWhite)
        .sheet(isPresented: $showingEditor) {
            RuleEditorView(rule: editingRule, buttonNamespace: editingRule == nil ? ruleButtonNamespace : nil)
        }
    }

    private func toggleRule(_ rule: Rule) {
        rule.isEnabled.toggle()
        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.updateRule(rule)
        } catch {
            Log.error("RulesManagerSection: Failed to toggle rule '\(rule.name)' - \(error.localizedDescription)", category: .analytics)
            rule.isEnabled.toggle() // Revert on failure
        }
    }

    private func deleteRule(_ rule: Rule) {
        do {
            let ruleService = RuleService(modelContext: modelContext)
            try ruleService.deleteRule(rule)
        } catch {
            Log.error("RulesManagerSection: Failed to delete rule '\(rule.name)' - \(error.localizedDescription)", category: .analytics)
        }
    }
}
