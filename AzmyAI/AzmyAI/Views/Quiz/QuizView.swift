//
//  QuizView.swift
//  AzmyAI
//
//  Quiz interface with multiple question types
//

import SwiftUI

// MARK: - Quiz Container (Sheet)
struct QuizContainerView: View {
    @EnvironmentObject var quizViewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                QuizHeader(
                    title: quizViewModel.currentQuiz?.title ?? "Quiz",
                    progress: quizViewModel.progress,
                    currentQuestion: quizViewModel.currentQuestionIndex + 1,
                    totalQuestions: quizViewModel.totalQuestions,
                    onClose: {
                        dismiss()
                        quizViewModel.closeQuiz()
                    }
                )

                if quizViewModel.isShowingResult {
                    QuizResultView()
                } else {
                    QuizContentView()
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Quiz Header
struct QuizHeader: View {
    let title: String
    let progress: Double
    let currentQuestion: Int
    let totalQuestions: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: AzmySpacing.sm) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(AzmyColors.textTertiary)
                .frame(width: 36, height: 5)
                .padding(.top, AzmySpacing.sm)

            HStack {
                Text(title)
                    .font(AzmyFonts.headline3())
                    .foregroundColor(AzmyColors.textPrimary)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AzmyColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(AzmyColors.backgroundCard)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AzmySpacing.lg)

            HStack {
                Text("\(currentQuestion)")
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textPrimary)
                Text("/ \(totalQuestions)")
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, AzmySpacing.lg)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AzmyColors.backgroundCard)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(AzmyColors.accentBlue)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, AzmySpacing.lg)
        }
        .padding(.bottom, AzmySpacing.md)
    }
}

// MARK: - Quiz Content View
struct QuizContentView: View {
    @EnvironmentObject var quizViewModel: QuizViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Question Content
            ScrollView {
                if let question = quizViewModel.currentQuestion {
                    QuestionView(question: question)
                        .padding(.horizontal, AzmySpacing.lg)
                        .padding(.top, AzmySpacing.xl)
                }
            }

            Spacer()

            // Navigation buttons
            QuizNavigationButtons()
        }
    }
}

// MARK: - Question View (Router)
struct QuestionView: View {
    let question: QuizQuestion
    @EnvironmentObject var quizViewModel: QuizViewModel

    var body: some View {
        VStack(spacing: AzmySpacing.xl) {
            Text(question.text)
                .font(AzmyFonts.headline1())
                .foregroundColor(AzmyColors.textPrimary)
                .multilineTextAlignment(.center)

            questionContent
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        switch question.type {
        case .chips:
            ChipsQuestionView(question: question)
        case .scale:
            ScaleQuestionView(question: question)
        case .bubbles:
            BubblesQuestionView(question: question)
        case .singleChoice:
            SingleChoiceQuestionView(question: question)
        case .multipleChoice:
            MultipleChoiceQuestionView(question: question)
        }
    }
}

// MARK: - Chips Question View
struct ChipsQuestionView: View {
    let question: QuizQuestion
    @EnvironmentObject var quizViewModel: QuizViewModel

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AzmySpacing.sm) {
            ForEach(question.options) { option in
                ChipButton(
                    option: option,
                    isSelected: quizViewModel.isOptionSelected(option)
                ) {
                    quizViewModel.selectOption(option)
                }
            }
        }
    }
}

struct ChipButton: View {
    let option: QuizOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AzmySpacing.sm) {
                Circle()
                    .fill(option.swiftUIColor)
                    .frame(width: 24, height: 24)

                Text(option.text)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(AzmySpacing.md)
            .background(
                isSelected
                    ? AzmyColors.accentBlue.opacity(0.2)
                    : AzmyColors.backgroundCard
            )
            .overlay(
                RoundedRectangle(cornerRadius: AzmyRadius.medium)
                    .stroke(isSelected ? AzmyColors.accentBlue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(AzmyRadius.medium)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scale Question View
struct ScaleQuestionView: View {
    let question: QuizQuestion
    @EnvironmentObject var quizViewModel: QuizViewModel
    @State private var sliderValue: Double = 0.5

    var body: some View {
        VStack(spacing: AzmySpacing.xl) {
            // Left label (first option)
            if let firstOption = question.options.first {
                Text(firstOption.text)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textSecondary)
                    .padding(.horizontal, AzmySpacing.md)
                    .padding(.vertical, AzmySpacing.sm)
                    .background(AzmyColors.backgroundCard)
                    .cornerRadius(AzmyRadius.medium)
            }

            // Scale circles
            HStack(spacing: AzmySpacing.sm) {
                ForEach(0..<7, id: \.self) { index in
                    let value = Double(index) / 6.0
                    let isSelected = abs(sliderValue - value) < 0.1

                    Circle()
                        .fill(isSelected ? AzmyColors.accentBlue : AzmyColors.backgroundCard)
                        .frame(width: circleSize(for: index), height: circleSize(for: index))
                        .overlay(
                            Circle()
                                .stroke(AzmyColors.accentBlue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                sliderValue = value
                                quizViewModel.updateSliderValue(value)
                            }
                        }
                }
            }

            // Labels
            HStack {
                Text("Not At All Like Me")
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)

                Spacer()

                Text("So-so")
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)

                Spacer()

                Text("This is Me 100%")
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)
            }

            // Right label (second option)
            if question.options.count > 1 {
                Text(question.options[1].text)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textSecondary)
                    .padding(.horizontal, AzmySpacing.md)
                    .padding(.vertical, AzmySpacing.sm)
                    .background(AzmyColors.backgroundCard)
                    .cornerRadius(AzmyRadius.medium)
            }
        }
        .onAppear {
            sliderValue = question.sliderValue
        }
    }

    private func circleSize(for index: Int) -> CGFloat {
        let baseSize: CGFloat = 32
        let centerIndex = 3
        let distance = abs(index - centerIndex)
        return baseSize + CGFloat(3 - distance) * 8
    }
}

// MARK: - Bubbles Question View
struct BubblesQuestionView: View {
    let question: QuizQuestion
    @EnvironmentObject var quizViewModel: QuizViewModel

    var body: some View {
        ZStack {
            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                BubbleView(
                    option: option,
                    isSelected: quizViewModel.isOptionSelected(option),
                    position: bubblePosition(for: index, total: question.options.count)
                ) {
                    quizViewModel.selectOption(option)
                }
            }
        }
        .frame(height: 350)
    }

    private func bubblePosition(for index: Int, total: Int) -> CGPoint {
        let positions: [CGPoint] = [
            CGPoint(x: 0.5, y: 0.35),   // center top
            CGPoint(x: 0.15, y: 0.55),  // left
            CGPoint(x: 0.85, y: 0.55),  // right
            CGPoint(x: 0.75, y: 0.2),   // top right
            CGPoint(x: 0.25, y: 0.75),  // bottom left
            CGPoint(x: 0.6, y: 0.8)     // bottom right
        ]
        return positions[index % positions.count]
    }
}

struct BubbleView: View {
    let option: QuizOption
    let isSelected: Bool
    let position: CGPoint
    let action: () -> Void

    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            Button(action: action) {
                Text(option.text)
                    .font(AzmyFonts.bodySmall())
                    .foregroundColor(isSelected ? .white : AzmyColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(AzmySpacing.md)
                    .frame(width: bubbleSize, height: bubbleSize)
                    .background(
                        Circle()
                            .fill(isSelected ? AzmyColors.accentBlue : AzmyColors.backgroundCard)
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? AzmyColors.accentBlue : AzmyColors.separator, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .position(
                x: geometry.size.width * position.x,
                y: geometry.size.height * position.y
            )
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(
                Animation.easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...1)),
                value: isAnimating
            )
        }
        .onAppear {
            isAnimating = true
        }
    }

    private var bubbleSize: CGFloat {
        let textLength = option.text.count
        if textLength > 20 { return 120 }
        if textLength > 10 { return 100 }
        return 80
    }
}

// MARK: - Single Choice Question View
struct SingleChoiceQuestionView: View {
    let question: QuizQuestion
    @EnvironmentObject var quizViewModel: QuizViewModel

    var body: some View {
        VStack(spacing: AzmySpacing.sm) {
            ForEach(question.options) { option in
                ChoiceButton(
                    option: option,
                    isSelected: quizViewModel.isOptionSelected(option),
                    isSingleChoice: true
                ) {
                    quizViewModel.selectOption(option)
                }
            }
        }
    }
}

// MARK: - Multiple Choice Question View
struct MultipleChoiceQuestionView: View {
    let question: QuizQuestion
    @EnvironmentObject var quizViewModel: QuizViewModel

    var body: some View {
        VStack(spacing: AzmySpacing.sm) {
            ForEach(question.options) { option in
                ChoiceButton(
                    option: option,
                    isSelected: quizViewModel.isOptionSelected(option),
                    isSingleChoice: false
                ) {
                    quizViewModel.selectOption(option)
                }
            }
        }
    }
}

struct ChoiceButton: View {
    let option: QuizOption
    let isSelected: Bool
    let isSingleChoice: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AzmySpacing.md) {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? AzmyColors.accentBlue : AzmyColors.textSecondary)
                        .frame(width: 40)
                }

                Text(option.text)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textPrimary)

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AzmyColors.accentBlue : AzmyColors.textTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(AzmyColors.accentBlue)
                            .frame(width: isSingleChoice ? 12 : 16)

                        if !isSingleChoice {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(AzmySpacing.md)
            .background(
                isSelected
                    ? AzmyColors.accentBlue.opacity(0.1)
                    : AzmyColors.backgroundCard
            )
            .cornerRadius(AzmyRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AzmyRadius.medium)
                    .stroke(isSelected ? AzmyColors.accentBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation Buttons
struct QuizNavigationButtons: View {
    @EnvironmentObject var quizViewModel: QuizViewModel

    var body: some View {
        VStack(spacing: AzmySpacing.sm) {
            // Next button
            Button(action: {
                quizViewModel.nextQuestion()
            }) {
                Text(quizViewModel.isLastQuestion ? "See Results" : "Next")
                    .font(AzmyFonts.bodyLarge())
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AzmySpacing.md)
                    .background(
                        quizViewModel.canGoNext
                            ? AzmyColors.accentBlue
                            : AzmyColors.accentBlue.opacity(0.5)
                    )
                    .cornerRadius(AzmyRadius.medium)
            }
            .disabled(!quizViewModel.canGoNext)

            // Back button
            if quizViewModel.canGoBack {
                Button(action: {
                    quizViewModel.previousQuestion()
                }) {
                    Text("Back")
                        .font(AzmyFonts.bodyLarge())
                        .foregroundColor(AzmyColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AzmySpacing.md)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(AzmyRadius.medium)
                }
            }
        }
        .padding(.horizontal, AzmySpacing.lg)
        .padding(.bottom, AzmySpacing.xl)
    }
}

// MARK: - Quiz Result View
struct QuizResultView: View {
    @EnvironmentObject var quizViewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: AzmySpacing.xl) {
                // Restart button
                HStack {
                    Button(action: {
                        quizViewModel.restartQuiz()
                    }) {
                        HStack(spacing: AzmySpacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("restart")
                        }
                        .font(AzmyFonts.bodySmall())
                        .foregroundColor(AzmyColors.accentBlue)
                        .padding(.horizontal, AzmySpacing.md)
                        .padding(.vertical, AzmySpacing.xs)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(AzmyRadius.medium)
                    }
                    Spacer()
                }
                .padding(.horizontal, AzmySpacing.lg)

                if let result = quizViewModel.quizResult {
                    // Personality type
                    VStack(spacing: AzmySpacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(AzmyColors.gradientBlue)
                            .padding()
                            .background(AzmyColors.backgroundCard)
                            .clipShape(Circle())

                        Text(result.personalityType)
                            .font(AzmyFonts.headline1())
                            .foregroundColor(AzmyColors.textPrimary)

                        Text(result.description)
                            .font(AzmyFonts.body())
                            .foregroundColor(AzmyColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AzmySpacing.lg)
                    }

                    // Match percentage ring
                    ZStack {
                        Circle()
                            .stroke(AzmyColors.backgroundCard, lineWidth: 12)
                            .frame(width: 150, height: 150)

                        // Colored segments
                        ForEach(Array(result.traits.enumerated()), id: \.element.id) { index, trait in
                            Circle()
                                .trim(from: trimStart(for: index, traits: result.traits),
                                      to: trimEnd(for: index, traits: result.traits))
                                .stroke(trait.swiftUIColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 150, height: 150)
                                .rotationEffect(.degrees(-90))
                        }

                        VStack(spacing: 0) {
                            Text("\(result.matchPercentage)%")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(AzmyColors.textPrimary)
                        }
                    }
                    .padding(.vertical, AzmySpacing.lg)

                    // Trait breakdown
                    VStack(spacing: AzmySpacing.sm) {
                        ForEach(result.traits) { trait in
                            TraitRow(trait: trait)
                        }
                    }
                    .padding(.horizontal, AzmySpacing.lg)
                }

                // Done button
                Button(action: {
                    dismiss()
                    quizViewModel.closeQuiz()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Again")
                    }
                    .font(AzmyFonts.bodyLarge())
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AzmySpacing.md)
                    .background(AzmyColors.accentBlue)
                    .cornerRadius(AzmyRadius.medium)
                }
                .padding(.horizontal, AzmySpacing.lg)
            }
            .padding(.vertical, AzmySpacing.lg)
        }
    }

    private func trimStart(for index: Int, traits: [TraitScore]) -> CGFloat {
        let totalScore = traits.reduce(0) { $0 + $1.score }
        var start: CGFloat = 0
        for i in 0..<index {
            start += CGFloat(traits[i].score / totalScore)
        }
        return start
    }

    private func trimEnd(for index: Int, traits: [TraitScore]) -> CGFloat {
        let totalScore = traits.reduce(0) { $0 + $1.score }
        var end: CGFloat = 0
        for i in 0...index {
            end += CGFloat(traits[i].score / totalScore)
        }
        return end
    }
}

struct TraitRow: View {
    let trait: TraitScore

    var body: some View {
        HStack(spacing: AzmySpacing.md) {
            Circle()
                .fill(trait.swiftUIColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(trait.name)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textPrimary)

                Text("\(trait.points) points")
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)
            }

            Spacer()

            Text("\(Int(trait.score * 100))%")
                .font(AzmyFonts.body())
                .foregroundColor(AzmyColors.textSecondary)
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
    }
}

// MARK: - Quiz Prompt Card (for Chat)
struct QuizPromptCard: View {
    let quiz: Quiz
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AzmySpacing.md) {
            Text(quiz.description)
                .font(AzmyFonts.body())
                .foregroundColor(AzmyColors.textPrimary)

            Button(action: onStart) {
                HStack {
                    Spacer()
                    Text("Open quiz")
                    Spacer()
                }
                .font(AzmyFonts.bodyLarge())
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, AzmySpacing.md)
                .background(AzmyColors.accentBlue)
                .cornerRadius(AzmyRadius.medium)
            }

            HStack(spacing: AzmySpacing.xs) {
                Image(systemName: "clock")
                Text("\(quiz.questions.count) questions")
                Text("·")
                Text("~\(quiz.estimatedMinutes) minutes")
            }
            .font(AzmyFonts.caption())
            .foregroundColor(AzmyColors.textTertiary)
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
    }
}

#Preview {
    QuizContainerView()
        .environmentObject(QuizViewModel())
        .preferredColorScheme(.dark)
}
