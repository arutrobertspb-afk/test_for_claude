//
//  CalendarView.swift
//  AzmyAI
//
//  Calendar with month/week views and event management
//

import SwiftUI
import EventKit

struct CalendarView: View {
    @EnvironmentObject var plannerViewModel: PlannerViewModel
    @EnvironmentObject var userProfile: UserProfileViewModel

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var viewMode: CalendarViewMode = .month
    @State private var showAddEvent: Bool = false
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // View mode and month selector
                    CalendarHeaderView(
                        currentMonth: $currentMonth,
                        viewMode: $viewMode,
                        selectedDate: selectedDate
                    )

                    if viewMode == .month {
                        MonthCalendarView(
                            currentMonth: currentMonth,
                            selectedDate: $selectedDate,
                            events: plannerViewModel.events
                        )
                    } else {
                        WeekCalendarView(
                            selectedDate: $selectedDate,
                            events: plannerViewModel.events
                        )
                    }

                    // Events for selected date
                    EventsListView(
                        date: selectedDate,
                        events: eventsForSelectedDate,
                        onEventTap: { event in
                            selectedEvent = event
                        }
                    )
                }

                // FAB
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
                                .shadow(color: AzmyColors.accentBlue.opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.trailing, AzmySpacing.lg)
                        .padding(.bottom, AzmySpacing.lg)
                    }
                }
            }
            .navigationTitle(monthYearString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showAddEvent) {
                AddEventView(selectedDate: selectedDate) { title, startDate, endDate, isAllDay, color in
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
                EventDetailView(event: event)
            }
        }
        .onAppear {
            Task {
                await plannerViewModel.fetchEventsForSelectedDate()
            }
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: currentMonth)
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        plannerViewModel.events.filter { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: selectedDate)
        }
    }
}

enum CalendarViewMode {
    case month
    case week
}

// MARK: - Calendar Header
struct CalendarHeaderView: View {
    @Binding var currentMonth: Date
    @Binding var viewMode: CalendarViewMode
    let selectedDate: Date

    var body: some View {
        VStack(spacing: AzmySpacing.md) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(AzmyColors.accentBlue)
                }

                Spacer()

                Text(monthYearString)
                    .font(AzmyFonts.headline2())
                    .foregroundColor(AzmyColors.textPrimary)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(AzmyColors.accentBlue)
                }
            }
            .padding(.horizontal, AzmySpacing.lg)

            // Weekday headers
            HStack {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day.prefix(3))
                        .font(AzmyFonts.caption())
                        .foregroundColor(AzmyColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AzmySpacing.md)
        }
        .padding(.vertical, AzmySpacing.md)
        .background(AzmyColors.backgroundPrimary)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private func previousMonth() {
        withAnimation {
            currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }

    private func nextMonth() {
        withAnimation {
            currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

// MARK: - Month Calendar View
struct MonthCalendarView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let events: [CalendarEvent]

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: AzmySpacing.xs) {
            ForEach(daysInMonth(), id: \.self) { date in
                if let date = date {
                    DayCell(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isToday: Calendar.current.isDateInToday(date),
                        events: eventsFor(date)
                    ) {
                        selectedDate = date
                    }
                } else {
                    Color.clear
                        .frame(height: 50)
                }
            }
        }
        .padding(.horizontal, AzmySpacing.md)
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        // Fill remaining cells
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func eventsFor(_ date: Date) -> [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let events: [CalendarEvent]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(AzmyFonts.body())
                    .foregroundColor(textColor)
                    .frame(width: 36, height: 36)
                    .background(backgroundColor)
                    .clipShape(Circle())

                // Event indicators
                HStack(spacing: 2) {
                    ForEach(events.prefix(3)) { event in
                        Circle()
                            .fill(colorFor(event.category))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(height: 50)
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return AzmyColors.accentBlue }
        return AzmyColors.textPrimary
    }

    private var backgroundColor: Color {
        if isSelected { return AzmyColors.accentBlue }
        if isToday { return AzmyColors.accentBlue.opacity(0.2) }
        return Color.clear
    }

    private func colorFor(_ category: EventCategory) -> Color {
        switch category {
        case .work: return .blue
        case .personal: return .purple
        case .health: return .green
        case .social: return .orange
        case .learning: return .yellow
        case .focus: return .indigo
        case .other: return .gray
        }
    }
}

// MARK: - Week Calendar View
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]

    var body: some View {
        VStack(spacing: 0) {
            // Week days row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AzmySpacing.sm) {
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
                .padding(.horizontal, AzmySpacing.md)
            }
            .padding(.vertical, AzmySpacing.md)

            // Time slots with events
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(8..<22, id: \.self) { hour in
                        TimeSlotRow(hour: hour, events: eventsForHour(hour))
                    }
                }
                .padding(.horizontal, AzmySpacing.md)
            }
        }
    }

    private func weekDays() -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!

        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }

    private func eventsForHour(_ hour: Int) -> [CalendarEvent] {
        events.filter { event in
            let eventHour = Calendar.current.component(.hour, from: event.startDate)
            return Calendar.current.isDate(event.startDate, inSameDayAs: selectedDate) && eventHour == hour
        }
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
                Text(dayOfWeek)
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(AzmyFonts.bodyLarge())
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : (isToday ? AzmyColors.accentBlue : AzmyColors.textPrimary))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? AzmyColors.accentBlue : Color.clear)
                    .clipShape(Circle())
            }
            .padding(.horizontal, AzmySpacing.xs)
        }
        .buttonStyle(.plain)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct TimeSlotRow: View {
    let hour: Int
    let events: [CalendarEvent]

    var body: some View {
        HStack(alignment: .top, spacing: AzmySpacing.md) {
            Text(String(format: "%02d:00", hour))
                .font(AzmyFonts.caption())
                .foregroundColor(AzmyColors.textTertiary)
                .frame(width: 50, alignment: .trailing)

            VStack(spacing: 4) {
                Divider()
                    .background(AzmyColors.separator)

                ForEach(events) { event in
                    EventSlotView(event: event)
                }
            }
        }
        .frame(minHeight: 60)
    }
}

struct EventSlotView: View {
    let event: CalendarEvent

    var body: some View {
        HStack {
            Rectangle()
                .fill(colorFor(event.category))
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(AzmyFonts.bodySmall())
                    .foregroundColor(AzmyColors.textPrimary)
                    .lineLimit(1)

                Text(event.formattedTime)
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)
            }

            Spacer()
        }
        .padding(AzmySpacing.sm)
        .background(colorFor(event.category).opacity(0.15))
        .cornerRadius(AzmyRadius.small)
    }

    private func colorFor(_ category: EventCategory) -> Color {
        switch category {
        case .work: return .blue
        case .personal: return .purple
        case .health: return .green
        case .social: return .orange
        case .learning: return .yellow
        case .focus: return .indigo
        case .other: return .gray
        }
    }
}

// MARK: - Events List View
struct EventsListView: View {
    let date: Date
    let events: [CalendarEvent]
    let onEventTap: (CalendarEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AzmySpacing.sm) {
            if events.isEmpty {
                Text("No events")
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AzmySpacing.xl)
            } else {
                ForEach(events) { event in
                    EventRowView(event: event)
                        .onTapGesture {
                            onEventTap(event)
                        }
                }
            }
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundSecondary)
    }
}

struct EventRowView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: AzmySpacing.md) {
            Rectangle()
                .fill(colorFor(event.category))
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textPrimary)

                Text(event.formattedTime)
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)
            }

            Spacer()

            if let location = event.location, !location.isEmpty {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(AzmyColors.textTertiary)
            }
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
    }

    private func colorFor(_ category: EventCategory) -> Color {
        switch category {
        case .work: return .blue
        case .personal: return .purple
        case .health: return .green
        case .social: return .orange
        case .learning: return .yellow
        case .focus: return .indigo
        case .other: return .gray
        }
    }
}

// MARK: - Event Detail View
struct EventDetailView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: AzmySpacing.lg) {
                    // Event card preview
                    VStack(alignment: .leading, spacing: AzmySpacing.md) {
                        Text(formattedDate)
                            .font(AzmyFonts.caption())
                            .foregroundColor(AzmyColors.textTertiary)

                        Text(event.formattedTime)
                            .font(AzmyFonts.bodySmall())
                            .foregroundColor(AzmyColors.textSecondary)

                        HStack {
                            Rectangle()
                                .fill(colorFor(event.category))
                                .frame(width: 4)

                            Text(event.title)
                                .font(AzmyFonts.body())
                                .foregroundColor(AzmyColors.textPrimary)
                        }
                    }
                    .padding(AzmySpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AzmyColors.backgroundCard)
                    .cornerRadius(AzmyRadius.medium)

                    Spacer()

                    // Action buttons
                    VStack(spacing: AzmySpacing.sm) {
                        Button(action: {}) {
                            Text("Edit")
                                .font(AzmyFonts.bodyLarge())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AzmySpacing.md)
                                .background(AzmyColors.accentBlue)
                                .cornerRadius(AzmyRadius.medium)
                        }

                        Button(action: { dismiss() }) {
                            Text("Close")
                                .font(AzmyFonts.bodyLarge())
                                .foregroundColor(AzmyColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AzmySpacing.md)
                                .background(AzmyColors.backgroundCard)
                                .cornerRadius(AzmyRadius.medium)
                        }
                    }
                }
                .padding(AzmySpacing.lg)
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: event.startDate)
    }

    private func colorFor(_ category: EventCategory) -> Color {
        switch category {
        case .work: return .blue
        case .personal: return .purple
        case .health: return .green
        case .social: return .orange
        case .learning: return .yellow
        case .focus: return .indigo
        case .other: return .gray
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(PlannerViewModel())
        .environmentObject(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
