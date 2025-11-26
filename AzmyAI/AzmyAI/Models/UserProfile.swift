//
//  UserProfile.swift
//  AzmyAI
//

import Foundation

// MARK: - User Profile
struct UserProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var email: String = ""
    var createdAt: Date = Date()

    // Authentication
    var authProvider: String = "none" // "google", "apple", "none"
    var authUserId: String?
    var profileImageURL: String?
    var isGoogleCalendarConnected: Bool = false

    // Quiz Results
    var quizAnswers: [QuizAnswer] = []
    var personalityTraits: PersonalityTraits?
    var lifestylePreferences: LifestylePreferences?

    // Health & Wellness
    var healthData: HealthSnapshot?
    var sleepGoal: Double = 8.0
    var dailyStepsGoal: Int = 10000

    // Preferences
    var notificationsEnabled: Bool = true
    var morningReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    var eveningReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    var preferGoogleCalendar: Bool = false // Use Google Calendar instead of local
}

// MARK: - Legacy Quiz Models (deprecated - use QuizModels.swift instead)
struct LegacyQuiz: Identifiable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let category: QuizCategory
    let questions: [LegacyQuizQuestion]
    let icon: String
}

enum QuizCategory: String, Codable, CaseIterable {
    case personality = "Personality"
    case productivity = "Productivity"
    case wellness = "Wellness"
    case lifestyle = "Lifestyle"
    case goals = "Goals"

    var color: String {
        switch self {
        case .personality: return "purple"
        case .productivity: return "blue"
        case .wellness: return "green"
        case .lifestyle: return "orange"
        case .goals: return "pink"
        }
    }
}

struct LegacyQuizQuestion: Identifiable {
    let id: UUID = UUID()
    let text: String
    let type: LegacyQuestionType
    let options: [LegacyQuizOption]?
    let minValue: Int?
    let maxValue: Int?
}

enum LegacyQuestionType {
    case singleChoice
    case multipleChoice
    case scale
    case text
}

struct LegacyQuizOption: Identifiable, Hashable {
    let id: UUID = UUID()
    let text: String
    let value: Int
}

struct QuizAnswer: Codable, Identifiable {
    var id: UUID = UUID()
    let quizId: UUID
    let questionId: UUID
    let answerValue: String
    let answeredAt: Date
}

// MARK: - Personality & Preferences
struct PersonalityTraits: Codable {
    var chronotype: Chronotype = .neutral
    var energyPattern: EnergyPattern = .steady
    var workStyle: WorkStyle = .balanced
    var socialPreference: SocialPreference = .ambivert
    var stressResponse: StressResponse = .moderate
}

enum Chronotype: String, Codable, CaseIterable {
    case earlyBird = "Early Bird"
    case nightOwl = "Night Owl"
    case neutral = "Neutral"

    var description: String {
        switch self {
        case .earlyBird: return "Most productive in the morning"
        case .nightOwl: return "Peak energy in the evening"
        case .neutral: return "Consistent throughout the day"
        }
    }
}

enum EnergyPattern: String, Codable, CaseIterable {
    case morning = "Morning Peak"
    case afternoon = "Afternoon Peak"
    case evening = "Evening Peak"
    case steady = "Steady"
}

enum WorkStyle: String, Codable, CaseIterable {
    case deepWork = "Deep Work"
    case collaborative = "Collaborative"
    case balanced = "Balanced"
}

enum SocialPreference: String, Codable, CaseIterable {
    case introvert = "Introvert"
    case extrovert = "Extrovert"
    case ambivert = "Ambivert"
}

enum StressResponse: String, Codable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
}

struct LifestylePreferences: Codable {
    var primaryGoals: [LifeGoal] = []
    var workSchedule: WorkSchedule = .standard
    var exerciseFrequency: ExerciseFrequency = .moderate
    var dietaryPreferences: [String] = []
    var hobbies: [String] = []
}

enum LifeGoal: String, Codable, CaseIterable {
    case productivity = "Boost Productivity"
    case health = "Improve Health"
    case balance = "Work-Life Balance"
    case fitness = "Fitness Goals"
    case learning = "Learn New Skills"
    case relationships = "Better Relationships"
    case stress = "Reduce Stress"
    case sleep = "Better Sleep"
}

enum WorkSchedule: String, Codable, CaseIterable {
    case standard = "9-5"
    case flexible = "Flexible"
    case shift = "Shift Work"
    case remote = "Remote/Async"
}

enum ExerciseFrequency: String, Codable, CaseIterable {
    case none = "Rarely"
    case light = "1-2x/week"
    case moderate = "3-4x/week"
    case active = "5+/week"
}

// MARK: - Health Data
struct HealthSnapshot: Codable {
    var lastUpdated: Date = Date()
    var sleepHours: Double?
    var steps: Int?
    var activeCalories: Int?
    var heartRate: Int?
    var hrvAverage: Double?
    var energyLevel: Int? // 1-10 scale
    var moodScore: Int? // 1-10 scale
}
