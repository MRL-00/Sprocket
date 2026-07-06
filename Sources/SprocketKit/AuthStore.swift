import Foundation
import os.log
#if canImport(Security)
import Security
#endif

private let authLog = Logger(subsystem: "nz.matt.sprocket", category: "auth")

public struct AuthCredentials: Sendable, Hashable, Codable {
    // Device-flow tokens don't expire and nothing refreshes them — the token
    // is all we store. Older keychain payloads with extra keys still decode.
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

/// Keychain-backed storage for the GitHub access token + UserDefaults-backed
/// storage for the user-supplied OAuth Client ID.
public actor AuthStore {
    public static let tokenAccount = "nz.matt.sprocket.github.token"
    public static let clientIDDefaultsKey = "SprocketGitHubClientID"

    public init() {}

    public func clientID() -> String? {
        UserDefaults.standard.string(forKey: Self.clientIDDefaultsKey)
    }

    public func setClientID(_ value: String?) {
        if let value, !value.isEmpty {
            UserDefaults.standard.set(value, forKey: Self.clientIDDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.clientIDDefaultsKey)
        }
    }

    public func loadCredentials() -> AuthCredentials? {
        #if canImport(Security)
        guard let data = readKeychain(account: Self.tokenAccount) else {
            authLog.info("Keychain load returned nil (no item or read denied)")
            return nil
        }
        do {
            let creds = try JSONDecoder().decode(AuthCredentials.self, from: data)
            authLog.info("Keychain load OK (\(data.count) bytes)")
            return creds
        } catch {
            authLog.info("Keychain load decode failed: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    public func saveCredentials(_ creds: AuthCredentials) throws {
        #if canImport(Security)
        let data = try JSONEncoder().encode(creds)
        try writeKeychain(account: Self.tokenAccount, data: data)
        authLog.info("Keychain save OK (\(data.count) bytes)")
        #endif
    }

    public func clearCredentials() {
        #if canImport(Security)
        deleteKeychain(account: Self.tokenAccount)
        #endif
    }

    #if canImport(Security)
    private func readKeychain(account: String) -> Data? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        if status != errSecSuccess {
            authLog.info("Keychain read failed for \(account), OSStatus=\(status)")
            return nil
        }
        return item as? Data
    }

    private func writeKeychain(account: String, data: Data) throws {
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(attrs as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account,
            ]
            let upd: [String: Any] = [kSecValueData as String: data]
            let s = SecItemUpdate(q as CFDictionary, upd as CFDictionary)
            if s != errSecSuccess { throw AuthError.keychain(s) }
        } else if status != errSecSuccess {
            throw AuthError.keychain(status)
        }
    }

    private func deleteKeychain(account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(q as CFDictionary)
    }
    #endif
}

public enum AuthError: Error, Sendable {
    case keychain(OSStatus)
    case invalidResponse
    case authorizationPending
    case slowDown
    case expiredToken
    case accessDenied
    case unsupportedGrantType
    case incorrectClientCredentials
    case other(String)
}
