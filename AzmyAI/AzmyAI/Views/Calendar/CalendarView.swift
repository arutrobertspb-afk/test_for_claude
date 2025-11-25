//
//  CalendarView.swift
//  AzmyAI
//
//  Calendar with month/week views matching Figma design
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
                // Header with month/week navigation
                calendarHeader

                if showWeekView {
                    // Week timeline view
                    WeekTimelineView(
                        selectedDate: $selectedDate,
                        events: plannerViewModel.events,
                        onEventTap: { event in
                            selectedEvent = event
                        }
                    )
                } else {
                    // Month grid view
                    MonthGridView(
                        currentMonth: currentMonth,
                        selectedDate: $selectedDate,
                        events: plannerViewModel.events
                    )
                }

                Spacer()
            }

            // FAB Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showAddEvent = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(AzmyColors.accentBlue)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
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
        }
        .sheet(item: $selectedEvent) { event in
            EventPreviewSheet(event: event, onDismiss: { selectedEvent = nil })
        }
        .onAppear {
            plannerViewModel.selectDate(selectedDate)
        }
        .onChange(of: selectedDate) { _, newDate in
            plannerViewModel.selectDate(newDate)
        }
        .onReceive(NotificationCenter.default.publisher(for: .calendarEventsDidChange)) { _ in
            plannerViewModel.selectDate(selectedDate)
        }
    }

    // MARK: - Calendar Header
    private var calendarHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Spacer()

                Text(showWeekView ? dayTitle : monthTitle)
                    .font(AzmyFonts.headline2())
                    .foregroundColor(.white)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Weekday headers
            if !showWeekView {
                HStack(spacing: 0) {
                    ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                        Text(day)
                            .font(AzmyFonts.caption())
                            .foregroundColor(AzmyColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            } else {
                // Week days horizontal scroll
                WeekDaySelector(selectedDate: $selectedDate)
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

    private func previousMonth() {
        withAnimation {
            if showWeekView {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } else {
                currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }
        }
    }

    private func nextMonth() {
        withAnimation {
            if showWeekView {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } else {
                currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }
        }
    }
}

// MARK: - Month Grid View
struct MonthGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let events: [CalendarEvent]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(daysInMonth().enumerated()), id: \.offset) { index, date in
                if let date = date {
                    DayCellView(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isToday: Calendar.current.isDateInToday(date),
                        events: eventsFor(date)
                    ) {
                        selectedDate = date
                    }
                } else {
                    Color.clear
                        .frame(height: 70)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        // Monday = 2 in gregorian calendar
        var firstWeekday = calendar.component(.weekday, from: startOfMonth)
        // Convert to Monday-first (Mon=0, Tue=1, ..., Sun=6)
        firstWeekday = (firstWeekday + 5) % 7

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

// MARK: - Day Cell View
struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let events: [CalendarEvent]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                // Day number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(AzmyFonts.body())
                    .foregroundColor(textColor)
                    .frame(width: 32, height: 32)
                    .background(backgroundColor)
                    .clipShape(Circle())

                // Event indicators (up to 2)
                VStack(spacing: 1) {
                    ForEach(Array(events.prefix(2).enumerated()), id: \.offset) { _, event in
                        Text(event.title)
                            .font(.system(size: 8))
                            .foregroundColor(eventColor(event))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 20)
            }
            .frame(height: 70)
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if isSelected { return .white }
        return .white
    }

    private var backgroundColor: Color {
        if isSelected { return AzmyColors.accentBlue }
        if isToday { return AzmyColors.accentBlue.opacity(0.3) }
        return Color.clear
    }

    private func eventColor(_ event: CalendarEvent) -> Color {
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

// MARK: - Week Day Selector
struct WeekDaySelector: View {
    @Binding var selectedDate: Date

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(weekDays(), id: \.self) { date in
                    WeekDayCell(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isToday: Calendar.current.isDateInToday(date)
                    ) {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    private func weekDays() -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
}

struct WeekDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(AzmyFonts.bodyLarge())
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : (isToday ? AzmyColors.accentBlue : .white))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? AzmyColors.accentBlue : Color.clear)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Week Timeline View
struct WeekTimelineView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    let onEventTap: (CalendarEvent) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(8..<22, id: \.self) { hour in
                    TimeSlotRow(
                        hour: hour,
                        events: eventsForHour(hour),
                        onEventTap: onEventTap
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func eventsForHour(_ hour: Int) -> [CalendarEvent] {
        events.filter { event in
            let eventHour = Calendar.current.component(.hour, from: event.startDate)
            return Calendar.current.isDate(event.startDate, inSameDayAs: selectedDate) && eventHour == hour
        }
    }
}

struct TimeSlotRow: View {
    let hour: Int
    let events: [CalendarEvent]
    let onEventTap: (CalendarEvent) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d:00", hour))
                .font(AzmyFonts.caption())
                .foregroundColor(AzmyColors.textTertiary)
                .frame(width: 45, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(AzmyColors.separator)
                    .frame(height: 1)

                ForEach(events) { event in
                    EventBlockView(event: event)
                        .onTapGesture { onEventTap(event) }
                }
            }
        }
        .frame(minHeight: 60)
    }
}

struct EventBlockView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(eventColor)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeRange)
                    .font(AzmyFonts.caption())
                    .foregroundColor(.white.opacity(0.8))

                Text(event.title)
                    .font(AzmyFonts.bodySmall())
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(8)
        .background(eventColor.opacity(0.3))
        .cornerRadius(8)
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

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
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
    @State private var showColorPicker: Bool = false

    init(selectedDate: Date, onCreate: @escaping (String, Date, Date, Bool, EventColor) -> Void) {
        self.selectedDate = selectedDate
        self.onCreate = onCreate

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let now = Date()
        components.hour = calendar.component(.hour, from: now)
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
                    VStack(spacing: 16) {
                        // Title field
                        TextField("Add title", text: $title)
                            .font(AzmyFonts.headline2())
                            .foregroundColor(.white)
                            .padding(16)
                            .background(AzmyColors.backgroundCard)
                            .cornerRadius(12)

                        // All day toggle
                        HStack {
                            Text("All day")
                                .font(AzmyFonts.body())
                                .foregroundColor(.white)
                            Spacer()
                            Toggle("", isOn: $isAllDay)
                                .tint(AzmyColors.accentBlue)
                        }
                        .padding(16)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(12)

                        // Start date/time
                        VStack(spacing: 0) {
                            HStack {
                                Text("Start")
                                    .font(AzmyFonts.body())
                                    .foregroundColor(.white)
                                Spacer()
                                DatePicker("", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(AzmyColors.accentBlue)
                            }
                            .padding(16)

                            Divider()
                                .background(AzmyColors.separator)

                            HStack {
                                Text("End")
                                    .font(AzmyFonts.body())
                                    .foregroundColor(.white)
                                Spacer()
                                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(AzmyColors.accentBlue)
                            }
                            .padding(16)
                        }
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(12)

                        // Color picker
                        VStack(spacing: 0) {
                            Button(action: { showColorPicker.toggle() }) {
                                HStack {
                                    Circle()
                                        .fill(selectedColor.color)
                                        .frame(width: 16, height: 16)
                                    Text("Color: \(selectedColor.name)")
                                        .font(AzmyFonts.body())
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: showColorPicker ? "chevron.up" : "chevron.down")
                                        .foregroundColor(AzmyColors.textTertiary)
                                }
                                .padding(16)
                            }

                            if showColorPicker {
                                Divider()
                                    .background(AzmyColors.separator)

                                VStack(spacing: 0) {
                                    ForEach(EventColor.allCases, id: \.self) { color in
                                        Button(action: {
                                            selectedColor = color
                                            showColorPicker = false
                                        }) {
                                            HStack {
                                                Circle()
                                                    .fill(color.color)
                                                    .frame(width: 16, height: 16)
                                                Text(color.name)
                                                    .font(AzmyFonts.body())
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

                        // Add event button
                        Button(action: saveEvent) {
                            Text("Add event")
                                .font(AzmyFonts.bodyLarge())
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(title.isEmpty ? AzmyColors.accentBlue.opacity(0.5) : AzmyColors.accentBlue)
                                .cornerRadius(12)
                        }
                        .disabled(title.isEmpty)
                        .padding(.top, 8)
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
                        .disabled(title.isEmpty)
                }
            }
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
    }

    private func saveEvent() {
        let finalEnd = isAllDay
            ? Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? endDate
            : endDate
        onCreate(title, startDate, finalEnd, isAllDay, selectedColor)
        dismiss()
    }
}

// MARK: - Event Preview Sheet
struct EventPreviewSheet: View {
    let event: CalendarEvent
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                // Event title
                Text(event.title)
                    .font(AzmyFonts.headline2())
                    .foregroundColor(.white)

                // Date
                Text(formattedDate)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textSecondary)

                // Time
                Text(event.formattedTime)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textSecondary)

                // Notes if available
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AzmyFonts.bodySmall())
                        .foregroundColor(AzmyColors.textTertiary)
                        .padding(.top, 4)
                }

                Spacer()

                // Buttons
                VStack(spacing: 8) {
                    Button(action: {}) {
                        Text("Edit")
                            .font(AzmyFonts.bodyLarge())
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AzmyColors.accentBlue)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        onDismiss()
                        dismiss()
                    }) {
                        Text("Close")
                            .font(AzmyFonts.bodyLarge())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AzmyColors.backgroundCard)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(20)
        }
        .background(AzmyColors.backgroundPrimary)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: event.startDate)
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
        case .orange: return Color.orange
        case .pink: return Color.pink
        case .green: return Color.green
        case .blue: return Color.blue
        case .yellow: return Color.yellow
        case .red: return Color.red
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(PlannerViewModel())
        .environmentObject(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
