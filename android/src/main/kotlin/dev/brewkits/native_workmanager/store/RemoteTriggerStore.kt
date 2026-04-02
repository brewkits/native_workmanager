package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

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

    private val helper = object : SQLiteOpenHelper(context, "native_workmanager.db", null, 6) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS remote_triggers (
                    source               TEXT PRIMARY KEY,
                    payload_key          TEXT NOT NULL,
                    worker_mappings_json TEXT NOT NULL,
                    updated_at           INTEGER NOT NULL
                )
            """.trimIndent())
        }

        override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {
            if (old < 4) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS remote_triggers (
                        source               TEXT PRIMARY KEY,
                        payload_key          TEXT NOT NULL,
                        worker_mappings_json TEXT NOT NULL,
                        updated_at           INTEGER NOT NULL
                    )
                """.trimIndent())
            }
            // v5-v6: no schema changes
        }
    }

    fun upsert(source: String, payloadKey: String, workerMappingsJson: String) {
        val now = System.currentTimeMillis()
        val cv = ContentValues().apply {
            put("source", source)
            put("payload_key", payloadKey)
            put("worker_mappings_json", workerMappingsJson)
            put("updated_at", now)
        }
        helper.writableDatabase.insertWithOnConflict(
            "remote_triggers",
            null,
            cv,
            SQLiteDatabase.CONFLICT_REPLACE
        )
    }

    fun getRule(source: String): RemoteTriggerRecord? =
        helper.readableDatabase.rawQuery(
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
        helper.writableDatabase.delete("remote_triggers", "source = ?", arrayOf(source))
    }
}
