package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase

/**
 * Persistent store for remote trigger rules (FCM/APNs mappings).
 *
 * Rules are registered from Dart and stored here so that the native side
 * can look them up and execute workers when a remote message arrives,
 * even if the app (and Flutter) is not currently running.
 *
 * Schema:
 *   remote_triggers (source PRIMARY KEY, payload_key, worker_mappings_json, updated_at)
 */
internal class RemoteTriggerStore(context: Context) {

    data class RemoteTriggerRecord(
        val source: String,
        val payloadKey: String,
        val workerMappingsJson: String,
        val updatedAt: Long
    )

    private val dbHelper = DatabaseHelper.getInstance(context)

    fun upsert(source: String, payloadKey: String, workerMappingsJson: String) {
        val now = System.currentTimeMillis()
        val cv = ContentValues().apply {
            put("source", source)
            put("payload_key", payloadKey)
            put("worker_mappings_json", workerMappingsJson)
            put("updated_at", now)
        }
        dbHelper.writableDatabase.insertWithOnConflict(
            "remote_triggers",
            null,
            cv,
            SQLiteDatabase.CONFLICT_REPLACE
        )
    }

    fun getRule(source: String): RemoteTriggerRecord? =
        dbHelper.readableDatabase.rawQuery(
            "SELECT * FROM remote_triggers WHERE source = ?",
            arrayOf(source)
        ).use { c ->
            if (c.moveToFirst()) {
                RemoteTriggerRecord(
                    source = c.getString(c.getColumnIndexOrThrow("source")),
                    payloadKey = c.getString(c.getColumnIndexOrThrow("payload_key")),
                    workerMappingsJson = c.getString(c.getColumnIndexOrThrow("worker_mappings_json")),
                    updatedAt = c.getLong(c.getColumnIndexOrThrow("updated_at"))
                )
            } else null
        }

    fun delete(source: String) {
        dbHelper.writableDatabase.delete("remote_triggers", "source = ?", arrayOf(source))
    }
}
