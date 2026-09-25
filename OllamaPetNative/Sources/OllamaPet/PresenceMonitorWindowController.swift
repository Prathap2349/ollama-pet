import Cocoa
import SwiftUI

public final class PresenceMonitorWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = PresenceMonitorWindowController()

    private var hostingView: NSHostingView<PresenceWidgetView>?

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 180, height: 140),
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
        panel.backgroundColor = NSColor(red: 15/255, green: 17/255, blue: 26/255, alpha: 0.95)
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
            window?.orderOut(nil)
        } else {
            showWidget()
        }
    }

    public func showWidget() {
        guard let window = self.window else { return }
        if !PresenceMonitor.shared.isRunning {
            PresenceMonitor.shared.start()
        }
        window.orderFront(nil)
    }

    public func hideWidget() {
        window?.orderOut(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        // Keep running in background if enabled in settings
    }
}

// MARK: - SwiftUI Presence Widget View

struct PresenceWidgetView: View {
    @ObservedObject var monitor = PresenceMonitor.shared

    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(monitor.presenceStatus.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Button(action: {
                    PresenceMonitorWindowController.shared.hideWidget()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            // Mini Camera Frame Preview or Radar View
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 70)

                if let img = monitor.latestPreviewImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 70)
                        .clipped()
                        .cornerRadius(8)
                        .opacity(0.85)

                    // Bounding boxes overlay
                    GeometryReader { geo in
                        ForEach(monitor.trackedSubjects) { subj in
                            widgetBoundingBox(subj: subj, in: geo)
                        }
                    }
                    .frame(height: 70)
                } else {
                    VStack(spacing: 3) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(statusColor)
                        Text(monitor.isRunning ? "Scanning zone..." : "Monitor Inactive")
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 8)

            // Footer info: Subject count & Controls
            HStack {
                Text("\(monitor.trackedSubjects.count) Subject\(monitor.trackedSubjects.count == 1 ? "" : "s")")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.7))

                Spacer()

                Button(action: {
                    if monitor.isRunning {
                        monitor.stop()
                    } else {
                        monitor.start()
                    }
                }) {
                    Text(monitor.isRunning ? "Pause" : "Start")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(monitor.isRunning ? Color.red.opacity(0.7) : Color.green.opacity(0.7))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .frame(width: 180, height: 140)
        .background(Color(red: 15/255, green: 17/255, blue: 26/255))
    }

    private var statusColor: Color {
        switch monitor.presenceStatus {
        case .ownerPresent: return .green
        case .unknownDetected: return .orange
        case .multipleDetected: return .yellow
        case .searching: return .cyan
        case .away: return .gray
        case .cameraUnavailable, .idle: return .red
        }
    }

    @ViewBuilder
    private func widgetBoundingBox(subj: TrackedSubject, in geo: GeometryProxy) -> some View {
        let r = subj.rect
        let w = max(16.0, r.width * geo.size.width)
        let h = max(16.0, r.height * geo.size.height)
        let x = r.minX * geo.size.width + w / 2.0
        let y = (1.0 - r.maxY) * geo.size.height + h / 2.0
        let color = subj.isOwner ? Color.green : Color.orange

        RoundedRectangle(cornerRadius: 4)
            .stroke(color, lineWidth: 2)
            .frame(width: w, height: h)
            .position(x: x, y: y)
    }
}
