package dev.brewkits.native_workmanager.engine

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Manages FlutterEngine lifecycle for Dart worker execution.
 *
 * This manager implements a singleton pattern with:
 * - Engine caching (reuse between tasks for performance)
 * - Auto-disposal after inactivity
 * - Thread-safe initialization
 * - Timeout handling
 *
 * Performance characteristics:
 * - First task (cold start): 500-1000ms (engine initialization)
 * - Subsequent tasks (engine cached): 100-200ms
 * - RAM: ~30-50MB while engine is alive
 * - Auto-dispose: 5 minutes after last task
 *
 * @see DartCallbackWorker
 */
object FlutterEngineManager {

    private const val TAG = "FlutterEngineManager"
    private const val CHANNEL_NAME = "dev.brewkits/dart_worker_channel"
    private const val ENGINE_IDLE_TIMEOUT_MS = 5 * 60 * 1000L // 5 minutes

    private var engine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private var lastUsedTimestamp = 0L
    private val initializationMutex = Mutex()
    private val isInitialized = AtomicBoolean(false)

    // Callback handle stored during plugin initialization
    private var callbackHandle: Long? = null

    // ✅ NEW: Coroutine scope for auto-disposal management
    private val disposalScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var disposalJob: Job? = null

    /**
     * Set the Dart callback handle.
     *
     * This must be called during plugin initialization with the handle
     * of the top-level callback dispatcher function.
     */
    fun setCallbackHandle(handle: Long) {
        callbackHandle = handle
        Log.d(TAG, "Callback handle set: $handle")
    }

    /**
     * Execute a Dart callback with input data.
     *
     * This method:
     * 1. Initializes engine if needed (lazy)
     * 2. Invokes the Dart callback via MethodChannel
     * 3. Waits for result with timeout
     * 4. Returns success/failure
     * 5. Disposes engine immediately if requested (aggressive disposal)
     *
     * @param context Android context
     * @param callbackHandle Serializable handle of the callback function (from PluginUtilities.getCallbackHandle)
     * @param input JSON input data for the callback
     * @param timeoutMs Maximum time to wait for callback result (default: 5 minutes)
     * @param disposeImmediately If true, engine is killed immediately after callback completes (saves ~50MB RAM)
     * @return True if callback succeeded, false otherwise
     */
    suspend fun executeDartCallback(
        context: Context,
        callbackHandle: Long,
        input: String?,
        timeoutMs: Long = 5 * 60 * 1000L, // 5 minutes default
        disposeImmediately: Boolean = false // ✅ NEW: Aggressive disposal flag
    ): Boolean = withContext(Dispatchers.Main) {
        // FlutterEngine constructor and MethodChannel calls require the main thread.
        try {
            Log.d(TAG, "Executing Dart callback with handle: $callbackHandle")

            ensureEngineInitialized(context)

            val channel = methodChannel
            if (channel == null) {
                Log.e(TAG, "MethodChannel is null after initialization")
                return@withContext false
            }

            val resultDeferred = CompletableDeferred<Boolean>()

            val args = mapOf(
                "callbackHandle" to callbackHandle,
                "input" to input
            )

            channel.invokeMethod("executeCallback", args, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val success = (result as? Boolean) ?: false
                    Log.d(TAG, "Dart callback result: $success")
                    resultDeferred.complete(success)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "Dart callback error: $errorCode - $errorMessage")
                    resultDeferred.complete(false)
                }

                override fun notImplemented() {
                    Log.e(TAG, "Dart callback not implemented")
                    resultDeferred.complete(false)
                }
            })

            val result = withTimeout(timeoutMs) {
                resultDeferred.await()
            }

            // ✅ NEW: Aggressive disposal logic
            if (disposeImmediately) {
                Log.d(TAG, "🔥 Aggressive disposal: Killing engine immediately to free RAM")
                dispose()
            } else {
                // Original behavior: Keep engine alive for 5 minutes
                lastUsedTimestamp = System.currentTimeMillis()
                scheduleDisposalCheck()
            }

            result

        } catch (e: Exception) {
            Log.e(TAG, "Error executing Dart callback", e)
            false
        }
    }

    /**
     * Ensure Flutter engine is initialized.
     *
     * This uses double-checked locking for thread safety and performance.
     */
    private suspend fun ensureEngineInitialized(context: Context) {
        // Fast path: already initialized
        if (isInitialized.get()) {
            return
        }

        // Slow path: need to initialize
        initializationMutex.withLock {
            // Double-check after acquiring lock
            if (isInitialized.get()) {
                return
            }

            Log.d(TAG, "Initializing Flutter engine...")

            val handle = callbackHandle ?: run {
                throw IllegalStateException(
                    "Callback handle not set. " +
                    "Call FlutterEngineManager.setCallbackHandle() during plugin initialization."
                )
            }

            // Get callback information
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(handle)
            if (callbackInfo == null) {
                throw IllegalStateException("Failed to lookup callback information for handle: $handle")
            }

            Log.d(TAG, "Callback info: ${callbackInfo.callbackName}")

            // Create engine
            val flutterEngine = FlutterEngine(context.applicationContext)

            // Start executing Dart callback dispatcher
            // Note: Simplified for compatibility - will need proper initialization later
            val dartBundlePath = context.assets.toString()

            val dartCallback = DartExecutor.DartCallback(
                context.assets,
                dartBundlePath,
                callbackInfo
            )

            flutterEngine.dartExecutor.executeDartCallback(dartCallback)

            // Create MethodChannel
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

            // Wait for Dart side to signal ready
            waitForDartReady(channel)

            // Store references
            engine = flutterEngine
            methodChannel = channel
            lastUsedTimestamp = System.currentTimeMillis()
            isInitialized.set(true)

            Log.d(TAG, "Flutter engine initialized successfully")
        }
    }

    /**
     * Wait for Dart side to signal it's ready.
     *
     * The Dart callback dispatcher will invoke 'dartReady' method
     * to signal that it's initialized and ready to receive tasks.
     */
    private suspend fun waitForDartReady(channel: MethodChannel) {
        val readyDeferred = CompletableDeferred<Unit>()

        channel.setMethodCallHandler { call, result ->
            if (call.method == "dartReady") {
                Log.d(TAG, "Dart side ready")
                readyDeferred.complete(Unit)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Wait up to 10 seconds for Dart to be ready
        withTimeout(10_000L) {
            readyDeferred.await()
        }

        Log.d(TAG, "Dart ready signal received")
    }

    /**
     * Schedule engine disposal check.
     *
     * If engine hasn't been used for ENGINE_IDLE_TIMEOUT_MS,
     * it will be disposed to free memory.
     */
    private fun scheduleDisposalCheck() {
        // ✅ IMPLEMENTED: Auto-disposal with proper CoroutineScope
        // Uses SupervisorJob to prevent leaks and properly managed lifecycle

        // Cancel any existing disposal job
        disposalJob?.cancel()

        // Schedule new disposal check
        disposalJob = disposalScope.launch {
            delay(ENGINE_IDLE_TIMEOUT_MS)

            // Check if engine is still idle
            val idleTime = System.currentTimeMillis() - lastUsedTimestamp
            if (idleTime >= ENGINE_IDLE_TIMEOUT_MS) {
                Log.d(TAG, "Auto-disposing engine after ${idleTime}ms idle")
                disposalScope.launch { dispose() }
            }
        }
    }

    /**
     * Dispose the Flutter engine.
     *
     * This frees ~30-50MB of RAM but future tasks will be slower
     * (need to cold-start engine again).
     */
    suspend fun dispose() {
        Log.d(TAG, "Disposing Flutter engine")

        methodChannel?.setMethodCallHandler(null)
        methodChannel = null

        withContext(Dispatchers.Main) {
            engine?.destroy()
        }
        engine = null

        isInitialized.set(false)

        // ✅ NEW: Cancel disposal job to prevent unnecessary work
        disposalJob?.cancel()
        disposalJob = null

        Log.d(TAG, "Flutter engine disposed")
    }

    /**
     * Check if engine is currently initialized.
     */
    fun isEngineAlive(): Boolean = isInitialized.get()

    /**
     * Get time since engine was last used (for monitoring).
     */
    fun getIdleTimeMs(): Long {
        if (!isInitialized.get()) return -1
        return System.currentTimeMillis() - lastUsedTimestamp
    }
}
