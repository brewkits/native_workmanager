package dev.brewkits.native_workmanager_example

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.RandomAccessFile

import dev.brewkits.native_workmanager.SimpleAndroidWorkerFactory
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorkerFactory
import dev.brewkits.native_workmanager_example.workers.ImageCompressWorker // Import the custom worker

class MainActivity : FlutterActivity() {
    private val METRICS_CHANNEL = "dev.brewkits.native_workmanager.example/metrics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register custom workers BEFORE Flutter engine starts
        SimpleAndroidWorkerFactory.setUserFactory(object : AndroidWorkerFactory {
            override fun createWorker(workerClassName: String): AndroidWorker? {
                return when (workerClassName) {
                    "ImageCompressWorker" -> ImageCompressWorker()
                    // Add more custom workers here
                    else -> null
                }
            }
        })


        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METRICS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMemoryMB" -> {
                    try {
                        result.success(getMemoryMB())
                    } catch (e: Exception) {
                        result.error("MEMORY_ERROR", "Failed to get memory: ${e.message}", null)
                    }
                }
                "getMemoryMetrics" -> {
                    try {
                        result.success(getMemoryMetrics())
                    } catch (e: Exception) {
                        result.error("MEMORY_ERROR", "Failed to get memory metrics: ${e.message}", null)
                    }
                }
                "getCpuMetrics" -> {
                    try {
                        result.success(getCpuMetrics())
                    } catch (e: Exception) {
                        result.error("CPU_ERROR", "Failed to get CPU metrics: ${e.message}", null)
                    }
                }
                "getBatteryMetrics" -> {
                    try {
                        result.success(getBatteryMetrics())
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", "Failed to get battery metrics: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getMemoryMB(): Double {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val pid = android.os.Process.myPid()
        val processMemInfo = activityManager.getProcessMemoryInfo(intArrayOf(pid))
        val pssKB = processMemInfo[0].totalPss
        return pssKB / 1024.0 // Convert KB to MB
    }

    private fun getMemoryMetrics(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memInfo)

        // Get app memory usage (PSS - Proportional Set Size)
        val pid = android.os.Process.myPid()
        val processMemInfo = activityManager.getProcessMemoryInfo(intArrayOf(pid))
        val appRAM = processMemInfo[0].totalPss * 1024L // Convert KB to bytes

        // Get Dart heap (approximate using Runtime)
        val runtime = Runtime.getRuntime()
        val dartHeap = runtime.totalMemory() - runtime.freeMemory()

        // Get native heap
        val nativeHeap = Debug.getNativeHeapAllocatedSize()

        return mapOf(
            "totalRAM" to memInfo.totalMem,
            "usedRAM" to (memInfo.totalMem - memInfo.availMem),
            "availableRAM" to memInfo.availMem,
            "appRAM" to appRAM,
            "dartHeap" to dartHeap,
            "nativeHeap" to nativeHeap,
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun getCpuMetrics(): Map<String, Any> {
        val cpuUsage = getCurrentCpuUsage()
        val cpuCores = Runtime.getRuntime().availableProcessors()

        return mapOf(
            "cpuUsage" to cpuUsage,
            "cpuCores" to cpuCores,
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun getBatteryMetrics(): Map<String, Any> {
        val batteryStatus: Intent? = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))

        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) {
            (level.toFloat() / scale.toFloat()) * 100.0f
        } else {
            0.0f
        }

        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL

        return mapOf(
            "level" to batteryPct.toDouble(),
            "isCharging" to isCharging,
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun getCurrentCpuUsage(): Double {
        return try {
            // Read /proc/stat to get CPU usage
            val reader = RandomAccessFile("/proc/stat", "r")
            val load = reader.readLine()
            reader.close()

            val toks = load.split(" +".toRegex())

            // Get idle time and total time
            val idle = toks[4].toLong()
            val total = toks.drop(1).take(7).sumOf { it.toLongOrNull() ?: 0L }

            // Calculate usage percentage (simplified)
            if (total > 0) {
                ((total - idle).toDouble() / total.toDouble()) * 100.0
            } else {
                0.0
            }
        } catch (e: Exception) {
            // Fallback: return 0 if unable to read CPU stats
            0.0
        }
    }
}
