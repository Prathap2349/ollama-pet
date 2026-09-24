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

    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var lastFailedPrompt: String? = nil
    @State private var errorMessage: String? = nil

    // Weather input
    @State private var weatherCityInput: String = ""

    // Reminders input
    @State private var reminderText: String = ""
    @State private var reminderMinutes: Int = 5

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
                    petState.isChatOpen = false
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
                    tabButton(title: "Chat", id: "chat", icon: "bubble.left")
                    tabButton(title: "Remind", id: "remind", icon: "clock")
                    tabButton(title: "Weather", id: "weather", icon: "cloud.sun")
                    tabButton(title: "Music & Play", id: "game", icon: "music.note")
                    tabButton(title: "System", id: "system", icon: "cpu")
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
                TextField("Message \(petState.currentSpecies.displayName)...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .onSubmit {
                        sendMessage()
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
        VStack(spacing: 12) {
            HStack {
                TextField("Enter city (e.g. Tokyo)", text: $weatherCityInput)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .onSubmit {
                        Task { await wx.fetchWeather(for: weatherCityInput) }
                    }

                Button("Fetch") {
                    Task { await wx.fetchWeather(for: weatherCityInput) }
                }
                .buttonStyle(.borderedProminent)
                .tint(petState.currentSpecies.accentColor)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Text(wx.statusMessage)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))

            if let w = wx.weather {
                VStack(spacing: 8) {
                    Text(w.cityName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        Text(w.icon)
                            .font(.system(size: 44))

                        VStack(alignment: .leading) {
                            Text("\(w.temp)°C")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("Feels like \(w.feelsLike)°C")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }

                    Text(w.description)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(petState.currentSpecies.accentColor)

                    HStack(spacing: 16) {
                        Text("💧 Humidity: \(w.humidity)%")
                        Text("💨 Wind: \(w.windSpeed) km/h")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.7))

                    Text("High / Low: \(w.highLow)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .padding(.horizontal, 12)
            } else {
                Spacer()
                Text("Search any city for live weather and forecast.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.4))
                Spacer()
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
                // Pomodoro Section
                VStack(spacing: 6) {
                    Text(petState.pomoIsBreak ? "☕ Break Session" : "💼 Focus Session")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(petState.currentSpecies.accentColor)

                    let mins = petState.pomoSeconds / 60
                    let secs = petState.pomoSeconds % 60
                    Text(String(format: "%02d:%02d", mins, secs))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        Button(petState.pomoRunning ? "Pause" : "Start") {
                            petState.togglePomo()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(petState.currentSpecies.accentColor)
                        .controlSize(.small)

                        Button("Reset") {
                            petState.resetPomo()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Pet Characters")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 75))], spacing: 8) {
                ForEach(PetSpecies.allCases) { sp in
                    Button(action: {
                        petState.setSpecies(sp)
                    }) {
                        VStack(spacing: 4) {
                            Text(sp.icon)
                                .font(.system(size: 24))
                            Text(sp.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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

            Divider().background(Color.white.opacity(0.1))

            Text("Ollama Model")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            Picker("Active Model", selection: $ollamaClient.activeModel) {
                if ollamaClient.installedModels.isEmpty {
                    Text("No models detected").tag("")
                } else {
                    ForEach(ollamaClient.installedModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
            }
            .pickerStyle(.menu)
            .onChange(of: ollamaClient.activeModel) { newModel in
                dataManager.savedData.selectedModel = newModel
                dataManager.saveData()
            }

            Spacer()
        }
        .padding(14)
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

        Task {
            do {
                let systemCtx = "You are \(petState.currentSpecies.displayName), a cute friendly desktop companion. Keep answers concise, helpful, and in character."
                let reply = try await ollamaClient.sendChat(systemPrompt: systemCtx, messages: messages)

                messages.append(ChatMessage(role: "assistant", content: reply))
                SoundEffect.receive.play()
                petState.showBubble("✓", duration: 1.0)
                petState.moodPoints = min(100.0, petState.moodPoints + 12.0)
                saveMessages()
            } catch {
                errorMessage = error.localizedDescription
                lastFailedPrompt = text
                petState.animState = .shock
                petState.showBubble("Error! 😱", duration: 2.5)
                SoundEffect.alert.play()
            }
            petState.isThinking = false
            petState.animState = .idle
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
