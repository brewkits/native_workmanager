package dev.brewkits.native_workmanager.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.WorkManager

class NotificationCancelReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadNotificationManager.CANCEL_ACTION) return
        val taskId = intent.getStringExtra(DownloadNotificationManager.EXTRA_TASK_ID) ?: return
        WorkManager.getInstance(context).cancelUniqueWork(taskId)
        DownloadNotificationManager.dismiss(context, taskId)
    }
}
