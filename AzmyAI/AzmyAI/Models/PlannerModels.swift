//
//  PlannerModels.swift
//  AzmyAI
//

import Foundation

// MARK: - Calendar Event
struct CalendarEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var category: EventCategory
    var isAIGenerated: Bool
    var calendarIdentifier: String?

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        category: EventCategory = .other,
        isAIGenerated: Bool = false,
        calendarIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.category = category
        self.isAIGenerated = isAIGenerated
        self.calendarIdentifier = calendarIdentifier
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var formattedTime: String {
        if isAllDay {
            return "All day"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

enum EventCategory: String, Codable, CaseIterable {
    case work = "Work"
    case personal = "Personal"
    case health = "Health"
    case social = "Social"
    case learning = "Learning"
    case focus = "Focus Time"
    case other = "Other"

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .social: return "person.2.fill"
        case .learning: return "book.fill"
        case .focus: return "brain.head.profile"
        case .other: return "circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .work: return "blue"
        case .personal: return "purple"
        case .health: return "green"
        case .social: return "orange"
        case .learning: return "yellow"
        case .focus: return "indigo"
        case .other: return "gray"
        }
    }
}

// MARK: - Planner Task
struct PlannerTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String?
    var dueDate: Date?
    var priority: TaskPriority
    var isCompleted: Bool
    var category: EventCategory
    var estimatedDuration: TimeInterval?
    var isAISuggested: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        isCompleted: Bool = false,
        category: EventCategory = .other,
        estimatedDuration: TimeInterval? = nil,
        isAISuggested: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.category = category
        self.estimatedDuration = estimatedDuration
        self.isAISuggested = isAISuggested
        self.createdAt = createdAt
    }
}

enum TaskPriority: Int, Codable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    var icon: String {
        switch self {
        case .low: return "flag"
        case .medium: return "flag.fill"
        case .high: return "exclamationmark.circle.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

// MARK: - Daily Plan
struct DailyPlan: Identifiable, Codable {
    let id: UUID
    let date: Date
    var events: [CalendarEvent]
    var tasks: [PlannerTask]
    var aiRecommendations: [AIRecommendation]
    var focusBlocks: [FocusBlock]
    var energyPrediction: [HourlyEnergy]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        events: [CalendarEvent] = [],
        tasks: [PlannerTask] = [],
        aiRecommendations: [AIRecommendation] = [],
        focusBlocks: [FocusBlock] = [],
        energyPrediction: [HourlyEnergy] = []
    ) {
        self.id = id
        self.date = date
        self.events = events
        self.tasks = tasks
        self.aiRecommendations = aiRecommendations
        self.focusBlocks = focusBlocks
        self.energyPrediction = energyPrediction
    }
}

struct AIRecommendation: Identifiable, Codable, Hashable {
    let id: UUID
    let type: RecommendationType
    let title: String
    let description: String
    let actionText: String?
    var isDismissed: Bool

    init(
        id: UUID = UUID(),
        type: RecommendationType,
        title: String,
        description: String,
        actionText: String? = nil,
        isDismissed: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.actionText = actionText
        self.isDismissed = isDismissed
    }
}

enum RecommendationType: String, Codable {
    case schedule = "Schedule"
    case health = "Health"
    case productivity = "Productivity"
    case break_ = "Break"
    case social = "Social"

    var icon: String {
        switch self {
        case .schedule: return "calendar.badge.clock"
        case .health: return "heart.text.square"
        case .productivity: return "chart.line.uptrend.xyaxis"
        case .break_: return "cup.and.saucer.fill"
        case .social: return "person.2.fill"
        }
    }
}

struct FocusBlock: Identifiable, Codable, Hashable {
    let id: UUID
    var startTime: Date
    var endTime: Date
    var type: FocusType
    var isBooked: Bool

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        type: FocusType,
        isBooked: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
        self.isBooked = isBooked
    }
}

enum FocusType: String, Codable {
    case deepWork = "Deep Work"
    case meetings = "Meetings"
    case admin = "Admin"
    case rest = "Rest"
}

struct HourlyEnergy: Identifiable, Codable, Hashable {
    let id: UUID
    let hour: Int
    let predictedLevel: Double // 0-1

    init(id: UUID = UUID(), hour: Int, predictedLevel: Double) {
        self.id = id
        self.hour = hour
        self.predictedLevel = predictedLevel
    }
}

// MARK: - Time Block
struct TimeBlock: Identifiable {
    let id = UUID()
    let startHour: Int
    let endHour: Int
    let events: [CalendarEvent]
    let focusBlock: FocusBlock?

    var isEmpty: Bool {
        events.isEmpty && focusBlock == nil
    }
}
