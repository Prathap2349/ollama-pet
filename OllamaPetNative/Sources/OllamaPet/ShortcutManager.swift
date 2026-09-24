import Foundation
import AppKit

public struct KeyCombo: Equatable, Hashable {
    public var modifiers: NSEvent.ModifierFlags
    public var keyCode: UInt16
    public var displayString: String

    public init(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, displayString: String) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.displayString = displayString
    }

    public static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        return lhs.keyCode == rhs.keyCode && lhs.modifiers.rawValue == rhs.modifiers.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers.rawValue)
    }

    public static func parse(_ string: String) -> KeyCombo? {
        let str = string.lowercased()
        var flags: NSEvent.ModifierFlags = []

        if str.contains("⌘") || str.contains("cmd") || str.contains("command") {
            flags.insert(.command)
        }
        if str.contains("⇧") || str.contains("shift") {
            flags.insert(.shift)
        }
        if str.contains("⌥") || str.contains("alt") || str.contains("opt") {
            flags.insert(.option)
        }
        if str.contains("⌃") || str.contains("ctrl") || str.contains("control") {
            flags.insert(.control)
        }

        // Determine key code
        var code: UInt16 = 35 // default 'p'
        if str.contains("space") {
            code = 49
        } else if str.contains(",") {
            code = 43
        } else if str.contains("p") {
            code = 35
        } else if str.contains("v") {
            code = 9
        } else if str.contains("o") {
            code = 31
        }

        return KeyCombo(modifiers: flags, keyCode: code, displayString: string)
    }

    public static func fromEvent(_ event: NSEvent) -> KeyCombo {
        var flags: NSEvent.ModifierFlags = []
        if event.modifierFlags.contains(.command) { flags.insert(.command) }
        if event.modifierFlags.contains(.shift) { flags.insert(.shift) }
        if event.modifierFlags.contains(.option) { flags.insert(.option) }
        if event.modifierFlags.contains(.control) { flags.insert(.control) }

        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyName = keyCodeToString(event.keyCode)
        parts.append(keyName)

        let display = parts.joined()
        return KeyCombo(modifiers: flags, keyCode: event.keyCode, displayString: display)
    }

    public static func keyCodeToString(_ code: UInt16) -> String {
        switch code {
        case 49: return "Space"
        case 43: return ","
        case 35: return "P"
        case 9: return "V"
        case 31: return "O"
        case 36: return "Return"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        default: return "Key(\(code))"
        }
    }
}

@MainActor
public class ShortcutManager: ObservableObject {
    public static let shared = ShortcutManager()

    @Published public var voiceShortcut: KeyCombo = KeyCombo(modifiers: [.command, .shift], keyCode: 49, displayString: "⌘⇧Space")
    @Published public var togglePetShortcut: KeyCombo = KeyCombo(modifiers: [.command, .shift], keyCode: 35, displayString: "⌘⇧P")
    @Published public var settingsShortcut: KeyCombo = KeyCombo(modifiers: [.command, .shift], keyCode: 43, displayString: "⌘⇧,")

    @Published public var recordingAction: String? = nil
    @Published public var conflictMessage: String? = nil

    private var globalMonitor: Any?
    private var localMonitor: Any?

    public init() {
        loadShortcuts()
        registerMonitors()
    }

    public func loadShortcuts() {
        let data = DataManager.shared.savedData
        if let v = data.shortcutVoice, let combo = KeyCombo.parse(v) {
            voiceShortcut = combo
        }
        if let p = data.shortcutTogglePet, let combo = KeyCombo.parse(p) {
            togglePetShortcut = combo
        }
        if let s = data.shortcutSettings, let combo = KeyCombo.parse(s) {
            settingsShortcut = combo
        }
    }

    public func startRecording(action: String) {
        recordingAction = action
        conflictMessage = nil
    }

    public func cancelRecording() {
        recordingAction = nil
        conflictMessage = nil
    }

    public func assignShortcut(_ combo: KeyCombo, to action: String) -> Bool {
        // Validate conflicts
        if action != "voice" && combo.keyCode == voiceShortcut.keyCode && matchesModifiers(combo.modifiers, voiceShortcut.modifiers) {
            conflictMessage = "⚠️ Shortcut already in use.\nAssigned to: Voice Assistant"
            return false
        }
        if action != "togglePet" && combo.keyCode == togglePetShortcut.keyCode && matchesModifiers(combo.modifiers, togglePetShortcut.modifiers) {
            conflictMessage = "⚠️ Shortcut already in use.\nAssigned to: Open Pet"
            return false
        }
        if action != "settings" && combo.keyCode == settingsShortcut.keyCode && matchesModifiers(combo.modifiers, settingsShortcut.modifiers) {
            conflictMessage = "⚠️ Shortcut already in use.\nAssigned to: Open Settings"
            return false
        }

        switch action {
        case "voice":
            voiceShortcut = combo
            DataManager.shared.setShortcutVoice(combo.displayString)
        case "togglePet":
            togglePetShortcut = combo
            DataManager.shared.setShortcutTogglePet(combo.displayString)
        case "settings":
            settingsShortcut = combo
            DataManager.shared.setShortcutSettings(combo.displayString)
        default:
            break
        }

        recordingAction = nil
        conflictMessage = nil
        return true
    }

    private func matchesModifiers(_ a: NSEvent.ModifierFlags, _ b: NSEvent.ModifierFlags) -> Bool {
        let mask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        return a.intersection(mask) == b.intersection(mask)
    }

    private func registerMonitors() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self = self {
                if self.recordingAction != nil {
                    // Currently capturing a new shortcut
                    let combo = KeyCombo.fromEvent(event)
                    _ = self.assignShortcut(combo, to: self.recordingAction!)
                    return nil
                }
                if self.handleKeyEvent(event) {
                    return nil
                }
            }
            return event
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Voice Assistant Hotkey
        if event.keyCode == voiceShortcut.keyCode && matchesModifiers(event.modifierFlags, voiceShortcut.modifiers) {
            Task { @MainActor in
                VoiceAssistant.shared.togglePushToTalk()
            }
            return true
        }

        // Toggle Pet Hotkey
        if event.keyCode == togglePetShortcut.keyCode && matchesModifiers(event.modifierFlags, togglePetShortcut.modifiers) {
            Task { @MainActor in
                PetWindowController.shared.toggleVisibility()
            }
            return true
        }

        // Settings Hotkey
        if event.keyCode == settingsShortcut.keyCode && matchesModifiers(event.modifierFlags, settingsShortcut.modifiers) {
            Task { @MainActor in
                let petState = PetState.shared
                if !petState.isChatOpen {
                    petState.isChatOpen = true
                    PetWindowController.shared.adjustWindowSize(open: true)
                }
                petState.activeTab = "settings"
            }
            return true
        }

        return false
    }

    deinit {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
    }
}
