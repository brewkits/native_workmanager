package dev.brewkits.native_workmanager.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

internal object DownloadNotificationManager {
    const val CHANNEL_ID = "native_workmanager_downloads"
    const val CHANNEL_NAME = "Downloads"
    const val CANCEL_ACTION = "dev.brewkits.native_workmanager.CANCEL_DOWNLOAD"
    const val PAUSE_ACTION  = "dev.brewkits.native_workmanager.PAUSE_DOWNLOAD"
    const val EXTRA_TASK_ID = "taskId"

    private val notifIds = ConcurrentHashMap<String, Int>()
    private val nextId = AtomicInteger(2000)

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW  // LOW = no sound, shows in status bar
            ).apply {
                description = "Download progress notifications"
                setShowBadge(false)
            }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    fun showProgress(
        context: Context,
        taskId: String,
        title: String,
        progress: Int,    // 0-100, or -1 for indeterminate
        message: String? = null
    ) {
        val notifId = notifIds.getOrPut(taskId) { nextId.incrementAndGet() }
        val cancelIntent = PendingIntent.getBroadcast(
            context, notifId,
            Intent(CANCEL_ACTION).setPackage(context.packageName).putExtra(EXTRA_TASK_ID, taskId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Use notifId + 10000 as a distinct request code for the pause PendingIntent
        val pauseIntent = PendingIntent.getBroadcast(
            context, notifId + 10_000,
            Intent(PAUSE_ACTION).setPackage(context.packageName).putExtra(EXTRA_TASK_ID, taskId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val indeterminate = progress < 0
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(message ?: if (indeterminate) "Downloading…" else "$progress%")
            .setProgress(100, if (indeterminate) 0 else progress, indeterminate)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .addAction(android.R.drawable.ic_media_pause, "Pause", pauseIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", cancelIntent)
        try {
            NotificationManagerCompat.from(context).notify(notifId, builder.build())
        } catch (_: SecurityException) { /* POST_NOTIFICATIONS not granted — silently ignore */ }
    }

    fun showCompleted(context: Context, taskId: String, title: String, fileName: String?) {
        val notifId = notifIds.remove(taskId) ?: nextId.incrementAndGet()
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(title)
            .setContentText(fileName ?: "Download complete")
            .setAutoCancel(true)
        try {
            NotificationManagerCompat.from(context).notify(notifId, builder.build())
        } catch (_: SecurityException) {}
    }

    fun showFailed(context: Context, taskId: String, title: String, error: String) {
        val notifId = notifIds.remove(taskId) ?: nextId.incrementAndGet()
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(title)
            .setContentText(error)
            .setAutoCancel(true)
        try {
            NotificationManagerCompat.from(context).notify(notifId, builder.build())
        } catch (_: SecurityException) {}
    }

    fun dismiss(context: Context, taskId: String) {
        val notifId = notifIds.remove(taskId) ?: return
        NotificationManagerCompat.from(context).cancel(notifId)
    }
}
