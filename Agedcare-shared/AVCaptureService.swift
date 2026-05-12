import AVFoundation
import UIKit
import Combine
import Photos

enum IncidentSyncStatus: String, Codable {
    case localOnly
    case pendingUpload
    case synced
    case failed
}

struct IncidentLocationSnapshot: Codable, Equatable {
    let locationName: String
    let latitude: Double?
    let longitude: Double?
    let speedMetersPerSecond: Double?
    let headingDegrees: Double?
    let totalDistanceMeters: Double
    let roomTemperatureCelsius: Double?
    let roomTemperatureSource: String?
    let capturedAt: Date

    init(weatherSnapshot: WeatherSnapshot, capturedAt: Date = Date()) {
        locationName = weatherSnapshot.locationName
        latitude = weatherSnapshot.coordinate?.latitude
        longitude = weatherSnapshot.coordinate?.longitude
        speedMetersPerSecond = weatherSnapshot.currentSpeedMetersPerSecond
        headingDegrees = weatherSnapshot.headingDegrees
        totalDistanceMeters = weatherSnapshot.totalDistanceMeters
        roomTemperatureCelsius = weatherSnapshot.roomTemperature
        roomTemperatureSource = weatherSnapshot.roomTemperatureSourceDescription()
        self.capturedAt = capturedAt
    }

    var coordinateDescription: String {
        guard let latitude, let longitude else { return "Location unavailable" }
        return String(format: "%.5f, %.5f", latitude, longitude)
    }

    var movementSummary: String {
        if let speedMetersPerSecond, speedMetersPerSecond >= 0.4 {
            return String(format: "Moving at %.1f km/h", speedMetersPerSecond * 3.6)
        }
        if totalDistanceMeters > 0 {
            return "Stationary after moving \(Int(totalDistanceMeters.rounded())) m"
        }
        return "Movement not yet established"
    }
}

enum CaptureError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case permissionDenied(String)
    case sessionConfigFailed(String)
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: return "Camera is not available on this device"
        case .microphoneUnavailable: return "Microphone is not available on this device"
        case .permissionDenied(let resource): return "\(resource) access was denied"
        case .sessionConfigFailed(let msg): return "Capture session configuration failed: \(msg)"
        case .recordingFailed(let msg): return "Recording failed: \(msg)"
        }
    }
}

@MainActor
final class AVCaptureService: NSObject, ObservableObject {
    static let shared = AVCaptureService()

    @Published var isCameraAuthorized = false
    @Published var isMicrophoneAuthorized = false
    @Published var isVideoRecording = false
    @Published var isAudioRecording = false
    @Published var currentAudioLevel: Float = 0
    @Published var lastCapturedImage: UIImage?
    @Published var lastRecordingURL: URL?
    @Published var errorMessage: String?
    @Published var incidentRecordings: [IncidentRecording] = []
    @Published var isCapturePipelineReady = false

    private(set) var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var levelTimer: Timer?

    private var photoCaptureDelegate: PhotoCaptureDelegate?
    private var videoCaptureDelegate: VideoCaptureDelegate?

    var frameHandler: ((CMSampleBuffer) -> Void)?

    private let preIncidentBufferDuration: TimeInterval = 15
    private var circularBuffer: CircularFrameBuffer?
    private var isAutoRecordingIncident = false
    private var incidentAssetWriter: AVAssetWriter?
    private var incidentWriterInput: AVAssetWriterInput?
    private var incidentStartTime: CMTime?
    private var activeIncidentContext: ActiveIncidentContext?
    private let backupStore = ICloudBackupStore.shared
    private let incidentMediaClient = SupabaseClient(
        config: SupabaseConfig(baseURL: AppHost.supabaseBaseURL, apiKey: AppHost.supabaseAnonKey),
        accessTokenProvider: { SupabaseAuthStore.shared.accessToken }
    )

    let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let incidentsDir: URL

    override private init() {
        incidentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Incidents", isDirectory: true)
        super.init()
        try? FileManager.default.createDirectory(at: incidentsDir, withIntermediateDirectories: true)
        loadIncidentRecordings()
        Task { [weak self] in
            await self?.retryPendingIncidentSyncs()
        }
    }

    // MARK: - Permission Requests

    func requestAllPermissions() async {
        await requestCameraPermission()
        await requestMicrophonePermission()
        await prepareCapturePipeline()
    }

    func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            isCameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isCameraAuthorized = false
        }
    }

    func requestMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            isMicrophoneAuthorized = true
        case .notDetermined:
            isMicrophoneAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            isMicrophoneAuthorized = false
        }
    }

    // MARK: - Camera Session Setup

    func prepareCapturePipeline() async {
        guard isCameraAuthorized else {
            isCapturePipelineReady = false
            return
        }

        do {
            try configureAudioSession()
            if captureSession == nil {
                try setupCaptureSession()
            }
            startCaptureSession()
            isCapturePipelineReady = true
            errorMessage = nil
        } catch {
            isCapturePipelineReady = false
            errorMessage = error.userFacingMessage(fallback: "Video capture is temporarily unavailable. Please try again.")
        }
    }

    func setupCaptureSession() throws {
        guard captureSession == nil else { return }
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
              ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CaptureError.cameraUnavailable
        }

        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(videoInput) else {
            throw CaptureError.sessionConfigFailed("Cannot add video input")
        }
        session.addInput(videoInput)

        if let mic = AVCaptureDevice.default(for: .audio) {
            if let audioInput = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }

        let movieOutput = AVCaptureMovieFileOutput()
        movieOutput.maxRecordedDuration = CMTime(seconds: 300, preferredTimescale: 600)
        guard session.canAddOutput(movieOutput) else {
            throw CaptureError.sessionConfigFailed("Cannot add movie output")
        }
        session.addOutput(movieOutput)
        videoOutput = movieOutput

        let photo = AVCapturePhotoOutput()
        guard session.canAddOutput(photo) else {
            throw CaptureError.sessionConfigFailed("Cannot add photo output")
        }
        session.addOutput(photo)
        photoOutput = photo

        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        dataOutput.alwaysDiscardsLateVideoFrames = true
        let dataQueue = DispatchQueue(label: "wcs.agedcare.videoDataOutput", qos: .userInteractive)
        dataOutput.setSampleBufferDelegate(VideoDataDelegate.shared, queue: dataQueue)
        guard session.canAddOutput(dataOutput) else {
            throw CaptureError.sessionConfigFailed("Cannot add video data output")
        }
        session.addOutput(dataOutput)
        videoDataOutput = dataOutput

        session.commitConfiguration()
        captureSession = session

        circularBuffer = CircularFrameBuffer(maxDuration: preIncidentBufferDuration)
        VideoDataDelegate.shared.onFrame = { [weak self] sampleBuffer in
            self?.circularBuffer?.append(sampleBuffer)
            self?.frameHandler?(sampleBuffer)
            if let self, self.isAutoRecordingIncident {
                self.writeIncidentFrame(sampleBuffer)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    func startCaptureSession() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stopCaptureSession() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        guard let photoOutput else {
            errorMessage = "Photo output not configured"
            return
        }
        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate { [weak self] image in
            Task { @MainActor in
                self?.lastCapturedImage = image
            }
        }
        photoCaptureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    func captureIncidentSnapshot() -> UIImage? {
        guard let buffer = circularBuffer?.latestFrame,
              let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Video Recording

    func startVideoRecording() throws {
        guard let output = videoOutput else {
            throw CaptureError.recordingFailed("Video output not configured")
        }
        guard !output.isRecording else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "video_\(formatter.string(from: Date())).mov"
        let url = documentsDir.appendingPathComponent(filename)

        let delegate = VideoCaptureDelegate { [weak self] url, error in
            Task { @MainActor in
                self?.isVideoRecording = false
                if let error {
                    self?.errorMessage = error.userFacingMessage(fallback: "Video recording could not be completed.")
                } else {
                    self?.lastRecordingURL = url
                }
            }
        }
        videoCaptureDelegate = delegate
        output.startRecording(to: url, recordingDelegate: delegate)
        isVideoRecording = true
    }

    func stopVideoRecording() {
        videoOutput?.stopRecording()
    }

    // MARK: - Incident Auto-Recording

    func startIncidentRecording(type: String, facilityId: UUID? = nil, residentId: UUID?) {
        guard !isAutoRecordingIncident else { return }
        guard captureSession != nil else {
            errorMessage = "Incident capture unavailable because the camera session is not ready"
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "incident_\(type)_\(formatter.string(from: Date())).mov"
        let url = incidentsDir.appendingPathComponent(filename)
        let locationSnapshot = IncidentLocationSnapshot(weatherSnapshot: LocationWeatherService.shared.snapshot)
        let snapshotURL = saveIncidentSnapshot(type: type, timestamp: Date())
        let syncStatus: IncidentSyncStatus = facilityId == nil ? .localOnly : .pendingUpload
        activeIncidentContext = ActiveIncidentContext(
            type: type,
            facilityId: facilityId,
            residentId: residentId,
            duration: 30,
            snapshotURL: snapshotURL,
            locationSnapshot: locationSnapshot,
            syncStatus: syncStatus
        )

        guard let writer = try? AVAssetWriter(url: url, fileType: .mov) else {
            errorMessage = "Failed to create incident writer"
            activeIncidentContext = nil
            return
        }
        writer.shouldOptimizeForNetworkUse = true

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 3_500_000,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(writerInput) else {
            errorMessage = "Cannot add video input to writer"
            return
        }
        writer.add(writerInput)
        writer.startWriting()

        incidentAssetWriter = writer
        incidentWriterInput = writerInput
        incidentStartTime = nil
        isAutoRecordingIncident = true

        if let preBuffer = circularBuffer {
            for frame in preBuffer.frames {
                writeIncidentFrame(frame)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopIncidentRecording(type: type, facilityId: facilityId, residentId: residentId)
        }
    }

    func stopIncidentRecording(type: String, facilityId: UUID? = nil, residentId: UUID?) {
        guard isAutoRecordingIncident else { return }
        isAutoRecordingIncident = false

        guard let writer = incidentAssetWriter else { return }
        incidentWriterInput?.markAsFinished()
        let url = writer.outputURL
        let context = activeIncidentContext ?? ActiveIncidentContext(
            type: type,
            facilityId: facilityId,
            residentId: residentId,
            duration: 30,
            snapshotURL: nil,
            locationSnapshot: IncidentLocationSnapshot(weatherSnapshot: LocationWeatherService.shared.snapshot),
            syncStatus: facilityId == nil ? .localOnly : .pendingUpload
        )

        writer.finishWriting { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let recording = IncidentRecording(
                    id: UUID(),
                    type: context.type,
                    timestamp: Date(),
                    fileURL: url,
                    residentId: context.residentId,
                    duration: context.duration,
                    hasPreIncidentFootage: true,
                    facilityId: context.facilityId,
                    snapshotURL: context.snapshotURL,
                    locationSnapshot: context.locationSnapshot,
                    syncStatus: context.syncStatus
                )
                self.incidentRecordings.append(recording)
                self.persistIncidentRecordings()
                self.lastRecordingURL = url
                Task {
                    await self.processIncidentRecording(recording)
                }
            }
        }

        incidentAssetWriter = nil
        incidentWriterInput = nil
        incidentStartTime = nil
        activeIncidentContext = nil
    }

    private func writeIncidentFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let writerInput = incidentWriterInput,
              writerInput.isReadyForMoreMediaData,
              let writer = incidentAssetWriter,
              writer.status == .writing else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if incidentStartTime == nil {
            incidentStartTime = timestamp
            writer.startSession(atSourceTime: timestamp)
        }
        writerInput.append(sampleBuffer)
    }

    // MARK: - Save to Photos

    func saveToPhotoLibrary(url: URL) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            return true
        } catch {
            errorMessage = error.userFacingMessage(fallback: "We couldn't save this video to Photos right now.")
            return false
        }
    }

    // MARK: - Audio Recording (standalone)

    func startAudioRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "audio_\(formatter.string(from: Date())).m4a"
        let url = documentsDir.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()
        audioRecorder = recorder
        isAudioRecording = true

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self, weak recorder] _ in
            guard let recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let normalized = max(0, min(1, (power + 60) / 60))
            Task { @MainActor [weak self] in
                self?.currentAudioLevel = Float(normalized)
            }
        }
    }

    func stopAudioRecording() -> URL? {
        levelTimer?.invalidate()
        levelTimer = nil
        guard let recorder = audioRecorder else { return nil }
        recorder.stop()
        let url = recorder.url
        audioRecorder = nil
        isAudioRecording = false
        currentAudioLevel = 0
        lastRecordingURL = url
        return url
    }

    // MARK: - Audio Engine (real-time tap)

    func startAudioEngine(bufferHandler: @escaping (AVAudioPCMBuffer) -> Void) throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            bufferHandler(buffer)
        }

        try engine.start()
        audioEngine = engine
    }

    func stopAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    // MARK: - Incident Persistence

    private func persistIncidentRecordings() {
        guard let data = try? JSONEncoder().encode(incidentRecordings) else { return }
        UserDefaults.standard.set(data, forKey: "wcs.agedcare.incidentRecordings")
        backupStore.saveIncidentRecordings(incidentRecordings)
    }

    private func loadIncidentRecordings() {
        let stored: [IncidentRecording]?
        if let data = UserDefaults.standard.data(forKey: "wcs.agedcare.incidentRecordings"),
           let decoded = try? JSONDecoder().decode([IncidentRecording].self, from: data) {
            stored = decoded
        } else {
            stored = backupStore.loadIncidentRecordings()
        }
        guard let stored else { return }
        incidentRecordings = stored.filter {
            FileManager.default.fileExists(atPath: $0.fileURL.path) || $0.backendMediaURL != nil
        }
    }

    func deleteIncidentRecording(_ recording: IncidentRecording) {
        try? FileManager.default.removeItem(at: recording.fileURL)
        if let snapshotURL = recording.snapshotURL {
            try? FileManager.default.removeItem(at: snapshotURL)
        }
        incidentRecordings.removeAll { $0.id == recording.id }
        persistIncidentRecordings()
    }

    // MARK: - Cleanup

    func tearDown() {
        stopCaptureSession()
        stopAudioEngine()
        _ = stopAudioRecording()
        stopVideoRecording()
        if isAutoRecordingIncident {
            stopIncidentRecording(type: "manual_stop", residentId: nil)
        }
        captureSession = nil
        isCapturePipelineReady = false
    }

    private func saveIncidentSnapshot(type: String, timestamp: Date) -> URL? {
        guard let image = captureIncidentSnapshot(),
              let data = image.jpegData(compressionQuality: 0.75) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "incident_\(type)_\(formatter.string(from: timestamp)).jpg"
        let url = incidentsDir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = error.userFacingMessage(fallback: "We couldn't save the incident preview image.")
            return nil
        }
    }

    private func processIncidentRecording(_ recording: IncidentRecording) async {
        var updatedRecording = recording
        guard let facilityId = recording.facilityId else {
            updateIncidentRecording(updatedRecording)
            return
        }

        updatedRecording.syncStatus = .pendingUpload
        updatedRecording.syncError = nil
        updateIncidentRecording(updatedRecording)

        if let analysis = await AIMonitoringService.shared.analyzeVideoFile(
            at: recording.fileURL,
            facilityId: facilityId.uuidString,
            residentId: recording.residentId?.uuidString,
            incidentType: recording.type
        ) {
            updatedRecording.syncStatus = .synced
            updatedRecording.backendAnalysisID = analysis.id
            updatedRecording.backendSummary = analysis.summary ?? analysis.insights.first
            updatedRecording.backendMediaURL = URL(string: analysis.media_url)
        } else {
            updatedRecording.syncError = AIMonitoringService.shared.errorMessage
        }

        updatedRecording.cloudKitRecordName = await syncIncidentToCloudKit(updatedRecording) ?? updatedRecording.cloudKitRecordName

        let syncRequest = IncidentMediaSyncRequest(
            p_incident_id: updatedRecording.id,
            p_facility_id: facilityId,
            p_resident_id: updatedRecording.residentId,
            p_incident_type: updatedRecording.type,
            p_recorded_at: updatedRecording.timestamp,
            p_duration_seconds: updatedRecording.duration,
            p_local_filename: updatedRecording.fileURL.lastPathComponent,
            p_snapshot_filename: updatedRecording.snapshotURL?.lastPathComponent,
            p_external_media_url: updatedRecording.backendMediaURL?.absoluteString,
            p_analysis_id: updatedRecording.backendAnalysisID,
            p_summary: updatedRecording.backendSummary,
            p_cloudkit_record_name: updatedRecording.cloudKitRecordName,
            p_sync_status: (updatedRecording.backendMediaURL == nil ? IncidentSyncStatus.pendingUpload : IncidentSyncStatus.synced).rawValue,
            p_metadata: makeIncidentMetadata(for: updatedRecording)
        )

        do {
            let response: IncidentMediaSyncResponse = try await incidentMediaClient.rpc("upsert_incident_media", payload: syncRequest)
            updatedRecording.supabaseIncidentID = UUID(uuidString: response.incidentID)
            if updatedRecording.backendMediaURL == nil, let remoteURL = response.externalMediaURL {
                updatedRecording.backendMediaURL = URL(string: remoteURL)
            }
            if updatedRecording.cloudKitRecordName == nil {
                updatedRecording.cloudKitRecordName = response.cloudKitRecordName
            }
            updatedRecording.lastSyncedAt = response.syncedAt ?? Date()
            updatedRecording.syncStatus = .synced
            updatedRecording.syncError = nil
        } catch {
            updatedRecording.syncStatus = .failed
            updatedRecording.syncError = error.userFacingMessage(
                fallback: "Incident sync is temporarily unavailable. The video remains available on this device."
            )
        }
        updateIncidentRecording(updatedRecording)
    }

    private func updateIncidentRecording(_ recording: IncidentRecording) {
        guard let index = incidentRecordings.firstIndex(where: { $0.id == recording.id }) else { return }
        incidentRecordings[index] = recording
        persistIncidentRecordings()
    }

    private func makeIncidentMetadata(for recording: IncidentRecording) -> [String: AnyCodable] {
        var metadata: [String: AnyCodable] = [
            "has_pre_incident_footage": AnyCodable(recording.hasPreIncidentFootage),
            "local_file_available": AnyCodable(FileManager.default.fileExists(atPath: recording.fileURL.path)),
            "sync_status": AnyCodable(recording.resolvedSyncStatus.rawValue),
        ]
        if let location = recording.locationSnapshot {
            metadata["location_name"] = AnyCodable(location.locationName)
            metadata["movement_summary"] = AnyCodable(location.movementSummary)
            metadata["latitude"] = AnyCodable(location.latitude as Any)
            metadata["longitude"] = AnyCodable(location.longitude as Any)
            metadata["room_temperature_celsius"] = AnyCodable(location.roomTemperatureCelsius as Any)
            metadata["room_temperature_source"] = AnyCodable(location.roomTemperatureSource as Any)
        }
        if let snapshotFilename = recording.snapshotURL?.lastPathComponent {
            metadata["snapshot_filename"] = AnyCodable(snapshotFilename)
        }
        return metadata
    }

    private func retryPendingIncidentSyncs() async {
        let pending = incidentRecordings.filter {
            $0.facilityId != nil
                && $0.resolvedSyncStatus != .synced
                && FileManager.default.fileExists(atPath: $0.fileURL.path)
        }
        for recording in pending {
            await processIncidentRecording(recording)
        }
    }

    private func syncIncidentToCloudKit(_ recording: IncidentRecording) async -> String? {
        #if canImport(CloudKit)
        do {
            return try await CloudKitService.shared.saveIncidentRecording(recording)
        } catch {
            return recording.cloudKitRecordName
        }
        #else
        return nil
        #endif
    }
}

// MARK: - Incident Recording Model

struct IncidentRecording: Identifiable, Codable {
    let id: UUID
    let type: String
    let timestamp: Date
    let fileURL: URL
    let residentId: UUID?
    let duration: TimeInterval
    let hasPreIncidentFootage: Bool
    let facilityId: UUID?
    let snapshotURL: URL?
    let locationSnapshot: IncidentLocationSnapshot?
    var syncStatus: IncidentSyncStatus?
    var syncError: String?
    var backendAnalysisID: String?
    var backendSummary: String?
    var backendMediaURL: URL?
    var cloudKitRecordName: String?
    var supabaseIncidentID: UUID?
    var lastSyncedAt: Date?

    init(
        id: UUID,
        type: String,
        timestamp: Date,
        fileURL: URL,
        residentId: UUID?,
        duration: TimeInterval,
        hasPreIncidentFootage: Bool,
        facilityId: UUID?,
        snapshotURL: URL?,
        locationSnapshot: IncidentLocationSnapshot?,
        syncStatus: IncidentSyncStatus? = nil,
        syncError: String? = nil,
        backendAnalysisID: String? = nil,
        backendSummary: String? = nil,
        backendMediaURL: URL? = nil,
        cloudKitRecordName: String? = nil,
        supabaseIncidentID: UUID? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.fileURL = fileURL
        self.residentId = residentId
        self.duration = duration
        self.hasPreIncidentFootage = hasPreIncidentFootage
        self.facilityId = facilityId
        self.snapshotURL = snapshotURL
        self.locationSnapshot = locationSnapshot
        self.syncStatus = syncStatus
        self.syncError = syncError
        self.backendAnalysisID = backendAnalysisID
        self.backendSummary = backendSummary
        self.backendMediaURL = backendMediaURL
        self.cloudKitRecordName = cloudKitRecordName
        self.supabaseIncidentID = supabaseIncidentID
        self.lastSyncedAt = lastSyncedAt
    }

    var resolvedSyncStatus: IncidentSyncStatus {
        syncStatus ?? .localOnly
    }

    var preferredPlaybackURL: URL {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return backendMediaURL ?? fileURL
    }

    var storageRouteSummary: String? {
        var parts = [String]()
        if supabaseIncidentID != nil {
            parts.append("Care database synced")
        }
        if cloudKitRecordName != nil {
            parts.append("iCloud backup ready")
        }
        if backendMediaURL != nil {
            parts.append("Secure video link ready")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

private struct ActiveIncidentContext {
    let type: String
    let facilityId: UUID?
    let residentId: UUID?
    let duration: TimeInterval
    let snapshotURL: URL?
    let locationSnapshot: IncidentLocationSnapshot?
    let syncStatus: IncidentSyncStatus
}

// MARK: - Circular Frame Buffer (pre-incident recording)

final class CircularFrameBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: [CMSampleBuffer] = []
    private let maxDuration: TimeInterval

    var frames: [CMSampleBuffer] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    var latestFrame: CMSampleBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return buffer.last
    }

    init(maxDuration: TimeInterval) {
        self.maxDuration = maxDuration
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(sampleBuffer)
        trimToMaxDuration()
    }

    private func trimToMaxDuration() {
        guard let first = buffer.first, let last = buffer.last else { return }
        let firstTime = CMSampleBufferGetPresentationTimeStamp(first).seconds
        let lastTime = CMSampleBufferGetPresentationTimeStamp(last).seconds
        while lastTime - firstTime > maxDuration, buffer.count > 1 {
            buffer.removeFirst()
            guard let newFirst = buffer.first else { break }
            let newFirstTime = CMSampleBufferGetPresentationTimeStamp(newFirst).seconds
            if lastTime - newFirstTime <= maxDuration { break }
        }
    }
}

// MARK: - Video Data Delegate (frame-by-frame output)

final class VideoDataDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    static let shared = VideoDataDelegate()
    var onFrame: ((CMSampleBuffer) -> Void)?

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}

// MARK: - Photo Capture Delegate

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}

// MARK: - Video Recording Delegate

private final class VideoCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    let completion: (URL?, Error?) -> Void

    init(completion: @escaping (URL?, Error?) -> Void) {
        self.completion = completion
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        completion(error == nil ? outputFileURL : nil, error)
    }
}
