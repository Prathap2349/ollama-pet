import Foundation
import AppKit

// MARK: - Robust KeyCombo Model

public struct KeyCombo: Equatable, Hashable, Codable {
    public var modifiers: NSEvent.ModifierFlags
    public var keyCode: UInt16
    public var displayString: String

    public init(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, displayString: String? = nil) {
        self.modifiers = Self.normalizeModifiers(modifiers)
        self.keyCode = keyCode
        if let display = displayString, !display.isEmpty {
            self.displayString = display
        } else {
            self.displayString = Self.buildDisplayString(modifiers: self.modifiers, keyCode: keyCode)
        }
    }

    public static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        return lhs.keyCode == rhs.keyCode &&
            lhs.normalizedRawModifiers == rhs.normalizedRawModifiers
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(normalizedRawModifiers)
    }

    public var normalizedRawModifiers: UInt {
        return Self.normalizeModifiers(modifiers).rawValue
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case modifiers
        case keyCode
        case displayString
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMods = try container.decode(UInt.self, forKey: .modifiers)
        self.keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        self.modifiers = Self.normalizeModifiers(NSEvent.ModifierFlags(rawValue: rawMods))
        let display = try container.decode(String.self, forKey: .displayString)
        self.displayString = display.isEmpty ? Self.buildDisplayString(modifiers: self.modifiers, keyCode: self.keyCode) : display
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(displayString, forKey: .displayString)
    }

    // MARK: - Normalization & Display

    public static let standardModifierMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    public static func normalizeModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        return flags.intersection(standardModifierMask)
    }

    public static func buildDisplayString(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        let norm = normalizeModifiers(modifiers)
        var parts: [String] = []
        // Standard macOS ordering: Control ⌃, Option ⌥, Shift ⇧, Command ⌘
        if norm.contains(.control) { parts.append("⌃") }
        if norm.contains(.option) { parts.append("⌥") }
        if norm.contains(.shift) { parts.append("⇧") }
        if norm.contains(.command) { parts.append("⌘") }

        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)
        return parts.joined()
    }

    public static func fromEvent(_ event: NSEvent) -> KeyCombo? {
        let code = event.keyCode
        // Reject modifier keys themselves
        if isModifierOnly(code) { return nil }

        let normMods = normalizeModifiers(event.modifierFlags)
        // Must contain at least one modifier
        if normMods.isEmpty { return nil }

        let display = buildDisplayString(modifiers: normMods, keyCode: code)
        return KeyCombo(modifiers: normMods, keyCode: code, displayString: display)
    }

    public static func isModifierOnly(_ code: UInt16) -> Bool {
        // macOS modifier key codes
        switch code {
        case 54, 55: return true // Command
        case 56, 60: return true // Shift
        case 58, 61: return true // Option
        case 59, 62: return true // Control
        case 57: return true     // Caps Lock
        case 63: return true     // Function (fn)
        default: return false
        }
    }

    // MARK: - Parsing

    public static func parse(_ string: String) -> KeyCombo? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Check for serialized format "rawMods:keyCode" or "displayString"
        let components = trimmed.components(separatedBy: ":")
        if components.count == 3,
           let rawMods = UInt(components[0]),
           let code = UInt16(components[1]) {
            let mods = normalizeModifiers(NSEvent.ModifierFlags(rawValue: rawMods))
            return KeyCombo(modifiers: mods, keyCode: code, displayString: components[2])
        }

        // Natural parse from symbol string
        var flags: NSEvent.ModifierFlags = []
        let lower = trimmed.lowercased()

        if trimmed.contains("⌃") || lower.contains("ctrl") || lower.contains("control") {
            flags.insert(.control)
        }
        if trimmed.contains("⌥") || lower.contains("opt") || lower.contains("option") || lower.contains("alt") {
            flags.insert(.option)
        }
        if trimmed.contains("⇧") || lower.contains("shift") {
            flags.insert(.shift)
        }
        if trimmed.contains("⌘") || lower.contains("cmd") || lower.contains("command") {
            flags.insert(.command)
        }

        // Clean out modifier tokens to isolate key character
        var keyPart = trimmed
            .replacingOccurrences(of: "⌃", with: "")
            .replacingOccurrences(of: "⌥", with: "")
            .replacingOccurrences(of: "⇧", with: "")
            .replacingOccurrences(of: "⌘", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if keyPart.isEmpty {
            // Check lower-cased tokens
            let tokens = lower
                .replacingOccurrences(of: "ctrl", with: "")
                .replacingOccurrences(of: "control", with: "")
                .replacingOccurrences(of: "opt", with: "")
                .replacingOccurrences(of: "option", with: "")
                .replacingOccurrences(of: "alt", with: "")
                .replacingOccurrences(of: "shift", with: "")
                .replacingOccurrences(of: "cmd", with: "")
                .replacingOccurrences(of: "command", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            keyPart = tokens
        }

        guard let code = stringToKeyCode(keyPart) else {
            return nil
        }

        let display = buildDisplayString(modifiers: flags, keyCode: code)
        return KeyCombo(modifiers: flags, keyCode: code, displayString: display)
    }

    public var serialized: String {
        return "\(modifiers.rawValue):\(keyCode):\(displayString)"
    }

    // MARK: - KeyCode Mapping

    public static func keyCodeToString(_ code: UInt16) -> String {
        switch code {
        // Letters
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"

        // Numbers
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

        // Whitespace & Navigation
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"

        // Punctuation & Symbols
        case 43: return ","
        case 47: return "."
        case 44: return "/"
        case 41: return ";"
        case 39: return "'"
        case 33: return "["
        case 30: return "]"
        case 42: return "\\"
        case 27: return "-"
        case 24: return "="
        case 50: return "`"

        // Function Keys
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"

        default: return "Key(\(code))"
        }
    }

    public static func stringToKeyCode(_ str: String) -> UInt16? {
        let upper = str.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch upper {
        case "A": return 0
        case "S": return 1
        case "D": return 2
        case "F": return 3
        case "H": return 4
        case "G": return 5
        case "Z": return 6
        case "X": return 7
        case "C": return 8
        case "V": return 9
        case "B": return 11
        case "Q": return 12
        case "W": return 13
        case "E": return 14
        case "R": return 15
        case "Y": return 16
        case "T": return 17
        case "O": return 31
        case "U": return 32
        case "I": return 34
        case "P": return 35
        case "L": return 37
        case "J": return 38
        case "K": return 40
        case "N": return 45
        case "M": return 46

        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "5": return 23
        case "6": return 22
        case "7": return 26
        case "8": return 28
        case "9": return 25
        case "0": return 29

        case "SPACE": return 49
        case "RETURN", "ENTER": return 36
        case "TAB": return 48
        case "DELETE", "BACKSPACE": return 51
        case "ESC", "ESCAPE": return 53
        case "LEFT", "←": return 123
        case "RIGHT", "→": return 124
        case "DOWN", "↓": return 125
        case "UP", "↑": return 126

        case ",": return 43
        case ".": return 47
        case "/": return 44
        case ";": return 41
        case "'": return 39
        case "[": return 33
        case "]": return 30
        case "\\": return 42
        case "-": return 27
        case "=": return 24
        case "`": return 50

        case "F1": return 122
        case "F2": return 120
        case "F3": return 99
        case "F4": return 118
        case "F5": return 96
        case "F6": return 97
        case "F7": return 98
        case "F8": return 100
        case "F9": return 101
        case "F10": return 109
        case "F11": return 103
        case "F12": return 111

        default:
            return nil
        }
    }
}

// MARK: - Centralized Shortcut Manager

@MainActor
public class ShortcutManager: ObservableObject {
    public static let shared = ShortcutManager()

    // Default shortcuts
    @Published public var voiceShortcut: KeyCombo = KeyCombo(modifiers: [.command, .shift], keyCode: 9, displayString: "⌘⇧V")
    @Published public var togglePetShortcut: KeyCombo = KeyCombo(modifiers: [.command, .shift], keyCode: 35, displayString: "⌘⇧P")
    @Published public var settingsShortcut: KeyCombo = KeyCombo(modifiers: [.command, .shift], keyCode: 43, displayString: "⌘⇧,")

    @Published public var recordingAction: String? = nil
    @Published public var conflictMessage: String? = nil
    @Published public var isAccessibilityGranted: Bool = false

    private var globalMonitor: Any?
    private var localMonitor: Any?

    public init() {
        checkAccessibilityPermission()
        loadShortcuts()
        registerMonitors()
    }

    public func checkAccessibilityPermission() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        self.isAccessibilityGranted = AXIsProcessTrustedWithOptions(opts)
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
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
        if action != "voice" && combo == voiceShortcut {
            conflictMessage = "⚠️ Shortcut already assigned to Voice Assistant (\(voiceShortcut.displayString))."
            return false
        }
        if action != "togglePet" && combo == togglePetShortcut {
            conflictMessage = "⚠️ Shortcut already assigned to Toggle Pet Window (\(togglePetShortcut.displayString))."
            return false
        }
        if action != "settings" && combo == settingsShortcut {
            conflictMessage = "⚠️ Shortcut already assigned to Settings (\(settingsShortcut.displayString))."
            return false
        }

        switch action {
        case "voice":
            voiceShortcut = combo
            DataManager.shared.setShortcutVoice(combo.serialized)
        case "togglePet":
            togglePetShortcut = combo
            DataManager.shared.setShortcutTogglePet(combo.serialized)
        case "settings":
            settingsShortcut = combo
            DataManager.shared.setShortcutSettings(combo.serialized)
        default:
            break
        }

        recordingAction = nil
        conflictMessage = nil
        return true
    }

    private func matchesModifiers(_ a: NSEvent.ModifierFlags, _ b: NSEvent.ModifierFlags) -> Bool {
        return KeyCombo.normalizeModifiers(a).rawValue == KeyCombo.normalizeModifiers(b).rawValue
    }

    public func registerMonitors() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }

        // Global monitor (fires when another app is focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor (fires when OllamaPet is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            if let action = self.recordingAction {
                // ESC cancels recording without changing current shortcut
                if event.keyCode == 53 {
                    self.cancelRecording()
                    return nil
                }

                // Reject modifier-only press (e.g. user just hit Command key)
                if KeyCombo.isModifierOnly(event.keyCode) {
                    return nil
                }

                // If user pressed a key without modifiers, alert/ignore
                let norm = KeyCombo.normalizeModifiers(event.modifierFlags)
                if norm.isEmpty {
                    self.conflictMessage = "⚠️ Shortcuts must include at least one modifier (⌘, ⌥, ⌃, ⇧)."
                    return nil
                }

                if let combo = KeyCombo.fromEvent(event) {
                    if self.assignShortcut(combo, to: action) {
                        return nil
                    }
                }
                return nil
            }

            if self.handleKeyEvent(event) {
                return nil
            }

            return event
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let code = event.keyCode
        let mods = event.modifierFlags

        // Voice Assistant Hotkey
        if code == voiceShortcut.keyCode && matchesModifiers(mods, voiceShortcut.modifiers) {
            Task { @MainActor in
                VoiceAssistant.shared.togglePushToTalk()
            }
            return true
        }

        // Toggle Pet Hotkey
        if code == togglePetShortcut.keyCode && matchesModifiers(mods, togglePetShortcut.modifiers) {
            Task { @MainActor in
                PetWindowController.shared.toggleVisibility()
            }
            return true
        }

        // Settings Hotkey
        if code == settingsShortcut.keyCode && matchesModifiers(mods, settingsShortcut.modifiers) {
            Task { @MainActor in
                SettingsWindowController.shared.showWindow()
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
