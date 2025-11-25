//
//  ChatModels.swift
//  AzmyAI
//

import Foundation

// MARK: - Chat Message
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let role: MessageRole
    let timestamp: Date
    var suggestions: [SuggestedAction]?
    var isTyping: Bool = false

    // Streaming support
    var displayedContent: String
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        suggestions: [SuggestedAction]? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.suggestions = suggestions
        self.isStreaming = isStreaming
        // For user messages, show full content immediately
        // For assistant messages with streaming, start empty
        self.displayedContent = (role == .assistant && isStreaming) ? "" : content
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Suggested Actions
struct SuggestedAction: Identifiable, Codable, Hashable {
    let id: UUID
    let type: ActionType
    let title: String
    let description: String?
    let payload: ActionPayload?

    init(
        id: UUID = UUID(),
        type: ActionType,
        title: String,
        description: String? = nil,
        payload: ActionPayload? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.payload = payload
    }
}

enum ActionType: String, Codable {
    case createEvent
    case setReminder
    case suggestTask
    case viewInsight
    case quickReply
    case openQuiz
}

struct ActionPayload: Codable, Hashable {
    var eventTitle: String?
    var eventDate: Date?
    var eventDuration: TimeInterval?
    var reminderText: String?
    var quizId: String?
}

// MARK: - Chat Context
struct ChatContext: Codable {
    var recentEvents: [CalendarEvent] = []
    var healthSnapshot: HealthSnapshot?
    var currentMood: Int?
    var currentEnergy: Int?
    var pendingTasks: [PlannerTask] = []
    var timeOfDay: TimeOfDay

    init() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            self.timeOfDay = .morning
        } else if hour < 17 {
            self.timeOfDay = .afternoon
        } else if hour < 21 {
            self.timeOfDay = .evening
        } else {
            self.timeOfDay = .night
        }
    }
}

enum TimeOfDay: String, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"

    var greeting: String {
        switch self {
        case .morning: return "Good morning"
        case .afternoon: return "Good afternoon"
        case .evening: return "Good evening"
        case .night: return "Good night"
        }
    }
}

// MARK: - Quick Prompts
struct QuickPrompt: Identifiable {
    let id = UUID()
    let title: String
    let prompt: String
    let icon: String
    let category: PromptCategory
}

enum PromptCategory: CaseIterable {
    case planning
    case wellness
    case productivity
    case reflection

    var title: String {
        switch self {
        case .planning: return "Planning"
        case .wellness: return "Wellness"
        case .productivity: return "Productivity"
        case .reflection: return "Reflection"
        }
    }
}

// MARK: - Sample Quick Prompts
extension QuickPrompt {
    static let samples: [QuickPrompt] = [
        QuickPrompt(
            title: "Plan my day",
            prompt: "Help me plan my day based on my calendar and energy levels",
            icon: "calendar.badge.clock",
            category: .planning
        ),
        QuickPrompt(
            title: "Energy check",
            prompt: "I want to log my current energy and mood",
            icon: "bolt.fill",
            category: .wellness
        ),
        QuickPrompt(
            title: "Focus time",
            prompt: "Find the best time for deep work today",
            icon: "brain.head.profile",
            category: .productivity
        ),
        QuickPrompt(
            title: "Evening reflection",
            prompt: "Let's reflect on how today went",
            icon: "moon.stars.fill",
            category: .reflection
        ),
        QuickPrompt(
            title: "Schedule event",
            prompt: "I need to schedule a meeting",
            icon: "plus.circle.fill",
            category: .planning
        ),
        QuickPrompt(
            title: "Sleep analysis",
            prompt: "How was my sleep this week?",
            icon: "bed.double.fill",
            category: .wellness
        )
    ]
}
