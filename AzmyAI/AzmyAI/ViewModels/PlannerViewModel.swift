//
//  PlannerViewModel.swift
//  AzmyAI
//

import Foundation
import Combine

class PlannerViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var events: [CalendarEvent] = []
    @Published var tasks: [PlannerTask] = []
    @Published var recommendations: [AIRecommendation] = []
    @Published var isLoading = false
    @Published var showEventCreator = false
    @Published var showTaskCreator = false

    private let calendarService = CalendarService()
    private var cancellables = Set<AnyCancellable>()

    private let tasksKey = "plannerTasks"

    init() {
        loadTasks()
        generateSampleRecommendations()
    }

    // MARK: - Date Navigation
    func selectDate(_ date: Date) {
        selectedDate = date
        Task {
            await fetchEventsForSelectedDate()
        }
    }

    func goToToday() {
        selectDate(Date())
    }

    func goToPreviousDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectDate(newDate)
        }
    }

    func goToNextDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectDate(newDate)
        }
    }

    // MARK: - Events
    func fetchEventsForSelectedDate() async {
        await MainActor.run { isLoading = true }

        do {
            let startOfDay = Calendar.current.startOfDay(for: selectedDate)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            let fetchedEvents = try await calendarService.fetchEvents(from: startOfDay, to: endOfDay)

            await MainActor.run {
                self.events = fetchedEvents.sorted { $0.startDate < $1.startDate }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Error fetching events: \(error)")
        }
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil
    ) async {
        do {
            let event = try await calendarService.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location,
                notes: notes
            )

            await MainActor.run {
                self.events.append(event)
                self.events.sort { $0.startDate < $1.startDate }
            }
        } catch {
            print("Error creating event: \(error)")
        }
    }

    // MARK: - Tasks
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let savedTasks = try? JSONDecoder().decode([PlannerTask].self, from: data) {
            tasks = savedTasks
        } else {
            // Add sample tasks for demo
            tasks = [
                PlannerTask(
                    title: "Review weekly goals",
                    priority: .high,
                    category: .work,
                    estimatedDuration: 1800,
                    isAISuggested: true
                ),
                PlannerTask(
                    title: "30-minute walk",
                    priority: .medium,
                    category: .health,
                    estimatedDuration: 1800,
                    isAISuggested: true
                ),
                PlannerTask(
                    title: "Prepare for tomorrow's meeting",
                    priority: .medium,
                    category: .work,
                    estimatedDuration: 2700
                )
            ]
        }
    }

    func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: tasksKey)
        }
    }

    func addTask(_ task: PlannerTask) {
        tasks.append(task)
        saveTasks()
    }

    func toggleTaskCompletion(_ task: PlannerTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            saveTasks()
        }
    }

    func deleteTask(_ task: PlannerTask) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }

    func updateTask(_ task: PlannerTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }

    // MARK: - Recommendations
    private func generateSampleRecommendations() {
        let hour = Calendar.current.component(.hour, from: Date())

        var recs: [AIRecommendation] = []

        if hour >= 9 && hour <= 11 {
            recs.append(AIRecommendation(
                type: .productivity,
                title: "Peak Energy Window",
                description: "Your morning energy is high. Perfect time for deep work tasks.",
                actionText: "Block focus time"
            ))
        }

        if hour >= 14 && hour <= 15 {
            recs.append(AIRecommendation(
                type: .break_,
                title: "Afternoon Dip",
                description: "Energy tends to drop after lunch. A short walk can help.",
                actionText: "Schedule break"
            ))
        }

        recs.append(AIRecommendation(
            type: .health,
            title: "Movement Reminder",
            description: "You've been sitting for a while. Time for a quick stretch?",
            actionText: "Start stretch routine"
        ))

        recommendations = recs
    }

    func dismissRecommendation(_ recommendation: AIRecommendation) {
        if let index = recommendations.firstIndex(where: { $0.id == recommendation.id }) {
            recommendations[index].isDismissed = true
            recommendations.remove(at: index)
        }
    }

    // MARK: - Helpers
    var todayTasks: [PlannerTask] {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return true }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }

    var completedTasksCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    var pendingTasksCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    var selectedDateFormatted: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
}
