//
//  PlannerView.swift
//  AzmyAI
//

import SwiftUI

struct PlannerView: View {
    @EnvironmentObject var plannerViewModel: PlannerViewModel
    @EnvironmentObject var userProfile: UserProfileViewModel

    @State private var showEventSheet = false
    @State private var showTaskSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    // Date navigation
                    DateNavigationBar(
                        dateString: plannerViewModel.selectedDateFormatted,
                        onPrevious: { plannerViewModel.goToPreviousDay() },
                        onNext: { plannerViewModel.goToNextDay() },
                        onToday: { plannerViewModel.goToToday() }
                    )

                    // AI Recommendations
                    if !plannerViewModel.recommendations.isEmpty {
                        RecommendationsSection(
                            recommendations: plannerViewModel.recommendations,
                            onDismiss: { plannerViewModel.dismissRecommendation($0) }
                        )
                    }

                    // Today's Schedule
                    ScheduleSection(
                        events: plannerViewModel.events,
                        onAddEvent: { showEventSheet = true }
                    )

                    // Tasks
                    TasksSection(
                        tasks: plannerViewModel.todayTasks,
                        onToggle: { plannerViewModel.toggleTaskCompletion($0) },
                        onDelete: { plannerViewModel.deleteTask($0) },
                        onAdd: { showTaskSheet = true }
                    )
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("Planner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEventSheet = true
                        } label: {
                            Label("Add Event", systemImage: "calendar.badge.plus")
                        }

                        Button {
                            showTaskSheet = true
                        } label: {
                            Label("Add Task", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.azuryGradient)
                    }
                }
            }
            .refreshable {
                await plannerViewModel.fetchEventsForSelectedDate()
            }
            .sheet(isPresented: $showEventSheet) {
                CreateEventSheet { title, start, end, isAllDay in
                    Task {
                        await plannerViewModel.createEvent(
                            title: title,
                            startDate: start,
                            endDate: end,
                            isAllDay: isAllDay
                        )
                    }
                }
            }
            .sheet(isPresented: $showTaskSheet) {
                CreateTaskSheet { task in
                    plannerViewModel.addTask(task)
                }
            }
        }
        .onAppear {
            Task {
                await plannerViewModel.fetchEventsForSelectedDate()
            }
        }
    }
}

// MARK: - Date Navigation Bar
struct DateNavigationBar: View {
    let dateString: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.azuryBlue)
            }

            Spacer()

            Button(action: onToday) {
                Text(dateString)
                    .font(.azuryTitle3)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.azuryBlue)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Recommendations Section
struct RecommendationsSection: View {
    let recommendations: [AIRecommendation]
    let onDismiss: (AIRecommendation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.azuryGradient)
                Text("AI Insights")
                    .font(.azuryHeadline)
            }

            ForEach(recommendations.filter { !$0.isDismissed }) { rec in
                RecommendationCard(recommendation: rec) {
                    onDismiss(rec)
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: AIRecommendation
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: recommendation.type.icon)
                .font(.title2)
                .foregroundStyle(Color.azuryGradient)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(recommendation.title)
                    .font(.azuryHeadline)

                Text(recommendation.description)
                    .font(.azuryCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.md)
        .background(Color.azuryGradient.opacity(0.08))
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Schedule Section
struct ScheduleSection: View {
    let events: [CalendarEvent]
    let onAddEvent: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Schedule")
                    .font(.azuryHeadline)

                Spacer()

                Button(action: onAddEvent) {
                    Text("Add")
                        .font(.azuryFootnote)
                        .foregroundColor(.azuryBlue)
                }
            }

            if events.isEmpty {
                EmptyScheduleCard(onAdd: onAddEvent)
            } else {
                ForEach(events) { event in
                    EventCard(event: event)
                }
            }
        }
    }
}

struct EmptyScheduleCard: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No events today")
                .font(.azurySubheadline)
                .foregroundColor(.secondary)

            Button("Add Event", action: onAdd)
                .font(.azuryFootnote)
                .foregroundColor(.azuryBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(Color.azurySecondaryBackground)
        .cornerRadius(CornerRadius.medium)
    }
}

struct EventCard: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Time indicator
            Rectangle()
                .fill(colorForCategory(event.category))
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(event.title)
                    .font(.azuryHeadline)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(event.formattedTime)
                        .font(.azuryCaption)
                }
                .foregroundColor(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "location")
                            .font(.caption)
                        Text(location)
                            .font(.azuryCaption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: event.category.icon)
                .foregroundColor(colorForCategory(event.category))
        }
        .padding(Spacing.md)
        .background(Color.azurySecondaryBackground)
        .cornerRadius(CornerRadius.medium)
    }

    private func colorForCategory(_ category: EventCategory) -> Color {
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

// MARK: - Tasks Section
struct TasksSection: View {
    let tasks: [PlannerTask]
    let onToggle: (PlannerTask) -> Void
    let onDelete: (PlannerTask) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Tasks")
                    .font(.azuryHeadline)

                Spacer()

                Text("\(tasks.filter { $0.isCompleted }.count)/\(tasks.count)")
                    .font(.azuryCaption)
                    .foregroundColor(.secondary)
            }

            ForEach(tasks) { task in
                TaskCard(
                    task: task,
                    onToggle: { onToggle(task) },
                    onDelete: { onDelete(task) }
                )
            }

            Button {
                onAdd()
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add task")
                }
                .font(.azurySubheadline)
                .foregroundColor(.azuryBlue)
            }
            .padding(.top, Spacing.xs)
        }
    }
}

struct TaskCard: View {
    let task: PlannerTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(task.title)
                    .font(.azuryBody)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                if task.isAISuggested {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("AI suggested")
                            .font(.azuryCaption)
                    }
                    .foregroundColor(.azuryPurple)
                }
            }

            Spacer()

            Image(systemName: task.priority.icon)
                .font(.caption)
                .foregroundColor(colorForPriority(task.priority))
        }
        .padding(Spacing.sm)
        .background(Color.azurySecondaryBackground)
        .cornerRadius(CornerRadius.small)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func colorForPriority(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Create Event Sheet
struct CreateEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isAllDay = false

    let onCreate: (String, Date, Date, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Event title", text: $title)

                Toggle("All day", isOn: $isAllDay)

                DatePicker(
                    "Start",
                    selection: $startDate,
                    displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                )

                if !isAllDay {
                    DatePicker(
                        "End",
                        selection: $endDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(title, startDate, isAllDay ? Calendar.current.date(byAdding: .day, value: 1, to: startDate)! : endDate, isAllDay)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Create Task Sheet
struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var priority: TaskPriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    let onCreate: (PlannerTask) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Task title", text: $title)

                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Text(p.title).tag(p)
                    }
                }

                Toggle("Due date", isOn: $hasDueDate)

                if hasDueDate {
                    DatePicker("Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let task = PlannerTask(
                            title: title,
                            dueDate: hasDueDate ? dueDate : nil,
                            priority: priority
                        )
                        onCreate(task)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    PlannerView()
        .environmentObject(PlannerViewModel())
        .environmentObject(UserProfileViewModel())
}
