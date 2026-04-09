package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.KeystorePasswordVault
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.io.File
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Native cryptographic operations worker for Android.
 *
 * Supports file/string hashing and AES encryption/decryption without requiring Flutter Engine.
 * Uses Android's built-in cryptography APIs for secure operations.
 *
 * **Configuration JSON (Hash File):**
 * ```json
 * {
 *   "operation": "hash",
 *   "filePath": "/path/to/file.bin",
 *   "algorithm": "SHA-256"  // Optional: MD5, SHA-1, SHA-256, SHA-512 (default: SHA-256)
 * }
 * ```
 *
 * **Configuration JSON (Hash String):**
 * ```json
 * {
 *   "operation": "hash",
 *   "data": "Hello World",
 *   "algorithm": "SHA-256"
 * }
 * ```
 *
 * **Configuration JSON (Encrypt File):**
 * ```json
 * {
 *   "operation": "encrypt",
 *   "filePath": "/path/to/input.txt",
 *   "outputPath": "/path/to/output.enc",  // Optional: defaults to inputPath + ".enc"
 *   "password": "secret123",
 *   "algorithm": "AES"  // Optional: Only AES supported currently
 * }
 * ```
 *
 * **Configuration JSON (Decrypt File):**
 * ```json
 * {
 *   "operation": "decrypt",
 *   "filePath": "/path/to/input.enc",
 *   "outputPath": "/path/to/output.txt",  // Optional: defaults to inputPath without ".enc"
 *   "password": "secret123",
 *   "algorithm": "AES"
 * }
 * ```
 *
 * **Security:**
 * - Uses PBKDF2 for password-based key derivation (100,000 iterations)
 * - AES-256-GCM authenticated encryption (confidentiality + integrity)
 * - Random 16-byte salt + 12-byte nonce prepended to each encrypted file
 *
 * **Performance:** ~2-5MB RAM, streaming for large files
 */
class CryptoWorker : AndroidWorker {

    companion object {
        private const val TAG = "CryptoWorker"
        private const val DEFAULT_ALGORITHM = "SHA-256"
        private const val AES_KEY_SIZE = 256
        private const val PBKDF2_ITERATIONS = 100_000
        private const val GCM_IV_SIZE = 12  // GCM standard IV size
        private const val SALT_SIZE = 16 // Random salt size
    }

    data class Config(
        val operation: String,            // "hash", "encrypt", "decrypt"
        val filePath: String? = null,     // File to operate on
        val data: String? = null,         // String data (for hash)
        val outputPath: String? = null,   // Output file (for encrypt/decrypt)
        val algorithm: String? = null,    // Algorithm (MD5, SHA-256, AES, etc.)
        val password: String? = null,     // Password (for encrypt/decrypt)
        val passwordKey: String? = null   // SC-C-001: vault key (replaces password in WorkManager input)
    ) {
        val effectiveAlgorithm: String get() = algorithm ?: DEFAULT_ALGORITHM

        // L-1: Override to prevent password leaking into logs via data class toString().
        override fun toString() =
            "Config(operation=$operation, filePath=$filePath, algorithm=$algorithm, " +
            "password=${if (password != null) "[REDACTED]" else "null"})"
    }

    override suspend fun doWork(input: String?, env: dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            throw IllegalArgumentException("Input JSON is required")
        }

        // Parse configuration
        val config = try {
            val j = org.json.JSONObject(input)
            Config(
                operation = j.getString("operation"),
                filePath = if (j.has("filePath") && !j.isNull("filePath")) j.getString("filePath") else null,
                data = if (j.has("data") && !j.isNull("data")) j.getString("data") else null,
                outputPath = if (j.has("outputPath") && !j.isNull("outputPath")) j.getString("outputPath") else null,
                algorithm = if (j.has("algorithm") && !j.isNull("algorithm")) j.getString("algorithm") else null,
                password = if (j.has("password") && !j.isNull("password")) j.getString("password") else null,
                passwordKey = if (j.has("passwordKey") && !j.isNull("passwordKey")) j.getString("passwordKey") else null
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        // SC-C-001: resolve password from Keychain vault if passwordKey is present
        val effectiveConfig = if (!config.passwordKey.isNullOrEmpty()) {
            val resolvedPassword = KeystorePasswordVault.retrieveAndDelete(config.passwordKey)
                ?: return@withContext WorkerResult.Failure("Password vault key not found — retry not possible")
            config.copy(password = resolvedPassword, passwordKey = null)
        } else {
            config
        }

        Log.d(TAG, "Operation: ${effectiveConfig.operation}, Algorithm: ${effectiveConfig.effectiveAlgorithm}")

        return@withContext when (effectiveConfig.operation.lowercase()) {
            "hash" -> performHash(effectiveConfig)
            "encrypt" -> performEncrypt(effectiveConfig)
            "decrypt" -> performDecrypt(effectiveConfig)
            else -> WorkerResult.Failure("Unsupported operation: ${effectiveConfig.operation}")
        }
    }

    /**
     * Perform hash operation on file or string.
     */
    private fun performHash(config: Config): WorkerResult {
        val algorithm = config.effectiveAlgorithm.uppercase()

        // SC-M-005: whitelist to prevent injection of arbitrary JCA algorithm names
        val normalizedAlgorithm = when (algorithm) {
            "SHA256" -> "SHA-256"
            "SHA512" -> "SHA-512"
            "SHA1" -> "SHA-1"
            else -> algorithm
        }
        val allowedHashAlgorithms = setOf("MD5", "SHA-1", "SHA-256", "SHA-512")
        if (normalizedAlgorithm !in allowedHashAlgorithms) {
            Log.e(TAG, "Unsupported algorithm: $algorithm")
            return WorkerResult.Failure("Unsupported algorithm: $algorithm. Supported: MD5, SHA-1, SHA-256, SHA-512")
        }

        return when {
            config.filePath != null -> {
                // Hash file
                // FIX H1: canonical-path check (replaces weak contains(".."))
                if (!SecurityValidator.validateFilePathSafe(config.filePath)) {
                    Log.e(TAG, "Error - Invalid or unsafe file path")
                    return WorkerResult.Failure("Invalid or unsafe file path")
                }

                val file = File(config.filePath)
                if (!file.exists()) {
                    Log.e(TAG, "Error - File not found: ${config.filePath}")
                    return WorkerResult.Failure("File not found: ${config.filePath}")
                }

                try {
                    val hash = calculateFileHash(file, normalizedAlgorithm)
                    // SC-M-003: do not log hash value — it is sensitive data
                    Log.d(TAG, "Hash calculated: ${file.name} ($normalizedAlgorithm)")

                    WorkerResult.Success(
                        message = "$normalizedAlgorithm hash calculated",
                        data = buildJsonObject {
                            put("hash", hash)
                            put("algorithm", normalizedAlgorithm)
                            put("filePath", file.absolutePath)
                            put("fileSize", file.length())
                        }
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error calculating hash: ${e.message}", e)
                    WorkerResult.Failure("Failed to calculate hash: ${e.message}")
                }
            }
            config.data != null -> {
                // Hash string
                try {
                    val hash = calculateStringHash(config.data, normalizedAlgorithm)
                    // SC-M-003: do not log hash value — it is sensitive data
                    Log.d(TAG, "Hash calculated: ${config.data.length} chars ($normalizedAlgorithm)")

                    WorkerResult.Success(
                        message = "$normalizedAlgorithm hash calculated",
                        data = buildJsonObject {
                            put("hash", hash)
                            put("algorithm", normalizedAlgorithm)
                            put("dataLength", config.data.length)
                        }
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error calculating hash: ${e.message}", e)
                    WorkerResult.Failure("Failed to calculate hash: ${e.message}")
                }
            }
            else -> {
                Log.e(TAG, "Error - No filePath or data provided")
                WorkerResult.Failure("No filePath or data provided for hash operation")
            }
        }
    }

    /**
     * Perform AES encryption on file.
     */
    private fun performEncrypt(config: Config): WorkerResult {
        if (config.filePath == null) {
            Log.e(TAG, "Error - filePath required for encrypt operation")
            return WorkerResult.Failure("filePath required for encrypt operation")
        }

        if (config.password == null) {
            Log.e(TAG, "Error - password required for encrypt operation")
            return WorkerResult.Failure("password required for encrypt operation")
        }

        // FIX H1: canonical-path checks (replace weak contains(".."))
        if (!SecurityValidator.validateFilePathSafe(config.filePath)) {
            Log.e(TAG, "Error - Invalid or unsafe input file path")
            return WorkerResult.Failure("Invalid or unsafe input file path")
        }

        val inputFile = File(config.filePath)
        if (!inputFile.exists()) {
            Log.e(TAG, "Error - Input file not found: ${config.filePath}")
            return WorkerResult.Failure("Input file not found: ${config.filePath}")
        }

        // Determine output path
        val outputPath = config.outputPath ?: "${config.filePath}.enc"
        if (!SecurityValidator.validateFilePathSafe(outputPath)) {
            Log.e(TAG, "Error - Invalid or unsafe output file path")
            return WorkerResult.Failure("Invalid or unsafe output file path")
        }

        val outputFile = File(outputPath)

        // M-2: AES/GCM/NoPadding in JCE buffers the entire ciphertext in RAM during
        // doFinal() to compute the authentication tag — it is NOT truly streaming.
        // Applying maxFileSize here prevents OOM on large files.
        if (!SecurityValidator.validateFileSize(inputFile)) {
            Log.e(TAG, "Error - Input file too large for GCM encryption (not truly streaming)")
            return WorkerResult.Failure("Input file exceeds max size for encryption (${SecurityValidator.maxFileSize / 1024 / 1024}MB)")
        }

        Log.d(TAG, "Encrypting: ${inputFile.name} → ${outputFile.name}")

        return try {
            // Generate random salt (unique per encryption)
            val salt = ByteArray(SALT_SIZE).also { SecureRandom().nextBytes(it) }
            val key = generateKey(config.password, salt)

            // ✅ SECURITY: Upgrade to AES-GCM (Authenticated Encryption)
            // GCM provides both confidentiality and integrity (prevents tampering)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val iv = ByteArray(12).also { SecureRandom().nextBytes(it) } // GCM standard IV size
            val spec = javax.crypto.spec.GCMParameterSpec(128, iv)
            cipher.init(Cipher.ENCRYPT_MODE, key, spec)

            inputFile.inputStream().use { input ->
                outputFile.outputStream().use { output ->
                    // Write Header: SALT (16) + IV (12)
                    output.write(salt)
                    output.write(iv)

                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        val encryptedChunk = cipher.update(buffer, 0, bytesRead)
                        if (encryptedChunk != null) {
                            output.write(encryptedChunk)
                        }
                    }
                    val finalChunk = cipher.doFinal()
                    if (finalChunk != null) {
                        output.write(finalChunk)
                    }
                }
            }
            Log.d(TAG, "Encryption complete (AES-GCM): ${outputFile.length()} bytes")

            WorkerResult.Success(
                message = "File encrypted successfully",
                data = buildJsonObject {
                    put("inputPath", inputFile.absolutePath)
                    put("outputPath", outputFile.absolutePath)
                    put("inputSize", inputFile.length())
                    put("outputSize", outputFile.length())
                    put("algorithm", "AES-256-GCM")
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error during encryption: ${e.message}", e)
            outputFile.delete()  // Clean up on error
            WorkerResult.Failure("Encryption failed: ${e.message}")
        }
    }

    /**
     * Perform AES decryption on file.
     */
    private fun performDecrypt(config: Config): WorkerResult {
        if (config.filePath == null) {
            Log.e(TAG, "Error - filePath required for decrypt operation")
            return WorkerResult.Failure("filePath required for decrypt operation")
        }

        if (config.password == null) {
            Log.e(TAG, "Error - password required for decrypt operation")
            return WorkerResult.Failure("password required for decrypt operation")
        }

        // FIX H1: canonical-path checks (replace weak contains(".."))
        if (!SecurityValidator.validateFilePathSafe(config.filePath)) {
            Log.e(TAG, "Error - Invalid or unsafe input file path")
            return WorkerResult.Failure("Invalid or unsafe input file path")
        }

        val inputFile = File(config.filePath)
        if (!inputFile.exists()) {
            Log.e(TAG, "Error - Input file not found: ${config.filePath}")
            return WorkerResult.Failure("Input file not found: ${config.filePath}")
        }

        // Determine output path
        val outputPath = config.outputPath ?: config.filePath.removeSuffix(".enc")
        if (!SecurityValidator.validateFilePathSafe(outputPath)) {
            Log.e(TAG, "Error - Invalid or unsafe output file path")
            return WorkerResult.Failure("Invalid or unsafe output file path")
        }

        val outputFile = File(outputPath)

        // SC-H-001: validate file size before loading into RAM (AES-GCM buffers entire
        // ciphertext to verify the authentication tag before releasing plaintext)
        if (!SecurityValidator.validateFileSize(inputFile)) {
            Log.e(TAG, "Error - Encrypted file too large for GCM decryption (not truly streaming)")
            return WorkerResult.Failure("Encrypted file exceeds max size for decryption (${SecurityValidator.maxFileSize / 1024 / 1024}MB)")
        }

        // SC-M-001: reject files too small to be valid AES-GCM output
        val minDecryptSize = SALT_SIZE + GCM_IV_SIZE + 16  // salt(16) + IV(12) + GCM tag(16)
        if (inputFile.length() < minDecryptSize) {
            Log.e(TAG, "Error - Encrypted file too small (${inputFile.length()} bytes, min $minDecryptSize)")
            return WorkerResult.Failure("Invalid encrypted file: too small to be valid (min $minDecryptSize bytes)")
        }

        Log.d(TAG, "Decrypting: ${inputFile.name} → ${outputFile.name}")

        return try {
            inputFile.inputStream().use { input ->
                // Read salt (first SALT_SIZE bytes), then IV
                val salt = ByteArray(SALT_SIZE)
                if (input.read(salt) != SALT_SIZE) {
                    throw IllegalArgumentException("Invalid encrypted file (missing or incomplete salt)")
                }
                val iv = ByteArray(GCM_IV_SIZE)
                if (input.read(iv) != GCM_IV_SIZE) {
                    throw IllegalArgumentException("Invalid encrypted file (missing or incomplete IV)")
                }

                val key = generateKey(config.password, salt)

                // ✅ SECURITY: Upgrade to AES-GCM (Authenticated Encryption)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                val spec = javax.crypto.spec.GCMParameterSpec(128, iv)
                cipher.init(Cipher.DECRYPT_MODE, key, spec)

                outputFile.outputStream().use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        val decryptedChunk = cipher.update(buffer, 0, bytesRead)
                        if (decryptedChunk != null) {
                            output.write(decryptedChunk)
                        }
                    }
                    val finalChunk = cipher.doFinal()
                    if (finalChunk != null) {
                        output.write(finalChunk)
                    }
                }
            }

            Log.d(TAG, "Decryption complete: ${outputFile.length()} bytes")

            WorkerResult.Success(
                message = "File decrypted successfully",
                data = buildJsonObject {
                    put("inputPath", inputFile.absolutePath)
                    put("outputPath", outputFile.absolutePath)
                    put("inputSize", inputFile.length())
                    put("outputSize", outputFile.length())
                    put("algorithm", "AES-256-GCM")
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error during decryption: ${e.message}", e)
            outputFile.delete()  // Clean up on error
            WorkerResult.Failure("Decryption failed: ${e.message}")
        }
    }

    /**
     * Calculate hash of a file.
     */
    private fun calculateFileHash(file: File, algorithm: String): String {
        val digest = MessageDigest.getInstance(algorithm)
        val buffer = ByteArray(8192)

        file.inputStream().use { input ->
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                digest.update(buffer, 0, bytesRead)
            }
        }

        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    /**
     * Calculate hash of a string.
     */
    private fun calculateStringHash(data: String, algorithm: String): String {
        val digest = MessageDigest.getInstance(algorithm)
        val bytes = data.toByteArray(Charsets.UTF_8)
        return digest.digest(bytes).joinToString("") { "%02x".format(it) }
    }

    /**
     * Generate AES key from password using PBKDF2.
     */
    private fun generateKey(password: String, salt: ByteArray): SecretKeySpec {
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val spec = PBEKeySpec(password.toCharArray(), salt, PBKDF2_ITERATIONS, AES_KEY_SIZE)
        return try {
            val tmp = factory.generateSecret(spec)
            SecretKeySpec(tmp.encoded, "AES")
        } finally {
            spec.clearPassword()   // SC-H-002: zero password char[] on heap
        }
    }
}
