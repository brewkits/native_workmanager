package dev.brewkits.native_workmanager.engine

import android.content.Context
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
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
import java.util.concurrent.atomic.AtomicInteger

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

    // Coroutine scope for auto-disposal management
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

    // Reference counter (AtomicInteger) to prevent disposal while tasks are running.
    // Multiple coroutines on different threads can call executeDartCallback() concurrently;
    // plain var Int would race on ++ / -- (non-atomic read-modify-write).
    private val activeTaskCount = AtomicInteger(0)

    /**
     * Execute a Dart callback with input data.
     */
    suspend fun executeDartCallback(
        context: Context,
        callbackHandle: Long,
        input: String?,
        timeoutMs: Long = 5 * 60 * 1000L,
        disposeImmediately: Boolean = false
    ): Boolean = withContext(Dispatchers.Main) {
        try {
            Log.d(TAG, "Executing Dart callback with handle: $callbackHandle")

            ensureEngineInitialized(context)
            activeTaskCount.incrementAndGet()

            val channel = methodChannel
            if (channel == null) {
                activeTaskCount.decrementAndGet()
                return@withContext false
            }

            val resultDeferred = CompletableDeferred<Boolean>()
            val args = mapOf("callbackHandle" to callbackHandle, "input" to input)

            channel.invokeMethod("executeCallback", args, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    resultDeferred.complete((result as? Boolean) ?: false)
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    resultDeferred.complete(false)
                }
                override fun notImplemented() {
                    resultDeferred.complete(false)
                }
            })

            val result = try {
                withTimeout(timeoutMs) { resultDeferred.await() }
            } finally {
                activeTaskCount.decrementAndGet()
            }

            if (disposeImmediately && activeTaskCount.get() <= 0) {
                dispose()
            } else {
                lastUsedTimestamp = System.currentTimeMillis()
                scheduleDisposalCheck()
            }

            result
        } catch (e: Exception) {
            Log.e(TAG, "Error executing Dart callback", e)
            // Error occurred — likely a timeout or crash. Dispose immediately if no other tasks
            // are running to ensure a clean slate and free RAM from a potentially hung Isolate.
            if (activeTaskCount.get() <= 0) {
                try { dispose() } catch (_: Exception) {}
            }
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

            // Destroy the engine on any init failure so we don't leak
            // ~30-50MB of RAM per failed attempt (invalid callback handle, 10s timeout, etc.).
            try {
                // Get the correct app bundle path for the Flutter assets.
                // context.assets.toString() returns the AssetManager object string, which is wrong.
                // FlutterLoader provides the correct path for both debug (JIT) and release (AOT) modes.
                val bundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()

                val dartCallback = DartExecutor.DartCallback(
                    context.assets,
                    bundlePath,
                    callbackInfo
                )

                // Create MethodChannel and register 'dartReady' handler BEFORE starting the Dart isolate.
                // This eliminates the race condition where Dart sends 'dartReady' before the Kotlin
                // handler is registered, which would cause the message to be dropped and the
                // waitForDartReady() 10-second timeout to fire.
                val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
                val readyDeferred = CompletableDeferred<Unit>()
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "dartReady" -> {
                            Log.d(TAG, "Dart side ready")
                            readyDeferred.complete(Unit)
                            result.success(null)
                        }
                        // Progress reports emitted from inside a DartWorker callback.
                        // The Dart side calls MethodChannel('dev.brewkits/dart_worker_channel')
                        // .invokeMethod('reportProgress', {...}) which arrives here and is
                        // forwarded to the shared ProgressReporter → Flutter EventChannel.
                        "reportProgress" -> {
                            val taskId  = call.argument<String>("taskId") ?: ""
                            val progress = call.argument<Int>("progress") ?: 0
                            val message  = call.argument<String>("message")
                            ProgressReporter.reportProgressNonBlocking(taskId, progress, message)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }

                // Now start the Dart isolate — handler is already registered, no race possible.
                flutterEngine.dartExecutor.executeDartCallback(dartCallback)

                // Wait for Dart to signal it's ready (up to 10 seconds)
                withTimeout(10_000L) {
                    readyDeferred.await()
                }
                Log.d(TAG, "Dart ready signal received")

                // Store references only after successful initialization
                engine = flutterEngine
                methodChannel = channel
                lastUsedTimestamp = System.currentTimeMillis()
                isInitialized.set(true)

                Log.d(TAG, "Flutter engine initialized successfully")
            } catch (e: Exception) {
                // DART-007: Ensure engine is destroyed on any failure path to prevent memory leak.
                withContext(Dispatchers.Main) {
                    try { flutterEngine.destroy() } catch (_: Exception) {}
                }
                throw e
            }
        }
    }

    /**
     * Schedule engine disposal check.
     *
     * If engine hasn't been used for ENGINE_IDLE_TIMEOUT_MS,
     * it will be disposed to free memory.
     */
    private fun scheduleDisposalCheck() {
        // Auto-disposal with proper CoroutineScope
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
     * Acquires [initializationMutex] to prevent a concurrent
     * [ensureEngineInitialized] call from storing a reference to a destroyed
     * engine, or vice-versa (H-2 fix).
     *
     * This frees ~30-50MB of RAM but future tasks will be slower
     * (need to cold-start engine again).
     */
    suspend fun dispose() {
        initializationMutex.withLock {
            Log.d(TAG, "Disposing Flutter engine")

            methodChannel?.setMethodCallHandler(null)
            methodChannel = null

            try {
                withContext(Dispatchers.Main) {
                    engine?.destroy()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error destroying engine (expected if already detached)", e)
            }
            engine = null

            isInitialized.set(false)

            // Cancel disposal job to prevent unnecessary work
            disposalJob?.cancel()
            disposalJob = null

            Log.d(TAG, "Flutter engine disposed")
        }
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
