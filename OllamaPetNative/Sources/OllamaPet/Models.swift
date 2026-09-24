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
        position: PetSavedPosition? = nil
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
