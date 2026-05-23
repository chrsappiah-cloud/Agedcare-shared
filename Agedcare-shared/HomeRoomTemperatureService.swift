import Foundation
import Combine

#if canImport(HomeKit)
import HomeKit

@MainActor
final class HomeRoomTemperatureService: NSObject, ObservableObject, HMHomeManagerDelegate, HMAccessoryDelegate {
    static let shared = HomeRoomTemperatureService()

    struct Reading {
        let temperatureCelsius: Double
        let sourceName: String
        let updatedAt: Date
    }

    @Published private(set) var latestReading: Reading?
    @Published private(set) var errorMessage: String?

    private let homeManager = HMHomeManager()
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var observedCharacteristicIDs = Set<UUID>()

    override init() {
        super.init()
        homeManager.delegate = self
    }

    func start() {
        startRefreshTimerIfNeeded()
        refreshIfPossible()
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshNow() {
        refreshIfPossible()
    }

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.configureAccessoryDelegates()
            self.observedCharacteristicIDs.removeAll()
            self.refreshIfPossible()
        }
    }

    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in
            self.applyTemperatureUpdate(from: characteristic, accessory: accessory, service: service)
        }
    }

    private func refreshIfPossible() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.refreshTemperatures()
        }
    }

    private func refreshTemperatures() async {
        configureAccessoryDelegates()
        let characteristics = temperatureCharacteristics()

        guard !characteristics.isEmpty else {
            latestReading = nil
            errorMessage = "Add a HomeKit temperature sensor or thermostat in the Home app to stream live room temperature."
            return
        }

        await enableNotificationsIfPossible(for: characteristics)

        var lastReadError: String?
        for (home, accessory, service, characteristic) in characteristics {
            do {
                if let value = try await readTemperature(from: characteristic) {
                    publishReading(
                        temperatureCelsius: value,
                        homeName: home.name,
                        accessory: accessory,
                        service: service
                    )
                    return
                }
            } catch {
                lastReadError = error.localizedDescription
            }
        }

        if let lastReadError, latestReading == nil {
            errorMessage = "Unable to read the HomeKit room-temperature sensor right now: \(lastReadError)"
        } else if latestReading == nil {
            errorMessage = "Waiting for a live HomeKit room-temperature reading."
        }
    }

    private func startRefreshTimerIfNeeded() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshIfPossible()
            }
        }
    }

    private func readTemperature(from characteristic: HMCharacteristic) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            characteristic.readValue { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let number = characteristic.value as? NSNumber {
                    continuation.resume(returning: number.doubleValue)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func configureAccessoryDelegates() {
        for home in homeManager.homes {
            for accessory in home.accessories {
                accessory.delegate = self
            }
        }
    }

    private func temperatureCharacteristics() -> [(home: HMHome, accessory: HMAccessory, service: HMService, characteristic: HMCharacteristic)] {
        homeManager.homes.flatMap { home in
            home.accessories.flatMap { accessory in
                accessory.services.flatMap { service in
                    service.characteristics.compactMap { characteristic in
                        guard characteristic.characteristicType == HMCharacteristicTypeCurrentTemperature else {
                            return nil
                        }
                        return (home, accessory, service, characteristic)
                    }
                }
            }
        }
    }

    private func enableNotificationsIfPossible(
        for characteristics: [(home: HMHome, accessory: HMAccessory, service: HMService, characteristic: HMCharacteristic)]
    ) async {
        for (_, _, _, characteristic) in characteristics {
            let identifier = characteristic.uniqueIdentifier
            guard !observedCharacteristicIDs.contains(identifier) else { continue }
            guard characteristic.properties.contains(HMCharacteristicPropertySupportsEventNotification) else { continue }
            do {
                try await enableNotifications(for: characteristic)
                observedCharacteristicIDs.insert(identifier)
            } catch {
                if latestReading == nil {
                    errorMessage = "HomeKit sensor connected, but live notifications couldn't start: \(error.localizedDescription)"
                }
            }
        }
    }

    private func enableNotifications(for characteristic: HMCharacteristic) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            characteristic.enableNotification(true) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func applyTemperatureUpdate(from characteristic: HMCharacteristic, accessory: HMAccessory, service: HMService) {
        guard characteristic.characteristicType == HMCharacteristicTypeCurrentTemperature else { return }
        guard let number = characteristic.value as? NSNumber else { return }

        let homeName = homeManager.homes.first(where: { home in
            home.accessories.contains(where: { $0.uniqueIdentifier == accessory.uniqueIdentifier })
        })?.name ?? "HomeKit"

        publishReading(
            temperatureCelsius: number.doubleValue,
            homeName: homeName,
            accessory: accessory,
            service: service
        )
    }

    private func publishReading(
        temperatureCelsius: Double,
        homeName: String,
        accessory: HMAccessory,
        service: HMService
    ) {
        let roomName = accessory.room?.name ?? service.name
        latestReading = Reading(
            temperatureCelsius: temperatureCelsius,
            sourceName: "\(homeName) · \(roomName)",
            updatedAt: Date()
        )
        errorMessage = nil
    }
}

#else

@MainActor
final class HomeRoomTemperatureService: NSObject, ObservableObject {
    static let shared = HomeRoomTemperatureService()

    struct Reading {
        let temperatureCelsius: Double
        let sourceName: String
        let updatedAt: Date
    }

    @Published private(set) var latestReading: Reading?
    @Published private(set) var errorMessage: String?

    func start() {}
    func stop() {}
    func refreshNow() {}
}
#endif
