//
//  GoogleCalendarService.swift
//  AzmyAI
//
//  Google Calendar API integration for syncing events
//

import Foundation

// MARK: - Google Calendar Event
struct GoogleCalendarEvent: Codable, Identifiable {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let start: GoogleEventDateTime
    let end: GoogleEventDateTime
    let status: String?
    let htmlLink: String?
    let colorId: String?

    var title: String {
        summary ?? "Untitled Event"
    }

    var startDate: Date? {
        start.dateTime ?? start.date
    }

    var endDate: Date? {
        end.dateTime ?? end.date
    }

    var isAllDay: Bool {
        start.date != nil && start.dateTime == nil
    }
}

struct GoogleEventDateTime: Codable {
    let dateTime: Date?
    let date: Date?
    let timeZone: String?

    enum CodingKeys: String, CodingKey {
        case dateTime
        case date
        case timeZone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone)

        // Try to decode dateTime first (for timed events)
        if let dateTimeString = try container.decodeIfPresent(String.self, forKey: .dateTime) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            dateTime = formatter.date(from: dateTimeString)
                ?? ISO8601DateFormatter().date(from: dateTimeString)
            date = nil
        } else if let dateString = try container.decodeIfPresent(String.self, forKey: .date) {
            // All-day event
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            date = formatter.date(from: dateString)
            dateTime = nil
        } else {
            dateTime = nil
            date = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(timeZone, forKey: .timeZone)

        let formatter = ISO8601DateFormatter()
        if let dateTime = dateTime {
            try container.encode(formatter.string(from: dateTime), forKey: .dateTime)
        }

        if let date = date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            try container.encode(dateFormatter.string(from: date), forKey: .date)
        }
    }
}

struct GoogleCalendarList: Codable {
    let kind: String
    let items: [GoogleCalendarItem]
}

struct GoogleCalendarItem: Codable, Identifiable {
    let id: String
    let summary: String
    let description: String?
    let backgroundColor: String?
    let foregroundColor: String?
    let primary: Bool?
    let accessRole: String
}

struct GoogleEventsResponse: Codable {
    let kind: String
    let summary: String?
    let items: [GoogleCalendarEvent]?
    let nextPageToken: String?
}

// MARK: - Google Calendar Service
@MainActor
class GoogleCalendarService: ObservableObject {
    static let shared = GoogleCalendarService()

    @Published var isConnected = false
    @Published var calendars: [GoogleCalendarItem] = []
    @Published var events: [GoogleCalendarEvent] = []
    @Published var isLoading = false
    @Published var error: GoogleCalendarError?

    private var accessToken: String?
    private var refreshToken: String?

    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let tokenKey = "googleCalendarAccessToken"
    private let refreshTokenKey = "googleCalendarRefreshToken"

    init() {
        loadSavedTokens()
    }

    // MARK: - Token Management
    private func loadSavedTokens() {
        accessToken = UserDefaults.standard.string(forKey: tokenKey)
        refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        isConnected = accessToken != nil
    }

    func setAccessToken(_ token: String, refreshToken: String?) {
        self.accessToken = token
        self.refreshToken = refreshToken

        UserDefaults.standard.set(token, forKey: tokenKey)
        if let refresh = refreshToken {
            UserDefaults.standard.set(refresh, forKey: refreshTokenKey)
        }

        isConnected = true
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        isConnected = false
        calendars = []
        events = []
    }

    // MARK: - API Calls

    /// Fetch all calendars
    func fetchCalendars() async throws -> [GoogleCalendarItem] {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: "\(baseURL)/users/me/calendarList")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GoogleCalendarError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        let calendarList = try JSONDecoder().decode(GoogleCalendarList.self, from: data)
        calendars = calendarList.items
        return calendarList.items
    }

    /// Fetch events from a calendar
    func fetchEvents(
        calendarId: String = "primary",
        from startDate: Date,
        to endDate: Date
    ) async throws -> [GoogleCalendarEvent] {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let formatter = ISO8601DateFormatter()

        var components = URLComponents(string: "\(baseURL)/calendars/\(calendarId)/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: startDate)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: endDate)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GoogleCalendarError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        let eventsResponse = try JSONDecoder().decode(GoogleEventsResponse.self, from: data)
        let fetchedEvents = eventsResponse.items ?? []
        events = fetchedEvents
        return fetchedEvents
    }

    /// Fetch today's events
    func fetchTodayEvents(calendarId: String = "primary") async throws -> [GoogleCalendarEvent] {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        return try await fetchEvents(calendarId: calendarId, from: startOfDay, to: endOfDay)
    }

    /// Fetch this week's events
    func fetchWeekEvents(calendarId: String = "primary") async throws -> [GoogleCalendarEvent] {
        let now = Date()
        let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek)!

        return try await fetchEvents(calendarId: calendarId, from: startOfWeek, to: endOfWeek)
    }

    /// Create a new event
    func createEvent(
        calendarId: String = "primary",
        title: String,
        description: String? = nil,
        location: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false
    ) async throws -> GoogleCalendarEvent {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: "\(baseURL)/calendars/\(calendarId)/events")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var eventData: [String: Any] = [
            "summary": title
        ]

        if let description = description {
            eventData["description"] = description
        }

        if let location = location {
            eventData["location"] = location
        }

        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        if isAllDay {
            eventData["start"] = ["date": dateFormatter.string(from: startDate)]
            eventData["end"] = ["date": dateFormatter.string(from: endDate)]
        } else {
            eventData["start"] = [
                "dateTime": formatter.string(from: startDate),
                "timeZone": TimeZone.current.identifier
            ]
            eventData["end"] = [
                "dateTime": formatter.string(from: endDate),
                "timeZone": TimeZone.current.identifier
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: eventData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GoogleCalendarError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GoogleCalendarEvent.self, from: data)
    }

    /// Update an existing event
    func updateEvent(
        calendarId: String = "primary",
        eventId: String,
        title: String? = nil,
        description: String? = nil,
        location: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> GoogleCalendarEvent {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let encodedEventId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        var request = URLRequest(url: URL(string: "\(baseURL)/calendars/\(calendarId)/events/\(encodedEventId)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var eventData: [String: Any] = [:]

        if let title = title {
            eventData["summary"] = title
        }
        if let description = description {
            eventData["description"] = description
        }
        if let location = location {
            eventData["location"] = location
        }

        let formatter = ISO8601DateFormatter()

        if let startDate = startDate {
            eventData["start"] = [
                "dateTime": formatter.string(from: startDate),
                "timeZone": TimeZone.current.identifier
            ]
        }
        if let endDate = endDate {
            eventData["end"] = [
                "dateTime": formatter.string(from: endDate),
                "timeZone": TimeZone.current.identifier
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: eventData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GoogleCalendarError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GoogleCalendarEvent.self, from: data)
    }

    /// Delete an event
    func deleteEvent(calendarId: String = "primary", eventId: String) async throws {
        guard let token = accessToken else {
            throw GoogleCalendarError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let encodedEventId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        var request = URLRequest(url: URL(string: "\(baseURL)/calendars/\(calendarId)/events/\(encodedEventId)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GoogleCalendarError.tokenExpired
        }

        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }
    }

    // MARK: - Convert to Local CalendarEvent
    func convertToLocalEvents(_ googleEvents: [GoogleCalendarEvent]) -> [CalendarEvent] {
        let eventColors: [(red: Double, green: Double, blue: Double)] = [
            (0.35, 0.55, 0.85),   // Blue
            (0.95, 0.45, 0.35),   // Red/Coral
            (0.30, 0.75, 0.50),   // Green
            (0.95, 0.60, 0.25),   // Orange
            (0.70, 0.45, 0.85),   // Purple
            (0.90, 0.75, 0.25),   // Yellow/Gold
            (0.85, 0.45, 0.65),   // Pink
            (0.40, 0.75, 0.80)    // Teal
        ]

        return googleEvents.enumerated().compactMap { index, event in
            guard let startDate = event.startDate,
                  let endDate = event.endDate else {
                return nil
            }

            let colorIndex = index % eventColors.count
            let color = eventColors[colorIndex]

            return CalendarEvent(
                id: UUID(),
                title: event.title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                notes: event.description,
                category: categorizeGoogleEvent(event),
                isAIGenerated: false,
                calendarIdentifier: event.id,
                colorRed: color.red,
                colorGreen: color.green,
                colorBlue: color.blue
            )
        }
    }

    private func categorizeGoogleEvent(_ event: GoogleCalendarEvent) -> EventCategory {
        let combined = "\(event.summary ?? "") \(event.description ?? "")".lowercased()

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

// MARK: - Google Calendar Errors
enum GoogleCalendarError: LocalizedError {
    case notAuthenticated
    case tokenExpired
    case invalidResponse
    case apiError(Int)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Google Calendar"
        case .tokenExpired:
            return "Google Calendar session expired. Please sign in again."
        case .invalidResponse:
            return "Invalid response from Google Calendar"
        case .apiError(let code):
            return "Google Calendar API error (code: \(code))"
        case .decodingError:
            return "Failed to parse Google Calendar data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
