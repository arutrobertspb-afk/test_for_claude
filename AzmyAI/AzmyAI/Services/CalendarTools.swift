//
//  CalendarTools.swift
//  AzmyAI
//
//  Calendar management tools for LLM function calling
//

import Foundation
import EventKit

// MARK: - Tool Definitions for Mistral API
struct MistralTool: Codable {
    let type: String = "function"
    let function: MistralFunction
}

struct MistralFunction: Codable {
    let name: String
    let description: String
    let parameters: MistralParameters
}

struct MistralParameters: Codable {
    let type: String = "object"
    let properties: [String: MistralProperty]
    let required: [String]
}

struct MistralProperty: Codable {
    let type: String
    let description: String
    let `enum`: [String]?

    init(type: String, description: String, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = enumValues
    }
}

// MARK: - Tool Call Response
struct ToolCall: Codable {
    let id: String
    let function: ToolFunction
}

struct ToolFunction: Codable {
    let name: String
    let arguments: String
}

// MARK: - Calendar Tools Definition
struct CalendarTools {

    static let allTools: [MistralTool] = [
        createEventTool,
        deleteEventTool,
        editEventTool,
        getEventsTool,
        analyzeScheduleTool,
        suggestRestTool
    ]

    // MARK: - Create Event Tool
    static let createEventTool = MistralTool(
        function: MistralFunction(
            name: "create_calendar_event",
            description: """
            Creates a new event in the user's calendar. Use this tool when the user wants to:
            - Schedule a meeting or appointment
            - Add a reminder for something
            - Plan an activity at a specific time
            - Book time for a task

            IMPORTANT: Before creating an event, consider:
            1. Check if the user already has events at that time
            2. Respect the user's working hours (typically 9:00-18:00)
            3. Suggest breaks if the user has many consecutive meetings

            Returns: Confirmation of created event with details
            """,
            parameters: MistralParameters(
                properties: [
                    "title": MistralProperty(
                        type: "string",
                        description: "The title/name of the event. Should be clear and descriptive."
                    ),
                    "start_datetime": MistralProperty(
                        type: "string",
                        description: "Start date and time in ISO 8601 format (YYYY-MM-DDTHH:MM:SS). Example: 2025-01-15T14:00:00"
                    ),
                    "end_datetime": MistralProperty(
                        type: "string",
                        description: "End date and time in ISO 8601 format. If not specified, defaults to 1 hour after start."
                    ),
                    "location": MistralProperty(
                        type: "string",
                        description: "Location of the event (address, room name, or 'online' for virtual meetings)"
                    ),
                    "notes": MistralProperty(
                        type: "string",
                        description: "Additional notes or description for the event"
                    ),
                    "color": MistralProperty(
                        type: "string",
                        description: "Color category for the event",
                        enumValues: ["blue", "green", "orange", "red", "purple", "yellow"]
                    )
                ],
                required: ["title", "start_datetime"]
            )
        )
    )

    // MARK: - Delete Event Tool
    static let deleteEventTool = MistralTool(
        function: MistralFunction(
            name: "delete_calendar_event",
            description: """
            Deletes an existing event from the user's calendar. Use this tool when the user wants to:
            - Cancel a meeting
            - Remove an appointment
            - Clear a scheduled activity

            IMPORTANT:
            1. Confirm with user before deleting important events
            2. If multiple events match, ask for clarification
            3. Consider offering to reschedule instead of delete

            Returns: Confirmation of deletion or error if event not found
            """,
            parameters: MistralParameters(
                properties: [
                    "event_id": MistralProperty(
                        type: "string",
                        description: "The unique identifier of the event to delete"
                    ),
                    "event_title": MistralProperty(
                        type: "string",
                        description: "Title of the event to delete (used for searching if ID not provided)"
                    ),
                    "event_date": MistralProperty(
                        type: "string",
                        description: "Date of the event in YYYY-MM-DD format (helps identify the correct event)"
                    )
                ],
                required: ["event_title"]
            )
        )
    )

    // MARK: - Edit Event Tool
    static let editEventTool = MistralTool(
        function: MistralFunction(
            name: "edit_calendar_event",
            description: """
            Modifies an existing event in the user's calendar. Use this tool when the user wants to:
            - Change the time of a meeting
            - Update the location
            - Rename an event
            - Add or modify notes
            - Reschedule an appointment

            IMPORTANT:
            1. Only update the fields that the user specifically mentioned
            2. Verify there are no conflicts with the new time
            3. Keep original values for fields not being updated

            Returns: Updated event details or error if event not found
            """,
            parameters: MistralParameters(
                properties: [
                    "event_id": MistralProperty(
                        type: "string",
                        description: "The unique identifier of the event to edit"
                    ),
                    "event_title": MistralProperty(
                        type: "string",
                        description: "Current title of the event (for finding it)"
                    ),
                    "event_date": MistralProperty(
                        type: "string",
                        description: "Current date of the event in YYYY-MM-DD format"
                    ),
                    "new_title": MistralProperty(
                        type: "string",
                        description: "New title for the event (if changing)"
                    ),
                    "new_start_datetime": MistralProperty(
                        type: "string",
                        description: "New start date and time in ISO 8601 format"
                    ),
                    "new_end_datetime": MistralProperty(
                        type: "string",
                        description: "New end date and time in ISO 8601 format"
                    ),
                    "new_location": MistralProperty(
                        type: "string",
                        description: "New location for the event"
                    ),
                    "new_notes": MistralProperty(
                        type: "string",
                        description: "New notes/description for the event"
                    )
                ],
                required: ["event_title"]
            )
        )
    )

    // MARK: - Get Events Tool
    static let getEventsTool = MistralTool(
        function: MistralFunction(
            name: "get_calendar_events",
            description: """
            Retrieves events from the user's calendar for a specified time period. Use this tool when the user:
            - Asks about their schedule
            - Wants to know what's planned
            - Needs to check availability
            - Asks "What do I have today/tomorrow/this week?"

            IMPORTANT:
            1. Always check events before suggesting new meeting times
            2. Consider time zones
            3. Group results by day for better readability

            Returns: List of events with titles, times, and locations
            """,
            parameters: MistralParameters(
                properties: [
                    "start_date": MistralProperty(
                        type: "string",
                        description: "Start of the period to check, in YYYY-MM-DD format. Defaults to today."
                    ),
                    "end_date": MistralProperty(
                        type: "string",
                        description: "End of the period to check, in YYYY-MM-DD format. Defaults to same as start_date."
                    ),
                    "search_query": MistralProperty(
                        type: "string",
                        description: "Optional: filter events by title containing this text"
                    )
                ],
                required: []
            )
        )
    )

    // MARK: - Analyze Schedule Tool
    static let analyzeScheduleTool = MistralTool(
        function: MistralFunction(
            name: "analyze_schedule",
            description: """
            Analyzes the user's calendar to provide insights about their schedule patterns. Use this tool to:
            - Assess if the user has too many meetings
            - Find patterns in their schedule
            - Identify busy/free days
            - Calculate meeting load statistics
            - Detect potential burnout indicators

            ANALYSIS CRITERIA:
            - More than 5 meetings/day = Heavy load
            - More than 3 hours of consecutive meetings = Needs break
            - Less than 30 min between meetings = Too packed
            - Meetings during lunch (12-13) = Missing break
            - Meetings after 18:00 = Work-life balance issue

            Returns: Detailed analysis with recommendations
            """,
            parameters: MistralParameters(
                properties: [
                    "period": MistralProperty(
                        type: "string",
                        description: "Period to analyze",
                        enumValues: ["today", "this_week", "next_week", "this_month"]
                    ),
                    "focus": MistralProperty(
                        type: "string",
                        description: "What aspect to focus on",
                        enumValues: ["meeting_load", "free_time", "patterns", "work_life_balance", "all"]
                    )
                ],
                required: ["period"]
            )
        )
    )

    // MARK: - Suggest Rest Tool
    static let suggestRestTool = MistralTool(
        function: MistralFunction(
            name: "suggest_rest",
            description: """
            Evaluates the user's schedule and suggests rest or breaks when needed. Use this tool when:
            - User seems overwhelmed
            - Schedule analysis shows high meeting load
            - User asks about taking time off
            - Consecutive busy days detected

            REST RECOMMENDATIONS BASED ON:
            - 3+ consecutive busy days → Suggest half-day off
            - 5+ meetings today → Suggest 15-min break between each
            - No lunch break scheduled → Suggest blocking lunch time
            - Working late (after 19:00) → Suggest earlier end time
            - Weekend work → Suggest compensation time off

            Returns: Personalized rest recommendations with specific suggestions
            """,
            parameters: MistralParameters(
                properties: [
                    "check_period": MistralProperty(
                        type: "string",
                        description: "Period to evaluate for rest needs",
                        enumValues: ["today", "this_week", "next_week"]
                    ),
                    "include_suggestions": MistralProperty(
                        type: "string",
                        description: "Whether to include specific time suggestions for breaks",
                        enumValues: ["yes", "no"]
                    )
                ],
                required: ["check_period"]
            )
        )
    )
}

// MARK: - Event Colors Palette
struct EventColorPalette {
    // Array of colors for events - each event on the same day gets a different color
    static let colors: [(red: Double, green: Double, blue: Double, name: String)] = [
        (0.35, 0.55, 0.85, "blue"),      // Blue
        (0.95, 0.45, 0.35, "red"),       // Red/Coral
        (0.30, 0.75, 0.50, "green"),     // Green
        (0.95, 0.60, 0.25, "orange"),    // Orange
        (0.70, 0.45, 0.85, "purple"),    // Purple
        (0.90, 0.75, 0.25, "yellow"),    // Yellow/Gold
        (0.85, 0.45, 0.65, "pink"),      // Pink
        (0.40, 0.75, 0.80, "teal")       // Teal
    ]

    static func colorForIndex(_ index: Int) -> (red: Double, green: Double, blue: Double) {
        let color = colors[index % colors.count]
        return (color.red, color.green, color.blue)
    }

    static func colorForName(_ name: String?) -> (red: Double, green: Double, blue: Double)? {
        guard let name = name?.lowercased() else { return nil }
        return colors.first { $0.name == name }.map { ($0.red, $0.green, $0.blue) }
    }
}

// MARK: - Calendar Tool Executor
class CalendarToolExecutor {
    private let eventStore = EKEventStore()

    init() {
        print("📅 CalendarToolExecutor initialized")
    }

    // Get the count of events on a specific day to assign unique color
    private func getEventCountForDay(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        return events.count
    }

    // MARK: - Ensure Authorization (async)
    private func ensureAuthorization() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        print("📅 Current authorization status: \(status.rawValue)")

        switch status {
        case .authorized, .fullAccess:
            print("✅ Calendar already authorized")
            return true
        case .notDetermined:
            print("🔄 Requesting calendar authorization...")
            do {
                var granted = false
                if #available(iOS 17.0, *) {
                    granted = try await eventStore.requestFullAccessToEvents()
                } else {
                    granted = try await eventStore.requestAccess(to: .event)
                }
                print(granted ? "✅ Authorization granted" : "❌ Authorization denied")
                return granted
            } catch {
                print("❌ Authorization error: \(error)")
                return false
            }
        case .denied, .restricted, .writeOnly:
            print("❌ Calendar access denied or restricted")
            return false
        @unknown default:
            print("❌ Unknown authorization status")
            return false
        }
    }

    // MARK: - Execute Tool Call
    func execute(toolName: String, arguments: [String: Any]) async -> String {
        print("🔧 CalendarToolExecutor.execute: \(toolName)")
        print("   Arguments: \(arguments)")

        switch toolName {
        case "create_calendar_event":
            return await createEvent(arguments)
        case "delete_calendar_event":
            return await deleteEvent(arguments)
        case "edit_calendar_event":
            return await editEvent(arguments)
        case "get_calendar_events":
            return await getEvents(arguments)
        case "analyze_schedule":
            return await analyzeSchedule(arguments)
        case "suggest_rest":
            return await suggestRest(arguments)
        default:
            return "Unknown tool: \(toolName)"
        }
    }

    // MARK: - Create Event
    private func createEvent(_ args: [String: Any]) async -> String {
        print("📅 createEvent called with: \(args)")

        guard await ensureAuthorization() else {
            print("❌ Calendar access not granted")
            return "Calendar access not granted. Please enable in Settings → Privacy → Calendars."
        }

        guard let title = args["title"] as? String,
              let startString = args["start_datetime"] as? String else {
            print("❌ Missing required fields")
            return "Missing required fields: title and start_datetime"
        }

        print("📅 Parsing date: \(startString)")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try multiple date formats
        var startDate: Date?
        startDate = formatter.date(from: startString)

        if startDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            startDate = formatter.date(from: startString)
        }

        if startDate == nil {
            // Try simpler format YYYY-MM-DDTHH:MM:SS
            let simpleFormatter = DateFormatter()
            simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            startDate = simpleFormatter.date(from: startString)
        }

        guard let startDate = startDate else {
            print("❌ Failed to parse date: \(startString)")
            return "Invalid date format. Use ISO 8601 format: YYYY-MM-DDTHH:MM:SS"
        }

        print("✅ Parsed start date: \(startDate)")

        let endDate: Date
        if let endString = args["end_datetime"] as? String {
            var parsedEnd: Date?
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            parsedEnd = formatter.date(from: endString)
            if parsedEnd == nil {
                formatter.formatOptions = [.withInternetDateTime]
                parsedEnd = formatter.date(from: endString)
            }
            if parsedEnd == nil {
                let simpleFormatter = DateFormatter()
                simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                parsedEnd = simpleFormatter.date(from: endString)
            }
            endDate = parsedEnd ?? startDate.addingTimeInterval(3600)
        } else {
            endDate = startDate.addingTimeInterval(3600) // Default 1 hour
        }

        print("📅 End date: \(endDate)")

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate

        // Debug: list all available calendars
        let allCalendars = eventStore.calendars(for: .event)
        print("📅 Available calendars (\(allCalendars.count)):")
        for cal in allCalendars {
            print("   - \(cal.title) [source: \(cal.source?.title ?? "unknown")] [type: \(cal.type.rawValue)] [allowsModify: \(cal.allowsContentModifications)]")
        }

        let defaultCalendar = eventStore.defaultCalendarForNewEvents
        print("📅 Default calendar: \(defaultCalendar?.title ?? "⚠️ NIL - NO DEFAULT CALENDAR")")

        if defaultCalendar == nil {
            // Try to find a writable calendar
            if let writableCalendar = allCalendars.first(where: { $0.allowsContentModifications }) {
                print("📅 Using fallback writable calendar: \(writableCalendar.title)")
                event.calendar = writableCalendar
            } else {
                print("❌ No writable calendar found!")
                return "No writable calendar available. Please add a calendar account in Settings."
            }
        } else {
            event.calendar = defaultCalendar
        }

        if let location = args["location"] as? String {
            event.location = location
            print("📅 Location: \(location)")
        }

        if let notes = args["notes"] as? String {
            event.notes = notes
            print("📅 Notes: \(notes)")
        }

        print("📅 About to save event:")
        print("   Title: \(event.title ?? "nil")")
        print("   Start: \(event.startDate?.description ?? "nil")")
        print("   End: \(event.endDate?.description ?? "nil")")
        print("   Calendar: \(event.calendar?.title ?? "nil")")

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "MMM d, HH:mm"
            let successMsg = "✅ Event created: \"\(title)\" on \(timeFormatter.string(from: startDate))"
            print(successMsg)
            print("📅 Event ID: \(event.eventIdentifier ?? "no-id")")

            // Notify UI to refresh
            await MainActor.run {
                NotificationCenter.default.post(name: Notification.Name("calendarEventsDidChange"), object: nil)
            }

            return successMsg
        } catch {
            let errorMsg = "Failed to create event: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            print("❌ Full error: \(error)")
            return errorMsg
        }
    }

    // MARK: - Delete Event
    private func deleteEvent(_ args: [String: Any]) async -> String {
        print("📅 deleteEvent called with: \(args)")

        guard await ensureAuthorization() else {
            return "Calendar access not granted."
        }

        guard let title = args["event_title"] as? String else {
            return "Missing event title"
        }

        let calendar = Calendar.current
        let startDate: Date
        let endDate: Date

        if let dateString = args["event_date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                startDate = calendar.startOfDay(for: date)
                endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
            } else {
                startDate = calendar.startOfDay(for: Date())
                endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
            }
        } else {
            startDate = calendar.startOfDay(for: Date())
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        let matchingEvents = events.filter { $0.title.lowercased().contains(title.lowercased()) }

        guard let eventToDelete = matchingEvents.first else {
            return "No event found matching: \"\(title)\""
        }

        do {
            try eventStore.remove(eventToDelete, span: .thisEvent)
            return "✅ Event deleted: \"\(eventToDelete.title ?? title)\""
        } catch {
            return "Failed to delete event: \(error.localizedDescription)"
        }
    }

    // MARK: - Edit Event
    private func editEvent(_ args: [String: Any]) async -> String {
        print("📅 editEvent called with: \(args)")

        guard await ensureAuthorization() else {
            return "Calendar access not granted."
        }

        guard let title = args["event_title"] as? String else {
            return "Missing event title"
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        guard let event = events.first(where: { $0.title.lowercased().contains(title.lowercased()) }) else {
            return "No event found matching: \"\(title)\""
        }

        if let newTitle = args["new_title"] as? String {
            event.title = newTitle
        }

        let formatter = ISO8601DateFormatter()
        if let newStart = args["new_start_datetime"] as? String,
           let date = formatter.date(from: newStart) {
            let duration = event.endDate.timeIntervalSince(event.startDate)
            event.startDate = date
            event.endDate = date.addingTimeInterval(duration)
        }

        if let newEnd = args["new_end_datetime"] as? String,
           let date = formatter.date(from: newEnd) {
            event.endDate = date
        }

        if let newLocation = args["new_location"] as? String {
            event.location = newLocation
        }

        if let newNotes = args["new_notes"] as? String {
            event.notes = newNotes
        }

        do {
            try eventStore.save(event, span: .thisEvent)
            return "✅ Event updated: \"\(event.title ?? "")\""
        } catch {
            return "Failed to update event: \(error.localizedDescription)"
        }
    }

    // MARK: - Get Events
    private func getEvents(_ args: [String: Any]) async -> String {
        print("📅 getEvents called with: \(args)")

        guard await ensureAuthorization() else {
            return "Calendar access not granted."
        }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let startDate: Date
        let endDate: Date

        if let startString = args["start_date"] as? String,
           let parsed = formatter.date(from: startString) {
            startDate = calendar.startOfDay(for: parsed)
        } else {
            startDate = calendar.startOfDay(for: Date())
        }

        if let endString = args["end_date"] as? String,
           let parsed = formatter.date(from: endString) {
            endDate = calendar.date(byAdding: .day, value: 1, to: parsed)!
        } else {
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        var events = eventStore.events(matching: predicate)

        if let query = args["search_query"] as? String {
            events = events.filter { $0.title.lowercased().contains(query.lowercased()) }
        }

        if events.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            return "No events found for \(dateFormatter.string(from: startDate))"
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var result = "📅 Events:\n"
        for event in events.sorted(by: { $0.startDate < $1.startDate }) {
            let start = timeFormatter.string(from: event.startDate)
            let end = timeFormatter.string(from: event.endDate)
            result += "• \(start)-\(end): \(event.title ?? "Untitled")\n"
        }

        return result
    }

    // MARK: - Analyze Schedule
    private func analyzeSchedule(_ args: [String: Any]) async -> String {
        print("📅 analyzeSchedule called with: \(args)")

        guard await ensureAuthorization() else {
            return "Calendar access not granted."
        }

        let period = args["period"] as? String ?? "this_week"
        let focus = args["focus"] as? String ?? "all"

        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        let endDate: Date

        switch period {
        case "today":
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        case "this_week":
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
        case "next_week":
            startDate = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
        case "this_month":
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
        default:
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        let totalEvents = events.count
        let days = max(1, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
        let avgPerDay = Double(totalEvents) / Double(days)

        var totalMeetingMinutes = 0
        for event in events {
            totalMeetingMinutes += Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        }

        var analysis = "📊 Schedule Analysis (\(period.replacingOccurrences(of: "_", with: " "))):\n\n"
        analysis += "• Total events: \(totalEvents)\n"
        analysis += "• Average per day: \(String(format: "%.1f", avgPerDay))\n"
        analysis += "• Total meeting time: \(totalMeetingMinutes / 60)h \(totalMeetingMinutes % 60)m\n\n"

        // Assessment
        if avgPerDay > 5 {
            analysis += "⚠️ HIGH LOAD: More than 5 events/day average. Consider delegating or rescheduling.\n"
        } else if avgPerDay > 3 {
            analysis += "🟡 MODERATE: Schedule is busy but manageable.\n"
        } else {
            analysis += "✅ BALANCED: Good meeting load.\n"
        }

        // Update memory with stats
        let busyDays = events.reduce(into: [String: Int]()) { result, event in
            let dayName = calendar.weekdaySymbols[calendar.component(.weekday, from: event.startDate) - 1]
            result[dayName, default: 0] += 1
        }
        let topBusyDays = busyDays.sorted { $0.value > $1.value }.prefix(3).map { $0.key }

        ConversationMemory.shared.updateScheduleStats(
            averageMeetings: avgPerDay,
            busyDays: topBusyDays
        )

        return analysis
    }

    // MARK: - Suggest Rest
    private func suggestRest(_ args: [String: Any]) async -> String {
        let period = args["check_period"] as? String ?? "this_week"
        let includeSuggestions = args["include_suggestions"] as? String ?? "yes"

        // First analyze the schedule
        let analysis = await analyzeSchedule(["period": period, "focus": "all"])

        var suggestions = "\n💆 Rest Recommendations:\n"

        if analysis.contains("HIGH LOAD") {
            suggestions += "• Block 2-hour focus time each morning\n"
            suggestions += "• Take a 15-min walk after lunch\n"
            suggestions += "• Consider a half-day off this week\n"
        } else if analysis.contains("MODERATE") {
            suggestions += "• Ensure lunch breaks are blocked\n"
            suggestions += "• Take 5-min stretching breaks\n"
        } else {
            suggestions += "• Your schedule looks good!\n"
            suggestions += "• Keep maintaining work-life balance\n"
        }

        if includeSuggestions == "yes" {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE 'at' HH:mm"
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

            suggestions += "\n📌 Suggested break: \(formatter.string(from: tomorrow)) (30 min)\n"
        }

        return analysis + suggestions
    }
}
