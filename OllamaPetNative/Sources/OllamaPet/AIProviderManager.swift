import Foundation
import Combine

public enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case ollama = "ollama"
    case openai = "openai"
    case gemini = "gemini"
    case anthropic = "anthropic"
    case groq = "groq"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ollama: return "Ollama (Local)"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
        case .groq: return "Groq Cloud"
        }
    }

    public var defaultModel: String {
        switch self {
        case .ollama: return "llama3"
        case .openai: return "gpt-4o-mini"
        case .gemini: return "gemini-1.5-flash"
        case .anthropic: return "claude-3-5-haiku-20241022"
        case .groq: return "llama-3.3-70b-versatile"
        }
    }

    public var icon: String {
        switch self {
        case .ollama: return "desktopcomputer"
        case .openai: return "sparkles"
        case .gemini: return "bolt.fill"
        case .anthropic: return "brain.head.profile"
        case .groq: return "bolt.horizontal.fill"
        }
    }

    public var requiresKey: Bool {
        return self != .ollama
    }
}

/// Unified manager handling local Ollama and Cloud AI providers (OpenAI, Gemini, Anthropic, Groq).
/// Ensures Ollama is strictly optional and automatically falls back to configured cloud providers if Ollama is unavailable.
@MainActor
public final class AIProviderManager: ObservableObject {
    public static let shared = AIProviderManager()

    @Published public var activeProvider: AIProvider = .ollama
    @Published public var isGenerating: Bool = false
    @Published public var lastUsedProvider: AIProvider? = nil

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45.0
        config.timeoutIntervalForResource = 120.0
        self.session = URLSession(configuration: config)

        if let saved = DataManager.shared.savedData.selectedProvider,
           let provider = AIProvider(rawValue: saved) {
            self.activeProvider = provider
        }
    }

    public func setProvider(_ provider: AIProvider) {
        self.activeProvider = provider
        DataManager.shared.savedData.selectedProvider = provider.rawValue
        DataManager.shared.saveData()
    }

    /// Stream a chat completion with automatic fallback
    public func streamChat(
        systemPrompt: String,
        messages: [ChatMessage],
        onToken: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        isGenerating = true
        defer { isGenerating = false }

        // Determine effective provider
        let provider = activeProvider

        // If local Ollama is chosen:
        if provider == .ollama {
            let ollama = OllamaClient.shared
            if ollama.isOnline {
                do {
                    lastUsedProvider = .ollama
                    return try await ollama.streamChat(systemPrompt: systemPrompt, messages: messages, onToken: onToken)
                } catch {
                    // Ollama error, attempt fallback to cloud if configured
                    if let fallback = firstAvailableCloudProvider() {
                        lastUsedProvider = fallback
                        return try await streamCloudChat(provider: fallback, systemPrompt: systemPrompt, messages: messages, onToken: onToken)
                    }
                    throw error
                }
            } else {
                // Ollama is offline. Try to start or fallback
                await ollama.checkHealth(preferredModel: DataManager.shared.savedData.selectedModel)
                if ollama.isOnline {
                    lastUsedProvider = .ollama
                    return try await ollama.streamChat(systemPrompt: systemPrompt, messages: messages, onToken: onToken)
                } else if let fallback = firstAvailableCloudProvider() {
                    lastUsedProvider = fallback
                    return try await streamCloudChat(provider: fallback, systemPrompt: systemPrompt, messages: messages, onToken: onToken)
                } else {
                    throw NSError(
                        domain: "AIProviderManager",
                        code: 503,
                        userInfo: [NSLocalizedDescriptionKey: "Ollama is currently offline. You can start Ollama or configure a Cloud AI key (OpenAI, Gemini, Groq, Anthropic) in Settings."]
                    )
                }
            }
        } else {
            // Cloud provider
            guard APIKeyManager.shared.hasKey(for: provider.rawValue) else {
                throw NSError(
                    domain: "AIProviderManager",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "No API Key configured for \(provider.displayName). Open Settings -> AI Providers to add your key."]
                )
            }
            lastUsedProvider = provider
            return try await streamCloudChat(provider: provider, systemPrompt: systemPrompt, messages: messages, onToken: onToken)
        }
    }

    /// Find the first cloud provider that has a valid API key configured
    public func firstAvailableCloudProvider() -> AIProvider? {
        let cloudProviders: [AIProvider] = [.groq, .openai, .gemini, .anthropic]
        for p in cloudProviders {
            if APIKeyManager.shared.hasKey(for: p.rawValue) {
                return p
            }
        }
        return nil
    }

    // MARK: - Cloud Providers Streaming

    private func streamCloudChat(
        provider: AIProvider,
        systemPrompt: String,
        messages: [ChatMessage],
        onToken: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        switch provider {
        case .openai:
            return try await streamOpenAICompatible(
                endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
                apiKey: APIKeyManager.shared.getKey(for: "openai") ?? "",
                model: DataManager.shared.savedData.openaiModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken
            )
        case .groq:
            return try await streamOpenAICompatible(
                endpoint: URL(string: "https://api.groq.com/openai/v1/chat/completions")!,
                apiKey: APIKeyManager.shared.getKey(for: "groq") ?? "",
                model: DataManager.shared.savedData.groqModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken
            )
        case .gemini:
            return try await streamGemini(
                apiKey: APIKeyManager.shared.getKey(for: "gemini") ?? "",
                model: DataManager.shared.savedData.geminiModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken
            )
        case .anthropic:
            return try await streamAnthropic(
                apiKey: APIKeyManager.shared.getKey(for: "anthropic") ?? "",
                model: DataManager.shared.savedData.anthropicModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken
            )
        case .ollama:
            return ""
        }
    }

    // MARK: - OpenAI / Groq Compatible SSE Streamer

    private func streamOpenAICompatible(
        endpoint: URL,
        apiKey: String,
        model: String,
        systemPrompt: String,
        messages: [ChatMessage],
        onToken: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var formattedMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        for msg in messages.suffix(10) {
            let role = msg.role == "user" ? "user" : "assistant"
            formattedMessages.append(["role": role, "content": msg.content])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": formattedMessages,
            "stream": true,
            "max_tokens": 1024
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIProviderManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AIProviderManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned error code \(httpResponse.statusCode)"])
        }

        var fullText = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("data: ") {
                let jsonStr = String(trimmed.dropFirst(6))
                if jsonStr == "[DONE]" { break }
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    fullText += content
                    onToken(content)
                }
            }
        }
        return fullText
    }

    // MARK: - Gemini SSE Streamer

    private func streamGemini(
        apiKey: String,
        model: String,
        systemPrompt: String,
        messages: [ChatMessage],
        onToken: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)") else {
            throw NSError(domain: "AIProviderManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = []
        contents.append([
            "role": "user",
            "parts": [["text": "System Context: \(systemPrompt)"]]
        ])
        for msg in messages.suffix(10) {
            let role = msg.role == "user" ? "user" : "model"
            contents.append([
                "role": role,
                "parts": [["text": msg.content]]
            ])
        }

        let body: [String: Any] = ["contents": contents]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AIProviderManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Gemini API error"])
        }

        var fullText = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("data: ") {
                let jsonStr = String(trimmed.dropFirst(6))
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    fullText += text
                    onToken(text)
                }
            }
        }
        return fullText
    }

    // MARK: - Anthropic Messages SSE Streamer

    private func streamAnthropic(
        apiKey: String,
        model: String,
        systemPrompt: String,
        messages: [ChatMessage],
        onToken: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw NSError(domain: "AIProviderManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Anthropic URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var formattedMessages: [[String: String]] = []
        for msg in messages.suffix(10) {
            let role = msg.role == "user" ? "user" : "assistant"
            formattedMessages.append(["role": role, "content": msg.content])
        }

        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "messages": formattedMessages,
            "max_tokens": 1024,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AIProviderManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Anthropic API error"])
        }

        var fullText = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("data: ") {
                let jsonStr = String(trimmed.dropFirst(6))
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String,
                   type == "content_block_delta",
                   let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    fullText += text
                    onToken(text)
                }
            }
        }
        return fullText
    }

    // MARK: - Testing Connection

    public func testProvider(provider: AIProvider) async -> (success: Bool, message: String) {
        if provider == .ollama {
            let online = await OllamaClient.shared.probeHealthOnce()
            return online
                ? (true, "Ollama connection verified! Models available: \(OllamaClient.shared.installedModels.count)")
                : (false, "Could not reach Ollama at 127.0.0.1:11434. Make sure Ollama is installed and running.")
        }

        guard let key = APIKeyManager.shared.getKey(for: provider.rawValue), !key.isEmpty else {
            return (false, "No API key configured for \(provider.displayName).")
        }

        do {
            var sampleResponse = ""
            _ = try await streamCloudChat(
                provider: provider,
                systemPrompt: "You are a helpful assistant.",
                messages: [ChatMessage(role: "user", content: "Reply with the single word 'OK'")],
                onToken: { sampleResponse += $0 }
            )
            return (true, "Connected to \(provider.displayName) successfully!")
        } catch {
            return (false, "Failed to connect: \(error.localizedDescription)")
        }
    }
}
