//
//  UserProfileViewModel.swift
//  AzmyAI
//

import Foundation
import Combine

class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var healthService = HealthKitService()
    @Published var calendarService = CalendarService()

    private let userDefaultsKey = "userProfile"
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load saved profile or create new one
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = savedProfile
        } else {
            self.profile = UserProfile()
        }

        // Auto-save on changes
        $profile
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] profile in
                self?.saveProfile(profile)
            }
            .store(in: &cancellables)
    }

    // MARK: - Profile Management
    func saveProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func updateName(_ name: String) {
        profile.name = name
    }

    func updateEmail(_ email: String) {
        profile.email = email
    }

    // MARK: - Quiz Handling
    func saveQuizAnswer(_ answer: QuizAnswer) {
        profile.quizAnswers.append(answer)
    }

    func processQuizResults() {
        // Analyze quiz answers to build personality profile
        var traits = PersonalityTraits()
        let preferences = LifestylePreferences()

        // Process each answer and update traits/preferences
        for answer in profile.quizAnswers {
            // This would be more sophisticated in production
            // For now, we'll use simple logic

            if answer.answerValue.lowercased().contains("morning") {
                traits.chronotype = .earlyBird
            } else if answer.answerValue.lowercased().contains("night") {
                traits.chronotype = .nightOwl
            }

            if answer.answerValue.lowercased().contains("alone") ||
               answer.answerValue.lowercased().contains("quiet") {
                traits.socialPreference = .introvert
            } else if answer.answerValue.lowercased().contains("people") ||
                      answer.answerValue.lowercased().contains("social") {
                traits.socialPreference = .extrovert
            }
        }

        profile.personalityTraits = traits
        profile.lifestylePreferences = preferences
    }

    // MARK: - Preferences
    func updateSleepGoal(_ hours: Double) {
        profile.sleepGoal = hours
    }

    func updateStepsGoal(_ steps: Int) {
        profile.dailyStepsGoal = steps
    }

    func toggleNotifications(_ enabled: Bool) {
        profile.notificationsEnabled = enabled
    }

    // MARK: - Health Data
    func requestHealthAccess() async {
        do {
            try await healthService.requestAuthorization()
        } catch {
            print("Health access error: \(error)")
        }
    }

    func fetchHealthData() async {
        do {
            let snapshot = try await healthService.fetchHealthSnapshot()
            await MainActor.run {
                profile.healthData = snapshot
            }
        } catch {
            print("Health fetch error: \(error)")
        }
    }

    // MARK: - Calendar Access
    func requestCalendarAccess() async {
        do {
            try await calendarService.requestAuthorization()
        } catch {
            print("Calendar access error: \(error)")
        }
    }

    // MARK: - Reset
    func resetProfile() {
        profile = UserProfile()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
