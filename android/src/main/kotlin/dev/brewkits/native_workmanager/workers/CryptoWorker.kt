package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.security.MessageDigest
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
 * - AES-256-CBC encryption with random IV
 * - IV is prepended to encrypted data for decryption
 *
 * **Performance:** ~2-5MB RAM, streaming for large files
 */
class CryptoWorker : AndroidWorker {

    companion object {
        private const val TAG = "CryptoWorker"
        private const val DEFAULT_ALGORITHM = "SHA-256"
        private const val AES_KEY_SIZE = 256
        private const val PBKDF2_ITERATIONS = 100_000
        private const val IV_SIZE = 16  // AES block size
    }

    data class Config(
        val operation: String,            // "hash", "encrypt", "decrypt"
        val filePath: String? = null,     // File to operate on
        val data: String? = null,         // String data (for hash)
        val outputPath: String? = null,   // Output file (for encrypt/decrypt)
        val algorithm: String? = null,    // Algorithm (MD5, SHA-256, AES, etc.)
        val password: String? = null      // Password (for encrypt/decrypt)
    ) {
        val effectiveAlgorithm: String get() = algorithm ?: DEFAULT_ALGORITHM
    }

    override suspend fun doWork(input: String?): WorkerResult = withContext(Dispatchers.IO) {
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
                password = if (j.has("password") && !j.isNull("password")) j.getString("password") else null
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        Log.d(TAG, "Operation: ${config.operation}, Algorithm: ${config.effectiveAlgorithm}")

        return@withContext when (config.operation.lowercase()) {
            "hash" -> performHash(config)
            "encrypt" -> performEncrypt(config)
            "decrypt" -> performDecrypt(config)
            else -> WorkerResult.Failure("Unsupported operation: ${config.operation}")
        }
    }

    /**
     * Perform hash operation on file or string.
     */
    private fun performHash(config: Config): WorkerResult {
        val algorithm = config.effectiveAlgorithm.uppercase()

        return when {
            config.filePath != null -> {
                // Hash file
                if (config.filePath.contains("..") || !config.filePath.startsWith("/")) {
                    Log.e(TAG, "Error - Invalid file path")
                    return WorkerResult.Failure("Invalid file path (path traversal attempt)")
                }

                val file = File(config.filePath)
                if (!file.exists()) {
                    Log.e(TAG, "Error - File not found: ${config.filePath}")
                    return WorkerResult.Failure("File not found: ${config.filePath}")
                }

                try {
                    val hash = calculateFileHash(file, algorithm)
                    Log.d(TAG, "Hash calculated: ${file.name} → $hash")

                    WorkerResult.Success(
                        message = "$algorithm hash calculated",
                        data = mapOf(
                            "hash" to hash,
                            "algorithm" to algorithm,
                            "filePath" to file.absolutePath,
                            "fileSize" to file.length()
                        )
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error calculating hash: ${e.message}", e)
                    WorkerResult.Failure("Failed to calculate hash: ${e.message}")
                }
            }
            config.data != null -> {
                // Hash string
                try {
                    val hash = calculateStringHash(config.data, algorithm)
                    Log.d(TAG, "Hash calculated: ${config.data.length} chars → $hash")

                    WorkerResult.Success(
                        message = "$algorithm hash calculated",
                        data = mapOf(
                            "hash" to hash,
                            "algorithm" to algorithm,
                            "dataLength" to config.data.length
                        )
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

        // ✅ SECURITY: Validate paths
        if (config.filePath.contains("..") || !config.filePath.startsWith("/")) {
            Log.e(TAG, "Error - Invalid input file path")
            return WorkerResult.Failure("Invalid input file path (path traversal attempt)")
        }

        val inputFile = File(config.filePath)
        if (!inputFile.exists()) {
            Log.e(TAG, "Error - Input file not found: ${config.filePath}")
            return WorkerResult.Failure("Input file not found: ${config.filePath}")
        }

        // Determine output path
        val outputPath = config.outputPath ?: "${config.filePath}.enc"
        if (outputPath.contains("..") || !outputPath.startsWith("/")) {
            Log.e(TAG, "Error - Invalid output file path")
            return WorkerResult.Failure("Invalid output file path (path traversal attempt)")
        }

        val outputFile = File(outputPath)

        Log.d(TAG, "Encrypting: ${inputFile.name} → ${outputFile.name}")

        return try {
            // Generate encryption key from password
            val salt = "native_workmanager_salt".toByteArray()  // In production, use random salt
            val key = generateKey(config.password, salt)

            // Encrypt file
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val iv = cipher.iv

            inputFile.inputStream().use { input ->
                outputFile.outputStream().use { output ->
                    // Write IV to output (needed for decryption)
                    output.write(iv)

                    // Encrypt and write data
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

            Log.d(TAG, "Encryption complete: ${outputFile.length()} bytes")

            WorkerResult.Success(
                message = "File encrypted successfully",
                data = mapOf(
                    "inputPath" to inputFile.absolutePath,
                    "outputPath" to outputFile.absolutePath,
                    "inputSize" to inputFile.length(),
                    "outputSize" to outputFile.length(),
                    "algorithm" to "AES-256-CBC"
                )
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

        // ✅ SECURITY: Validate paths
        if (config.filePath.contains("..") || !config.filePath.startsWith("/")) {
            Log.e(TAG, "Error - Invalid input file path")
            return WorkerResult.Failure("Invalid input file path (path traversal attempt)")
        }

        val inputFile = File(config.filePath)
        if (!inputFile.exists()) {
            Log.e(TAG, "Error - Input file not found: ${config.filePath}")
            return WorkerResult.Failure("Input file not found: ${config.filePath}")
        }

        // Determine output path
        val outputPath = config.outputPath ?: config.filePath.removeSuffix(".enc")
        if (outputPath.contains("..") || !outputPath.startsWith("/")) {
            Log.e(TAG, "Error - Invalid output file path")
            return WorkerResult.Failure("Invalid output file path (path traversal attempt)")
        }

        val outputFile = File(outputPath)

        Log.d(TAG, "Decrypting: ${inputFile.name} → ${outputFile.name}")

        return try {
            // Generate decryption key from password
            val salt = "native_workmanager_salt".toByteArray()  // Must match encryption salt
            val key = generateKey(config.password, salt)

            inputFile.inputStream().use { input ->
                // Read IV from input
                val iv = ByteArray(IV_SIZE)
                val ivBytesRead = input.read(iv)
                if (ivBytesRead != IV_SIZE) {
                    throw IllegalArgumentException("Invalid encrypted file (missing or incomplete IV)")
                }

                // Decrypt file
                val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
                cipher.init(Cipher.DECRYPT_MODE, key, IvParameterSpec(iv))

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
                data = mapOf(
                    "inputPath" to inputFile.absolutePath,
                    "outputPath" to outputFile.absolutePath,
                    "inputSize" to inputFile.length(),
                    "outputSize" to outputFile.length(),
                    "algorithm" to "AES-256-CBC"
                )
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
        val tmp = factory.generateSecret(spec)
        return SecretKeySpec(tmp.encoded, "AES")
    }
}
