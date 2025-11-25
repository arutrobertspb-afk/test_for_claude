//
//  QuizViewModel.swift
//  AzmyAI
//
//  Quiz management and scoring
//

import Foundation
import SwiftUI
import Combine

class QuizViewModel: ObservableObject {
    @Published var availableQuizzes: [AzmyQuiz] = AzmyQuiz.allQuizzes
    @Published var currentQuiz: AzmyQuiz?
    @Published var currentQuestionIndex: Int = 0
    @Published var isQuizActive: Bool = false
    @Published var isShowingResult: Bool = false
    @Published var quizResult: QuizResult?

    // MARK: - Computed Properties
    var currentQuestion: QuizQuestion? {
        guard let quiz = currentQuiz,
              currentQuestionIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentQuestionIndex]
    }

    var progress: Double {
        guard let quiz = currentQuiz, !quiz.questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(quiz.questions.count)
    }

    var totalQuestions: Int {
        currentQuiz?.questions.count ?? 0
    }

    var canGoNext: Bool {
        currentQuestion?.isAnswered ?? false
    }

    var canGoBack: Bool {
        currentQuestionIndex > 0
    }

    var isLastQuestion: Bool {
        guard let quiz = currentQuiz else { return false }
        return currentQuestionIndex >= quiz.questions.count - 1
    }

    // MARK: - Quiz Control
    func startQuiz(_ quiz: AzmyQuiz) {
        currentQuiz = quiz
        currentQuestionIndex = 0
        isQuizActive = true
        isShowingResult = false
        quizResult = nil
    }

    func closeQuiz() {
        isQuizActive = false
        currentQuiz = nil
        currentQuestionIndex = 0
        isShowingResult = false
        quizResult = nil
    }

    func nextQuestion() {
        guard let quiz = currentQuiz else { return }

        if currentQuestionIndex < quiz.questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
        } else {
            // Quiz completed
            calculateResult()
        }
    }

    func previousQuestion() {
        if currentQuestionIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex -= 1
            }
        }
    }

    // MARK: - Answer Selection
    func selectOption(_ option: QuizOption) {
        guard var quiz = currentQuiz,
              currentQuestionIndex < quiz.questions.count else { return }

        var question = quiz.questions[currentQuestionIndex]

        switch question.type {
        case .singleChoice:
            question.selectedOptionIds = [option.id]
        case .multipleChoice, .chips, .bubbles:
            if question.selectedOptionIds.contains(option.id) {
                question.selectedOptionIds.remove(option.id)
            } else {
                question.selectedOptionIds.insert(option.id)
            }
        case .scale:
            // Scale is handled by updateSliderValue
            break
        }

        quiz.questions[currentQuestionIndex] = question
        currentQuiz = quiz
    }

    func updateSliderValue(_ value: Double) {
        guard var quiz = currentQuiz,
              currentQuestionIndex < quiz.questions.count else { return }

        var question = quiz.questions[currentQuestionIndex]
        question.sliderValue = value
        quiz.questions[currentQuestionIndex] = question
        currentQuiz = quiz
    }

    func isOptionSelected(_ option: QuizOption) -> Bool {
        currentQuestion?.selectedOptionIds.contains(option.id) ?? false
    }

    // MARK: - Result Calculation
    private func calculateResult() {
        guard let quiz = currentQuiz else { return }

        var traitScores: [String: Double] = [:]

        // Calculate scores from all answers
        for question in quiz.questions {
            switch question.type {
            case .scale:
                // For scale questions, interpolate between first and last option weights
                if question.options.count >= 2 {
                    let firstWeights = question.options[0].weight
                    let lastWeights = question.options[1].weight

                    for (trait, weight) in firstWeights {
                        let score = weight * (1.0 - question.sliderValue)
                        traitScores[trait, default: 0] += score
                    }
                    for (trait, weight) in lastWeights {
                        let score = weight * question.sliderValue
                        traitScores[trait, default: 0] += score
                    }
                }

            default:
                // For selection-based questions
                for optionId in question.selectedOptionIds {
                    if let option = question.options.first(where: { $0.id == optionId }) {
                        for (trait, weight) in option.weight {
                            traitScores[trait, default: 0] += weight
                        }
                    }
                }
            }
        }

        // Normalize scores
        let maxScore = traitScores.values.max() ?? 1.0
        let normalizedScores = traitScores.mapValues { $0 / maxScore }

        // Determine personality type
        let topTraits = normalizedScores.sorted { $0.value > $1.value }.prefix(3)
        let personalityType = determinePersonalityType(from: Array(topTraits.map { $0.key }))

        // Create trait scores for display
        let colors = ["3B82F6", "EC4899", "F59E0B", "10B981", "8B5CF6"]
        let traits = topTraits.enumerated().map { index, trait in
            TraitScore(
                name: trait.key.capitalized,
                score: trait.value,
                color: colors[index % colors.count],
                points: Int(trait.value * 10)
            )
        }

        // Calculate match percentage
        let matchPercentage = Int(normalizedScores.values.reduce(0, +) / Double(normalizedScores.count) * 100)

        quizResult = QuizResult(
            personalityType: personalityType.name,
            description: personalityType.description,
            matchPercentage: min(98, max(75, matchPercentage)),
            traits: Array(traits)
        )

        // Update quiz as completed
        if var quiz = currentQuiz {
            quiz.isCompleted = true
            quiz.result = quizResult
            currentQuiz = quiz

            // Update in available quizzes
            if let index = availableQuizzes.firstIndex(where: { $0.id == quiz.id }) {
                availableQuizzes[index] = quiz
            }
        }

        withAnimation {
            isShowingResult = true
        }
    }

    private func determinePersonalityType(from traits: [String]) -> PersonalityType {
        if traits.contains("minimalist") || traits.contains("modern") {
            return .modernMinimalist
        } else if traits.contains("creative") || traits.contains("artistic") {
            return .creativeIntellectual
        } else if traits.contains("natural") || traits.contains("cozy") {
            return .naturalCozy
        }
        return .modernMinimalist
    }

    // MARK: - Restart Quiz
    func restartQuiz() {
        guard var quiz = currentQuiz else { return }

        // Reset all answers
        for i in quiz.questions.indices {
            quiz.questions[i].selectedOptionIds = []
            quiz.questions[i].sliderValue = 0.5
        }

        currentQuiz = quiz
        currentQuestionIndex = 0
        isShowingResult = false
        quizResult = nil
    }
}
