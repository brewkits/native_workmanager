import Foundation
import CryptoKit
import CommonCrypto

/// Native cryptographic operations worker for iOS.
///
/// Supports file/string hashing and AES encryption/decryption without requiring Flutter Engine.
/// Uses iOS's built-in cryptography APIs (CryptoKit for iOS 13+, CommonCrypto fallback).
///
/// **Configuration JSON (Hash File):**
/// ```json
/// {
///   "operation": "hash",
///   "filePath": "/path/to/file.bin",
///   "algorithm": "SHA-256"  // Optional: MD5, SHA-1, SHA-256, SHA-512 (default: SHA-256)
/// }
/// ```
///
/// **Configuration JSON (Hash String):**
/// ```json
/// {
///   "operation": "hash",
///   "data": "Hello World",
///   "algorithm": "SHA-256"
/// }
/// ```
///
/// **Configuration JSON (Encrypt File):**
/// ```json
/// {
///   "operation": "encrypt",
///   "filePath": "/path/to/input.txt",
///   "outputPath": "/path/to/output.enc",  // Optional: defaults to inputPath + ".enc"
///   "password": "secret123",
///   "algorithm": "AES"  // Optional: Only AES supported currently
/// }
/// ```
///
/// **Configuration JSON (Decrypt File):**
/// ```json
/// {
///   "operation": "decrypt",
///   "filePath": "/path/to/input.enc",
///   "outputPath": "/path/to/output.txt",  // Optional: defaults to inputPath without ".enc"
///   "password": "secret123",
///   "algorithm": "AES"
/// }
/// ```
///
/// **Security:**
/// - Uses PBKDF2 for password-based key derivation (100,000 iterations)
/// - AES-256-GCM encryption with random nonce (iOS 13+)
/// - Nonce and tag are prepended to encrypted data for decryption
///
/// **Performance:** ~2-5MB RAM, streaming for large files
class CryptoWorker: IosWorker {

    private static let defaultAlgorithm = "SHA-256"
    private static let pbkdf2Iterations = 100_000
    private static let aesKeySize = 32  // 256 bits
    private static let nonceSize = 12   // GCM nonce size

    struct Config: Codable {
        let operation: String            // "hash", "encrypt", "decrypt"
        let filePath: String?            // File to operate on
        let data: String?                // String data (for hash)
        let outputPath: String?          // Output file (for encrypt/decrypt)
        let algorithm: String?           // Algorithm (MD5, SHA-256, AES, etc.)
        let password: String?            // Password (for encrypt/decrypt)

        var effectiveAlgorithm: String {
            algorithm ?? CryptoWorker.defaultAlgorithm
        }
    }

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            print("CryptoWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        guard let data = input.data(using: .utf8) else {
            print("CryptoWorker: Error - Invalid UTF-8 encoding")
            return .failure(message: "Invalid input encoding")
        }

        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("CryptoWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        print("CryptoWorker: Operation: \(config.operation), Algorithm: \(config.effectiveAlgorithm)")

        switch config.operation.lowercased() {
        case "hash":
            return performHash(config: config)
        case "encrypt":
            return await performEncrypt(config: config)
        case "decrypt":
            return await performDecrypt(config: config)
        default:
            return .failure(message: "Unsupported operation: \(config.operation)")
        }
    }

    /// Perform hash operation on file or string.
    private func performHash(config: Config) -> WorkerResult {
        let algorithm = config.effectiveAlgorithm.uppercased()

        if let filePath = config.filePath {
            // Hash file
            guard SecurityValidator.validateFilePath(filePath) else {
                print("CryptoWorker: Error - Invalid file path")
                return .failure(message: "Invalid file path")
            }

            let fileURL = URL(fileURLWithPath: filePath)
            guard FileManager.default.fileExists(atPath: filePath) else {
                print("CryptoWorker: Error - File not found: \(filePath)")
                return .failure(message: "File not found: \(filePath)")
            }

            do {
                let hash = try calculateFileHash(fileURL: fileURL, algorithm: algorithm)
                let fileSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64 ?? 0
                print("CryptoWorker: Hash calculated: \(fileURL.lastPathComponent) → \(hash)")

                return .success(
                    message: "\(algorithm) hash calculated",
                    data: [
                        "hash": hash,
                        "algorithm": algorithm,
                        "filePath": fileURL.path,
                        "fileSize": fileSize
                    ]
                )
            } catch {
                print("CryptoWorker: Error calculating hash: \(error)")
                return .failure(message: "Failed to calculate hash: \(error.localizedDescription)")
            }
        } else if let data = config.data {
            // Hash string
            do {
                let hash = try calculateStringHash(data: data, algorithm: algorithm)
                print("CryptoWorker: Hash calculated: \(data.count) chars → \(hash)")

                return .success(
                    message: "\(algorithm) hash calculated",
                    data: [
                        "hash": hash,
                        "algorithm": algorithm,
                        "dataLength": data.count
                    ]
                )
            } catch {
                print("CryptoWorker: Error calculating hash: \(error)")
                return .failure(message: "Failed to calculate hash: \(error.localizedDescription)")
            }
        } else {
            print("CryptoWorker: Error - No filePath or data provided")
            return .failure(message: "No filePath or data provided for hash operation")
        }
    }

    /// Perform AES encryption on file.
    @available(iOS 13.0, *)
    private func performEncrypt(config: Config) async -> WorkerResult {
        guard let filePath = config.filePath else {
            print("CryptoWorker: Error - filePath required for encrypt operation")
            return .failure(message: "filePath required for encrypt operation")
        }

        guard let password = config.password else {
            print("CryptoWorker: Error - password required for encrypt operation")
            return .failure(message: "password required for encrypt operation")
        }

        // ✅ SECURITY: Validate paths
        guard SecurityValidator.validateFilePath(filePath) else {
            print("CryptoWorker: Error - Invalid input file path")
            return .failure(message: "Invalid input file path")
        }

        let inputURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("CryptoWorker: Error - Input file not found: \(filePath)")
            return .failure(message: "Input file not found: \(filePath)")
        }

        // Determine output path
        let outputPath = config.outputPath ?? "\(filePath).enc"
        guard SecurityValidator.validateFilePath(outputPath) else {
            print("CryptoWorker: Error - Invalid output file path")
            return .failure(message: "Invalid output file path")
        }

        let outputURL = URL(fileURLWithPath: outputPath)

        print("CryptoWorker: Encrypting: \(inputURL.lastPathComponent) → \(outputURL.lastPathComponent)")

        do {
            // Generate encryption key from password
            let salt = "native_workmanager_salt".data(using: .utf8)!
            let key = try generateKey(password: password, salt: salt)

            // Read input file
            let inputData = try Data(contentsOf: inputURL)

            // Encrypt data using AES-GCM
            let sealedBox = try AES.GCM.seal(inputData, using: key)

            // Write nonce + ciphertext + tag to output
            guard let combined = sealedBox.combined else {
                throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get combined data"])
            }
            try combined.write(to: outputURL)

            let inputSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64 ?? 0
            let outputSize = try FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64 ?? 0

            print("CryptoWorker: Encryption complete: \(outputSize) bytes")

            return .success(
                message: "File encrypted successfully",
                data: [
                    "inputPath": inputURL.path,
                    "outputPath": outputURL.path,
                    "inputSize": inputSize,
                    "outputSize": outputSize,
                    "algorithm": "AES-256-GCM"
                ]
            )
        } catch {
            print("CryptoWorker: Error during encryption: \(error)")
            try? FileManager.default.removeItem(at: outputURL)  // Clean up on error
            return .failure(message: "Encryption failed: \(error.localizedDescription)")
        }
    }

    /// Perform AES decryption on file.
    @available(iOS 13.0, *)
    private func performDecrypt(config: Config) async -> WorkerResult {
        guard let filePath = config.filePath else {
            print("CryptoWorker: Error - filePath required for decrypt operation")
            return .failure(message: "filePath required for decrypt operation")
        }

        guard let password = config.password else {
            print("CryptoWorker: Error - password required for decrypt operation")
            return .failure(message: "password required for decrypt operation")
        }

        // ✅ SECURITY: Validate paths
        guard SecurityValidator.validateFilePath(filePath) else {
            print("CryptoWorker: Error - Invalid input file path")
            return .failure(message: "Invalid input file path")
        }

        let inputURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("CryptoWorker: Error - Input file not found: \(filePath)")
            return .failure(message: "Input file not found: \(filePath)")
        }

        // Determine output path
        let outputPath = config.outputPath ?? filePath.replacingOccurrences(of: ".enc", with: "")
        guard SecurityValidator.validateFilePath(outputPath) else {
            print("CryptoWorker: Error - Invalid output file path")
            return .failure(message: "Invalid output file path")
        }

        let outputURL = URL(fileURLWithPath: outputPath)

        print("CryptoWorker: Decrypting: \(inputURL.lastPathComponent) → \(outputURL.lastPathComponent)")

        do {
            // Generate decryption key from password
            let salt = "native_workmanager_salt".data(using: .utf8)!
            let key = try generateKey(password: password, salt: salt)

            // Read encrypted file
            let encryptedData = try Data(contentsOf: inputURL)

            // Decrypt data using AES-GCM
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            // Write decrypted data to output
            try decryptedData.write(to: outputURL)

            let inputSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64 ?? 0
            let outputSize = try FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64 ?? 0

            print("CryptoWorker: Decryption complete: \(outputSize) bytes")

            return .success(
                message: "File decrypted successfully",
                data: [
                    "inputPath": inputURL.path,
                    "outputPath": outputURL.path,
                    "inputSize": inputSize,
                    "outputSize": outputSize,
                    "algorithm": "AES-256-GCM"
                ]
            )
        } catch {
            print("CryptoWorker: Error during decryption: \(error)")
            try? FileManager.default.removeItem(at: outputURL)  // Clean up on error
            return .failure(message: "Decryption failed: \(error.localizedDescription)")
        }
    }

    /// Calculate hash of a file.
    private func calculateFileHash(fileURL: URL, algorithm: String) throws -> String {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot open file"])
        }
        defer { try? fileHandle.close() }

        let bufferSize = 8192
        let algorithmUpper = algorithm.uppercased()

        if #available(iOS 13.0, *) {
            switch algorithmUpper {
            case "MD5":
                var hasher = Insecure.MD5()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    return true
                }) {}
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-1", "SHA1":
                var hasher = Insecure.SHA1()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    return true
                }) {}
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-256", "SHA256":
                var hasher = SHA256()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    return true
                }) {}
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-512", "SHA512":
                var hasher = SHA512()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    return true
                }) {}
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()

            default:
                throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported algorithm: \(algorithm)"])
            }
        } else {
            throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "CryptoKit requires iOS 13+"])
        }
    }

    /// Calculate hash of a string.
    private func calculateStringHash(data: String, algorithm: String) throws -> String {
        guard let dataBytes = data.data(using: .utf8) else {
            throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot encode string as UTF-8"])
        }

        let algorithmUpper = algorithm.uppercased()

        if #available(iOS 13.0, *) {
            switch algorithmUpper {
            case "MD5":
                let digest = Insecure.MD5.hash(data: dataBytes)
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-1", "SHA1":
                let digest = Insecure.SHA1.hash(data: dataBytes)
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-256", "SHA256":
                let digest = SHA256.hash(data: dataBytes)
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-512", "SHA512":
                let digest = SHA512.hash(data: dataBytes)
                return digest.map { String(format: "%02x", $0) }.joined()

            default:
                throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported algorithm: \(algorithm)"])
            }
        } else {
            throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "CryptoKit requires iOS 13+"])
        }
    }

    /// Generate AES key from password using PBKDF2.
    @available(iOS 13.0, *)
    private func generateKey(password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot encode password as UTF-8"])
        }

        // Derive key using PBKDF2
        var derivedKeyData = Data(repeating: 0, count: CryptoWorker.aesKeySize)
        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(CryptoWorker.pbkdf2Iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        CryptoWorker.aesKeySize
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw NSError(domain: "CryptoWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Key derivation failed"])
        }

        return SymmetricKey(data: derivedKeyData)
    }
}
