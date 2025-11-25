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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(userProfile)
                .environmentObject(chatViewModel)
                .environmentObject(plannerViewModel)
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
    case planner = 1
    case insights = 2
    case profile = 3

    var title: String {
        switch self {
        case .chat: return "Azmy"
        case .planner: return "Planner"
        case .insights: return "Insights"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .planner: return "calendar"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.circle.fill"
        }
    }
}
