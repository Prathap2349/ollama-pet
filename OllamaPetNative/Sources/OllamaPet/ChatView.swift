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
        .frame(width: 320, height: 460)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 15/255, green: 17/255, blue: 26/255).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(petState.currentSpecies.accentColor.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 16, x: 0, y: 8)
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
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Text(petState.currentSpecies.icon)
                        .font(.system(size: 13))
                    Text("Ollama Pet")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(headerStatusColor)
                        .frame(width: 7, height: 7)

                    Text(ollamaClient.statusMessage)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
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

                Button(action: {
                    PetWindowController.shared.closePanel()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.5))
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Close Panel")
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)

            // Tabs Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if dataManager.isFeatureVisible("chat") {
                        tabButton(title: "Chat", id: "chat", icon: "bubble.left")
                    }
                    if dataManager.isFeatureVisible("remind") {
                        tabButton(title: "Remind", id: "remind", icon: "clock")
                    }
                    if dataManager.isFeatureVisible("weather") {
                        tabButton(title: "Weather", id: "weather", icon: "cloud.sun")
                    }
                    if dataManager.isFeatureVisible("game") {
                        tabButton(title: "Focus & Audio", id: "game", icon: "headphones")
                    }
                    if dataManager.isFeatureVisible("system") {
                        tabButton(title: "System", id: "system", icon: "cpu")
                    }
                    Button(action: {
                        SettingsWindowController.shared.showWindow()
                        SoundEffect.click.play()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10))
                            Text("Settings")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .foregroundColor(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
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
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                petState.activeTab == id
                    ? petState.currentSpecies.accentColor.opacity(0.35)
                    : Color.white.opacity(0.08)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(petState.activeTab == id ? petState.currentSpecies.accentColor.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
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
                                        .font(.system(size: 12, weight: .bold))
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
                                .padding(.top, 16)
                            } else {
                                Text("Session started. Ask \(petState.currentSpecies.displayName) anything!")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.4))
                                    .padding(.top, 20)
                            }
                        }

                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }

                        if petState.isThinking {
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

            // Footer action buttons
            HStack {
                Button("Walk") {
                    startWalkAcrossScreen()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))

                Spacer()

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
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))
        }
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
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                HStack {
                    TextField("Reminder note...", text: $reminderText)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                        .foregroundColor(.white)

                    Picker("", selection: $reminderMinutes) {
                        Text("1m").tag(1)
                        Text("5m").tag(5)
                        Text("15m").tag(15)
                        Text("30m").tag(30)
                        Text("60m").tag(60)
                    }
                    .labelsHidden()
                    .frame(width: 70)

                    Button("Add") {
                        if !reminderText.trimmingCharacters(in: .whitespaces).isEmpty {
                            dataManager.addReminder(text: reminderText, minutes: reminderMinutes)
                            petState.showBubble("I'll remind you in \(reminderMinutes)m! ⏰")
                            reminderText = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(petState.currentSpecies.accentColor)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            List {
                if dataManager.savedData.reminders.isEmpty {
                    Text("No active reminders scheduled.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.4))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(dataManager.savedData.reminders) { rem in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rem.text)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)

                                let minsLeft = max(0, Int((rem.due - Date().timeIntervalSince1970 * 1000) / 60000))
                                Text("Due in ~\(minsLeft)m")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.5))
                            }

                            Spacer()

                            Button(action: {
                                dataManager.removeReminder(id: rem.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
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

    // MARK: - Game / Music Tab
    private var gameTabContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Focus Guardian Section
                VStack(spacing: 8) {
                    HStack {
                        Text(focusGuardian.isSessionActive ? "🎯 Active Focus Session" : "🎯 Focus Guardian")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(petState.currentSpecies.accentColor)
                        Spacer()
                        if focusGuardian.isSessionActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(focusGuardian.userIsAway ? Color.red : Color.green)
                                    .frame(width: 6, height: 6)
                                Text(focusGuardian.userIsAway ? "User Away" : "Focused")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(focusGuardian.userIsAway ? .red : .green)
                            }
                        }
                    }

                    // Current Timer Countdown
                    Text(focusGuardian.formattedTime)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    // Custom Duration Inputs (Hours, Minutes, Seconds)
                    if !focusGuardian.isSessionActive {
                        HStack(spacing: 6) {
                            Text("Duration:")
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
                        .padding(.vertical, 2)
                    }

                    // Action Buttons
                    HStack(spacing: 10) {
                        Button(focusGuardian.isSessionActive ? "Pause" : "Start") {
                            if focusGuardian.isSessionActive {
                                focusGuardian.pauseFocusSession()
                            } else {
                                focusGuardian.startFocusSession()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(petState.currentSpecies.accentColor)
                        .controlSize(.small)

                        Button("Reset") {
                            focusGuardian.resetFocusSession()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    // Quick Presets: 10s (Test), 1m, 10m, 25m, 45m, 60m
                    if !focusGuardian.isSessionActive {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Button("10s (Test)") { focusGuardian.applyPreset(seconds: 10) }
                                Button("1m") { focusGuardian.applyPreset(seconds: 60) }
                                Button("10m") { focusGuardian.applyPreset(seconds: 10 * 60) }
                                Button("25m") { focusGuardian.applyPreset(seconds: 25 * 60) }
                                Button("45m") { focusGuardian.applyPreset(seconds: 45 * 60) }
                            }
                            .font(.system(size: 9, weight: .medium))
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }

                    if visionGuardian.isRunning || screenGuardian.isMonitoring {
                        HStack(spacing: 10) {
                            if visionGuardian.isRunning {
                                Label(visionGuardian.presenceState.rawValue, systemImage: "video.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color.white.opacity(0.7))
                            }
                            if screenGuardian.isMonitoring {
                                Label(screenGuardian.currentCategory.rawValue, systemImage: "display")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color.white.opacity(0.7))
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                Divider().background(Color.white.opacity(0.1))

                // Music Visualizer Section
                VStack(spacing: 6) {
                    HStack {
                        Text("Beat Visualizer")
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
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(0..<8) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(petState.currentSpecies.accentColor)
                                .frame(width: 14, height: max(6, music.beatLevels[i] * 40))
                        }
                    }
                    .frame(height: 44)

                    HStack {
                        Button("Upload Music") {
                            openMusicFile()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if music.isPlaying {
                            Button("Stop") {
                                music.stop()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
            .padding(12)
        }
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
