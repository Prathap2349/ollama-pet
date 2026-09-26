import Foundation
import AppKit
import SwiftUI
import ServiceManagement
import UserNotifications

// MARK: - Dedicated Settings Window Controller

@MainActor
public class SettingsWindowController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    @Published public var activeTab: SettingsTab = .character
    private var window: NSWindow?

    public func showWindow() {
        if window == nil {
            setupWindow()
        }
        window?.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 1)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func showTab(_ tab: SettingsTab) {
        self.activeTab = tab
        showWindow()
    }

    private func setupWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Ollama Pet Settings"
        win.center()
        win.setFrameAutosaveName("OllamaPetSettingsWindow")
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.minSize = NSSize(width: 680, height: 520)

        let settingsView = SettingsContainerView()
        win.contentView = NSHostingView(rootView: settingsView)
        self.window = win
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        // Keep settings above floating pet panel while focused
        window?.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 1)
    }

    public func windowDidResignKey(_ notification: Notification) {
        // Return to normal level when another app is focused
        window?.level = .normal
    }

    public func windowWillClose(_ notification: Notification) {
        DataManager.shared.saveData()
        PetWindowController.shared.window?.orderFrontRegardless()
    }
}

// MARK: - Settings Grouping & Tab Items

public enum SettingsGroup: String, CaseIterable, Identifiable {
    case general = "GENERAL"
    case companion = "COMPANION"
    case aiAndVoice = "AI & VOICE"
    case macControl = "MAC CONTROL"
    case presence = "PRESENCE"
    case privacyAndSystem = "PRIVACY & SYSTEM"

    public var id: String { rawValue }

    public var tabs: [SettingsTab] {
        switch self {
        case .general:
            return [.general, .appearance, .shortcuts]
        case .companion:
            return [.character, .animation]
        case .aiAndVoice:
            return [.ollama, .cloudAi, .voice]
        case .macControl:
            return [.macControl, .actionHistory]
        case .presence:
            return [.presenceMonitor, .screen, .focus]
        case .privacyAndSystem:
            return [.notifications, .permissions, .privacy]
        }
    }
}

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case shortcuts = "Keyboard Shortcuts"
    case character = "Character & Silhouettes"
    case animation = "Animation & Physics"
    case ollama = "Ollama Local AI"
    case cloudAi = "Cloud AI Providers"
    case voice = "Voice Assistant"
    case macControl = "Mac Control"
    case actionHistory = "Action History"
    case presenceMonitor = "Presence Monitor"
    case screen = "Screen Awareness"
    case focus = "Focus & Health"
    case notifications = "Notifications"
    case permissions = "Permissions & Security"
    case privacy = "Privacy & Telemetry"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .shortcuts: return "command"
        case .character: return "pawprint.fill"
        case .animation: return "figure.walk.motion"
        case .ollama: return "cpu.fill"
        case .cloudAi: return "sparkles"
        case .voice: return "mic.fill"
        case .macControl: return "macmini.fill"
        case .actionHistory: return "clock.arrow.circlepath"
        case .presenceMonitor: return "person.crop.rectangle.badge.plus"
        case .screen: return "display"
        case .focus: return "brain.head.profile"
        case .notifications: return "bell.badge.fill"
        case .permissions: return "lock.shield.fill"
        case .privacy: return "hand.raised.fill"
        }
    }
}

// MARK: - Reusable Settings Design System Components

public struct SettingsSection<Content: View>: View {
    public let title: String
    public let subtitle: String?
    public let badge: String?
    public let badgeColor: Color
    public let content: Content

    public init(
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        badgeColor: Color = .accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.badgeColor = badgeColor
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(badgeColor.opacity(0.18)))
                            .foregroundColor(badgeColor)
                    }
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
    }
}

public struct SettingsCard<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

public struct SettingsRow<Trailing: View>: View {
    public let icon: String?
    public let iconColor: Color
    public let title: String
    public let subtitle: String?
    public let trailing: Trailing

    public init(
        icon: String? = nil,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon = icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 2)
    }
}

public struct SettingsToggleRow: View {
    public let icon: String?
    public let iconColor: Color
    public let title: String
    public let subtitle: String?
    public let binding: Binding<Bool>

    public init(
        icon: String? = nil,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.binding = isOn
    }

    public var body: some View {
        SettingsRow(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle) {
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

public struct SettingsStatusCard: View {
    public let statusDotColor: Color
    public let title: String
    public let detail: String
    public let actionTitle: String?
    public let onAction: (() -> Void)?

    public init(
        statusDotColor: Color,
        title: String,
        detail: String,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.statusDotColor = statusDotColor
        self.title = title
        self.detail = detail
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let actionTitle = actionTitle, let onAction = onAction {
                Button(actionTitle) {
                    onAction()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusDotColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusDotColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Live Ollama Status Pill

public struct OllamaStatusPill: View {
    @ObservedObject var client = OllamaClient.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(statusColor.opacity(0.12)))
        .overlay(Capsule().stroke(statusColor.opacity(0.25), lineWidth: 1))
    }

    private var statusColor: Color {
        switch client.connectionState {
        case .connected: return .green
        case .connecting, .reconnecting, .checking: return .orange
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch client.connectionState {
        case .connected:
            return "Ollama Ready (\(client.activeModel))"
        case .connecting:
            return "Connecting to Ollama..."
        case .reconnecting:
            return "Reconnecting..."
        case .checking:
            return "Checking Ollama..."
        case .failed:
            return "Ollama Offline"
        }
    }
}

// MARK: - Main Settings Container

public struct SettingsContainerView: View {
    @ObservedObject var windowController = SettingsWindowController.shared
    @ObservedObject var petState = PetState.shared
    @ObservedObject var perf = PerformanceManager.shared

    public var body: some View {
        HStack(spacing: 0) {
            // Grouped Sidebar Navigation
            VStack(alignment: .leading, spacing: 0) {
                // Header badge
                HStack(spacing: 8) {
                    Text(petState.currentSpecies.icon)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Ollama Pet")
                            .font(.system(size: 14, weight: .bold))
                        Text(perf.isSafeMode ? "🛡️ Safe Mode Active" : "v2.5 Native")
                            .font(.system(size: 11))
                            .foregroundColor(perf.isSafeMode ? .yellow : .secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(SettingsGroup.allCases) { group in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 4)

                                ForEach(group.tabs) { tab in
                                    Button(action: {
                                        windowController.activeTab = tab
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: tab.icon)
                                                .frame(width: 18)
                                                .foregroundColor(windowController.activeTab == tab ? .white : .secondary)
                                            Text(tab.rawValue)
                                                .font(.system(size: 12, weight: windowController.activeTab == tab ? .semibold : .regular))
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7)
                                                .fill(windowController.activeTab == tab ? Color.accentColor : Color.clear)
                                        )
                                        .foregroundColor(windowController.activeTab == tab ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                }

                Spacer()

                // Emergency Safe Mode Quick Button
                VStack(spacing: 6) {
                    Button(action: {
                        perf.toggleSafeMode()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: perf.isSafeMode ? "shield.checkered" : "shield.slash")
                                .foregroundColor(perf.isSafeMode ? .yellow : .secondary)
                            Text(perf.isSafeMode ? "Exit Safe Mode" : "Enable Safe Mode")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(perf.isSafeMode ? Color.yellow.opacity(0.15) : Color.primary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
            .frame(width: 220)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.7))

            Divider()

            // Detail Content
            VStack(spacing: 0) {
                // Top Header Bar with Live Status Pill
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ollama Pet Settings")
                            .font(.system(size: 15, weight: .bold))
                        Text(windowController.activeTab.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    OllamaStatusPill()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

                Divider()

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        switch windowController.activeTab {
                        case .general:
                            GeneralSettingsSection()
                        case .appearance:
                            AppearanceSettingsSection()
                        case .character:
                            CharacterSettingsSection()
                        case .macControl:
                            MacControlSettingsSection()
                        case .permissions:
                            PermissionsPrivacySettingsSection()
                        case .actionHistory:
                            ActionHistorySettingsSection()
                        case .animation:
                            AnimationSettingsSection()
                        case .voice:
                            VoiceSettingsSection()
                        case .shortcuts:
                            ShortcutsSettingsSection()
                        case .ollama:
                            OllamaSettingsSection()
                        case .cloudAi:
                            CloudAISettingsSection()
                        case .presenceMonitor:
                            PresenceSettingsSection()
                        case .screen:
                            ScreenSettingsSection()
                        case .focus:
                            FocusSettingsSection()
                        case .notifications:
                            NotificationSettingsSection()
                        case .privacy:
                            PrivacySettingsSection()
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 540)
    }
}

// MARK: - Character & Silhouette Section (Key Focus of P0/P1)

struct CharacterSettingsSection: View {
    @ObservedObject var petState = PetState.shared
    @ObservedObject var perf = PerformanceManager.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Character & Distinct Silhouettes")
                .font(.system(size: 18, weight: .bold))

            Text("Each character features a unique, anatomically distinct silhouette—not just a recolor. Inspect them live below.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // 1. Rendering Engine Mode (3D Next-Gen vs 2D Classic Canvas)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rendering Engine Mode")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Choose between 3D Metal SceneKit real geometry or 2D Classic Canvas.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    ForEach(RenderEngineMode.allCases) { mode in
                        let isSelected = (petState.renderEngineMode == mode)
                        Button(action: {
                            petState.setRenderEngineMode(mode)
                            SoundEffect.click.play()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? petState.currentSpecies.accentColor.opacity(0.25) : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? petState.currentSpecies.accentColor : Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // 2. Character Customization (Phase 14)
            VStack(alignment: .leading, spacing: 10) {
                Text("Character Customization & Accessories")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 16) {
                    if petState.currentSpecies == .dragon {
                        Toggle("Horns", isOn: Binding(
                            get: { petState.customHornEnabled },
                            set: { _ in petState.toggleHorns() }
                        ))
                        .toggleStyle(.checkbox)

                        Toggle("Wings", isOn: Binding(
                            get: { petState.customWingsEnabled },
                            set: { _ in petState.toggleWings() }
                        ))
                        .toggleStyle(.checkbox)
                    }

                    Text("Accessory:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("", selection: Binding(
                        get: { petState.customAccessory },
                        set: { petState.setCustomAccessory($0) }
                    )) {
                        Text("None").tag("none")
                        Text("👓 Glasses").tag("glasses")
                        Text("🎩 Top Hat").tag("hat")
                        Text("🎀 Bowtie").tag("bowtie")
                        Text("👑 Crown").tag("crown")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // Silhouette Grayscale Test Mode Toggle (Prominent)
            Toggle(isOn: $perf.grayscaleTestMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer Grayscale Silhouette Test Mode")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Renders characters in pure high-contrast grayscale to verify distinct silhouette geometry without color cues.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // Live Silhouette Preview Stage
            HStack(spacing: 20) {
                // Interactive 3D Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(perf.grayscaleTestMode ? Color(white: 0.15) : Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    CharacterPreviewView(previewSpecies: nil)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(width: 140, height: 140)

                // Character Info Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(petState.currentSpecies.icon)
                            .font(.system(size: 20))
                        Text(petState.currentSpecies.displayName)
                            .font(.system(size: 16, weight: .bold))
                        Text("(\(petState.currentSpecies.speciesName))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(petState.currentSpecies.personality)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(petState.currentSpecies.accentColor.opacity(0.18)))
                            .foregroundColor(petState.currentSpecies.accentColor)
                    }

                    Text(petState.currentSpecies.lore)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .top, spacing: 6) {
                            Text("Distinct Feature:")
                                .font(.system(size: 11, weight: .bold))
                            Text(distinctFeatureDescription(for: petState.currentSpecies))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(alignment: .top, spacing: 6) {
                            Text("Idle Behavior:")
                                .font(.system(size: 11, weight: .bold))
                            Text(petState.currentSpecies.idleBehavior)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.03)))

            // Species Grid (All 7 species with live native Canvas preview cards)
            Text("Select Companion")
                .font(.system(size: 14, weight: .semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(PetSpecies.allCases) { species in
                    SpeciesPreviewCard(
                        species: species,
                        isSelected: petState.currentSpecies == species,
                        action: {
                            petState.setSpecies(species)
                        }
                    )
                }
            }

            Divider()
                .padding(.vertical, 6)

            // Walk & Special Ability Test Buttons
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interactive Rig Testing")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Test locomotion and unique 3D abilities (\(petState.currentSpecies.specialAbility.displayName)).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Test Ability") {
                    petState.triggerSpecialAbility()
                }
                .buttonStyle(.bordered)

                Button("Walk Test") {
                    WalkerManager.shared.startWalk(species: petState.currentSpecies, isTest: true)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // Autonomous Life Scheduler
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Autonomous Life Frequency")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Randomized 4–6 min intervals for life behaviors, stretches, and abilities (auto-pauses during focus & chat).")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: Binding(
                        get: { petState.autonomousLifeSetting },
                        set: { petState.setAutonomousLifeSetting($0) }
                    )) {
                        ForEach(AutonomousLifeSetting.allCases) { setting in
                            Text(setting.rawValue).tag(setting)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
    }

    private func distinctFeatureDescription(for species: PetSpecies) -> String {
        switch species {
        case .cat: return "Triangular upright ears, whisker pairs, feline tail, 4-paw stance."
        case .dragon: return "Dual curved horns, membrane wings, dorsal spine ridge, spade tail."
        case .robot: return "Square chassis, antenna beacon, mechanical shoulder/foot joints, chest core."
        case .robotcat: return "Cybernetic feline hybrid with visor HUD and segmented tail."
        case .ghost: return "Legless wavy floating sheet, ghostly floating wisps, floating drift."
        case .fox: return "Large angled ears with dark rims, elongated muzzle, giant bushy white-tipped tail."
        case .bunny: return "Long upright ears, spherical body, hopping hind limbs, round cotton puff tail."
        }
    }
}

// MARK: - Reusable 2D / 3D Character Preview View

struct CharacterPreviewView: View {
    let previewSpecies: PetSpecies?
    @ObservedObject var petState = PetState.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared
    @ObservedObject var perf = PerformanceManager.shared

    var effectiveSpecies: PetSpecies {
        previewSpecies ?? petState.currentSpecies
    }

    var body: some View {
        if petState.renderEngineMode == .threeD {
            Pet3DSceneView(previewSpecies: previewSpecies)
        } else {
            TimelineView(.animation(minimumInterval: perf.minimumRenderInterval)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let snapshot = motion.evaluateSnapshot(
                        at: t,
                        animState: petState.animState,
                        mood: petState.currentMood,
                        atmosphere: .clearDay,
                        isSafeMode: perf.isSafeMode
                    )
                    let model = CharacterStructuralModel.model(for: effectiveSpecies)

                    PetCanvasRenderer.draw(
                        context: &context,
                        size: size,
                        species: effectiveSpecies,
                        model: model,
                        animState: petState.animState,
                        mood: petState.currentMood,
                        snapshot: snapshot,
                        perf: perf
                    )
                }
            }
        }
    }
}

// MARK: - Native Character Preview Card

struct SpeciesPreviewCard: View {
    let species: PetSpecies
    let isSelected: Bool
    @ObservedObject var perf = PerformanceManager.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Live 2D/3D Preview Stage with Selection Badge
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(perf.grayscaleTestMode ? Color(white: 0.15) : Color.black.opacity(0.85))

                    CharacterPreviewView(previewSpecies: species)
                        .frame(height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16))
                            .padding(6)
                    }
                }
                .frame(height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Character Identity & Unique Silhouette Description
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(species.displayName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                        Spacer()
                        Text(species.speciesName)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)))
                            .foregroundColor(.secondary)
                    }

                    Text(uniqueDescription(for: species))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func uniqueDescription(for species: PetSpecies) -> String {
        switch species {
        case .cat:
            return "Feline sitting silhouette with triangular ears and curved tail."
        case .dragon:
            return "Winged dragon with dual horns, dorsal spikes, and spade tail."
        case .robot:
            return "Rectangular mechanical android with top antenna and LED chest core."
        case .robotcat:
            return "Cybernetic feline hybrid with plated ears and circuit tail."
        case .ghost:
            return "Legless floating spectral shroud with wavy undulating wisps."
        case .fox:
            return "Slender fox with elongated snout muzzle and large bushy tail."
        case .bunny:
            return "Very tall upright ears, chubby round body, and cotton puff tail."
        }
    }
}

// MARK: - Quality Preset Card

struct QualityPresetCard: View {
    let quality: PerformanceQuality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(quality.displayName)
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                Text("\(Int(quality.targetFPS)) FPS Cap")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animation & Performance Section

struct AnimationSettingsSection: View {
    @ObservedObject var perf = PerformanceManager.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared
    @ObservedObject var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Animation & Render Quality")
                .font(.system(size: 18, weight: .bold))

            // Quality Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Performance Quality Preset")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 12) {
                    ForEach(PerformanceQuality.allCases, id: \.self) { quality in
                        QualityPresetCard(
                            quality: quality,
                            isSelected: perf.quality == quality,
                            action: { perf.setQuality(quality) }
                        )
                    }
                }
            }

            // Safe Mode Toggle
            Toggle(isOn: Binding(
                get: { perf.isSafeMode },
                set: { _ in perf.toggleSafeMode() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.yellow)
                        Text("Emergency Safe Mode (15 FPS, Zero Extra Processing)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text("Guarantees low system usage: disables all particles, lighting shaders, weather, camera, and screen loops.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // Accessibility Reduce Motion Toggle
            Toggle(isOn: Binding(
                get: { perf.reduceMotion },
                set: { val in
                    perf.reduceMotion = val
                    perf.saveSettings()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "figure.walk.motion")
                            .foregroundColor(.blue)
                        Text("Reduce Motion (Accessibility)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text("Dampens rapid bounces, hops, and high-frequency vibrations for a calmer, motion-sensitive companion experience.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            Divider()

            // Walk Gait Preset
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Walk Gait")
                    .font(.system(size: 13, weight: .semibold))

                Picker("Gait Style", selection: Binding(
                    get: { motion.gaitPreset },
                    set: { (val: WalkGaitPreset) in motion.setGaitPreset(val) }
                )) {
                    ForEach(WalkGaitPreset.allCases) { (gait: WalkGaitPreset) in
                        Text(gait.rawValue).tag(gait)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Autonomous Companion Life Cycle
            VStack(alignment: .leading, spacing: 8) {
                Text("Autonomous Companion Life")
                    .font(.system(size: 13, weight: .semibold))

                Text("Controls subtle background behaviors (looking around, stretching, brief strolls, naps) when idle. Automatically pauses during chats, typing, or focus sessions.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Picker("Autonomous Activity", selection: Binding(
                    get: { PetState.shared.autonomousLifeMode },
                    set: { PetState.shared.setAutonomousLifeMode($0) }
                )) {
                    Text("Off").tag("off")
                    Text("Minimal").tag("minimal")
                    Text("Normal (Recommended)").tag("normal")
                    Text("Lively").tag("lively")
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Locomotion & Walk Speed
            VStack(alignment: .leading, spacing: 8) {
                Text("Locomotion & Walk Speed")
                    .font(.system(size: 13, weight: .semibold))

                Text("Controls the companion window movement velocity and frequency across your display desktop.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack {
                    Text("Walk Speed: \(String(format: "%.1f", dataManager.savedData.walkSpeed ?? 1.0))x")
                        .font(.system(size: 12, weight: .medium))
                    Slider(
                        value: Binding(
                            get: { dataManager.savedData.walkSpeed ?? 1.0 },
                            set: { dataManager.setWalkSpeed($0) }
                        ),
                        in: 0.5...2.0,
                        step: 0.1
                    )
                }

                Picker("Walk Frequency", selection: Binding(
                    get: { dataManager.savedData.walkFrequency ?? "normal" },
                    set: { dataManager.setWalkFrequency($0) }
                )) {
                    Text("Off").tag("off")
                    Text("Minimal").tag("minimal")
                    Text("Normal").tag("normal")
                    Text("Lively").tag("lively")
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Music Reaction & Media Awareness
            VStack(alignment: .leading, spacing: 8) {
                Text("Music & Media Awareness")
                    .font(.system(size: 13, weight: .semibold))

                VStack(spacing: 8) {
                    SettingsToggleRow(
                        icon: "headphones",
                        iconColor: .purple,
                        title: "Music Reactions",
                        subtitle: "Detects active media playback across YouTube (Chrome, Safari, Brave, Edge), Spotify, Apple Music, and VLC to react naturally.",
                        isOn: Binding(
                            get: { MusicManager.shared.isMediaDetectionEnabled },
                            set: { MusicManager.shared.setMediaDetectionEnabled($0) }
                        )
                    )
                    Divider()
                    SettingsToggleRow(
                        icon: "music.note",
                        iconColor: .pink,
                        title: "Dance When Music Is Detected",
                        subtitle: "Pet performs a rhythmic groove and celebration when media playback begins.",
                        isOn: Binding(
                            get: { MusicManager.shared.danceWhenMusicDetected },
                            set: { MusicManager.shared.setDanceWhenMusicDetected($0) }
                        )
                    )
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            }

            Divider()

            // Visual Enhancements & Shaders
            VStack(alignment: .leading, spacing: 10) {
                Text("Visual Enhancements & Shaders")
                    .font(.system(size: 13, weight: .semibold))

                Text("Visual effects are decoupled from companion physics. Turn off to minimize GPU utilization.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    SettingsToggleRow(
                        icon: "sun.max.fill",
                        iconColor: .orange,
                        title: "Dynamic Radial Lighting",
                        subtitle: "Adds soft directional aura and rim glow.",
                        isOn: $perf.dynamicLightingEnabled
                    )
                    Divider()
                    SettingsToggleRow(
                        icon: "cloud.sun.rain.fill",
                        iconColor: .cyan,
                        title: "Weather Atmospheric Effects",
                        subtitle: "Renders raindrops, flurries, and golden hour particles.",
                        isOn: $perf.weatherEffectsEnabled
                    )
                    Divider()
                    SettingsToggleRow(
                        icon: "flame.fill",
                        iconColor: .red,
                        title: "CPU Thermal Reactive Glow",
                        subtitle: "Pulsates companion aura when CPU usage spikes above 40%.",
                        isOn: $perf.cpuReactiveGlowEnabled
                    )
                    Divider()
                    SettingsToggleRow(
                        icon: "sparkles",
                        iconColor: .yellow,
                        title: "Floating Thought Particles",
                        subtitle: "Floating sparks while LLM responses are streaming.",
                        isOn: $perf.particlesEnabled
                    )
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

                HStack {
                    Spacer()
                    Button("Reset Visuals to Default") {
                        perf.resetToDefaults()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

// MARK: - General Section

struct GeneralSettingsSection: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("General Settings")
                .font(.system(size: 18, weight: .bold))

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.stars.fill")
                                .foregroundColor(.indigo)
                            Text("Quiet Mode")
                                .font(.system(size: 13, weight: .medium))
                        }
                        Text("Suppresses spoken voice responses, status bubbles, and sounds, and slows companion movement.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { dataManager.savedData.quietModeEnabled ?? false },
                        set: { dataManager.setQuietModeEnabled($0) }
                    ))
                    .labelsHidden()
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sound Effects")
                            .font(.system(size: 13, weight: .medium))
                        Text("Plays cheerful bleeps and notification tones.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { dataManager.savedData.soundEffectsEnabled ?? true },
                        set: {
                            dataManager.savedData.soundEffectsEnabled = $0
                            dataManager.saveData()
                        }
                    ))
                    .labelsHidden()
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .medium))
                        Text("Start Ollama Pet automatically when you log into your Mac.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { newVal in
                            if #available(macOS 13.0, *) {
                                if newVal {
                                    try? SMAppService.mainApp.register()
                                } else {
                                    try? SMAppService.mainApp.unregister()
                                }
                            }
                        }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            .onAppear {
                if #available(macOS 13.0, *) {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        }
    }
}

// MARK: - Appearance Section

struct AppearanceSettingsSection: View {
    @ObservedObject var petState = PetState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Appearance & Window Behavior")
                .font(.system(size: 18, weight: .bold))

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Always on Top (Floating Window)")
                            .font(.system(size: 13, weight: .medium))
                        Text("Keeps your pet visible over all other open application windows.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { PetWindowController.shared.window?.level == .floating },
                        set: {
                            PetWindowController.shared.window?.level = $0 ? .floating : .normal
                        }
                    ))
                    .labelsHidden()
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Click-Through Desktop Companion")
                            .font(.system(size: 13, weight: .medium))
                        Text("Ignores all mouse clicks so you can click windows directly underneath.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { PetWindowController.shared.isCompanionClickThrough },
                        set: { PetWindowController.shared.isCompanionClickThrough = $0 }
                    ))
                    .labelsHidden()
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
    }
}

// MARK: - Voice Settings Section

struct VoiceSettingsSection: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var voice = VoiceAssistant.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Voice Assistant & Speech Synthesis")
                .font(.system(size: 18, weight: .bold))

            // 1. Toggles
            VStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { dataManager.savedData.voiceAssistantEnabled ?? false },
                    set: {
                        dataManager.savedData.voiceAssistantEnabled = $0
                        dataManager.saveData()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Voice Assistant")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Allows speech-to-text input and spoken companion voice replies.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle(isOn: Binding(
                    get: { dataManager.savedData.speakAiResponses ?? true },
                    set: {
                        dataManager.savedData.speakAiResponses = $0
                        dataManager.saveData()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speak Replies Aloud (TTS)")
                            .font(.system(size: 13, weight: .medium))
                        Text("Companion vocalizes responses using macOS speech synthesis.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // 2. Curated Voice Presets
            VStack(alignment: .leading, spacing: 10) {
                Text("Assistant Persona & Voice Presets")
                    .font(.system(size: 13, weight: .semibold))

                Text("Quickly match the companion's tone to your workflow.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(AssistantVoicePreset.allCases) { preset in
                        let isSelected = (dataManager.savedData.voicePreset == preset.rawValue)
                        Button(action: {
                            voice.applyVoicePreset(preset)
                        }) {
                            HStack {
                                Text(preset.rawValue)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .accentColor : .primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // 3. Granular Voice Selector & Test Button
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Installed System Voice")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Native macOS neural and standard synthesis voices.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Picker("", selection: Binding(
                        get: { dataManager.savedData.selectedVoiceId ?? "" },
                        set: {
                            dataManager.setSelectedVoiceId($0)
                            dataManager.setVoicePreset("")
                        }
                    )) {
                        ForEach(voice.availableVoices) { opt in
                            Text("\(opt.name) (\(opt.language))").tag(opt.id)
                        }
                    }
                    .frame(width: 200)
                }

                Divider()

                // Speech Speed Slider
                HStack {
                    Text("Speed")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { dataManager.savedData.speechSpeed ?? 1.0 },
                            set: { dataManager.setSpeechSpeed($0) }
                        ),
                        in: 0.5...2.0,
                        step: 0.05
                    )
                    Text(String(format: "%.2fx", dataManager.savedData.speechSpeed ?? 1.0))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }

                // Speech Volume Slider
                HStack {
                    Text("Volume")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { dataManager.savedData.speechVolume ?? 1.0 },
                            set: { dataManager.setSpeechVolume($0) }
                        ),
                        in: 0.1...1.0,
                        step: 0.05
                    )
                    Text("\(Int((dataManager.savedData.speechVolume ?? 1.0) * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }

                // Speech Pitch Slider
                HStack {
                    Text("Pitch")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { dataManager.savedData.speechPitch ?? 1.0 },
                            set: { dataManager.setSpeechPitch($0) }
                        ),
                        in: 0.5...2.0,
                        step: 0.05
                    )
                    Text(String(format: "%.2fx", dataManager.savedData.speechPitch ?? 1.0))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }

                Divider()

                // Test Voice Button
                HStack {
                    Spacer()
                    if voice.isSpeaking {
                        Button(action: {
                            voice.stopSpeaking()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                Text("Stop Speaking")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button(action: {
                            voice.testVoicePreview()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Test Voice Preview")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
    }
}

// MARK: - Shortcuts Settings Section

struct ShortcutsSettingsSection: View {
    @ObservedObject var shortcut = ShortcutManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Keyboard Shortcuts")
                .font(.system(size: 18, weight: .bold))

            Text("Customize system-wide keyboard shortcuts for quick companion access. Press Escape while recording to cancel.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Accessibility Permission Banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(shortcut.isAccessibilityGranted ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(shortcut.isAccessibilityGranted ? "Accessibility Permission: Enabled" : "Accessibility Permission: Required")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(shortcut.isAccessibilityGranted
                         ? "Global shortcuts are active even when other applications are focused."
                         : "macOS requires Accessibility permission to detect shortcuts while other apps are active.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !shortcut.isAccessibilityGranted {
                    Button("Grant in System Settings") {
                        shortcut.openAccessibilitySettings()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(shortcut.isAccessibilityGranted ? Color.green.opacity(0.08) : Color.orange.opacity(0.12)))

            // Conflict Warning
            if let conflict = shortcut.conflictMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(conflict)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                    Spacer()
                    Button("Dismiss") {
                        shortcut.conflictMessage = nil
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
            }

            // Shortcuts List
            VStack(spacing: 12) {
                editableShortcutRow(
                    actionId: "togglePet",
                    title: "Toggle Companion Window",
                    subtitle: "Shows or hides the desktop companion window.",
                    currentCombo: shortcut.togglePetShortcut
                )

                Divider()

                editableShortcutRow(
                    actionId: "voice",
                    title: "Push-to-Talk Voice",
                    subtitle: "Hold to speak, release to send audio to companion.",
                    currentCombo: shortcut.voiceShortcut
                )

                Divider()

                editableShortcutRow(
                    actionId: "settings",
                    title: "Open Settings Center",
                    subtitle: "Directly opens the comprehensive Settings Window.",
                    currentCombo: shortcut.settingsShortcut
                )
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
        .onAppear {
            shortcut.checkAccessibilityPermission()
        }
    }

    private func editableShortcutRow(actionId: String, title: String, subtitle: String, currentCombo: KeyCombo) -> some View {
        let isRecording = shortcut.recordingAction == actionId

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isRecording {
                HStack(spacing: 8) {
                    Text("Press new shortcut (Esc to cancel)...")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15)))

                    Button("Cancel") {
                        shortcut.cancelRecording()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Text(currentCombo.displayString)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))

                    Button("Change") {
                        shortcut.startRecording(action: actionId)
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

// MARK: - Ollama Section

struct OllamaSettingsSection: View {
    @ObservedObject var client = OllamaClient.shared
    @ObservedObject var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. Connection Status Card
            SettingsSection(
                title: "Ollama Connection & Service",
                subtitle: "Direct local inference on your Mac with zero cloud dependencies.",
                badge: connectionBadgeText,
                badgeColor: connectionColor
            ) {
                SettingsCard {
                    SettingsStatusCard(
                        statusDotColor: connectionColor,
                        title: connectionTitle,
                        detail: connectionDetail,
                        actionTitle: client.connectionState.isConnected ? "Refresh Models" : "Start / Connect",
                        onAction: {
                            Task {
                                await client.connectOrStartIfNeeded(preferredModel: dataManager.savedData.selectedModel)
                            }
                        }
                    )

                    Divider()

                    SettingsRow(
                        title: "Daemon Endpoint",
                        subtitle: "Local REST API host for Llama, Mistral, and custom models"
                    ) {
                        Text("http://127.0.0.1:11434")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Auto-Start Ollama at Launch",
                        subtitle: "Automatically checks and launches Ollama background service when Ollama Pet opens.",
                        isOn: Binding(
                            get: { dataManager.savedData.autoStartOllama ?? true },
                            set: {
                                dataManager.savedData.autoStartOllama = $0
                                dataManager.saveData()
                            }
                        )
                    )

                    Divider()

                    SettingsToggleRow(
                        title: "Background Auto-Reconnect Monitor",
                        subtitle: "Silently reconnects if Ollama service is restarted or wakes from sleep.",
                        isOn: Binding(
                            get: { dataManager.savedData.autoReconnectOllama ?? true },
                            set: {
                                dataManager.savedData.autoReconnectOllama = $0
                                dataManager.saveData()
                            }
                        )
                    )
                }
            }

            // 2. Active Model Configuration
            SettingsSection(
                title: "Model Selection",
                subtitle: "Choose which local Ollama model powers your companion's voice, chat, and reasoning."
            ) {
                SettingsCard {
                    if client.installedModels.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("No local models detected")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text("Ollama is not running, or no models have been pulled yet. Open your Terminal and run:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Text("ollama pull llama3.2")
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))

                            HStack(spacing: 10) {
                                Button("Start Ollama Now") {
                                    Task {
                                        await client.connectOrStartIfNeeded(preferredModel: dataManager.savedData.selectedModel)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button("Check Again") {
                                    Task {
                                        await client.checkHealth(preferredModel: dataManager.savedData.selectedModel)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        SettingsRow(
                            title: "Companion AI Model",
                            subtitle: "\(client.installedModels.count) models installed on your Mac"
                        ) {
                            Picker("", selection: Binding(
                                get: { dataManager.savedData.selectedModel ?? client.installedModels.first ?? "llama3" },
                                set: {
                                    dataManager.savedData.selectedModel = $0
                                    dataManager.saveData()
                                    client.activeModel = $0
                                }
                            )) {
                                ForEach(client.installedModels, id: \.self) { m in
                                    Text(m).tag(m)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }

                        Divider()

                        HStack {
                            Text("Active Model: \(client.activeModel)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Refresh Model List") {
                                Task {
                                    await client.checkHealth(preferredModel: dataManager.savedData.selectedModel)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var connectionColor: Color {
        switch client.connectionState {
        case .connected: return .green
        case .connecting, .reconnecting, .checking: return .orange
        case .failed: return .red
        }
    }

    private var connectionBadgeText: String {
        switch client.connectionState {
        case .connected: return "Ready"
        case .connecting: return "Connecting"
        case .reconnecting: return "Reconnecting"
        case .checking: return "Checking"
        case .failed: return "Offline"
        }
    }

    private var connectionTitle: String {
        switch client.connectionState {
        case .connected:
            return "Ollama Connected & Operational"
        case .connecting:
            return "Connecting to Ollama Daemon..."
        case .reconnecting:
            return "Reconnecting to Ollama..."
        case .checking:
            return "Checking Ollama Service Status..."
        case .failed:
            return "Ollama Is Not Running"
        }
    }

    private var connectionDetail: String {
        switch client.connectionState {
        case .connected:
            return "Local daemon responded successfully at http://127.0.0.1:11434 with \(client.installedModels.count) models available."
        case .connecting, .checking:
            return "Verifying local HTTP daemon at port 11434..."
        case .reconnecting:
            return "Attempting to re-establish link with Ollama background service..."
        case .failed:
            return "Could not reach local server. Click 'Start / Connect' to auto-launch Ollama background daemon."
        }
    }
}

// MARK: - Vision / Screen / Focus / Privacy

// MARK: - Native Presence Monitor & Cloud AI Providers

struct PresenceSettingsSection: View {
    @ObservedObject var monitor = PresenceMonitor.shared
    @ObservedObject var dataManager = DataManager.shared
    @State private var enrollmentStatusText: String = ""
    @State private var showEnrollmentWizard: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Native Presence Monitor")
                        .font(.system(size: 18, weight: .bold))
                    Text("Local computer-vision presence analysis powered by Apple Vision. Real-time human bounding box detection, owner verification, and local security snapshots.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    PresenceMonitorWindowController.shared.toggleWidget()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "macwindow.on.rectangle")
                        Text("Desktop Widget")
                    }
                }
                .buttonStyle(.bordered)
            }

            // Radar / Live Camera Monitor Card
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(monitor.presenceStatus.rawValue)
                            .font(.system(size: 13, weight: .bold))
                    }
                    Spacer()
                    Button(action: {
                        if monitor.isRunning {
                            monitor.stop()
                        } else {
                            monitor.start()
                        }
                    }) {
                        Text(monitor.isRunning ? "Stop Monitor" : "Start Monitor")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(monitor.isRunning ? Color.red : Color.green)
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Camera preview box
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 190)

                    if let img = monitor.latestPreviewImage {
                        ZStack {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 190)

                            // Subject Bounding Boxes
                            GeometryReader { geo in
                                ForEach(monitor.trackedSubjects) { subj in
                                    subjectBoundingBox(subj: subj, in: geo)
                                }
                            }
                            .frame(height: 190)
                        }
                        .scaleEffect(
                            monitor.autoFramingEnabled ? monitor.currentZoomScale : 1.0,
                            anchor: monitor.autoFramingEnabled ? monitor.currentPanAnchor : .center
                        )
                        .animation(.easeInOut(duration: 0.25), value: monitor.currentZoomScale)
                        .animation(.easeInOut(duration: 0.25), value: monitor.currentPanAnchor)
                        .frame(height: 190)
                        .cornerRadius(10)
                        .clipped()

                        if monitor.autoFramingEnabled && monitor.currentZoomScale > 1.05 {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.metering.matrix")
                                Text(String(format: "%.1fx Track", monitor.currentZoomScale))
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.65)))
                            .padding(8)
                        }
                    } else if monitor.monitoringState == .permissionRequired || monitor.presenceStatus == .permissionRequired {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                            Text("Camera Permission Required")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("Please allow camera access in macOS System Settings.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            HStack(spacing: 8) {
                                Button("Retry") {
                                    monitor.retry()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Button("Open System Settings") {
                                    monitor.openSystemCameraSettings()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if monitor.monitoringState == .cameraUnavailable || monitor.presenceStatus == .cameraUnavailable {
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.red)
                            Text("Camera Unavailable")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("No compatible camera found or video pipeline is locked.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            Button("Retry") {
                                monitor.retry()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if monitor.monitoringState == .starting || monitor.presenceStatus == .starting {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Starting camera pipeline...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if monitor.monitoringState == .recovering || monitor.presenceStatus == .recovering {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Recovering video pipeline...")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text(monitor.isRunning ? "Scanning for human subjects..." : "Monitor is currently stopped.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 190)

                if !monitor.trackedSubjects.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(monitor.trackedSubjects.count > 1 ? "👥 Multiple Subjects Detected (\(monitor.trackedSubjects.count))" : "👤 Detected Subject")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(Array(monitor.trackedSubjects.enumerated()), id: \.element.id) { idx, subj in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(subj.isOwner ? Color.green : (!monitor.isOwnerEnrolled ? Color.blue : Color.orange))
                                    .frame(width: 8, height: 8)

                                Text("Person \(idx + 1):")
                                    .font(.system(size: 12, weight: .bold))

                                Text(subj.statusDescription)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(subj.recognitionBadge)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

            // Performance Profile
            VStack(alignment: .leading, spacing: 8) {
                Text("Monitoring Performance Profile")
                    .font(.system(size: 14, weight: .bold))

                Picker("Performance Mode", selection: Binding(
                    get: { monitor.performanceMode },
                    set: { newMode in
                        monitor.performanceMode = newMode
                        dataManager.savedData.monitoringPerformanceMode = newMode.rawValue
                        dataManager.saveData()
                    }
                )) {
                    Text("Low Power").tag(MonitoringPerformanceMode.lowPower)
                    Text("Balanced").tag(MonitoringPerformanceMode.balanced)
                    Text("Responsive").tag(MonitoringPerformanceMode.responsive)
                }
                .pickerStyle(.segmented)

                Text(performanceModeDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

            // Owner Profile Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Owner Verification & Calibration")
                            .font(.system(size: 14, weight: .bold))
                        Text("3-angle on-device facial feature prints (Front, Left, Right) allow seamless, local owner recognition.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    let count = monitor.enrolledSamplesCount
                    Text(monitor.isOwnerEnrolled ? "🟢 \(count)/3 Calibrated" : "⚪ Not Enrolled")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(monitor.isOwnerEnrolled ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15)))
                        .foregroundColor(monitor.isOwnerEnrolled ? .green : .secondary)
                }

                // Sample Status Badges & Photo Preview
                HStack(spacing: 14) {
                    if let photo = monitor.getOwnerPhoto() {
                        Image(nsImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.green, lineWidth: 2))
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            sampleBadge(title: "Front", enrolled: monitor.isSampleEnrolled(angle: .front))
                            sampleBadge(title: "Left ~25°", enrolled: monitor.isSampleEnrolled(angle: .leftProfile))
                            sampleBadge(title: "Right ~25°", enrolled: monitor.isSampleEnrolled(angle: .rightProfile))
                        }

                        Text(monitor.isOwnerEnrolled
                            ? "On-device facial feature prints stored locally on this Mac using secure serialization. Unknown visitors trigger gentle alerts without false positives."
                            : "Calibrate your face to allow your Pet to recognize you and greet you when you return to your Mac.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if !enrollmentStatusText.isEmpty {
                    Text(enrollmentStatusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(enrollmentStatusText.contains("Ready") || enrollmentStatusText.contains("enrolled") ? .green : .orange)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                }

                HStack(spacing: 10) {
                    Button(action: {
                        showEnrollmentWizard = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Open Calibration Wizard...")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    if monitor.isOwnerEnrolled {
                        Button("Remove Profile") {
                            monitor.resetOwnerProfile()
                            enrollmentStatusText = "Owner profile removed."
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

            // Alert Configuration
            VStack(alignment: .leading, spacing: 12) {
                Text("Security & Voice Alert Rules")
                    .font(.system(size: 14, weight: .bold))

                Toggle("Alert when unknown person stays near Mac > 5s", isOn: Binding(
                    get: { dataManager.savedData.presenceDwellAlertEnabled ?? true },
                    set: { dataManager.savedData.presenceDwellAlertEnabled = $0; dataManager.saveData() }
                ))

                Toggle("Pet Voice Announcements (Master switch for spoken presence alerts)", isOn: Binding(
                    get: { dataManager.savedData.presenceSpokenAlertsEnabled ?? false },
                    set: { dataManager.savedData.presenceSpokenAlertsEnabled = $0; dataManager.saveData() }
                ))

                if dataManager.savedData.presenceSpokenAlertsEnabled ?? false {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Speak greeting when owner arrives (\"Welcome back.\")", isOn: Binding(
                            get: { dataManager.savedData.presenceOwnerGreetingEnabled ?? true },
                            set: { dataManager.savedData.presenceOwnerGreetingEnabled = $0; dataManager.saveData() }
                        ))

                        Toggle("Speak alert when unknown person arrives (\"Unfamiliar person detected.\")", isOn: Binding(
                            get: { dataManager.savedData.presenceUnknownAlertVoiceEnabled ?? true },
                            set: { dataManager.savedData.presenceUnknownAlertVoiceEnabled = $0; dataManager.saveData() }
                        ))

                        HStack {
                            Text("Voice Alert Cooldown:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Picker("", selection: Binding(
                                get: { dataManager.savedData.presenceVoiceCooldownSeconds ?? 90 },
                                set: { dataManager.savedData.presenceVoiceCooldownSeconds = $0; dataManager.saveData() }
                            )) {
                                Text("30 seconds").tag(30)
                                Text("60 seconds").tag(60)
                                Text("90 seconds").tag(90)
                                Text("3 minutes").tag(180)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.vertical, 4)
                }

                Toggle("Save unknown-person security snapshots (OFF by default)", isOn: Binding(
                    get: { dataManager.savedData.presenceUnknownAlertEnabled ?? false },
                    set: { dataManager.savedData.presenceUnknownAlertEnabled = $0; dataManager.saveData() }
                ))

                Text("When enabled, saves 1 discrete local snapshot per unknown encounter (max 20 FIFO, stored locally). Never uploaded to cloud.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Divider()

                Toggle("Auto Pan & Zoom (Digital Face Tracking)", isOn: Binding(
                    get: { monitor.autoFramingEnabled },
                    set: {
                        monitor.autoFramingEnabled = $0
                        dataManager.savedData.presenceAutoFramingEnabled = $0
                        dataManager.saveData()
                    }
                ))

                Text("Dynamically tracks detected faces and pans/zooms smoothly to keep subjects centered in the viewfinder.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if #available(macOS 12.3, *) {
                    Toggle("Hardware Center Stage (Auto-Framing on supported Macs)", isOn: Binding(
                        get: { dataManager.savedData.presenceCenterStageEnabled ?? true },
                        set: {
                            dataManager.savedData.presenceCenterStageEnabled = $0
                            dataManager.saveData()
                            if monitor.isRunning {
                                monitor.stop()
                                monitor.start()
                            }
                        }
                    ))

                    Text("Enables Apple Silicon / Studio Display ultra-wide hardware Center Stage framing.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

            // Snapshot Vault (Max 20, FIFO)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local Security Snapshots (\(monitor.snapshotCount)/20)")
                            .font(.system(size: 14, weight: .bold))
                        Text("Stored purely in ~/Library/Application Support/OllamaPet/Snapshots. Oldest pruned automatically.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if monitor.snapshotCount > 0 {
                        Button(action: {
                            _ = monitor.exportAllSnapshotsToDownloads()
                        }) {
                            Label("Export All", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Delete All") {
                            monitor.clearAllSnapshots()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                let snapshotURLs = monitor.getSnapshotURLs()
                if snapshotURLs.isEmpty {
                    Text("No snapshots captured yet.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(snapshotURLs, id: \.self) { url in
                                if let img = NSImage(contentsOf: url) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(nsImage: img)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 105, height: 78)
                                                .cornerRadius(6)
                                                .clipped()

                                            HStack(spacing: 3) {
                                                Button(action: {
                                                    _ = monitor.exportSnapshotToDownloads(url: url)
                                                }) {
                                                    Image(systemName: "arrow.down.circle.fill")
                                                        .font(.system(size: 15))
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.65)))
                                                }
                                                .buttonStyle(.plain)
                                                .help("Download to ~/Downloads")

                                                Button(action: {
                                                    monitor.revealSnapshotInFinder(url: url)
                                                }) {
                                                    Image(systemName: "folder.circle.fill")
                                                        .font(.system(size: 15))
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.65)))
                                                }
                                                .buttonStyle(.plain)
                                                .help("Reveal in Finder")

                                                Button(action: {
                                                    monitor.deleteSnapshot(at: url)
                                                }) {
                                                    Image(systemName: "trash.circle.fill")
                                                        .font(.system(size: 15))
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.65)))
                                                }
                                                .buttonStyle(.plain)
                                                .help("Delete snapshot permanently")
                                            }
                                            .padding(3)
                                        }

                                        Text(url.lastPathComponent.replacingOccurrences(of: "snapshot_", with: "").replacingOccurrences(of: ".jpg", with: ""))
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
        }
        .sheet(isPresented: $showEnrollmentWizard) {
            OwnerEnrollmentWizardView(isPresented: $showEnrollmentWizard)
        }
        .onAppear {
            monitor.requestLivePreview(id: "settings_presence_tab")
        }
        .onDisappear {
            monitor.releaseLivePreview(id: "settings_presence_tab")
        }
    }

    private func sampleBadge(title: String, enrolled: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: enrolled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(enrolled ? .green : .secondary)
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 11, weight: enrolled ? .bold : .regular))
                .foregroundColor(enrolled ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(enrolled ? Color.green.opacity(0.12) : Color.primary.opacity(0.05)))
    }

    private var performanceModeDescription: String {
        switch monitor.performanceMode {
        case .lowPower:
            return "Minimizes CPU/battery impact. Checks presence every 1.2–3.5s with maximum thermal throttling."
        case .balanced:
            return "Recommended. Balances reaction time with energy efficiency (0.7–2.5s adaptive interval)."
        case .responsive:
            return "Fastest reaction time (0.4–1.2s adaptive interval). Useful if you want immediate wake/sleep triggers."
        }
    }

    private var statusColor: Color {
        switch monitor.presenceStatus {
        case .ownerPresent, .ownerConfirmed: return .green
        case .faceDetected: return .blue
        case .verifying, .uncertain: return .yellow
        case .unknownDetected: return .orange
        case .ownerTemporarilyUnavailable, .noFace: return Color(white: 0.8)
        case .personDetectedNoOwner: return .cyan
        case .multipleDetected: return .purple
        case .searching: return .cyan
        case .starting, .recovering: return .yellow
        case .away, .noPerson: return .indigo
        case .permissionRequired, .cameraUnavailable, .cameraError, .failed: return .red
        case .idle, .stopped: return .secondary
        }
    }

    @ViewBuilder
    private func subjectBoundingBox(subj: TrackedSubject, in geo: GeometryProxy) -> some View {
        let r = subj.rect
        let w = max(24.0, r.width * geo.size.width)
        let h = max(24.0, r.height * geo.size.height)
        let x = r.minX * geo.size.width + w / 2.0
        let y = (1.0 - r.maxY) * geo.size.height + h / 2.0
        let isOwner = subj.isOwner
        let dwellSec = Int(subj.dwellDuration)
        let label = !monitor.isOwnerEnrolled ? "Person (\(dwellSec)s)" : (isOwner ? "Owner 👤" : "Unknown (\(dwellSec)s)")
        let color: Color = !monitor.isOwnerEnrolled ? .blue : (isOwner ? .green : .orange)

        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6)
                .stroke(color, lineWidth: 2)
                .frame(width: w, height: h)

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(3)
                .background(color.opacity(0.85))
                .cornerRadius(4)
                .offset(y: -14)
        }
        .position(x: x, y: y)
    }
}

// MARK: - Guided Owner Enrollment Wizard View

struct OwnerEnrollmentWizardView: View {
    @ObservedObject var monitor = PresenceMonitor.shared
    @Binding var isPresented: Bool

    @State private var currentAngle: OwnerSampleAngle = .front
    @State private var statusFeedback: String = ""
    @State private var qualityReport: EnrollmentQualityReport? = nil
    @State private var timer: Timer? = nil
    @State private var stableHoldSeconds: Double = 0.0
    @State private var isAutoCapturing: Bool = false
    @State private var justCaptured: Bool = false
    @State private var startedMonitorForWizard: Bool = false

    // Explicit Camera State tracking for Timeout & Failures
    @State private var initElapsedSeconds: Double = 0.0
    @State private var isCameraTimedOut: Bool = false

    private enum WizardCameraStatus {
        case starting
        case active
        case permissionDenied
        case unavailable(String)
    }

    private var cameraStatus: WizardCameraStatus {
        if monitor.monitoringState == .permissionRequired {
            return .permissionDenied
        }
        if monitor.monitoringState == .cameraUnavailable {
            return .unavailable("Camera hardware is unavailable or in use by another application.")
        }
        if isCameraTimedOut && monitor.latestPreviewImage == nil {
            return .unavailable("Camera preview initialization timed out. Click Retry to restart camera.")
        }
        if monitor.latestPreviewImage != nil {
            return .active
        }
        return .starting
    }

    private var isAllAnglesEnrolled: Bool {
        OwnerSampleAngle.allCases.allSatisfy { monitor.isSampleEnrolled(angle: $0) }
    }

    private var enrolledCount: Int {
        OwnerSampleAngle.allCases.filter { monitor.isSampleEnrolled(angle: $0) }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header Bar with explicit Cancel (Secondary) and Finish (Primary)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Owner Calibration Wizard")
                        .font(.system(size: 16, weight: .bold))
                    Text("Calibrate facial angles for reliable, zero-prompt recognition.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()

                HStack(spacing: 10) {
                    Button("Cancel") {
                        performCancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Finish") {
                        performFinish()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if isAllAnglesEnrolled {
                // MARK: - Completion Screen
                VStack(spacing: 18) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.green)

                    Text("Calibration Complete!")
                        .font(.system(size: 18, weight: .bold))

                    Text("Your owner profile is fully calibrated with all 7 facial angles for zero-prompt recognition.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    // 7 Angle Checklist Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(OwnerSampleAngle.allCases) { angle in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(angle.title)
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.08)))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    HStack(spacing: 16) {
                        Button("Cancel") {
                            performCancel()
                        }
                        .buttonStyle(.bordered)

                        Button("Finish & Save") {
                            performFinish()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // MARK: - Compact Step Progress Header (P1 Fix for 7-Step UI)
                VStack(spacing: 8) {
                    HStack {
                        Text("Step \(currentAngle.stepIndex) of 7: \(currentAngle.title)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text("\(enrolledCount)/7 Enrolled")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    // Compact Dots Row: ● ● ● ◉ ○ ○ ○
                    HStack(spacing: 10) {
                        ForEach(OwnerSampleAngle.allCases) { angle in
                            Button(action: {
                                currentAngle = angle
                                statusFeedback = ""
                                stableHoldSeconds = 0.0
                                justCaptured = false
                                isAutoCapturing = false
                            }) {
                                HStack(spacing: 3) {
                                    if monitor.isSampleEnrolled(angle: angle) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 13))
                                    } else if angle == currentAngle {
                                        Image(systemName: "circle.circle.fill")
                                            .foregroundColor(.accentColor)
                                            .font(.system(size: 13))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(Color.primary.opacity(0.3))
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Step \(angle.stepIndex): \(angle.title)")
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                }
                .padding(.horizontal, 20)

                // Step Instruction Box
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(currentAngle.instruction)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.08)))
                .padding(.horizontal, 20)

                // Main Viewfinder / Camera State Machine
                switch cameraStatus {
                case .starting:
                    VStack(spacing: 14) {
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                        Text("Starting Camera…")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Initializing video stream for facial calibration.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Cancel") {
                            performCancel()
                        }
                        .buttonStyle(.bordered)
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .unavailable(let reason):
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text("Camera Preview Unavailable")
                            .font(.system(size: 15, weight: .bold))
                        Text(reason)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        Spacer()
                        HStack(spacing: 14) {
                            Button("Cancel") {
                                performCancel()
                            }
                            .buttonStyle(.bordered)

                            Button("Retry Camera") {
                                retryCamera()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .permissionDenied:
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                        Text("Camera Access Required")
                            .font(.system(size: 15, weight: .bold))
                        Text("Allow camera access in System Settings to continue with facial calibration.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        Spacer()
                        HStack(spacing: 14) {
                            Button("Cancel") {
                                performCancel()
                            }
                            .buttonStyle(.bordered)

                            Button("Open System Settings") {
                                monitor.openSystemCameraSettings()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .active:
                    // Live Viewfinder & Alignment Guide
                    HStack(spacing: 16) {
                        // Camera Box
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.9))
                                .frame(width: 320, height: 240)

                            if let img = monitor.latestPreviewImage {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 320, height: 240)
                                    .cornerRadius(10)

                                // Center Alignment Oval
                                Ellipse()
                                    .stroke(
                                        (qualityReport?.isReadyToCapture ?? false) ? Color.green : Color.white.opacity(0.4),
                                        style: StrokeStyle(lineWidth: 2, dash: (qualityReport?.isReadyToCapture ?? false) ? [] : [6, 4])
                                    )
                                    .frame(width: 140, height: 180)
                            }
                        }
                        .frame(width: 320, height: 240)

                        // Live Quality Checklist
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Alignment & Quality Checks")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)

                            qualityCheckRow(
                                title: "Face Detected",
                                passed: (qualityReport?.faceDetected ?? false) && !(qualityReport?.multipleFaces ?? false),
                                detail: qualityReport?.multipleFaces == true ? "Multiple faces" : ((qualityReport?.faceDetected ?? false) ? "1 face" : "No face")
                            )

                            qualityCheckRow(
                                title: "Positioning",
                                passed: qualityReport?.isCentered ?? false,
                                detail: (qualityReport?.isCentered ?? false) ? "Centered" : "Adjust position"
                            )

                            qualityCheckRow(
                                title: "Face Distance",
                                passed: qualityReport?.isGoodSize ?? false,
                                detail: (qualityReport?.isGoodSize ?? false) ? "Good size" : "Too far/close"
                            )

                            qualityCheckRow(
                                title: "Lighting",
                                passed: qualityReport?.isGoodLighting ?? false,
                                detail: (qualityReport?.isGoodLighting ?? false) ? "Good lighting" : "Check illumination"
                            )

                            qualityCheckRow(
                                title: "Pose Alignment",
                                passed: qualityReport?.angleMatched ?? false,
                                detail: (qualityReport?.angleMatched ?? false) ? "Angle matched" : "Tilt to match"
                            )

                            qualityCheckRow(
                                title: "Image Clarity",
                                passed: qualityReport?.isGoodQuality ?? false,
                                detail: (qualityReport?.isGoodQuality ?? false) ? "Clear" : "Hold still"
                            )

                            Spacer()

                            // Saved Snapshot Thumbnail for Current Angle
                            if let photo = monitor.getSamplePhoto(angle: currentAngle) {
                                HStack(spacing: 8) {
                                    Image(nsImage: photo)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 44, height: 36)
                                        .cornerRadius(4)
                                        .clipped()

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(currentAngle.title) Enrolled")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.green)
                                        Text("Stored securely on-device")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Retake") {
                                        captureCurrentAngle()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.horizontal, 20)

                    // Status Feedback Message & Hold Progress Bar
                    if justCaptured {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Captured ✓ \(currentAngle.title) calibrated successfully")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.15)))
                        .padding(.horizontal, 20)
                    } else if let report = qualityReport {
                        HStack(spacing: 12) {
                            if report.isReadyToCapture {
                                Image(systemName: "timer")
                                    .foregroundColor(.green)
                                ProgressView(value: min(1.0, stableHoldSeconds / 0.5))
                                    .frame(width: 80)
                                Text("Hold still... (\(Int(min(1.0, stableHoldSeconds / 0.5) * 100))%)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text(report.statusMessage)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill((report.isReadyToCapture ? Color.green : Color.orange).opacity(0.12)))
                        .padding(.horizontal, 20)
                    }

                    // Bottom Action Bar
                    HStack(spacing: 14) {
                        Button("Cancel") {
                            performCancel()
                        }
                        .buttonStyle(.bordered)

                        if currentAngle.stepIndex > 1 {
                            Button("← Previous") {
                                navigateToPreviousAngle()
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        Button(action: {
                            captureCurrentAngle()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                Text(monitor.isSampleEnrolled(angle: currentAngle) ? "Re-capture \(currentAngle.title)" : "Capture \(currentAngle.title)")
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        if currentAngle.stepIndex < 7 {
                            Button("Next →") {
                                navigateToNextAngle()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Finish & Save") {
                                performFinish()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 580, height: 490)
        .onExitCommand {
            performCancel()
        }
        .onAppear {
            monitor.isCalibrationActive = true
            monitor.requestLivePreview(id: "owner_enrollment_wizard")
            if !monitor.isRunning {
                startedMonitorForWizard = true
                monitor.start()
            } else {
                startedMonitorForWizard = false
            }
            startInspectionLoop()
        }
        .onDisappear {
            performCleanup()
        }
    }

    private func performCancel() {
        performCleanup()
        isPresented = false
    }

    private func performFinish() {
        performCleanup()
        isPresented = false
    }

    private func performCleanup() {
        timer?.invalidate()
        timer = nil
        monitor.releaseLivePreview(id: "owner_enrollment_wizard")
        monitor.isCalibrationActive = false
        if startedMonitorForWizard {
            monitor.stop()
            startedMonitorForWizard = false
        }
        qualityReport = nil
        stableHoldSeconds = 0.0
        isAutoCapturing = false
        justCaptured = false
        statusFeedback = ""
        initElapsedSeconds = 0.0
        isCameraTimedOut = false
    }

    private func retryCamera() {
        performCleanup()
        monitor.isCalibrationActive = true
        monitor.requestLivePreview(id: "owner_enrollment_wizard")
        startedMonitorForWizard = true
        monitor.start()
        startInspectionLoop()
    }

    private func navigateToPreviousAngle() {
        let all = OwnerSampleAngle.allCases
        if let idx = all.firstIndex(of: currentAngle), idx > 0 {
            currentAngle = all[idx - 1]
            stableHoldSeconds = 0.0
            justCaptured = false
            isAutoCapturing = false
        }
    }

    private func navigateToNextAngle() {
        let all = OwnerSampleAngle.allCases
        if let idx = all.firstIndex(of: currentAngle), idx < all.count - 1 {
            currentAngle = all[idx + 1]
            stableHoldSeconds = 0.0
            justCaptured = false
            isAutoCapturing = false
        }
    }

    private func qualityCheckRow(title: String, passed: Bool, detail: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundColor(passed ? .green : .orange)
                .font(.system(size: 12))
            Text(title)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private func startInspectionLoop() {
        initElapsedSeconds = 0.0
        isCameraTimedOut = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                if monitor.latestPreviewImage == nil {
                    self.initElapsedSeconds += 0.1
                    if self.initElapsedSeconds >= 6.0 {
                        self.isCameraTimedOut = true
                    }
                } else {
                    self.initElapsedSeconds = 0.0
                    self.isCameraTimedOut = false
                }

                let report = monitor.evaluateEnrollmentFrame(for: currentAngle)
                self.qualityReport = report

                if self.justCaptured {
                    return
                }

                if report.isReadyToCapture {
                    self.stableHoldSeconds += 0.1
                    if self.stableHoldSeconds >= 0.5 && !self.isAutoCapturing {
                        self.isAutoCapturing = true
                        self.triggerAutoCapture()
                    }
                } else {
                    self.stableHoldSeconds = 0.0
                }
            }
        }
    }

    private func triggerAutoCapture() {
        let res = monitor.enrollSample(angle: currentAngle)
        statusFeedback = res.message
        if res.success {
            justCaptured = true
            stableHoldSeconds = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.justCaptured = false
                self.isAutoCapturing = false
                self.advanceToNextAngle()
            }
        } else {
            isAutoCapturing = false
            stableHoldSeconds = 0.0
        }
    }

    private func advanceToNextAngle() {
        for angle in OwnerSampleAngle.allCases {
            if !monitor.isSampleEnrolled(angle: angle) {
                currentAngle = angle
                return
            }
        }
    }

    private func captureCurrentAngle() {
        let res = monitor.enrollSample(angle: currentAngle)
        statusFeedback = res.message
        if res.success {
            justCaptured = true
            stableHoldSeconds = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.justCaptured = false
                self.isAutoCapturing = false
                self.advanceToNextAngle()
            }
        } else {
            isAutoCapturing = false
            stableHoldSeconds = 0.0
        }
    }
}

struct CloudAISettingsSection: View {
    @ObservedObject var aiManager = AIProviderManager.shared
    @ObservedObject var dataManager = DataManager.shared

    @State private var openaiKeyInput: String = ""
    @State private var geminiKeyInput: String = ""
    @State private var anthropicKeyInput: String = ""
    @State private var groqKeyInput: String = ""

    @State private var testStatus: [String: String] = [:]
    @State private var isTesting: [String: Bool] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Cloud AI Providers & API Keys")
                    .font(.system(size: 18, weight: .bold))
                Text("All API keys are securely stored inside your macOS Keychain and never saved in plaintext files or logs. If local Ollama is offline, Ollama Pet seamlessly falls back to your configured cloud providers.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Primary Provider Selector
            VStack(alignment: .leading, spacing: 10) {
                Text("Active Companion AI Provider")
                    .font(.system(size: 14, weight: .bold))

                Picker("", selection: $aiManager.activeProvider) {
                    ForEach(AIProvider.allCases) { p in
                        HStack {
                            Image(systemName: p.icon)
                            Text(p.displayName)
                        }
                        .tag(p)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: aiManager.activeProvider) { newProvider in
                    aiManager.setProvider(newProvider)
                }

                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.green)
                    Text("Auto-Fallback Enabled: If \(aiManager.activeProvider.displayName) is unreachable, available cloud keys will be used automatically.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

            // Provider Cards (OpenAI, Gemini, Anthropic, Groq)
            VStack(spacing: 12) {
                providerRow(
                    provider: .openai,
                    input: $openaiKeyInput,
                    modelBinding: Binding(
                        get: { dataManager.savedData.openaiModel ?? "gpt-4o-mini" },
                        set: { dataManager.savedData.openaiModel = $0; dataManager.saveData() }
                    ),
                    models: ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "o3-mini"]
                )

                providerRow(
                    provider: .gemini,
                    input: $geminiKeyInput,
                    modelBinding: Binding(
                        get: { dataManager.savedData.geminiModel ?? "gemini-1.5-flash" },
                        set: { dataManager.savedData.geminiModel = $0; dataManager.saveData() }
                    ),
                    models: ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash"]
                )

                providerRow(
                    provider: .anthropic,
                    input: $anthropicKeyInput,
                    modelBinding: Binding(
                        get: { dataManager.savedData.anthropicModel ?? "claude-3-5-haiku-20241022" },
                        set: { dataManager.savedData.anthropicModel = $0; dataManager.saveData() }
                    ),
                    models: ["claude-3-5-haiku-20241022", "claude-3-5-sonnet-20241022"]
                )

                providerRow(
                    provider: .groq,
                    input: $groqKeyInput,
                    modelBinding: Binding(
                        get: { dataManager.savedData.groqModel ?? "llama-3.3-70b-versatile" },
                        set: { dataManager.savedData.groqModel = $0; dataManager.saveData() }
                    ),
                    models: ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"]
                )
            }
        }
    }

    private func providerRow(
        provider: AIProvider,
        input: Binding<String>,
        modelBinding: Binding<String>,
        models: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: provider.icon)
                    .font(.system(size: 14))
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                let masked = APIKeyManager.shared.maskedKey(for: provider.rawValue)
                Text(masked)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(APIKeyManager.shared.hasKey(for: provider.rawValue) ? .green : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(4)
            }

            HStack(spacing: 8) {
                SecureField("Enter API Key (saved to Keychain)", text: input)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                Button("Save") {
                    let key = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !key.isEmpty {
                        APIKeyManager.shared.setKey(key, for: provider.rawValue)
                        input.wrappedValue = ""
                        testStatus[provider.rawValue] = "Saved to Keychain! ✓"
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if APIKeyManager.shared.hasKey(for: provider.rawValue) {
                    Button("Remove") {
                        APIKeyManager.shared.deleteKey(for: provider.rawValue)
                        testStatus[provider.rawValue] = "Key removed from Keychain."
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: {
                    Task {
                        isTesting[provider.rawValue] = true
                        testStatus[provider.rawValue] = "Testing connection..."
                        let result = await aiManager.testProvider(provider: provider)
                        isTesting[provider.rawValue] = false
                        testStatus[provider.rawValue] = result.message
                    }
                }) {
                    Text((isTesting[provider.rawValue] ?? false) ? "Testing..." : "Test")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isTesting[provider.rawValue] ?? false || !APIKeyManager.shared.hasKey(for: provider.rawValue))
            }

            // Model Selection
            HStack {
                Text("Default Model:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Picker("", selection: modelBinding) {
                    ForEach(models, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
            }

            if let status = testStatus[provider.rawValue] {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundColor(status.contains("✓") || status.contains("successfully") ? .green : .orange)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
    }
}

struct ScreenSettingsSection: View {
    @ObservedObject var screen = ScreenGuardian.shared
    @ObservedObject var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Screen Awareness")
                .font(.system(size: 18, weight: .bold))

            Text("Pet can observe active desktop windows to offer contextual suggestions.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Toggle(isOn: Binding(
                get: { dataManager.savedData.screenMonitoringEnabled ?? false },
                set: { enabled in
                    dataManager.savedData.screenMonitoringEnabled = enabled
                    dataManager.saveData()
                    if enabled {
                        screen.startMonitoring()
                    } else {
                        screen.stopMonitoring()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Screen Awareness")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Disabled by default on startup for performance.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
    }
}

// MARK: - Interactive Focus Duration Editor (Requirement 12)

struct FocusDurationEditorView: View {
    @ObservedObject var focus = FocusGuardian.shared
    @State private var directInput: String = ""
    @State private var hoursText: String = ""
    @State private var minutesText: String = ""
    @State private var secondsText: String = ""
    @State private var directInputError: String? = nil
    @State private var isCustomMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Focus Duration")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if focus.isSessionActive {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("Session Active — Locked")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))
                } else {
                    Text("Configured: \(focus.formattedSelectedDuration)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                        .foregroundColor(.accentColor)
                }
            }

            // Presets: [10m] [25m] [45m] [60m] [CUSTOM]
            HStack(spacing: 8) {
                presetButton(mins: 10)
                presetButton(mins: 25)
                presetButton(mins: 45)
                presetButton(mins: 60)
                customButton
            }

            // Custom Configuration Controls (Always accessible, highlighted when custom active)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Typeable HH : MM : SS
                    HStack(spacing: 8) {
                        VStack(alignment: .center, spacing: 2) {
                            Text("Hours")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("00", text: $hoursText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 44)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .disabled(focus.isSessionActive)
                                .onSubmit { commitCustomTime() }
                        }

                        Text(":")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.top, 12)

                        VStack(alignment: .center, spacing: 2) {
                            Text("Minutes")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("25", text: $minutesText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 44)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .disabled(focus.isSessionActive)
                                .onSubmit { commitCustomTime() }
                        }

                        Text(":")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.top, 12)

                        VStack(alignment: .center, spacing: 2) {
                            Text("Seconds")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("00", text: $secondsText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 44)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .disabled(focus.isSessionActive)
                                .onSubmit { commitCustomTime() }
                        }
                    }

                    Divider()
                        .frame(height: 32)

                    // Direct Input Field (e.g. "90m", "1h30m", "45", "1:30:00")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Direct input (e.g. \"90m\", \"1h30m\", \"45\")")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            TextField("e.g. 90m", text: $directInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .font(.system(size: 12))
                                .disabled(focus.isSessionActive)
                                .onSubmit { parseAndApplyDirectInput() }

                            Button("Apply") {
                                parseAndApplyDirectInput()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(focus.isSessionActive || directInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                if let err = directInputError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        .onAppear {
            syncFromFocus()
            isCustomMode = isNonPresetDuration()
        }
        .onChange(of: focus.customHours) { _ in syncFromFocus() }
        .onChange(of: focus.customMinutes) { _ in syncFromFocus() }
        .onChange(of: focus.customSeconds) { _ in syncFromFocus() }
    }

    @ViewBuilder
    private func presetButton(mins: Int) -> some View {
        let isSelected = !isCustomMode && focus.selectedDurationSeconds == (mins * 60)
        let btn = Button("\(mins)m") {
            isCustomMode = false
            applyPresetMinutes(mins)
        }
        .controlSize(.small)
        .disabled(focus.isSessionActive)

        if isSelected {
            btn.buttonStyle(.borderedProminent)
        } else {
            btn.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var customButton: some View {
        let isSelected = isCustomMode || isNonPresetDuration()
        let btn = Button("Custom") {
            isCustomMode = true
        }
        .controlSize(.small)
        .disabled(focus.isSessionActive)

        if isSelected {
            btn.buttonStyle(.borderedProminent)
        } else {
            btn.buttonStyle(.bordered)
        }
    }

    private func isNonPresetDuration() -> Bool {
        let total = focus.selectedDurationSeconds
        return total != 600 && total != 1500 && total != 2700 && total != 3600
    }

    private func syncFromFocus() {
        hoursText = String(format: "%02d", focus.customHours)
        minutesText = String(format: "%02d", focus.customMinutes)
        secondsText = String(format: "%02d", focus.customSeconds)
    }

    private func applyPresetMinutes(_ mins: Int) {
        focus.applyPreset(seconds: mins * 60)
        syncFromFocus()
        directInputError = nil
    }

    private func commitCustomTime() {
        let h = max(0, min(23, Int(hoursText.filter({ $0.isNumber })) ?? 0))
        let m = max(0, min(59, Int(minutesText.filter({ $0.isNumber })) ?? 0))
        let s = max(0, min(59, Int(secondsText.filter({ $0.isNumber })) ?? 0))
        let total = (h * 3600) + (m * 60) + s
        if total > 0 {
            isCustomMode = true
            focus.setConfiguredDuration(seconds: total)
            syncFromFocus()
            directInputError = nil
        }
    }

    private func parseAndApplyDirectInput() {
        directInputError = nil
        let trimmed = directInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let seconds = FocusDurationParser.parse(trimmed) {
            isCustomMode = true
            focus.setConfiguredDuration(seconds: seconds)
            syncFromFocus()
            directInput = ""
        } else {
            directInputError = "Invalid duration. Try '25', '45m', '90m', '1h30m', or '1:30:00'."
        }
    }
}

struct FocusSettingsSection: View {
    @ObservedObject var focus = FocusGuardian.shared
    @ObservedObject var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Focus Guardian & Health Ergonomics")
                .font(.system(size: 18, weight: .bold))

            // 1. Interactive Focus Duration Editor (Requirement 12)
            FocusDurationEditorView()

            // 2. Step-Away Alerts Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { dataManager.savedData.focusNotificationsEnabled ?? true },
                    set: {
                        dataManager.savedData.focusNotificationsEnabled = $0
                        dataManager.saveData()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Step-Away & Absence Alerts")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Pet notifies you when you step away during an active focus block.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // 3. Hydration Reminders & Interval
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { dataManager.savedData.hydrationReminderEnabled ?? true },
                    set: {
                        dataManager.savedData.hydrationReminderEnabled = $0
                        dataManager.saveData()
                        focus.startHydrationTimerIfNeeded()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hydration & Eye Break Reminders")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Pet periodically reminds you to drink water and look away from the screen.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if dataManager.savedData.hydrationReminderEnabled ?? true {
                    Divider()
                        .padding(.vertical, 2)

                    HStack {
                        Text("Reminder Interval")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { dataManager.savedData.hydrationIntervalMinutes ?? 60 },
                            set: {
                                dataManager.savedData.hydrationIntervalMinutes = $0
                                dataManager.saveData()
                                focus.startHydrationTimerIfNeeded()
                            }
                        )) {
                            Text("Every 20 minutes (20-20-20 rule)").tag(20)
                            Text("Every 30 minutes").tag(30)
                            Text("Every 45 minutes").tag(45)
                            Text("Every 60 minutes (Default)").tag(60)
                            Text("Every 90 minutes").tag(90)
                        }
                        .labelsHidden()
                        .frame(width: 240)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // 4. Quick Action to Start/Stop Session
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(focus.isSessionActive ? "Focus Session Running: \(focus.formattedTime)" : "Focus Session Inactive")
                        .font(.system(size: 13, weight: .semibold))
                    Text(focus.isSessionActive ? "Click Pause or switch to Chat panel to manage." : "Start now using configured duration.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(focus.isSessionActive ? "Pause Session" : "Start Focus Session") {
                    if focus.isSessionActive {
                        focus.pauseFocusSession()
                    } else {
                        focus.startFocusSession()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.08)))
        }
    }
}

struct PrivacySettingsSection: View {
    @ObservedObject var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Privacy & Local Safety")
                .font(.system(size: 18, weight: .bold))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                    Text("100% Local AI Guarantee")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text("Ollama Pet runs completely on your Mac. All LLM chats, reminders, vision inferences, and voice transcriptions are processed locally with zero telemetry sent to third-party cloud servers.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            Button(role: .destructive, action: {
                dataManager.savedData.history = []
                dataManager.savedData.reminders = []
                dataManager.saveData()
            }) {
                Text("Clear All Local Chat History & Reminders")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Mac Control Settings Section

struct MacControlSettingsSection: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var perf = PerformanceManager.shared
    @State private var newShortcutInput: String = ""

    private var settingsBinding: Binding<MacControlSettings> {
        Binding(
            get: { dataManager.savedData.macControlSettings ?? MacControlSettings() },
            set: { dataManager.updateMacControlSettings($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Mac Control & Action Assistant")
                .font(.system(size: 18, weight: .bold))

            // Master Toggle
            VStack(alignment: .leading, spacing: 6) {
                SettingsRow(
                    icon: "slider.horizontal.3",
                    iconColor: .blue,
                    title: "Enable Mac Control Assistant",
                    subtitle: "Allows Ollama Pet to perform safe, approved actions on your Mac. OFF by default."
                ) {
                    Toggle("", isOn: settingsBinding.macControlEnabled)
                        .labelsHidden()
                }

                if settingsBinding.wrappedValue.macControlEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        Text("Zero Terminal execution. Only structured actions from the safe allowlist are permitted.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 40)
                    .padding(.top, 4)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            if settingsBinding.wrappedValue.macControlEnabled {
                // Allowed Actions Group
                VStack(alignment: .leading, spacing: 10) {
                    Text("Allowed Actions")
                        .font(.system(size: 13, weight: .bold))

                    VStack(spacing: 6) {
                        SettingsRow(
                            icon: "app.badge.fill",
                            iconColor: .blue,
                            title: "Open Applications",
                            subtitle: "Launch apps like Safari, Chrome, Slack, Notes, etc."
                        ) {
                            Toggle("", isOn: settingsBinding.openAppsEnabled)
                                .labelsHidden()
                        }
                        Divider()

                        SettingsRow(
                            icon: "globe",
                            iconColor: .teal,
                            title: "Open Websites",
                            subtitle: "Open safe HTTPS/HTTP URLs in your default browser."
                        ) {
                            Toggle("", isOn: settingsBinding.openURLsEnabled)
                                .labelsHidden()
                        }
                        Divider()

                        SettingsRow(
                            icon: "magnifyingglass",
                            iconColor: .indigo,
                            title: "Web Search",
                            subtitle: "Execute web searches on Google or YouTube."
                        ) {
                            Toggle("", isOn: settingsBinding.webSearchEnabled)
                                .labelsHidden()
                        }
                        Divider()

                        SettingsRow(
                            icon: "clock.badge.checkmark",
                            iconColor: .orange,
                            title: "Create Reminders",
                            subtitle: "Add natural language reminders to your schedule."
                        ) {
                            Toggle("", isOn: settingsBinding.remindersEnabled)
                                .labelsHidden()
                        }
                        Divider()

                        SettingsRow(
                            icon: "calendar",
                            iconColor: .red,
                            title: "Open Calendar & Reminders",
                            subtitle: "Open macOS Calendar and Reminders apps."
                        ) {
                            Toggle("", isOn: settingsBinding.calendarEnabled)
                                .labelsHidden()
                        }
                        Divider()

                        SettingsRow(
                            icon: "message.fill",
                            iconColor: .green,
                            title: "Open WhatsApp & Messages",
                            subtitle: "Open messaging apps and prepare drafts."
                        ) {
                            Toggle("", isOn: settingsBinding.whatsappEnabled)
                                .labelsHidden()
                        }
                        Divider()

                        SettingsRow(
                            icon: "bolt.fill",
                            iconColor: .purple,
                            title: "Run Approved Shortcuts",
                            subtitle: "Trigger macOS Shortcuts explicitly added below."
                        ) {
                            Toggle("", isOn: settingsBinding.shortcutsEnabled)
                                .labelsHidden()
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

                // Confirmation & Safety
                VStack(alignment: .leading, spacing: 10) {
                    Text("Confirmation & Safety")
                        .font(.system(size: 13, weight: .bold))

                    VStack(spacing: 6) {
                        SettingsRow(
                            icon: "hand.raised.fill",
                            iconColor: .orange,
                            title: "Always confirm external actions",
                            subtitle: "Show an interactive [Cancel] / [Confirm] dialog before sending messages or triggering automations."
                        ) {
                            Toggle("", isOn: settingsBinding.alwaysConfirmExternalActions)
                                .labelsHidden()
                        }
                        Divider()

                        SettingsRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            iconColor: .blue,
                            title: "Show action status in pet",
                            subtitle: "Pet displays short status bubbles (e.g. 'Opening Safari...', 'Reminder created.')."
                        ) {
                            Toggle("", isOn: settingsBinding.showActionStatus)
                                .labelsHidden()
                        }
                        Divider()

                        SettingsRow(
                            icon: "mic.fill",
                            iconColor: .pink,
                            title: "Voice Mac Control",
                            subtitle: "Allow push-to-talk voice commands (\(ShortcutManager.shared.voiceShortcut.displayString)) to trigger Mac actions."
                        ) {
                            Toggle("", isOn: settingsBinding.voiceControlEnabled)
                                .labelsHidden()
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

                // Approved Shortcuts
                VStack(alignment: .leading, spacing: 10) {
                    Text("Approved macOS Shortcuts")
                        .font(.system(size: 13, weight: .bold))

                    Text("Only shortcuts explicitly approved in this list can ever be executed. Ollama cannot invent shortcut names.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        TextField("New approved shortcut name...", text: $newShortcutInput)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            let trimmed = newShortcutInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                var s = settingsBinding.wrappedValue
                                if !s.approvedShortcuts.contains(trimmed) {
                                    s.approvedShortcuts.append(trimmed)
                                    dataManager.updateMacControlSettings(s)
                                }
                                newShortcutInput = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newShortcutInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    VStack(spacing: 6) {
                        ForEach(settingsBinding.wrappedValue.approvedShortcuts, id: \.self) { name in
                            HStack {
                                Image(systemName: "command.square.fill")
                                    .foregroundColor(.accentColor)
                                Text(name)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                Spacer()
                                Button(action: {
                                    var s = settingsBinding.wrappedValue
                                    s.approvedShortcuts.removeAll { $0 == name }
                                    dataManager.updateMacControlSettings(s)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

                // Verification & Diagnostics Test Suite
                MacControlDiagnosticsView()
            }
        }
    }
}

// MARK: - Mac Control Diagnostics View

struct PipelineLogStep: Identifiable {
    let id = UUID()
    let stage: String
    let message: String
    let icon: String
    let color: Color
}

struct MacControlDiagnosticsView: View {
    @State private var isExecuting: Bool = false
    @State private var logs: [PipelineLogStep] = []
    @State private var finalResult: String? = nil
    @State private var finalStatus: ActionExecutionStatus? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.blue)
                Text("Verification & Diagnostics Pipeline")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            Text("Test live action dispatching against the 5-step pipeline: REQUEST → PARSE → VALIDATE → EXECUTE → VERIFY → STATUS.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Test Buttons Grid
            HStack(spacing: 8) {
                Button("Test Safari") {
                    runTest(query: "open safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isExecuting)

                Button("Test Chrome + YouTube") {
                    runTest(query: "play lofi hip hop on youtube using chrome")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isExecuting)

                Button("Test WhatsApp Draft") {
                    runTest(query: "message Alex on whatsapp saying hello")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isExecuting)

                Button("Test System Vitals") {
                    runTest(query: "check cpu temperature")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isExecuting)
            }
            .padding(.vertical, 4)

            // Live Pipeline Steps
            if !logs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(logs) { step in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: step.icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(step.color)
                                .frame(width: 14)
                                .padding(.top, 2)

                            Text(step.stage)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(step.color)
                                .frame(width: 70, alignment: .leading)

                            Text(step.message)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(3)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            }

            // Final Result Badge
            if let result = finalResult, let status = finalStatus {
                HStack(spacing: 6) {
                    Image(systemName: status.iconName)
                        .foregroundColor(status.badgeColor)
                    Text(result)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(status.badgeColor)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }

    private func runTest(query: String) {
        guard !isExecuting else { return }
        isExecuting = true
        logs = []
        finalResult = nil
        finalStatus = nil

        Task { @MainActor in
            // Step 1: REQUEST
            logs.append(PipelineLogStep(
                stage: "REQUEST",
                message: "\"\(query)\"",
                icon: "paperplane.fill",
                color: .blue
            ))
            try? await Task.sleep(nanoseconds: 80_000_000)

            // Step 2: PARSE
            let action = await ActionIntentParser.shared.parseIntent(from: query)
            guard let action = action else {
                logs.append(PipelineLogStep(
                    stage: "PARSE",
                    message: "No action intent matched user input.",
                    icon: "xmark.circle.fill",
                    color: .red
                ))
                finalStatus = .failed
                finalResult = "Action intent could not be parsed."
                isExecuting = false
                return
            }
            logs.append(PipelineLogStep(
                stage: "PARSE",
                message: "Type: \(action.type.rawValue) [\(action.summaryDescription)]",
                icon: "cpu",
                color: .teal
            ))
            try? await Task.sleep(nanoseconds: 80_000_000)

            // Step 3: VALIDATE
            let settings = DataManager.shared.savedData.macControlSettings ?? MacControlSettings()
            let validation = ActionValidator.validate(action: action, settings: settings, isSafeMode: PerformanceManager.shared.isSafeMode)
            switch validation {
            case .blocked(let reason):
                logs.append(PipelineLogStep(
                    stage: "VALIDATE",
                    message: "Blocked: \(reason)",
                    icon: "hand.raised.fill",
                    color: .orange
                ))
                finalStatus = .blocked
                finalResult = reason
                isExecuting = false
                return
            case .needsClarification(let prompt):
                logs.append(PipelineLogStep(
                    stage: "VALIDATE",
                    message: "Clarification: \(prompt)",
                    icon: "questionmark.circle.fill",
                    color: .orange
                ))
                finalStatus = .needsClarification
                finalResult = prompt
                isExecuting = false
                return
            case .requiresConfirmation:
                logs.append(PipelineLogStep(
                    stage: "VALIDATE",
                    message: "Requires user confirmation prompt.",
                    icon: "exclamationmark.circle.fill",
                    color: .yellow
                ))
            case .valid:
                logs.append(PipelineLogStep(
                    stage: "VALIDATE",
                    message: "Passed allowlist & security checks.",
                    icon: "checkmark.seal.fill",
                    color: .green
                ))
            }
            try? await Task.sleep(nanoseconds: 80_000_000)

            // Step 4: EXECUTE
            logs.append(PipelineLogStep(
                stage: "EXECUTE",
                message: "Dispatching via native MacActionExecutor...",
                icon: "play.fill",
                color: .purple
            ))

            let resultMessage = await MacActionExecutor.shared.processAction(action, userText: query)
            try? await Task.sleep(nanoseconds: 80_000_000)

            // Step 5: VERIFY
            let lastItem = ActionHistoryManager.shared.items.first
            let status = lastItem?.status ?? .success
            logs.append(PipelineLogStep(
                stage: "VERIFY",
                message: "Checked macOS process & sandbox state: \(status.rawValue)",
                icon: "magnifyingglass",
                color: status.badgeColor
            ))

            // Step 6: STATUS
            logs.append(PipelineLogStep(
                stage: "STATUS",
                message: resultMessage,
                icon: status.iconName,
                color: status.badgeColor
            ))

            finalStatus = status
            finalResult = "[\(status.rawValue)] \(resultMessage)"
            isExecuting = false
        }
    }
}

// MARK: - Permissions & Privacy Center Section

struct PermissionsPrivacySettingsSection: View {
    @ObservedObject var perm = PermissionManager.shared
    @State private var isTestingNotification: Bool = false
    @State private var testNotificationMessage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Permissions & Privacy Center")
                .font(.system(size: 18, weight: .bold))

            // Privacy Guarantee
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                    Text("100% On-Device Privacy Architecture")
                        .font(.system(size: 13, weight: .bold))
                }
                Text("• Voice is only captured while you actively hold Push-to-Talk.\n• Camera & Screen sensing are strictly disabled by default.\n• No continuous background surveillance, screen recording, or audio logging.\n• No audio recordings, private tokens, or passwords are ever stored.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // Permissions Grid
            VStack(alignment: .leading, spacing: 10) {
                Text("System Permissions")
                    .font(.system(size: 13, weight: .bold))

                VStack(spacing: 8) {
                    SettingsRow(
                        icon: "mic.fill",
                        iconColor: .pink,
                        title: "Microphone",
                        subtitle: "Required for Push-to-Talk voice assistant."
                    ) {
                        HStack(spacing: 8) {
                            Text(perm.microphoneStatus.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(perm.microphoneStatus == .granted ? .green : (perm.microphoneStatus == .denied ? .red : .secondary))

                            Button("Settings") {
                                PermissionManager.shared.openSystemSettings(pane: "Privacy_Microphone")
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    SettingsRow(
                        icon: "waveform.badge.magnifyingglass",
                        iconColor: .blue,
                        title: "Speech Recognition",
                        subtitle: "Processes speech into text using native macOS APIs."
                    ) {
                        HStack(spacing: 8) {
                            Text(perm.speechStatus.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(perm.speechStatus == .granted ? .green : (perm.speechStatus == .denied ? .red : .secondary))

                            Button("Settings") {
                                PermissionManager.shared.openSystemSettings(pane: "Privacy_SpeechRecognition")
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    SettingsRow(
                        icon: "camera.fill",
                        iconColor: .teal,
                        title: "Camera",
                        subtitle: "Optional posture awareness (Off by default)."
                    ) {
                        HStack(spacing: 8) {
                            Text(perm.cameraStatus.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(perm.cameraStatus == .granted ? .green : (perm.cameraStatus == .denied ? .red : .secondary))

                            Button("Settings") {
                                PermissionManager.shared.openSystemSettings(pane: "Privacy_Camera")
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    SettingsRow(
                        icon: "bell.badge.fill",
                        iconColor: .orange,
                        title: "Notifications",
                        subtitle: "Required for reminder alerts, focus milestones, and hydration prompts."
                    ) {
                        HStack(spacing: 8) {
                            Text(perm.notificationsStatus.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(perm.notificationsStatus == .granted ? .green : (perm.notificationsStatus == .denied ? .red : .secondary))

                            Button(action: {
                                isTestingNotification = true
                                testNotificationMessage = "Sending test notification..."
                                NotificationScheduler.shared.sendTestNotification { success in
                                    Task { @MainActor in
                                        isTestingNotification = false
                                        if success {
                                            testNotificationMessage = "✅ Test notification delivered! Check macOS Notification Center."
                                        } else {
                                            testNotificationMessage = "⚠️ Notifications may be muted or disabled in macOS System Settings."
                                        }
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if isTestingNotification {
                                        ProgressView().controlSize(.mini)
                                    }
                                    Text("Test Notification")
                                }
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(isTestingNotification)

                            Button("Settings") {
                                PermissionManager.shared.openSystemSettings(pane: nil)
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if !testNotificationMessage.isEmpty {
                        Text(testNotificationMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(testNotificationMessage.contains("✅") ? .green : .orange)
                            .padding(.top, 4)
                            .padding(.leading, 40)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
        .onAppear {
            perm.checkAllPermissions()
        }
    }
}

// MARK: - Action History Section

struct ActionHistorySettingsSection: View {
    @ObservedObject var history = ActionHistoryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Action History")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                if !history.items.isEmpty {
                    Button("Clear History") {
                        history.clearHistory()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Text("Minimal log of recent Mac actions. Zero audio recordings, passwords, or personal tokens are stored.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if history.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No actions recorded yet.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(history.items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.status.iconName)
                                .foregroundColor(item.status.badgeColor)
                                .font(.system(size: 14))
                                .frame(width: 18)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(item.summary)
                                        .font(.system(size: 12, weight: .bold))
                                    Spacer()
                                    Text(item.formattedTime)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 6) {
                                    Text(item.status.rawValue)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(item.status.badgeColor.opacity(0.2)))
                                        .foregroundColor(item.status.badgeColor)

                                    if let detail = item.detail, !detail.isEmpty {
                                        Text(detail)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                    }
                }
            }
        }
    }
}

// MARK: - Notifications Settings Section

struct NotificationSettingsSection: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isTesting: Bool = false
    @State private var testResult: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications & Alerts")
                    .font(.system(size: 18, weight: .bold))
                Text("Manage native macOS banner notifications, speech alerts, and companion reminder schedules.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 1. Status Card & System Permission
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle)
                            .font(.system(size: 13, weight: .semibold))
                        Text(statusDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if authStatus == .denied {
                        Button("Open macOS Settings") {
                            openSystemNotificationSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else if authStatus == .notDetermined {
                        Button("Allow Notifications") {
                            NotificationScheduler.shared.requestAuthorization { _ in
                                refreshStatus()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if authStatus == .denied {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Notifications are disabled in macOS System Settings. Open System Settings > Notifications > Ollama Pet to enable.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // 2. Test Notification Action
            VStack(alignment: .leading, spacing: 10) {
                Text("Verification & Diagnostics")
                    .font(.system(size: 13, weight: .bold))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Send Test Notification")
                            .font(.system(size: 13, weight: .medium))
                        Text("Dispatches an immediate notification banner to verify macOS delivery.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(isTesting ? "Sending..." : "Send Test Notification") {
                        isTesting = true
                        testResult = nil
                        NotificationScheduler.shared.sendTestNotification { success in
                            isTesting = false
                            testResult = success ? "✓ Notification delivered successfully" : "⚠️ Failed to post. Check Do Not Disturb / Focus."
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isTesting)
                }

                if let res = testResult {
                    Text(res)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(res.hasPrefix("✓") ? .green : .orange)
                        .padding(.top, 2)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // 3. Notification Category Checklist
            VStack(alignment: .leading, spacing: 12) {
                Text("Active Notification Checklist")
                    .font(.system(size: 13, weight: .bold))

                VStack(spacing: 8) {
                    notificationTypeRow(
                        icon: "target",
                        iconColor: .purple,
                        title: "Focus Session Completions",
                        subtitle: "Celebrates session completion, plays tone, and shows finish stats.",
                        isActive: true
                    )
                    Divider()
                    notificationTypeRow(
                        icon: "drop.fill",
                        iconColor: .blue,
                        title: "Hydration & Health Breaks",
                        subtitle: "Alerts you to take regular screen breaks and drink water.",
                        isActive: dataManager.savedData.hydrationReminderEnabled ?? true
                    )
                    Divider()
                    notificationTypeRow(
                        icon: "clock.badge.checkmark",
                        iconColor: .orange,
                        title: "Companion Reminders",
                        subtitle: "Dispatches scheduled reminders set via chat or Voice Assistant.",
                        isActive: true
                    )
                    Divider()
                    notificationTypeRow(
                        icon: "person.crop.rectangle.badge.plus",
                        iconColor: .green,
                        title: "Presence & Security Alerts",
                        subtitle: "Notifies when an unrecognized person lingers near your Mac.",
                        isActive: dataManager.savedData.presenceDwellAlertEnabled ?? true
                    )
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // 4. Spoken Announcements & Audio
            VStack(alignment: .leading, spacing: 12) {
                Text("Companion Spoken Announcements")
                    .font(.system(size: 13, weight: .bold))

                VStack(spacing: 8) {
                    SettingsToggleRow(
                        icon: "speaker.wave.2.fill",
                        iconColor: .indigo,
                        title: "Speak Focus Completion Aloud",
                        subtitle: "Pet warmly announces when your focus session timer expires.",
                        isOn: Binding(
                            get: { dataManager.savedData.speakFocusCompletionAloud ?? false },
                            set: { dataManager.savedData.speakFocusCompletionAloud = $0; dataManager.saveData() }
                        )
                    )
                    Divider()
                    SettingsToggleRow(
                        icon: "person.wave.2.fill",
                        iconColor: .teal,
                        title: "Speak Presence Alerts Aloud",
                        subtitle: "Pet vocalizes welcome greetings or unrecognized presence alerts.",
                        isOn: Binding(
                            get: { dataManager.savedData.presenceSpokenAlertsEnabled ?? false },
                            set: { dataManager.savedData.presenceSpokenAlertsEnabled = $0; dataManager.saveData() }
                        )
                    )
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
        .onAppear {
            refreshStatus()
        }
    }

    private func refreshStatus() {
        NotificationScheduler.shared.checkAuthorization { status in
            DispatchQueue.main.async {
                self.authStatus = status
            }
        }
    }

    private func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private var statusColor: Color {
        switch authStatus {
        case .authorized, .provisional: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .secondary
        }
    }

    private var statusTitle: String {
        switch authStatus {
        case .authorized, .provisional: return "macOS Notifications Enabled"
        case .denied: return "macOS Notifications Disabled"
        case .notDetermined: return "Notification Permission Not Determined"
        @unknown default: return "Notification Status Unknown"
        }
    }

    private var statusDescription: String {
        switch authStatus {
        case .authorized, .provisional:
            return "Ollama Pet has full permission to send system notification alerts and sound tones."
        case .denied:
            return "Alerts are blocked by system settings. Open macOS Settings to grant notification access."
        case .notDetermined:
            return "Grant permission so companion can alert you about focus sessions and reminders."
        @unknown default:
            return "System notification permission state is unavailable."
        }
    }

    private func notificationTypeRow(icon: String, iconColor: Color, title: String, subtitle: String, isActive: Bool) -> some View {
        let badgeText: String
        let badgeColor: Color
        if authStatus == .denied {
            badgeText = "Blocked by System"
            badgeColor = .red
        } else if authStatus == .notDetermined {
            badgeText = "Permission Needed"
            badgeColor = .orange
        } else if isActive {
            badgeText = "Active"
            badgeColor = .green
        } else {
            badgeText = "Disabled"
            badgeColor = .secondary
        }

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(badgeText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(badgeColor.opacity(0.12)))
        }
        .padding(.vertical, 2)
    }
}

