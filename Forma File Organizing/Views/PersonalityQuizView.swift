import SwiftUI

/// Interactive personality quiz to determine user's organization style.
///
/// Uses scenario-based questions to map user behavior to organization preferences,
/// allowing Forma to suggest appropriate templates and customize the experience.
struct PersonalityQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentQuestion = 0
    @State private var answers: [Int] = []
    @State private var showResult = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let onComplete: (OrganizationPersonality) -> Void
    var onBack: (() -> Void)? = nil
    var showStepIndicator: Bool = true
    
    private let questions = [
        Question(
            id: 0,
            text: "When you can't find a file, what do you do?",
            emoji: "🔍",
            options: [
                Option(text: "Scan Desktop or Downloads visually", icon: "eyes", description: "I look through visible files"),
                Option(text: "Check Recent Files or use Search", icon: "magnifyingglass", description: "I use system tools"),
                Option(text: "Navigate through my folder structure", icon: "folder.fill", description: "I know where things are")
            ]
        ),
        Question(
            id: 1,
            text: "Your Desktop right now is...",
            emoji: "💻",
            options: [
                Option(text: "Covered with files I'm working on", icon: "doc.on.doc.fill", description: "Everything visible"),
                Option(text: "Has a few shortcuts, rest in folders", icon: "square.grid.2x2", description: "Mostly organized"),
                Option(text: "Empty, everything is organized away", icon: "sparkles", description: "Clean and minimal")
            ]
        ),
        Question(
            id: 2,
            text: "When you organize work, you think in terms of...",
            emoji: "🎯",
            options: [
                Option(text: "Projects and clients", icon: "person.2.fill", description: "Who and what"),
                Option(text: "Weeks, months, quarters", icon: "calendar", description: "When"),
                Option(text: "Categories and topics", icon: "square.grid.2x2", description: "Type and subject")
            ]
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if showResult {
                resultView
            } else {
                quizContent
            }
        }
        .frame(width: 650, height: 720)
        .background(Color.formaBackground)
    }
    
    // MARK: - Quiz Content
    
    private var quizContent: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.top, FormaSpacing.large)
                .padding(.horizontal, FormaSpacing.huge)
            
            // Progress
            progressBar
                .padding(.horizontal, FormaSpacing.huge)
                .padding(.top, FormaSpacing.large)
            
            // Question
            ScrollView {
                VStack(spacing: FormaSpacing.generous) {
                    questionCard
                    
                    answerOptions
                }
                .padding(.horizontal, FormaSpacing.huge)
                .padding(.vertical, FormaSpacing.huge)
            }
            
            // Navigation
            navigationButtons
                .padding(.horizontal, FormaSpacing.huge)
                .padding(.vertical, FormaSpacing.generous)
        }
    }
    
    private var header: some View {
        VStack(spacing: FormaSpacing.standard) {
            // Step indicator for onboarding flow (only when shown standalone)
            if showStepIndicator {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.formaSage)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.formaSteelBlue)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay), lineWidth: 2)
                                .frame(width: 16, height: 16)
                        )
                }
                .padding(.bottom, FormaSpacing.standard)
            }

            Text(questions[currentQuestion].emoji)
                .font(.formaIcon)

            Text("Question \(currentQuestion + 1) of \(questions.count)")
                .font(.formaCaption)
                .foregroundColor(.formaSecondaryLabel)
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                    .fill(Color.formaObsidian.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                    .frame(height: 6)
                
                // Progress
                RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.formaSteelBlue, Color.formaSage],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 6)
    }
    
    private var questionCard: some View {
        Text(questions[currentQuestion].text)
            .font(.formaH1)
            .foregroundColor(.formaLabel)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.top, FormaSpacing.standard)
    }
    
    private var answerOptions: some View {
        VStack(spacing: FormaSpacing.standard) {
            ForEach(Array(questions[currentQuestion].options.enumerated()), id: \.offset) { index, option in
                AnswerCard(
                    option: option,
                    isSelected: answers.count > currentQuestion && answers[currentQuestion] == index,
                    onSelect: {
                        selectAnswer(index)
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Show back button if we're past question 0, OR if we have an onBack handler for step 0
            if currentQuestion > 0 || onBack != nil {
                Button(action: {
                    if currentQuestion > 0 {
                        goBack()
                    } else if let onBack = onBack {
                        onBack()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.formaBodySemibold)
                        Text("Back")
                            .font(.formaBodyLarge)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.formaSecondaryLabel)
                    .padding(.vertical, FormaSpacing.standard - FormaSpacing.micro)
                    .padding(.horizontal, FormaSpacing.large)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                            .strokeBorder(Color.formaSeparator, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Button(action: nextQuestion) {
                HStack(spacing: 8) {
                    Text(currentQuestion == questions.count - 1 ? "See Results" : "Continue")
                        .font(.formaBodyLarge)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.formaBodySemibold)
                }
                .foregroundColor(.formaBoneWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .fill(hasAnsweredCurrent ? Color.formaSteelBlue : Color.formaSecondaryLabel.opacity(Color.FormaOpacity.overlay))
                )
                .shadow(color: hasAnsweredCurrent ? Color.formaSteelBlue.opacity(Color.FormaOpacity.medium) : Color.clear, radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!hasAnsweredCurrent)
        }
    }
    
    // MARK: - Result View
    
    private var resultView: some View {
        let personality = calculatePersonality()
        
        return VStack(spacing: FormaSpacing.huge) {
            Spacer()
            
            // Celebration
            VStack(spacing: FormaSpacing.generous) {
                Text("✨")
                    .font(.formaIconLarge)

                Text("Your Organization Style")
                    .font(.formaH3)
                    .foregroundColor(.formaSecondaryLabel)

                Text(personalityTitle(personality))
                    .font(.formaHero)
                    .foregroundColor(.formaLabel)
                    .multilineTextAlignment(.center)
            }
            
            // Recommended template
            VStack(spacing: FormaSpacing.standard) {
                Text("We recommend")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
                
                TemplatePreviewCard(template: personality.suggestedTemplate)
            }
            .padding(.horizontal, FormaSpacing.huge)
            
            Spacer()
            
            // Continue button
            Button(action: {
                personality.save()
                onComplete(personality)
            }) {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.formaBodyLarge)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.formaBodySemibold)
                }
                .foregroundColor(.formaBoneWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FormaSpacing.standard)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .fill(Color.formaSage)
                )
                .shadow(color: Color.formaSage.opacity(Color.FormaOpacity.medium), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, FormaSpacing.huge)
            .padding(.bottom, FormaSpacing.huge)
        }
    }
    
    // MARK: - Computed Properties
    
    private var progress: Double {
        Double(currentQuestion + 1) / Double(questions.count)
    }
    
    private var hasAnsweredCurrent: Bool {
        answers.count > currentQuestion
    }
    
    // MARK: - Actions
    
    private func selectAnswer(_ index: Int) {
        if answers.count > currentQuestion {
            answers[currentQuestion] = index
        } else {
            answers.append(index)
        }
    }
    
    private func nextQuestion() {
        guard hasAnsweredCurrent else { return }
        
        if currentQuestion < questions.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentQuestion += 1
            }
        } else {
            // Show results
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showResult = true
            }
        }
    }
    
    private func goBack() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentQuestion = max(0, currentQuestion - 1)
        }
    }
    
    // MARK: - Personality Calculation
    
    private func calculatePersonality() -> OrganizationPersonality {
        guard answers.count == questions.count else {
            return .default
        }
        
        // Q1: Finding files → Thinking style (organization style comes from Q2)
        let q1 = answers[0]
        let thinkingStyle: OrganizationPersonality.ThinkingStyle = q1 == 2 ? .hierarchical : .visual
        
        // Q2: Desktop state → Organization style (primary determinant)
        let q2 = answers[1]
        let organizationStyle: OrganizationPersonality.OrganizationStyle = q2 == 0 ? .piler : .filer
        
        // Q3: Mental model
        let q3 = answers[2]
        let mentalModel: OrganizationPersonality.MentalModel = 
            q3 == 0 ? .projectBased : (q3 == 1 ? .timeBased : .topicBased)
        
        return OrganizationPersonality(
            organizationStyle: organizationStyle,
            thinkingStyle: thinkingStyle,
            mentalModel: mentalModel
        )
    }
    
    private func personalityTitle(_ personality: OrganizationPersonality) -> String {
        switch (personality.organizationStyle, personality.thinkingStyle) {
        case (.piler, .visual):
            return "Visual Organizer"
        case (.piler, .hierarchical):
            return "Flexible Organizer"
        case (.filer, .visual):
            return "Structured Organizer"
        case (.filer, .hierarchical):
            return "Systematic Organizer"
        }
    }
}

// MARK: - Supporting Types

struct Question {
    let id: Int
    let text: String
    let emoji: String
    let options: [Option]
}

struct Option {
    let text: String
    let icon: String
    let description: String
}

// MARK: - Answer Card

struct AnswerCard: View {
    let option: Option
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FormaSpacing.large) {
                // Icon
                Image(systemName: option.icon)
                    .font(.formaH1)
                    .foregroundColor(isSelected ? .formaSteelBlue : .formaSecondaryLabel)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                    ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
                                    : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 2)
                            )
                    )

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.text)
                        .font(.formaBodyLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(.formaLabel)

                    Text(option.description)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.formaH1)
                        .foregroundColor(.formaSteelBlue)
                }
            }
            .padding(FormaSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle)
                            : (isHovered
                                ? Color.formaBoneWhite.opacity(Color.FormaOpacity.prominent)
                                : Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.formaSteelBlue
                            : (isHovered ? Color.formaObsidian.opacity(Color.FormaOpacity.light) : Color.formaObsidian.opacity(Color.FormaOpacity.subtle)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected
                    ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
                    : Color.formaObsidian.opacity(Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle),
                radius: 4,
                x: 0,
                y: 2
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Template Preview Card

struct TemplatePreviewCard: View {
    let template: OrganizationTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: template.iconName)
                    .font(.formaH1)
                    .foregroundColor(.formaSteelBlue)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.displayName)
                        .font(.formaH3)
                        .foregroundColor(.formaLabel)
                    
                    Text(template.description)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.ultraSubtle * 3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.medium), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    PersonalityQuizView { personality in
        Log.debug("Personality quiz completed with personality: \(personality)", category: .analytics)
    }
}
