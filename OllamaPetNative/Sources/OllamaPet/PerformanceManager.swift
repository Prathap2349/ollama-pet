import Foundation
import SwiftUI
import AppKit

public enum PerformanceQuality: String, CaseIterable, Codable, Identifiable {
    case batterySaver = "Battery Saver"
    case balanced = "Balanced"
    case highQuality = "High Quality"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    public var targetFPS: Double {
        switch self {
        case .batterySaver: return 15.0
        case .balanced: return 30.0
        case .highQuality: return 60.0
        }
    }

    public var description: String {
        switch self {
        case .batterySaver: return "15 FPS max — minimal CPU/GPU usage, ideal for laptops"
        case .balanced: return "30 FPS — smooth animations with low energy consumption (Recommended)"
        case .highQuality: return "60 FPS — maximum fluidity for walking and dance bursts"
        }
    }
}

@MainActor
public class PerformanceManager: ObservableObject {
    public static let shared = PerformanceManager()

    @Published public var quality: PerformanceQuality = .balanced
    @Published public var isSafeMode: Bool = false
    @Published public var dynamicLightingEnabled: Bool = false
    @Published public var weatherEffectsEnabled: Bool = false
    @Published public var cpuReactiveGlowEnabled: Bool = false
    @Published public var dayNightTintEnabled: Bool = false
    @Published public var particlesEnabled: Bool = false
    @Published public var grayscaleTestMode: Bool = false
    @Published public var reduceMotion: Bool = false
    @Published public var statusNotice: String? = nil

    public var isReduceMotionActive: Bool {
        return reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    public var effectiveFPS: Double {
        if isSafeMode {
            return 15.0
        }
        if SystemMonitor.shared.isPowerSavingMode && quality != .batterySaver {
            return 20.0
        }
        return quality.targetFPS
    }

    public var minimumRenderInterval: Double {
        return 1.0 / effectiveFPS
    }

    public init() {
        loadSettings()
    }

    public func loadSettings() {
        let data = DataManager.shared.savedData
        if let qStr = data.performanceQuality, let q = PerformanceQuality(rawValue: qStr) {
            self.quality = q
        }
        self.isSafeMode = data.isSafeMode ?? false
        self.dynamicLightingEnabled = data.dynamicLightingEnabled ?? false
        self.weatherEffectsEnabled = data.weatherEffectsEnabled ?? false
        self.cpuReactiveGlowEnabled = data.cpuReactiveGlowEnabled ?? false
        self.dayNightTintEnabled = data.dayNightTintEnabled ?? false
        self.particlesEnabled = data.particlesEnabled ?? false
        self.grayscaleTestMode = data.grayscaleTestMode ?? false
        self.reduceMotion = data.reduceMotion ?? false

        self.statusNotice = self.isSafeMode ? "Performance Safe Mode enabled to reduce system load." : nil
    }

    public func saveSettings() {
        DataManager.shared.savedData.performanceQuality = quality.rawValue
        DataManager.shared.savedData.isSafeMode = isSafeMode
        DataManager.shared.savedData.dynamicLightingEnabled = dynamicLightingEnabled
        DataManager.shared.savedData.weatherEffectsEnabled = weatherEffectsEnabled
        DataManager.shared.savedData.cpuReactiveGlowEnabled = cpuReactiveGlowEnabled
        DataManager.shared.savedData.dayNightTintEnabled = dayNightTintEnabled
        DataManager.shared.savedData.particlesEnabled = particlesEnabled
        DataManager.shared.savedData.grayscaleTestMode = grayscaleTestMode
        DataManager.shared.savedData.reduceMotion = reduceMotion
        DataManager.shared.saveData()

        updateStatusNotice()
    }

    public func setQuality(_ newQuality: PerformanceQuality) {
        self.quality = newQuality
        saveSettings()
    }

    public func toggleSafeMode() {
        self.isSafeMode.toggle()
        if isSafeMode {
            // Immediately stop heavy optional subsystems
            VisionGuardian.shared.stopSession()
            ScreenGuardian.shared.stopMonitoring()
            VoiceAssistant.shared.stopSpeaking()
            MusicManager.shared.stop()
            statusNotice = "Safe Mode enabled: animations throttled, optional sensing disabled."
        } else {
            statusNotice = nil
        }
        saveSettings()
    }

    public func resetToDefaults() {
        self.quality = .balanced
        self.isSafeMode = false
        self.dynamicLightingEnabled = false
        self.weatherEffectsEnabled = false
        self.cpuReactiveGlowEnabled = false
        self.dayNightTintEnabled = false
        self.particlesEnabled = false
        self.grayscaleTestMode = false
        self.statusNotice = nil
        saveSettings()
    }

    public func updateStatusNotice() {
        if isSafeMode {
            statusNotice = "Performance Safe Mode enabled to reduce system load."
        } else {
            statusNotice = nil
        }
    }
}
