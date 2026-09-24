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
        VStack(spacing: 0) {
            // Header: Ollama Status + Tabs + Close
            headerBar

            // Tab Content
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
                settingsTabContent
            default:
                chatTabContent
            }
        }
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
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(ollamaClient.isOnline ? (ollamaClient.installedModels.isEmpty ? Color.orange : Color.green) : Color.red)
                    .frame(width: 8, height: 8)

                Text(ollamaClient.statusMessage)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    PetWindowController.shared.closePanel()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.6))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

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
                        tabButton(title: "Music & Play", id: "game", icon: "music.note")
                    }
                    if dataManager.isFeatureVisible("system") {
                        tabButton(title: "System", id: "system", icon: "cpu")
                    }
                    tabButton(title: "Settings", id: "settings", icon: "gearshape")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
        .background(Color.white.opacity(0.04))
    }

    private func tabButton(title: String, id: String, icon: String) -> some View {
        Button(action: {
            petState.activeTab = id
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
                    ? petState.currentSpecies.accentColor.opacity(0.3)
                    : Color.white.opacity(0.08)
            )
            .cornerRadius(8)
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
                            Text("Session started. Ask \(petState.currentSpecies.displayName) anything!")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.4))
                                .padding(.top, 20)
                        }

                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }

                        if petState.isThinking {
                            HStack {
                                Text("\(petState.currentSpecies.displayName) is thinking...")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(petState.currentSpecies.accentColor)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
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
                .help("Push-to-Talk Voice Assistant (⌘⇧Space)")

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

    private func messageBubble(_ msg: ChatMessage) -> some View {
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
                VStack(spacing: 6) {
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

                    let mins = focusGuardian.remainingSeconds / 60
                    let secs = focusGuardian.remainingSeconds % 60
                    Text(String(format: "%02d:%02d", mins, secs))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        Button(focusGuardian.isSessionActive ? "Pause" : "Start 25m Focus") {
                            if focusGuardian.isSessionActive {
                                focusGuardian.pauseFocusSession()
                            } else {
                                focusGuardian.startFocusSession(minutes: 25)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(petState.currentSpecies.accentColor)
                        .controlSize(.small)

                        Button("Reset") {
                            focusGuardian.resetFocusSession(minutes: 25)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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

                Divider().background(Color.white.opacity(0.1))

                // Mini Games: RPS & Trivia
                VStack(spacing: 8) {
                    Text("Mini Games")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 16) {
                        Button("✊ Rock") { petState.playRPS(choice: "✊") }
                        Button("✋ Paper") { petState.playRPS(choice: "✋") }
                        Button("✌️ Scissors") { petState.playRPS(choice: "✌️") }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if !petState.rpsResult.isEmpty {
                        Text(petState.rpsResult)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(petState.currentSpecies.accentColor)
                    }

                    Button("Load Trivia Question") {
                        Task { await petState.fetchTrivia() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if !petState.triviaQuestion.isEmpty {
                        VStack(spacing: 4) {
                            Text(petState.triviaQuestion)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            ForEach(petState.triviaAnswers, id: \.self) { ans in
                                Button(ans) {
                                    petState.answerTrivia(ans)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: - Settings Tab
    private var settingsTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Dedicated Settings Window Button
                Button(action: {
                    SettingsWindowController.shared.showWindow()
                }) {
                    HStack {
                        Image(systemName: "macwindow.badge.plus")
                            .font(.system(size: 14))
                        Text("Open Full Settings Window")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(petState.currentSpecies.accentColor.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)

                // Section 1: Ollama Local AI Status & Model Selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🤖 Ollama Local AI")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Circle()
                            .fill(ollamaClient.isOnline ? (ollamaClient.installedModels.isEmpty ? Color.orange : Color.green) : Color.red)
                            .frame(width: 8, height: 8)
                        Text(ollamaClient.isOnline ? "Online" : "Offline")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(ollamaClient.isOnline ? .green : .red)
                    }

                    if ollamaClient.installedModels.isEmpty {
                        Text(ollamaClient.isOnline ? "No models found. Run: ollama pull llama3" : "Ollama not running. Run: ollama serve")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                    } else {
                        Picker("Model", selection: $ollamaClient.activeModel) {
                            ForEach(ollamaClient.installedModels, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: ollamaClient.activeModel) { newModel in
                            dataManager.savedData.selectedModel = newModel
                            dataManager.saveData()
                        }
                    }

                    HStack(spacing: 8) {
                        Button(action: {
                            Task {
                                await ollamaClient.checkHealth(preferredModel: dataManager.savedData.selectedModel)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Models")
                            }
                            .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: {
                            runOllamaTest()
                        }) {
                            HStack(spacing: 4) {
                                if testingOllama {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "bolt.fill")
                                }
                                Text("Test Connection")
                            }
                            .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(testingOllama || !ollamaClient.isOnline || ollamaClient.activeModel.isEmpty)
                    }

                    if let res = testOllamaResult {
                        Text(res)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(res.starts(with: "✓") ? .green : .red)
                            .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 2: Character Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("🐾 Character")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(PetSpecies.allCases) { sp in
                            Button(action: {
                                petState.setSpecies(sp)
                            }) {
                                VStack(spacing: 4) {
                                    Text(sp.icon)
                                        .font(.system(size: 20))
                                    Text(sp.displayName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    petState.currentSpecies == sp
                                        ? sp.accentColor.opacity(0.4)
                                        : Color.white.opacity(0.06)
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Random Character Setting
                    HStack {
                        Text("Switch Mode")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.8))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { dataManager.savedData.randomCharMode ?? "fixed" },
                            set: { dataManager.setRandomCharMode($0) }
                        )) {
                            Text("Fixed").tag("fixed")
                            Text("Launch").tag("launch")
                            Text("Daily").tag("daily")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                    .padding(.top, 4)

                    Divider().background(Color.white.opacity(0.1))

                    // Procedural Structural Model
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Structural Model (Procedural Physics)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.8))

                        Picker("", selection: Binding(
                            get: { motion.structuralModel },
                            set: { motion.setStructuralModel($0) }
                        )) {
                            ForEach(CharacterStructuralModel.allCases) { m in
                                Text("\(m.icon) \(m.rawValue)").tag(m)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(motion.structuralModel.subtitle)
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .padding(.top, 2)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 3: Voice Assistant & Speech
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🎙 Voice Assistant")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(voiceAssistant.state.rawValue)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(voiceAssistant.state == .listening ? .red : (voiceAssistant.isSpeaking ? .green : .white.opacity(0.6)))
                    }

                    Toggle("Speak AI Responses (TTS)", isOn: Binding(
                        get: { dataManager.savedData.speakAiResponses ?? true },
                        set: { dataManager.setSpeakAiResponses($0) }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11))

                    if !voiceAssistant.availableVoices.isEmpty {
                        Picker("Voice", selection: Binding(
                            get: { dataManager.savedData.selectedVoiceId ?? voiceAssistant.availableVoices.first?.id ?? "" },
                            set: { dataManager.setSelectedVoiceId($0) }
                        )) {
                            ForEach(voiceAssistant.availableVoices) { v in
                                Text(v.name).tag(v.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("Speed:")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.7))
                        Slider(value: Binding(
                            get: { dataManager.savedData.speechSpeed ?? 1.0 },
                            set: { dataManager.setSpeechSpeed($0) }
                        ), in: 0.5...1.8, step: 0.1)
                        Text(String(format: "%.1fx", dataManager.savedData.speechSpeed ?? 1.0))
                            .font(.system(size: 10, design: .monospaced))
                    }

                    HStack(spacing: 8) {
                        Button("Test Voice") {
                            voiceAssistant.speak(text: "Hello! I am \(petState.currentSpecies.displayName), your desktop companion.")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if voiceAssistant.isSpeaking {
                            Button("Stop Speaking") {
                                voiceAssistant.stopSpeaking()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 4: Keyboard Shortcuts
                VStack(alignment: .leading, spacing: 8) {
                    Text("⌨️ Keyboard Shortcuts")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    shortcutRow(title: "Voice Assistant", action: "voice", combo: shortcutManager.voiceShortcut)
                    shortcutRow(title: "Show / Hide Pet", action: "togglePet", combo: shortcutManager.togglePetShortcut)
                    shortcutRow(title: "Open Settings", action: "settings", combo: shortcutManager.settingsShortcut)

                    if let conflict = shortcutManager.conflictMessage {
                        Text(conflict)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 5: Realistic Walk Mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("🚶 Walk Mode")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    HStack {
                        Text("Walk Speed:")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                        Slider(value: Binding(
                            get: { dataManager.savedData.walkSpeed ?? 1.0 },
                            set: { dataManager.setWalkSpeed($0) }
                        ), in: 0.5...2.0, step: 0.1)
                        Text(String(format: "%.1fx", dataManager.savedData.walkSpeed ?? 1.0))
                            .font(.system(size: 11, design: .monospaced))
                    }

                    // Gait Kinematics Preset
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gait Kinematics:")
                            .font(.system(size: 11))
                            .foregroundColor(.white)

                        Picker("", selection: Binding(
                            get: { motion.gaitPreset },
                            set: { motion.setGaitPreset($0) }
                        )) {
                            ForEach(WalkGaitPreset.allCases) { g in
                                Text("\(g.icon) \(g.rawValue)").tag(g)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(motion.gaitPreset.description)
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .padding(.vertical, 2)

                    HStack(spacing: 8) {
                        Button("Test Walk (Short)") {
                            WalkerManager.shared.startWalk(species: petState.currentSpecies, isTest: true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Full Screen Walk") {
                            WalkerManager.shared.startWalk(species: petState.currentSpecies, isTest: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 6: Camera Awareness & Vision
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("👁 Camera Awareness (Vision)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Circle()
                            .fill(visionGuardian.isRunning ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(visionGuardian.isRunning ? "Active" : "Off")
                            .font(.system(size: 10, design: .monospaced))
                    }

                    Toggle("Enable Camera Awareness", isOn: Binding(
                        get: { dataManager.savedData.cameraAwarenessEnabled ?? false },
                        set: { isEnabled in
                            dataManager.setCameraAwarenessEnabled(isEnabled)
                            if isEnabled {
                                visionGuardian.startSession()
                            } else {
                                visionGuardian.stopSession()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11))

                    if dataManager.savedData.cameraAwarenessEnabled ?? false {
                        HStack {
                            Text("Check Interval:")
                                .font(.system(size: 11))
                            Spacer()
                            Picker("", selection: Binding(
                                get: { dataManager.savedData.cameraIntervalSeconds ?? 10 },
                                set: { dataManager.setCameraIntervalSeconds($0) }
                            )) {
                                Text("5s").tag(5)
                                Text("10s").tag(10)
                                Text("30s").tag(30)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }

                        Toggle("Gentle Stillness Check", isOn: Binding(
                            get: { dataManager.savedData.stillnessAlertEnabled ?? true },
                            set: { dataManager.setStillnessAlertEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .font(.system(size: 10))

                        Text("Status: \(visionGuardian.presenceState.rawValue)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 7: Screen Awareness
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🖥 Screen Awareness")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Circle()
                            .fill(screenGuardian.isMonitoring ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(screenGuardian.isMonitoring ? "Active" : "Off")
                            .font(.system(size: 10, design: .monospaced))
                    }

                    Toggle("Enable Screen Awareness", isOn: Binding(
                        get: { dataManager.savedData.screenMonitoringEnabled ?? false },
                        set: { isEnabled in
                            dataManager.setScreenMonitoringEnabled(isEnabled)
                            if isEnabled {
                                screenGuardian.startMonitoring()
                            } else {
                                screenGuardian.stopMonitoring()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11))

                    if dataManager.savedData.screenMonitoringEnabled ?? false {
                        Text("Context: \(screenGuardian.currentCategory.rawValue) (\(screenGuardian.activeAppName))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 8: Focus Guardian & Hydration
                VStack(alignment: .leading, spacing: 8) {
                    Text("🎯 Focus & Wellness")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Toggle("Focus Step-away Alerts", isOn: Binding(
                        get: { dataManager.savedData.focusNotificationsEnabled ?? true },
                        set: { dataManager.setFocusNotificationsEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11))

                    Toggle("Hydration Reminders", isOn: Binding(
                        get: { dataManager.savedData.hydrationReminderEnabled ?? true },
                        set: { isEnabled in
                            dataManager.setHydrationReminderEnabled(isEnabled)
                            focusGuardian.startHydrationTimerIfNeeded()
                        }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11))

                    if dataManager.savedData.hydrationReminderEnabled ?? true {
                        HStack {
                            Text("Interval:")
                                .font(.system(size: 11))
                            Spacer()
                            Picker("", selection: Binding(
                                get: { dataManager.savedData.hydrationIntervalMinutes ?? 60 },
                                set: {
                                    dataManager.setHydrationIntervalMinutes($0)
                                    focusGuardian.startHydrationTimerIfNeeded()
                                }
                            )) {
                                Text("30m").tag(30)
                                Text("60m").tag(60)
                                Text("90m").tag(90)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 9: Privacy Center
                VStack(alignment: .leading, spacing: 8) {
                    Text("🔐 Privacy Center")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    privacyStatusRow(icon: "mic.fill", name: "Microphone", isLive: voiceAssistant.state == .listening, isPermitted: voiceAssistant.micPermissionGranted)
                    privacyStatusRow(icon: "video.fill", name: "Camera", isLive: visionGuardian.isRunning, isPermitted: visionGuardian.permissionGranted)
                    privacyStatusRow(icon: "display", name: "Screen Awareness", isLive: screenGuardian.isMonitoring, isPermitted: screenGuardian.permissionGranted)
                    privacyStatusRow(icon: "cpu", name: "AI Processing", isLive: ollamaClient.isOnline, isPermitted: true, note: "Local Ollama (100% Private)")
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 10: Tab & Feature Visibility
                VStack(alignment: .leading, spacing: 8) {
                    Text("📱 Tab Visibility")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    VStack(spacing: 6) {
                        featureToggleRow(title: "💬 Chat with AI", id: "chat")
                        featureToggleRow(title: "⏰ Reminders", id: "remind")
                        featureToggleRow(title: "⛅ Weather", id: "weather")
                        featureToggleRow(title: "🎵 Music & Focus", id: "game")
                        featureToggleRow(title: "📊 System Monitor", id: "system")
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 11: Behavior & Reset
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚙️ General")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Toggle("Idle Animations", isOn: Binding(
                        get: { dataManager.savedData.idleAnimationsEnabled ?? true },
                        set: { dataManager.setIdleAnimationsEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11))

                    Toggle("Speech Bubbles", isOn: Binding(
                        get: { dataManager.savedData.speechBubblesEnabled ?? true },
                        set: { dataManager.setSpeechBubblesEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11))

                    Toggle("Sound Effects", isOn: Binding(
                        get: { dataManager.savedData.soundEffectsEnabled ?? true },
                        set: { dataManager.setSoundEffectsEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 11))
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                // Section 12: Reset Window Position
                Button(action: {
                    if let screen = NSScreen.main {
                        let screenFrame = screen.visibleFrame
                        let defaultX = screenFrame.maxX - 140 - 30
                        let defaultY = screenFrame.minY + 40
                        PetWindowController.shared.updatePetOriginFromDrag(NSPoint(x: defaultX, y: defaultY))
                        DataManager.shared.updatePosition(x: Double(defaultX), y: Double(defaultY))
                        petState.showBubble("Reset to bottom-right! 📍", duration: 2.0)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Pet to Bottom-Right Corner")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(10)
        }
    }

    private func shortcutRow(title: String, action: String, combo: KeyCombo) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white)
            Spacer()
            if shortcutManager.recordingAction == action {
                Text("Press keys...")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            } else {
                Text(combo.displayString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(petState.currentSpecies.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)

                Button("Change") {
                    shortcutManager.startRecording(action: action)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
    }

    private func privacyStatusRow(icon: String, name: String, isLive: Bool, isPermitted: Bool, note: String? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isLive ? .green : Color.white.opacity(0.6))
                .frame(width: 16)
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(.white)
            Spacer()
            if let n = note {
                Text(n)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.green)
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isLive ? Color.green : (isPermitted ? Color.orange : Color.gray.opacity(0.5)))
                        .frame(width: 6, height: 6)
                    Text(isLive ? "Active" : (isPermitted ? "Granted / Off" : "Not Granted"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(isLive ? .green : (isPermitted ? Color.white.opacity(0.8) : Color.white.opacity(0.4)))
                }
            }
        }
    }

    private func featureToggleRow(title: String, id: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: Binding(
                get: { dataManager.isFeatureVisible(id) },
                set: { isVis in
                    dataManager.setFeatureVisible(id, visible: isVis)
                    if !isVis && petState.activeTab == id {
                        petState.activeTab = "settings"
                    }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
    }

    private func runOllamaTest() {
        testingOllama = true
        testOllamaResult = "Testing prompt..."

        Task {
            do {
                let testReply = try await ollamaClient.sendChat(
                    systemPrompt: "Respond with exactly 'PONG'.",
                    messages: [ChatMessage(role: "user", content: "PING")]
                )
                testOllamaResult = "✓ Ollama OK (\(ollamaClient.activeModel)): \(testReply.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))"
                SoundEffect.wake.play()
            } catch {
                testOllamaResult = "✗ Failed: \(error.localizedDescription)"
                SoundEffect.alert.play()
            }
            testingOllama = false
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
        petState.isThinking = true
        petState.animState = .thinking
        motion.transitionTo(.thinking)

        let assistantMsgId = UUID()
        let assistantPlaceholder = ChatMessage(id: assistantMsgId, role: "assistant", content: "")
        messages.append(assistantPlaceholder)

        Task {
            do {
                let systemCtx = "You are \(petState.currentSpecies.displayName), a cute friendly desktop companion. Keep answers concise, helpful, and in character."
                let nonStreamingHistory = messages.filter { $0.id != assistantMsgId }

                let fullReply = try await ollamaClient.streamChat(
                    systemPrompt: systemCtx,
                    messages: nonStreamingHistory
                ) { token in
                    if let index = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        messages[index] = ChatMessage(
                            id: assistantMsgId,
                            role: "assistant",
                            content: messages[index].content + token
                        )
                        motion.transitionTo(.streamingResponse)
                    }
                }

                SoundEffect.receive.play()
                petState.showBubble("✓", duration: 1.0)
                petState.moodPoints = min(100.0, petState.moodPoints + 12.0)
                saveMessages()

                if dataManager.savedData.speakAiResponses ?? false {
                    voiceAssistant.speak(text: fullReply)
                }
            } catch {
                errorMessage = error.localizedDescription
                lastFailedPrompt = text
                messages.removeAll { $0.id == assistantMsgId }
                petState.animState = .shock
                petState.showBubble("Error! 😱", duration: 2.5)
                SoundEffect.alert.play()
            }
            petState.isThinking = false
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
