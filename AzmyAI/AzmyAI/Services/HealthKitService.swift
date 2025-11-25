//
//  HealthKitService.swift
//  AzmyAI
//

import Foundation
import HealthKit

class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var latestSnapshot: HealthSnapshot?

    // Types to read
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        await MainActor.run {
            self.isAuthorized = true
        }
    }

    // MARK: - Fetch Data
    func fetchHealthSnapshot() async throws -> HealthSnapshot {
        // Fetch all data concurrently
        async let stepsResult = fetchSteps()
        async let caloriesResult = fetchActiveCalories()
        async let heartRateResult = fetchLatestHeartRate()
        async let hrvResult = fetchHRV()
        async let sleepResult = fetchSleepHours()

        let steps = try? await stepsResult
        let calories = try? await caloriesResult
        let heartRate = try? await heartRateResult
        let hrv = try? await hrvResult
        let sleep = try? await sleepResult

        let snapshot = HealthSnapshot(
            lastUpdated: Date(),
            sleepHours: sleep,
            steps: steps,
            activeCalories: calories,
            heartRate: heartRate,
            hrvAverage: hrv,
            energyLevel: nil,
            moodScore: nil
        )

        await MainActor.run {
            self.latestSnapshot = snapshot
        }

        return snapshot
    }

    // MARK: - Individual Fetches
    private func fetchSteps() async throws -> Int {
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    private func fetchActiveCalories() async throws -> Int {
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: caloriesType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: Int(calories))
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestHeartRate() async throws -> Int {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: Int(heartRate))
            }
            healthStore.execute(query)
        }
    }

    private func fetchHRV() async throws -> Double {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let hrv = result?.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli)) ?? 0
                continuation.resume(returning: hrv)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepHours() async throws -> Double {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let startOfYesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: now))!
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var totalSleep: TimeInterval = 0
                for sample in samples ?? [] {
                    guard let categorySample = sample as? HKCategorySample else { continue }
                    // Only count asleep states
                    if categorySample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       categorySample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       categorySample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       categorySample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        totalSleep += categorySample.endDate.timeIntervalSince(categorySample.startDate)
                    }
                }
                let hours = totalSleep / 3600.0
                continuation.resume(returning: hours)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Errors
enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationFailed
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationFailed:
            return "Failed to authorize HealthKit access"
        case .fetchFailed:
            return "Failed to fetch health data"
        }
    }
}
