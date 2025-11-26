//
//  ProfileView.swift
//  AzmyAI
//
//  Settings screen matching Figma design
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userProfile: UserProfileViewModel
    @EnvironmentObject var appState: AppState

    @State private var isPermissionExpanded = false
    @State private var allowAppAccess = true
    @State private var googleAccountAccess = true
    @State private var microphoneAccess = true
    @State private var calendarAccess = true
    @State private var notificationsEnabled = true
    @State private var showLogoutAlert = false

    var body: some View {
        ZStack {
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Email Section
                    SettingsSection(title: "Email") {
                        EmailRow(email: userProfile.profile.email.isEmpty ? "user@example.com" : userProfile.profile.email)
                    }

                    // Permission Section
                    SettingsSection(title: "Permission") {
                        VStack(spacing: 0) {
                            // Main toggle with expand
                            PermissionMainRow(
                                isExpanded: $isPermissionExpanded,
                                isEnabled: $allowAppAccess
                            )

                            // Expandable content
                            if isPermissionExpanded {
                                VStack(spacing: 0) {
                                    Divider()
                                        .background(AzmyColors.separator)

                                    PermissionSubRow(
                                        title: "Google account access",
                                        isEnabled: $googleAccountAccess
                                    )

                                    PermissionSubRow(
                                        title: "Microphone access",
                                        isEnabled: $microphoneAccess
                                    )

                                    PermissionSubRow(
                                        title: "Calendar access",
                                        isEnabled: $calendarAccess
                                    )
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isPermissionExpanded)

                        Text("Take control over what Azmy can access to support you best.")
                            .font(.system(size: 13))
                            .foregroundColor(AzmyColors.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    // Notification Section
                    SettingsSection(title: "Notification") {
                        SettingsToggleRow(
                            title: "Enable notifications",
                            isEnabled: $notificationsEnabled
                        )
                    }

                    // Legal Section
                    SettingsSection(title: "Legal") {
                        VStack(spacing: 0) {
                            SettingsLinkRow(title: "Privacy policy") {
                                if let url = URL(string: "https://azmy.ai/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            }

                            Divider()
                                .background(AzmyColors.separator)

                            SettingsLinkRow(title: "Terms of Uses") {
                                if let url = URL(string: "https://azmy.ai/terms") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }

                    // Contact Section
                    SettingsSection(title: "Contact us") {
                        SettingsLinkRow(title: "Email us at support@azmy.ai") {
                            if let url = URL(string: "mailto:support@azmy.ai") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    // Logout Button
                    Button(action: { showLogoutAlert = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                            Text("Logout")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AzmyColors.accentBlue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(20)
                    }
                    .padding(.top, 16)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                userProfile.resetProfile()
                appState.isOnboardingComplete = false
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .onAppear {
            calendarAccess = userProfile.calendarService.isAuthorized
            notificationsEnabled = userProfile.profile.notificationsEnabled
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AzmyColors.textTertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(AzmyColors.backgroundCard)
            .cornerRadius(12)
        }
    }
}

// MARK: - Email Row
struct EmailRow: View {
    let email: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope")
                .font(.system(size: 18))
                .foregroundColor(AzmyColors.textSecondary)

            Text(email)
                .font(.system(size: 16))
                .foregroundColor(AzmyColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Permission Main Row
struct PermissionMainRow: View {
    @Binding var isExpanded: Bool
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AzmyColors.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }

            Text("Allow app access")
                .font(.system(size: 16))
                .foregroundColor(AzmyColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(AzmyColors.accentBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Permission Sub Row
struct PermissionSubRow: View {
    let title: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(AzmyColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(AzmyColors.accentBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let title: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(AzmyColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(AzmyColors.accentBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Settings Link Row
struct SettingsLinkRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(AzmyColors.accentBlue)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserProfileViewModel())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
