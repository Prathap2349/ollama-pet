import Foundation
import AVFoundation
import Vision
import AppKit

public enum PersonPresenceState: String {
    case absent = "User Away"
    case present = "User Present"
    case still = "Very Still"
    case unknown = "Checking..."
}

// Background session manager isolated from MainActor to avoid Swift 5.9/6 isolation conflicts
private class VisionCaptureSessionCoordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession?
    var videoOutput: AVCaptureVideoDataOutput?
    let sessionQueue = DispatchQueue(label: "com.ollamapet.visionQueue")

    var intervalSeconds: Double = 10.0
    var lastAnalysisTimestamp: TimeInterval = 0
    var onDetectionResult: ((Bool) -> Void)?

    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .vga640x480

            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]

            let queue = DispatchQueue(label: "com.ollamapet.videoProcessing")
            output.setSampleBufferDelegate(self, queue: queue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            session.startRunning()

            self.captureSession = session
            self.videoOutput = output
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.videoOutput = nil
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

        let request = VNDetectHumanRectanglesRequest { [weak self] req, _ in
            let results = req.results as? [VNHumanObservation] ?? []
            let personDetected = !results.isEmpty
            self?.onDetectionResult?(personDetected)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
}

@MainActor
public class VisionGuardian: NSObject, ObservableObject {
    public static let shared = VisionGuardian()

    @Published public var isRunning: Bool = false
    @Published public var presenceState: PersonPresenceState = .unknown
    @Published public var permissionGranted: Bool = false
    @Published public var lastDetectionDate: Date? = nil
    @Published public var availableCameras: [String] = []

    private let coordinator = VisionCaptureSessionCoordinator()
    private var consecutiveStationaryCount: Int = 0
    private var consecutiveAbsentCount: Int = 0

    override public init() {
        super.init()
        coordinator.onDetectionResult = { [weak self] personFound in
            Task { @MainActor in
                self?.handleDetectionResults(personFound: personFound)
            }
        }
        checkPermission()
        loadAvailableCameras()
    }

    public func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        default:
            permissionGranted = false
        }
    }

    public func requestPermission() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                continuation.resume(returning: authorized)
            }
        }
        self.permissionGranted = granted
        return granted
    }

    public func loadAvailableCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        self.availableCameras = discovery.devices.map { $0.localizedName }
    }

    public func startSession() {
        guard !isRunning else { return }

        if !permissionGranted {
            Task {
                let granted = await requestPermission()
                if granted {
                    self.beginCapture()
                } else {
                    PetState.shared.showBubble("📷 Camera permission needed", duration: 2.5)
                }
            }
        } else {
            beginCapture()
        }
    }

    private func beginCapture() {
        coordinator.intervalSeconds = Double(DataManager.shared.savedData.cameraIntervalSeconds ?? 10)
        coordinator.start()
        isRunning = true
        presenceState = .unknown
    }

    public func stopSession() {
        guard isRunning else { return }
        isRunning = false
        presenceState = .unknown
        coordinator.stop()
    }

    private func handleDetectionResults(personFound: Bool) {
        lastDetectionDate = Date()

        if personFound {
            consecutiveAbsentCount = 0
            consecutiveStationaryCount += 1

            if presenceState == .absent {
                presenceState = .present
                if FocusGuardian.shared.isSessionActive {
                    FocusGuardian.shared.notifyUserReturn()
                }
            } else {
                presenceState = .present
            }

            let alertStill = DataManager.shared.savedData.stillnessAlertEnabled ?? true
            if alertStill && consecutiveStationaryCount >= 6 {
                consecutiveStationaryCount = 0
                presenceState = .still
                PetState.shared.showBubble("You've been very still. Everything okay? 🌿", duration: 3.5)
            }
        } else {
            consecutiveStationaryCount = 0
            consecutiveAbsentCount += 1

            if consecutiveAbsentCount >= 2 && presenceState != .absent {
                presenceState = .absent
                if FocusGuardian.shared.isSessionActive {
                    FocusGuardian.shared.notifyUserAway()
                }
            }
        }
    }
}
