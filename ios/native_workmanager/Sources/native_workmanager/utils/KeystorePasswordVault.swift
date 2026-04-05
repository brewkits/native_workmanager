import Foundation
import Security

/// SC-C-001: Secure password vault backed by iOS Keychain Services.
///
/// The task database (SQLite) stores worker configuration including any fields passed at
/// enqueue time. Passing a password directly in workerConfig would persist it on disk in
/// plaintext. This vault stores the password under a random UUID key in the iOS Keychain
/// (hardware-backed Secure Enclave on supported devices) and replaces the `password` field
/// in the stored config with a `passwordKey` UUID that the worker resolves at runtime.
///
/// Usage flow:
///   1. Before task store: `let key = KeystorePasswordVault.shared.store(password)`
///   2. Replace `workerConfig["password"]` with `workerConfig["passwordKey"] = key`
///   3. In the worker: `let password = KeystorePasswordVault.shared.retrieveAndDelete(key)`
final class KeystorePasswordVault {
    static let shared = KeystorePasswordVault()
    private init() {}

    private let service = "dev.brewkits.native_workmanager.crypto_vault"

    /// Store [secret] in the Keychain; returns the UUID key to pass to the worker.
    func store(_ secret: String) -> String {
        let key = UUID().uuidString
        guard let secretData = secret.data(using: .utf8) else {
            NativeLogger.e("KeystorePasswordVault: Failed to encode secret as UTF-8")
            return key
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: secretData,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        // Ensure no stale entry exists before adding
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NativeLogger.e("KeystorePasswordVault: SecItemAdd failed with status \(status)")
        }
        return key
    }

    /// Retrieve and immediately delete the secret associated with [key].
    /// Returns nil if the key is not found (e.g. vault cleared between retries).
    func retrieveAndDelete(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            NativeLogger.w("KeystorePasswordVault: Secret not found for key=\(key)")
            return nil
        }

        delete(key)
        return secret
    }

    /// Delete without retrieving (for cancel/cleanup paths).
    func delete(_ key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
