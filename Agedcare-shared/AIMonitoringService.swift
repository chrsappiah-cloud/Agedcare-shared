import Foundation
import Combine
import UIKit

@MainActor
final class AIMonitoringService: ObservableObject {
  static let shared = AIMonitoringService()

  private let session = URLSession.shared
  private let requestFactory = BackendRequestFactory()
  private let backupStore = ICloudBackupStore.shared

  @Published var recentInsights: [MediaAnalysisResult] = []
  @Published var activeSessions: [AudioMonitorSession] = []
  @Published var recentEvents: [AudioMonitorEvent] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private var pollTimer: Timer?

  init() {
  }

  // MARK: - Media Analysis

  func analyzeImage(_ image: UIImage, facilityId: String, residentId: String? = nil) async -> MediaAnalysisResult? {
    guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
    let b64 = data.base64EncodedString()
    return await analyzeMedia(b64, filename: "photo_\(UUID().uuidString.prefix(8)).jpg", mediaType: "photo", facilityId: facilityId, residentId: residentId)
  }

  func analyzeAudioBase64(_ b64: String, filename: String, facilityId: String, residentId: String? = nil, transcribedText: String? = nil) async -> MediaAnalysisResult? {
    return await analyzeMedia(b64, filename: filename, mediaType: "audio", facilityId: facilityId, residentId: residentId, transcribedText: transcribedText)
  }

  func analyzeVideoFile(at url: URL, facilityId: String, residentId: String? = nil, incidentType: String? = nil) async -> MediaAnalysisResult? {
    let b64: String
    do {
      b64 = try await base64EncodedContents(of: url)
    } catch {
      errorMessage = "Cannot read video file"
      return nil
    }
    let context = incidentType.map { "Incident type: \($0.replacingOccurrences(of: "_", with: " "))" }
    return await analyzeMedia(
      b64,
      filename: url.lastPathComponent,
      mediaType: "video",
      facilityId: facilityId,
      residentId: residentId,
      transcribedText: context
    )
  }

  private func analyzeMedia(_ b64: String, filename: String, mediaType: String, facilityId: String, residentId: String? = nil, transcribedText: String? = nil) async -> MediaAnalysisResult? {
    do {
      var req = try requestFactory.makeRequest(path: "ai/analyze/media", method: "POST")
      var body: [String: Any] = [
        "data_base64": b64,
        "filename": filename,
        "media_type": mediaType,
        "facility_id": facilityId,
      ]
      if let rid = residentId { body["resident_id"] = rid }
      if let tt = transcribedText { body["transcribed_text"] = tt }
      req.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, _) = try await session.data(for: req)
      let decoder = JSONDecoder()
      return try decoder.decode(MediaAnalysisResult.self, from: data)
    } catch {
      errorMessage = error.userFacingMessage(fallback: "Monitoring analysis is temporarily unavailable. Please try again shortly.")
      return nil
    }
  }

  // MARK: - Insights Fetching

  func fetchInsights(facilityId: String, limit: Int = 20) async {
    isLoading = true
    errorMessage = nil

    do {
      var req = try requestFactory.makeRequest(path: "ai/insights", method: "POST")
      let body: [String: Any] = ["facility_id": facilityId, "limit": limit]
      req.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, _) = try await session.data(for: req)
      let decoder = JSONDecoder()
      recentInsights = try decoder.decode([MediaAnalysisResult].self, from: data)
      backupStore.saveInsights(recentInsights, facilityId: facilityId)
    } catch {
      errorMessage = error.userFacingMessage(fallback: "Monitoring insights are temporarily unavailable. Showing the latest saved updates instead.")
      if let cached = backupStore.loadInsights(facilityId: facilityId) {
        recentInsights = cached
      }
    }
    isLoading = false
  }

  // MARK: - Audio Monitoring Sessions

  func startMonitoring(facilityId: String, residentId: String? = nil, staffId: String? = nil) async -> String? {
    do {
      var req = try requestFactory.makeRequest(path: "ai/monitor/start", method: "POST")
      var body: [String: Any] = ["facility_id": facilityId]
      if let rid = residentId { body["resident_id"] = rid }
      if let sid = staffId { body["started_by"] = sid }
      req.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, _) = try await session.data(for: req)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      return json?["session_id"] as? String
    } catch {
      errorMessage = error.userFacingMessage(fallback: "Monitoring could not start right now. Please try again.")
      return nil
    }
  }

  func stopMonitoring(sessionId: String) async {
    do {
      let req = try requestFactory.makeRequest(path: "ai/monitor/\(sessionId)/stop", method: "POST")
      _ = try await session.data(for: req)
    } catch {
      errorMessage = error.userFacingMessage(fallback: "Monitoring could not stop cleanly. Please try again.")
    }
  }

  func reportEvent(sessionId: String, event: AIEventReport) async {
    do {
      var req = try requestFactory.makeRequest(path: "ai/monitor/\(sessionId)/event", method: "POST")
      req.httpBody = try JSONEncoder().encode(event)
      _ = try await session.data(for: req)
    } catch {
      errorMessage = error.userFacingMessage(fallback: "Monitoring updates are temporarily unavailable. Please try again.")
    }
  }

  func fetchSessions(facilityId: String, limit: Int = 10) async {
    do {
      var req = try requestFactory.makeRequest(path: "ai/sessions", method: "POST")
      let body: [String: Any] = ["facility_id": facilityId, "limit": limit]
      req.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, _) = try await session.data(for: req)
      let decoder = JSONDecoder()
      activeSessions = try decoder.decode([AudioMonitorSession].self, from: data)
      backupStore.saveSessions(activeSessions, facilityId: facilityId)
    } catch {
      errorMessage = error.userFacingMessage(fallback: "Monitoring sessions are temporarily unavailable. Showing the latest saved updates instead.")
      if let cached = backupStore.loadSessions(facilityId: facilityId) {
        activeSessions = cached
      }
    }
  }

  func fetchRecentEvents(facilityId: String, hours: Int = 24) async {
    do {
      var req = try requestFactory.makeRequest(path: "ai/events/recent", method: "POST")
      let body: [String: Any] = ["facility_id": facilityId, "hours": hours]
      req.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, _) = try await session.data(for: req)
      let decoder = JSONDecoder()
      recentEvents = try decoder.decode([AudioMonitorEvent].self, from: data)
      backupStore.saveEvents(recentEvents, facilityId: facilityId)
    } catch {
      errorMessage = error.userFacingMessage(fallback: "Recent monitoring events are temporarily unavailable. Showing the latest saved updates instead.")
      if let cached = backupStore.loadEvents(facilityId: facilityId) {
        recentEvents = cached
      }
    }
  }

  // MARK: - Polling

  func startPolling(facilityId: String, interval: TimeInterval = 10) {
    stopPolling()
    pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      Task { [weak self] in
        await self?.fetchRecentEvents(facilityId: facilityId)
      }
    }
  }

  func stopPolling() {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  deinit {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  private nonisolated func base64EncodedContents(of url: URL) async throws -> String {
    try await Task.detached(priority: .userInitiated) {
      let data = try Data(contentsOf: url)
      return data.base64EncodedString()
    }.value
  }
}
