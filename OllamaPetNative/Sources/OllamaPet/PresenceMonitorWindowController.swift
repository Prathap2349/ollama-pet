import Cocoa
import SwiftUI

public final class PresenceMonitorWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = PresenceMonitorWindowController()

    private var hostingView: NSHostingView<PresenceWidgetView>?

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 154, height: 146),
            styleMask: [.titled, .nonactivatingPanel, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "Presence Monitor"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = NSColor(red: 15/255, green: 17/255, blue: 26/255, alpha: 0.96)
        panel.hasShadow = true

        let rootView = PresenceWidgetView()
        let hosting = NSHostingView(rootView: rootView)
        panel.contentView = hosting
        self.hostingView = hosting

        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func toggleWidget() {
        if window?.isVisible == true {
            hideWidget()
        } else {
            showWidget()
        }
    }

    public func showWidget() {
        guard let window = self.window else { return }
        window.orderFront(nil)
    }

    public func hideWidget() {
        window?.orderOut(nil)
        PresenceMonitor.shared.releaseLivePreview(id: "presence_widget")
    }

    public func setExpanded(_ expanded: Bool) {
        guard let window = self.window else { return }
        let currentOrigin = window.frame.origin
        let newSize = expanded ? NSSize(width: 250, height: 320) : NSSize(width: 154, height: 146)
        let newFrame = NSRect(
            x: currentOrigin.x,
            y: currentOrigin.y - (newSize.height - window.frame.height),
            width: newSize.width,
            height: newSize.height
        )
        window.setFrame(newFrame, display: true, animate: true)
    }

    public func windowWillClose(_ notification: Notification) {
        PresenceMonitor.shared.releaseLivePreview(id: "presence_widget")
    }
}

// MARK: - SwiftUI Presence Widget View

struct PresenceWidgetView: View {
    @ObservedObject var monitor = PresenceMonitor.shared
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Header bar
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(monitor.isRunning ? "LIVE" : "OFF")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                        if isExpanded {
                            monitor.requestLivePreview(id: "presence_widget")
                        } else {
                            monitor.releaseLivePreview(id: "presence_widget")
                        }
                        PresenceMonitorWindowController.shared.setExpanded(isExpanded)
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Button(action: {
                    PresenceMonitorWindowController.shared.hideWidget()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            if !isExpanded {
                // COLLAPSED COMPANION SQUARE
                collapsedBodyView
            } else {
                // EXPANDED CAMERA VIEW
                expandedBodyView
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 15/255, green: 17/255, blue: 26/255))
        .onDisappear {
            monitor.releaseLivePreview(id: "presence_widget")
        }
    }

    // MARK: - Collapsed View (Zero Video Conversion Overhead)

    private var collapsedBodyView: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .stroke(statusColor.opacity(0.35), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Image(systemName: centralStatusIcon)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
            }

            Text(centralStatusTitle)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(centralStatusSubtitle)
                .font(.system(size: 8, design: .rounded))
                .foregroundColor(Color.white.opacity(0.6))
                .lineLimit(1)

            Spacer(minLength: 0)

            HStack {
                Text("\(monitor.trackedSubjects.count) Present")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))

                Spacer()

                Button(action: {
                    if monitor.isRunning {
                        monitor.stop()
                    } else {
                        monitor.start()
                    }
                }) {
                    Text(monitor.isRunning ? "Pause" : "Start")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(monitor.isRunning ? Color.orange.opacity(0.8) : Color.green.opacity(0.8)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
        }
    }

    // MARK: - Expanded Detailed View

    private var expandedBodyView: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.75))
                    .frame(height: 140)

                if let img = monitor.latestPreviewImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 140)
                        .cornerRadius(10)

                    GeometryReader { geo in
                        ForEach(monitor.trackedSubjects) { subj in
                            widgetBoundingBox(subj: subj, in: geo)
                        }
                    }
                    .frame(height: 140)
                } else if monitor.monitoringState == .permissionRequired || monitor.presenceStatus == .permissionRequired {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        Text("Permission Needed")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        HStack(spacing: 6) {
                            Button("Retry") { monitor.retry() }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("Settings") { monitor.openSystemCameraSettings() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                        }
                    }
                    .padding(8)
                } else if monitor.monitoringState == .cameraUnavailable || monitor.presenceStatus == .cameraUnavailable {
                    VStack(spacing: 4) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                        Text("Camera Unavailable")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        Button("Retry") { monitor.retry() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                    }
                    .padding(8)
                } else if monitor.monitoringState == .starting || monitor.presenceStatus == .starting {
                    VStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Starting camera...")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Activating camera feed...")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Status:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(monitor.presenceStatus.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                    Spacer()
                }

                HStack {
                    Text("People nearby:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(monitor.trackedSubjects.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if monitor.isOwnerEnrolled {
                        Text("Profile Active ✓")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    } else {
                        Text("Profile Not Set")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)

            HStack {
                Button(action: {
                    SettingsWindowController.shared.showTab(.presenceMonitor)
                }) {
                    Text("Settings...")
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    if monitor.isRunning {
                        monitor.stop()
                    } else {
                        monitor.start()
                    }
                }) {
                    Text(monitor.isRunning ? "Stop Monitor" : "Resume Monitor")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(monitor.isRunning ? Color.red.opacity(0.8) : Color.green.opacity(0.8)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
        }
    }

    // MARK: - UI Helpers

    private var centralStatusIcon: String {
        switch monitor.presenceStatus {
        case .ownerPresent, .ownerConfirmed: return "person.crop.circle.badge.checkmark"
        case .ownerTemporarilyUnavailable, .noFace: return "person.crop.circle.badge.questionmark"
        case .unknownDetected: return "person.crop.circle.badge.exclamationmark"
        case .faceDetected: return "face.smiling"
        case .uncertain, .verifying: return "person.crop.circle.badge.questionmark"
        case .personDetectedNoOwner: return "person.crop.circle"
        case .multipleDetected: return "person.2.fill"
        case .searching: return "viewfinder"
        case .starting, .recovering: return "arrow.triangle.2.circlepath"
        case .away, .noPerson: return "moon.zzz.fill"
        case .permissionRequired: return "lock.shield.fill"
        case .failed, .cameraError: return "exclamationmark.triangle.fill"
        case .idle, .stopped, .cameraUnavailable: return "video.slash.fill"
        }
    }

    private var centralStatusTitle: String {
        switch monitor.presenceStatus {
        case .ownerPresent, .ownerConfirmed: return "OWNER"
        case .ownerTemporarilyUnavailable, .noFace: return "AWAY-FACING"
        case .unknownDetected: return "UNKNOWN"
        case .faceDetected: return "FACE DETECTED"
        case .uncertain, .verifying: return "VERIFYING"
        case .personDetectedNoOwner: return "PERSON"
        case .multipleDetected: return "MULTIPLE"
        case .searching: return "SCANNING"
        case .starting: return "STARTING"
        case .recovering: return "RECOVERING"
        case .away, .noPerson: return "NO PERSON"
        case .permissionRequired: return "PERMISSION"
        case .failed, .cameraError: return "ERROR"
        case .idle: return "PAUSED"
        case .stopped: return "STOPPED"
        case .cameraUnavailable: return "CAMERA OFF"
        }
    }

    private var centralStatusSubtitle: String {
        switch monitor.presenceStatus {
        case .ownerPresent, .ownerConfirmed: return "Owner Verified"
        case .ownerTemporarilyUnavailable, .noFace: return "Face Temporarily Unavailable"
        case .unknownDetected: return "Unknown Person"
        case .faceDetected: return "Face Detected"
        case .uncertain, .verifying: return "Verifying..."
        case .personDetectedNoOwner: return "Person Detected"
        case .multipleDetected: return "Multiple People"
        case .searching: return "Looking for user"
        case .starting: return "Starting feed..."
        case .recovering: return "Recovering..."
        case .away, .noPerson: return "No Person Detected"
        case .permissionRequired: return "Grant camera access"
        case .failed, .cameraError: return "Camera error"
        case .idle, .stopped: return "Monitoring Stopped"
        case .cameraUnavailable: return "Check permission"
        }
    }

    private var statusColor: Color {
        switch monitor.presenceStatus {
        case .ownerPresent, .ownerConfirmed: return .green
        case .faceDetected: return .blue
        case .uncertain, .verifying: return .yellow
        case .unknownDetected: return .orange
        case .ownerTemporarilyUnavailable, .noFace: return Color(white: 0.8)
        case .personDetectedNoOwner: return .cyan
        case .multipleDetected: return .yellow
        case .searching: return .cyan
        case .starting, .recovering: return .yellow
        case .away, .noPerson: return .indigo
        case .permissionRequired, .failed, .cameraError: return .red
        case .idle, .stopped, .cameraUnavailable: return .gray
        }
    }

    @ViewBuilder
    private func widgetBoundingBox(subj: TrackedSubject, in geo: GeometryProxy) -> some View {
        let r = subj.rect
        let w = max(16.0, r.width * geo.size.width)
        let h = max(16.0, r.height * geo.size.height)
        let x = r.minX * geo.size.width + w / 2.0
        let y = (1.0 - r.maxY) * geo.size.height + h / 2.0
        let color = subj.isOwner ? Color.green : (subj.isUncertain ? Color.yellow : Color.orange)

        RoundedRectangle(cornerRadius: 4)
            .stroke(color, lineWidth: 2)
            .frame(width: w, height: h)
            .position(x: x, y: y)
    }
}
