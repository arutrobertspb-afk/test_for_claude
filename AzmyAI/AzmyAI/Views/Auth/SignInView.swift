//
//  SignInView.swift
//  AzmyAI
//
//  Sign in with Google or Apple ID
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userProfile: UserProfileViewModel
    @ObservedObject var authService = AuthenticationService.shared

    @State private var isSigningIn = false
    @State private var showError = false
    @State private var errorMessage = ""

    var onSignInComplete: (() -> Void)?
    var showSkipButton: Bool = true

    var body: some View {
        ZStack {
            // Background
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            LinearGradient(
                colors: [AzmyColors.accentBlue.opacity(0.1), AzmyColors.accentPurple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: AzmySpacing.xl) {
                Spacer()

                // Logo and title
                VStack(spacing: AzmySpacing.md) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 70))
                        .foregroundStyle(AzmyColors.gradientBlue)

                    Text("Sign In")
                        .font(AzmyFonts.headline1())
                        .foregroundColor(AzmyColors.textPrimary)

                    Text("Sign in to sync your data across devices\nand connect to Google Calendar")
                        .font(AzmyFonts.body())
                        .foregroundColor(AzmyColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AzmySpacing.lg)
                }

                Spacer()

                // Sign in buttons
                VStack(spacing: AzmySpacing.md) {
                    // Google Sign-In
                    Button(action: signInWithGoogle) {
                        HStack(spacing: AzmySpacing.sm) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Continue with Google")
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

                    // Apple Sign-In
                    SignInWithAppleButton(.signIn, onRequest: configureAppleSignIn, onCompletion: handleAppleSignIn)
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(AzmyRadius.medium)
                        .disabled(isSigningIn)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(AzmyColors.backgroundTertiary)
                            .frame(height: 1)
                        Text("or")
                            .font(AzmyFonts.caption())
                            .foregroundColor(AzmyColors.textTertiary)
                        Rectangle()
                            .fill(AzmyColors.backgroundTertiary)
                            .frame(height: 1)
                    }
                    .padding(.vertical, AzmySpacing.sm)

                    // Skip button
                    if showSkipButton {
                        Button(action: skipSignIn) {
                            Text("Continue without signing in")
                                .font(AzmyFonts.body())
                                .foregroundColor(AzmyColors.textSecondary)
                                .underline()
                        }
                        .disabled(isSigningIn)
                    }
                }
                .padding(.horizontal, AzmySpacing.lg)

                Spacer()

                // Privacy note
                Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AzmySpacing.xl)
                    .padding(.bottom, AzmySpacing.lg)
            }

            // Loading overlay
            if isSigningIn {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                VStack(spacing: AzmySpacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)

                    Text("Signing in...")
                        .font(AzmyFonts.body())
                        .foregroundColor(.white)
                }
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Google Sign-In
    private func signInWithGoogle() {
        isSigningIn = true

        Task {
            do {
                let user = try await authService.signInWithGoogle()
                await MainActor.run {
                    updateUserProfile(with: user)
                    isSigningIn = false
                    onSignInComplete?()
                }
            } catch let error as AuthError {
                await MainActor.run {
                    isSigningIn = false
                    if case .cancelled = error {
                        // User cancelled, don't show error
                    } else {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    // MARK: - Apple Sign-In
    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isSigningIn = true

            Task {
                do {
                    let user = try await authService.signInWithApple()
                    await MainActor.run {
                        updateUserProfile(with: user)
                        isSigningIn = false
                        onSignInComplete?()
                    }
                } catch let error as AuthError {
                    await MainActor.run {
                        isSigningIn = false
                        if case .cancelled = error {
                            // User cancelled
                        } else {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        isSigningIn = false
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                // User cancelled
            } else {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Skip Sign-In
    private func skipSignIn() {
        onSignInComplete?()
    }

    // MARK: - Update User Profile
    // Automatically sync all user data from Google/Apple - no manual input needed
    private func updateUserProfile(with authUser: AuthenticatedUser) {
        // Always use email and name from the auth provider (Google/Apple)
        userProfile.profile.email = authUser.email
        userProfile.profile.name = authUser.displayName
        userProfile.profile.authProvider = authUser.provider.rawValue
        userProfile.profile.authUserId = authUser.id
        userProfile.profile.profileImageURL = authUser.profileImageURL

        if authUser.provider == .google {
            userProfile.profile.isGoogleCalendarConnected = true
            userProfile.profile.preferGoogleCalendar = true
        }
    }
}

// MARK: - Compact Sign-In Buttons (for Profile/Settings)
struct SignInButtonsCompact: View {
    @ObservedObject var authService = AuthenticationService.shared
    @EnvironmentObject var userProfile: UserProfileViewModel

    @State private var isSigningIn = false
    @State private var showError = false
    @State private var errorMessage = ""

    var onSignInComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: AzmySpacing.sm) {
            // Google Sign-In
            Button(action: signInWithGoogle) {
                HStack(spacing: AzmySpacing.sm) {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("Google")
                        .font(AzmyFonts.body())
                        .fontWeight(.medium)
                    Spacer()
                    if isSigningIn {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(AzmySpacing.md)
                .background(AzmyColors.backgroundCard)
                .cornerRadius(AzmyRadius.medium)
            }
            .foregroundColor(AzmyColors.textPrimary)
            .disabled(isSigningIn)

            // Apple Sign-In
            Button(action: signInWithApple) {
                HStack(spacing: AzmySpacing.sm) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("Apple")
                        .font(AzmyFonts.body())
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(AzmySpacing.md)
                .background(AzmyColors.backgroundCard)
                .cornerRadius(AzmyRadius.medium)
            }
            .foregroundColor(AzmyColors.textPrimary)
            .disabled(isSigningIn)
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
                    onSignInComplete?()
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
                    onSignInComplete?()
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

    // Automatically sync all user data from Google/Apple - no manual input needed
    private func updateUserProfile(with authUser: AuthenticatedUser) {
        // Always use email and name from the auth provider (Google/Apple)
        userProfile.profile.email = authUser.email
        userProfile.profile.name = authUser.displayName
        userProfile.profile.authProvider = authUser.provider.rawValue
        userProfile.profile.authUserId = authUser.id
        userProfile.profile.profileImageURL = authUser.profileImageURL

        if authUser.provider == .google {
            userProfile.profile.isGoogleCalendarConnected = true
            userProfile.profile.preferGoogleCalendar = true
        }
    }
}

// MARK: - Preview
#Preview {
    SignInView()
        .environmentObject(AppState())
        .environmentObject(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
