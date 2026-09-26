import Foundation
import AVFoundation
import Speech

public enum VoiceState: String {
    case idle
    case listening = "🎙 Listening..."
    case processing = "⏳ Processing..."
    case speaking = "🔊 Speaking..."
    case unavailable = "⚠️ Microphone unavailable"
}

public struct VoiceOption: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let language: String
}

@MainActor
public class VoiceAssistant: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = VoiceAssistant()

    @Published public var state: VoiceState = .idle
    @Published public var recognizedText: String = ""
    @Published public var errorMessage: String? = nil
    @Published public var isSpeaking: Bool = false
    @Published public var micPermissionGranted: Bool = false
    @Published public var speechPermissionGranted: Bool = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private let synthesizer = AVSpeechSynthesizer()

    override public init() {
        super.init()
        synthesizer.delegate = self
        checkPermissions()
    }

    public func checkPermissions() {
        // Microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micPermissionGranted = true
        default:
            micPermissionGranted = false
        }

        // Speech recognition permission
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechPermissionGranted = true
        default:
            speechPermissionGranted = false
        }
    }

    public func requestPermissions() async -> Bool {
        let micGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        self.micPermissionGranted = micGranted

        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }
        self.speechPermissionGranted = speechGranted

        return micGranted && speechGranted
    }

    // MARK: - Push to Talk Speech-to-Text

    public func togglePushToTalk() {
        if state == .listening {
            stopListeningAndProcess()
        } else if state == .speaking {
            stopSpeaking()
        } else {
            startListening()
        }
    }

    public func startListening() {
        guard state == .idle || state == .speaking else { return }

        // Stop any current speech
        if isSpeaking {
            stopSpeaking()
        }

        // Check permissions
        if !micPermissionGranted || !speechPermissionGranted {
            Task {
                let granted = await requestPermissions()
                if !granted {
                    self.state = .unavailable
                    self.errorMessage = "Microphone or Speech Recognition permission required."
                    PetState.shared.showBubble("⚠️ Mic access needed", duration: 3.0)
                    return
                }
                self.beginRecording()
            }
        } else {
            beginRecording()
        }
    }

    private func beginRecording() {
        // Cancel existing task if any
        cleanupAudioEngine()

        recognizedText = ""
        errorMessage = nil
        state = .listening
        PetState.shared.showBubble("🎙 Listening...", duration: 8.0)
        SoundEffect.click.play()

        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                state = .unavailable
                return
            }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0 else {
                state = .unavailable
                errorMessage = "Invalid audio input format"
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                Task { @MainActor in
                    if let result = result {
                        self.recognizedText = result.bestTranscription.formattedString
                    }
                    if error != nil {
                        // Stopped or failed
                        if self.state == .listening && !self.recognizedText.isEmpty {
                            self.stopListeningAndProcess()
                        }
                    }
                }
            }
        } catch {
            cleanupAudioEngine()
            state = .unavailable
            errorMessage = error.localizedDescription
            PetState.shared.showBubble("⚠️ Mic error", duration: 2.5)
        }
    }

    public func stopListeningAndProcess() {
        guard state == .listening else { return }
        state = .processing
        cleanupAudioEngine()

        let finalText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalText.isEmpty {
            state = .idle
            PetState.shared.showBubble("Didn't catch that~", duration: 2.0)
            return
        }

        PetState.shared.showBubble("⏳ Thinking...", duration: 3.0)
        PetState.shared.isThinking = true
        PetState.shared.animState = .thinking

        // Send into main Ollama pipeline via PetState
        Task {
            await processSpokenQuery(finalText)
        }
    }

    public func cancelListening() {
        cleanupAudioEngine()
        recognizedText = ""
        state = .idle
    }

    private func cleanupAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func processSpokenQuery(_ text: String) async {
        let petState = PetState.shared
        let dataManager = DataManager.shared

        // Add to chat history
        let userMsg = ChatMessage(role: "user", content: text)
        var history = dataManager.savedData.history.map { ChatMessage(role: $0.role, content: $0.content) }
        history.append(userMsg)

        dataManager.savedData.history = history.suffix(20).map { PetSavedMessage(role: $0.role, content: $0.content) }
        dataManager.saveData()

        // 1. Check if Mac Control Action Assistant handles this request
        let macSettings = dataManager.savedData.macControlSettings ?? MacControlSettings()
        if macSettings.macControlEnabled && macSettings.voiceControlEnabled {
            if let action = await ActionIntentParser.shared.parseIntent(from: text) {
                let actionResult = await MacActionExecutor.shared.processAction(action, userText: text)

                history.append(ChatMessage(role: "assistant", content: actionResult))
                dataManager.savedData.history = history.suffix(20).map { PetSavedMessage(role: $0.role, content: $0.content) }
                dataManager.saveData()

                petState.isThinking = false
                petState.animState = .idle

                if dataManager.savedData.speakAiResponses ?? true {
                    speak(text: actionResult)
                } else {
                    state = .idle
                }
                return
            }
        }

        do {
            let systemCtx = "You are \(petState.currentSpecies.displayName), a cute friendly desktop companion. Keep answers short, conversational, and direct (1-3 sentences max)."
            var accumulated = ""

            let reply = try await AIProviderManager.shared.streamChat(
                systemPrompt: systemCtx,
                messages: history
            ) { token in
                accumulated += token
                petState.showBubble(accumulated, duration: 4.0)
            }

            // Save reply to history
            history.append(ChatMessage(role: "assistant", content: reply))
            dataManager.savedData.history = history.suffix(20).map { PetSavedMessage(role: $0.role, content: $0.content) }
            dataManager.saveData()

            petState.isThinking = false
            petState.animState = .idle
            petState.showBubble(reply, duration: 4.0)

            // Speak response if enabled and not in Quiet Mode
            let isQuiet = dataManager.savedData.quietModeEnabled ?? false
            if !isQuiet && (dataManager.savedData.speakAiResponses ?? true) {
                speak(text: reply)
            } else {
                state = .idle
            }
        } catch {
            petState.isThinking = false
            petState.animState = .shock
            petState.showBubble("Error: \(error.localizedDescription)", duration: 3.0)
            state = .idle
        }
    }

    // MARK: - Text-to-Speech

    public var availableVoices: [VoiceOption] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices
            .filter { $0.language.starts(with: "en") }
            .map { VoiceOption(id: $0.identifier, name: $0.name, language: $0.language) }
    }

    public func applyVoicePreset(_ preset: AssistantVoicePreset) {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        for keyword in preset.preferredVoiceKeywords {
            if let matched = voices.first(where: { $0.name.localizedCaseInsensitiveContains(keyword) }) {
                DataManager.shared.setSelectedVoiceId(matched.identifier)
                DataManager.shared.setVoicePreset(preset.rawValue)
                return
            }
        }
        // Fallback to first available English voice
        if let fallback = voices.first(where: { $0.language.starts(with: "en") }) {
            DataManager.shared.setSelectedVoiceId(fallback.identifier)
            DataManager.shared.setVoicePreset(preset.rawValue)
        }
    }

    public func testVoicePreview() {
        speak(text: "Hello! I am your desktop companion, ready to assist you.")
    }

    public func speak(text: String) {
        stopSpeaking()

        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else {
            state = .idle
            return
        }

        let utterance = AVSpeechUtterance(string: cleaned)
        let data = DataManager.shared.savedData

        if let voiceId = data.selectedVoiceId, let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Default to Samantha or current locale voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        let speed = Float(data.speechSpeed ?? 1.0)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speed
        utterance.volume = Float(data.speechVolume ?? 1.0)
        utterance.pitchMultiplier = Float(data.speechPitch ?? 1.0)

        isSpeaking = true
        state = .speaking
        PetState.shared.animState = .dance
        synthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        state = .idle
        if PetState.shared.animState == .dance {
            PetState.shared.animState = .idle
        }
    }

    private func cleanTextForSpeech(_ text: String) -> String {
        // Strip markdown backticks, asterisks, hashtags, emojis
        var cleaned = text.replacingOccurrences(of: "`", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.state = .idle
            if PetState.shared.animState == .dance {
                PetState.shared.animState = .idle
            }
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.state = .idle
            if PetState.shared.animState == .dance {
                PetState.shared.animState = .idle
            }
        }
    }
}
