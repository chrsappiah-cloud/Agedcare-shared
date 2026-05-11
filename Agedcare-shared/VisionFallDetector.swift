import Foundation
import Vision
import AVFoundation
import UIKit
import Combine

@MainActor
final class VisionFallDetector: ObservableObject {
    static let shared = VisionFallDetector()

    @Published var isAnalyzing = false
    @Published var detectedPose: DetectedPose?
    @Published var fallRiskLevel: FallRiskLevel = .none
    @Published var lastIncidentEvent: VisionIncidentEvent?

    private var bodyPoseRequest: VNDetectHumanBodyPoseRequest?
    private var previousPoseTimestamp: Date?
    private var previousHeadY: CGFloat?
    private var fallCooldown = false

    var onFallDetected: ((VisionIncidentEvent) -> Void)?
    var onInjuryDetected: ((VisionIncidentEvent) -> Void)?

    enum FallRiskLevel: String {
        case none = "None"
        case low = "Low"
        case elevated = "Elevated"
        case high = "High — Possible Fall"
        case confirmed = "Fall Detected"
    }

    struct DetectedPose {
        let headPosition: CGPoint
        let bodyCenter: CGPoint
        let isUpright: Bool
        let isOnGround: Bool
        let confidence: Float
        let timestamp: Date
    }

    struct VisionIncidentEvent: Identifiable {
        let id = UUID()
        let type: IncidentType
        let timestamp: Date
        let confidence: Double
        let snapshot: UIImage?
        let poseData: DetectedPose?

        enum IncidentType: String {
            case fall = "Fall Detected"
            case rapidDescent = "Rapid Descent"
            case prolongedGround = "Person on Ground"
            case injury = "Possible Injury"
        }
    }

    init() {
        setupVisionRequests()
    }

    private func setupVisionRequests() {
        bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    }

    // MARK: - Frame Analysis

    nonisolated func analyzeFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return }
            Task { @MainActor in
                self.processBodyPose(observation)
            }
        } catch {
            // Vision analysis failed silently — expected on some frames
        }
    }

    private func processBodyPose(_ observation: VNHumanBodyPoseObservation) {
        isAnalyzing = true

        guard let headPoint = try? observation.recognizedPoint(.nose),
              let hipPoint = try? observation.recognizedPoint(.root),
              let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
              let rightAnkle = try? observation.recognizedPoint(.rightAnkle) else {
            isAnalyzing = false
            return
        }

        let headY = headPoint.location.y
        let hipY = hipPoint.location.y
        let ankleY = (leftAnkle.location.y + rightAnkle.location.y) / 2.0
        let bodyCenter = CGPoint(x: hipPoint.location.x, y: hipY)

        let headToHipDelta = headY - hipY
        let isUpright = headToHipDelta > 0.15
        let isOnGround = headY < 0.3 && abs(headY - ankleY) < 0.1

        let avgConfidence = (headPoint.confidence + hipPoint.confidence) / 2.0

        let pose = DetectedPose(
            headPosition: CGPoint(x: headPoint.location.x, y: headY),
            bodyCenter: bodyCenter,
            isUpright: isUpright,
            isOnGround: isOnGround,
            confidence: avgConfidence,
            timestamp: Date()
        )
        detectedPose = pose

        evaluateFallRisk(pose: pose, headY: headY)
        isAnalyzing = false
    }

    private func evaluateFallRisk(pose: DetectedPose, headY: CGFloat) {
        let now = Date()

        if let prevY = previousHeadY, let prevTime = previousPoseTimestamp {
            let timeDelta = now.timeIntervalSince(prevTime)
            guard timeDelta > 0, timeDelta < 2.0 else {
                previousHeadY = headY
                previousPoseTimestamp = now
                return
            }

            let headDropRate = (prevY - headY) / timeDelta

            if headDropRate > 1.5 && !fallCooldown {
                fallRiskLevel = .confirmed
                triggerIncident(type: .fall, confidence: Double(pose.confidence), pose: pose)
            } else if headDropRate > 0.8 {
                fallRiskLevel = .high
                triggerIncident(type: .rapidDescent, confidence: Double(pose.confidence) * 0.7, pose: pose)
            } else if pose.isOnGround {
                fallRiskLevel = .elevated
                triggerIncident(type: .prolongedGround, confidence: Double(pose.confidence) * 0.5, pose: pose)
            } else if !pose.isUpright && pose.confidence > 0.5 {
                fallRiskLevel = .low
            } else {
                fallRiskLevel = .none
            }
        }

        previousHeadY = headY
        previousPoseTimestamp = now
    }

    private func triggerIncident(type: VisionIncidentEvent.IncidentType, confidence: Double, pose: DetectedPose) {
        guard !fallCooldown else { return }
        fallCooldown = true

        let snapshot = AVCaptureService.shared.captureIncidentSnapshot()
        let event = VisionIncidentEvent(
            type: type,
            timestamp: Date(),
            confidence: confidence,
            snapshot: snapshot,
            poseData: pose
        )
        lastIncidentEvent = event

        switch type {
        case .fall, .rapidDescent:
            onFallDetected?(event)
        case .prolongedGround, .injury:
            onInjuryDetected?(event)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.fallCooldown = false
        }
    }

    func reset() {
        fallRiskLevel = .none
        detectedPose = nil
        previousHeadY = nil
        previousPoseTimestamp = nil
        fallCooldown = false
        isAnalyzing = false
    }
}
