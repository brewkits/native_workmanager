package dev.brewkits.native_workmanager.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.WorkManager
import dev.brewkits.native_workmanager.store.TaskStore

class NotificationPauseReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadNotificationManager.PAUSE_ACTION) return
        val taskId = intent.getStringExtra(DownloadNotificationManager.EXTRA_TASK_ID) ?: return
        // Cancel WorkManager work — preserves the .tmp partial file for later resume
        WorkManager.getInstance(context).cancelUniqueWork(taskId)
        // Persist paused state so the plugin's handleResume can pick it up
        TaskStore(context).updateStatus(taskId, "paused")
        DownloadNotificationManager.dismiss(context, taskId)
    }
}
