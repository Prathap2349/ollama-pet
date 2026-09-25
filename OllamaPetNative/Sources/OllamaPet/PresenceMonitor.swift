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

// MARK: - Presence Encounter Lifecycle & Alert Controller

public enum PresenceEncounterState: Equatable {
    case noPerson
    case personArrived(since: Date)
    case ownerConfirmed(since: Date)
    case unknownConfirmed(since: Date)
    case multiplePersons(since: Date)
}

@MainActor
public final class PresenceAlertController {
    public private(set) var state: PresenceEncounterState = .noPerson
    private var departureStartTime: Date? = nil
    private var lastSpokenAlertTime: Date = Date.distantPast
    
    public func update(
        subjects: [TrackedSubject],
        status: PresenceStatus,
        now: Date = Date()
    ) {
        let departureThreshold: TimeInterval = 4.0
        let verificationGracePeriod: TimeInterval = 2.8
        
        let hasPerson = !subjects.isEmpty && status != .away && status != .idle && status != .cameraUnavailable
        
        if !hasPerson {
            if departureStartTime == nil {
                departureStartTime = now
            }
            if let dep = departureStartTime, now.timeIntervalSince(dep) >= departureThreshold {
                state = .noPerson
            }
            return
        }
        
        // A person is present
        departureStartTime = nil
        
        let savedData = DataManager.shared.savedData
        let masterSpoken = savedData.presenceSpokenAlertsEnabled ?? false
        let ownerGreeting = savedData.presenceOwnerGreetingEnabled ?? true
        let unknownVoice = savedData.presenceUnknownAlertVoiceEnabled ?? true
        let cooldown = TimeInterval(savedData.presenceVoiceCooldownSeconds ?? 90)
        
        let anyOwner = subjects.contains(where: { $0.isOwner })
        let anyUncertain = subjects.contains(where: { $0.isUncertain || $0.consecutiveOwnerMatches > 0 })
        
        switch state {
        case .noPerson:
            state = .personArrived(since: now)
            if anyOwner {
                state = .ownerConfirmed(since: now)
                triggerOwnerGreeting(now: now, masterSpoken: masterSpoken, ownerGreeting: ownerGreeting, cooldown: cooldown)
            }
            
        case .personArrived(let since):
            if anyOwner {
                state = .ownerConfirmed(since: now)
                triggerOwnerGreeting(now: now, masterSpoken: masterSpoken, ownerGreeting: ownerGreeting, cooldown: cooldown)
            } else if subjects.count > 1 {
                if now.timeIntervalSince(since) >= 2.0 {
                    state = .multiplePersons(since: now)
                    PetState.shared.setTemporaryMood(.surprised, duration: 4.0)
                    PetState.shared.showBubble("I see multiple people. 👥", duration: 3.0)
                }
            } else if now.timeIntervalSince(since) >= verificationGracePeriod {
                if !anyUncertain && PresenceMonitor.shared.isOwnerEnrolled {
                    state = .unknownConfirmed(since: now)
                    triggerUnknownAlert(now: now, masterSpoken: masterSpoken, unknownVoice: unknownVoice, cooldown: cooldown)
                } else if !PresenceMonitor.shared.isOwnerEnrolled {
                    state = .unknownConfirmed(since: now)
                    PetState.shared.setTemporaryMood(.happy, duration: 4.0)
                    PetState.shared.showBubble("Hello there! 🐾", duration: 3.0)
                }
            }
            
        case .ownerConfirmed:
            // Owner remains in frame. Complete silence, no voice repetitions.
            if subjects.count > 1 && now.timeIntervalSince(lastSpokenAlertTime) > 60.0 {
                PetState.shared.setTemporaryMood(.surprised, duration: 3.0)
                PetState.shared.showBubble("Someone is behind you. 👥", duration: 3.0)
            }
            
        case .unknownConfirmed:
            // Unknown stays in frame. Do not spam.
            if anyOwner {
                state = .ownerConfirmed(since: now)
                triggerOwnerGreeting(now: now, masterSpoken: masterSpoken, ownerGreeting: ownerGreeting, cooldown: cooldown)
            }
            
        case .multiplePersons:
            if anyOwner {
                state = .ownerConfirmed(since: now)
            }
        }
    }
    
    private func triggerOwnerGreeting(now: Date, masterSpoken: Bool, ownerGreeting: Bool, cooldown: TimeInterval) {
        PetState.shared.setTemporaryMood(.happy, duration: 5.0)
        PetState.shared.triggerCelebration(color: Color.green, duration: 3.0)
        PetState.shared.showBubble("Welcome back! 🐾", duration: 3.5)
        
        if masterSpoken && ownerGreeting && (now.timeIntervalSince(lastSpokenAlertTime) >= cooldown) {
            lastSpokenAlertTime = now
            VoiceAssistant.shared.speak(text: "Welcome back.")
        }
    }
    
    private func triggerUnknownAlert(now: Date, masterSpoken: Bool, unknownVoice: Bool, cooldown: TimeInterval) {
        PetState.shared.setTemporaryMood(.concerned, duration: 5.0)
        PetState.shared.triggerCelebration(color: Color.orange, duration: 2.0)
        PetState.shared.showBubble("Hmm... I don't recognize this person. 👀", duration: 3.5)
        
        if masterSpoken && unknownVoice && (now.timeIntervalSince(lastSpokenAlertTime) >= cooldown) {
            lastSpokenAlertTime = now
            VoiceAssistant.shared.speak(text: "Unfamiliar person detected.")
        }
    }
    
    public func reset() {
        state = .noPerson
        departureStartTime = nil
    }
}

// MARK: - Guided Owner Enrollment Models

public enum OwnerSampleAngle: String, Codable, CaseIterable, Identifiable {
    case front = "front"
    case leftProfile = "left"
    case rightProfile = "right"
    
    public var id: String { rawValue }
    
    public var stepIndex: Int {
        switch self {
        case .front: return 1
        case .leftProfile: return 2
        case .rightProfile: return 3
        }
    }
    
    public var title: String {
        switch self {
        case .front: return "Front & Center"
        case .leftProfile: return "Left Angle"
        case .rightProfile: return "Right Angle"
        }
    }
    
    public var instruction: String {
        switch self {
        case .front: return "Look straight into camera with good lighting."
        case .leftProfile: return "Turn your head gently ~25° to your left."
        case .rightProfile: return "Turn your head gently ~25° to your right."
        }
    }
    
    public var icon: String {
        switch self {
        case .front: return "person.crop.circle"
        case .leftProfile: return "arrow.turn.up.left"
        case .rightProfile: return "arrow.turn.up.right"
        }
    }
    
    public func matches(yaw: Double) -> (matches: Bool, feedback: String) {
        switch self {
        case .front:
            if abs(yaw) <= 0.22 {
                return (true, "Facing forward ✓")
            } else if yaw > 0.22 {
                return (false, "Turn slightly right to center")
            } else {
                return (false, "Turn slightly left to center")
            }
        case .leftProfile:
            if yaw >= 0.16 && yaw <= 0.85 {
                return (true, "Left angle aligned ✓")
            } else if yaw < 0.16 {
                return (false, "Turn head more to your left")
            } else {
                return (false, "Turned too far left, ease back")
            }
        case .rightProfile:
            if yaw <= -0.16 && yaw >= -0.85 {
                return (true, "Right angle aligned ✓")
            } else if yaw > -0.16 {
                return (false, "Turn head more to your right")
            } else {
                return (false, "Turned too far right, ease back")
            }
        }
    }
}

public struct EnrollmentQualityReport {
    public let faceDetected: Bool
    public let multipleFaces: Bool
    public let isCentered: Bool
    public let isGoodSize: Bool
    public let isGoodLighting: Bool
    public let isGoodQuality: Bool
    public let angleMatched: Bool
    public let statusMessage: String
    public let faceRect: CGRect?
    public let yaw: Double
    public let qualityScore: Float
    public let luminance: Double
    
    public var isReadyToCapture: Bool {
        return faceDetected && !multipleFaces && isCentered && isGoodSize && isGoodLighting && isGoodQuality && angleMatched
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

    func start(interval: Double, centerStageEnabled: Bool = true, completion: @escaping (Bool) -> Void) {
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
            if #available(macOS 12.3, *) {
                AVCaptureDevice.isCenterStageEnabled = centerStageEnabled
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
    @Published public var enrolledAngles: Set<OwnerSampleAngle> = []
    @Published public var lastEnrollmentQuality: EnrollmentQualityReport? = nil
    @Published public var autoFramingEnabled: Bool = true
    @Published public var currentZoomScale: CGFloat = 1.0
    @Published public var currentPanAnchor: UnitPoint = UnitPoint(x: 0.5, y: 0.5)

    public let alertController = PresenceAlertController()

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
        if let framing = DataManager.shared.savedData.presenceAutoFramingEnabled {
            self.autoFramingEnabled = framing
        }
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
        alertController.reset()
        coordinator.stop()
    }

    private func setupAndStartCapture() {
        updateSamplingFrequency()
        lastCameraFrameTime = Date()
        lastSuccessfulAnalysisTime = Date()

        let centerStage = DataManager.shared.savedData.presenceCenterStageEnabled ?? true
        coordinator.start(interval: coordinator.intervalSeconds, centerStageEnabled: centerStage) { [weak self] success in
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
                let centerStage = DataManager.shared.savedData.presenceCenterStageEnabled ?? true
                self.coordinator.start(interval: self.coordinator.intervalSeconds, centerStageEnabled: centerStage) { [weak self] success in
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

        // Connect presence status transitions to Pet emotions & reactions via Arrival State Machine
        alertController.update(subjects: subjects, status: status, now: Date())

        // Smooth Digital Auto-Framing (Pan & Zoom on detected person)
        if autoFramingEnabled, let primary = subjects.first {
            let bbox = primary.rect
            let targetX = max(0.20, min(0.80, bbox.midX))
            let targetY = max(0.20, min(0.80, 1.0 - bbox.midY))
            let targetZoom = subjects.count > 1 ? 1.0 : min(1.80, max(1.0, 0.45 / max(0.18, bbox.width)))
            currentZoomScale = currentZoomScale * 0.78 + targetZoom * 0.22
            currentPanAnchor = UnitPoint(
                x: currentPanAnchor.x * 0.78 + targetX * 0.22,
                y: currentPanAnchor.y * 0.78 + targetY * 0.22
            )
        } else {
            currentZoomScale = currentZoomScale * 0.78 + 1.0 * 0.22
            currentPanAnchor = UnitPoint(
                x: currentPanAnchor.x * 0.78 + 0.5 * 0.22,
                y: currentPanAnchor.y * 0.78 + 0.5 * 0.22
            )
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

    // MARK: - Snapshot Export & Finder Integration

    @discardableResult
    public func exportSnapshotToDownloads(url: URL) -> Bool {
        guard let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return false
        }
        let destURL = downloadsURL.appendingPathComponent(url.lastPathComponent)
        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: url, to: destURL)
            PetState.shared.showBubble("Saved snapshot to Downloads! 📥", duration: 3.0)
            SoundEffect.success.play()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func exportAllSnapshotsToDownloads() -> Int {
        let urls = getSnapshotURLs()
        guard !urls.isEmpty else { return 0 }
        var count = 0
        for u in urls {
            if exportSnapshotToDownloads(url: u) {
                count += 1
            }
        }
        PetState.shared.showBubble("Exported \(count) snapshots to Downloads! 📥", duration: 3.5)
        return count
    }

    public func revealSnapshotInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
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

    // MARK: - Guided Owner Calibration & Quality Analysis

    private func computeFaceLuminance(cgImage: CGImage, faceRect: CGRect) -> Double {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let cropX = max(0, min(w - 1, faceRect.origin.x * w))
        let cropY = max(0, min(h - 1, (1.0 - faceRect.origin.y - faceRect.height) * h))
        let cropW = max(1, min(w - cropX, faceRect.width * w))
        let cropH = max(1, min(h - cropY, faceRect.height * h))
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        guard let cropped = cgImage.cropping(to: cropRect) else { return 0.5 }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var rawBytes = [UInt8](repeating: 0, count: 256)
        guard let ctx = CGContext(
            data: &rawBytes,
            width: 16,
            height: 16,
            bitsPerComponent: 8,
            bytesPerRow: 16,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0.5
        }
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        let total = rawBytes.reduce(0.0) { $0 + Double($1) }
        return total / (256.0 * 255.0)
    }

    private func estimateHeadYaw(face: VNFaceObservation) -> Double {
        if let yawNum = face.yaw {
            return yawNum.doubleValue
        }
        if let landmarks = face.landmarks,
           let nose = landmarks.nose?.normalizedPoints.first,
           let leftEye = landmarks.leftEye?.normalizedPoints.first,
           let rightEye = landmarks.rightEye?.normalizedPoints.first {
            let span = rightEye.x - leftEye.x
            if span > 0.02 {
                let ratio = (nose.x - leftEye.x) / span
                return Double((ratio - 0.5) * 1.6)
            }
        }
        return 0.0
    }

    public func evaluateEnrollmentFrame(for angle: OwnerSampleAngle) -> EnrollmentQualityReport {
        guard let image = latestPreviewImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return EnrollmentQualityReport(
                faceDetected: false,
                multipleFaces: false,
                isCentered: false,
                isGoodSize: false,
                isGoodLighting: false,
                isGoodQuality: false,
                angleMatched: false,
                statusMessage: "Camera preview inactive. Start camera to inspect.",
                faceRect: nil,
                yaw: 0,
                qualityScore: 0,
                luminance: 0
            )
        }

        let faceReq = VNDetectFaceRectanglesRequest()
        let qualityReq = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([faceReq, qualityReq])

        guard let results = faceReq.results, !results.isEmpty else {
            let rep = EnrollmentQualityReport(
                faceDetected: false,
                multipleFaces: false,
                isCentered: false,
                isGoodSize: false,
                isGoodLighting: false,
                isGoodQuality: false,
                angleMatched: false,
                statusMessage: "No face detected. Please face the camera.",
                faceRect: nil,
                yaw: 0,
                qualityScore: 0,
                luminance: 0
            )
            self.lastEnrollmentQuality = rep
            return rep
        }

        if results.count > 1 {
            let rep = EnrollmentQualityReport(
                faceDetected: true,
                multipleFaces: true,
                isCentered: false,
                isGoodSize: false,
                isGoodLighting: false,
                isGoodQuality: false,
                angleMatched: false,
                statusMessage: "Multiple faces detected. Ensure only you are in frame.",
                faceRect: nil,
                yaw: 0,
                qualityScore: 0,
                luminance: 0
            )
            self.lastEnrollmentQuality = rep
            return rep
        }

        let face = results[0]
        let bbox = face.boundingBox

        let isCentered = bbox.midX >= 0.28 && bbox.midX <= 0.72 && bbox.midY >= 0.25 && bbox.midY <= 0.75
        let isGoodSize = bbox.width >= 0.15 && bbox.width <= 0.72 && bbox.height >= 0.15 && bbox.height <= 0.72

        let luminance = computeFaceLuminance(cgImage: cgImage, faceRect: bbox)
        let isGoodLighting = luminance >= 0.18 && luminance <= 0.88

        let qualityScore = (qualityReq.results?.first as? VNFaceObservation)?.faceCaptureQuality ?? 0.5
        let isGoodQuality = qualityScore >= 0.30

        let yaw = estimateHeadYaw(face: face)
        let angleCheck = angle.matches(yaw: yaw)

        let message: String
        if !isCentered {
            message = "Move your head toward the center of the frame."
        } else if !isGoodSize {
            message = bbox.width < 0.15 ? "Move a little closer to the camera." : "Move back slightly from the camera."
        } else if !isGoodLighting {
            message = luminance < 0.18 ? "Lighting is too dark. Increase ambient light." : "Lighting is too bright or glare is present."
        } else if !isGoodQuality {
            message = "Hold still for a clear capture."
        } else if !angleCheck.matches {
            message = angleCheck.feedback
        } else {
            message = "Pose and lighting aligned! Ready to capture."
        }

        let report = EnrollmentQualityReport(
            faceDetected: true,
            multipleFaces: false,
            isCentered: isCentered,
            isGoodSize: isGoodSize,
            isGoodLighting: isGoodLighting,
            isGoodQuality: isGoodQuality,
            angleMatched: angleCheck.matches,
            statusMessage: message,
            faceRect: bbox,
            yaw: yaw,
            qualityScore: qualityScore,
            luminance: luminance
        )
        self.lastEnrollmentQuality = report
        return report
    }

    public func checkEnrollmentEligibility() -> (eligible: Bool, message: String, faceRect: CGRect?) {
        let report = evaluateEnrollmentFrame(for: .front)
        return (report.isReadyToCapture, report.statusMessage, report.faceRect)
    }

    public func enrollSample(angle: OwnerSampleAngle) -> (success: Bool, message: String) {
        guard let image = latestPreviewImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (false, "No camera frame available. Please start monitor first.")
        }

        let faceReq = VNDetectFaceRectanglesRequest()
        let qualityReq = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([faceReq, qualityReq])

        guard let face = faceReq.results?.first else {
            return (false, "No face detected in frame. Please face the camera.")
        }

        if let count = faceReq.results?.count, count > 1 {
            return (false, "Multiple faces detected. Please ensure only you are in frame.")
        }

        let featurePrintReq = VNGenerateImageFeaturePrintRequest()
        featurePrintReq.regionOfInterest = face.boundingBox
        try? handler.perform([featurePrintReq])

        guard let obs = featurePrintReq.results?.first as? VNFeaturePrintObservation else {
            return (false, "Could not generate facial feature print. Check lighting.")
        }

        // 1. Save angle observation file
        let angleFileURL = ownerURL.appendingPathComponent("owner_\(angle.rawValue).data")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: obs, requiringSecureCoding: true) {
            try? data.write(to: angleFileURL)
        }

        // 2. Save preview photo for this angle
        let photoURL = ownerURL.appendingPathComponent("owner_\(angle.rawValue).jpg")
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        if let jpg = bitmap.representation(using: .jpeg, properties: [:]) {
            try? jpg.write(to: photoURL)
            // If front angle, also save as primary owner.jpg
            if angle == .front {
                let mainPhotoURL = ownerURL.appendingPathComponent("owner.jpg")
                try? jpg.write(to: mainPhotoURL)
            }
        }

        // 3. Save metadata
        let qualityScore = (qualityReq.results?.first as? VNFaceObservation)?.faceCaptureQuality
        let yaw = estimateHeadYaw(face: face)
        saveAngleMetadata(angle: angle, quality: qualityScore, yaw: yaw)

        // 4. Reload all angle files and compile aggregated prints
        loadOwnerProfile()

        // Save aggregate prints archive
        let printsURL = ownerURL.appendingPathComponent("owner_prints.data")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: self.ownerFeaturePrints as NSArray, requiringSecureCoding: true) {
            try? data.write(to: printsURL)
        }

        PetState.shared.setTemporaryMood(.proud, duration: 3.0)
        PetState.shared.showBubble("Enrolled \(angle.title) sample! ✨", duration: 3.0)
        SoundEffect.success.play()

        return (true, "\(angle.title) sample enrolled successfully!")
    }

    public func enrollCurrentFaceAsOwner(sampleIndex: Int? = nil) -> (success: Bool, message: String) {
        // Fallback convenience method: pick next unenrolled angle or front
        let targetAngle: OwnerSampleAngle
        if !isSampleEnrolled(angle: .front) {
            targetAngle = .front
        } else if !isSampleEnrolled(angle: .leftProfile) {
            targetAngle = .leftProfile
        } else if !isSampleEnrolled(angle: .rightProfile) {
            targetAngle = .rightProfile
        } else {
            targetAngle = .front
        }
        return enrollSample(angle: targetAngle)
    }

    public func isSampleEnrolled(angle: OwnerSampleAngle) -> Bool {
        return enrolledAngles.contains(angle)
    }

    public func getSamplePhoto(angle: OwnerSampleAngle) -> NSImage? {
        let photoURL = ownerURL.appendingPathComponent("owner_\(angle.rawValue).jpg")
        return NSImage(contentsOf: photoURL)
    }

    public func deleteSample(angle: OwnerSampleAngle) {
        let fileURL = ownerURL.appendingPathComponent("owner_\(angle.rawValue).data")
        let photoURL = ownerURL.appendingPathComponent("owner_\(angle.rawValue).jpg")
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: photoURL)
        loadOwnerProfile()

        // Re-save aggregate prints archive
        let printsURL = ownerURL.appendingPathComponent("owner_prints.data")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: self.ownerFeaturePrints as NSArray, requiringSecureCoding: true) {
            try? data.write(to: printsURL)
        }
        PetState.shared.showBubble("\(angle.title) sample removed.", duration: 2.0)
    }

    public func resetOwnerProfile() {
        for angle in OwnerSampleAngle.allCases {
            let fileURL = ownerURL.appendingPathComponent("owner_\(angle.rawValue).data")
            let photoURL = ownerURL.appendingPathComponent("owner_\(angle.rawValue).jpg")
            try? fileManager.removeItem(at: fileURL)
            try? fileManager.removeItem(at: photoURL)
        }
        let printsURL = ownerURL.appendingPathComponent("owner_prints.data")
        let legacyPrintURL = ownerURL.appendingPathComponent("owner_print.data")
        let photoURL = ownerURL.appendingPathComponent("owner.jpg")
        let metaURL = ownerURL.appendingPathComponent("owner_metadata.json")
        try? fileManager.removeItem(at: printsURL)
        try? fileManager.removeItem(at: legacyPrintURL)
        try? fileManager.removeItem(at: photoURL)
        try? fileManager.removeItem(at: metaURL)

        self.ownerFeaturePrints = []
        self.coordinator.setOwnerFeaturePrints([])
        self.isOwnerEnrolled = false
        self.enrolledSamplesCount = 0
        self.enrolledAngles = []
        self.alertController.reset()
        PetState.shared.showBubble("Owner profile removed.", duration: 2.0)
    }

    public func getOwnerPhoto() -> NSImage? {
        let photoURL = ownerURL.appendingPathComponent("owner.jpg")
        return NSImage(contentsOf: photoURL)
    }

    private func saveAngleMetadata(angle: OwnerSampleAngle, quality: Float?, yaw: Double?) {
        let metaURL = ownerURL.appendingPathComponent("owner_metadata.json")
        var currentMeta: [String: [String: Any]] = [:]
        if let data = try? Data(contentsOf: metaURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            currentMeta = json
        }
        currentMeta[angle.rawValue] = [
            "angle": angle.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "quality": quality ?? 0.5,
            "yaw": yaw ?? 0.0
        ]
        if let outData = try? JSONSerialization.data(withJSONObject: currentMeta, options: [.prettyPrinted]) {
            try? outData.write(to: metaURL)
        }
    }

    private func loadOwnerProfile() {
        let printsURL = ownerURL.appendingPathComponent("owner_prints.data")
        let legacyPrintURL = ownerURL.appendingPathComponent("owner_print.data")

        var detectedAngles: Set<OwnerSampleAngle> = []
        var angleObservations: [VNFeaturePrintObservation] = []

        for angle in OwnerSampleAngle.allCases {
            let fileURL = ownerURL.appendingPathComponent("owner_\(angle.rawValue).data")
            if let data = try? Data(contentsOf: fileURL),
               let obs = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data) {
                detectedAngles.insert(angle)
                angleObservations.append(obs)
            }
        }

        if !angleObservations.isEmpty {
            self.ownerFeaturePrints = angleObservations
            self.coordinator.setOwnerFeaturePrints(angleObservations)
            self.isOwnerEnrolled = true
            self.enrolledSamplesCount = angleObservations.count
            self.enrolledAngles = detectedAngles
            return
        }

        if let data = try? Data(contentsOf: printsURL),
           let list = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, VNFeaturePrintObservation.self], from: data) as? [VNFeaturePrintObservation],
           !list.isEmpty {
            self.ownerFeaturePrints = list
            self.coordinator.setOwnerFeaturePrints(list)
            self.isOwnerEnrolled = true
            self.enrolledSamplesCount = list.count
            self.enrolledAngles = [.front]
        } else if let data = try? Data(contentsOf: legacyPrintURL),
                  let single = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data) {
            self.ownerFeaturePrints = [single]
            self.coordinator.setOwnerFeaturePrints([single])
            self.isOwnerEnrolled = true
            self.enrolledSamplesCount = 1
            self.enrolledAngles = [.front]
        } else {
            self.ownerFeaturePrints = []
            self.coordinator.setOwnerFeaturePrints([])
            self.isOwnerEnrolled = false
            self.enrolledSamplesCount = 0
            self.enrolledAngles = []
        }
    }
}
