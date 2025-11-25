//
//  CalendarService.swift
//  AzmyAI
//

import Foundation
import EventKit
import UIKit

class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()

    @Published var isAuthorized = false
    @Published var calendars: [EKCalendar] = []
    @Published var events: [CalendarEvent] = []

    init() {
        // Check and request authorization on init
        Task {
            await checkAndRequestAuthorization()
        }
    }

    // MARK: - Authorization
    private func checkAndRequestAuthorization() async {
        do {
            try await requestAuthorization()
            print("✅ Calendar access granted")
        } catch {
            print("❌ Calendar access error: \(error)")
        }
    }

    func requestAuthorization() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            await MainActor.run {
                self.isAuthorized = true
                self.loadCalendars()
            }
        case .notDetermined:
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.isAuthorized = granted
                    if granted { self.loadCalendars() }
                }
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    self.isAuthorized = granted
                    if granted { self.loadCalendars() }
                }
            }
        case .denied, .restricted, .writeOnly:
            throw CalendarError.accessDenied
        @unknown default:
            throw CalendarError.unknown
        }
    }

    // MARK: - Load Calendars
    private func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    // MARK: - Fetch Events
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)

        let calendarEvents = ekEvents.map { event -> CalendarEvent in
            // Extract calendar color
            let (red, green, blue) = extractCalendarColor(from: event)

            return CalendarEvent(
                id: UUID(),
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                notes: event.notes,
                category: categorizeEvent(event),
                isAIGenerated: false,
                calendarIdentifier: event.eventIdentifier,
                colorRed: red,
                colorGreen: green,
                colorBlue: blue
            )
        }

        await MainActor.run {
            self.events = calendarEvents
        }

        return calendarEvents
    }

    // MARK: - Fetch Today's Events
    func fetchTodayEvents() async throws -> [CalendarEvent] {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        return try await fetchEvents(from: startOfDay, to: endOfDay)
    }

    // MARK: - Fetch Week Events
    func fetchWeekEvents() async throws -> [CalendarEvent] {
        let now = Date()
        let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek)!

        return try await fetchEvents(from: startOfWeek, to: endOfWeek)
    }

    // MARK: - Create Event
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        calendarIdentifier: String? = nil
    ) async throws -> CalendarEvent {
        print("📅 Creating event: \(title)")
        print("   isAuthorized: \(isAuthorized)")

        guard isAuthorized else {
            print("❌ Not authorized for calendar")
            throw CalendarError.notAuthorized
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes

        // Use default calendar if none specified
        if let calId = calendarIdentifier,
           let calendar = calendars.first(where: { $0.calendarIdentifier == calId }) {
            event.calendar = calendar
            print("   Using calendar: \(calendar.title)")
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
            print("   Using default calendar: \(eventStore.defaultCalendarForNewEvents?.title ?? "nil")")
        }

        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Event saved successfully: \(event.eventIdentifier ?? "no-id")")
        } catch {
            print("❌ Failed to save event: \(error)")
            throw error
        }

        return CalendarEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            category: .other,
            isAIGenerated: true,
            calendarIdentifier: event.eventIdentifier
        )
    }

    // MARK: - Delete Event
    func deleteEvent(identifier: String) async throws {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        guard let event = eventStore.event(withIdentifier: identifier) else {
            throw CalendarError.eventNotFound
        }

        try eventStore.remove(event, span: .thisEvent)
    }

    // MARK: - Update Event
    func updateEvent(
        identifier: String,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        location: String? = nil,
        notes: String? = nil
    ) async throws {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        guard let event = eventStore.event(withIdentifier: identifier) else {
            throw CalendarError.eventNotFound
        }

        if let title = title { event.title = title }
        if let startDate = startDate { event.startDate = startDate }
        if let endDate = endDate { event.endDate = endDate }
        if let location = location { event.location = location }
        if let notes = notes { event.notes = notes }

        try eventStore.save(event, span: .thisEvent)
    }

    // MARK: - Find Free Slots
    func findFreeSlots(
        on date: Date,
        duration: TimeInterval,
        workingHoursStart: Int = 9,
        workingHoursEnd: Int = 18
    ) async throws -> [DateInterval] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let workStart = Calendar.current.date(bySettingHour: workingHoursStart, minute: 0, second: 0, of: startOfDay)!
        let workEnd = Calendar.current.date(bySettingHour: workingHoursEnd, minute: 0, second: 0, of: startOfDay)!

        let events = try await fetchEvents(from: workStart, to: workEnd)
            .sorted { $0.startDate < $1.startDate }

        var freeSlots: [DateInterval] = []
        var currentTime = workStart

        for event in events {
            if currentTime < event.startDate {
                let gap = event.startDate.timeIntervalSince(currentTime)
                if gap >= duration {
                    freeSlots.append(DateInterval(start: currentTime, end: event.startDate))
                }
            }
            if event.endDate > currentTime {
                currentTime = event.endDate
            }
        }

        // Check remaining time after last event
        if currentTime < workEnd {
            let gap = workEnd.timeIntervalSince(currentTime)
            if gap >= duration {
                freeSlots.append(DateInterval(start: currentTime, end: workEnd))
            }
        }

        return freeSlots
    }

    // MARK: - Extract Calendar Color
    private func extractCalendarColor(from event: EKEvent) -> (Double, Double, Double) {
        guard let calendar = event.calendar,
              let cgColor = calendar.cgColor else {
            // Default blue color
            return (0.3, 0.6, 1.0)
        }

        let uiColor = UIColor(cgColor: cgColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (Double(red), Double(green), Double(blue))
    }

    // MARK: - Categorize Event
    private func categorizeEvent(_ event: EKEvent) -> EventCategory {
        let title = event.title?.lowercased() ?? ""
        let notes = event.notes?.lowercased() ?? ""
        let combined = title + " " + notes

        if combined.contains("workout") || combined.contains("gym") || combined.contains("exercise") ||
           combined.contains("doctor") || combined.contains("health") || combined.contains("medical") {
            return .health
        }
        if combined.contains("meeting") || combined.contains("call") || combined.contains("standup") ||
           combined.contains("review") || combined.contains("work") {
            return .work
        }
        if combined.contains("lunch") || combined.contains("dinner") || combined.contains("party") ||
           combined.contains("friend") || combined.contains("birthday") {
            return .social
        }
        if combined.contains("focus") || combined.contains("deep work") || combined.contains("concentrate") {
            return .focus
        }
        if combined.contains("learn") || combined.contains("study") || combined.contains("course") ||
           combined.contains("class") || combined.contains("training") {
            return .learning
        }

        return .personal
    }
}

// MARK: - Errors
enum CalendarError: LocalizedError {
    case notAuthorized
    case accessDenied
    case eventNotFound
    case saveFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized"
        case .accessDenied:
            return "Calendar access was denied"
        case .eventNotFound:
            return "Event not found"
        case .saveFailed:
            return "Failed to save event"
        case .unknown:
            return "Unknown calendar error"
        }
    }
}
