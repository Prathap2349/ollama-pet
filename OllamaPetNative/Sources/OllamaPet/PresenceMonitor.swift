import Foundation
import AVFoundation
import Vision
import AppKit
import Combine

// MARK: - Models

public struct TrackedSubject: Identifiable {
    public let id: UUID
    public var rect: CGRect // Normalized (0...1) in Vision coords (origin bottom-left)
    public var firstSeen: Date
    public var lastSeen: Date
    public var isOwner: Bool
    public var hasCapturedSnapshot: Bool

    public var dwellDuration: TimeInterval {
        return lastSeen.timeIntervalSince(firstSeen)
    }

    public init(id: UUID = UUID(), rect: CGRect, isOwner: Bool = false) {
        self.id = id
        self.rect = rect
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.isOwner = isOwner
        self.hasCapturedSnapshot = false
    }
}

public enum PresenceStatus: String {
    case idle = "Idle"
    case searching = "Scanning..."
    case ownerPresent = "Owner Verified 👤"
    case unknownDetected = "Unknown Subject 👀"
    case multipleDetected = "Multiple People 👥"
    case away = "User Away 💤"
    case cameraUnavailable = "Camera Inactive"
}

// MARK: - Lightweight IoU Tracker

private final class LightweightIoUTracker {
    private var subjects: [TrackedSubject] = []
    private let iouThreshold: CGFloat = 0.30
    private let maxTimeWithoutUpdate: TimeInterval = 3.5

    func update(detections: [(rect: CGRect, isOwner: Bool)]) -> [TrackedSubject] {
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
                if det.isOwner { subj.isOwner = true }
                updatedSubjects.append(subj)
            } else {
                // New subject track
                let newSubj = TrackedSubject(rect: det.rect, isOwner: det.isOwner)
                updatedSubjects.append(newSubj)
            }
        }

        // Keep surviving subjects that were seen recently
        for (idx, subj) in subjects.enumerated() {
            if !matchedIndices.contains(idx) && now.timeIntervalSince(subj.lastSeen) < maxTimeWithoutUpdate {
                updatedSubjects.append(subj)
            }
        }

        self.subjects = updatedSubjects
        return subjects
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

// MARK: - Video Output Delegate Coordinator

private final class PresenceCaptureCoordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrameProcessed: (([(rect: CGRect, isOwner: Bool)], CGImage?, CVPixelBuffer) -> Void)?
    var intervalSeconds: Double = 1.0
    private var lastAnalysisTimestamp: TimeInterval = 0
    private var ownerFeaturePrint: VNFeaturePrintObservation?
    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.ollamapet.presence.session")

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

            let outputQueue = DispatchQueue(label: "com.ollamapet.presence.videoQueue")
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

        // Convert to CGImage for snapshot or preview if needed
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)

        // Run Apple Vision Human and Face Detection Requests
        let humanRequest = VNDetectHumanRectanglesRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([humanRequest, faceRequest])

            var detections: [(rect: CGRect, isOwner: Bool)] = []

            // Process humans
            if let humanResults = humanRequest.results {
                for human in humanResults {
                    detections.append((rect: human.boundingBox, isOwner: false))
                }
            }

            // If owner print is available, check faces for verification
            if let ownerPrint = self.ownerFeaturePrint, let faceResults = faceRequest.results, !faceResults.isEmpty {
                for face in faceResults {
                    let facePrintReq = VNGenerateImageFeaturePrintRequest()
                    facePrintReq.regionOfInterest = face.boundingBox
                    try? handler.perform([facePrintReq])
                    if let obs = facePrintReq.results?.first as? VNFeaturePrintObservation {
                        var distance: Float = 1.0
                        try? obs.computeDistance(&distance, to: ownerPrint)
                        if distance < 0.45 {
                            // Verified owner face: mark nearby detection as owner
                            for i in 0..<detections.count {
                                if detections[i].rect.intersects(face.boundingBox) || face.boundingBox.intersects(detections[i].rect) {
                                    detections[i].isOwner = true
                                }
                            }
                        }
                    }
                }
            } else if self.ownerFeaturePrint == nil && !detections.isEmpty {
                // If no owner is enrolled yet, treat single detection as owner by default
                if detections.count == 1 {
                    detections[0].isOwner = true
                }
            }

            onFrameProcessed?(detections, cgImage, pixelBuffer)
        } catch {
            // Ignore frame processing errors safely
        }
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

    private let tracker = LightweightIoUTracker()
    private let coordinator = PresenceCaptureCoordinator()

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
        loadOwnerProfile()
        updateSnapshotCount()

        coordinator.onFrameProcessed = { [weak self] detections, cgImage, pixelBuffer in
            Task { @MainActor [weak self] in
                self?.handleProcessedFrame(detections: detections, cgImage: cgImage)
            }
        }
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
        coordinator.stop()
    }

    private func setupAndStartCapture() {
        let interval = DataManager.shared.savedData.presenceIntervalSeconds ?? 1.0
        coordinator.start(interval: interval) { [weak self] success in
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

    private func handleProcessedFrame(detections: [(rect: CGRect, isOwner: Bool)], cgImage: CGImage?) {
        guard isRunning else { return }

        let subjects = tracker.update(detections: detections)
        self.trackedSubjects = subjects

        // Update preview image
        if let cg = cgImage {
            let nsImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            self.latestPreviewImage = nsImage
        }

        // Determine Overall Presence Status
        if subjects.isEmpty {
            presenceStatus = .away
        } else if subjects.count > 1 {
            presenceStatus = .multipleDetected
        } else if let first = subjects.first {
            presenceStatus = first.isOwner ? .ownerPresent : .unknownDetected
        }

        // Handle Unknown Subject Alerts & Snapshots
        let dwellAlertEnabled = DataManager.shared.savedData.presenceDwellAlertEnabled ?? true
        let unknownAlertEnabled = DataManager.shared.savedData.presenceUnknownAlertEnabled ?? true

        for i in 0..<trackedSubjects.count {
            var subj = trackedSubjects[i]
            if !subj.isOwner {
                // Unknown person detected
                if unknownAlertEnabled && subj.dwellDuration >= 5.0 && !subj.hasCapturedSnapshot {
                    subj.hasCapturedSnapshot = true
                    trackedSubjects[i] = subj
                    if let cg = cgImage {
                        saveSnapshotLocally(cgImage: cg)
                    }
                    if dwellAlertEnabled {
                        PetState.shared.showBubble("Unfamiliar person detected near Mac! 👀", duration: 3.5)
                        SoundEffect.alert.play()
                    }
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

    // MARK: - Owner Enrollment

    public func enrollCurrentFaceAsOwner() {
        guard let image = latestPreviewImage, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }

        let faceReq = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([faceReq])

        guard let face = faceReq.results?.first else {
            PetState.shared.showBubble("No face seen to enroll. Look at camera! 📷", duration: 3.0)
            return
        }

        let featurePrintReq = VNGenerateImageFeaturePrintRequest()
        featurePrintReq.regionOfInterest = face.boundingBox
        try? handler.perform([featurePrintReq])

        if let obs = featurePrintReq.results?.first as? VNFeaturePrintObservation {
            let data = try? NSKeyedArchiver.archivedData(withRootObject: obs, requiringSecureCoding: true)
            let printURL = ownerURL.appendingPathComponent("owner_print.data")
            try? data?.write(to: printURL)

            // Save owner photo preview
            let photoURL = ownerURL.appendingPathComponent("owner.jpg")
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            if let jpg = bitmap.representation(using: .jpeg, properties: [:]) {
                try? jpg.write(to: photoURL)
            }

            self.coordinator.setOwnerFeaturePrint(obs)
            self.isOwnerEnrolled = true
            PetState.shared.showBubble("Owner face enrolled successfully! ✨", duration: 3.0)
            SoundEffect.success.play()
        }
    }

    public func resetOwnerProfile() {
        let printURL = ownerURL.appendingPathComponent("owner_print.data")
        let photoURL = ownerURL.appendingPathComponent("owner.jpg")
        try? fileManager.removeItem(at: printURL)
        try? fileManager.removeItem(at: photoURL)
        self.coordinator.setOwnerFeaturePrint(nil)
        self.isOwnerEnrolled = false
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
