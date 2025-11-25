//
//  ContentView.swift
//  AzmyAI
//
//  Dark theme app container with 5-tab navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userProfile: UserProfileViewModel
    @EnvironmentObject var quizViewModel: QuizViewModel

    @State private var showQuiz = false

    var body: some View {
        Group {
            if !appState.isOnboardingComplete {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isOnboardingComplete)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showQuiz) {
            QuizContainerView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showQuiz)) { notification in
            if let quiz = notification.object as? Quiz {
                quizViewModel.startQuiz(quiz)
                showQuiz = true
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            TabView(selection: $appState.selectedTab) {
                ChatView()
                    .tabItem {
                        Label(TabSelection.chat.title, systemImage: TabSelection.chat.icon)
                    }
                    .tag(TabSelection.chat)

                CalendarView()
                    .tabItem {
                        Label(TabSelection.calendar.title, systemImage: TabSelection.calendar.icon)
                    }
                    .tag(TabSelection.calendar)

                InsightsView()
                    .tabItem {
                        Label(TabSelection.insights.title, systemImage: TabSelection.insights.icon)
                    }
                    .tag(TabSelection.insights)

                PlannerView()
                    .tabItem {
                        Label(TabSelection.planner.title, systemImage: TabSelection.planner.icon)
                    }
                    .tag(TabSelection.planner)

                ProfileView()
                    .tabItem {
                        Label(TabSelection.profile.title, systemImage: TabSelection.profile.icon)
                    }
                    .tag(TabSelection.profile)
            }
            .tint(AzmyColors.accentBlue)
        }
    }
}

// MARK: - Notification for Quiz
extension Notification.Name {
    static let showQuiz = Notification.Name("showQuiz")
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(UserProfileViewModel())
        .environmentObject(ChatViewModel())
        .environmentObject(PlannerViewModel())
        .environmentObject(QuizViewModel())
}
