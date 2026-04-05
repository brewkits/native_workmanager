package dev.brewkits.native_workmanager

import android.content.Context
import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorkerFactory
import dev.brewkits.native_workmanager.workers.CryptoWorker
import dev.brewkits.native_workmanager.workers.DartCallbackWorkerWrapper
import dev.brewkits.native_workmanager.workers.FileCompressionWorker
import dev.brewkits.native_workmanager.workers.FileDecompressionWorker
import dev.brewkits.native_workmanager.workers.FileSystemWorker
import dev.brewkits.native_workmanager.workers.HttpDownloadWorker
import dev.brewkits.native_workmanager.workers.HttpRequestWorker
import dev.brewkits.native_workmanager.workers.ParallelHttpDownloadWorker
import dev.brewkits.native_workmanager.workers.ParallelHttpUploadWorker
import dev.brewkits.native_workmanager.workers.HttpSyncWorker
import dev.brewkits.native_workmanager.workers.HttpUploadWorker
import dev.brewkits.native_workmanager.workers.ImageProcessWorker
import dev.brewkits.native_workmanager.workers.DbCleanupWorker
import dev.brewkits.native_workmanager.workers.MoveToSharedStorageWorker
import dev.brewkits.native_workmanager.workers.PdfWorker
import dev.brewkits.native_workmanager.workers.WebSocketWorker

/**
 * AndroidWorkerFactory implementation for native_workmanager plugin.
 *
 * Creates all native workers:
 * - DartCallbackWorker: Executes Dart code in background (requires Flutter Engine)
 * - HttpRequestWorker: GET/POST/PUT/DELETE/PATCH with security validation
 * - HttpUploadWorker: Multipart file upload with security validation
 * - HttpDownloadWorker: Streaming file download with security validation
 * - HttpSyncWorker: JSON sync operations with security validation
 * - FileCompressionWorker: ZIP compression for files/directories (v1.0.0+)
 * - FileDecompressionWorker: ZIP extraction with security protection (v1.0.0+)
 * - ImageProcessWorker: Native image resize/compress/convert (v1.0.0+)
 * - CryptoWorker: File hashing and AES encryption (v1.0.0+)
 * - FileSystemWorker: File operations (copy/move/delete/list/mkdir) for pure-native chains (v1.0.0+)
 *
 * Supports two extension mechanisms (Open/Closed Principle):
 *  1. **Per-worker registry** (preferred): [registerWorker] — mirrors iOS [IosWorkerFactory.registerWorker].
 *  2. **Factory chain** (backward-compat): [setUserFactory] — single catch-all factory.
 *
 * Worker lookup order: per-worker registry → factory chain → built-in workers.
 */
class SimpleAndroidWorkerFactory(
    private val context: Context
) : AndroidWorkerFactory {

    companion object {
        private const val TAG = "SimpleAndroidWorkerFactory"

        /**
         * Per-worker registry: className → factory closure.
         *
         * Thread-safe via [ConcurrentHashMap]. Mirrors iOS [IosWorkerFactory]'s design,
         * enabling the Open/Closed Principle: add workers without modifying this class.
         *
         * ```kotlin
         * // In MainActivity.kt, before NativeWorkManager.initialize():
         * SimpleAndroidWorkerFactory.registerWorker("ImageCompressWorker") {
         *     ImageCompressWorker()
         * }
         * SimpleAndroidWorkerFactory.registerWorker("EncryptionWorker") {
         *     EncryptionWorker()
         * }
         * ```
         */
        private val workerRegistry =
            java.util.concurrent.ConcurrentHashMap<String, () -> AndroidWorker>()

        /**
         * Register a custom worker by class name.
         *
         * The factory closure is called each time a new instance is needed.
         * Safe to call before [NativeWorkManager.initialize].
         *
         * @param className Worker class name (must match Dart's `NativeWorker.custom(className:)`).
         * @param factory   Closure that creates a fresh worker instance.
         */
        fun registerWorker(className: String, factory: () -> AndroidWorker) {
            workerRegistry[className] = factory
            Log.d(TAG, "Registered custom worker '$className'")
        }

        /**
         * Unregister a previously registered worker.
         */
        fun unregisterWorker(className: String) {
            workerRegistry.remove(className)
            Log.d(TAG, "Unregistered custom worker '$className'")
        }

        /**
         * User-provided catch-all factory (legacy / backward-compat alternative to [registerWorker]).
         * Set this in MainActivity before calling NativeWorkManager.initialize().
         */
        @Volatile
        private var userFactory: AndroidWorkerFactory? = null

        /**
         * Register a catch-all custom worker factory.
         *
         * Prefer [registerWorker] for individual workers. Use this only when you need
         * to handle an open-ended set of worker class names dynamically at runtime.
         *
         * ```kotlin
         * SimpleAndroidWorkerFactory.setUserFactory(object : AndroidWorkerFactory {
         *     override fun createWorker(workerClassName: String): AndroidWorker? {
         *         return when (workerClassName) {
         *             "ImageCompressWorker" -> ImageCompressWorker()
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
        // 1. Per-worker registry (Open/Closed — preferred API)
        workerRegistry[workerClassName]?.let { return it() }

        // 2. Catch-all factory chain (backward-compat)
        userFactory?.createWorker(workerClassName)?.let { return it }

        // 3. Built-in workers
        return when (workerClassName) {
            "DartCallbackWorker" -> DartCallbackWorkerWrapper(context)
            "HttpRequestWorker" -> HttpRequestWorker()
            "HttpUploadWorker" -> HttpUploadWorker()
            "HttpDownloadWorker" -> HttpDownloadWorker()
            "ParallelHttpDownloadWorker" -> ParallelHttpDownloadWorker()
            "ParallelHttpUploadWorker" -> ParallelHttpUploadWorker()
            "HttpSyncWorker" -> HttpSyncWorker()
            "FileCompressionWorker" -> FileCompressionWorker()
            "FileDecompressionWorker" -> FileDecompressionWorker()
            "ImageProcessWorker" -> ImageProcessWorker()
            "CryptoWorker" -> CryptoWorker()
            "FileSystemWorker" -> FileSystemWorker()
            "MoveToSharedStorageWorker" -> MoveToSharedStorageWorker(context)
            "PdfWorker" -> PdfWorker()
            "WebSocketWorker" -> WebSocketWorker()
            DbCleanupWorker.TASK_ID, "DbCleanupWorker" -> DbCleanupWorker()
            else -> {
                Log.e(TAG, "Unknown worker class: '$workerClassName'. " +
                    "Register it via SimpleAndroidWorkerFactory.registerWorker() in MainActivity.")
                null
            }
        }
    }
}
