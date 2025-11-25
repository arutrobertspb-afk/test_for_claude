//
//  Theme.swift
//  AzmyAI
//
//  Dark theme based on Figma design (#090F1E)
//

import SwiftUI

// MARK: - Azmy Colors (Dark Theme)
struct AzmyColors {
    // Background colors
    static let backgroundPrimary = Color(hex: "090F1E")
    static let backgroundSecondary = Color(hex: "111827")
    static let backgroundTertiary = Color(hex: "1F2937")
    static let backgroundCard = Color(hex: "151C2C")

    // Accent colors
    static let accentBlue = Color(hex: "3B82F6")
    static let accentPurple = Color(hex: "8B5CF6")
    static let accentCyan = Color(hex: "06B6D4")

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "9CA3AF")
    static let textTertiary = Color(hex: "6B7280")

    // Separator
    static let separator = Color(hex: "707FA0").opacity(0.2)

    // Status colors
    static let success = Color(hex: "10B981")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")

    // Gradient
    static let gradientBlue = LinearGradient(
        colors: [Color(hex: "3B82F6"), Color(hex: "8B5CF6")],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
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

// MARK: - Typography (Inter font style)
struct AzmyFonts {
    // Headlines - weight 800
    static func headline1() -> Font {
        .system(size: 28, weight: .heavy, design: .default)
    }

    static func headline2() -> Font {
        .system(size: 22, weight: .heavy, design: .default)
    }

    static func headline3() -> Font {
        .system(size: 18, weight: .bold, design: .default)
    }

    // Body - weight 500
    static func bodyLarge() -> Font {
        .system(size: 16, weight: .medium, design: .default)
    }

    static func body() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }

    static func bodySmall() -> Font {
        .system(size: 12, weight: .medium, design: .default)
    }

    static func caption() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }
}

// MARK: - Spacing
struct AzmySpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
struct AzmyRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 10
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
    static let card: CGFloat = 40
}

// MARK: - View Modifiers
struct AzmyCardModifier: ViewModifier {
    var padding: CGFloat = AzmySpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AzmyColors.backgroundCard)
            .cornerRadius(AzmyRadius.large)
    }
}

extension View {
    func azmyCard(padding: CGFloat = AzmySpacing.md) -> some View {
        modifier(AzmyCardModifier(padding: padding))
    }
}

// MARK: - Input Field Style
struct AzmyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(AzmySpacing.md)
            .background(AzmyColors.backgroundSecondary)
            .foregroundColor(AzmyColors.textPrimary)
            .cornerRadius(AzmyRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AzmyRadius.medium)
                    .stroke(AzmyColors.separator, lineWidth: 1)
            )
    }
}
