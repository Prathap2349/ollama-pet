import Foundation
import SwiftUI

// MARK: - Character Data & Themes

public enum PetSpecies: String, CaseIterable, Codable, Identifiable {
    case cat = "cat"
    case dragon = "dragon"
    case robot = "robot"
    case robotcat = "robotcat"
    case ghost = "ghost"
    case fox = "fox"
    case bunny = "bunny"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cat: return "Mochi"
        case .dragon: return "Ember"
        case .robot: return "ARIA"
        case .robotcat: return "NEO"
        case .ghost: return "BOO"
        case .fox: return "KITA"
        case .bunny: return "POCHI"
        }
    }

    public var icon: String {
        switch self {
        case .cat: return "🐱"
        case .dragon: return "🐉"
        case .robot: return "🤖"
        case .robotcat: return "🐱‍💻"
        case .ghost: return "👻"
        case .fox: return "🦊"
        case .bunny: return "🐰"
        }
    }

    public var accentColor: Color {
        switch self {
        case .cat: return Color(red: 139/255, green: 92/255, blue: 246/255)
        case .dragon: return Color(red: 249/255, green: 115/255, blue: 22/255)
        case .robot: return Color(red: 6/255, green: 182/255, blue: 212/255)
        case .robotcat: return Color(red: 16/255, green: 185/255, blue: 129/255)
        case .ghost: return Color(red: 148/255, green: 163/255, blue: 184/255)
        case .fox: return Color(red: 251/255, green: 146/255, blue: 60/255)
        case .bunny: return Color(red: 244/255, green: 114/255, blue: 182/255)
        }
    }

    public var greetings: [String] {
        switch self {
        case .cat: return ["Nyaa~ 🐱", "Pet me!", "Meow!", "*purrs*", "nya nya~"]
        case .dragon: return ["RAWR! 🐉", "Fire away!", "*roars*", "Feel the heat!"]
        case .robot: return ["BEEP BOOP 🤖", "Online!", "Systems ready", "Processing~", "Hello, human!"]
        case .robotcat: return ["Meow.exe 🐱‍💻", "Purr~", "nya~", "System purring~"]
        case .ghost: return ["Boo! 👻", "*floats past*", "Whoooo~", "Spooky!", "Haunting you~"]
        case .fox: return ["Yip! 🦊", "Foxy~!", "Hehehe 😏", "*tail swish*", "Kita here!"]
        case .bunny: return ["*hops* 🐰", "Binky time!", "Bun bun~", "Carrots? 🥕", "Thump thump!"]
        }
    }

    public var lore: String {
        switch self {
        case .cat: return "A mischievous, cozy feline companion who loves quick naps, purrs, and sunny spots."
        case .dragon: return "A fierce yet loyal mini dragon with glowing ember breath and flapping wings."
        case .robot: return "An articulated automaton companion with reactive visor and clean cybernetic joints."
        case .robotcat: return "A futuristic cyborg cat engineered with holographic HUD and sleek cybernetic paws."
        case .ghost: return "A gentle, legless spectral wisp that floats effortlessly and drifts across the screen."
        case .fox: return "A cunning, quick-witted forest fox with huge pointed ears and an enormous bushy tail."
        case .bunny: return "A delightfully plump bunny that hops rhythmically with long upright ears and a cotton tail."
        }
    }

    public var speciesName: String {
        switch self {
        case .cat: return "Feline"
        case .dragon: return "Dragon"
        case .robot: return "Android"
        case .robotcat: return "Cyber Cat"
        case .ghost: return "Phantom"
        case .fox: return "Kitsune"
        case .bunny: return "Rabbit"
        }
    }

    public func moodEmoji(for mood: PetMood) -> String {
        switch (self, mood) {
        case (.cat, .happy): return "😸"
        case (.cat, .sad): return "😿"
        case (.cat, .hungry): return "🙀"
        case (.cat, .sleepy): return "😴"
        case (.cat, .excited): return "🐱"
        case (.cat, .tired): return "😫"
        case (.cat, .love): return "😻"
        case (.cat, .angry): return "🙈"
        case (.cat, .surprised): return "😲"
        case (.cat, .crying): return "😹"

        case (.dragon, .happy): return "🔥"
        case (.dragon, .sad): return "💧"
        case (.dragon, .hungry): return "😤"
        case (.dragon, .sleepy): return "😴"
        case (.dragon, .excited): return "⚡"
        case (.dragon, .tired): return "🌬️"
        case (.dragon, .love): return "❤️‍🔥"
        case (.dragon, .angry): return "🐲"
        case (.dragon, .surprised): return "😲"
        case (.dragon, .crying): return "😢"

        case (.robot, .happy): return "💻"
        case (.robot, .sad): return "🔴"
        case (.robot, .hungry): return "⚡"
        case (.robot, .sleepy): return "💤"
        case (.robot, .excited): return "🔆"
        case (.robot, .tired): return "🌡️"
        case (.robot, .love): return "🤖"
        case (.robot, .angry): return "⚠️"
        case (.robot, .surprised): return "❗"
        case (.robot, .crying): return "🔧"

        case (.robotcat, .happy): return "😻"
        case (.robotcat, .sad): return "🙁"
        case (.robotcat, .hungry): return "⚡"
        case (.robotcat, .sleepy): return "💤"
        case (.robotcat, .excited): return "🚀"
        case (.robotcat, .tired): return "🔋"
        case (.robotcat, .love): return "👻"
        case (.robotcat, .angry): return "💢"
        case (.robotcat, .surprised): return "😱"
        case (.robotcat, .crying): return "😭"

        case (.ghost, .happy): return "😄"
        case (.ghost, .sad): return "😢"
        case (.ghost, .hungry): return "😮"
        case (.ghost, .sleepy): return "😴"
        case (.ghost, .excited): return "🌟"
        case (.ghost, .tired): return "💀"
        case (.ghost, .love): return "😍"
        case (.ghost, .angry): return "😠"
        case (.ghost, .surprised): return "🤩"
        case (.ghost, .crying): return "😭"

        case (.fox, .happy): return "🦊"
        case (.fox, .sad): return "😔"
        case (.fox, .hungry): return "🍖"
        case (.fox, .sleepy): return "😴"
        case (.fox, .excited): return "✨"
        case (.fox, .tired): return "😓"
        case (.fox, .love): return "🧡"
        case (.fox, .angry): return "😠"
        case (.fox, .surprised): return "😲"
        case (.fox, .crying): return "😭"

        case (.bunny, .happy): return "🐰"
        case (.bunny, .sad): return "🥲"
        case (.bunny, .hungry): return "🥕"
        case (.bunny, .sleepy): return "😴"
        case (.bunny, .excited): return "🐇"
        case (.bunny, .tired): return "🫠"
        case (.bunny, .love): return "💗"
        case (.bunny, .angry): return "😤"
        case (.bunny, .surprised): return "👀"
        case (.bunny, .crying): return "😭"
        }
    }
}

public enum PetMood: String, CaseIterable, Codable {
    case happy, excited, love, surprised, hungry, tired, angry, sad, crying, sleepy
}

public enum PetAnimState: String, Codable {
    case idle, dance, thinking, sleep, shock
}

// MARK: - Chat Message Model

public struct ChatMessage: Identifiable, Codable, Equatable {
    public let id: UUID
    public let role: String // "user", "assistant", "system"
    public let content: String
    public let timestamp: Date
    public var isFailed: Bool

    public init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(), isFailed: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isFailed = isFailed
    }
}

// MARK: - Reminder Model

public struct PetReminder: Identifiable, Codable, Equatable {
    public let id: Int64
    public var text: String
    public var due: Double // epoch milliseconds
    public var createdAt: Double
    public var status: String // "pending", "completed"

    public init(id: Int64 = Int64(Date().timeIntervalSince1970 * 1000), text: String, due: Double, createdAt: Double = Date().timeIntervalSince1970 * 1000, status: String = "pending") {
        self.id = id
        self.text = text
        self.due = due
        self.createdAt = createdAt
        self.status = status
    }
}

// MARK: - Persisted App State Data (~/ollama-pet-data.json)

public struct PetSavedData: Codable {
    public var version: Int? = 1
    public var currentChar: String
    public var streak: Int
    public var lastChatDate: String
    public var moodPoints: Double
    public var gameBest: Int
    public var activeTab: String?
    public var selectedModel: String?
    public var history: [PetSavedMessage]
    public var reminders: [PetReminder]
    public var position: PetSavedPosition?

    // Settings & Customization
    public var featureVisibility: [String: Bool]?
    public var randomCharMode: String?
    public var themeMode: String?
    public var accentColorChoice: String?
    public var petScale: Double?
    public var idleAnimationsEnabled: Bool?
    public var speechBubblesEnabled: Bool?
    public var soundEffectsEnabled: Bool?
    public var launchAtLoginEnabled: Bool?

    // Voice Assistant Settings
    public var voiceAssistantEnabled: Bool?
    public var selectedVoiceId: String?
    public var speechSpeed: Double? // 0.5 to 2.0 (default 1.0)
    public var speechVolume: Double? // 0.0 to 1.0 (default 1.0)
    public var speakAiResponses: Bool?

    // Walk Mode Settings
    public var walkSpeed: Double? // 0.5 to 2.0 (default 1.0)

    // Keyboard Shortcuts
    public var shortcutVoice: String? // e.g. "cmd+shift+space"
    public var shortcutTogglePet: String? // e.g. "cmd+shift+p"
    public var shortcutSettings: String? // e.g. "cmd+shift+,"

    // Camera & Vision Settings
    public var cameraAwarenessEnabled: Bool?
    public var cameraIntervalSeconds: Int? // 5, 10, 30 (default 10)
    public var stillnessAlertEnabled: Bool?

    // Screen Awareness Settings
    public var screenMonitoringEnabled: Bool?

    // Focus Guardian Settings
    public var focusNotificationsEnabled: Bool?
    public var hydrationReminderEnabled: Bool?
    public var hydrationIntervalMinutes: Int? // default 60

    // Multi-City Climate Vault
    public var weatherLocations: [SavedWeatherLocation] = []
    public var activeWeatherLocationId: UUID? = nil

    // Expressive Kinematics & Structural Model
    public var structuralModel: String? = nil
    public var walkGaitPreset: String? = nil

    // Performance & Appearance Stability
    public var performanceQuality: String? = "Balanced"
    public var isSafeMode: Bool? = false
    public var dynamicLightingEnabled: Bool? = false
    public var weatherEffectsEnabled: Bool? = false
    public var cpuReactiveGlowEnabled: Bool? = false
    public var dayNightTintEnabled: Bool? = false
    public var particlesEnabled: Bool? = false
    public var grayscaleTestMode: Bool? = false

    // Safe Mac Control & Action Assistant Settings
    public var macControlSettings: MacControlSettings? = MacControlSettings()
    public var actionHistory: [ActionHistoryItem]? = []

    public init(
        version: Int? = 1,
        currentChar: String = "cat",
        streak: Int = 0,
        lastChatDate: String = "",
        moodPoints: Double = 100.0,
        gameBest: Int = 0,
        activeTab: String? = "chat",
        selectedModel: String? = nil,
        history: [PetSavedMessage] = [],
        reminders: [PetReminder] = [],
        position: PetSavedPosition? = nil,
        featureVisibility: [String: Bool]? = nil,
        randomCharMode: String? = "fixed",
        themeMode: String? = "system",
        accentColorChoice: String? = nil,
        petScale: Double? = 1.0,
        idleAnimationsEnabled: Bool? = true,
        speechBubblesEnabled: Bool? = true,
        soundEffectsEnabled: Bool? = true,
        launchAtLoginEnabled: Bool? = true,
        voiceAssistantEnabled: Bool? = false,
        selectedVoiceId: String? = nil,
        speechSpeed: Double? = 1.0,
        speechVolume: Double? = 1.0,
        speakAiResponses: Bool? = true,
        walkSpeed: Double? = 1.0,
        shortcutVoice: String? = "⌘⇧Space",
        shortcutTogglePet: String? = "⌘⇧P",
        shortcutSettings: String? = "⌘⇧,",
        cameraAwarenessEnabled: Bool? = false,
        cameraIntervalSeconds: Int? = 10,
        stillnessAlertEnabled: Bool? = true,
        screenMonitoringEnabled: Bool? = false,
        focusNotificationsEnabled: Bool? = true,
        hydrationReminderEnabled: Bool? = true,
        hydrationIntervalMinutes: Int? = 60,
        weatherLocations: [SavedWeatherLocation] = [],
        activeWeatherLocationId: UUID? = nil,
        structuralModel: String? = nil,
        walkGaitPreset: String? = nil,
        macControlSettings: MacControlSettings? = MacControlSettings(),
        actionHistory: [ActionHistoryItem]? = []
    ) {
        self.version = version
        self.currentChar = currentChar
        self.streak = streak
        self.lastChatDate = lastChatDate
        self.moodPoints = moodPoints
        self.gameBest = gameBest
        self.activeTab = activeTab
        self.selectedModel = selectedModel
        self.history = history
        self.reminders = reminders
        self.position = position
        self.featureVisibility = featureVisibility
        self.randomCharMode = randomCharMode
        self.themeMode = themeMode
        self.accentColorChoice = accentColorChoice
        self.petScale = petScale
        self.idleAnimationsEnabled = idleAnimationsEnabled
        self.speechBubblesEnabled = speechBubblesEnabled
        self.soundEffectsEnabled = soundEffectsEnabled
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.voiceAssistantEnabled = voiceAssistantEnabled
        self.selectedVoiceId = selectedVoiceId
        self.speechSpeed = speechSpeed
        self.speechVolume = speechVolume
        self.speakAiResponses = speakAiResponses
        self.walkSpeed = walkSpeed
        self.shortcutVoice = shortcutVoice
        self.shortcutTogglePet = shortcutTogglePet
        self.shortcutSettings = shortcutSettings
        self.cameraAwarenessEnabled = cameraAwarenessEnabled
        self.cameraIntervalSeconds = cameraIntervalSeconds
        self.stillnessAlertEnabled = stillnessAlertEnabled
        self.screenMonitoringEnabled = screenMonitoringEnabled
        self.focusNotificationsEnabled = focusNotificationsEnabled
        self.hydrationReminderEnabled = hydrationReminderEnabled
        self.hydrationIntervalMinutes = hydrationIntervalMinutes
        self.weatherLocations = weatherLocations
        self.activeWeatherLocationId = activeWeatherLocationId
        self.structuralModel = structuralModel
        self.walkGaitPreset = walkGaitPreset
        self.macControlSettings = macControlSettings
        self.actionHistory = actionHistory
    }
}

// MARK: - Multi-City Climate Vault Models

public enum WeatherAtmosphere: String, Codable {
    case clearDay
    case goldenHour
    case nightClear
    case rain
    case snow
    case fog
    case thunderstorm
}

public struct SavedWeatherLocation: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var country: String?
    public var latitude: Double
    public var longitude: Double
    public var timezone: String?
    public var lastTemp: Int?
    public var lastConditionCode: Int?
    public var lastUpdated: String?

    public init(
        id: UUID = UUID(),
        name: String,
        country: String? = nil,
        latitude: Double,
        longitude: Double,
        timezone: String? = nil,
        lastTemp: Int? = nil,
        lastConditionCode: Int? = nil,
        lastUpdated: String? = nil
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.lastTemp = lastTemp
        self.lastConditionCode = lastConditionCode
        self.lastUpdated = lastUpdated
    }
}

public struct PetSavedMessage: Codable {
    public var role: String
    public var content: String
}

public struct PetSavedPosition: Codable {
    public var x: Double
    public var y: Double
}

// MARK: - Accent Color & Panel Anchor

public enum AccentColorChoice: String, CaseIterable, Codable, Identifiable {
    case purple, blue, cyan, green, pink, orange

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    public var color: Color {
        switch self {
        case .purple: return Color(red: 139/255, green: 92/255, blue: 246/255)
        case .blue: return Color(red: 59/255, green: 130/255, blue: 246/255)
        case .cyan: return Color(red: 6/255, green: 182/255, blue: 212/255)
        case .green: return Color(red: 34/255, green: 197/255, blue: 94/255)
        case .pink: return Color(red: 244/255, green: 114/255, blue: 182/255)
        case .orange: return Color(red: 249/255, green: 115/255, blue: 22/255)
        }
    }
}

public struct PanelAnchor: Equatable {
    public var isLeft: Bool
    public var isTop: Bool

    public init(isLeft: Bool = false, isTop: Bool = false) {
        self.isLeft = isLeft
        self.isTop = isTop
    }
}
