import Foundation
import SwiftUI
import WatchConnectivity
import HealthKit

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    struct AlertSnapshot: Identifiable, Codable {
        let id: Int64
        let residentId: String
        let type: String
        let status: String
        let priority: Int
        let createdAt: String
    }

    @Published var statusText = "Preparing watch link"
    @Published var heartRateText = "--"
    @Published var bloodOxygenText = "--"
    @Published var fallRisk = "unknown"
    @Published var locationName = "Waiting for iPhone"
    @Published var movementSummary = "No movement summary"
    @Published var isMonitoringActive = false
    @Published var isRecordingIncident = false
    @Published var isReachable = false
    @Published var lastSyncDate: Date?
    @Published var alerts: [AlertSnapshot] = []
    @Published var errorMessage: String?

    private let healthStore = HKHealthStore()
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() async {
        guard let session else {
            statusText = "WatchConnectivity unavailable"
            return
        }

        session.delegate = self
        session.activate()
        updateConnectivityState(from: session)
        await requestHealthAuthorization()
        requestContextRefresh()
        await refreshLatestVitals()
    }

    func sendSOS() {
        sendMessage([
            "type": "sos_from_watch",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ])
    }

    func requestContextRefresh() {
        sendMessage([
            "type": "request_context",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ])
    }

    func refreshVitalsFromWatch() {
        Task {
            await refreshLatestVitals()
        }
    }

    private func requestHealthAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let shareTypes = Set<HKSampleType>()
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        ]

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshLatestVitals() async {
        await loadLatestSample(type: .heartRate,
                               unit: .count().unitDivided(by: .minute()),
                               formatter: { "\(Int($0)) bpm" },
                               assign: { self.heartRateText = $0 },
                               metricName: "heart_rate")
        await loadLatestSample(type: .oxygenSaturation,
                               unit: .percent(),
                               formatter: { "\(Int(($0 * 100).rounded()))%" },
                               assign: { self.bloodOxygenText = $0 },
                               metricName: "blood_oxygen")
    }

    private func loadLatestSample(
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        formatter: @escaping (Double) -> String,
        assign: @escaping (String) -> Void,
        metricName: String
    ) async {
        guard HKHealthStore.isHealthDataAvailable(),
              let quantityType = HKQuantityType.quantityType(forIdentifier: type) else { return }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, error in
                Task { @MainActor in
                    defer { continuation.resume() }
                    if let error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    guard let sample = samples?.first as? HKQuantitySample else { return }
                    let value = sample.quantity.doubleValue(for: unit)
                    let formatted = formatter(value)
                    assign(formatted)
                    self?.lastSyncDate = Date()
                    self?.sendMessage([
                        "type": "vital_from_watch",
                        "metric": metricName,
                        "value": value,
                        "timestamp": ISO8601DateFormatter().string(from: sample.endDate),
                    ])
                }
            }
            healthStore.execute(query)
        }
    }

    private func updateConnectivityState(from session: WCSession) {
        isReachable = session.isReachable

        if session.activationState != .activated {
            statusText = "Activating watch connection"
        } else if isReachable {
            statusText = "Watch connected"
        } else {
            statusText = "Background sync ready"
        }
    }

    private func sendMessage(_ payload: [String: Any]) {
        guard let session else { return }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func handle(applicationContext: [String: Any]) {
        lastSyncDate = Date()

        if let residentStatus = applicationContext["residentStatus"] as? [String: Any] {
            statusText = residentStatus["statusText"] as? String ?? statusText
            isMonitoringActive = residentStatus["isMonitoringActive"] as? Bool ?? isMonitoringActive
            isRecordingIncident = residentStatus["isRecordingIncident"] as? Bool ?? isRecordingIncident
            fallRisk = residentStatus["fallRisk"] as? String ?? fallRisk
            locationName = residentStatus["locationName"] as? String ?? locationName
            movementSummary = residentStatus["movementSummary"] as? String ?? movementSummary
            heartRateText = residentStatus["heartRate"] as? String ?? heartRateText
            bloodOxygenText = residentStatus["bloodOxygen"] as? String ?? bloodOxygenText
        }

        if let alertsObject = applicationContext["alerts"] {
            do {
                let data = try JSONSerialization.data(withJSONObject: alertsObject)
                alerts = try JSONDecoder().decode([AlertSnapshot].self, from: data)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.updateConnectivityState(from: session)
            if let error {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateConnectivityState(from: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handle(applicationContext: applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            self.handle(applicationContext: userInfo)
        }
    }
}
