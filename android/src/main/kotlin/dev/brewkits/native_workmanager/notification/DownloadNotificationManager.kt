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
    private const val GROUP_KEY = "nwm_downloads"
    private const val SUMMARY_NOTIF_ID = 1999

    private val notifIds = ConcurrentHashMap<String, Int>()
    private val nextId = AtomicInteger(2000)

    /**
     * Replace template variables in a notification title or message.
     *
     * Supported variables:
     * - `{filename}` → the file name (last path segment of URL or save path)
     * - `{progress}` → "42%" (integer percent)
     * - `{numFinished}` → number of completed tasks in the group
     * - `{numTotal}` → total tasks in the group
     */
    fun applyTemplate(
        template: String,
        filename: String? = null,
        progress: Int = 0,
        numFinished: Int = 0,
        numTotal: Int = 0
    ): String = template
        .replace("{filename}", filename ?: "")
        .replace("{progress}", "$progress%")
        .replace("{numFinished}", numFinished.toString())
        .replace("{numTotal}", numTotal.toString())

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
        message: String? = null,
        filename: String? = null,
        allowPause: Boolean = true,
        numFinished: Int = 0,
        numTotal: Int = 0
    ) {
        val notifId = notifIds.getOrPut(taskId) { nextId.incrementAndGet() }
        val effectiveProgress = if (progress < 0) 0 else progress
        val resolvedTitle = applyTemplate(title, filename, effectiveProgress, numFinished, numTotal)
        val resolvedMessage = message?.let { applyTemplate(it, filename, effectiveProgress, numFinished, numTotal) }
        val cancelIntent = PendingIntent.getBroadcast(
            context, notifId,
            Intent(CANCEL_ACTION).setPackage(context.packageName).putExtra(EXTRA_TASK_ID, taskId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val indeterminate = progress < 0
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(resolvedTitle)
            .setContentText(resolvedMessage ?: if (indeterminate) "Downloading…" else "$effectiveProgress%")
            .setProgress(100, effectiveProgress, indeterminate)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setGroup(GROUP_KEY)
        if (allowPause) {
            // Use notifId + 10000 as a distinct request code for the pause PendingIntent
            val pauseIntent = PendingIntent.getBroadcast(
                context, notifId + 10_000,
                Intent(PAUSE_ACTION).setPackage(context.packageName).putExtra(EXTRA_TASK_ID, taskId),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(android.R.drawable.ic_media_pause, "Pause", pauseIntent)
        }
        builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", cancelIntent)
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
            .setGroup(GROUP_KEY)
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
            .setGroup(GROUP_KEY)
        try {
            NotificationManagerCompat.from(context).notify(notifId, builder.build())
        } catch (_: SecurityException) {}
    }

    /**
     * Show or update the notification group summary.
     * Call this whenever the set of active/completed downloads changes.
     *
     * @param activeCount     number of downloads currently in progress
     * @param completedCount  number of downloads completed in this session
     */
    fun updateGroupSummary(context: Context, activeCount: Int, completedCount: Int) {
        if (activeCount <= 0 && completedCount <= 0) {
            // Nothing to summarise — dismiss summary
            try { NotificationManagerCompat.from(context).cancel(SUMMARY_NOTIF_ID) } catch (_: Exception) {}
            return
        }
        val text = when {
            activeCount > 0 && completedCount > 0 -> "$activeCount active, $completedCount completed"
            activeCount > 0 -> "$activeCount download${if (activeCount > 1) "s" else ""} in progress"
            else -> "$completedCount download${if (completedCount > 1) "s" else ""} complete"
        }
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Downloads")
            .setContentText(text)
            .setGroup(GROUP_KEY)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .setSilent(true)
        try {
            NotificationManagerCompat.from(context).notify(SUMMARY_NOTIF_ID, builder.build())
        } catch (_: SecurityException) {}
    }

    fun dismiss(context: Context, taskId: String) {
        val notifId = notifIds.remove(taskId) ?: return
        NotificationManagerCompat.from(context).cancel(notifId)
    }
}
