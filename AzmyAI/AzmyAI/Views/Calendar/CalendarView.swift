//
//  CalendarView.swift
//  AzmyAI
//
//  Google Calendar style implementation
//

import SwiftUI
import EventKit

// MARK: - Notification for calendar updates
extension Notification.Name {
    static let calendarEventsDidChange = Notification.Name("calendarEventsDidChange")
}

struct CalendarView: View {
    @EnvironmentObject var plannerViewModel: PlannerViewModel
    @EnvironmentObject var userProfile: UserProfileViewModel

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var showWeekView: Bool = false
    @State private var showAddEvent: Bool = false
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        ZStack {
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                CalendarHeader(
                    title: showWeekView ? dayTitle : monthTitle,
                    showBackButton: showWeekView,
                    onBack: { showWeekView = false },
                    onPrevious: previousAction,
                    onNext: nextAction
                )

                if showWeekView {
                    // Week selector
                    WeekDayStrip(selectedDate: $selectedDate)

                    // Day timeline
                    DayTimelineView(
                        selectedDate: selectedDate,
                        events: eventsForSelectedDate,
                        onEventTap: { event in
                            selectedEvent = event
                        }
                    )
                } else {
                    // Weekday headers
                    WeekdayHeader()

                    // Month grid
                    MonthGridView(
                        currentMonth: currentMonth,
                        selectedDate: $selectedDate,
                        events: plannerViewModel.events,
                        onDateTap: { date in
                            selectedDate = date
                            showWeekView = true
                        }
                    )
                }

                Spacer()
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showAddEvent = true }) {
                        Image(systemName: "plus")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(AzmyColors.accentBlue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(20)
                }
            }

            // Event Preview Overlay
            if let event = selectedEvent {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { selectedEvent = nil }

                EventPreviewCard(
                    event: event,
                    onEdit: { /* TODO */ },
                    onClose: { selectedEvent = nil }
                )
            }
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventSheet(selectedDate: selectedDate) { title, startDate, endDate, isAllDay, color in
                Task {
                    await plannerViewModel.createEvent(
                        title: title,
                        startDate: startDate,
                        endDate: endDate,
                        isAllDay: isAllDay
                    )
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            Task {
                await plannerViewModel.fetchEventsForMonth(currentMonth)
            }
        }
        .onChange(of: currentMonth) { _, newMonth in
            Task {
                await plannerViewModel.fetchEventsForMonth(newMonth)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .calendarEventsDidChange)) { _ in
            Task {
                await plannerViewModel.fetchEventsForMonth(currentMonth)
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: currentMonth)
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: selectedDate)
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        plannerViewModel.events.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate)
        }
    }

    private func previousAction() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if showWeekView {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } else {
                currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }
        }
    }

    private func nextAction() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if showWeekView {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } else {
                currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }
        }
    }
}

// MARK: - Calendar Header
struct CalendarHeader: View {
    let title: String
    let showBackButton: Bool
    let onBack: (() -> Void)?
    let onPrevious: () -> Void
    let onNext: () -> Void

    init(title: String, showBackButton: Bool = false, onBack: (() -> Void)? = nil, onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
        self.title = title
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    var body: some View {
        HStack {
            if showBackButton {
                Button(action: { onBack?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AzmyColors.accentBlue)
                }
                .frame(width: 70, alignment: .leading)
            } else {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(10)
                }
            }

            Spacer()

            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            if showBackButton {
                // Navigation arrows for day view
                HStack(spacing: 8) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(AzmyColors.backgroundCard)
                            .cornerRadius(8)
                    }
                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(AzmyColors.backgroundCard)
                            .cornerRadius(8)
                    }
                }
            } else {
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Weekday Header
struct WeekdayHeader: View {
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AzmyColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Month Grid View
struct MonthGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    let onDateTap: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            let weeks = weeksInMonth()
            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                // Week row
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, date in
                        if let date = date {
                            MonthDayCell(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                isToday: Calendar.current.isDateInToday(date),
                                events: eventsFor(date)
                            ) {
                                onDateTap(date)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 72)
                        }
                    }
                }

                // Divider after each week (except last)
                if weekIndex < weeks.count - 1 {
                    Rectangle()
                        .fill(AzmyColors.separator.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func weeksInMonth() -> [[Date?]] {
        let days = daysInMonth()
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = []

        for (index, date) in days.enumerated() {
            currentWeek.append(date)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }

        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }

        return weeks
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        var firstWeekday = calendar.component(.weekday, from: startOfMonth)
        firstWeekday = (firstWeekday + 5) % 7 // Monday-first

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func eventsFor(_ date: Date) -> [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }
}

// MARK: - Month Day Cell
struct MonthDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let events: [CalendarEvent]
    let action: () -> Void

    private let maxVisibleEvents = 2

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                // Day number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday ? .bold : .medium))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(isToday ? AzmyColors.accentBlue : Color.clear)
                    .clipShape(Circle())

                // Event pills (colored badges like Google Calendar)
                VStack(spacing: 1) {
                    ForEach(Array(events.prefix(maxVisibleEvents).enumerated()), id: \.offset) { _, event in
                        EventPill(title: event.title, color: event.color)
                    }

                    if events.count > maxVisibleEvents {
                        Text("+\(events.count - maxVisibleEvents)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(AzmyColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 2)
                    }
                }
                .frame(minHeight: 32, alignment: .top)
            }
            .frame(height: 72)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Pill (colored badge)
struct EventPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(truncatedTitle)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color)
            .cornerRadius(3)
    }

    private var truncatedTitle: String {
        if title.count > 6 {
            return String(title.prefix(5)) + "..."
        }
        return title
    }
}

// MARK: - Week Day Strip
struct WeekDayStrip: View {
    @Binding var selectedDate: Date

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays(), id: \.self) { date in
                WeekDayItem(
                    date: date,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                ) {
                    selectedDate = date
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func weekDays() -> [Date] {
        let calendar = Calendar.current
        // Get Monday of current week
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        components.weekday = 2 // Monday
        let monday = calendar.date(from: components) ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }
}

struct WeekDayItem: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AzmyColors.textTertiary)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? AzmyColors.accentBlue : Color.clear)
                    .clipShape(Circle())

                // Selection indicator
                if isSelected {
                    Rectangle()
                        .fill(AzmyColors.accentBlue)
                        .frame(width: 24, height: 3)
                        .cornerRadius(1.5)
                } else {
                    Color.clear.frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Day Timeline View
struct DayTimelineView: View {
    let selectedDate: Date
    let events: [CalendarEvent]
    let onEventTap: (CalendarEvent) -> Void

    private let startHour = 8
    private let endHour = 22

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Time slots
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        TimeSlotRow(hour: hour)
                    }
                }

                // Current time indicator
                if Calendar.current.isDateInToday(selectedDate) {
                    CurrentTimeIndicator(startHour: startHour)
                }

                // Events
                ForEach(events) { event in
                    EventBlock(event: event, startHour: startHour)
                        .onTapGesture { onEventTap(event) }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

struct TimeSlotRow: View {
    let hour: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%02d:00", hour))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AzmyColors.textTertiary)
                .frame(width: 40, alignment: .trailing)

            VStack {
                Rectangle()
                    .fill(AzmyColors.separator.opacity(0.5))
                    .frame(height: 1)
                Spacer()
            }
        }
        .frame(height: 60)
    }
}

struct CurrentTimeIndicator: View {
    let startHour: Int

    var body: some View {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let offset = CGFloat(hour - startHour) * 60 + CGFloat(minute)

        HStack(spacing: 0) {
            Circle()
                .fill(AzmyColors.accentBlue)
                .frame(width: 10, height: 10)
                .offset(x: 35)

            Rectangle()
                .fill(AzmyColors.accentBlue)
                .frame(height: 2)
        }
        .offset(y: offset)
    }
}

struct EventBlock: View {
    let event: CalendarEvent
    let startHour: Int

    var body: some View {
        let startHourOfEvent = Calendar.current.component(.hour, from: event.startDate)
        let startMinute = Calendar.current.component(.minute, from: event.startDate)
        let duration = event.endDate.timeIntervalSince(event.startDate) / 60

        // Clamp to visible range
        let effectiveStartHour = max(startHourOfEvent, startHour)
        let yOffset = CGFloat(effectiveStartHour - startHour) * 60 + (startHourOfEvent >= startHour ? CGFloat(startMinute) : 0)
        let height = max(CGFloat(duration), 30)

        HStack(spacing: 8) {
            Rectangle()
                .fill(event.color)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeRange)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(8)
        .frame(height: height)
        .background(event.color.opacity(0.25))
        .background(AzmyColors.backgroundCard)
        .cornerRadius(8)
        .padding(.leading, 52)
        .padding(.trailing, 4)
        .offset(y: yOffset)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) — \(formatter.string(from: event.endDate))"
    }
}

// MARK: - Event Preview Card
struct EventPreviewCard: View {
    let event: CalendarEvent
    let onEdit: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(event.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            // Date
            Text(formattedDate)
                .font(.system(size: 14))
                .foregroundColor(AzmyColors.textSecondary)

            // Time
            Text(event.formattedTime)
                .font(.system(size: 14))
                .foregroundColor(AzmyColors.textSecondary)

            // Event preview block
            HStack(spacing: 8) {
                Rectangle()
                    .fill(eventColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(timeRange)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text(event.title)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(10)
            .background(eventColor.opacity(0.2))
            .cornerRadius(8)

            Spacer().frame(height: 8)

            // Buttons
            Button(action: onEdit) {
                Text("Edit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AzmyColors.accentBlue)
                    .cornerRadius(12)
            }

            Button(action: onClose) {
                Text("Close")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AzmyColors.backgroundCard)
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(AzmyColors.backgroundPrimary)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .padding(.horizontal, 20)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: event.startDate)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) — \(formatter.string(from: event.endDate))"
    }

    private var eventColor: Color {
        switch event.category {
        case .work: return .blue
        case .personal: return .orange
        case .health: return .green
        case .social: return .pink
        case .learning: return .yellow
        case .focus: return .purple
        case .other: return .gray
        }
    }
}

// MARK: - Add Event Sheet
struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedDate: Date
    let onCreate: (String, Date, Date, Bool, EventColor) -> Void

    @State private var title: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedColor: EventColor = .orange
    @State private var showDatePicker: Bool = false
    @State private var showTimePicker: Bool = false
    @State private var showColorPicker: Bool = false
    @State private var editingStart: Bool = true

    init(selectedDate: Date, onCreate: @escaping (String, Date, Date, Bool, EventColor) -> Void) {
        self.selectedDate = selectedDate
        self.onCreate = onCreate

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = 16
        components.minute = 0

        let start = calendar.date(from: components) ?? selectedDate
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: calendar.date(byAdding: .hour, value: 1, to: start) ?? start)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // Title with color bar
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(selectedColor.color)
                                .frame(width: 4)
                                .cornerRadius(2)

                            TextField("Add title", text: $title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .frame(height: 56)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(12)

                        // All day toggle
                        HStack {
                            Text("All day")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            Spacer()
                            Toggle("", isOn: $isAllDay)
                                .tint(AzmyColors.accentBlue)
                        }
                        .padding(16)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(12)

                        // Start row
                        VStack(spacing: 0) {
                            DateTimeRow(
                                label: "Start",
                                date: startDate,
                                showTime: !isAllDay,
                                onDateTap: {
                                    editingStart = true
                                    showDatePicker.toggle()
                                    showTimePicker = false
                                },
                                onTimeTap: {
                                    editingStart = true
                                    showTimePicker.toggle()
                                    showDatePicker = false
                                }
                            )

                            if showDatePicker && editingStart {
                                InlineDatePicker(date: $startDate)
                            }

                            if showTimePicker && editingStart {
                                InlineTimePicker(date: $startDate)
                            }
                        }
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(12)

                        // End row
                        VStack(spacing: 0) {
                            DateTimeRow(
                                label: "End",
                                date: endDate,
                                showTime: !isAllDay,
                                onDateTap: {
                                    editingStart = false
                                    showDatePicker.toggle()
                                    showTimePicker = false
                                },
                                onTimeTap: {
                                    editingStart = false
                                    showTimePicker.toggle()
                                    showDatePicker = false
                                }
                            )

                            if showDatePicker && !editingStart {
                                InlineDatePicker(date: $endDate)
                            }

                            if showTimePicker && !editingStart {
                                InlineTimePicker(date: $endDate)
                            }
                        }
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(12)

                        // Color picker
                        VStack(spacing: 0) {
                            Button(action: { withAnimation { showColorPicker.toggle() } }) {
                                HStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(selectedColor.color)
                                        .frame(width: 20, height: 20)

                                    Text("Color: \(selectedColor.name)")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(AzmyColors.textTertiary)
                                        .rotationEffect(.degrees(showColorPicker ? 180 : 0))
                                }
                                .padding(16)
                            }

                            if showColorPicker {
                                VStack(spacing: 0) {
                                    ForEach(EventColor.allCases, id: \.self) { color in
                                        Button(action: {
                                            selectedColor = color
                                            withAnimation { showColorPicker = false }
                                        }) {
                                            HStack {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(color.color)
                                                    .frame(width: 20, height: 20)

                                                Text(color.name)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)

                                                Spacer()

                                                if selectedColor == color {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(AzmyColors.accentBlue)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                        }
                                    }
                                }
                            }
                        }
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(12)

                        Spacer().frame(height: 20)

                        // Add event button
                        Button(action: saveEvent) {
                            Text("Add event")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(title.isEmpty ? AzmyColors.accentBlue.opacity(0.5) : AzmyColors.accentBlue)
                                .cornerRadius(12)
                        }
                        .disabled(title.isEmpty)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AzmyColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEvent() }
                        .foregroundColor(title.isEmpty ? AzmyColors.textTertiary : AzmyColors.accentBlue)
                        .fontWeight(.semibold)
                        .disabled(title.isEmpty)
                }
            }
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func saveEvent() {
        onCreate(title, startDate, endDate, isAllDay, selectedColor)
        dismiss()
    }
}

// MARK: - Date Time Row
struct DateTimeRow: View {
    let label: String
    let date: Date
    let showTime: Bool
    let onDateTap: () -> Void
    let onTimeTap: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Spacer()

            Button(action: onDateTap) {
                Text(formattedDate)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AzmyColors.backgroundSecondary)
                    .cornerRadius(8)
            }

            if showTime {
                Button(action: onTimeTap) {
                    Text(formattedTime)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AzmyColors.backgroundSecondary)
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, yyyy"
        return formatter.string(from: date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Inline Date Picker
struct InlineDatePicker: View {
    @Binding var date: Date

    var body: some View {
        DatePicker("", selection: $date, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .colorScheme(.dark)
            .tint(AzmyColors.accentBlue)
            .padding(.horizontal, 8)
    }
}

// MARK: - Inline Time Picker
struct InlineTimePicker: View {
    @Binding var date: Date

    var body: some View {
        DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .colorScheme(.dark)
            .frame(height: 150)
            .padding(.horizontal, 8)
    }
}

// MARK: - Event Color
enum EventColor: String, CaseIterable {
    case orange = "Orange"
    case pink = "Pink"
    case green = "Green"
    case blue = "Blue"
    case yellow = "Yellow"
    case red = "Red"

    var name: String { rawValue }

    var color: Color {
        switch self {
        case .orange: return .orange
        case .pink: return .pink
        case .green: return .green
        case .blue: return .blue
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(PlannerViewModel())
        .environmentObject(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
