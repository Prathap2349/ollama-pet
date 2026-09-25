import Foundation
import AppKit

// MARK: - Explicit Ollama Connection State Machine

public enum OllamaConnectionState: Equatable {
    case checking
    case connecting(message: String)
    case connected(model: String)
    case reconnecting(attempt: Int)
    case failed(reason: String)

    public var isOnline: Bool {
        if case .connected = self { return true }
        return false
    }

    public var isConnecting: Bool {
        switch self {
        case .connecting, .reconnecting, .checking: return true
        default: return false
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    public var badgeColor: NSColor {
        switch self {
        case .connected:
            return .systemGreen
        case .checking, .connecting, .reconnecting:
            return .systemYellow
        case .failed:
            return .systemRed
        }
    }

    public var displayTitle: String {
        switch self {
        case .checking:
            return "Checking Ollama..."
        case .connecting(let msg):
            return msg
        case .connected(let model):
            return "Ollama Connected (\(model))"
        case .reconnecting(let attempt):
            return "Reconnecting (Attempt \(attempt))..."
        case .failed:
            return "Ollama Unavailable"
        }
    }
}

// MARK: - Robust Ollama Client

@MainActor
public class OllamaClient: ObservableObject {
    public static let shared = OllamaClient()

    @Published public var connectionState: OllamaConnectionState = .checking
    @Published public var isOnline: Bool = false
    @Published public var installedModels: [String] = []
    @Published public var activeModel: String = ""
    @Published public var statusMessage: String = "Checking Ollama..."
    @Published public var isChecking: Bool = false
    @Published public var isStartingService: Bool = false
    @Published public var diagnosticError: String? = nil

    private let baseURL = URL(string: "http://127.0.0.1:11434")!
    public var endpoint: String { baseURL.absoluteString }
    private let session: URLSession

    private var autoReconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private var backgroundProcess: Process?

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45.0
        config.timeoutIntervalForResource = 90.0
        self.session = URLSession(configuration: config)

        startAutoReconnectMonitor()
    }

    // MARK: - Auto-Start & Health Check Pipeline

    /// Primary entry point: Checks local service. If offline and autoStart is enabled, attempts to start Ollama.
    public func connectOrStartIfNeeded(preferredModel: String? = nil) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        connectionState = .connecting(message: "Connecting to Ollama...")
        statusMessage = "🟡 Connecting to Ollama..."

        // Step 1: Probe local Ollama service
        let isHealthy = await probeHealthOnce(preferredModel: preferredModel)
        if isHealthy {
            reconnectAttempts = 0
            diagnosticError = nil
            return
        }

        // Step 2: If offline, check if auto-start is enabled
        let autoStart = DataManager.shared.savedData.autoStartOllama ?? true
        if !autoStart {
            setOffline(reason: "Ollama is not running. Turn on Auto-start or launch Ollama manually.")
            return
        }

        // Step 3: Attempt automatic startup
        connectionState = .connecting(message: "Starting local Ollama service...")
        statusMessage = "🟡 Starting Ollama service..."
        isStartingService = true

        let started = await attemptStartLocalOllama()
        isStartingService = false

        if started {
            // Poll for service readiness (up to 15 seconds)
            for _ in 1...15 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if await probeHealthOnce(preferredModel: preferredModel) {
                    reconnectAttempts = 0
                    diagnosticError = nil
                    return
                }
            }
        }

        // Failed to start or connect
        setOffline(reason: "Ollama could not be started automatically. Ensure Ollama is installed on your Mac.")
    }

    /// Health check alias for callers
    public func checkHealth(preferredModel: String? = nil) async {
        await connectOrStartIfNeeded(preferredModel: preferredModel)
    }

    /// Single non-intrusive probe of http://127.0.0.1:11434/api/tags
    public func probeHealthOnce(preferredModel: String? = nil) async -> Bool {
        let tagsURL = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: tagsURL)
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }

            struct TagsResponse: Decodable {
                struct ModelEntry: Decodable {
                    let name: String?
                    let model: String?
                }
                let models: [ModelEntry]?
            }

            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            let models = decoded.models?.compactMap { $0.name ?? $0.model } ?? []

            self.installedModels = models
            self.isOnline = true

            if models.isEmpty {
                self.activeModel = ""
                self.connectionState = .connected(model: "No models installed")
                self.statusMessage = "⚠️ Connected: No models installed"
            } else {
                let savedModel = DataManager.shared.savedData.selectedModel
                if let pref = preferredModel, models.contains(pref) {
                    self.activeModel = pref
                } else if let saved = savedModel, models.contains(saved) {
                    self.activeModel = saved
                } else if !models.contains(activeModel) {
                    self.activeModel = models[0]
                }
                self.connectionState = .connected(model: self.activeModel)
                self.statusMessage = "🟢 Ollama Connected (\(self.activeModel))"
                DataManager.shared.savedData.selectedModel = self.activeModel
            }
            return true
        } catch {
            self.diagnosticError = error.localizedDescription
            return false
        }
    }

    /// Safely attempts to launch the installed Ollama app or binary
    private func attemptStartLocalOllama() async -> Bool {
        // Option A: Look for /Applications/Ollama.app or ~/Applications/Ollama.app
        let candidateApps = [
            URL(fileURLWithPath: "/Applications/Ollama.app"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Ollama.app")
        ]

        for appURL in candidateApps {
            if FileManager.default.fileExists(atPath: appURL.path) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = false
                config.addsToRecentItems = false

                do {
                    _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                    NSLog("[OllamaClient] Launched Ollama via \(appURL.path)")
                    return true
                } catch {
                    NSLog("[OllamaClient] Failed to open \(appURL.path): \(error.localizedDescription)")
                }
            }
        }

        // Option B: Check for CLI binary `ollama` in common paths
        let candidateBinaries = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "/usr/bin/ollama",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ollama/bin/ollama").path
        ]

        var binaryPath: String?
        for path in candidateBinaries {
            if FileManager.default.isExecutableFile(atPath: path) {
                binaryPath = path
                break
            }
        }

        if let bin = binaryPath {
            do {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: bin)
                proc.arguments = ["serve"]
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                try proc.run()
                self.backgroundProcess = proc
                NSLog("[OllamaClient] Launched 'ollama serve' via \(bin)")
                return true
            } catch {
                NSLog("[OllamaClient] Failed to execute '\(bin) serve': \(error.localizedDescription)")
            }
        }

        return false
    }

    /// User-facing retry action
    public func retryConnection() async {
        await connectOrStartIfNeeded()
    }

    /// Refresh model list from Ollama
    public func refreshModels() async {
        isChecking = true
        defer { isChecking = false }
        _ = await probeHealthOnce()
    }

    /// User changes active model
    public func selectModel(_ model: String) {
        guard installedModels.contains(model) else { return }
        self.activeModel = model
        self.connectionState = .connected(model: model)
        self.statusMessage = "🟢 Ollama Connected (\(model))"
        DataManager.shared.savedData.selectedModel = model
        DataManager.shared.saveData()
    }

    private func setOffline(reason: String) {
        isOnline = false
        connectionState = .failed(reason: reason)
        statusMessage = "🔴 \(reason)"
    }

    // MARK: - Auto-Reconnect Timer

    private func startAutoReconnectMonitor() {
        autoReconnectTimer?.invalidate()
        // Proactive health monitor every 20 seconds
        autoReconnectTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let autoReconnect = DataManager.shared.savedData.autoReconnectOllama ?? true
                guard autoReconnect else { return }

                if self.isOnline {
                    // Check if still reachable
                    let stillHealthy = await self.probeHealthOnce()
                    if !stillHealthy {
                        self.isOnline = false
                        self.reconnectAttempts += 1
                        self.connectionState = .reconnecting(attempt: self.reconnectAttempts)
                        self.statusMessage = "🟡 Connection lost. Reconnecting..."
                    }
                } else if case .reconnecting = self.connectionState {
                    // Try to re-establish
                    self.reconnectAttempts += 1
                    let recovered = await self.probeHealthOnce()
                    if recovered {
                        self.reconnectAttempts = 0
                    } else if self.reconnectAttempts >= 5 {
                        self.setOffline(reason: "Ollama connection lost. Click Retry to reconnect.")
                    }
                }
            }
        }
    }

    // MARK: - Chat Requests

    public func sendChat(
        systemPrompt: String,
        messages: [ChatMessage],
        overrideModel: String? = nil
    ) async throws -> String {
        let modelToUse = overrideModel ?? activeModel
        guard !modelToUse.isEmpty else {
            throw NSError(domain: "OllamaClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "No model selected or available. Please install an Ollama model."])
        }

        let chatURL = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct ChatPayloadMessage: Encodable {
            let role: String
            let content: String
        }

        struct ChatRequestPayload: Encodable {
            let model: String
            let messages: [ChatPayloadMessage]
            let stream: Bool
        }

        var payloadMessages: [ChatPayloadMessage] = []
        payloadMessages.append(ChatPayloadMessage(role: "system", content: systemPrompt))

        let recentMessages = messages.suffix(12)
        for msg in recentMessages {
            let role = msg.role == "user" ? "user" : "assistant"
            payloadMessages.append(ChatPayloadMessage(role: role, content: msg.content))
        }

        let payload = ChatRequestPayload(model: modelToUse, messages: payloadMessages, stream: false)
        request.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "OllamaClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response from Ollama"])
            }

            guard httpResponse.statusCode == 200 else {
                let rawError = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw NSError(domain: "OllamaClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ollama error: \(rawError)"])
            }

            struct ChatResponsePayload: Decodable {
                struct MessageContent: Decodable {
                    let role: String?
                    let content: String?
                }
                let message: MessageContent?
                let response: String?
            }

            if let chatResp = try? JSONDecoder().decode(ChatResponsePayload.self, from: data) {
                if let content = chatResp.message?.content, !content.isEmpty {
                    return content
                }
                if let resp = chatResp.response, !resp.isEmpty {
                    return resp
                }
            }

            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                return raw
            }

            throw NSError(domain: "OllamaClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty reply from Ollama"])
        } catch {
            // Signal connection degradation gracefully
            if (error as NSError).domain == NSURLErrorDomain {
                self.isOnline = false
                self.connectionState = .reconnecting(attempt: 1)
                self.statusMessage = "🟡 Connection lost. Reconnecting..."
            }
            throw error
        }
    }

    public func streamChat(
        systemPrompt: String,
        messages: [ChatMessage],
        overrideModel: String? = nil,
        onToken: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        let modelToUse = overrideModel ?? activeModel
        guard !modelToUse.isEmpty else {
            throw NSError(domain: "OllamaClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "No model selected. Please pull an Ollama model (e.g. ollama pull llama3)."])
        }

        let chatURL = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct ChatPayloadMessage: Encodable {
            let role: String
            let content: String
        }

        struct ChatRequestPayload: Encodable {
            let model: String
            let messages: [ChatPayloadMessage]
            let stream: Bool
        }

        var payloadMessages: [ChatPayloadMessage] = []
        payloadMessages.append(ChatPayloadMessage(role: "system", content: systemPrompt))

        let recentMessages = messages.suffix(12)
        for msg in recentMessages {
            let role = msg.role == "user" ? "user" : "assistant"
            payloadMessages.append(ChatPayloadMessage(role: role, content: msg.content))
        }

        let payload = ChatRequestPayload(model: modelToUse, messages: payloadMessages, stream: true)
        request.httpBody = try JSONEncoder().encode(payload)

        do {
            let (asyncBytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "OllamaClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid stream response from Ollama"])
            }

            struct StreamChunk: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message?
                let response: String?
                let done: Bool?
            }

            var fullAccumulation = ""

            for try await line in asyncBytes.lines {
                guard !line.isEmpty else { continue }
                if let data = line.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) {
                    let token = chunk.message?.content ?? chunk.response ?? ""
                    if !token.isEmpty {
                        fullAccumulation += token
                        await MainActor.run {
                            onToken(token)
                        }
                    }
                    if chunk.done == true {
                        break
                    }
                }
            }

            return fullAccumulation
        } catch {
            if (error as NSError).domain == NSURLErrorDomain {
                self.isOnline = false
                self.connectionState = .reconnecting(attempt: 1)
                self.statusMessage = "🟡 Connection lost. Reconnecting..."
            }
            throw error
        }
    }

    deinit {
        autoReconnectTimer?.invalidate()
        backgroundProcess?.terminate()
    }
}
