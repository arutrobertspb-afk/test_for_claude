//
//  ConversationMemory.swift
//  AzmyAI
//
//  Persistent conversation memory using UserDefaults + in-memory cache
//

import Foundation

// MARK: - Memory Entry
struct MemoryEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let role: String
    let content: String
    let summary: String?
    let importance: Int // 1-10, higher = more important to remember

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        role: String,
        content: String,
        summary: String? = nil,
        importance: Int = 5
    ) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.content = content
        self.summary = summary
        self.importance = importance
    }
}

// MARK: - User Context
struct UserContext: Codable {
    var name: String?
    var preferences: [String: String]
    var goals: [String]
    var schedule: ScheduleContext
    var healthInsights: [String]
    var lastInteraction: Date?

    init() {
        self.preferences = [:]
        self.goals = []
        self.schedule = ScheduleContext()
        self.healthInsights = []
    }
}

struct ScheduleContext: Codable {
    var busyDays: [String] // e.g., ["Monday", "Wednesday"]
    var preferredMeetingTimes: [String] // e.g., ["morning", "afternoon"]
    var workHoursStart: Int = 9
    var workHoursEnd: Int = 18
    var averageMeetingsPerDay: Double = 0

    init() {
        self.busyDays = []
        self.preferredMeetingTimes = []
    }
}

// MARK: - Conversation Memory Manager
class ConversationMemory: ObservableObject {
    static let shared = ConversationMemory()

    @Published var shortTermMemory: [MemoryEntry] = []
    @Published var userContext: UserContext = UserContext()

    private let maxShortTermEntries = 20
    private let maxContextWindowTokens = 4000
    private let userDefaultsKey = "azmy_conversation_memory"
    private let userContextKey = "azmy_user_context"

    init() {
        loadFromStorage()
    }

    // MARK: - Add Message to Memory
    func addMessage(role: String, content: String, importance: Int = 5) {
        let entry = MemoryEntry(
            role: role,
            content: content,
            importance: importance
        )

        shortTermMemory.append(entry)

        // Trim if exceeds max
        if shortTermMemory.count > maxShortTermEntries {
            // Keep high importance messages
            let sorted = shortTermMemory.sorted { $0.importance > $1.importance }
            shortTermMemory = Array(sorted.prefix(maxShortTermEntries))
            shortTermMemory.sort { $0.timestamp < $1.timestamp }
        }

        saveToStorage()
    }

    // MARK: - Get Context for LLM
    func getContextForLLM() -> String {
        var context = ""

        // Add user context summary
        if let name = userContext.name {
            context += "User's name: \(name)\n"
        }

        if !userContext.goals.isEmpty {
            context += "User's goals: \(userContext.goals.joined(separator: ", "))\n"
        }

        if !userContext.preferences.isEmpty {
            let prefs = userContext.preferences.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            context += "Preferences: \(prefs)\n"
        }

        if !userContext.healthInsights.isEmpty {
            context += "Health insights: \(userContext.healthInsights.suffix(3).joined(separator: "; "))\n"
        }

        // Add schedule context
        if userContext.schedule.averageMeetingsPerDay > 0 {
            context += "Average meetings per day: \(String(format: "%.1f", userContext.schedule.averageMeetingsPerDay))\n"
        }

        context += "\n--- Recent Conversation ---\n"

        // Add recent messages (last 10)
        for entry in shortTermMemory.suffix(10) {
            let rolePrefix = entry.role == "user" ? "User" : "Azmy"
            context += "\(rolePrefix): \(entry.content)\n"
        }

        return context
    }

    // MARK: - Update User Context
    func updateUserName(_ name: String) {
        userContext.name = name
        saveToStorage()
    }

    func addGoal(_ goal: String) {
        if !userContext.goals.contains(goal) {
            userContext.goals.append(goal)
            saveToStorage()
        }
    }

    func updatePreference(key: String, value: String) {
        userContext.preferences[key] = value
        saveToStorage()
    }

    func addHealthInsight(_ insight: String) {
        userContext.healthInsights.append(insight)
        if userContext.healthInsights.count > 10 {
            userContext.healthInsights.removeFirst()
        }
        saveToStorage()
    }

    func updateScheduleStats(averageMeetings: Double, busyDays: [String]) {
        userContext.schedule.averageMeetingsPerDay = averageMeetings
        userContext.schedule.busyDays = busyDays
        saveToStorage()
    }

    // MARK: - Persistence
    private func saveToStorage() {
        let encoder = JSONEncoder()

        if let memoryData = try? encoder.encode(shortTermMemory) {
            UserDefaults.standard.set(memoryData, forKey: userDefaultsKey)
        }

        if let contextData = try? encoder.encode(userContext) {
            UserDefaults.standard.set(contextData, forKey: userContextKey)
        }

        userContext.lastInteraction = Date()
    }

    private func loadFromStorage() {
        let decoder = JSONDecoder()

        if let memoryData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let memory = try? decoder.decode([MemoryEntry].self, from: memoryData) {
            shortTermMemory = memory
        }

        if let contextData = UserDefaults.standard.data(forKey: userContextKey),
           let context = try? decoder.decode(UserContext.self, from: contextData) {
            userContext = context
        }
    }

    // MARK: - Clear Memory
    func clearAllMemory() {
        shortTermMemory = []
        userContext = UserContext()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: userContextKey)
    }

    func clearConversation() {
        shortTermMemory = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
