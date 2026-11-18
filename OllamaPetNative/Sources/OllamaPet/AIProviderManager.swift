import Foundation
import Combine

public enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case ollama = "ollama"
    case openai = "openai"
    case gemini = "gemini"
    case anthropic = "anthropic"
    case groq = "groq"
    case xai = "xai"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ollama: return "Ollama (Local)"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
        case .groq: return "Groq Cloud"
        case .xai: return "xAI Grok"
        case .custom: return "Custom Provider"
        }
    }

    public var defaultModel: String {
        switch self {
        case .ollama: return "llama3"
        case .openai: return "gpt-5.4-mini"
        case .gemini: return "gemini-3.8-flash"
        case .anthropic: return "claude-haiku-4-5-20251001"
        case .groq: return "openai/gpt-oss-120b"
        case .xai: return "grok-4.7"
        case .custom: return "model"
        }
    }

    public var icon: String {
        switch self {
        case .ollama: return "desktopcomputer"
        case .openai: return "sparkles"
        case .gemini: return "bolt.fill"
        case .anthropic: return "brain.head.profile"
        case .groq: return "bolt.horizontal.fill"
        case .xai: return "sparkle.magnifyingglass"
        case .custom: return "server.rack"
        }
    }

    public var requiresKey: Bool {
        return self != .ollama
    }
}

public enum AIGenerationPolicy {
    case normal
    case localOnly
}

/// Unified manager handling local Ollama and configured cloud AI providers.
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

        let savedData = DataManager.shared.savedData
        if savedData.selectedProvider == AIProvider.custom.rawValue,
           let id = savedData.selectedCustomAIProviderID,
           savedData.customAIProviders?.contains(where: { $0.id == id }) == true {
            self.activeProvider = .custom
        } else if let saved = savedData.selectedProvider, let provider = AIProvider(rawValue: saved) {
            self.activeProvider = provider == .custom ? .ollama : provider
        }
    }

    public func setProvider(_ provider: AIProvider) {
        guard provider != .custom else { return }
        self.activeProvider = provider
        DataManager.shared.savedData.selectedProvider = provider.rawValue
        DataManager.shared.saveData()
    }

    public func setCustomProvider(id: String) {
        guard DataManager.shared.savedData.customAIProviders?.contains(where: { $0.id == id }) == true else { return }
        activeProvider = .custom
        DataManager.shared.savedData.selectedProvider = AIProvider.custom.rawValue
        DataManager.shared.savedData.selectedCustomAIProviderID = id
        DataManager.shared.saveData()
    }

    /// Stream a chat completion with policy enforcement (e.g. local-only for Daily Awareness)
    public func streamChat(
        systemPrompt: String,
        messages: [ChatMessage],
        policy: AIGenerationPolicy = .normal,
        onToken: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        isGenerating = true
        defer { isGenerating = false }

        // Enforce Local-Only Policy for Daily Awareness (Never send private data or fallback to Cloud AI)
        if policy == .localOnly {
            let ollama = OllamaClient.shared
            if !ollama.isOnline {
                await ollama.checkHealth(preferredModel: DataManager.shared.savedData.selectedModel)
            }
            guard ollama.isOnline else {
                throw NSError(
                    domain: "AIProviderManager",
                    code: 503,
                    userInfo: [NSLocalizedDescriptionKey: "Daily Awareness operates exclusively in local-only mode to safeguard your personal calendar and private information. Ollama is currently offline. Please start Ollama to generate your briefing."]
                )
            }
            lastUsedProvider = .ollama
            return try await ollama.streamChat(systemPrompt: systemPrompt, messages: messages, onToken: onToken)
        }

        // Use only the explicitly configured fallback when Ollama is offline.
        let provider = activeProvider

        // If local Ollama is chosen:
        if provider == .ollama {
            let ollama = OllamaClient.shared
            if ollama.isOnline {
                do {
                    lastUsedProvider = .ollama
                    return try await ollama.streamChat(systemPrompt: systemPrompt, messages: messages, onToken: onToken)
                } catch {
                    throw error
                }
            } else {
                // Ollama is offline. Try to start or fallback
                await ollama.checkHealth(preferredModel: DataManager.shared.savedData.selectedModel)
                if ollama.isOnline {
                    lastUsedProvider = .ollama
                    return try await ollama.streamChat(systemPrompt: systemPrompt, messages: messages, onToken: onToken)
                } else if let fallback = configuredFallbackProvider() {
                    lastUsedProvider = fallback
                    PetState.shared.showBubble("☁️ Ollama is offline. Using \(fallbackDisplayName(fallback)).", duration: 4.0)
                    return try await streamCloudChat(
                        provider: fallback,
                        systemPrompt: systemPrompt,
                        messages: messages,
                        onToken: onToken,
                        customProviderID: fallback == .custom ? configuredFallbackCustomID() : nil
                    )
                } else {
                    throw NSError(
                        domain: "AIProviderManager",
                        code: 503,
                        userInfo: [NSLocalizedDescriptionKey: "Ollama is offline. Start Ollama or enable a cloud fallback provider in Settings."]
                    )
                }
            }
        } else {
            // Cloud provider
            let keyAccount = provider == .custom ? customKeyAccount(for: DataManager.shared.savedData.selectedCustomAIProviderID ?? "") : provider.rawValue
            guard APIKeyManager.shared.hasKey(for: keyAccount) else {
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
        let cloudProviders: [AIProvider] = [.openai, .anthropic, .gemini, .groq, .xai]
        for p in cloudProviders {
            if APIKeyManager.shared.hasKey(for: p.rawValue) {
                return p
            }
        }
        return nil
    }

    private func configuredFallbackProvider() -> AIProvider? {
        let data = DataManager.shared.savedData
        guard data.cloudFallbackEnabled ?? false else { return nil }
        let selection = data.cloudFallbackProvider ?? "openai"
        if selection.hasPrefix("custom:") {
            let id = String(selection.dropFirst("custom:".count))
            guard data.customAIProviders?.contains(where: { $0.id == id }) == true,
                  APIKeyManager.shared.hasKey(for: customKeyAccount(for: id)) else { return nil }
            return .custom
        }
        guard let provider = AIProvider(rawValue: selection), provider != .ollama, provider != .custom,
              APIKeyManager.shared.hasKey(for: provider.rawValue) else { return nil }
        return provider
    }

    private func configuredFallbackCustomID() -> String? {
        let selection = DataManager.shared.savedData.cloudFallbackProvider ?? "openai"
        guard selection.hasPrefix("custom:") else { return nil }
        return String(selection.dropFirst("custom:".count))
    }

    private func fallbackDisplayName(_ provider: AIProvider) -> String {
        if provider == .custom,
           let id = DataManager.shared.savedData.cloudFallbackProvider?.replacingOccurrences(of: "custom:", with: ""),
           let custom = DataManager.shared.savedData.customAIProviders?.first(where: { $0.id == id }) {
            return custom.name
        }
        return provider.displayName
    }

    private func customKeyAccount(for id: String) -> String { "custom-provider-\(id)" }

    public func validatedCustomBaseURL(_ rawURL: String) throws -> String {
        let normalized = rawURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let components = URLComponents(string: normalized),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1"].contains(host)) else {
            throw NSError(domain: "AIProviderManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Use an HTTPS URL, or HTTP only for localhost or 127.0.0.1."])
        }
        return normalized
    }

    private func openAICompatibleURL(_ baseURL: String, endpoint: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1"].contains(host)) else {
            throw NSError(domain: "AIProviderManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Provider URL must use HTTPS (HTTP is allowed only for localhost or 127.0.0.1)."])
        }
        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            path = String(path.dropLast("chat/completions".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if path.isEmpty { path = endpoint } else { path += "/\(endpoint)" }
        components.path = "/" + path
        guard let url = components.url else {
            throw NSError(domain: "AIProviderManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid provider URL."])
        }
        return url
    }

    private func normalizedHistory(_ messages: [ChatMessage]) -> [(role: String, content: String)] {
        var normalized = messages.suffix(10).map { message in
            (role: message.role == "user" ? "user" : "assistant", content: message.content)
        }
        while normalized.first?.role == "assistant" { normalized.removeFirst() }
        var merged: [(role: String, content: String)] = []
        for message in normalized {
            if merged.last?.role == message.role {
                merged[merged.count - 1].content += "\n\(message.content)"
            } else {
                merged.append(message)
            }
        }
        while merged.last?.role == "assistant" { merged.removeLast() }
        return merged
    }

    private func readResponseBody(_ bytes: URLSession.AsyncBytes) async -> String {
        var body = ""
        do {
            for try await line in bytes.lines {
                if body.utf8.count > 16_000 { break }
                body += line + "\n"
            }
        } catch { }
        return body
    }

    private func providerHTTPError(status: Int, body: String, apiKey: String) -> NSError {
        let safeBody = body.replacingOccurrences(of: apiKey, with: "[redacted]")
        let lower = safeBody.lowercased()
        let reason: String
        if status == 401 || status == 403 {
            reason = "Invalid or unauthorized API key."
        } else if status == 429 {
            reason = "Rate limit reached or account has no available credit."
        } else if status == 404 || lower.contains("model_not_found") || lower.contains("model not found") || lower.contains("unknown model") || (lower.contains("model") && (lower.contains("invalid") || lower.contains("unsupported") || lower.contains("does not exist"))) {
            reason = "Model not found or unavailable."
        } else {
            reason = "Provider request failed."
        }
        let detail = safeBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = detail.isEmpty ? "\(reason) HTTP \(status)." : "\(reason) HTTP \(status): \(detail)"
        return NSError(domain: "AIProviderManager", code: status, userInfo: [NSLocalizedDescriptionKey: message])
    }

    // MARK: - Cloud Providers Streaming

    private func streamCloudChat(
        provider: AIProvider,
        systemPrompt: String,
        messages: [ChatMessage],
        onToken: @MainActor @escaping (String) -> Void,
        apiKeyOverride: String? = nil,
        customProviderID: String? = nil,
        modelOverride: String? = nil,
        maxTokens: Int = 1024
    ) async throws -> String {
        let data = DataManager.shared.savedData
        switch provider {
        case .openai:
            return try await streamOpenAICompatible(
                endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
                apiKey: apiKeyOverride ?? APIKeyManager.shared.getKey(for: "openai") ?? "",
                model: modelOverride ?? data.openaiModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken,
                maxTokens: maxTokens,
                maxTokensField: "max_completion_tokens"
            )
        case .groq:
            return try await streamOpenAICompatible(
                endpoint: URL(string: "https://api.groq.com/openai/v1/chat/completions")!,
                apiKey: apiKeyOverride ?? APIKeyManager.shared.getKey(for: "groq") ?? "",
                model: modelOverride ?? data.groqModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken,
                maxTokens: maxTokens
            )
        case .xai:
            return try await streamOpenAICompatible(
                endpoint: URL(string: "https://api.x.ai/v1/chat/completions")!,
                apiKey: apiKeyOverride ?? APIKeyManager.shared.getKey(for: "xai") ?? "",
                model: modelOverride ?? data.xaiModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken,
                maxTokens: maxTokens
            )
        case .gemini:
            return try await streamGemini(
                apiKey: apiKeyOverride ?? APIKeyManager.shared.getKey(for: "gemini") ?? "",
                model: modelOverride ?? data.geminiModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken,
                maxTokens: maxTokens
            )
        case .anthropic:
            return try await streamAnthropic(
                apiKey: apiKeyOverride ?? APIKeyManager.shared.getKey(for: "anthropic") ?? "",
                model: modelOverride ?? data.anthropicModel ?? provider.defaultModel,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken,
                maxTokens: maxTokens
            )
        case .custom:
            guard let custom = data.customAIProviders?.first(where: { $0.id == (customProviderID ?? data.selectedCustomAIProviderID) }) else {
                throw NSError(domain: "AIProviderManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Custom provider was deleted or is unavailable."])
            }
            let account = customKeyAccount(for: custom.id)
            let endpoint = try openAICompatibleURL(custom.baseURL, endpoint: "chat/completions")
            return try await streamOpenAICompatible(
                endpoint: endpoint,
                apiKey: apiKeyOverride ?? APIKeyManager.shared.getKey(for: account) ?? "",
                model: modelOverride ?? custom.model,
                systemPrompt: systemPrompt,
                messages: messages,
                onToken: onToken,
                maxTokens: maxTokens
            )
        case .ollama:
            throw NSError(domain: "AIProviderManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ollama is not a cloud provider."])
        }
    }

    // MARK: - OpenAI / Groq Compatible SSE Streamer

    private func streamOpenAICompatible(
        endpoint: URL,
        apiKey: String,
        model: String,
        systemPrompt: String,
        messages: [ChatMessage],
        onToken: @MainActor @escaping (String) -> Void,
        maxTokens: Int = 1024,
        maxTokensField: String = "max_tokens"
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
            maxTokensField: maxTokens
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIProviderManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = await readResponseBody(bytes)
            throw providerHTTPError(status: httpResponse.statusCode, body: body, apiKey: apiKey)
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
        onToken: @MainActor @escaping (String) -> Void,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse") else {
            throw NSError(domain: "AIProviderManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        var contents: [[String: Any]] = []
        for msg in normalizedHistory(messages) {
            let role = msg.role == "user" ? "user" : "model"
            contents.append([
                "role": role,
                "parts": [["text": msg.content]]
            ])
        }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": contents,
            "generationConfig": ["maxOutputTokens": maxTokens]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIProviderManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini server response."])
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorBody = await readResponseBody(bytes)
            throw providerHTTPError(status: httpResponse.statusCode, body: errorBody, apiKey: apiKey)
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
        onToken: @MainActor @escaping (String) -> Void,
        maxTokens: Int = 1024
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
        for msg in normalizedHistory(messages) {
            let role = msg.role == "user" ? "user" : "assistant"
            formattedMessages.append(["role": role, "content": msg.content])
        }

        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "messages": formattedMessages,
            "max_tokens": maxTokens,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIProviderManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Anthropic server response."])
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorBody = await readResponseBody(bytes)
            throw providerHTTPError(status: httpResponse.statusCode, body: errorBody, apiKey: apiKey)
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

    public func fetchModels(provider: AIProvider, customProviderID: String? = nil, apiKeyOverride: String? = nil) async throws -> [String] {
        let data = DataManager.shared.savedData
        let account: String
        let url: URL
        switch provider {
        case .openai:
            account = "openai"
            url = URL(string: "https://api.openai.com/v1/models")!
        case .groq:
            account = "groq"
            url = URL(string: "https://api.groq.com/openai/v1/models")!
        case .xai:
            account = "xai"
            url = URL(string: "https://api.x.ai/v1/models")!
        case .gemini:
            account = "gemini"
            url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!
        case .anthropic:
            account = "anthropic"
            url = URL(string: "https://api.anthropic.com/v1/models")!
        case .custom:
            guard let custom = data.customAIProviders?.first(where: { $0.id == (customProviderID ?? data.selectedCustomAIProviderID) }) else {
                throw NSError(domain: "AIProviderManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Custom provider is unavailable."])
            }
            account = customKeyAccount(for: custom.id)
            url = try openAICompatibleURL(custom.baseURL, endpoint: "models")
        case .ollama:
            return OllamaClient.shared.installedModels
        }

        let enteredKey = apiKeyOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = enteredKey?.isEmpty == false ? enteredKey! : (APIKeyManager.shared.getKey(for: account) ?? "")
        guard !key.isEmpty else {
            throw NSError(domain: "AIProviderManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Enter or save an API key before refreshing models."])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        switch provider {
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .gemini:
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        default:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AIProviderManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid provider response."])
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw providerHTTPError(status: http.statusCode, body: body, apiKey: key)
        }
        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] ?? [:]
        let values = (json["data"] as? [[String: Any]])?.compactMap { $0["id"] as? String }
            ?? (json["models"] as? [[String: Any]])?.compactMap { ($0["name"] as? String)?.replacingOccurrences(of: "models/", with: "") }
            ?? []
        return values.sorted()
    }

    public func testProvider(
        provider: AIProvider,
        apiKeyOverride: String? = nil,
        customProviderID: String? = nil,
        modelOverride: String? = nil
    ) async -> (success: Bool, message: String) {
        if provider == .ollama {
            let online = await OllamaClient.shared.probeHealthOnce()
            return online
                ? (true, "Ollama connection verified! Models available: \(OllamaClient.shared.installedModels.count)")
                : (false, "Could not reach Ollama at 127.0.0.1:11434. Make sure Ollama is installed and running.")
        }

        let account = provider == .custom ? customKeyAccount(for: customProviderID ?? "") : provider.rawValue
        let enteredKey = apiKeyOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key = enteredKey?.isEmpty == false ? enteredKey : APIKeyManager.shared.getKey(for: account), !key.isEmpty else {
            return (false, "No API key configured for \(provider.displayName).")
        }

        do {
            var sampleResponse = ""
            _ = try await streamCloudChat(
                provider: provider,
                systemPrompt: "You are a helpful assistant.",
                messages: [ChatMessage(role: "user", content: "Reply with the single word 'OK'")],
                onToken: { sampleResponse += $0 },
                apiKeyOverride: key,
                customProviderID: customProviderID,
                modelOverride: modelOverride,
                maxTokens: 8
            )
            return (true, "Connected to \(provider.displayName) successfully!")
        } catch {
            if let urlError = error as? URLError {
                return (false, "Network failure (no HTTP status): \(urlError.localizedDescription)")
            }
            return (false, error.localizedDescription)
        }
    }
}
