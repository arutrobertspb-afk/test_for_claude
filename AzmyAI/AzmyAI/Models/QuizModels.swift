//
//  QuizModels.swift
//  AzmyAI
//
//  Quiz system with multiple question types
//

import Foundation
import SwiftUI

// MARK: - Quiz
struct Quiz: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let estimatedMinutes: Int
    var questions: [QuizQuestion]
    var isCompleted: Bool = false
    var result: QuizResult?

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        icon: String = "sparkles",
        estimatedMinutes: Int = 3,
        questions: [QuizQuestion]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.estimatedMinutes = estimatedMinutes
        self.questions = questions
    }
}

// MARK: - Quiz Question
struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    let text: String
    let type: QuestionType
    let options: [QuizOption]
    var selectedOptionIds: Set<UUID> = []
    var sliderValue: Double = 0.5

    init(
        id: UUID = UUID(),
        text: String,
        type: QuestionType,
        options: [QuizOption] = []
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.options = options
    }

    var isAnswered: Bool {
        switch type {
        case .singleChoice, .multipleChoice, .chips, .bubbles:
            return !selectedOptionIds.isEmpty
        case .scale:
            return true // Scale always has a value
        }
    }
}

enum QuestionType: String, Codable {
    case singleChoice      // Radio buttons
    case multipleChoice    // Checkboxes
    case chips             // Color/tag chips
    case scale             // Slider from 0-100%
    case bubbles           // Floating bubbles
}

// MARK: - Quiz Option
struct QuizOption: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let color: String?      // Hex color for chips
    let icon: String?       // SF Symbol name
    let weight: [String: Double]  // Weights for personality traits

    init(
        id: UUID = UUID(),
        text: String,
        color: String? = nil,
        icon: String? = nil,
        weight: [String: Double] = [:]
    ) {
        self.id = id
        self.text = text
        self.color = color
        self.icon = icon
        self.weight = weight
    }

    var swiftUIColor: Color {
        guard let hex = color else { return AzmyColors.accentBlue }
        return Color(hex: hex)
    }
}

// MARK: - Quiz Result
struct QuizResult: Codable {
    let personalityType: String
    let description: String
    let matchPercentage: Int
    let traits: [TraitScore]
    let recommendations: [String]
    let timestamp: Date

    init(
        personalityType: String,
        description: String,
        matchPercentage: Int,
        traits: [TraitScore],
        recommendations: [String] = [],
        timestamp: Date = Date()
    ) {
        self.personalityType = personalityType
        self.description = description
        self.matchPercentage = matchPercentage
        self.traits = traits
        self.recommendations = recommendations
        self.timestamp = timestamp
    }
}

struct TraitScore: Codable, Identifiable {
    let id: UUID
    let name: String
    let score: Double       // 0.0 to 1.0
    let color: String       // Hex color
    let points: Int

    init(
        id: UUID = UUID(),
        name: String,
        score: Double,
        color: String,
        points: Int = 0
    ) {
        self.id = id
        self.name = name
        self.score = score
        self.color = color
        self.points = points
    }

    var swiftUIColor: Color {
        Color(hex: color)
    }
}

// MARK: - Sample Quizzes
extension Quiz {
    static let interiorStyleQuiz = Quiz(
        title: "Fast Quiz",
        description: "Understand your interior taste",
        icon: "paintpalette.fill",
        estimatedMinutes: 3,
        questions: [
            QuizQuestion(
                text: "Favorite Color Palette",
                type: .chips,
                options: [
                    QuizOption(text: "Black hues", color: "1A1A1A", weight: ["minimalist": 0.8, "modern": 0.6]),
                    QuizOption(text: "Warm wood shades", color: "8B5A2B", weight: ["natural": 0.9, "cozy": 0.7]),
                    QuizOption(text: "Grey tones", color: "808080", weight: ["minimalist": 0.7, "modern": 0.8]),
                    QuizOption(text: "White colors", color: "F5F5F5", weight: ["minimalist": 0.9, "clean": 0.8]),
                    QuizOption(text: "Bright accent colors", color: "FF6B6B", weight: ["creative": 0.8, "bold": 0.7])
                ]
            ),
            QuizQuestion(
                text: "Interior Style Preference",
                type: .scale,
                options: [
                    QuizOption(text: "Minimalistic design", weight: ["minimalist": 1.0]),
                    QuizOption(text: "Richly decorated", weight: ["maximalist": 1.0])
                ]
            ),
            QuizQuestion(
                text: "What do you value most?",
                type: .bubbles,
                options: [
                    QuizOption(text: "plants and natural materials", weight: ["natural": 0.9]),
                    QuizOption(text: "classical aesthetics", weight: ["classic": 0.9]),
                    QuizOption(text: "simplicity", weight: ["minimalist": 0.8]),
                    QuizOption(text: "retro", weight: ["vintage": 0.8]),
                    QuizOption(text: "traditional items", weight: ["classic": 0.7]),
                    QuizOption(text: "art", weight: ["creative": 0.9])
                ]
            ),
            QuizQuestion(
                text: "Preferred lighting atmosphere",
                type: .singleChoice,
                options: [
                    QuizOption(text: "Bright and airy", icon: "sun.max.fill", weight: ["modern": 0.7]),
                    QuizOption(text: "Warm and cozy", icon: "lamp.desk.fill", weight: ["cozy": 0.9]),
                    QuizOption(text: "Dramatic with accents", icon: "light.recessed.fill", weight: ["bold": 0.8]),
                    QuizOption(text: "Natural light focused", icon: "window.vertical.open", weight: ["natural": 0.8])
                ]
            ),
            QuizQuestion(
                text: "Furniture style preference",
                type: .chips,
                options: [
                    QuizOption(text: "Mid-century modern", color: "C4A484", weight: ["modern": 0.8]),
                    QuizOption(text: "Scandinavian", color: "E8DCC4", weight: ["minimalist": 0.9]),
                    QuizOption(text: "Industrial", color: "4A4A4A", weight: ["bold": 0.7]),
                    QuizOption(text: "Bohemian", color: "D4A373", weight: ["creative": 0.8]),
                    QuizOption(text: "Contemporary", color: "2C3E50", weight: ["modern": 0.9])
                ]
            ),
            QuizQuestion(
                text: "How important is functionality?",
                type: .scale,
                options: [
                    QuizOption(text: "Form follows function", weight: ["practical": 1.0]),
                    QuizOption(text: "Aesthetics first", weight: ["artistic": 1.0])
                ]
            ),
            QuizQuestion(
                text: "Texture preferences",
                type: .multipleChoice,
                options: [
                    QuizOption(text: "Soft fabrics", icon: "square.fill", weight: ["cozy": 0.7]),
                    QuizOption(text: "Natural wood", icon: "leaf.fill", weight: ["natural": 0.8]),
                    QuizOption(text: "Metal accents", icon: "bolt.fill", weight: ["modern": 0.7]),
                    QuizOption(text: "Glass elements", icon: "square.split.diagonal", weight: ["minimalist": 0.6]),
                    QuizOption(text: "Stone/Marble", icon: "mountain.2.fill", weight: ["luxury": 0.8])
                ]
            ),
            QuizQuestion(
                text: "Room clutter tolerance",
                type: .scale,
                options: [
                    QuizOption(text: "Everything hidden", weight: ["minimalist": 1.0]),
                    QuizOption(text: "Displayed collections", weight: ["maximalist": 1.0])
                ]
            ),
            QuizQuestion(
                text: "Color scheme approach",
                type: .singleChoice,
                options: [
                    QuizOption(text: "Monochromatic", icon: "circle.fill", weight: ["minimalist": 0.9]),
                    QuizOption(text: "Neutral with one accent", icon: "circle.lefthalf.filled", weight: ["modern": 0.8]),
                    QuizOption(text: "Bold contrasts", icon: "circle.grid.2x2.fill", weight: ["bold": 0.9]),
                    QuizOption(text: "Earthy tones", icon: "leaf.circle.fill", weight: ["natural": 0.9])
                ]
            ),
            QuizQuestion(
                text: "Art and decor style",
                type: .bubbles,
                options: [
                    QuizOption(text: "Abstract art", weight: ["modern": 0.8]),
                    QuizOption(text: "Photography", weight: ["minimalist": 0.6]),
                    QuizOption(text: "Vintage posters", weight: ["vintage": 0.9]),
                    QuizOption(text: "Sculptures", weight: ["artistic": 0.8]),
                    QuizOption(text: "Plants as decor", weight: ["natural": 0.9]),
                    QuizOption(text: "Minimal decor", weight: ["minimalist": 0.9])
                ]
            )
        ]
    )

    static let personalityQuiz = Quiz(
        title: "Personality Quiz",
        description: "Discover your work and life style",
        icon: "brain.head.profile",
        estimatedMinutes: 5,
        questions: [
            QuizQuestion(
                text: "How do you prefer to start your day?",
                type: .singleChoice,
                options: [
                    QuizOption(text: "Early morning workout", icon: "figure.run", weight: ["active": 0.9]),
                    QuizOption(text: "Quiet coffee and reading", icon: "cup.and.saucer.fill", weight: ["calm": 0.9]),
                    QuizOption(text: "Jump straight into work", icon: "laptopcomputer", weight: ["productive": 0.8]),
                    QuizOption(text: "Slow and relaxed", icon: "bed.double.fill", weight: ["relaxed": 0.9])
                ]
            ),
            QuizQuestion(
                text: "Your ideal work environment",
                type: .chips,
                options: [
                    QuizOption(text: "Quiet home office", color: "4A5568", weight: ["introverted": 0.8]),
                    QuizOption(text: "Busy coffee shop", color: "805AD5", weight: ["social": 0.7]),
                    QuizOption(text: "Collaborative office", color: "3182CE", weight: ["teamwork": 0.9]),
                    QuizOption(text: "Outdoor spaces", color: "38A169", weight: ["natural": 0.8])
                ]
            ),
            QuizQuestion(
                text: "Social energy level",
                type: .scale,
                options: [
                    QuizOption(text: "Solo recharge", weight: ["introverted": 1.0]),
                    QuizOption(text: "Social butterfly", weight: ["extroverted": 1.0])
                ]
            )
        ]
    )

    static let allQuizzes: [Quiz] = [interiorStyleQuiz, personalityQuiz]
}

// MARK: - Personality Types
struct PersonalityType {
    let name: String
    let description: String
    let traits: [String]

    static let modernMinimalist = PersonalityType(
        name: "Modern Minimalist",
        description: "You have a preference for clean lines, neutral colors, and functional yet stylish furnishings. Your choices reflect a modern aesthetic, favoring simplicity over ornamentation. You appreciate uncluttered spaces that allow the beauty of architectural details and quality materials to shine through.",
        traits: ["minimalist", "modern", "clean"]
    )

    static let creativeIntellectual = PersonalityType(
        name: "Creative intellectual",
        description: "Actively search for exhibits, visit museums, follow art on Instagram/Pinterest.",
        traits: ["creative", "artistic", "bold"]
    )

    static let naturalCozy = PersonalityType(
        name: "Natural & Cozy",
        description: "You're drawn to warmth and organic elements. Natural materials, soft textures, and earthy tones create your ideal sanctuary.",
        traits: ["natural", "cozy", "warm"]
    )

    static let allTypes = [modernMinimalist, creativeIntellectual, naturalCozy]
}
