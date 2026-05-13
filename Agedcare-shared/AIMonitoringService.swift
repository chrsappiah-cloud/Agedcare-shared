import Foundation
import Combine
import UIKit

@MainActor
final class AIMonitoringService: ObservableObject {
  private struct ExternalAIConfiguration {
    let chatCompletionsURL: URL
    let apiKey: String?
    let model: String
    let providerName: String
  }

  private struct OpenAICompatibleChatRequest: Encodable {
    struct Message: Encodable {
      struct ContentPart: Encodable {
        struct ImageURL: Encodable {
          let url: String
        }

        let type: String
        let text: String?
        let imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
          case type
          case text
          case imageURL = "image_url"
        }
      }

      let role: String
      let content: [ContentPart]
    }

    struct ResponseFormat: Encodable {
      let type: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
      case model
      case messages
      case temperature
      case responseFormat = "response_format"
    }
  }

  private struct OpenAICompatibleChatResponse: Decodable {
    struct Choice: Decodable {
      struct Message: Decodable {
        let content: String
      }

      let message: Message
    }

    let choices: [Choice]
  }

  private struct ExternalIncidentEnhancementPayload: Decodable {
    struct SafetyFlagPayload: Decodable {
      let type: String
      let detail: String
    }

    let summary: String?
    let confidence: Double?
    let insights: [String]?
    let keywords: [String]?
    let safetyFlags: [SafetyFlagPayload]?

    enum CodingKeys: String, CodingKey {
      case summary
      case confidence
      case insights
      case keywords
      case safetyFlags = "safety_flags"
    }
  }

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

  func analyzeVideoFile(
    at url: URL,
    facilityId: String,
    residentId: String? = nil,
    incidentType: String? = nil,
    snapshotURL: URL? = nil,
    locationSnapshot: IncidentLocationSnapshot? = nil
  ) async -> MediaAnalysisResult? {
    let b64: String
    do {
      b64 = try await base64EncodedContents(of: url)
    } catch {
      errorMessage = "Cannot read video file"
      return nil
    }
    let context = incidentType.map { "Incident type: \($0.replacingOccurrences(of: "_", with: " "))" }
    let primaryAnalysis = await analyzeMedia(
      b64,
      filename: url.lastPathComponent,
      mediaType: "video",
      facilityId: facilityId,
      residentId: residentId,
      transcribedText: context
    )

    do {
      guard let configuration = Self.externalAIConfiguration() else {
        return primaryAnalysis
      }

      let enhancement = try await enhanceIncidentVideoExternally(
        fileURL: url,
        snapshotURL: snapshotURL,
        incidentType: incidentType,
        facilityId: facilityId,
        residentId: residentId,
        locationSnapshot: locationSnapshot,
        configuration: configuration
      )

      errorMessage = nil
      if let primaryAnalysis {
        return Self.mergeAnalysis(
          primary: primaryAnalysis,
          summary: enhancement.summary,
          confidence: enhancement.confidence,
          insights: enhancement.insights ?? [],
          detectedKeywords: enhancement.keywords ?? [],
          safetyFlags: (enhancement.safetyFlags ?? []).map {
            MediaAnalysisResult.SafetyFlag(type: $0.type, detail: $0.detail)
          },
          providerName: configuration.providerName
        )
      }

      return Self.syntheticAnalysisResult(
        facilityId: facilityId,
        residentId: residentId,
        mediaURL: url.absoluteString,
        payload: enhancement,
        providerName: configuration.providerName
      )
    } catch {
      if primaryAnalysis == nil {
        errorMessage = error.userFacingMessage(
          fallback: "Monitoring analysis is temporarily unavailable. Please try again shortly."
        )
      }
      return primaryAnalysis
    }
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

  private func enhanceIncidentVideoExternally(
    fileURL: URL,
    snapshotURL: URL?,
    incidentType: String?,
    facilityId: String,
    residentId: String?,
    locationSnapshot: IncidentLocationSnapshot?,
    configuration: ExternalAIConfiguration
  ) async throws -> ExternalIncidentEnhancementPayload {
    let prompt = Self.incidentVideoEnhancementPrompt(
      incidentType: incidentType,
      locationSnapshot: locationSnapshot,
      includesSnapshot: snapshotURL != nil
    )

    var content = [
      OpenAICompatibleChatRequest.Message.ContentPart(
        type: "text",
        text: prompt,
        imageURL: nil
      )
    ]

    if let snapshotURL,
       let snapshotData = try? Data(contentsOf: snapshotURL),
       let mimeType = Self.mimeType(for: snapshotURL) {
      let dataURL = "data:\(mimeType);base64,\(snapshotData.base64EncodedString())"
      content.append(
        OpenAICompatibleChatRequest.Message.ContentPart(
          type: "image_url",
          text: nil,
          imageURL: .init(url: dataURL)
        )
      )
    }

    let requestBody = OpenAICompatibleChatRequest(
      model: configuration.model,
      messages: [
        .init(role: "system", content: [
          .init(
            type: "text",
            text: "You review aged-care incident footage support material. Return only compact JSON with keys summary, confidence, insights, keywords, and safety_flags.",
            imageURL: nil
          )
        ]),
        .init(role: "user", content: content),
      ],
      temperature: 0.2,
      responseFormat: .init(type: "json_object")
    )

    var request = URLRequest(url: configuration.chatCompletionsURL, timeoutInterval: 45)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let apiKey = configuration.apiKey {
      request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try JSONEncoder().encode(requestBody)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      throw URLError(.badServerResponse)
    }

    let completion = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
    guard let content = completion.choices.first?.message.content,
          let payloadData = content.data(using: .utf8) else {
      throw URLError(.cannotParseResponse)
    }

    return try JSONDecoder().decode(ExternalIncidentEnhancementPayload.self, from: payloadData)
  }

  private nonisolated static func externalAIConfiguration() -> ExternalAIConfiguration? {
    guard let chatCompletionsURL = AppHost.externalAIChatCompletionsURL,
          let model = AppHost.externalAIModel else {
      return nil
    }
    return ExternalAIConfiguration(
      chatCompletionsURL: chatCompletionsURL,
      apiKey: AppHost.externalAIAPIKey,
      model: model,
      providerName: AppHost.externalAIProviderName
    )
  }

  nonisolated static func incidentVideoEnhancementPrompt(
    incidentType: String?,
    locationSnapshot: IncidentLocationSnapshot?,
    includesSnapshot: Bool
  ) -> String {
    var lines = [
      "Review this aged-care incident recording context and return JSON only.",
      "Focus on fall risk, visible safety concerns, scene hazards, and useful escalation notes. Do not diagnose.",
      "Snapshot frame attached: \(includesSnapshot ? "yes" : "no")",
      "Incident type: \((incidentType ?? "unspecified").replacingOccurrences(of: "_", with: " "))",
    ]

    if let locationSnapshot {
      lines.append("Location: \(locationSnapshot.locationName)")
      lines.append("Movement: \(locationSnapshot.movementSummary)")
      lines.append("Coordinates: \(locationSnapshot.coordinateDescription)")
      if let roomTemperature = locationSnapshot.roomTemperatureCelsius {
        lines.append("Room temperature: \(String(format: "%.1f", roomTemperature)) C")
      }
      if let roomSource = locationSnapshot.roomTemperatureSource, !roomSource.isEmpty {
        lines.append("Room temperature source: \(roomSource)")
      }
    } else {
      lines.append("Location context unavailable")
    }

    lines.append("Return JSON: {\"summary\": string, \"confidence\": number, \"insights\": [string], \"keywords\": [string], \"safety_flags\": [{\"type\": string, \"detail\": string}]}")
    return lines.joined(separator: "\n")
  }

  nonisolated static func mergeAnalysis(
    primary: MediaAnalysisResult,
    summary: String?,
    confidence: Double?,
    insights: [String],
    detectedKeywords: [String],
    safetyFlags: [MediaAnalysisResult.SafetyFlag],
    providerName: String
  ) -> MediaAnalysisResult {
    let mergedInsights = deduplicated(
      primary.insights + insights + ["Enhanced via \(providerName)"]
    )
    let mergedKeywords = deduplicated(primary.detected_keywords + detectedKeywords)
    let mergedFlags = deduplicatedFlags(primary.safety_flags + safetyFlags)
    let resolvedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      ? summary
      : (primary.summary ?? mergedInsights.first)

    return MediaAnalysisResult(
      id: primary.id,
      facility_id: primary.facility_id,
      resident_id: primary.resident_id,
      resident_name: primary.resident_name,
      media_url: primary.media_url,
      media_type: primary.media_type,
      analysis_status: primary.analysis_status,
      summary: resolvedSummary,
      confidence: max(primary.confidence, confidence ?? primary.confidence),
      insights: mergedInsights,
      detected_keywords: mergedKeywords,
      sentiment: primary.sentiment,
      safety_flags: mergedFlags,
      transcribed_text: primary.transcribed_text,
      created_at: primary.created_at,
      completed_at: primary.completed_at
    )
  }

  private nonisolated static func syntheticAnalysisResult(
    facilityId: String,
    residentId: String?,
    mediaURL: String,
    payload: ExternalIncidentEnhancementPayload,
    providerName: String
  ) -> MediaAnalysisResult {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let safetyFlags = (payload.safetyFlags ?? []).map {
      MediaAnalysisResult.SafetyFlag(type: $0.type, detail: $0.detail)
    }

    return MediaAnalysisResult(
      id: "external-\(UUID().uuidString)",
      facility_id: facilityId,
      resident_id: residentId,
      resident_name: nil,
      media_url: mediaURL,
      media_type: "video",
      analysis_status: "completed",
      summary: payload.summary ?? payload.insights?.first ?? "Incident enhancement generated",
      confidence: payload.confidence ?? 0.6,
      insights: deduplicated((payload.insights ?? []) + ["Enhanced via \(providerName)"]),
      detected_keywords: deduplicated(payload.keywords ?? []),
      sentiment: nil,
      safety_flags: safetyFlags,
      transcribed_text: nil,
      created_at: timestamp,
      completed_at: timestamp
    )
  }

  private nonisolated static func deduplicated(_ values: [String]) -> [String] {
    var unique = [String]()
    for value in values {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, !unique.contains(trimmed) else { continue }
      unique.append(trimmed)
    }
    return unique
  }

  private nonisolated static func deduplicatedFlags(_ flags: [MediaAnalysisResult.SafetyFlag]) -> [MediaAnalysisResult.SafetyFlag] {
    var unique = [MediaAnalysisResult.SafetyFlag]()
    for flag in flags where !unique.contains(where: { $0.type == flag.type && $0.detail == flag.detail }) {
      unique.append(flag)
    }
    return unique
  }

  private nonisolated static func mimeType(for url: URL) -> String? {
    switch url.pathExtension.lowercased() {
    case "jpg", "jpeg":
      return "image/jpeg"
    case "png":
      return "image/png"
    default:
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
