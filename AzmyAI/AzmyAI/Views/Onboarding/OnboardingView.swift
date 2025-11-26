//
//  OnboardingView.swift
//  AzmyAI
//
//  Dark theme onboarding flow
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userProfile: UserProfileViewModel
    @ObservedObject var authService = AuthenticationService.shared

    @State private var currentStep = 0
    @State private var userName = ""
    @State private var selectedGoals: Set<LifeGoal> = []
    @State private var selectedChronotype: Chronotype = .neutral
    @State private var selectedWorkStyle: WorkStyle = .balanced

    private let totalSteps = 6

    var body: some View {
        ZStack {
            // Dark background with subtle gradient
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            LinearGradient(
                colors: [AzmyColors.accentBlue.opacity(0.1), AzmyColors.accentPurple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                ProgressBar(progress: Double(currentStep + 1) / Double(totalSteps))
                    .padding(.horizontal, AzmySpacing.lg)
                    .padding(.top, AzmySpacing.md)

                // Content
                TabView(selection: $currentStep) {
                    WelcomeStep(userName: $userName)
                        .tag(0)

                    SignInStep(onContinue: { withAnimation { currentStep += 1 } })
                        .tag(1)

                    GoalsStep(selectedGoals: $selectedGoals)
                        .tag(2)

                    ChronotypeStep(selectedChronotype: $selectedChronotype)
                        .tag(3)

                    WorkStyleStep(selectedWorkStyle: $selectedWorkStyle)
                        .tag(4)

                    PermissionsStep()
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                // Navigation buttons
                HStack(spacing: AzmySpacing.md) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .buttonStyle(AzmyButtonStyle(isSecondary: true))
                    }

                    Spacer()

                    Button(currentStep == totalSteps - 1 ? "Get Started" : "Continue") {
                        if currentStep == totalSteps - 1 {
                            completeOnboarding()
                        } else {
                            withAnimation { currentStep += 1 }
                        }
                    }
                    .buttonStyle(AzmyButtonStyle())
                    .disabled(!canProceed)
                    .opacity(canProceed ? 1 : 0.5)
                }
                .padding(.horizontal, AzmySpacing.lg)
                .padding(.bottom, AzmySpacing.xl)
            }
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return !userName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return true // Sign-in step - always can proceed (optional)
        case 2: return !selectedGoals.isEmpty
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
                    .fill(AzmyColors.backgroundTertiary)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(AzmyColors.gradientBlue)
                    .frame(width: geometry.size.width * progress, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    @Binding var userName: String

    var body: some View {
        VStack(spacing: AzmySpacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(AzmyColors.gradientBlue)

            Text("Welcome to Azmy")
                .font(AzmyFonts.headline1())
                .foregroundColor(AzmyColors.textPrimary)

            Text("Your personal AI assistant for optimizing daily life")
                .font(AzmyFonts.body())
                .foregroundColor(AzmyColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AzmySpacing.xl)

            VStack(alignment: .leading, spacing: AzmySpacing.xs) {
                Text("What's your name?")
                    .font(AzmyFonts.headline3())
                    .foregroundColor(AzmyColors.textPrimary)

                TextField("Enter your name", text: $userName)
                    .textFieldStyle(AzmyTextFieldStyle())
            }
            .padding(.horizontal, AzmySpacing.lg)
            .padding(.top, AzmySpacing.xl)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Goals Step
struct GoalsStep: View {
    @Binding var selectedGoals: Set<LifeGoal>

    var body: some View {
        VStack(spacing: AzmySpacing.lg) {
            VStack(spacing: AzmySpacing.sm) {
                Text("What are your goals?")
                    .font(AzmyFonts.headline1())
                    .foregroundColor(AzmyColors.textPrimary)

                Text("Select all that apply")
                    .font(AzmyFonts.bodyLarge())
                    .foregroundColor(AzmyColors.textSecondary)
            }
            .padding(.top, AzmySpacing.xl)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AzmySpacing.sm) {
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
            .padding(.horizontal, AzmySpacing.lg)

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
            VStack(spacing: AzmySpacing.xs) {
                Image(systemName: iconForGoal(goal))
                    .font(.title2)
                    .foregroundColor(isSelected ? AzmyColors.accentBlue : AzmyColors.textPrimary)

                Text(goal.rawValue)
                    .font(AzmyFonts.bodySmall())
                    .foregroundColor(isSelected ? AzmyColors.accentBlue : AzmyColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AzmySpacing.md)
            .background(
                isSelected
                    ? AzmyColors.accentBlue.opacity(0.15)
                    : AzmyColors.backgroundCard
            )
            .overlay(
                RoundedRectangle(cornerRadius: AzmyRadius.medium)
                    .stroke(isSelected ? AzmyColors.accentBlue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(AzmyRadius.medium)
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
        VStack(spacing: AzmySpacing.lg) {
            VStack(spacing: AzmySpacing.sm) {
                Text("When do you feel most energetic?")
                    .font(AzmyFonts.headline1())
                    .foregroundColor(AzmyColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("This helps us optimize your schedule")
                    .font(AzmyFonts.bodyLarge())
                    .foregroundColor(AzmyColors.textSecondary)
            }
            .padding(.top, AzmySpacing.xl)
            .padding(.horizontal, AzmySpacing.md)

            VStack(spacing: AzmySpacing.sm) {
                ForEach(Chronotype.allCases, id: \.self) { type in
                    ChronotypeCard(
                        chronotype: type,
                        isSelected: selectedChronotype == type
                    ) {
                        selectedChronotype = type
                    }
                }
            }
            .padding(.horizontal, AzmySpacing.lg)

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
            HStack(spacing: AzmySpacing.md) {
                Image(systemName: iconForChronotype)
                    .font(.title)
                    .foregroundColor(isSelected ? AzmyColors.accentBlue : AzmyColors.textPrimary)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: AzmySpacing.xxs) {
                    Text(chronotype.rawValue)
                        .font(AzmyFonts.headline3())
                        .foregroundColor(AzmyColors.textPrimary)

                    Text(chronotype.description)
                        .font(AzmyFonts.caption())
                        .foregroundColor(AzmyColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AzmyColors.gradientBlue)
                }
            }
            .padding(AzmySpacing.md)
            .background(
                isSelected
                    ? AzmyColors.accentBlue.opacity(0.1)
                    : AzmyColors.backgroundCard
            )
            .overlay(
                RoundedRectangle(cornerRadius: AzmyRadius.medium)
                    .stroke(isSelected ? AzmyColors.accentBlue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(AzmyRadius.medium)
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
        VStack(spacing: AzmySpacing.lg) {
            VStack(spacing: AzmySpacing.sm) {
                Text("How do you prefer to work?")
                    .font(AzmyFonts.headline1())
                    .foregroundColor(AzmyColors.textPrimary)

                Text("We'll tailor recommendations to your style")
                    .font(AzmyFonts.bodyLarge())
                    .foregroundColor(AzmyColors.textSecondary)
            }
            .padding(.top, AzmySpacing.xl)

            VStack(spacing: AzmySpacing.sm) {
                ForEach(WorkStyle.allCases, id: \.self) { style in
                    WorkStyleCard(
                        style: style,
                        isSelected: selectedWorkStyle == style
                    ) {
                        selectedWorkStyle = style
                    }
                }
            }
            .padding(.horizontal, AzmySpacing.lg)

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
            HStack(spacing: AzmySpacing.md) {
                Image(systemName: iconForStyle)
                    .font(.title)
                    .foregroundColor(isSelected ? AzmyColors.accentBlue : AzmyColors.textPrimary)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: AzmySpacing.xxs) {
                    Text(style.rawValue)
                        .font(AzmyFonts.headline3())
                        .foregroundColor(AzmyColors.textPrimary)

                    Text(descriptionForStyle)
                        .font(AzmyFonts.caption())
                        .foregroundColor(AzmyColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AzmyColors.gradientBlue)
                }
            }
            .padding(AzmySpacing.md)
            .background(
                isSelected
                    ? AzmyColors.accentBlue.opacity(0.1)
                    : AzmyColors.backgroundCard
            )
            .overlay(
                RoundedRectangle(cornerRadius: AzmyRadius.medium)
                    .stroke(isSelected ? AzmyColors.accentBlue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(AzmyRadius.medium)
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

// MARK: - Sign In Step
struct SignInStep: View {
    @EnvironmentObject var userProfile: UserProfileViewModel
    @ObservedObject var authService = AuthenticationService.shared
    @ObservedObject var googleCalendar = GoogleCalendarService.shared

    @State private var isSigningIn = false
    @State private var showError = false
    @State private var errorMessage = ""

    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: AzmySpacing.lg) {
            Spacer()

            VStack(spacing: AzmySpacing.md) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundStyle(AzmyColors.gradientBlue)

                Text("Sign In")
                    .font(AzmyFonts.headline1())
                    .foregroundColor(AzmyColors.textPrimary)

                Text("Sign in to sync your data and\nconnect to Google Calendar")
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: AzmySpacing.md) {
                // Google Sign-In
                Button(action: signInWithGoogle) {
                    HStack(spacing: AzmySpacing.sm) {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text("Continue with Google")
                            .font(AzmyFonts.bodyLarge())
                            .fontWeight(.semibold)

                        if isSigningIn {
                            Spacer()
                            ProgressView()
                                .tint(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AzmySpacing.md)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(AzmyRadius.medium)
                }
                .disabled(isSigningIn)

                // Apple Sign-In
                Button(action: signInWithApple) {
                    HStack(spacing: AzmySpacing.sm) {
                        Image(systemName: "apple.logo")
                            .font(.title2)
                        Text("Continue with Apple")
                            .font(AzmyFonts.bodyLarge())
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AzmySpacing.md)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(AzmyRadius.medium)
                }
                .disabled(isSigningIn)

                // Skip
                Button(action: onContinue) {
                    Text("Skip for now")
                        .font(AzmyFonts.body())
                        .foregroundColor(AzmyColors.textSecondary)
                        .underline()
                }
                .padding(.top, AzmySpacing.sm)
                .disabled(isSigningIn)
            }
            .padding(.horizontal, AzmySpacing.lg)

            // Show connected status
            if authService.isAuthenticated {
                HStack(spacing: AzmySpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Signed in as \(authService.currentUser?.displayName ?? "User")")
                        .font(AzmyFonts.caption())
                        .foregroundColor(AzmyColors.textSecondary)
                }
                .padding(.top, AzmySpacing.sm)
            }

            Spacer()
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func signInWithGoogle() {
        isSigningIn = true
        Task {
            do {
                let user = try await authService.signInWithGoogle()
                await MainActor.run {
                    updateUserProfile(with: user)
                    isSigningIn = false
                    onContinue()
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    if let authError = error as? AuthError, case .cancelled = authError {
                        // Cancelled
                    } else {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }

    private func signInWithApple() {
        isSigningIn = true
        Task {
            do {
                let user = try await authService.signInWithApple()
                await MainActor.run {
                    updateUserProfile(with: user)
                    isSigningIn = false
                    onContinue()
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    if let authError = error as? AuthError, case .cancelled = authError {
                        // Cancelled
                    } else {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }

    private func updateUserProfile(with authUser: AuthenticatedUser) {
        userProfile.profile.email = authUser.email
        if userProfile.profile.name.isEmpty {
            userProfile.profile.name = authUser.displayName
        }
        userProfile.profile.authProvider = authUser.provider.rawValue
        userProfile.profile.authUserId = authUser.id
        userProfile.profile.profileImageURL = authUser.profileImageURL

        if authUser.provider == .google {
            userProfile.profile.isGoogleCalendarConnected = true
            userProfile.profile.preferGoogleCalendar = true
        }
    }
}

// MARK: - Permissions Step
struct PermissionsStep: View {
    @EnvironmentObject var userProfile: UserProfileViewModel
    @ObservedObject var authService = AuthenticationService.shared
    @ObservedObject var googleCalendar = GoogleCalendarService.shared

    var body: some View {
        VStack(spacing: AzmySpacing.lg) {
            VStack(spacing: AzmySpacing.sm) {
                Text("Connect Your Data")
                    .font(AzmyFonts.headline1())
                    .foregroundColor(AzmyColors.textPrimary)

                Text("Azmy works best with access to your calendar and health data")
                    .font(AzmyFonts.bodyLarge())
                    .foregroundColor(AzmyColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, AzmySpacing.xl)
            .padding(.horizontal, AzmySpacing.md)

            VStack(spacing: AzmySpacing.md) {
                // Google Calendar (if signed in with Google)
                if authService.currentUser?.provider == .google {
                    PermissionCard(
                        icon: "calendar.badge.clock",
                        title: "Google Calendar",
                        description: "Sync events from your Google Calendar",
                        isConnected: googleCalendar.isConnected
                    ) {
                        // Already connected via Google Sign-In
                    }
                }

                // Local Calendar
                PermissionCard(
                    icon: "calendar",
                    title: "Device Calendar",
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
            .padding(.horizontal, AzmySpacing.lg)

            Text("You can change these permissions later in Settings")
                .font(AzmyFonts.caption())
                .foregroundColor(AzmyColors.textTertiary)

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
        HStack(spacing: AzmySpacing.md) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(AzmyColors.gradientBlue)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: AzmySpacing.xxs) {
                Text(title)
                    .font(AzmyFonts.headline3())
                    .foregroundColor(AzmyColors.textPrimary)

                Text(description)
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textSecondary)
            }

            Spacer()

            Button(action: action) {
                Text(isConnected ? "Connected" : "Connect")
                    .font(AzmyFonts.bodySmall())
                    .fontWeight(.medium)
                    .foregroundColor(isConnected ? .green : .white)
                    .padding(.horizontal, AzmySpacing.sm)
                    .padding(.vertical, AzmySpacing.xs)
                    .background(
                        isConnected
                            ? Color.green.opacity(0.2)
                            : AzmyColors.accentBlue
                    )
                    .cornerRadius(AzmyRadius.small)
            }
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
    }
}

// MARK: - Button Style
struct AzmyButtonStyle: ButtonStyle {
    var isSecondary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AzmyFonts.bodyLarge())
            .fontWeight(.semibold)
            .foregroundColor(isSecondary ? AzmyColors.textPrimary : .white)
            .padding(.horizontal, AzmySpacing.lg)
            .padding(.vertical, AzmySpacing.sm)
            .background(
                isSecondary
                    ? AzmyColors.backgroundCard
                    : AzmyColors.accentBlue
            )
            .cornerRadius(AzmyRadius.medium)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
