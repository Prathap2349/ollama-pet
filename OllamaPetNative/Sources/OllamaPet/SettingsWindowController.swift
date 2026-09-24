import Foundation
import AppKit
import SwiftUI
import ServiceManagement

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
    }
}

// MARK: - Settings Tab Items

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case character = "Character & Silhouettes"
    case macControl = "Mac Control"
    case permissions = "Permissions & Privacy"
    case actionHistory = "Action History"
    case animation = "Animation & Physics"
    case voice = "Voice Assistant"
    case shortcuts = "Keyboard Shortcuts"
    case ollama = "Ollama & AI"
    case vision = "Camera Awareness"
    case screen = "Screen Awareness"
    case focus = "Focus & Health"
    case privacy = "Privacy & Data"
    case performance = "Performance & Safety"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .character: return "pawprint.fill"
        case .macControl: return "macmini.fill"
        case .permissions: return "lock.shield.fill"
        case .actionHistory: return "clock.arrow.circlepath"
        case .animation: return "figure.walk.motion"
        case .voice: return "mic.fill"
        case .shortcuts: return "command"
        case .ollama: return "cpu.fill"
        case .vision: return "camera.fill"
        case .screen: return "display"
        case .focus: return "brain.head.profile"
        case .privacy: return "hand.raised.fill"
        case .performance: return "bolt.shield.fill"
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
            // Sidebar Navigation
            VStack(alignment: .leading, spacing: 2) {
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
                    .padding(.bottom, 6)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(SettingsTab.allCases) { tab in
                            Button(action: {
                                windowController.activeTab = tab
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: tab.icon)
                                        .frame(width: 18)
                                        .foregroundColor(windowController.activeTab == tab ? .white : .secondary)
                                    Text(tab.rawValue)
                                        .font(.system(size: 12, weight: windowController.activeTab == tab ? .semibold : .regular))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(windowController.activeTab == tab ? Color.accentColor : Color.clear)
                                )
                                .foregroundColor(windowController.activeTab == tab ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
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
                    case .vision:
                        VisionSettingsSection()
                    case .screen:
                        ScreenSettingsSection()
                    case .focus:
                        FocusSettingsSection()
                    case .privacy:
                        PrivacySettingsSection()
                    case .performance:
                        PerformanceSettingsSection()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 680, minHeight: 520)
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
                // Interactive Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(perf.grayscaleTestMode ? Color(white: 0.15) : Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    TimelineView(.animation(minimumInterval: perf.minimumRenderInterval)) { (timeline: TimelineViewDefaultContext) in
                        Canvas { context, size in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let snapshot = motion.evaluateSnapshot(
                                at: t,
                                animState: .idle,
                                atmosphere: .clearDay,
                                isSafeMode: perf.isSafeMode
                            )
                            let model = CharacterStructuralModel.model(for: petState.currentSpecies)
                            PetCanvasRenderer.draw(
                                context: &context,
                                size: size,
                                species: petState.currentSpecies,
                                model: model,
                                animState: .idle,
                                snapshot: snapshot,
                                perf: perf
                            )
                        }
                    }
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
                    }

                    Text(petState.currentSpecies.lore)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(3)

                    HStack(spacing: 6) {
                        Text("Distinct Feature:")
                            .font(.system(size: 11, weight: .bold))
                        Text(distinctFeatureDescription(for: petState.currentSpecies))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.03)))

            // Species Grid (All 7 species with live native Canvas preview cards)
            Text("Select Companion")
                .font(.system(size: 14, weight: .semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
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

            // Walk Test Button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Test Walking Rig")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Simulates the species-specific walking cycle (hopping for bunny, floating wave for ghost, 4-leg trot for cat/fox).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Walk Test") {
                    WalkerManager.shared.startWalk(species: petState.currentSpecies, isTest: true)
                }
                .buttonStyle(.borderedProminent)
            }
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

// MARK: - Native Character Preview Card

struct SpeciesPreviewCard: View {
    let species: PetSpecies
    let isSelected: Bool
    @ObservedObject var perf = PerformanceManager.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Live Canvas Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(perf.grayscaleTestMode ? Color(white: 0.15) : Color.black.opacity(0.85))

                    TimelineView(.animation(minimumInterval: perf.minimumRenderInterval)) { (timeline: TimelineViewDefaultContext) in
                        Canvas { context, size in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let snapshot = motion.evaluateSnapshot(
                                at: t,
                                animState: .idle,
                                atmosphere: .clearDay,
                                isSafeMode: perf.isSafeMode
                            )
                            let model = CharacterStructuralModel.model(for: species)
                            PetCanvasRenderer.draw(
                                context: &context,
                                size: size,
                                species: species,
                                model: model,
                                animState: .idle,
                                snapshot: snapshot,
                                perf: perf
                            )
                        }
                    }
                }
                .frame(height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(species.icon)
                            .font(.system(size: 13))
                        Text(species.displayName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                    }
                    Text(species.speciesName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
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
        }
    }
}

// MARK: - Performance & Safety Section

struct PerformanceSettingsSection: View {
    @ObservedObject var perf = PerformanceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Performance & Shaders")
                .font(.system(size: 18, weight: .bold))

            Text("All visual enhancements are strictly decoupled and opt-in to prevent high GPU/CPU cycles.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Toggle(isOn: $perf.dynamicLightingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dynamic Radial Lighting & Highlights")
                            .font(.system(size: 13, weight: .medium))
                        Text("Adds soft directional aura and rim glow. Off by default.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Toggle(isOn: $perf.weatherEffectsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weather Atmospheric Effects")
                            .font(.system(size: 13, weight: .medium))
                        Text("Renders raindrops, snow flurries, or golden hour particles in stage.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Toggle(isOn: $perf.cpuReactiveGlowEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CPU Thermal Reactive Glow")
                            .font(.system(size: 13, weight: .medium))
                        Text("Gently pulses when CPU activity spikes above normal.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Toggle(isOn: $perf.particlesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Floating Thought Particles & Sparks")
                            .font(.system(size: 13, weight: .medium))
                        Text("Renders levitating thought particles during LLM generation.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            Button("Reset Performance to Defaults") {
                perf.resetToDefaults()
            }
            .buttonStyle(.bordered)
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
            Text("Voice Assistant")
                .font(.system(size: 18, weight: .bold))

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
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

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
                    Text("Pet vocalizes responses using native macOS speech synthesis.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
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

            VStack(spacing: 10) {
                shortcutRow(title: "Toggle Companion Window", shortcut: "⌘ ⇧ P")
                Divider()
                shortcutRow(title: "Open Chat / Panel", shortcut: "⌘ ⇧ C")
                Divider()
                shortcutRow(title: "Push-to-Talk Voice", shortcut: "Hold ⌘ ⇧ V")
                Divider()
                shortcutRow(title: "Trigger Walk Cycle", shortcut: "⌘ ⇧ W")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
    }

    private func shortcutRow(title: String, shortcut: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
        }
    }
}

// MARK: - Ollama Section

struct OllamaSettingsSection: View {
    @ObservedObject var client = OllamaClient.shared
    @ObservedObject var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ollama & Local AI")
                .font(.system(size: 18, weight: .bold))

            // Installed Models
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Selected Model")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button("Refresh") {
                        Task { await client.checkHealth(preferredModel: dataManager.savedData.selectedModel) }
                    }
                    .buttonStyle(.borderless)
                }

                if client.installedModels.isEmpty {
                    Text("No local models found at http://127.0.0.1:11434. Ensure Ollama is running.")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                } else {
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
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
    }
}

// MARK: - Vision / Screen / Focus / Privacy

struct VisionSettingsSection: View {
    @ObservedObject var vision = VisionGuardian.shared
    @ObservedObject var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Camera & Focus Vision")
                .font(.system(size: 18, weight: .bold))

            Text("Processes webcam frames strictly on-device using local Vision frameworks. No photos or video leave your Mac.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Toggle(isOn: Binding(
                get: { dataManager.savedData.cameraAwarenessEnabled ?? false },
                set: { enabled in
                    dataManager.savedData.cameraAwarenessEnabled = enabled
                    dataManager.saveData()
                    if enabled {
                        vision.startSession()
                    } else {
                        vision.stopSession()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Camera Awareness")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Allows pet to notice posture and presence. Off by default on startup.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
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

struct FocusSettingsSection: View {
    @ObservedObject var focus = FocusGuardian.shared
    @ObservedObject var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Focus Guardian & Health Ergonomics")
                .font(.system(size: 18, weight: .bold))

            // 1. Default Session Duration
            VStack(alignment: .leading, spacing: 10) {
                Text("Default Focus Duration")
                    .font(.system(size: 13, weight: .semibold))

                Text("Configure your standard timer length for new focus sessions.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Picker("H", selection: Binding(
                            get: { focus.customHours },
                            set: {
                                focus.customHours = $0
                                focus.applyPreset(seconds: ($0 * 3600) + (focus.customMinutes * 60) + focus.customSeconds)
                            }
                        )) {
                            ForEach(0...12, id: \.self) { h in
                                Text("\(h)").tag(h)
                            }
                        }
                        .frame(width: 60)
                        Text("hr")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Picker("M", selection: Binding(
                            get: { focus.customMinutes },
                            set: {
                                focus.customMinutes = $0
                                focus.applyPreset(seconds: (focus.customHours * 3600) + ($0 * 60) + focus.customSeconds)
                            }
                        )) {
                            ForEach(0...59, id: \.self) { m in
                                Text("\(m)").tag(m)
                            }
                        }
                        .frame(width: 60)
                        Text("min")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Picker("S", selection: Binding(
                            get: { focus.customSeconds },
                            set: {
                                focus.customSeconds = $0
                                focus.applyPreset(seconds: (focus.customHours * 3600) + (focus.customMinutes * 60) + $0)
                            }
                        )) {
                            ForEach(0...59, id: \.self) { s in
                                Text("\(s)").tag(s)
                            }
                        }
                        .frame(width: 60)
                        Text("sec")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("Preset: \(focus.formattedTime)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

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
                Toggle(isOn: settingsBinding.macControlEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Mac Control Assistant")
                            .font(.system(size: 13, weight: .bold))
                        Text("Allows Ollama Pet to perform safe, approved actions on your Mac. OFF by default.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
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

                    VStack(spacing: 8) {
                        actionToggle(title: "Open Applications", desc: "Launch apps like Safari, Chrome, Slack, Notes, etc.", binding: settingsBinding.openAppsEnabled)
                        Divider()
                        actionToggle(title: "Open Websites", desc: "Open safe HTTPS/HTTP URLs in your default browser.", binding: settingsBinding.openURLsEnabled)
                        Divider()
                        actionToggle(title: "Web Search", desc: "Execute web searches on Google or YouTube.", binding: settingsBinding.webSearchEnabled)
                        Divider()
                        actionToggle(title: "Create Reminders", desc: "Add natural language reminders to your schedule.", binding: settingsBinding.remindersEnabled)
                        Divider()
                        actionToggle(title: "Open Calendar & Reminders", desc: "Open macOS Calendar and Reminders apps.", binding: settingsBinding.calendarEnabled)
                        Divider()
                        actionToggle(title: "Open WhatsApp & Messages", desc: "Open messaging apps and prepare drafts.", binding: settingsBinding.whatsappEnabled)
                        Divider()
                        actionToggle(title: "Run Approved Shortcuts", desc: "Trigger macOS Shortcuts explicitly added below.", binding: settingsBinding.shortcutsEnabled)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

                // Confirmation & Safety
                VStack(alignment: .leading, spacing: 10) {
                    Text("Confirmation & Safety")
                        .font(.system(size: 13, weight: .bold))

                    Toggle(isOn: settingsBinding.alwaysConfirmExternalActions) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Always confirm external actions")
                                .font(.system(size: 12, weight: .medium))
                            Text("Show an interactive [Cancel] / [Confirm] dialog before sending messages or triggering automations.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    Toggle(isOn: settingsBinding.showActionStatus) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show action status in pet")
                                .font(.system(size: 12, weight: .medium))
                            Text("Pet displays short status bubbles (e.g. 'Opening Safari...', 'Reminder created.').")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    Toggle(isOn: settingsBinding.voiceControlEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Voice Mac Control")
                                .font(.system(size: 12, weight: .medium))
                            Text("Allow push-to-talk voice commands (⌘⇧Space) to trigger Mac actions.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
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
            }
        }
    }

    private func actionToggle(title: String, desc: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Permissions & Privacy Center Section

struct PermissionsPrivacySettingsSection: View {
    @ObservedObject var perm = PermissionManager.shared

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
                    permissionRow(
                        name: "Microphone",
                        desc: "Required for Push-to-Talk voice assistant.",
                        status: perm.microphoneStatus,
                        pane: "Privacy_Microphone"
                    )
                    Divider()
                    permissionRow(
                        name: "Speech Recognition",
                        desc: "Processes speech into text using native macOS APIs.",
                        status: perm.speechStatus,
                        pane: "Privacy_SpeechRecognition"
                    )
                    Divider()
                    permissionRow(
                        name: "Camera",
                        desc: "Optional posture awareness (Off by default).",
                        status: perm.cameraStatus,
                        pane: "Privacy_Camera"
                    )
                    Divider()
                    permissionRow(
                        name: "Notifications",
                        desc: "Required for reminder alerts and hydration prompts.",
                        status: perm.notificationsStatus,
                        pane: nil
                    )
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
        }
        .onAppear {
            perm.checkAllPermissions()
        }
    }

    private func permissionRow(name: String, desc: String, status: SystemPermissionStatus, pane: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(status.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(status == .granted ? .green : (status == .denied ? .red : .secondary))

            Button("Settings") {
                PermissionManager.shared.openSystemSettings(pane: pane)
            }
            .font(.system(size: 10))
            .buttonStyle(.bordered)
            .controlSize(.small)
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
