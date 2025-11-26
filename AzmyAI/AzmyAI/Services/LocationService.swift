//
//  LocationService.swift
//  AzmyAI
//
//  Handles user location for weather and location-based features
//

import Foundation
import CoreLocation

// MARK: - Location Data

struct LocationData: Equatable {
    let latitude: Double
    let longitude: Double
    let cityName: String
    let countryName: String
    let fullAddress: String

    var displayName: String {
        if countryName.isEmpty {
            return cityName
        }
        return "\(cityName), \(countryName)"
    }

    static let placeholder = LocationData(
        latitude: 34.6937,
        longitude: 135.5023,
        cityName: "Limassol",
        countryName: "Cyprus",
        fullAddress: "Limassol, Cyprus"
    )
}

// MARK: - Location Service

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var currentLocation: LocationData?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Permission

    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Location Updates

    func startUpdatingLocation() {
        guard hasLocationPermission else {
            requestPermission()
            return
        }

        isLoading = true
        errorMessage = nil
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - One-time Location Request

    func getCurrentLocation() async -> LocationData? {
        guard hasLocationPermission else {
            requestPermission()
            return nil
        }

        isLoading = true
        errorMessage = nil

        // Request one-time location
        locationManager.requestLocation()

        // Wait for location with timeout
        let location = await withCheckedContinuation { continuation in
            self.locationContinuation = continuation

            // Timeout after 10 seconds
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(returning: nil)
                    self.locationContinuation = nil
                }
            }
        }

        guard let location = location else {
            isLoading = false
            errorMessage = "Could not get location"
            return nil
        }

        // Reverse geocode
        let locationData = await reverseGeocode(location: location)
        isLoading = false

        if let data = locationData {
            currentLocation = data
        }

        return locationData
    }

    // MARK: - Reverse Geocoding

    private func reverseGeocode(location: CLLocation) async -> LocationData? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            guard let placemark = placemarks.first else {
                return LocationData(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    cityName: "Unknown",
                    countryName: "",
                    fullAddress: "Unknown location"
                )
            }

            let city = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
            let country = placemark.country ?? ""
            let fullAddress = [
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ].compactMap { $0 }.joined(separator: ", ")

            return LocationData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                cityName: city,
                countryName: country,
                fullAddress: fullAddress.isEmpty ? "\(city), \(country)" : fullAddress
            )

        } catch {
            print("[Location] Geocoding error: \(error)")
            return LocationData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                cityName: "Unknown",
                countryName: "",
                fullAddress: "Unknown location"
            )
        }
    }

    // MARK: - Refresh Location

    func refreshLocation() {
        Task {
            _ = await getCurrentLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            // Resume continuation if waiting
            if let continuation = self.locationContinuation {
                continuation.resume(returning: location)
                self.locationContinuation = nil
                return
            }

            // Regular update
            let locationData = await self.reverseGeocode(location: location)
            self.currentLocation = locationData
            self.isLoading = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("[Location] Error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false

            // Resume continuation with nil
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus

            if self.hasLocationPermission {
                self.startUpdatingLocation()
            }
        }
    }
}
