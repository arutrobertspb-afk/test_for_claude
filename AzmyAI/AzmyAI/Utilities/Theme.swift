//
//  Theme.swift
//  AzmyAI
//

import SwiftUI

// MARK: - Color Extensions
extension Color {
    // Primary Brand Colors
    static let azuryPrimary = Color("AzuryPrimary", bundle: nil)
    static let azurySecondary = Color("AzurySecondary", bundle: nil)
    static let azuryAccent = Color("AzuryAccent", bundle: nil)

    // Fallback colors if assets not available
    static let azuryBlue = Color(hex: "4F46E5")
    static let azuryPurple = Color(hex: "7C3AED")
    static let azuryTeal = Color(hex: "14B8A6")
    static let azuryPink = Color(hex: "EC4899")

    // Semantic Colors
    static let azurySuccess = Color(hex: "10B981")
    static let azuryWarning = Color(hex: "F59E0B")
    static let azuryError = Color(hex: "EF4444")

    // Background Colors
    static let azuryBackground = Color(UIColor.systemBackground)
    static let azurySecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let azuryTertiaryBackground = Color(UIColor.tertiarySystemBackground)

    // Gradient
    static let azuryGradient = LinearGradient(
        colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let azuryGradientLight = LinearGradient(
        colors: [Color(hex: "818CF8"), Color(hex: "A78BFA")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography
extension Font {
    // Headlines
    static let azuryLargeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let azuryTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let azuryTitle2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let azuryTitle3 = Font.system(size: 20, weight: .semibold, design: .rounded)

    // Body
    static let azuryHeadline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let azuryBody = Font.system(size: 17, weight: .regular, design: .default)
    static let azuryCallout = Font.system(size: 16, weight: .regular, design: .default)
    static let azurySubheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let azuryFootnote = Font.system(size: 13, weight: .regular, design: .default)
    static let azuryCaption = Font.system(size: 12, weight: .regular, design: .default)
}

// MARK: - Spacing
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
    static let circular: CGFloat = 9999
}

// MARK: - Shadows
extension View {
    func azuryShadow(radius: CGFloat = 8, y: CGFloat = 4) -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: radius, x: 0, y: y)
    }

    func azuryCardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - View Modifiers
struct AzuryCardStyle: ViewModifier {
    var padding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.azurySecondaryBackground)
            .cornerRadius(CornerRadius.large)
            .azuryCardShadow()
    }
}

struct AzuryButtonStyle: ButtonStyle {
    var isSecondary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.azuryHeadline)
            .foregroundColor(isSecondary ? Color.azuryBlue : .white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                isSecondary
                    ? AnyView(Color.azuryBlue.opacity(0.1))
                    : AnyView(Color.azuryGradient)
            )
            .cornerRadius(CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension View {
    func azuryCard(padding: CGFloat = Spacing.md) -> some View {
        modifier(AzuryCardStyle(padding: padding))
    }
}

// MARK: - Animation
extension Animation {
    static let azurySpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let azuryQuick = Animation.easeOut(duration: 0.2)
    static let azurySmooth = Animation.easeInOut(duration: 0.3)
}
