package dev.brewkits.native_workmanager.workers

import android.content.Context
import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.engine.FlutterEngineManager
import org.json.JSONObject

/**
 * Android worker that executes Dart callbacks in background.
 *
 * This worker:
 * 1. Receives a callback handle (from PluginUtilities.getCallbackHandle)
 * 2. Starts/reuses Flutter Engine
 * 3. Invokes the Dart callback via MethodChannel
 * 4. Returns the callback result
 *
 * Performance characteristics:
 * - Cold start (first task): 500-1000ms
 * - Warm start (engine cached): 100-200ms
 * - RAM usage: ~30-50MB while engine is alive
 *
 * Input JSON format:
 * ```json
 * {
 *   "callbackId": "myCallback",        // For logging/debugging
 *   "callbackHandle": 12345678,        // ✅ Serializable handle (REQUIRED)
 *   "input": "{\"key\": \"value\"}",   // Optional JSON string input
 *   "autoDispose": true                // Optional: Kill engine immediately after completion (default: false)
 * }
 * ```
 *
 * @see FlutterEngineManager
 */
class DartCallbackWorkerWrapper(
    private val context: Context
) : AndroidWorker {

    companion object {
        private const val TAG = "DartCallbackWorker"
    }

    /**
     * Execute the Dart callback.
     *
     * This method is called by WorkManager in a background thread.
     * It's blocking but that's OK since WorkManager handles threading.
     *
     * @param input JSON string containing callback handle and optional input data
     * @return WorkerResult indicating success/failure (data from Dart callback)
     */
    override suspend fun doWork(input: String?): WorkerResult {
        return try {
            Log.d(TAG, "DartCallbackWorker started")

            if (input == null || input.isEmpty()) {
                Log.e(TAG, "Input is null or empty")
                return WorkerResult.Failure("Input is null or empty")
            }

            // Parse input JSON
            val json = try {
                JSONObject(input)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse input JSON: $input", e)
                return WorkerResult.Failure("Failed to parse input JSON: ${e.message}")
            }

            // Extract callback handle (REQUIRED)
            val callbackHandle = try {
                json.getLong("callbackHandle")
            } catch (e: Exception) {
                Log.e(TAG, "Missing or invalid callbackHandle in input: $input", e)
                Log.e(TAG, "Input JSON keys: ${json.keys().asSequence().toList()}")
                return WorkerResult.Failure("Missing or invalid callbackHandle")
            }

            // Extract callbackId (for logging only)
            val callbackId = json.optString("callbackId", "unknown")

            // Extract optional input data
            val callbackInput = json.optString("input", null)

            // ✅ NEW: Extract autoDispose flag (default: false)
            val autoDispose = json.optBoolean("autoDispose", false)

            Log.d(TAG, "Executing callback: $callbackId (handle: $callbackHandle, autoDispose: $autoDispose)")

            // Execute Dart callback via FlutterEngineManager
            // ✅ Pass callbackHandle (not callbackId) to enable cross-isolate execution
            val result = FlutterEngineManager.executeDartCallback(
                context = context,
                callbackHandle = callbackHandle,  // ✅ Serializable handle
                input = callbackInput,
                timeoutMs = 5 * 60 * 1000L, // 5 minutes timeout
                disposeImmediately = autoDispose // ✅ NEW: Aggressive disposal flag
            )

            Log.d(TAG, "Dart callback completed: $callbackId, result: $result")

            if (result) {
                WorkerResult.Success(message = "Dart callback executed: $callbackId")
            } else {
                WorkerResult.Failure("Dart callback returned false: $callbackId")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error in DartCallbackWorker", e)
            WorkerResult.Failure(e.message ?: "Unknown error", shouldRetry = true)
        }
    }
}
