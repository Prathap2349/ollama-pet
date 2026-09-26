import Foundation
import AppKit
import SwiftUI
import ServiceManagement
import UserNotifications

// MARK: - Startup Diagnostics

/// Lightweight structured startup log. Every stage writes here so install.sh
/// diagnostic mode and the terminal can report exactly which stage failed.
public final class StartupLog {
    public static let shared = StartupLog()
    private init() {}

    private(set) var entries: [(stage: Int, label: String, status: String)] = []
    private var nextStage = 1

    @discardableResult
    func begin(_ label: String) -> Int {
        let stage = nextStage
        nextStage += 1
        entries.append((stage, label, "started"))
        NSLog("[Startup %02d] %@", stage, label)
        return stage
    }

    func complete(_ stage: Int) {
        if let idx = entries.firstIndex(where: { $0.stage == stage }) {
            entries[idx] = (stage, entries[idx].label, "ok")
        }
        NSLog("[Startup %02d] ✓ done", stage)
    }

    func fail(_ stage: Int, reason: String) {
        if let idx = entries.firstIndex(where: { $0.stage == stage }) {
            entries[idx] = (stage, entries[idx].label, "FAILED: \(reason)")
        }
        NSLog("[Startup ERROR] Stage %02d FAILED — %@", stage, reason)
    }
}

// MARK: - AppDelegate

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var reminderCheckTimer: Timer?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let log = StartupLog.shared

        // ── Stage 1: Accessory policy ──────────────────────────────────────
        let s1 = log.begin("NSApplication activation policy (.accessory)")
        NSApp.setActivationPolicy(.accessory)
        log.complete(s1)

        // ── Stage 2: Notifications delegate ────────────────────────────────
        let s2 = log.begin("UserNotifications delegate setup")
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
            // Request authorization asynchronously — denial must never crash startup
            NotificationScheduler.shared.requestAuthorization()
        }
        log.complete(s2)

        // ── Stage 3: DataManager (load saved data) ─────────────────────────
        let s3 = log.begin("DataManager initialization")
        _ = DataManager.shared   // trigger load; errors are caught internally
        log.complete(s3)

        // ── Stage 4: Menu bar status item ──────────────────────────────────
        let s4 = log.begin("Status item (menu bar icon)")
        do {
            try setupStatusItemSafe()
            log.complete(s4)
        } catch {
            log.fail(s4, reason: error.localizedDescription)
            // Status item failure is non-fatal; app continues
        }

        // ── Stage 5: Safety recovery ───────────────────────────────────────
        let s5 = log.begin("Safety recovery check")
        if UserDefaults.standard.bool(forKey: "isExecutingMacAction") {
            UserDefaults.standard.removeObject(forKey: "isExecutingMacAction")
            PerformanceManager.shared.isSafeMode = true
            NSLog("[Safety] App previously terminated while executing a Mac action. Starting in Safe Mode.")
        }
        log.complete(s5)

        // ── Stage 6: Global shortcut manager ──────────────────────────────
        let s6 = log.begin("ShortcutManager initialization")
        // ShortcutManager.registerMonitors() calls NSEvent.addGlobalMonitorForEvents
        // which is safe regardless of Accessibility permission — it returns nil
        // when Accessibility is denied but never crashes.
        _ = ShortcutManager.shared
        log.complete(s6)

        // ── Stage 7: Pet window ────────────────────────────────────────────
        let s7 = log.begin("PetWindowController.showWindow()")
        guard NSScreen.main != nil else {
            log.fail(s7, reason: "NSScreen.main is nil — no display available at launch")
            // Still continue; window will be created when a screen becomes available
            NSLog("[Startup WARNING] No main screen at launch — pet window deferred")
            finishStartup(log: log)
            return
        }
        PetWindowController.shared.showWindow()
        log.complete(s7)

        finishStartup(log: log)
    }

    private func finishStartup(log: StartupLog) {
        // ── Stage 8: Reminder timer ────────────────────────────────────────
        let s8 = log.begin("Reminder check timer")
        startReminderTimer()
        log.complete(s8)

        // ── Stage 9: Ollama connection (background, never blocks startup) ──
        let s9 = log.begin("Ollama background connection task")
        Task {
            await OllamaClient.shared.connectOrStartIfNeeded()
        }
        log.complete(s9)

        // ── Stage 10: Move-to-Applications prompt (deferred, non-blocking) ─
        let s10 = log.begin("Move-to-Applications check (deferred)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.checkAndPromptToMoveToApplications()
        }
        log.complete(s10)

        log.begin("Application startup complete ✓")
        NSLog("[Startup] All stages complete. Application is running.")
    }

    // MARK: - Status Item Setup

    private func setupStatusItemSafe() throws {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else {
            throw NSError(domain: "OllamaPet", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create status item button"])
        }
        button.title = "🐾"
        button.action = #selector(statusItemClicked)
        button.target = self

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

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        menu.addItem(settingsItem)

        let safeModeItem = NSMenuItem(title: "🛡️ Safe Mode (15 FPS)", action: #selector(toggleSafeModeMenu(_:)), keyEquivalent: "")
        safeModeItem.state = PerformanceManager.shared.isSafeMode ? .on : .off
        menu.addItem(safeModeItem)

        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        if #available(macOS 13.0, *) {
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Ollama Pet", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Helpers

    private var isInstalledInApplicationsFolder: Bool {
        let bundlePath = Bundle.main.bundleURL.standardized.path
        let systemApps = URL(fileURLWithPath: "/Applications").standardized.path
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardized.path
        return bundlePath.hasPrefix(systemApps) || bundlePath.hasPrefix(userApps)
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

    private func startReminderTimer() {
        reminderCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                DataManager.shared.checkReminders { reminder, isOverdue in
                    PetState.shared.setTemporaryMood(.concerned, duration: 4.5)
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

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, error in
                DispatchQueue.main.async {
                    if error == nil {
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
