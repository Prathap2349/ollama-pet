import Foundation
import AVFoundation
import Vision
import AppKit
import Combine
import SwiftUI

// MARK: - Presence State & Models

public enum PresenceStatus: String {
    case idle = "Camera Off"
    case searching = "Scanning..."
    case ownerPresent = "Owner Verified 👤"
    case personDetectedNoOwner = "Person (Owner Not Set) 👤"
    case uncertain = "Checking Face 🔍"
    case noFace = "Face Obscured"
    case unknownDetected = "Unknown Subject 👀"
    case multipleDetected = "Multiple People 👥"
    case away = "No Person Detected 💤"
    case cameraUnavailable = "Camera Unavailable"

    public var isPositive: Bool {
        return self == .ownerPresent
    }

    public var displayIndicator: String {
        switch self {
        case .searching: return "● Scanning"
        case .uncertain: return "🟡 Checking Face"
        case .ownerPresent: return "🟢 Owner Verified"
        case .unknownDetected: return "🔴 Unknown"
        case .multipleDetected: return "👥 Multiple People"
        case .away: return "💤 No Person Detected"
        case .noFace: return "⚪ Face Obscured"
        case .personDetectedNoOwner: return "👤 Person Detected"
        case .cameraUnavailable: return "⚠️ Camera Unavailable"
        case .idle: return "○ Camera Off"
        }
    }
}

public struct TrackedSubject: Identifiable {
    public let id: UUID
    public var rect: CGRect // Normalized (0...1) in Vision coordinates (origin bottom-left)
    public var firstSeen: Date
    public var lastSeen: Date
    public var isOwner: Bool
    public var isUncertain: Bool
    public var consecutiveOwnerMatches: Int
    public var lastRecognitionTime: Date?
    public var hasCapturedSnapshot: Bool
    public var missedFramesCount: Int

    public var dwellDuration: TimeInterval {
        return lastSeen.timeIntervalSince(firstSeen)
    }

    public var recognitionBadge: String {
        if isOwner {
            return "🟢 Owner Verified"
        } else if consecutiveOwnerMatches > 0 || isUncertain {
            return "🟡 Checking Face"
        } else {
            return "🔴 Unknown"
        }
    }

    public var statusDescription: String {
        if isOwner {
            return "Strong match · \(consecutiveOwnerMatches) confirmations"
        } else if consecutiveOwnerMatches > 0 {
            return "Possible match · \(consecutiveOwnerMatches) confirmation"
        } else if isUncertain {
            return "Checking face alignment..."
        } else {
            return "No owner match"
        }
    }

    public init(
        id: UUID = UUID(),
        rect: CGRect,
        isOwner: Bool = false,
        isUncertain: Bool = false,
        consecutiveOwnerMatches: Int = 0,
        lastRecognitionTime: Date? = nil
    ) {
        self.id = id
        self.rect = rect
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.isOwner = isOwner
        self.isUncertain = isUncertain
        self.consecutiveOwnerMatches = consecutiveOwnerMatches
        self.lastRecognitionTime = lastRecognitionTime
        self.hasCapturedSnapshot = false
        self.missedFramesCount = 0
    }
}

public enum MonitoringPerformanceMode: String, CaseIterable, Codable, Identifiable {
    case lowPower = "Low Power"
    case balanced = "Balanced"
    case responsive = "Responsive"

    public var id: String { rawValue }

    public var baseInterval: Double {
        switch self {
        case .lowPower: return 2.0
        case .balanced: return 1.0
        case .responsive: return 0.6
        }
    }

    public var activeInterval: Double {
        switch self {
        case .lowPower: return 1.8
        case .balanced: return 0.8
        case .responsive: return 0.4
        }
    }

    public var ownerRelaxedInterval: Double {
        switch self {
        case .lowPower: return 3.2
        case .balanced: return 2.2
        case .responsive: return 1.2
        }
    }
}

// MARK: - Enhanced IoU & Proximity Tracker

private final class EnhancedPresenceTracker {
    private var subjects: [TrackedSubject] = []
    private let scoreThreshold: CGFloat = 0.30
    private let maxMissedCycles = 3
    private let maxTimeWithoutUpdate: TimeInterval = 3.2

    func currentSubjects() -> [TrackedSubject] {
        return subjects
    }

    func clear() {
        subjects.removeAll()
    }

    func update(
        matchedPairs: [(human: VNHumanObservation, face: VNFaceObservation?)],
        ownerPrints: [VNFeaturePrintObservation],
        handler: VNImageRequestHandler
    ) -> ([TrackedSubject], PresenceStatus) {
        let now = Date()
        var matchedSubjectIndices = Set<Int>()
        var updatedSubjects: [TrackedSubject] = []

        for pair in matchedPairs {
            let hRect = pair.human.boundingBox
            var bestScore: CGFloat = 0.0
            var bestIdx: Int? = nil

            for (idx, subj) in subjects.enumerated() {
                if matchedSubjectIndices.contains(idx) { continue }
                let score = computeMatchScore(subj.rect, hRect)
                if score > bestScore && score >= scoreThreshold {
                    bestScore = score
                    bestIdx = idx
                }
            }

            if let matchedIdx = bestIdx {
                matchedSubjectIndices.insert(matchedIdx)
                var subj = subjects[matchedIdx]

                // Smooth exponential box update to eliminate jumping
                let smoothX = subj.rect.origin.x * 0.35 + hRect.origin.x * 0.65
                let smoothY = subj.rect.origin.y * 0.35 + hRect.origin.y * 0.65
                let smoothW = subj.rect.size.width * 0.35 + hRect.size.width * 0.65
                let smoothH = subj.rect.size.height * 0.35 + hRect.size.height * 0.65
                subj.rect = CGRect(x: smoothX, y: smoothY, width: smoothW, height: smoothH)
                subj.lastSeen = now
                subj.missedFramesCount = 0

                // Face Recognition & Verification
                if let face = pair.face, !ownerPrints.isEmpty {
                    let timeSinceLastRec = subj.lastRecognitionTime != nil ? now.timeIntervalSince(subj.lastRecognitionTime!) : 999.0

                    // If verified owner and within recent cooldown (12s), keep verification to save CPU
                    if subj.isOwner && timeSinceLastRec < 12.0 {
                        // Cooldown active, keep isOwner = true
                    } else {
                        // Perform recognition
                        let facePrintReq = VNGenerateImageFeaturePrintRequest()
                        facePrintReq.regionOfInterest = face.boundingBox
                        try? handler.perform([facePrintReq])

                        if let obs = facePrintReq.results?.first as? VNFeaturePrintObservation {
                            var minDistance: Float = 1.0
                            for op in ownerPrints {
                                var d: Float = 1.0
                                if (try? obs.computeDistance(&d, to: op)) != nil {
                                    minDistance = min(minDistance, d)
                                }
                            }

                            // Strict conservative thresholds
                            if minDistance < 0.38 {
                                subj.consecutiveOwnerMatches += 1
                                if subj.consecutiveOwnerMatches >= 2 {
                                    subj.isOwner = true
                                    subj.isUncertain = false
                                } else {
                                    // 1st match: require 2 consecutive samples
                                    subj.isOwner = false
                                    subj.isUncertain = true
                                }
                            } else if minDistance <= 0.48 {
                                subj.consecutiveOwnerMatches = 0
                                subj.isOwner = false
                                subj.isUncertain = true
                            } else {
                                subj.consecutiveOwnerMatches = 0
                                subj.isOwner = false
                                subj.isUncertain = false
                            }
                            subj.lastRecognitionTime = now
                        } else {
                            if timeSinceLastRec > 8.0 {
                                subj.isOwner = false
                                subj.isUncertain = true
                            }
                        }
                    }
                } else if pair.face == nil {
                    // Face obscured
                    let timeSinceLastRec = subj.lastRecognitionTime != nil ? now.timeIntervalSince(subj.lastRecognitionTime!) : 999.0
                    if timeSinceLastRec > 6.0 {
                        subj.isOwner = false
                        subj.isUncertain = false
                    }
                } else {
                    // Owner prints empty (no owner enrolled)
                    subj.isOwner = false
                    subj.isUncertain = false
                }

                updatedSubjects.append(subj)
            } else {
                // New subject entering frame — NEVER inherits previous owner status!
                var newSubj = TrackedSubject(
                    rect: hRect,
                    isOwner: false,
                    isUncertain: false,
                    consecutiveOwnerMatches: 0
                )
                newSubj.lastSeen = now

                if let face = pair.face, !ownerPrints.isEmpty {
                    let facePrintReq = VNGenerateImageFeaturePrintRequest()
                    facePrintReq.regionOfInterest = face.boundingBox
                    try? handler.perform([facePrintReq])

                    if let obs = facePrintReq.results?.first as? VNFeaturePrintObservation {
                        var minDistance: Float = 1.0
                        for op in ownerPrints {
                            var d: Float = 1.0
                            if (try? obs.computeDistance(&d, to: op)) != nil {
                                minDistance = min(minDistance, d)
                            }
                        }

                        if minDistance < 0.38 {
                            newSubj.consecutiveOwnerMatches = 1 // Sample 1 of 2 -> NOT owner yet!
                            newSubj.isOwner = false
                            newSubj.isUncertain = true
                        } else if minDistance <= 0.48 {
                            newSubj.consecutiveOwnerMatches = 0
                            newSubj.isOwner = false
                            newSubj.isUncertain = true
                        } else {
                            newSubj.consecutiveOwnerMatches = 0
                            newSubj.isOwner = false
                            newSubj.isUncertain = false
                        }
                        newSubj.lastRecognitionTime = now
                    }
                }

                updatedSubjects.append(newSubj)
            }
        }

        // Retain un-matched subjects within short missed-frame tolerance
        for (idx, var subj) in subjects.enumerated() {
            if !matchedSubjectIndices.contains(idx) {
                subj.missedFramesCount += 1
                let timeSinceLast = now.timeIntervalSince(subj.lastSeen)
                if subj.missedFramesCount <= maxMissedCycles && timeSinceLast < maxTimeWithoutUpdate {
                    updatedSubjects.append(subj)
                }
            }
        }

        self.subjects = updatedSubjects

        // Determine Overall Presence Status
        let status: PresenceStatus
        if updatedSubjects.isEmpty {
            status = .away
        } else if updatedSubjects.count > 1 {
            status = .multipleDetected
        } else {
            let s = updatedSubjects[0]
            if ownerPrints.isEmpty {
                status = .personDetectedNoOwner
            } else if s.isOwner {
                status = .ownerPresent
            } else if s.isUncertain || s.consecutiveOwnerMatches > 0 {
                status = .uncertain
            } else if s.lastRecognitionTime != nil {
                status = .unknownDetected
            } else {
                status = .noFace
            }
        }

        return (subjects, status)
    }

    private func computeMatchScore(_ r1: CGRect, _ r2: CGRect) -> CGFloat {
        let iou = computeIoU(r1, r2)
        let c1 = CGPoint(x: r1.midX, y: r1.midY)
        let c2 = CGPoint(x: r2.midX, y: r2.midY)
        let dist = hypot(c1.x - c2.x, c1.y - c2.y)
        let proximityScore = max(0.0, 1.0 - (dist / 0.35))
        return (iou * 0.60) + (proximityScore * 0.40)
    }

    private func computeIoU(_ r1: CGRect, _ r2: CGRect) -> CGFloat {
        let intersection = r1.intersection(r2)
        if intersection.isNull || intersection.isEmpty { return 0.0 }
        let interArea = intersection.width * intersection.height
        let unionArea = (r1.width * r1.height) + (r2.width * r2.height) - interArea
        guard unionArea > 0 else { return 0.0 }
        return interArea / unionArea
    }
}

// MARK: - Background Video Output Coordinator

private final class PresenceCaptureCoordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrameProcessed: (([TrackedSubject], PresenceStatus) -> Void)?
    var onPreviewFrameReady: ((CGImage) -> Void)?
    var onHeartbeat: (() -> Void)?

    private let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])
    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.ollamapet.presence.sessionQueue", qos: .userInitiated)

    var intervalSeconds: Double = 1.0
    var isLivePreviewRequested: Bool = false

    private var isAnalyzing: Bool = false
    private var lastAnalysisTimestamp: TimeInterval = 0
    private var lastPreviewTimestamp: TimeInterval = 0
    private let minPreviewInterval: TimeInterval = 0.12 // Controlled 8 FPS preview cap

    private var ownerFeaturePrints: [VNFeaturePrintObservation] = []
    private weak var trackerRef: EnhancedPresenceTracker?

    func setOwnerFeaturePrints(_ prints: [VNFeaturePrintObservation]) {
        self.ownerFeaturePrints = prints
    }

    func setTrackerReference(_ tracker: EnhancedPresenceTracker) {
        self.trackerRef = tracker
    }

    func start(interval: Double, completion: @escaping (Bool) -> Void) {
        self.intervalSeconds = interval

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .vga640x480

            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                completion(false)
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]

            // Video queue priority set to .userInitiated (NOT .userInteractive)
            let outputQueue = DispatchQueue(label: "com.ollamapet.presence.videoQueue", qos: .userInitiated)
            output.setSampleBufferDelegate(self, queue: outputQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()
            session.startRunning()

            self.captureSession = session
            completion(true)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.isAnalyzing = false
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Record camera alive signal for watchdog
        onHeartbeat?()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = Date().timeIntervalSince1970

        // 1. Controlled Preview Pipeline (Only when expanded/requested, capped at ~8 FPS)
        if isLivePreviewRequested && (now - lastPreviewTimestamp >= minPreviewInterval) {
            lastPreviewTimestamp = now
            if let cg = renderCGImage(from: pixelBuffer) {
                onPreviewFrameReady?(cg)
            }
        }

        // 2. Controlled Vision Detection Pipeline (Gated by performance sampling interval)
        guard now - lastAnalysisTimestamp >= intervalSeconds else { return }
        guard !isAnalyzing else { return } // Prevent queued Vision requests from piling up
        isAnalyzing = true
        lastAnalysisTimestamp = now

        processVisionFrame(pixelBuffer: pixelBuffer)
    }

    private func processVisionFrame(pixelBuffer: CVPixelBuffer) {
        defer { isAnalyzing = false }

        // Step 1: Human Detection First (Lightweight filter)
        let humanRequest = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([humanRequest])
            let humanResults = humanRequest.results ?? []

            if humanResults.isEmpty {
                // Zero humans detected -> Publish away state immediately; skip faces and feature prints!
                self.trackerRef?.clear()
                self.onFrameProcessed?([], .away)
                return
            }

            // Step 2: Humans are present -> Detect Faces for Identification
            let faceRequest = VNDetectFaceRectanglesRequest()
            try handler.perform([faceRequest])
            let faceResults = faceRequest.results ?? []

            // Step 3: Strict 1-to-1 Bipartite Face Matching
            let matchedPairs = matchFacesToHumans(humans: humanResults, faces: faceResults)

            // Step 4: Authoritative Tracker Update with Strict Identity & Multi-Sample Verification
            if let tracker = self.trackerRef {
                let (subjects, status) = tracker.update(
                    matchedPairs: matchedPairs,
                    ownerPrints: self.ownerFeaturePrints,
                    handler: handler
                )
                self.onFrameProcessed?(subjects, status)
            }
        } catch {
            // Ignore temporary Vision exceptions safely
        }
    }

    /// 1-to-1 Bipartite spatial matching: ensures a face cannot be assigned to multiple humans
    private func matchFacesToHumans(
        humans: [VNHumanObservation],
        faces: [VNFaceObservation]
    ) -> [(human: VNHumanObservation, face: VNFaceObservation?)] {
        var availableFaceIndices = Set(0..<faces.count)
        var results: [(human: VNHumanObservation, face: VNFaceObservation?)] = []

        for human in humans {
            let hRect = human.boundingBox
            // Upper torso / head anchor in Vision coordinates (origin bottom-left, y=1 is top)
            let headAnchor = CGPoint(x: hRect.midX, y: hRect.maxY - (hRect.height * 0.15))

            var bestFaceIdx: Int? = nil
            var bestDistance: CGFloat = .infinity

            for faceIdx in availableFaceIndices {
                let faceRect = faces[faceIdx].boundingBox
                let faceCenter = CGPoint(x: faceRect.midX, y: faceRect.midY)

                // Face must be vertically in the upper half of human rectangle or slightly above
                let isVerticallyAligned = faceCenter.y >= (hRect.midY - 0.12)
                // Face must be horizontally within human bounds (+ generous margin for side turns)
                let isHorizontallyAligned = faceCenter.x >= (hRect.minX - 0.15) && faceCenter.x <= (hRect.maxX + 0.15)

                if isVerticallyAligned && isHorizontallyAligned {
                    let d = hypot(faceCenter.x - headAnchor.x, faceCenter.y - headAnchor.y)
                    if d < bestDistance {
                        bestDistance = d
                        bestFaceIdx = faceIdx
                    }
                }
            }

            if let matchedIdx = bestFaceIdx {
                availableFaceIndices.remove(matchedIdx)
                results.append((human: human, face: faces[matchedIdx]))
            } else {
                results.append((human: human, face: nil))
            }
        }

        return results
    }

    private func renderCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return sharedCIContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

// MARK: - Main Presence Monitor

@MainActor
public final class PresenceMonitor: ObservableObject {
    public static let shared = PresenceMonitor()

    @Published public var isRunning: Bool = false
    @Published public var presenceStatus: PresenceStatus = .idle
    @Published public var trackedSubjects: [TrackedSubject] = []
    @Published public var latestPreviewImage: NSImage? = nil
    @Published public var isOwnerEnrolled: Bool = false
    @Published public var enrolledSamplesCount: Int = 0
    @Published public var snapshotCount: Int = 0
    @Published public var performanceMode: MonitoringPerformanceMode = .balanced

    /// Whether any UI component (expanded monitor or settings) is actively watching the camera view
    @Published public var isLivePreviewRequested: Bool = false {
        didSet {
            coordinator.isLivePreviewRequested = isLivePreviewRequested
            if !isLivePreviewRequested {
                latestPreviewImage = nil // Free preview image memory immediately
            }
        }
    }

    private let tracker = EnhancedPresenceTracker()
    private let coordinator = PresenceCaptureCoordinator()
    private var snapshotCooldownUntil: Date = Date.distantPast
    private var ownerFeaturePrints: [VNFeaturePrintObservation] = []
    private var previousPresenceStatus: PresenceStatus = .idle

    // Internal Watchdog for Self-Healing (Zero Terminal / killall commands)
    private var watchdogTimer: Timer?
    private var lastCameraFrameTime: Date = Date()
    private var lastSuccessfulAnalysisTime: Date = Date()
    private var recoveryAttemptsInWindow: Int = 0
    private var lastRecoveryWindowStart: Date = Date()
    private let recoveryWindowDuration: TimeInterval = 40.0
    private let maxRecoveriesPerWindow: Int = 2
    private var isRecovering: Bool = false

    private let fileManager = FileManager.default
    private var appSupportURL: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("OllamaPet", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var snapshotsURL: URL {
        let dir = appSupportURL.appendingPathComponent("Snapshots", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var ownerURL: URL {
        let dir = appSupportURL.appendingPathComponent("Owner", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        if let modeStr = DataManager.shared.savedData.monitoringPerformanceMode,
           let mode = MonitoringPerformanceMode(rawValue: modeStr) {
            self.performanceMode = mode
        }

        coordinator.setTrackerReference(tracker)
        loadOwnerProfile()
        updateSnapshotCount()

        // 1. Detection Results Callback (Runs on controlled analysis schedule)
        coordinator.onFrameProcessed = { [weak self] subjects, status in
            Task { @MainActor [weak self] in
                self?.handleProcessedFrame(subjects: subjects, status: status)
            }
        }

        // 2. Throttled Preview Callback (Runs at ~8 FPS only when requested)
        coordinator.onPreviewFrameReady = { [weak self] cgImage in
            Task { @MainActor [weak self] in
                guard let self = self, self.isLivePreviewRequested else { return }
                self.latestPreviewImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        // 3. Heartbeat for Watchdog
        coordinator.onHeartbeat = { [weak self] in
            Task { @MainActor [weak self] in
                self?.lastCameraFrameTime = Date()
            }
        }
    }

    public func setPerformanceMode(_ mode: MonitoringPerformanceMode) {
        self.performanceMode = mode
        DataManager.shared.savedData.monitoringPerformanceMode = mode.rawValue
        DataManager.shared.saveData()
        updateSamplingFrequency()
    }

    private func updateSamplingFrequency() {
        let interval: Double
        if presenceStatus == .ownerPresent {
            interval = performanceMode.ownerRelaxedInterval
        } else if presenceStatus == .away || presenceStatus == .idle {
            interval = performanceMode.baseInterval
        } else {
            interval = performanceMode.activeInterval
        }
        coordinator.intervalSeconds = interval
    }

    // MARK: - Session Control

    public func start() {
        guard !isRunning else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndStartCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupAndStartCapture()
                    } else {
                        self?.presenceStatus = .cameraUnavailable
                    }
                }
            }
        default:
            presenceStatus = .cameraUnavailable
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        stopWatchdog()
        presenceStatus = .idle
        trackedSubjects = []
        latestPreviewImage = nil
        tracker.clear()
        coordinator.stop()
    }

    private func setupAndStartCapture() {
        updateSamplingFrequency()
        lastCameraFrameTime = Date()
        lastSuccessfulAnalysisTime = Date()

        coordinator.start(interval: coordinator.intervalSeconds) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    self.isRunning = true
                    self.presenceStatus = .searching
                    self.startWatchdog()
                } else {
                    self.presenceStatus = .cameraUnavailable
                }
            }
        }
    }

    // MARK: - Internal Self-Healing Watchdog

    private func startWatchdog() {
        stopWatchdog()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.inspectPipelineHealth()
            }
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func inspectPipelineHealth() {
        guard isRunning, !isRecovering else { return }
        let now = Date()

        // Check if camera frames or analysis have stalled (> 9.0s)
        let frameLag = now.timeIntervalSince(lastCameraFrameTime)
        let analysisLag = now.timeIntervalSince(lastSuccessfulAnalysisTime)

        if frameLag > 8.0 || analysisLag > 9.5 {
            // Pipeline appears stuck
            handleWatchdogStall()
        }
    }

    private func handleWatchdogStall() {
        let now = Date()

        // Reset recovery window if 40s have elapsed
        if now.timeIntervalSince(lastRecoveryWindowStart) > recoveryWindowDuration {
            recoveryAttemptsInWindow = 0
            lastRecoveryWindowStart = now
        }

        if recoveryAttemptsInWindow < maxRecoveriesPerWindow {
            recoveryAttemptsInWindow += 1
            isRecovering = true

            // Gracefully reset camera session without terminal commands
            coordinator.stop()
            tracker.clear()
            latestPreviewImage = nil
            trackedSubjects = []

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self, self.isRunning else { return }
                self.coordinator.start(interval: self.coordinator.intervalSeconds) { [weak self] success in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isRecovering = false
                        if success {
                            self.lastCameraFrameTime = Date()
                            self.lastSuccessfulAnalysisTime = Date()
                            self.presenceStatus = .searching
                        } else {
                            self.presenceStatus = .cameraUnavailable
                        }
                    }
                }
            }
        } else {
            // Repeated recovery failures in short window -> safely pause monitoring
            stop()
            presenceStatus = .cameraUnavailable
            PetState.shared.showBubble("Camera paused: pipeline could not recover", duration: 3.5)
        }
    }

    // MARK: - Frame & Subject Processing

    private func handleProcessedFrame(
        subjects: [TrackedSubject],
        status: PresenceStatus
    ) {
        guard isRunning else { return }
        lastSuccessfulAnalysisTime = Date()

        self.trackedSubjects = subjects
        self.presenceStatus = status

        // Connect presence status transitions to Pet emotions & reactions
        if status != previousPresenceStatus {
            let previous = previousPresenceStatus
            previousPresenceStatus = status

            let spokenAlerts = DataManager.shared.savedData.presenceSpokenAlertsEnabled ?? false

            if status == .ownerPresent {
                PetState.shared.setTemporaryMood(.happy, duration: 5.0)
                PetState.shared.triggerCelebration(color: Color.green, duration: 3.0)
                PetState.shared.showBubble("Welcome back! 🐾", duration: 3.5)
                if spokenAlerts {
                    VoiceAssistant.shared.speak(text: "Welcome back.")
                }
            } else if status == .unknownDetected && previous != .uncertain {
                PetState.shared.setTemporaryMood(.concerned, duration: 5.0)
                PetState.shared.triggerCelebration(color: Color.orange, duration: 2.0)
                PetState.shared.showBubble("Hmm... I don't recognize this person. 👀", duration: 3.5)
                if spokenAlerts {
                    VoiceAssistant.shared.speak(text: "Unfamiliar person detected.")
                }
            } else if status == .multipleDetected {
                PetState.shared.setTemporaryMood(.surprised, duration: 4.0)
                PetState.shared.showBubble("I see multiple people. 👥", duration: 3.0)
            }
        }

        // Dynamically tune sampling frequency based on presence state
        updateSamplingFrequency()

        // Event-Based Unknown Person Snapshots (OFF BY DEFAULT)
        let snapshotsEnabled = DataManager.shared.savedData.presenceUnknownAlertEnabled ?? false
        let dwellAlertEnabled = DataManager.shared.savedData.presenceDwellAlertEnabled ?? true
        let now = Date()

        if snapshotsEnabled && now >= snapshotCooldownUntil {
            for i in 0..<trackedSubjects.count {
                var subj = trackedSubjects[i]
                if !subj.isOwner && !subj.isUncertain && subj.dwellDuration >= 5.0 && !subj.hasCapturedSnapshot {
                    subj.hasCapturedSnapshot = true
                    trackedSubjects[i] = subj
                    snapshotCooldownUntil = now.addingTimeInterval(60.0) // 1 minute cooldown per unknown encounter

                    if let preview = latestPreviewImage,
                       let cg = preview.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        saveSnapshotLocally(cgImage: cg)
                    }
                    if dwellAlertEnabled {
                        PetState.shared.showBubble("Unfamiliar person detected near Mac! 👀", duration: 3.5)
                        SoundEffect.alert.play()
                    }
                    break
                }
            }
        }
    }

    // MARK: - Snapshot Management (Max 20, FIFO, 100% Local)

    private func saveSnapshotLocally(cgImage: CGImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "snapshot_\(formatter.string(from: Date())).jpg"
        let fileURL = snapshotsURL.appendingPathComponent(filename)

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .jpeg, properties: [:]) else { return }

        try? data.write(to: fileURL)
        pruneOldSnapshots()
        updateSnapshotCount()
    }

    private func pruneOldSnapshots() {
        guard let files = try? fileManager.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return
        }

        if files.count > 20 {
            let sorted = files.sorted {
                let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }
            let toRemove = sorted.prefix(files.count - 20)
            for f in toRemove {
                try? fileManager.removeItem(at: f)
            }
        }
    }

    public func deleteSnapshot(at url: URL) {
        try? fileManager.removeItem(at: url)
        updateSnapshotCount()
    }

    public func clearAllSnapshots() {
        guard let files = try? fileManager.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: nil) else { return }
        for f in files {
            try? fileManager.removeItem(at: f)
        }
        updateSnapshotCount()
    }

    public func getSnapshotURLs() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return []
        }
        return files.sorted {
            let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }
    }

    private func updateSnapshotCount() {
        let urls = getSnapshotURLs()
        self.snapshotCount = urls.count
    }

    // MARK: - Guided Owner Enrollment Flow (Multi-Sample Support)

    public func checkEnrollmentEligibility() -> (eligible: Bool, message: String, faceRect: CGRect?) {
        guard let image = latestPreviewImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (false, "Camera preview inactive. Start camera to enroll.", nil)
        }

        let faceReq = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([faceReq])

        guard let results = faceReq.results, !results.isEmpty else {
            return (false, "No face detected. Please look directly at the camera.", nil)
        }

        if results.count > 1 {
            return (false, "Multiple faces detected. Please ensure only you are in frame.", nil)
        }

        let face = results[0]
        let bbox = face.boundingBox

        // Verify face is reasonably centered and adequately sized
        let centerX = bbox.midX
        let centerY = bbox.midY

        if centerX < 0.25 || centerX > 0.75 || centerY < 0.25 || centerY > 0.75 {
            return (false, "Face not centered. Move closer to the center of the frame.", bbox)
        }

        if bbox.width < 0.15 || bbox.height < 0.15 {
            return (false, "Face too far. Move a little closer to the camera.", bbox)
        }

        return (true, "Good lighting & position! Ready to enroll.", bbox)
    }

    public func enrollCurrentFaceAsOwner(sampleIndex: Int? = nil) -> (success: Bool, message: String) {
        guard let image = latestPreviewImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (false, "No camera frame available. Please start monitor first.")
        }

        let faceReq = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([faceReq])

        guard let face = faceReq.results?.first else {
            return (false, "No face detected in frame. Please face the camera.")
        }

        let featurePrintReq = VNGenerateImageFeaturePrintRequest()
        featurePrintReq.regionOfInterest = face.boundingBox
        try? handler.perform([featurePrintReq])

        if let obs = featurePrintReq.results?.first as? VNFeaturePrintObservation {
            var currentPrints = self.ownerFeaturePrints
            if currentPrints.count >= 3 {
                currentPrints = [obs]
            } else {
                currentPrints.append(obs)
            }
            self.ownerFeaturePrints = currentPrints

            // Archive array of [VNFeaturePrintObservation]
            let printsURL = ownerURL.appendingPathComponent("owner_prints.data")
            let data = try? NSKeyedArchiver.archivedData(withRootObject: currentPrints as NSArray, requiringSecureCoding: true)
            try? data?.write(to: printsURL)

            // Save legacy single observation for backward compatibility
            let legacyData = try? NSKeyedArchiver.archivedData(withRootObject: obs, requiringSecureCoding: true)
            let printURL = ownerURL.appendingPathComponent("owner_print.data")
            try? legacyData?.write(to: printURL)

            // Save owner photo preview for settings confirmation
            let photoURL = ownerURL.appendingPathComponent("owner.jpg")
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            if let jpg = bitmap.representation(using: .jpeg, properties: [:]) {
                try? jpg.write(to: photoURL)
            }

            self.coordinator.setOwnerFeaturePrints(currentPrints)
            self.isOwnerEnrolled = true
            self.enrolledSamplesCount = currentPrints.count

            let sampleNum = currentPrints.count
            PetState.shared.setTemporaryMood(.proud, duration: 3.0)
            PetState.shared.showBubble("Owner sample \(sampleNum)/3 enrolled! ✨", duration: 3.0)
            SoundEffect.success.play()

            let msg = sampleNum < 3
                ? "Sample \(sampleNum)/3 enrolled! Tilt slightly and click again to add more angles."
                : "Owner profile fully calibrated with 3 samples!"
            return (true, msg)
        }

        return (false, "Could not generate facial feature print. Try with better lighting.")
    }

    public func resetOwnerProfile() {
        let printsURL = ownerURL.appendingPathComponent("owner_prints.data")
        let printURL = ownerURL.appendingPathComponent("owner_print.data")
        let photoURL = ownerURL.appendingPathComponent("owner.jpg")
        try? fileManager.removeItem(at: printsURL)
        try? fileManager.removeItem(at: printURL)
        try? fileManager.removeItem(at: photoURL)
        self.ownerFeaturePrints = []
        self.coordinator.setOwnerFeaturePrints([])
        self.isOwnerEnrolled = false
        self.enrolledSamplesCount = 0
        PetState.shared.showBubble("Owner profile removed.", duration: 2.0)
    }

    public func getOwnerPhoto() -> NSImage? {
        let photoURL = ownerURL.appendingPathComponent("owner.jpg")
        return NSImage(contentsOf: photoURL)
    }

    private func loadOwnerProfile() {
        let printsURL = ownerURL.appendingPathComponent("owner_prints.data")
        let legacyPrintURL = ownerURL.appendingPathComponent("owner_print.data")

        if let data = try? Data(contentsOf: printsURL),
           let list = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, VNFeaturePrintObservation.self], from: data) as? [VNFeaturePrintObservation],
           !list.isEmpty {
            self.ownerFeaturePrints = list
            self.coordinator.setOwnerFeaturePrints(list)
            self.isOwnerEnrolled = true
            self.enrolledSamplesCount = list.count
        } else if let data = try? Data(contentsOf: legacyPrintURL),
                  let single = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data) {
            self.ownerFeaturePrints = [single]
            self.coordinator.setOwnerFeaturePrints([single])
            self.isOwnerEnrolled = true
            self.enrolledSamplesCount = 1
        } else {
            self.ownerFeaturePrints = []
            self.coordinator.setOwnerFeaturePrints([])
            self.isOwnerEnrolled = false
            self.enrolledSamplesCount = 0
        }
    }
}
