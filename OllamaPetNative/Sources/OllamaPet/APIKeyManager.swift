import Foundation
import Security

/// Thread-safe manager for storing API keys securely in the macOS Keychain.
/// Keys are never stored in UserDefaults, plaintext files, or printed to logs.
public final class APIKeyManager {
    public static let shared = APIKeyManager()

    private let serviceName = "com.ollamapet.native.apikeys"
    private let lock = NSLock()

    private init() {}

    /// Save an API key securely to the Keychain
    @discardableResult
    public func setKey(_ key: String, for provider: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return deleteKey(for: provider)
        }

        guard let data = trimmed.data(using: .utf8) else { return false }

        // Try updating first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider.lowercased()
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if status == errSecSuccess {
            return true
        } else if status == errSecItemNotFound {
            // Insert new item
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            return addStatus == errSecSuccess
        }

        return false
    }

    /// Retrieve an API key securely from Keychain
    public func getKey(for provider: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider.lowercased(),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data, let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Delete an API key from Keychain
    @discardableResult
    public func deleteKey(for provider: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider.lowercased()
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if a valid API key exists for the provider
    public func hasKey(for provider: String) -> Bool {
        guard let key = getKey(for: provider), !key.isEmpty else { return false }
        return true
    }

    /// Return a safe masked representation of the key (e.g., "sk-...1234")
    public func maskedKey(for provider: String) -> String {
        guard let key = getKey(for: provider), !key.isEmpty else {
            return "Not Configured"
        }
        if key.count <= 8 {
            return "••••••••"
        }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)••••\(suffix)"
    }
}
