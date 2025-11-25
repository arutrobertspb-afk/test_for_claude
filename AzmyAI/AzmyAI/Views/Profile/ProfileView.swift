//
//  ProfileView.swift
//  AzmyAI
//
//  Dark theme profile and settings
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userProfile: UserProfileViewModel
    @EnvironmentObject var appState: AppState

    @State private var showAPIKeySheet = false
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                List {
                    // Profile Header
                    Section {
                        ProfileHeader(profile: userProfile.profile)
                    }
                    .listRowBackground(Color.clear)

                    // Personality & Preferences
                    Section("Your Profile") {
                        if let traits = userProfile.profile.personalityTraits {
                            ProfileRow(
                                icon: "sunrise.fill",
                                title: "Chronotype",
                                value: traits.chronotype.rawValue
                            )

                            ProfileRow(
                                icon: "bolt.fill",
                                title: "Energy Pattern",
                                value: traits.energyPattern.rawValue
                            )

                            ProfileRow(
                                icon: "briefcase.fill",
                                title: "Work Style",
                                value: traits.workStyle.rawValue
                            )
                        }

                        NavigationLink {
                            GoalsEditView()
                        } label: {
                            ProfileRow(
                                icon: "target",
                                title: "Goals",
                                value: "\(userProfile.profile.lifestylePreferences?.primaryGoals.count ?? 0) selected"
                            )
                        }
                    }
                    .listRowBackground(AzmyColors.backgroundCard)

                    // Connections
                    Section("Connections") {
                        ConnectionRow(
                            icon: "calendar",
                            title: "Calendar",
                            isConnected: userProfile.calendarService.isAuthorized
                        ) {
                            Task { await userProfile.requestCalendarAccess() }
                        }

                        ConnectionRow(
                            icon: "heart.fill",
                            title: "Apple Health",
                            isConnected: userProfile.healthService.isAuthorized
                        ) {
                            Task { await userProfile.requestHealthAccess() }
                        }
                    }
                    .listRowBackground(AzmyColors.backgroundCard)

                    // Settings
                    Section("Settings") {
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            SettingsRow(icon: "bell.fill", title: "Notifications")
                        }

                        NavigationLink {
                            GoalsSettingsView()
                        } label: {
                            SettingsRow(icon: "target", title: "Daily Goals")
                        }

                        Button {
                            showAPIKeySheet = true
                        } label: {
                            SettingsRow(icon: "key.fill", title: "API Settings")
                        }
                    }
                    .listRowBackground(AzmyColors.backgroundCard)

                    // About
                    Section("About") {
                        Link(destination: URL(string: "https://azmy.ai/privacy")!) {
                            SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy")
                        }

                        Link(destination: URL(string: "https://azmy.ai/terms")!) {
                            SettingsRow(icon: "doc.text.fill", title: "Terms of Service")
                        }

                        HStack {
                            SettingsRow(icon: "info.circle.fill", title: "Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(AzmyColors.textSecondary)
                        }
                    }
                    .listRowBackground(AzmyColors.backgroundCard)

                    // Danger Zone
                    Section {
                        Button(role: .destructive) {
                            showResetAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Reset App Data")
                            }
                        }
                    }
                    .listRowBackground(AzmyColors.backgroundCard)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showAPIKeySheet) {
                APIKeySheet()
            }
            .alert("Reset App Data", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    userProfile.resetProfile()
                    appState.isOnboardingComplete = false
                }
            } message: {
                Text("This will delete all your data and preferences. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeader: View {
    let profile: UserProfile

    var body: some View {
        VStack(spacing: AzmySpacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AzmyColors.gradientBlue)
                    .frame(width: 80, height: 80)

                Text(profile.name.prefix(1).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(profile.name.isEmpty ? "User" : profile.name)
                .font(AzmyFonts.headline2())
                .foregroundColor(AzmyColors.textPrimary)

            Text("Member since \(profile.createdAt.formatted(.dateTime.month().year()))")
                .font(AzmyFonts.caption())
                .foregroundColor(AzmyColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AzmySpacing.md)
    }
}

// MARK: - Profile Row
struct ProfileRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AzmyColors.gradientBlue)
                .frame(width: 24)

            Text(title)
                .foregroundColor(AzmyColors.textPrimary)

            Spacer()

            Text(value)
                .foregroundColor(AzmyColors.textSecondary)
        }
    }
}

// MARK: - Connection Row
struct ConnectionRow: View {
    let icon: String
    let title: String
    let isConnected: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AzmyColors.gradientBlue)
                .frame(width: 24)

            Text(title)
                .foregroundColor(AzmyColors.textPrimary)

            Spacer()

            Button(action: action) {
                Text(isConnected ? "Connected" : "Connect")
                    .font(AzmyFonts.bodySmall())
                    .fontWeight(.medium)
                    .foregroundColor(isConnected ? .green : AzmyColors.accentBlue)
                    .padding(.horizontal, AzmySpacing.sm)
                    .padding(.vertical, AzmySpacing.xs)
                    .background(
                        isConnected
                            ? Color.green.opacity(0.1)
                            : AzmyColors.accentBlue.opacity(0.1)
                    )
                    .cornerRadius(AzmyRadius.small)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AzmyColors.gradientBlue)
                .frame(width: 24)

            Text(title)
                .foregroundColor(AzmyColors.textPrimary)
        }
    }
}

// MARK: - Goals Edit View
struct GoalsEditView: View {
    @EnvironmentObject var userProfile: UserProfileViewModel
    @State private var selectedGoals: Set<LifeGoal> = []

    var body: some View {
        ZStack {
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            List {
                ForEach(LifeGoal.allCases, id: \.self) { goal in
                    Button {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    } label: {
                        HStack {
                            Text(goal.rawValue)
                                .foregroundColor(AzmyColors.textPrimary)

                            Spacer()

                            if selectedGoals.contains(goal) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AzmyColors.gradientBlue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AzmyColors.backgroundCard)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            selectedGoals = Set(userProfile.profile.lifestylePreferences?.primaryGoals ?? [])
        }
        .onDisappear {
            var prefs = userProfile.profile.lifestylePreferences ?? LifestylePreferences()
            prefs.primaryGoals = Array(selectedGoals)
            userProfile.profile.lifestylePreferences = prefs
        }
    }
}

// MARK: - Notification Settings
struct NotificationSettingsView: View {
    @EnvironmentObject var userProfile: UserProfileViewModel

    var body: some View {
        ZStack {
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            Form {
                Section {
                    Toggle("Enable Notifications", isOn: Binding(
                        get: { userProfile.profile.notificationsEnabled },
                        set: { userProfile.toggleNotifications($0) }
                    ))
                }
                .listRowBackground(AzmyColors.backgroundCard)

                Section("Reminders") {
                    DatePicker(
                        "Morning Check-in",
                        selection: Binding(
                            get: { userProfile.profile.morningReminderTime },
                            set: { userProfile.profile.morningReminderTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "Evening Reflection",
                        selection: Binding(
                            get: { userProfile.profile.eveningReminderTime },
                            set: { userProfile.profile.eveningReminderTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
                .listRowBackground(AzmyColors.backgroundCard)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Goals Settings
struct GoalsSettingsView: View {
    @EnvironmentObject var userProfile: UserProfileViewModel

    var body: some View {
        ZStack {
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            Form {
                Section("Sleep") {
                    HStack {
                        Text("Daily Goal")
                            .foregroundColor(AzmyColors.textPrimary)
                        Spacer()
                        Text("\(Int(userProfile.profile.sleepGoal)) hours")
                            .foregroundColor(AzmyColors.textSecondary)
                    }

                    Slider(
                        value: Binding(
                            get: { userProfile.profile.sleepGoal },
                            set: { userProfile.updateSleepGoal($0) }
                        ),
                        in: 5...12,
                        step: 0.5
                    )
                    .tint(AzmyColors.accentBlue)
                }
                .listRowBackground(AzmyColors.backgroundCard)

                Section("Activity") {
                    HStack {
                        Text("Daily Steps Goal")
                            .foregroundColor(AzmyColors.textPrimary)
                        Spacer()
                        Text("\(userProfile.profile.dailyStepsGoal)")
                            .foregroundColor(AzmyColors.textSecondary)
                    }

                    Stepper(
                        "",
                        value: Binding(
                            get: { userProfile.profile.dailyStepsGoal },
                            set: { userProfile.updateStepsGoal($0) }
                        ),
                        in: 1000...30000,
                        step: 1000
                    )
                }
                .listRowBackground(AzmyColors.backgroundCard)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Daily Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - API Key Sheet
struct APIKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                Form {
                    Section {
                        SecureField("OpenAI API Key", text: $apiKey)
                    } footer: {
                        Text("Your API key is stored securely on your device and is never sent to our servers.")
                            .foregroundColor(AzmyColors.textSecondary)
                    }
                    .listRowBackground(AzmyColors.backgroundCard)

                    Section {
                        Link("Get an API key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .foregroundColor(AzmyColors.accentBlue)
                    }
                    .listRowBackground(AzmyColors.backgroundCard)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("API Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AzmyColors.accentBlue)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        UserDefaults.standard.set(apiKey, forKey: "openai_api_key")
                        dismiss()
                    }
                    .foregroundColor(AzmyColors.accentBlue)
                }
            }
            .onAppear {
                apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserProfileViewModel())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
