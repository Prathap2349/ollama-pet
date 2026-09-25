import Foundation
import AVFoundation
import Vision
import AppKit
import Combine

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
}

public struct TrackedSubject: Identifiable {
    public let id: UUID
    public var rect: CGRect // Normalized (0...1) in Vision coords (origin bottom-left)
    public var firstSeen: Date
    public var lastSeen: Date
    public var isOwner: Bool
    public var isUncertain: Bool
    public var lastRecognitionTime: Date?
    public var hasCapturedSnapshot: Bool

    public var dwellDuration: TimeInterval {
        return lastSeen.timeIntervalSince(firstSeen)
    }

    public init(id: UUID = UUID(), rect: CGRect, isOwner: Bool = false, isUncertain: Bool = false) {
        self.id = id
        self.rect = rect
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.isOwner = isOwner
        self.isUncertain = isUncertain
        self.hasCapturedSnapshot = false
    }
}

public enum MonitoringPerformanceMode: String, CaseIterable, Codable, Identifiable {
    case lowPower = "Low Power"
    case balanced = "Balanced"
    case responsive = "Responsive"

    public var id: String { rawValue }

    public var baseInterval: Double {
        switch self {
        case .lowPower: return 2.2
        case .balanced: return 1.4
        case .responsive: return 0.9
        }
    }

    public var activeInterval: Double {
        switch self {
        case .lowPower: return 1.2
        case .balanced: return 0.7
        case .responsive: return 0.4
        }
    }

    public var ownerRelaxedInterval: Double {
        switch self {
        case .lowPower: return 3.5
        case .balanced: return 2.4
        case .responsive: return 1.6
        }
    }
}

// MARK: - Lightweight IoU Tracker

private final class LightweightIoUTracker {
    private var subjects: [TrackedSubject] = []
    private let iouThreshold: CGFloat = 0.28
    private let maxTimeWithoutUpdate: TimeInterval = 3.5

    func update(detections: [(rect: CGRect, isOwner: Bool, isUncertain: Bool, wasRecognized: Bool)]) -> [TrackedSubject] {
        let now = Date()
        var matchedIndices = Set<Int>()
        var updatedSubjects: [TrackedSubject] = []

        for det in detections {
            var bestIoU: CGFloat = 0.0
            var bestIdx: Int? = nil

            for (idx, subj) in subjects.enumerated() {
                if matchedIndices.contains(idx) { continue }
                let iou = computeIoU(subj.rect, det.rect)
                if iou > bestIoU && iou >= iouThreshold {
                    bestIoU = iou
                    bestIdx = idx
                }
            }

            if let matchedIdx = bestIdx {
                matchedIndices.insert(matchedIdx)
                var subj = subjects[matchedIdx]
                subj.rect = det.rect
                subj.lastSeen = now
                if det.wasRecognized {
                    subj.isOwner = det.isOwner
                    subj.isUncertain = det.isUncertain
                    subj.lastRecognitionTime = now
                }
                updatedSubjects.append(subj)
            } else {
                var newSubj = TrackedSubject(rect: det.rect, isOwner: det.isOwner, isUncertain: det.isUncertain)
                if det.wasRecognized {
                    newSubj.lastRecognitionTime = now
                }
                updatedSubjects.append(newSubj)
            }
        }

        // Retain surviving recent tracks
        for (idx, subj) in subjects.enumerated() {
            if !matchedIndices.contains(idx) && now.timeIntervalSince(subj.lastSeen) < maxTimeWithoutUpdate {
                updatedSubjects.append(subj)
            }
        }

        self.subjects = updatedSubjects
        return subjects
    }

    func clear() {
        subjects.removeAll()
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
    var onFrameProcessed: (([(rect: CGRect, isOwner: Bool, isUncertain: Bool, wasRecognized: Bool)], CGImage?, PresenceStatus) -> Void)?

    // Shared reusable CIContext to prevent memory/GPU churn
    private let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])

    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.ollamapet.presence.sessionQueue", qos: .userInitiated)

    var intervalSeconds: Double = 1.4
    var isLivePreviewRequested: Bool = false
    private var lastAnalysisTimestamp: TimeInterval = 0
    private var ownerFeaturePrint: VNFeaturePrintObservation?

    func setOwnerFeaturePrint(_ print: VNFeaturePrintObservation?) {
        self.ownerFeaturePrint = print
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

            let outputQueue = DispatchQueue(label: "com.ollamapet.presence.videoQueue", qos: .userInteractive)
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
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date().timeIntervalSince1970
        guard now - lastAnalysisTimestamp >= intervalSeconds else { return }
        lastAnalysisTimestamp = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Step 1: Detect Human Rectangles first (Fastest filter)
        let humanRequest = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([humanRequest])
            let humanResults = humanRequest.results ?? []

            if humanResults.isEmpty {
                // Zero humans detected -> Publish away state immediately without further Vision or preview work!
                let cgPreview: CGImage? = self.isLivePreviewRequested ? self.renderCGImage(from: pixelBuffer) : nil
                self.onFrameProcessed?([], cgPreview, .away)
                return
            }

            // Step 2: Humans are present -> Detect Faces for Identification
            let faceRequest = VNDetectFaceRectanglesRequest()
            try handler.perform([faceRequest])
            let faceResults = faceRequest.results ?? []

            var detections: [(rect: CGRect, isOwner: Bool, isUncertain: Bool, wasRecognized: Bool)] = []
            var status: PresenceStatus = .searching

            let hasEnrolledOwner = self.ownerFeaturePrint != nil

            for human in humanResults {
                let hRect = human.boundingBox
                // Check if any face overlaps this human body
                let matchingFace = faceResults.first { face in
                    face.boundingBox.intersects(hRect) || hRect.intersects(face.boundingBox)
                }

                if let face = matchingFace {
                    if let ownerPrint = self.ownerFeaturePrint {
                        // Compare feature print
                        let facePrintReq = VNGenerateImageFeaturePrintRequest()
                        facePrintReq.regionOfInterest = face.boundingBox
                        try? handler.perform([facePrintReq])

                        if let obs = facePrintReq.results?.first as? VNFeaturePrintObservation {
                            var distance: Float = 1.0
                            try? obs.computeDistance(&distance, to: ownerPrint)

                            if distance < 0.40 {
                                detections.append((rect: hRect, isOwner: true, isUncertain: false, wasRecognized: true))
                                status = .ownerPresent
                            } else if distance <= 0.52 {
                                detections.append((rect: hRect, isOwner: false, isUncertain: true, wasRecognized: true))
                                if status != .ownerPresent { status = .uncertain }
                            } else {
                                detections.append((rect: hRect, isOwner: false, isUncertain: false, wasRecognized: true))
                                if status != .ownerPresent { status = .unknownDetected }
                            }
                        } else {
                            detections.append((rect: hRect, isOwner: false, isUncertain: true, wasRecognized: false))
                            if status != .ownerPresent { status = .uncertain }
                        }
                    } else {
                        // Owner profile not configured
                        detections.append((rect: hRect, isOwner: false, isUncertain: false, wasRecognized: false))
                        status = .personDetectedNoOwner
                    }
                } else {
                    // Human detected but face obscured
                    detections.append((rect: hRect, isOwner: false, isUncertain: false, wasRecognized: false))
                    if status != .ownerPresent {
                        status = hasEnrolledOwner ? .noFace : .personDetectedNoOwner
                    }
                }
            }

            if detections.count > 1 {
                status = .multipleDetected
            }

            // Only render preview image if user requested it!
            let cgPreview: CGImage? = self.isLivePreviewRequested ? self.renderCGImage(from: pixelBuffer) : nil

            self.onFrameProcessed?(detections, cgPreview, status)
        } catch {
            // Ignore frame processing errors safely
        }
    }

    /// Reusable CIContext image rendering
    private func renderCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return sharedCIContext.createCGImage(ciImage, from: ciImage.extent)
    }

    /// Instant snapshot capture of a single frame
    func captureSingleSnapshot(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return renderCGImage(from: pixelBuffer)
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

    private let tracker = LightweightIoUTracker()
    private let coordinator = PresenceCaptureCoordinator()
    private var snapshotCooldownUntil: Date = Date.distantPast

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

        loadOwnerProfile()
        updateSnapshotCount()

        coordinator.onFrameProcessed = { [weak self] detections, cgImage, status in
            Task { @MainActor [weak self] in
                self?.handleProcessedFrame(detections: detections, cgImage: cgImage, status: status)
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
        presenceStatus = .idle
        trackedSubjects = []
        latestPreviewImage = nil
        tracker.clear()
        coordinator.stop()
    }

    private func setupAndStartCapture() {
        updateSamplingFrequency()
        coordinator.start(interval: coordinator.intervalSeconds) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    self.isRunning = true
                    self.presenceStatus = .searching
                } else {
                    self.presenceStatus = .cameraUnavailable
                }
            }
        }
    }

    // MARK: - Frame & Subject Processing

    private func handleProcessedFrame(
        detections: [(rect: CGRect, isOwner: Bool, isUncertain: Bool, wasRecognized: Bool)],
        cgImage: CGImage?,
        status: PresenceStatus
    ) {
        guard isRunning else { return }

        let subjects = tracker.update(detections: detections)
        self.trackedSubjects = subjects
        self.presenceStatus = status

        // Update preview image only if requested
        if isLivePreviewRequested, let cg = cgImage {
            self.latestPreviewImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
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
                    snapshotCooldownUntil = now.addingTimeInterval(60.0) // 1 minute cooldown per unknown subject

                    if let cg = cgImage {
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

    // MARK: - Guided Owner Enrollment Flow

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

    public func enrollCurrentFaceAsOwner() -> (success: Bool, message: String) {
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
            let data = try? NSKeyedArchiver.archivedData(withRootObject: obs, requiringSecureCoding: true)
            let printURL = ownerURL.appendingPathComponent("owner_print.data")
            try? data?.write(to: printURL)

            // Save owner photo preview for settings confirmation
            let photoURL = ownerURL.appendingPathComponent("owner.jpg")
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            if let jpg = bitmap.representation(using: .jpeg, properties: [:]) {
                try? jpg.write(to: photoURL)
            }

            self.coordinator.setOwnerFeaturePrint(obs)
            self.isOwnerEnrolled = true
            PetState.shared.showBubble("Owner profile saved! ✨", duration: 3.0)
            SoundEffect.success.play()
            return (true, "Owner profile enrolled successfully!")
        }

        return (false, "Could not generate facial feature print. Try with better lighting.")
    }

    public func resetOwnerProfile() {
        let printURL = ownerURL.appendingPathComponent("owner_print.data")
        let photoURL = ownerURL.appendingPathComponent("owner.jpg")
        try? fileManager.removeItem(at: printURL)
        try? fileManager.removeItem(at: photoURL)
        self.coordinator.setOwnerFeaturePrint(nil)
        self.isOwnerEnrolled = false
        PetState.shared.showBubble("Owner profile removed.", duration: 2.0)
    }

    public func getOwnerPhoto() -> NSImage? {
        let photoURL = ownerURL.appendingPathComponent("owner.jpg")
        return NSImage(contentsOf: photoURL)
    }

    private func loadOwnerProfile() {
        let printURL = ownerURL.appendingPathComponent("owner_print.data")
        if let data = try? Data(contentsOf: printURL),
           let obs = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data) {
            self.coordinator.setOwnerFeaturePrint(obs)
            self.isOwnerEnrolled = true
        } else {
            self.isOwnerEnrolled = false
        }
    }
}
