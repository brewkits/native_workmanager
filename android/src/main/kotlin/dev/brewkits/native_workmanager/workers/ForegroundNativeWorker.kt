package dev.brewkits.native_workmanager.workers

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ForegroundInfo
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.SimpleAndroidWorkerFactory
import dev.brewkits.native_workmanager.engine.TaskEventBus
import dev.brewkits.native_workmanager.utils.MappingUtils.toJson
import org.json.JSONObject

class ForegroundNativeWorker(
    private val context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    private val fgsConfigJson = inputData.getString("fgsConfigJson")
    private val workerClassName = inputData.getString("workerClassName") ?: "Unknown"
    private val taskId = inputData.getString("taskId") ?: id.toString()

    override suspend fun doWork(): Result {
        NativeLogger.d("ForegroundNativeWorker: starting doWork for $taskId ($workerClassName)")

        try {
            setForeground(getForegroundInfo())
        } catch (e: Exception) {
            NativeLogger.e("ForegroundNativeWorker: Failed to set foreground status. This might be due to background-start restrictions on Android 12+.", e)
            // We continue as background work if possible, but the OS might kill us.
        }
        val workerFactory = SimpleAndroidWorkerFactory(context)
        val worker = workerFactory.createWorker(workerClassName)
        if (worker == null) {
            NativeLogger.e("ForegroundNativeWorker: Worker class not found: $workerClassName")
            emitToBus(false, "Worker class not found: $workerClassName")
            return Result.failure()
        }

        var inputJson = inputData.getString("inputJson")
        val inputJsonFile = inputData.getString("inputJsonFile")
        if (inputJson == null && inputJsonFile != null) {
            val file = java.io.File(inputJsonFile)
            if (file.exists()) {
                inputJson = file.readText()
            }
        }

        val env = WorkerEnvironment(null, { isStopped })

        return try {
            val result = worker.doWork(inputJson ?: "", env)
            when (result) {
                is WorkerResult.Success -> {
                    val outputJson = result.data?.let { toJson(it as Map<*, *>) }
                    emitToBus(true, result.message, outputJson)
                    val outputData = Data.Builder()
                    if (outputJson != null) outputData.putString("outputData", outputJson)
                    Result.success(outputData.build())
                }
                is WorkerResult.Failure -> {
                    emitToBus(false, result.message, null)
                    if (result.shouldRetry) {
                        Result.retry()
                    } else {
                        Result.failure()
                    }
                }
            }
        } catch (e: Exception) {
            NativeLogger.e("ForegroundNativeWorker: Error executing worker", e)
            emitToBus(false, e.message ?: "Unknown execution error")
            Result.failure()
        }
    }

    private suspend fun emitToBus(success: Boolean, message: String?, outputData: String? = null) {
        try {
            TaskEventBus.emit(
                TaskEventBus.Event(
                    taskId = taskId,
                    taskName = taskId,
                    success = success,
                    message = message,
                    outputData = outputData
                )
            )
        } catch (e: Exception) {
            NativeLogger.e("ForegroundNativeWorker: Failed to emit to TaskEventBus", e)
        }
    }

    override suspend fun getForegroundInfo(): ForegroundInfo {
        val fgsConfig = fgsConfigJson?.let { JSONObject(it) }

        val title = fgsConfig?.optString("title")?.takeIf { it.isNotBlank() } ?: "Background Task"
        val body = fgsConfig?.optString("body")?.takeIf { it.isNotBlank() } ?: "Running..."
        val iconName = fgsConfig?.optString("iconName")
        val colorHex = fgsConfig?.optString("colorHex")
        val showCancelButton = fgsConfig?.optBoolean("showCancelButton", true) ?: true
        val cancelText = fgsConfig?.optString("cancelText")?.takeIf { it.isNotBlank() } ?: "Cancel"

        val channelId = "native_workmanager_fgs"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Background Tasks",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        var smallIcon = android.R.drawable.stat_sys_download
        if (!iconName.isNullOrBlank()) {
            val resId = context.resources.getIdentifier(iconName, "drawable", context.packageName)
            if (resId != 0) {
                smallIcon = resId
            }
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(smallIcon)
            .setOngoing(true)

        if (!colorHex.isNullOrBlank()) {
            try {
                builder.color = android.graphics.Color.parseColor(colorHex)
            } catch (e: Exception) {
                // Ignore parse error
            }
        }

        if (showCancelButton) {
            val cancelIntent = WorkManager.getInstance(context).createCancelPendingIntent(id)
            builder.addAction(android.R.drawable.ic_delete, cancelText, cancelIntent)
        }

        val notification = builder.build()
        val notificationId = id.hashCode()

        // Handle Android 14+ FGS Types
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Check for explicit type in inputData (mapped via MappingUtils)
            val typeName = inputData.getString("fgsType")
            val serviceType = when (typeName?.lowercase()) {
                "datasync" -> ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                "location" -> ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                "mediaplayback" -> ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                "phonecall" -> ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
                "connecteddevice" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE else 0
                "mediaprojection" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION else 0
                "health" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                "remotemessaging" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                "shortservice" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                "specialuse" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                "systemexemption" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) 0x00000400 else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                else -> ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            }
            ForegroundInfo(notificationId, notification, serviceType)
        } else {
            ForegroundInfo(notificationId, notification)
        }
    }
}
