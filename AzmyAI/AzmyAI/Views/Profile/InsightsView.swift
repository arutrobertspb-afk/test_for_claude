//
//  InsightsView.swift
//  AzmyAI
//
//  Dark theme insights dashboard
//

import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var userProfile: UserProfileViewModel
    @EnvironmentObject var plannerViewModel: PlannerViewModel
    @EnvironmentObject var quizViewModel: QuizViewModel

    @State private var selectedTimeframe: Timeframe = .week
    @State private var showQuiz = false

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AzmySpacing.lg) {
                        // Quiz Card
                        QuizLaunchCard {
                            quizViewModel.startQuiz(AzmyQuiz.interiorStyleQuiz)
                            showQuiz = true
                        }

                        // Timeframe picker
                        Picker("Timeframe", selection: $selectedTimeframe) {
                            ForEach(Timeframe.allCases, id: \.self) { tf in
                                Text(tf.rawValue).tag(tf)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AzmySpacing.md)

                        // Quick Stats
                        QuickStatsGrid(profile: userProfile.profile)

                        // Energy Chart
                        EnergyChartCard()

                        // Sleep Analysis
                        SleepAnalysisCard(profile: userProfile.profile)

                        // Productivity Score
                        ProductivityCard(tasks: plannerViewModel.tasks)

                        // Patterns
                        PatternsCard(profile: userProfile.profile)
                    }
                    .padding(.bottom, AzmySpacing.xl)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showQuiz) {
                QuizContainerView()
                    .environmentObject(quizViewModel)
            }
        }
    }
}

// MARK: - Quiz Launch Card
struct QuizLaunchCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AzmySpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AzmySpacing.xs) {
                    Text("Explore Your Style")
                        .font(AzmyFonts.headline2())
                        .foregroundColor(AzmyColors.textPrimary)

                    Text("Take a quick quiz to understand your preferences")
                        .font(AzmyFonts.body())
                        .foregroundColor(AzmyColors.textSecondary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(AzmyColors.gradientBlue)
            }

            Button(action: onStart) {
                HStack {
                    Spacer()
                    Text("Start Quiz")
                        .font(AzmyFonts.bodyLarge())
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, AzmySpacing.md)
                .background(AzmyColors.accentBlue)
                .cornerRadius(AzmyRadius.medium)
            }
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.large)
        .padding(.horizontal, AzmySpacing.md)
    }
}

enum Timeframe: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

// MARK: - Quick Stats Grid
struct QuickStatsGrid: View {
    let profile: UserProfile

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AzmySpacing.sm) {
            StatCard(
                title: "Sleep Avg",
                value: String(format: "%.1f", profile.healthData?.sleepHours ?? 7.2),
                unit: "hrs",
                icon: "moon.fill",
                color: .indigo
            )

            StatCard(
                title: "Steps Today",
                value: formatNumber(profile.healthData?.steps ?? 6420),
                unit: "",
                icon: "figure.walk",
                color: .green
            )

            StatCard(
                title: "Energy",
                value: "\(profile.healthData?.energyLevel ?? 7)",
                unit: "/10",
                icon: "bolt.fill",
                color: .orange
            )

            StatCard(
                title: "Focus Time",
                value: "3.5",
                unit: "hrs",
                icon: "brain.head.profile",
                color: .purple
            )
        }
        .padding(.horizontal, AzmySpacing.md)
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fk", Double(num) / 1000)
        }
        return "\(num)"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AzmySpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(AzmyFonts.headline1())
                    .foregroundColor(AzmyColors.textPrimary)
                Text(unit)
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textSecondary)
            }

            Text(title)
                .font(AzmyFonts.caption())
                .foregroundColor(AzmyColors.textSecondary)
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
    }
}

// MARK: - Energy Chart Card
struct EnergyChartCard: View {
    let data: [HourlyEnergy] = (8...20).map { hour in
        HourlyEnergy(
            hour: hour,
            predictedLevel: energyForHour(hour)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AzmySpacing.sm) {
            HStack {
                Text("Energy Pattern")
                    .font(AzmyFonts.headline3())
                    .foregroundColor(AzmyColors.textPrimary)

                Spacer()

                Text("Today")
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textSecondary)
            }

            Chart(data) { item in
                AreaMark(
                    x: .value("Hour", item.hour),
                    y: .value("Energy", item.predictedLevel)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AzmyColors.accentBlue.opacity(0.5), AzmyColors.accentBlue.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Hour", item.hour),
                    y: .value("Energy", item.predictedLevel)
                )
                .foregroundStyle(AzmyColors.accentBlue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis {
                AxisMarks(values: [8, 12, 16, 20]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(formatHour(hour))
                                .font(AzmyFonts.caption())
                                .foregroundColor(AzmyColors.textSecondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                }
            }
            .frame(height: 150)

            HStack(spacing: AzmySpacing.lg) {
                InsightBadge(icon: "sunrise.fill", text: "Peak: 9-11 AM", color: .orange)
                InsightBadge(icon: "moon.fill", text: "Low: 2-3 PM", color: .indigo)
            }
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
        .padding(.horizontal, AzmySpacing.md)
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 12 { return "12PM" }
        if hour < 12 { return "\(hour)AM" }
        return "\(hour - 12)PM"
    }

    private static func energyForHour(_ hour: Int) -> Double {
        // Simulated energy curve based on typical chronotype
        switch hour {
        case 8: return 0.6
        case 9: return 0.8
        case 10: return 0.95
        case 11: return 0.9
        case 12: return 0.75
        case 13: return 0.5
        case 14: return 0.45
        case 15: return 0.55
        case 16: return 0.65
        case 17: return 0.7
        case 18: return 0.6
        case 19: return 0.5
        case 20: return 0.4
        default: return 0.5
        }
    }
}

struct InsightBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: AzmySpacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(AzmyFonts.caption())
        }
        .foregroundColor(color)
    }
}

// MARK: - Sleep Analysis Card
struct SleepAnalysisCard: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: AzmySpacing.sm) {
            Text("Sleep Analysis")
                .font(AzmyFonts.headline3())
                .foregroundColor(AzmyColors.textPrimary)

            HStack(spacing: AzmySpacing.lg) {
                // Sleep score ring
                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.2), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: 0.85)
                        .stroke(Color.indigo, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("85")
                            .font(AzmyFonts.headline2())
                            .foregroundColor(AzmyColors.textPrimary)
                        Text("Score")
                            .font(AzmyFonts.caption())
                            .foregroundColor(AzmyColors.textSecondary)
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: AzmySpacing.xs) {
                    SleepMetric(label: "Duration", value: "7h 23m", target: "8h")
                    SleepMetric(label: "Quality", value: "Good", target: nil)
                    SleepMetric(label: "Consistency", value: "92%", target: nil)
                }
            }

            Divider()
                .background(AzmyColors.separator)

            Text("You tend to sleep better on weeknights. Consider maintaining your weeknight routine on weekends.")
                .font(AzmyFonts.caption())
                .foregroundColor(AzmyColors.textSecondary)
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
        .padding(.horizontal, AzmySpacing.md)
    }
}

struct SleepMetric: View {
    let label: String
    let value: String
    let target: String?

    var body: some View {
        HStack {
            Text(label)
                .font(AzmyFonts.caption())
                .foregroundColor(AzmyColors.textSecondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(AzmyFonts.bodyLarge())
                .fontWeight(.medium)
                .foregroundColor(AzmyColors.textPrimary)

            if let target = target {
                Text("/ \(target)")
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textSecondary)
            }
        }
    }
}

// MARK: - Productivity Card
struct ProductivityCard: View {
    let tasks: [PlannerTask]

    var completionRate: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.isCompleted }.count) / Double(tasks.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AzmySpacing.sm) {
            HStack {
                Text("Productivity")
                    .font(AzmyFonts.headline3())
                    .foregroundColor(AzmyColors.textPrimary)

                Spacer()

                Text("\(Int(completionRate * 100))% complete")
                    .font(AzmyFonts.caption())
                    .foregroundColor(AzmyColors.textSecondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * completionRate)
                }
            }
            .frame(height: 8)

            HStack {
                ProductivityStat(value: "\(tasks.filter { $0.isCompleted }.count)", label: "Completed")
                Spacer()
                ProductivityStat(value: "\(tasks.filter { !$0.isCompleted }.count)", label: "Remaining")
                Spacer()
                ProductivityStat(value: "\(tasks.filter { $0.priority >= .high }.count)", label: "High Priority")
            }
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
        .padding(.horizontal, AzmySpacing.md)
    }
}

struct ProductivityStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: AzmySpacing.xxs) {
            Text(value)
                .font(AzmyFonts.headline3())
                .foregroundColor(AzmyColors.textPrimary)

            Text(label)
                .font(AzmyFonts.caption())
                .foregroundColor(AzmyColors.textSecondary)
        }
    }
}

// MARK: - Patterns Card
struct PatternsCard: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: AzmySpacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AzmyColors.gradientBlue)
                Text("Your Patterns")
                    .font(AzmyFonts.headline3())
                    .foregroundColor(AzmyColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: AzmySpacing.sm) {
                PatternItem(
                    icon: "sunrise.fill",
                    text: "You're most productive between 9-11 AM",
                    color: .orange
                )

                PatternItem(
                    icon: "figure.walk",
                    text: "Walking 30+ min correlates with better focus",
                    color: .green
                )

                PatternItem(
                    icon: "moon.fill",
                    text: "7.5+ hours of sleep improves your energy by 23%",
                    color: .indigo
                )
            }
        }
        .padding(AzmySpacing.md)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
        .padding(.horizontal, AzmySpacing.md)
    }
}

struct PatternItem: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: AzmySpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(AzmyFonts.bodyLarge())
                .foregroundColor(AzmyColors.textPrimary)
        }
    }
}

#Preview {
    InsightsView()
        .environmentObject(UserProfileViewModel())
        .environmentObject(PlannerViewModel())
        .environmentObject(QuizViewModel())
        .preferredColorScheme(.dark)
}
