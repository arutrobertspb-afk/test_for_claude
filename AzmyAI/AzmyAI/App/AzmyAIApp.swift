//
//  AzmyAIApp.swift
//  AzmyAI
//
//  Personal AI Assistant for daily life optimization
//

import SwiftUI

@main
struct AzmyAIApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var userProfile = UserProfileViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var plannerViewModel = PlannerViewModel()
    @StateObject private var quizViewModel = QuizViewModel()

    // Shared services
    private let authService = AuthenticationService.shared
    private let googleCalendarService = GoogleCalendarService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(userProfile)
                .environmentObject(chatViewModel)
                .environmentObject(plannerViewModel)
                .environmentObject(quizViewModel)
                .onOpenURL { url in
                    // Handle OAuth callback URLs
                    handleOAuthCallback(url)
                }
        }
    }

    private func handleOAuthCallback(_ url: URL) {
        // Handle Google OAuth callback
        if url.scheme == "com.azmy.ai" {
            // The callback is handled by ASWebAuthenticationSession
            print("OAuth callback received: \(url)")
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool {
        didSet {
            UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete")
        }
    }
    @Published var selectedTab: TabSelection = .chat
    @Published var isLoading = false

    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    }
}

enum TabSelection: Int, CaseIterable {
    case chat = 0
    case calendar = 1
    case insights = 2
    case statistic = 3
    case profile = 4

    var title: String {
        switch self {
        case .chat: return "Home"
        case .calendar: return "Calendar"
        case .insights: return "Insights"
        case .statistic: return "Statistic"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "house.fill"
        case .calendar: return "calendar"
        case .insights: return "lightbulb.fill"
        case .statistic: return "clock.fill"
        case .profile: return "person.circle.fill"
        }
    }
}
