import Foundation
import HealthKit
import CloudKit
import Combine
import Vision
import UserNotifications

@MainActor
final class MonitoringCoordinator: ObservableObject {
  @Published var monitoringEnabled = false
  @Published var healthKitAuthorized = false
  @Published var lastEvent: FallDetectionEvent?
  @Published var lastErrorMessage: String?
  @Published var latestHeartRate: String?
  @Published var latestBloodOxygen: String?
  @Published var hkAuthError: String?
  @Published var visionFallRisk: VisionFallDetector.FallRiskLevel = .none
  @Published var isRecordingIncident = false

  private let fallService: FallService
  private let facilityId: UUID
  private let residentId: UUID
  private let alertsRepository: AlertsRepositoryProtocol
  private let residentsRepository: ResidentsRepositoryProtocol
  private var healthTask: Task<Void, Never>?
  private var vitalEventTask: Task<Void, Never>?
  private var incidentResetTask: Task<Void, Never>?

  init(fallService: FallService, facilityId: UUID, residentId: UUID, alertsRepository: AlertsRepositoryProtocol, residentsRepository: ResidentsRepositoryProtocol) {
    self.fallService = fallService
    self.facilityId = facilityId
    self.residentId = residentId
    self.alertsRepository = alertsRepository
    self.residentsRepository = residentsRepository
    self.fallService.delegate = self
    setupVisionFallDetection()
  }

  func startMonitoring() {
    monitoringEnabled = true
    fallService.start()
    authorizeAndStartHealthKit()
    subscribeToCloudKitAlerts()
    LocationWeatherService.shared.requestPermissionAndStart()
    Task { await AVCaptureService.shared.prepareCapturePipeline() }
    startVideoMonitoring()
    syncWatchMonitoringStatus(statusText: "Monitoring active")
  }

  func stopMonitoring() {
    monitoringEnabled = false
    fallService.stop()
    healthTask?.cancel()
    healthTask = nil
    vitalEventTask?.cancel()
    vitalEventTask = nil
    incidentResetTask?.cancel()
    incidentResetTask = nil
    AVCaptureService.shared.frameHandler = nil
    syncWatchMonitoringStatus(statusText: "Monitoring paused")
  }

  // MARK: - Vision Fall Detection

  private func setupVisionFallDetection() {
    VisionFallDetector.shared.onFallDetected = { [weak self] event in
      Task { @MainActor in
        self?.handleVisionFallEvent(event)
      }
    }
    VisionFallDetector.shared.onInjuryDetected = { [weak self] event in
      Task { @MainActor in
        self?.handleVisionInjuryEvent(event)
      }
    }
  }

  private func startVideoMonitoring() {
    AVCaptureService.shared.frameHandler = { sampleBuffer in
      VisionFallDetector.shared.analyzeFrame(sampleBuffer)
    }
  }

  private func handleVisionFallEvent(_ event: VisionFallDetector.VisionIncidentEvent) {
    visionFallRisk = VisionFallDetector.shared.fallRiskLevel
    startManagedIncidentCapture(
      type: "fall",
      priority: 3,
      title: "Fall Detected (Vision)",
      body: "Camera detected a possible fall. Recording incident video."
    )
  }

  private func handleVisionInjuryEvent(_ event: VisionFallDetector.VisionIncidentEvent) {
    visionFallRisk = VisionFallDetector.shared.fallRiskLevel
    startManagedIncidentCapture(
      type: "injury",
      priority: 3,
      title: "Possible Injury Detected",
      body: "Camera analysis suggests a possible injury. Recording."
    )
  }

  private func authorizeAndStartHealthKit() {
    guard HealthKitService.shared.isAvailable else {
      hkAuthError = "HealthKit not available on this device"
      return
    }

    Task {
      do {
        try await HealthKitService.shared.requestAuthorization()
        healthKitAuthorized = true
        hkAuthError = nil
        startHealthKitMonitoring()
      } catch {
        hkAuthError = "HealthKit auth failed: \(error.localizedDescription)"
        healthKitAuthorized = false
      }
    }
  }

  private func startHealthKitMonitoring() {
    guard HealthKitService.shared.isAvailable, healthKitAuthorized else { return }

    healthTask = Task { [weak self] in
      do {
        let stream = HealthKitService.shared.startHeartRateMonitoring(interval: 30)
        for try await reading in stream {
          guard let self = self, self.monitoringEnabled else { break }
          self.latestHeartRate = "\(Int(reading.value)) bpm"
          self.syncWatchVital(metric: "heart_rate", value: reading.value)
          self.syncWatchMonitoringStatus(statusText: "Monitoring active")

          if let alert = HealthKitService.shared.detectAbnormalVitals(reading: reading) {
            await self.handleVitalAlert(alert)
          }

          await self.recordVitalReading(reading)
        }
      } catch {
        print("[MonitoringCoordinator] HealthKit monitoring error: \(error)")
      }
    }
  }

  private func recordVitalReading(_ reading: VitalReading) async {
    #if canImport(HealthKit)
    let metric: String
    let value: Double
    switch reading.type {
    case .heartRate:
      metric = "heart_rate"
      value = reading.value
    case .oxygenSaturation:
      metric = "blood_oxygen"
      value = reading.value
    default:
      return
    }
    #else
    let metric = reading.type
    let value = reading.value
    #endif

    do {
      try await residentsRepository.recordVitalEvent(
        facilityId: facilityId,
        residentId: residentId,
        metric: metric,
        value: value,
        timestamp: reading.timestamp
      )
    } catch {
      print("[MonitoringCoordinator] Failed to record vital: \(error)")
    }
  }

  private func handleVitalAlert(_ alert: VitalAlert) async {
    let title: String
    let body: String

    switch alert {
    case .highHeartRate(let reading):
      title = "High Heart Rate"
      body = "\(Int(reading.value)) bpm — above threshold"
    case .lowHeartRate(let reading):
      title = "Low Heart Rate"
      body = "\(Int(reading.value)) bpm — below threshold"
    case .lowBloodOxygen(let reading):
      title = "Low Blood Oxygen"
      body = "\(Int(reading.value * 100))% — below 90% threshold"
    case .fallImpact:
      title = "Fall Impact Detected"
      body = "Motion sensors detected a potential fall"
      await triggerExternalAlert(type: "fall", priority: 3)
    }

    postLocalNotification(title: title, body: body)
    syncWatchMonitoringStatus(statusText: title)
  }

  private func triggerExternalAlert(type: String, priority: Int) async {
    do {
      switch type {
      case "injury", "sos":
        let _ = try await alertsRepository.createSOSAlert(facilityId: facilityId, residentId: residentId)
      default:
        let _ = try await alertsRepository.createFallAlert(facilityId: facilityId, residentId: residentId, priority: priority)
      }
      lastErrorMessage = nil
    } catch {
      lastErrorMessage = "Alert creation failed: \(error.localizedDescription)"
    }
  }

  private func subscribeToCloudKitAlerts() {
    #if canImport(CloudKit)
    guard let sync = CloudKitAlertSync.shared else { return }
    sync.alertUpdateHandler = { [weak self] alert, reason in
      let title = "Alert \(reason == .recordCreated ? "" : "Updated")"
      let body = "\(alert.typeDisplay) — Priority \(alert.priority)"
      Swift.Task { @MainActor in
        self?.postLocalNotification(title: title, body: body)
      }
    }
    #endif
  }

  private func postLocalNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}

extension MonitoringCoordinator: FallServiceDelegate {
  func fallServiceDidTriggerPossibleFall(_ service: FallService, event: FallDetectionEvent) {
    lastEvent = event
    if !isRecordingIncident {
      startManagedIncidentCapture(
        type: "fall_motion",
        priority: 3,
        title: "Possible Fall Detected",
        body: "Staff have been notified. Incident video recording started."
      )
      return
    }
    Task { await triggerExternalAlert(type: "fall", priority: 3) }
  }

  func fallService(_ service: FallService, didFailWith error: Error) {
    lastErrorMessage = error.localizedDescription
  }

  private func startManagedIncidentCapture(type: String, priority: Int, title: String, body: String) {
    isRecordingIncident = true
    AVCaptureService.shared.startIncidentRecording(type: type, facilityId: facilityId, residentId: residentId)
    postLocalNotification(title: title, body: body)
    syncWatchMonitoringStatus(statusText: title)
    Task { await triggerExternalAlert(type: type, priority: priority) }

    incidentResetTask?.cancel()
    incidentResetTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 32_000_000_000)
      await MainActor.run {
        self?.isRecordingIncident = false
        self?.syncWatchMonitoringStatus(statusText: "Monitoring active")
      }
    }
  }

  private func syncWatchVital(metric: String, value: Double) {
    WatchConnectivityService.shared.sendVitalUpdate(
      facilityId: facilityId.uuidString,
      residentId: residentId.uuidString,
      metric: metric,
      value: value
    )
  }

  private func syncWatchMonitoringStatus(statusText: String) {
    let snapshot = LocationWeatherService.shared.snapshot
    WatchConnectivityService.shared.syncResidentStatus(
      .init(
        facilityId: facilityId.uuidString,
        residentId: residentId.uuidString,
        statusText: statusText,
        isMonitoringActive: monitoringEnabled,
        isRecordingIncident: isRecordingIncident,
        fallRisk: String(describing: visionFallRisk),
        heartRate: latestHeartRate,
        bloodOxygen: latestBloodOxygen,
        locationName: snapshot.locationName.isEmpty ? nil : snapshot.locationName,
        movementSummary: snapshot.movementStateDescription(),
        recordedAt: ISO8601DateFormatter().string(from: Date())
      )
    )
  }
}
