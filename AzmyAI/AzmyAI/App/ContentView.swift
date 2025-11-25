//
//  ContentView.swift
//  AzmyAI
//
//  Dark theme app container
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userProfile: UserProfileViewModel

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

                PlannerView()
                    .tabItem {
                        Label(TabSelection.planner.title, systemImage: TabSelection.planner.icon)
                    }
                    .tag(TabSelection.planner)

                InsightsView()
                    .tabItem {
                        Label(TabSelection.insights.title, systemImage: TabSelection.insights.icon)
                    }
                    .tag(TabSelection.insights)

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

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(UserProfileViewModel())
        .environmentObject(ChatViewModel())
        .environmentObject(PlannerViewModel())
}
