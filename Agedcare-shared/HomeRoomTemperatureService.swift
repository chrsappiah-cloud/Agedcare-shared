import Foundation
import Combine

#if canImport(HomeKit)
import HomeKit

@MainActor
final class HomeRoomTemperatureService: NSObject, ObservableObject, HMHomeManagerDelegate {
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

    override init() {
        super.init()
        homeManager.delegate = self
    }

    func start() {
        refreshIfPossible()
    }

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.refreshIfPossible()
        }
    }

    private func refreshIfPossible() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.refreshTemperatures()
        }
    }

    private func refreshTemperatures() async {
        for home in homeManager.homes {
            for accessory in home.accessories {
                for service in accessory.services {
                    for characteristic in service.characteristics where characteristic.characteristicType == HMCharacteristicTypeCurrentTemperature {
                        do {
                            if let value = try await readTemperature(from: characteristic) {
                                let roomName = accessory.room?.name ?? service.name
                                latestReading = Reading(
                                    temperatureCelsius: value,
                                    sourceName: "\(home.name) · \(roomName)",
                                    updatedAt: Date()
                                )
                                errorMessage = nil
                                return
                            }
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
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
}
#endif
