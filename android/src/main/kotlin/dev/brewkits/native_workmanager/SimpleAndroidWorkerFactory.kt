package dev.brewkits.native_workmanager

import android.content.Context
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorkerFactory
import dev.brewkits.native_workmanager.workers.CryptoWorker
import dev.brewkits.native_workmanager.workers.DartCallbackWorkerWrapper
import dev.brewkits.native_workmanager.workers.FileCompressionWorker
import dev.brewkits.native_workmanager.workers.FileDecompressionWorker
import dev.brewkits.native_workmanager.workers.FileSystemWorker
import dev.brewkits.native_workmanager.workers.HttpDownloadWorker
import dev.brewkits.native_workmanager.workers.HttpRequestWorker
import dev.brewkits.native_workmanager.workers.HttpSyncWorker
import dev.brewkits.native_workmanager.workers.HttpUploadWorker
import dev.brewkits.native_workmanager.workers.ImageProcessWorker

/**
 * AndroidWorkerFactory implementation for native_workmanager plugin.
 *
 * Creates all native workers:
 * - DartCallbackWorker: Executes Dart code in background (requires Flutter Engine)
 * - HttpRequestWorker: GET/POST/PUT/DELETE/PATCH with security validation
 * - HttpUploadWorker: Multipart file upload with security validation
 * - HttpDownloadWorker: Streaming file download with security validation
 * - HttpSyncWorker: JSON sync operations with security validation
 * - FileCompressionWorker: ZIP compression for files/directories (v0.9.0+)
 * - FileDecompressionWorker: ZIP extraction with security protection (v1.0.0+)
 * - ImageProcessWorker: Native image resize/compress/convert (v1.0.0+)
 * - CryptoWorker: File hashing and AES encryption (v1.0.0+)
 * - FileSystemWorker: File operations (copy/move/delete/list/mkdir) for pure-native chains (v1.0.0+)
 *
 * Supports custom worker registration via [setUserFactory].
 * User factory is checked first, then falls back to built-in workers.
 */
class SimpleAndroidWorkerFactory(
    private val context: Context
) : AndroidWorkerFactory {

    companion object {
        /**
         * User-provided factory for custom workers.
         * Set this in MainActivity before calling NativeWorkManager.initialize().
         */
        @Volatile
        private var userFactory: AndroidWorkerFactory? = null

        /**
         * Register a custom worker factory.
         *
         * Example usage in MainActivity.kt:
         * ```kotlin
         * SimpleAndroidWorkerFactory.setUserFactory(object : AndroidWorkerFactory {
         *     override fun createWorker(workerClassName: String): AndroidWorker? {
         *         return when (workerClassName) {
         *             "ImageCompressWorker" -> ImageCompressWorker()
         *             "EncryptionWorker" -> EncryptionWorker()
         *             else -> null
         *         }
         *     }
         * })
         * ```
         */
        fun setUserFactory(factory: AndroidWorkerFactory?) {
            userFactory = factory
        }
    }

    override fun createWorker(workerClassName: String): AndroidWorker? {
        // Try user factory first
        userFactory?.createWorker(workerClassName)?.let { return it }

        // Fallback to built-in workers
        return when (workerClassName) {
            "DartCallbackWorker" -> DartCallbackWorkerWrapper(context)
            "HttpRequestWorker" -> HttpRequestWorker()
            "HttpUploadWorker" -> HttpUploadWorker()
            "HttpDownloadWorker" -> HttpDownloadWorker()
            "HttpSyncWorker" -> HttpSyncWorker()
            "FileCompressionWorker" -> FileCompressionWorker()
            "FileDecompressionWorker" -> FileDecompressionWorker()
            "ImageProcessWorker" -> ImageProcessWorker()
            "CryptoWorker" -> CryptoWorker()
            "FileSystemWorker" -> FileSystemWorker()
            else -> null
        }
    }
}
