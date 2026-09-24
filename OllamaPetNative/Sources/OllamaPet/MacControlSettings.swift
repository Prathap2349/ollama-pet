import Foundation

// MARK: - Mac Control Settings Data Model

public struct MacControlSettings: Codable, Equatable {
    public var macControlEnabled: Bool = false
    public var voiceControlEnabled: Bool = true
    public var openAppsEnabled: Bool = true
    public var openURLsEnabled: Bool = true
    public var webSearchEnabled: Bool = true
    public var remindersEnabled: Bool = true
    public var calendarEnabled: Bool = true
    public var whatsappEnabled: Bool = true
    public var messagesEnabled: Bool = true
    public var shortcutsEnabled: Bool = false
    public var alwaysConfirmExternalActions: Bool = true
    public var showActionStatus: Bool = true
    public var approvedShortcuts: [String] = ["Study Mode", "Morning Routine", "Focus Session"]

    public init(
        macControlEnabled: Bool = false,
        voiceControlEnabled: Bool = true,
        openAppsEnabled: Bool = true,
        openURLsEnabled: Bool = true,
        webSearchEnabled: Bool = true,
        remindersEnabled: Bool = true,
        calendarEnabled: Bool = true,
        whatsappEnabled: Bool = true,
        messagesEnabled: Bool = true,
        shortcutsEnabled: Bool = false,
        alwaysConfirmExternalActions: Bool = true,
        showActionStatus: Bool = true,
        approvedShortcuts: [String] = ["Study Mode", "Morning Routine", "Focus Session"]
    ) {
        self.macControlEnabled = macControlEnabled
        self.voiceControlEnabled = voiceControlEnabled
        self.openAppsEnabled = openAppsEnabled
        self.openURLsEnabled = openURLsEnabled
        self.webSearchEnabled = webSearchEnabled
        self.remindersEnabled = remindersEnabled
        self.calendarEnabled = calendarEnabled
        self.whatsappEnabled = whatsappEnabled
        self.messagesEnabled = messagesEnabled
        self.shortcutsEnabled = shortcutsEnabled
        self.alwaysConfirmExternalActions = alwaysConfirmExternalActions
        self.showActionStatus = showActionStatus
        self.approvedShortcuts = approvedShortcuts
    }
}
