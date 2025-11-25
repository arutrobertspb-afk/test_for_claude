//
//  OnboardingView.swift
//  AzmyAI
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userProfile: UserProfileViewModel

    @State private var currentStep = 0
    @State private var userName = ""
    @State private var selectedGoals: Set<LifeGoal> = []
    @State private var selectedChronotype: Chronotype = .neutral
    @State private var selectedWorkStyle: WorkStyle = .balanced

    private let totalSteps = 5

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "4F46E5").opacity(0.1), Color(hex: "7C3AED").opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                ProgressBar(progress: Double(currentStep + 1) / Double(totalSteps))
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)

                // Content
                TabView(selection: $currentStep) {
                    WelcomeStep(userName: $userName)
                        .tag(0)

                    GoalsStep(selectedGoals: $selectedGoals)
                        .tag(1)

                    ChronotypeStep(selectedChronotype: $selectedChronotype)
                        .tag(2)

                    WorkStyleStep(selectedWorkStyle: $selectedWorkStyle)
                        .tag(3)

                    PermissionsStep()
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.azurySmooth, value: currentStep)

                // Navigation buttons
                HStack(spacing: Spacing.md) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .buttonStyle(AzuryButtonStyle(isSecondary: true))
                    }

                    Spacer()

                    Button(currentStep == totalSteps - 1 ? "Get Started" : "Continue") {
                        if currentStep == totalSteps - 1 {
                            completeOnboarding()
                        } else {
                            withAnimation { currentStep += 1 }
                        }
                    }
                    .buttonStyle(AzuryButtonStyle())
                    .disabled(!canProceed)
                    .opacity(canProceed ? 1 : 0.5)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return !userName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !selectedGoals.isEmpty
        default: return true
        }
    }

    private func completeOnboarding() {
        // Save user data
        userProfile.updateName(userName)

        // Save quiz results
        var traits = PersonalityTraits()
        traits.chronotype = selectedChronotype
        traits.workStyle = selectedWorkStyle
        userProfile.profile.personalityTraits = traits

        var preferences = LifestylePreferences()
        preferences.primaryGoals = Array(selectedGoals)
        userProfile.profile.lifestylePreferences = preferences

        // Request permissions
        Task {
            await userProfile.requestHealthAccess()
            await userProfile.requestCalendarAccess()
        }

        // Complete onboarding
        withAnimation {
            appState.isOnboardingComplete = true
        }
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.azuryGradient)
                    .frame(width: geometry.size.width * progress, height: 6)
                    .animation(.azurySmooth, value: progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    @Binding var userName: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.azuryGradient)

            Text("Welcome to Azmy")
                .font(.azuryLargeTitle)

            Text("Your personal AI assistant for optimizing daily life")
                .font(.azuryBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("What's your name?")
                    .font(.azuryHeadline)

                TextField("Enter your name", text: $userName)
                    .textFieldStyle(AzuryTextFieldStyle())
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Goals Step
struct GoalsStep: View {
    @Binding var selectedGoals: Set<LifeGoal>

    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text("What are your goals?")
                    .font(.azuryTitle)

                Text("Select all that apply")
                    .font(.azurySubheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, Spacing.xl)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                ForEach(LifeGoal.allCases, id: \.self) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }
}

struct GoalCard: View {
    let goal: LifeGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: iconForGoal(goal))
                    .font(.title2)

                Text(goal.rawValue)
                    .font(.azuryFootnote)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                isSelected
                    ? AnyView(Color.azuryGradient.opacity(0.2))
                    : AnyView(Color.azurySecondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.azuryBlue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }

    private func iconForGoal(_ goal: LifeGoal) -> String {
        switch goal {
        case .productivity: return "chart.line.uptrend.xyaxis"
        case .health: return "heart.fill"
        case .balance: return "scale.3d"
        case .fitness: return "figure.run"
        case .learning: return "book.fill"
        case .relationships: return "person.2.fill"
        case .stress: return "leaf.fill"
        case .sleep: return "moon.fill"
        }
    }
}

// MARK: - Chronotype Step
struct ChronotypeStep: View {
    @Binding var selectedChronotype: Chronotype

    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text("When do you feel most energetic?")
                    .font(.azuryTitle)
                    .multilineTextAlignment(.center)

                Text("This helps us optimize your schedule")
                    .font(.azurySubheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.sm) {
                ForEach(Chronotype.allCases, id: \.self) { type in
                    ChronotypeCard(
                        chronotype: type,
                        isSelected: selectedChronotype == type
                    ) {
                        selectedChronotype = type
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }
}

struct ChronotypeCard: View {
    let chronotype: Chronotype
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: iconForChronotype)
                    .font(.title)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(chronotype.rawValue)
                        .font(.azuryHeadline)

                    Text(chronotype.description)
                        .font(.azuryCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.azuryGradient)
                }
            }
            .padding(Spacing.md)
            .background(
                isSelected
                    ? AnyView(Color.azuryGradient.opacity(0.1))
                    : AnyView(Color.azurySecondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.azuryBlue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }

    private var iconForChronotype: String {
        switch chronotype {
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .neutral: return "sun.max.fill"
        }
    }
}

// MARK: - Work Style Step
struct WorkStyleStep: View {
    @Binding var selectedWorkStyle: WorkStyle

    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text("How do you prefer to work?")
                    .font(.azuryTitle)

                Text("We'll tailor recommendations to your style")
                    .font(.azurySubheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, Spacing.xl)

            VStack(spacing: Spacing.sm) {
                ForEach(WorkStyle.allCases, id: \.self) { style in
                    WorkStyleCard(
                        style: style,
                        isSelected: selectedWorkStyle == style
                    ) {
                        selectedWorkStyle = style
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }
}

struct WorkStyleCard: View {
    let style: WorkStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: iconForStyle)
                    .font(.title)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(style.rawValue)
                        .font(.azuryHeadline)

                    Text(descriptionForStyle)
                        .font(.azuryCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.azuryGradient)
                }
            }
            .padding(Spacing.md)
            .background(
                isSelected
                    ? AnyView(Color.azuryGradient.opacity(0.1))
                    : AnyView(Color.azurySecondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? Color.azuryBlue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }

    private var iconForStyle: String {
        switch style {
        case .deepWork: return "brain.head.profile"
        case .collaborative: return "person.3.fill"
        case .balanced: return "arrow.left.arrow.right"
        }
    }

    private var descriptionForStyle: String {
        switch style {
        case .deepWork: return "Long focus sessions, minimal interruptions"
        case .collaborative: return "Frequent meetings and teamwork"
        case .balanced: return "Mix of focused and collaborative work"
        }
    }
}

// MARK: - Permissions Step
struct PermissionsStep: View {
    @EnvironmentObject var userProfile: UserProfileViewModel

    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text("Connect Your Data")
                    .font(.azuryTitle)

                Text("Azmy works best with access to your calendar and health data")
                    .font(.azurySubheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.md) {
                PermissionCard(
                    icon: "calendar",
                    title: "Calendar",
                    description: "Plan your day and create events automatically",
                    isConnected: userProfile.calendarService.isAuthorized
                ) {
                    Task { await userProfile.requestCalendarAccess() }
                }

                PermissionCard(
                    icon: "heart.fill",
                    title: "Health",
                    description: "Get insights based on sleep, activity, and more",
                    isConnected: userProfile.healthService.isAuthorized
                ) {
                    Task { await userProfile.requestHealthAccess() }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Text("You can change these permissions later in Settings")
                .font(.azuryCaption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isConnected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(Color.azuryGradient)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.azuryHeadline)

                Text(description)
                    .font(.azuryCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: action) {
                Text(isConnected ? "Connected" : "Connect")
                    .font(.azuryFootnote)
                    .fontWeight(.medium)
                    .foregroundColor(isConnected ? .green : .white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        isConnected
                            ? AnyView(Color.green.opacity(0.2))
                            : AnyView(Color.azuryGradient)
                    )
                    .cornerRadius(CornerRadius.small)
            }
        }
        .padding(Spacing.md)
        .background(Color.azurySecondaryBackground)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Custom Text Field Style
struct AzuryTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Spacing.md)
            .background(Color.azurySecondaryBackground)
            .cornerRadius(CornerRadius.medium)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(UserProfileViewModel())
}
