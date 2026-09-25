import Foundation
import AppKit
import SwiftUI
import ServiceManagement
import UserNotifications

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var reminderCheckTimer: Timer?
    private var globalHotKeyMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (LSUIElement mode)
        NSApp.setActivationPolicy(.accessory)

        // Setup UserNotifications delegate & request auth (if running bundled)
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
            NotificationScheduler.shared.requestAuthorization()
        }

        // Setup menu bar status item
        setupStatusItem()

        // Setup global hotkey (Cmd+Shift+P)
        setupGlobalShortcut()

        // Safety recovery: check if app crashed during action execution
        if UserDefaults.standard.bool(forKey: "isExecutingMacAction") {
            UserDefaults.standard.removeObject(forKey: "isExecutingMacAction")
            PerformanceManager.shared.isSafeMode = true
            NSLog("[Safety] App previously terminated while executing an action. Starting in Safe Mode for stability.")
        }

        // Setup Pet Window
        PetWindowController.shared.showWindow()

        // Start periodic reminder timer
        startReminderTimer()

        // Check & Auto-start Ollama asynchronously in background
        Task {
            await OllamaClient.shared.connectOrStartIfNeeded()
        }

        // Check if running from /Applications (only for user downloads, delayed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.checkAndPromptToMoveToApplications()
        }
    }

    private var isInstalledInApplicationsFolder: Bool {
        let bundlePath = Bundle.main.bundleURL.standardized.path
        let systemApps = URL(fileURLWithPath: "/Applications").standardized.path
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardized.path
        return bundlePath.hasPrefix(systemApps) || bundlePath.hasPrefix(userApps)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "🐾"
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide Ollama Pet (⌘⇧P)", action: #selector(togglePetVisibility), keyEquivalent: "P"))
        
        if !isInstalledInApplicationsFolder {
            let moveItem = NSMenuItem(title: "📥 Move to Applications Folder...", action: #selector(promptMoveToApplicationsManually), keyEquivalent: "")
            menu.addItem(moveItem)
        }
        
        menu.addItem(NSMenuItem.separator())

        // Quick character switch menu
        let charSubmenu = NSMenu()
        for species in PetSpecies.allCases {
            let item = NSMenuItem(title: "\(species.icon) \(species.displayName)", action: #selector(changeSpeciesFromMenu(_:)), keyEquivalent: "")
            item.representedObject = species
            charSubmenu.addItem(item)
        }
        let charItem = NSMenuItem(title: "Characters", action: nil, keyEquivalent: "")
        charItem.submenu = charSubmenu
        menu.addItem(charItem)

        // Settings Window
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        menu.addItem(settingsItem)

        // Safe Mode Toggle
        let safeModeItem = NSMenuItem(title: "🛡️ Safe Mode (15 FPS)", action: #selector(toggleSafeModeMenu(_:)), keyEquivalent: "")
        safeModeItem.state = PerformanceManager.shared.isSafeMode ? .on : .off
        menu.addItem(safeModeItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at login toggle
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        if #available(macOS 13.0, *) {
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Ollama Pet", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func openSettingsWindow() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func toggleSafeModeMenu(_ sender: NSMenuItem) {
        PerformanceManager.shared.toggleSafeMode()
        sender.state = PerformanceManager.shared.isSafeMode ? .on : .off
    }

    @objc private func statusItemClicked() {
        PetWindowController.shared.toggleVisibility()
    }

    @objc private func togglePetVisibility() {
        PetWindowController.shared.toggleVisibility()
    }

    @objc private func changeSpeciesFromMenu(_ sender: NSMenuItem) {
        if let species = sender.representedObject as? PetSpecies {
            PetState.shared.setSpecies(species)
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                try? SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try? SMAppService.mainApp.register()
                sender.state = .on
            }
        }
    }

    @objc private func quitApp() {
        DataManager.shared.saveData()
        NSApp.terminate(nil)
    }

    private func setupGlobalShortcut() {
        // Initialize centralized ShortcutManager
        _ = ShortcutManager.shared
    }

    private func startReminderTimer() {
        reminderCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                DataManager.shared.checkReminders { reminder, isOverdue in
                    PetState.shared.showBubble("⏰ \(isOverdue ? "Overdue: " : "")\(reminder.text)", duration: 5.0)
                    SoundEffect.alert.play()
                }
            }
        }
    }

    // MARK: - Move to Applications Folder Support

    @objc private func promptMoveToApplicationsManually() {
        showMoveToApplicationsAlert(force: true)
    }

    private func checkAndPromptToMoveToApplications() {
        if isInstalledInApplicationsFolder { return }
        let path = Bundle.main.bundleURL.standardized.path
        // Skip prompt if running from dev repo, build artifacts, or tmp directories
        if path.contains("/.build") || path.contains("/build") || path.contains("/dist-native") || path.contains("/tmp/") {
            return
        }
        if UserDefaults.standard.bool(forKey: "SuppressMoveToApplicationsPrompt") { return }
        showMoveToApplicationsAlert(force: false)
    }

    private func showMoveToApplicationsAlert(force: Bool) {
        let alert = NSAlert()
        alert.messageText = "Move to Applications Folder?"
        alert.informativeText = "Ollama Pet can move itself to your Applications folder so it's easy to find in Spotlight and Launchpad."
        alert.addButton(withTitle: "Move to Applications Folder")
        alert.addButton(withTitle: "Do Not Move")
        
        if !force {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "Do not ask again"
        }
        alert.alertStyle = .informational

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if !force && alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: "SuppressMoveToApplicationsPrompt")
        }

        if response == .alertFirstButtonReturn {
            moveToApplicationsFolder(from: Bundle.main.bundleURL)
        }
    }

    private func moveToApplicationsFolder(from sourceURL: URL) {
        let fileManager = FileManager.default
        let appName = sourceURL.lastPathComponent
        let defaultAppsURL = URL(fileURLWithPath: "/Applications")
        var targetURL = defaultAppsURL.appendingPathComponent(appName)

        // Check if /Applications is writable, otherwise use user's ~/Applications
        if !fileManager.isWritableFile(atPath: defaultAppsURL.path) {
            let userAppsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            try? fileManager.createDirectory(at: userAppsURL, withIntermediateDirectories: true)
            targetURL = userAppsURL.appendingPathComponent(appName)
        }

        do {
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: sourceURL, to: targetURL)

            // Relaunch from Applications folder
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, error in
                DispatchQueue.main.async {
                    if error == nil {
                        // If source was in Downloads or Desktop, safely remove old duplicate
                        let srcPath = sourceURL.path
                        if srcPath.contains("/Downloads/") || srcPath.contains("/Desktop/") {
                            try? FileManager.default.removeItem(at: sourceURL)
                        }
                        exit(0)
                    } else {
                        let failAlert = NSAlert()
                        failAlert.messageText = "Failed to Launch From Applications"
                        failAlert.informativeText = error?.localizedDescription ?? "Could not launch application."
                        failAlert.runModal()
                    }
                }
            }
        } catch {
            let errAlert = NSAlert()
            errAlert.messageText = "Could Not Move Automatically"
            errAlert.informativeText = "\(error.localizedDescription)\n\nYou can manually drag OllamaPet.app into your Applications folder."
            errAlert.runModal()
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    public func applicationWillTerminate(_ notification: Notification) {
        DataManager.shared.saveData()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Display banner, sound, and badge even when app is active/foreground
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            PetWindowController.shared.showWindow()
        }
        completionHandler()
    }
}
