import Foundation
import SwiftUI
import AppKit

struct ChatView: View {
    @ObservedObject var petState = PetState.shared
    @ObservedObject var ollamaClient = OllamaClient.shared
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var sysMon = SystemMonitor.shared
    @ObservedObject var wx = WeatherService.shared
    @ObservedObject var music = MusicManager.shared
    @ObservedObject var voiceAssistant = VoiceAssistant.shared
    @ObservedObject var shortcutManager = ShortcutManager.shared
    @ObservedObject var visionGuardian = VisionGuardian.shared
    @ObservedObject var screenGuardian = ScreenGuardian.shared
    @ObservedObject var focusGuardian = FocusGuardian.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared

    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var lastFailedPrompt: String? = nil
    @State private var errorMessage: String? = nil

    // Weather input
    @State private var weatherCityInput: String = ""

    // Reminders input
    @State private var reminderText: String = ""
    @State private var reminderMinutes: Int = 5

    // Settings state
    @State private var testingOllama: Bool = false
    @State private var testOllamaResult: String? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header: Ollama Status + Tabs + Close
                headerBar

                // Tab Content
                Group {
                    switch petState.activeTab {
                    case "chat":
                        chatTabContent
                    case "weather":
                        weatherTabContent
                    case "system":
                        systemTabContent
                    case "game":
                        gameTabContent
                    case "remind":
                        remindTabContent
                    case "settings":
                        chatTabContent
                    default:
                        chatTabContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .offset(y: 4)))
                .id(petState.activeTab)
            }

            // Native Action Confirmation Dialog
            ActionConfirmationView()
        }
        .animation(.easeInOut(duration: 0.18), value: petState.activeTab)
        .frame(width: 360, height: 466)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 15/255, green: 17/255, blue: 26/255).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(petState.currentSpecies.accentColor.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 18, x: 0, y: 8)
        )
        .onAppear {
            loadMessages()
            Task {
                await ollamaClient.checkHealth(preferredModel: dataManager.savedData.selectedModel)
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(petState.currentSpecies.icon)
                        .font(.system(size: 14))
                    Text("Ollama Pet")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                HStack(spacing: 5) {
                    Circle()
                        .fill(headerStatusColor)
                        .frame(width: 7, height: 7)

                    Text(ollamaClient.statusMessage)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))

                if !ollamaClient.isOnline {
                    Button(action: {
                        Task {
                            await ollamaClient.connectOrStartIfNeeded(preferredModel: dataManager.savedData.selectedModel)
                        }
                    }) {
                        Text(ollamaClient.connectionState.isConnecting ? "Starting..." : "Start")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange.opacity(0.7)))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: {
                    SettingsWindowController.shared.showWindow()
                    SoundEffect.click.play()
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(Color.white.opacity(0.65))
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button(action: {
                    PetWindowController.shared.closePanel()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.55))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Close Panel")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // Tabs Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if dataManager.isFeatureVisible("chat") {
                        tabButton(title: "Chat", id: "chat", icon: "bubble.left.fill")
                    }
                    if dataManager.isFeatureVisible("remind") {
                        tabButton(title: "Reminders", id: "remind", icon: "clock.fill")
                    }
                    if dataManager.isFeatureVisible("game") {
                        tabButton(title: "Focus", id: "game", icon: "target")
                    }
                    if dataManager.isFeatureVisible("weather") {
                        tabButton(title: "Weather", id: "weather", icon: "cloud.sun.fill")
                    }
                    if dataManager.isFeatureVisible("system") {
                        tabButton(title: "System", id: "system", icon: "cpu.fill")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .background(Color.white.opacity(0.04))
    }

    private var headerStatusColor: Color {
        switch ollamaClient.connectionState {
        case .connected:
            return ollamaClient.installedModels.isEmpty ? .orange : .green
        case .connecting, .reconnecting, .checking:
            return .orange
        case .failed:
            return .red
        }
    }

    private func tabButton(title: String, id: String, icon: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                petState.activeTab = id
            }
            dataManager.savedData.activeTab = id
            dataManager.saveData()
            SoundEffect.click.play()
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                petState.activeTab == id
                    ? petState.currentSpecies.accentColor.opacity(0.35)
                    : Color.white.opacity(0.08)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(petState.activeTab == id ? petState.currentSpecies.accentColor.opacity(0.55) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .foregroundColor(petState.activeTab == id ? .white : Color.white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat Tab
    private var chatTabContent: some View {
        VStack(spacing: 0) {
            // Message List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if messages.isEmpty {
                            if !ollamaClient.isOnline {
                                VStack(spacing: 8) {
                                    Text("🔴 Ollama is Offline")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.orange)
                                    Text("Start Ollama service to chat with \(petState.currentSpecies.displayName).")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                    Button(action: {
                                        Task {
                                            await ollamaClient.connectOrStartIfNeeded(preferredModel: dataManager.savedData.selectedModel)
                                        }
                                    }) {
                                        Text("Start Ollama")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(petState.currentSpecies.accentColor))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                            } else {
                                // Welcoming Onboarding Banner
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(petState.currentSpecies.accentColor.opacity(0.18))
                                            .frame(width: 52, height: 52)
                                        Text(petState.currentSpecies.icon)
                                            .font(.system(size: 28))
                                    }
                                    .padding(.top, 8)

                                    VStack(spacing: 3) {
                                        Text("Hi, I'm \(petState.currentSpecies.displayName)!")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Your local AI desktop companion")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.white.opacity(0.6))
                                    }

                                    VStack(spacing: 6) {
                                        Text("SUGGESTED PROMPTS")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Color.white.opacity(0.4))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 4)

                                        suggestionPill("What can you help me with?")
                                        suggestionPill("Open Safari")
                                        suggestionPill("Set a 25m focus timer")
                                        suggestionPill("How is the weather today?")
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.top, 4)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
                                .padding(.horizontal, 14)
                                .padding(.top, 8)
                            }
                        }

                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }

                        if petState.isThinking && (messages.isEmpty || messages.last?.role == "user") {
                            HStack {
                                TypingDotsView(accentColor: petState.currentSpecies.accentColor)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                            .id("thinking_indicator")
                        }

                        if let err = errorMessage {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("⚠️ Request Failed: \(err)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.red)

                                if let failedText = lastFailedPrompt {
                                    Button(action: {
                                        retryMessage(failedText)
                                    }) {
                                        Text("↻ Retry message")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.red.opacity(0.2))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(8)
                            .padding(.horizontal, 10)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Input Bar
            HStack(spacing: 8) {
                // Voice Assistant Push-to-Talk button
                Button(action: {
                    voiceAssistant.togglePushToTalk()
                }) {
                    Image(systemName: voiceAssistant.state == .listening ? "waveform.circle.fill" : (voiceAssistant.isSpeaking ? "speaker.wave.3.fill" : "mic.circle.fill"))
                        .font(.system(size: 20))
                        .foregroundColor(voiceAssistant.state == .listening ? Color.red : (voiceAssistant.isSpeaking ? petState.currentSpecies.accentColor : Color.white.opacity(0.7)))
                }
                .buttonStyle(.plain)
                .help("Push-to-Talk Voice Assistant (\(ShortcutManager.shared.voiceShortcut.displayString))")

                TextField(voiceAssistant.state == .listening ? "Listening to your voice..." : "Message \(petState.currentSpecies.displayName)...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .onSubmit {
                        sendMessage()
                    }

                // Stop speaking button if currently reading out loud
                if voiceAssistant.isSpeaking {
                    Button(action: {
                        voiceAssistant.stopSpeaking()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help("Stop Speaking")
                }

                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.3) : petState.currentSpecies.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || petState.isThinking)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))

            // Footer action bar with companion identity badge
            HStack {
                HStack(spacing: 5) {
                    Text(petState.currentSpecies.icon)
                        .font(.system(size: 11))
                    Text("\(petState.currentSpecies.displayName) · Level \(petState.level)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                }

                Spacer()

                Button("Walk") {
                    startWalkAcrossScreen()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))

                Button("Export") {
                    exportChat()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))

                Button("Clear") {
                    clearChat()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.red.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.25))
        }
    }

    private func suggestionPill(_ prompt: String) -> some View {
        Button(action: {
            inputText = prompt
            sendMessage()
        }) {
            HStack {
                Image(systemName: "sparkle")
                    .font(.system(size: 9))
                    .foregroundColor(petState.currentSpecies.accentColor)
                Text(prompt)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage) -> some View {
        if !msg.content.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                if msg.role == "user" {
                    Spacer()
                    Text(msg.content)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(petState.currentSpecies.accentColor.opacity(0.45))
                        .cornerRadius(12)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(msg.content)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(msg.content, forType: .string)
                            petState.showBubble("Copied! ⎘", duration: 1.0)
                        }) {
                            Text("⎘ copy")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 10)
        }
    }

    // MARK: - Weather Tab
    private var weatherTabContent: some View {
        VStack(spacing: 8) {
            // City Search & Add Drawer Header
            HStack(spacing: 6) {
                TextField("Add city to vault (e.g. Kyoto, London)...", text: $weatherCityInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(7)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .onSubmit {
                        addWeatherCity()
                    }

                Button(action: {
                    addWeatherCity()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(weatherCityInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.3) : petState.currentSpecies.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(weatherCityInput.trimmingCharacters(in: .whitespaces).isEmpty || wx.isLoading)

                if wx.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Active Weather Atmospheric Banner
            if let w = wx.weather {
                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.cityName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(w.description)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(petState.currentSpecies.accentColor)
                        }
                        Spacer()
                        Text(w.icon)
                            .font(.system(size: 28))
                        Text("\(w.temp)°C")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 10) {
                        Text("Feels: \(w.feelsLike)°C")
                        Text("💧 \(w.humidity)%")
                        Text("💨 \(w.windSpeed)km/h")
                        Spacer()
                        Text(w.highLow)
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(petState.currentSpecies.accentColor.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 12)
            }

            // Stored Cities Vault List Header
            HStack {
                Text("Saved Climate Vault (\(wx.savedLocations.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.8))
                Spacer()
                Text("Tap to activate")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)

            // Saved Cities List with Selection & Explicit Trash Delete Button
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(wx.savedLocations) { loc in
                        let isActive = loc.id == wx.activeLocationId
                        HStack(spacing: 8) {
                            Button(action: {
                                wx.selectLocation(id: loc.id)
                            }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(isActive ? petState.currentSpecies.accentColor : Color.white.opacity(0.2))
                                        .frame(width: 7, height: 7)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(loc.name)
                                            .font(.system(size: 11, weight: isActive ? .bold : .medium))
                                            .foregroundColor(.white)
                                        if let country = loc.country {
                                            Text(country)
                                                .font(.system(size: 9))
                                                .foregroundColor(Color.white.opacity(0.5))
                                        }
                                    }

                                    Spacer()

                                    if let temp = loc.lastTemp {
                                        Text("\(temp)°")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.white.opacity(0.12))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            // Explicit Trash Delete Button
                            Button(action: {
                                withAnimation {
                                    wx.removeLocation(id: loc.id)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.red.opacity(0.75))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                            .help("Remove \(loc.name) from Climate Vault")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isActive ? petState.currentSpecies.accentColor.opacity(0.2) : Color.white.opacity(0.04))
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func addWeatherCity() {
        let city = weatherCityInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty else { return }
        weatherCityInput = ""
        Task {
            do {
                try await wx.addLocation(cityName: city)
                petState.showBubble("Added \(city)! 🌤", duration: 2.0)
            } catch {
                petState.showBubble("City not found! ❌", duration: 2.0)
            }
        }
    }

    // MARK: - Reminders Tab
    private var remindTabContent: some View {
        VStack(spacing: 8) {
            let pendingReminders = dataManager.savedData.reminders
                .filter { $0.status == "pending" }
                .sorted { $0.due < $1.due }
            let nextReminder = pendingReminders.first

            // 1. Top "Next Reminder" Highlight Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("NEXT REMINDER", systemImage: "bell.badge.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(petState.currentSpecies.accentColor)
                    Spacer()
                    if let next = nextReminder {
                        let minsLeft = max(0, Int((next.due - Date().timeIntervalSince1970 * 1000) / 60000))
                        Text(minsLeft == 0 ? "Due now" : "in \(minsLeft)m")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(petState.currentSpecies.accentColor.opacity(0.2)))
                            .foregroundColor(petState.currentSpecies.accentColor)
                    }
                }

                if let next = nextReminder {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.text)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            let timeStr = Date(timeIntervalSince1970: next.due / 1000).formatted(date: .omitted, time: .shortened)
                            Text("Scheduled for \(timeStr)")
                                .font(.system(size: 10))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        Spacer()
                        Button(action: {
                            dataManager.removeReminder(id: next.id)
                            petState.showBubble("Done! ✓", duration: 1.5)
                            SoundEffect.receive.play()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark")
                                Text("Done")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.green))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("✨ No upcoming reminders. Set one below or ask in Chat!")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.vertical, 4)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // 2. Upcoming Reminders List
            VStack(alignment: .leading, spacing: 4) {
                Text("UPCOMING REMINDERS (\(pendingReminders.count))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(.horizontal, 14)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        if pendingReminders.isEmpty {
                            Text("No reminders scheduled")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.35))
                                .padding(.top, 14)
                        } else {
                            ForEach(pendingReminders) { rem in
                                HStack(spacing: 8) {
                                    let minsLeft = max(0, Int((rem.due - Date().timeIntervalSince1970 * 1000) / 60000))
                                    Text(minsLeft == 0 ? "now" : "\(minsLeft)m")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(petState.currentSpecies.accentColor)
                                        .frame(width: 38, alignment: .center)
                                        .padding(.vertical, 3)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(petState.currentSpecies.accentColor.opacity(0.15)))

                                    Text(rem.text)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Spacer()

                                    Button(action: {
                                        dataManager.removeReminder(id: rem.id)
                                        SoundEffect.click.play()
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.white.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete reminder")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            Spacer(minLength: 0)

            // 3. Bottom "+ Create Reminder" Section
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    TextField("Reminder note...", text: $reminderText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(7)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .onSubmit {
                            createReminder()
                        }

                    Button(action: {
                        createReminder()
                    }) {
                        Text("+ Add")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(reminderText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.2) : petState.currentSpecies.accentColor))
                    }
                    .buttonStyle(.plain)
                    .disabled(reminderText.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Quick Duration Pills (+5m, +15m, +30m, +1h)
                HStack(spacing: 6) {
                    Text("In:")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.5))
                    ForEach([5, 15, 30, 60], id: \.self) { mins in
                        Button(action: {
                            reminderMinutes = mins
                            SoundEffect.click.play()
                        }) {
                            Text(mins == 60 ? "+1h" : "+\(mins)m")
                                .font(.system(size: 10, weight: reminderMinutes == mins ? .bold : .medium))
                                .foregroundColor(reminderMinutes == mins ? .white : Color.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(reminderMinutes == mins ? petState.currentSpecies.accentColor : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
        }
    }

    private func createReminder() {
        let note = reminderText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        dataManager.addReminder(text: note, minutes: reminderMinutes)
        petState.showBubble("I'll remind you in \(reminderMinutes)m! ⏰")
        SoundEffect.receive.play()
        reminderText = ""
    }

    // MARK: - System Tab
    private var systemTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("System Vitals")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                // CPU
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CPU Load")
                        Spacer()
                        Text(String(format: "%.1f%%", sysMon.cpuPercent))
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.8))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                            Rectangle()
                                .fill(sysMon.cpuPercent > 70 ? Color.red : (sysMon.cpuPercent > 40 ? Color.orange : Color.green))
                                .frame(width: geo.size.width * CGFloat(sysMon.cpuPercent / 100.0))
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 6)
                }

                // Battery & Uptime
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Battery")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                        Text("\(sysMon.batteryPercent)% \(sysMon.isCharging ? "⚡ Charging" : "🔋")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(sysMon.batteryPercent < 20 ? .red : .green)
                    }

                    VStack(alignment: .leading) {
                        Text("System Uptime")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                        Text(sysMon.uptimeString)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Running Apps
                Text("Active Applications (\(sysMon.foregroundApps.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.8))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 6) {
                    ForEach(sysMon.foregroundApps, id: \.self) { app in
                        Text(app)
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Focus & Health Tab
    private var gameTabContent: some View {
        ScrollView {
            VStack(spacing: 10) {
                // 1. Timer Hero Display with Progress Bar
                VStack(spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(focusStatusColor)
                                .frame(width: 8, height: 8)
                            Text(focusStatusText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(focusStatusColor)
                        }
                        Spacer()
                        if focusGuardian.isSessionActive {
                            Text("\(Int(focusGuardian.progress * 100))% done")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }

                    // Giant Timer Countdown
                    Text(focusGuardian.formattedTime)
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.vertical, 2)

                    // Smooth Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.12))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(petState.currentSpecies.accentColor)
                                .frame(width: geo.size.width * CGFloat(focusGuardian.progress))
                        }
                    }
                    .frame(height: 6)

                    // Start / Pause / Reset Controls
                    HStack(spacing: 10) {
                        Button(action: {
                            if focusGuardian.isSessionActive {
                                focusGuardian.pauseFocusSession()
                            } else {
                                focusGuardian.startFocusSession()
                            }
                            SoundEffect.click.play()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: focusGuardian.isSessionActive ? "pause.fill" : "play.fill")
                                Text(focusGuardian.isSessionActive ? "Pause" : "Start Focus")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(petState.currentSpecies.accentColor))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            focusGuardian.resetFocusSession()
                            SoundEffect.click.play()
                        }) {
                            Text("Reset")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))

                // 2. Companion Focus Card
                HStack(spacing: 12) {
                    Text(petState.currentSpecies.icon)
                        .font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(petState.currentSpecies.displayName) is focusing with you")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Distractions silenced. Take deep breaths and work peacefully.")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(petState.currentSpecies.accentColor.opacity(0.12)))

                // 3. Quick Session Presets & Custom Configuration
                if !focusGuardian.isSessionActive {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QUICK PRESETS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.4))
                            .padding(.horizontal, 4)

                        HStack(spacing: 6) {
                            presetButton("10m Quick", seconds: 10 * 60)
                            presetButton("25m Pomodoro", seconds: 25 * 60)
                            presetButton("45m Deep", seconds: 45 * 60)
                            presetButton("60m", seconds: 60 * 60)
                        }

                        // Custom duration row
                        HStack(spacing: 6) {
                            Text("Custom:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)

                            HStack(spacing: 1) {
                                Text("H")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $focusGuardian.customHours) {
                                    ForEach(0..<12) { h in Text("\(h)").tag(h) }
                                }
                                .labelsHidden()
                                .frame(width: 44)
                            }

                            HStack(spacing: 1) {
                                Text("M")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $focusGuardian.customMinutes) {
                                    ForEach(0..<60) { m in Text(String(format: "%02d", m)).tag(m) }
                                }
                                .labelsHidden()
                                .frame(width: 48)
                            }

                            HStack(spacing: 1) {
                                Text("S")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $focusGuardian.customSeconds) {
                                    ForEach(0..<60) { s in Text(String(format: "%02d", s)).tag(s) }
                                }
                                .labelsHidden()
                                .frame(width: 48)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                }

                // 4. Secondary Audio / Music Visualizer Section
                VStack(spacing: 8) {
                    HStack {
                        Label("Focus Audio & Visualizer", systemImage: "headphones")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if music.isPlaying {
                            Text("♪ \(music.trackTitle)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.green)
                                .lineLimit(1)
                        }
                    }

                    // Beat Bars
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(0..<8) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(petState.currentSpecies.accentColor)
                                .frame(width: 12, height: max(4, music.beatLevels[i] * 32))
                        }
                    }
                    .frame(height: 32)

                    HStack(spacing: 8) {
                        Button("Upload Audio") {
                            openMusicFile()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if music.isPlaying {
                            Button("Stop") {
                                music.stop()
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
            }
            .padding(12)
        }
    }

    private var focusStatusColor: Color {
        if !focusGuardian.isSessionActive {
            return Color.secondary
        }
        if focusGuardian.isPaused {
            return Color.yellow
        }
        if focusGuardian.userIsAway {
            return Color.red
        }
        return Color.green
    }

    private var focusStatusText: String {
        if !focusGuardian.isSessionActive {
            return "⚪ Ready to Focus"
        }
        if focusGuardian.isPaused {
            return "🟡 Session Paused"
        }
        if focusGuardian.userIsAway {
            return "🔴 Stepped Away"
        }
        return "🟢 Deep Focus Active"
    }

    private func presetButton(_ title: String, seconds: Int) -> some View {
        Button(action: {
            focusGuardian.applyPreset(seconds: seconds)
            SoundEffect.click.play()
        }) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }




    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !petState.isThinking else { return }

        inputText = ""
        errorMessage = nil
        lastFailedPrompt = nil

        let userMsg = ChatMessage(role: "user", content: text)
        messages.append(userMsg)
        SoundEffect.send.play()

        petState.streak = dataManager.savedData.streak
        dataManager.updateStreak()
        withAnimation(.easeInOut(duration: 0.2)) {
            petState.isThinking = true
        }
        petState.animState = .thinking
        motion.transitionTo(.thinking)

        let assistantMsgId = UUID()

        Task {
            // 1. Check if Mac Control Action Assistant handles this request
            let macSettings = dataManager.savedData.macControlSettings ?? MacControlSettings()
            if macSettings.macControlEnabled {
                if let action = await ActionIntentParser.shared.parseIntent(from: text) {
                    let actionResult = await MacActionExecutor.shared.processAction(action, userText: text)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        petState.isThinking = false
                    }
                    messages.append(ChatMessage(
                        id: assistantMsgId,
                        role: "assistant",
                        content: actionResult
                    ))
                    petState.animState = .idle
                    motion.transitionTo(.idle)
                    saveMessages()

                    if dataManager.savedData.speakAiResponses ?? false {
                        voiceAssistant.speak(text: actionResult)
                    }
                    return
                }
            }

            do {
                let systemCtx = "You are \(petState.currentSpecies.displayName), a cute friendly desktop companion. Keep answers concise, helpful, and in character."
                let nonStreamingHistory = messages

                let fullReply = try await AIProviderManager.shared.streamChat(
                    systemPrompt: systemCtx,
                    messages: nonStreamingHistory
                ) { token in
                    if let index = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        messages[index] = ChatMessage(
                            id: assistantMsgId,
                            role: "assistant",
                            content: messages[index].content + token
                        )
                    } else {
                        // First token arrives! Fade out typing indicator smoothly
                        withAnimation(.easeInOut(duration: 0.2)) {
                            petState.isThinking = false
                        }
                        messages.append(ChatMessage(
                            id: assistantMsgId,
                            role: "assistant",
                            content: token
                        ))
                    }
                    motion.transitionTo(.streamingResponse)
                }

                SoundEffect.receive.play()
                petState.showBubble("✓", duration: 1.0)
                petState.moodPoints = min(100.0, petState.moodPoints + 12.0)
                saveMessages()

                if dataManager.savedData.speakAiResponses ?? false {
                    voiceAssistant.speak(text: fullReply)
                }
            } catch {
                withAnimation(.easeInOut(duration: 0.2)) {
                    petState.isThinking = false
                }
                errorMessage = error.localizedDescription
                lastFailedPrompt = text
                messages.removeAll { $0.id == assistantMsgId }
                petState.animState = .shock
                petState.showBubble("Error! 😱", duration: 2.5)
                SoundEffect.alert.play()
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                petState.isThinking = false
            }
            petState.animState = .idle
            motion.transitionTo(.idle)
        }
    }

    private func retryMessage(_ text: String) {
        errorMessage = nil
        inputText = text
        sendMessage()
    }

    private func loadMessages() {
        messages = dataManager.savedData.history.map {
            ChatMessage(role: $0.role, content: $0.content)
        }
    }

    private func saveMessages() {
        dataManager.savedData.history = messages.suffix(20).map {
            PetSavedMessage(role: $0.role, content: $0.content)
        }
        dataManager.saveData()
    }

    private func clearChat() {
        messages.removeAll()
        dataManager.savedData.history = []
        dataManager.saveData()
        petState.showBubble("Chat cleared! ✨", duration: 1.5)
    }

    private func exportChat() {
        let exportStr = messages.map { "[\($0.role.uppercased())]: \($0.content)" }.joined(separator: "\n\n")
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "ollama-pet-chat.txt"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? exportStr.write(to: url, atomically: true, encoding: .utf8)
            petState.showBubble("Saved! 📄", duration: 1.5)
        }
    }

    private func openMusicFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio, .mp3]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            music.loadAndPlay(fileURL: url)
            petState.animState = .dance
            petState.showBubble("🎧 Dancing to music!", duration: 2.0)
        }
    }

    private func startWalkAcrossScreen() {
        WalkerManager.shared.startWalk(species: petState.currentSpecies)
        petState.showBubble("Going for a walk! 🚶", duration: 2.0)
    }
}

// MARK: - Native Staggered Typing Dots View

public struct TypingDotsView: View {
    public let accentColor: Color
    @State private var dotScales: [CGFloat] = [0.45, 0.45, 0.45]
    @State private var dotOffsets: [CGFloat] = [2.0, 2.0, 2.0]

    public init(accentColor: Color) {
        self.accentColor = accentColor
    }

    public var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(accentColor.opacity(dotScales[i] > 0.6 ? 0.95 : 0.45))
                    .frame(width: 5.5, height: 5.5)
                    .offset(y: dotOffsets[i])
                    .scaleEffect(dotScales[i])
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.16).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            for i in 0..<3 {
                withAnimation(
                    Animation.easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.16)
                ) {
                    dotOffsets[i] = -3.5
                    dotScales[i] = 1.15
                }
            }
        }
    }
}
