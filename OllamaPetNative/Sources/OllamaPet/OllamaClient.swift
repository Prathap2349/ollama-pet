import Foundation

@MainActor
public class OllamaClient: ObservableObject {
    public static let shared = OllamaClient()

    @Published public var isOnline: Bool = false
    @Published public var installedModels: [String] = []
    @Published public var activeModel: String = ""
    @Published public var statusMessage: String = "Checking Ollama..."
    @Published public var isChecking: Bool = false

    private let baseURL = URL(string: "http://127.0.0.1:11434")!
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        self.session = URLSession(configuration: config)
    }

    public func checkHealth(preferredModel: String? = nil) async {
        isChecking = true
        defer { isChecking = false }

        let tagsURL = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: tagsURL)
        request.timeoutInterval = 4.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                setOffline(reason: "HTTP error from Ollama")
                return
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

            if models.isEmpty {
                isOnline = true
                installedModels = []
                activeModel = ""
                statusMessage = "⚠️ Ollama online: no models installed. Run: ollama pull <model>"
            } else {
                isOnline = true
                installedModels = models

                if let pref = preferredModel, models.contains(pref) {
                    activeModel = pref
                } else if !models.contains(activeModel) {
                    activeModel = models[0]
                }
                statusMessage = "🟢 Ollama (\(activeModel))"
            }
        } catch {
            setOffline(reason: "Ollama offline — run: ollama serve")
        }
    }

    private func setOffline(reason: String) {
        isOnline = false
        installedModels = []
        activeModel = ""
        statusMessage = "🔴 \(reason)"
    }

    public func sendChat(
        systemPrompt: String,
        messages: [ChatMessage],
        overrideModel: String? = nil
    ) async throws -> String {
        let modelToUse = overrideModel ?? activeModel
        guard !modelToUse.isEmpty else {
            throw NSError(domain: "OllamaClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "No model selected or available"])
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

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OllamaClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
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

        if let raw = String(data: data, encoding: .utf8) {
            return raw
        }

        throw NSError(domain: "OllamaClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty reply from Ollama"])
    }
}
