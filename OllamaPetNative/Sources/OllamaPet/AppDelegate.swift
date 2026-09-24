import Foundation
import AppKit
import SwiftUI
import ServiceManagement

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var reminderCheckTimer: Timer?
    private var globalHotKeyMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (LSUIElement mode)
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar status item
        setupStatusItem()

        // Setup global hotkey (Cmd+Shift+P)
        setupGlobalShortcut()

        // Setup Pet Window
        PetWindowController.shared.showWindow()

        // Start periodic reminder timer
        startReminderTimer()
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

    public func applicationWillTerminate(_ notification: Notification) {
        DataManager.shared.saveData()
    }
}
