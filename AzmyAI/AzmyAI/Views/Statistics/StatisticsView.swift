//
//  StatisticsView.swift
//  AzmyAI
//
//  Health statistics screen matching Figma design
//

import SwiftUI
import HealthKit

struct StatisticsView: View {
    @EnvironmentObject var userProfile: UserProfileViewModel
    @State private var healthStats: [HealthStat] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AzmyColors.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    Text("Today")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Stats Cards
                    VStack(spacing: 12) {
                        if isLoading {
                            ForEach(0..<5) { _ in
                                StatCardPlaceholder()
                            }
                        } else if healthStats.isEmpty {
                            // Show sample data if no health access
                            StatCard(stat: HealthStat(type: .activeEnergy, value: 45, unit: "Kcal", time: "04:23 PM"))
                            StatCard(stat: HealthStat(type: .restingEnergy, value: 1003, unit: "Kcal", time: "05:10 PM"))
                            StatCard(stat: HealthStat(type: .flightsClimbed, value: 3, unit: "Floors", time: "05:10 PM"))
                            StatCard(stat: HealthStat(type: .distance, value: 1.1, unit: "Km", time: "05:10 PM"))
                            StatCard(stat: HealthStat(type: .steps, value: 1697, unit: "Steps", time: "05:10 PM"))
                        } else {
                            ForEach(healthStats) { stat in
                                StatCard(stat: stat)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            loadHealthData()
        }
    }

    private func loadHealthData() {
        isLoading = true

        // Try to get real health data
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                // For now, show sample data
                // In real app, this would come from HealthKit via userProfile.healthService
                let now = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "hh:mm a"
                let timeString = formatter.string(from: now)

                healthStats = [
                    HealthStat(type: .activeEnergy, value: Double(userProfile.healthService.todayActiveEnergy), unit: "Kcal", time: timeString),
                    HealthStat(type: .restingEnergy, value: Double(userProfile.healthService.todayRestingEnergy), unit: "Kcal", time: timeString),
                    HealthStat(type: .flightsClimbed, value: Double(userProfile.healthService.todayFlightsClimbed), unit: "Floors", time: timeString),
                    HealthStat(type: .distance, value: userProfile.healthService.todayDistance / 1000, unit: "Km", time: timeString),
                    HealthStat(type: .steps, value: Double(userProfile.healthService.todaySteps), unit: "Steps", time: timeString)
                ]
                isLoading = false
            }
        }
    }
}

// MARK: - Health Stat Model
struct HealthStat: Identifiable {
    let id = UUID()
    let type: HealthStatType
    let value: Double
    let unit: String
    let time: String

    var title: String {
        type.title
    }

    var formattedValue: String {
        if value >= 1000 {
            return String(format: "%.0f", value).replacingOccurrences(of: ",", with: " ")
        } else if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
        }
    }
}

enum HealthStatType {
    case activeEnergy
    case restingEnergy
    case flightsClimbed
    case distance
    case steps

    var title: String {
        switch self {
        case .activeEnergy: return "Activity energy"
        case .restingEnergy: return "Rest energy"
        case .flightsClimbed: return "Flights completed"
        case .distance: return "Walking and running distance"
        case .steps: return "Steps"
        }
    }

    var icon: String {
        return "flame.fill"
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let stat: HealthStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 6) {
                Image(systemName: stat.type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(AzmyColors.accentBlue)

                Text(stat.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AzmyColors.accentBlue)
            }

            // Value row
            HStack(alignment: .lastTextBaseline) {
                Text(stat.formattedValue)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text(stat.unit)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Text(stat.time)
                    .font(.system(size: 13))
                    .foregroundColor(AzmyColors.textTertiary)
            }
        }
        .padding(16)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
    }
}

// MARK: - Placeholder
struct StatCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(AzmyColors.backgroundCard.opacity(0.5))
                .frame(width: 120, height: 16)

            RoundedRectangle(cornerRadius: 4)
                .fill(AzmyColors.backgroundCard.opacity(0.5))
                .frame(width: 80, height: 28)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
        .shimmer()
    }
}

// MARK: - Shimmer Effect
extension View {
    func shimmer() -> some View {
        self.redacted(reason: .placeholder)
    }
}

#Preview {
    StatisticsView()
        .environmentObject(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
