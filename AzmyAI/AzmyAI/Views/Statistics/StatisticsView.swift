//
//  StatisticsView.swift
//  AzmyAI
//
//  Health statistics screen matching Figma design
//

import SwiftUI

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
                        ForEach(healthStats) { stat in
                            HealthStatCard(stat: stat)
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
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        let timeString = formatter.string(from: now)

        // Sample data - in real app would come from HealthKit
        healthStats = [
            HealthStat(type: .activeEnergy, value: 45, unit: "Kcal", time: "04:23 PM"),
            HealthStat(type: .restingEnergy, value: 1003, unit: "Kcal", time: timeString),
            HealthStat(type: .flightsClimbed, value: 3, unit: "Floors", time: timeString),
            HealthStat(type: .distance, value: 1.1, unit: "Km", time: timeString),
            HealthStat(type: .steps, value: 1697, unit: "Steps", time: timeString)
        ]
        isLoading = false
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
            let formatted = String(format: "%.0f", value)
            // Add space as thousands separator
            var result = ""
            for (index, char) in formatted.reversed().enumerated() {
                if index > 0 && index % 3 == 0 {
                    result = " " + result
                }
                result = String(char) + result
            }
            return result
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
}

// MARK: - Health Stat Card
struct HealthStatCard: View {
    let stat: HealthStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
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

#Preview {
    StatisticsView()
        .environmentObject(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
