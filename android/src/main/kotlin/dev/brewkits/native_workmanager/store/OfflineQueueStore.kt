package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Persistent store for the Offline Queue Pattern on Android.
 *
 * Stores tasks that should be executed when network is available.
 *
 * Schema:
 *   offline_queue (id INTEGER PK AUTOINCREMENT, queue_id, task_id, worker_class, worker_config, retry_policy, created_at)
 */
internal class OfflineQueueStore(context: Context) {

    data class QueueRecord(
        val id: Long,
        val queueId: String,
        val taskId: String,
        val workerClassName: String,
        val workerConfig: String?,
        val retryPolicy: String?,
        val createdAt: Long
    )

    private val helper = object : SQLiteOpenHelper(context, "native_workmanager.db", null, 6) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS offline_queue (
                    id              INTEGER PRIMARY KEY AUTOINCREMENT,
                    queue_id        TEXT NOT NULL,
                    task_id         TEXT NOT NULL,
                    worker_class    TEXT NOT NULL,
                    worker_config   TEXT,
                    retry_policy    TEXT,
                    created_at      INTEGER NOT NULL
                )
            """.trimIndent())
        }

        override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {
            if (old < 5) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS offline_queue (
                        id              INTEGER PRIMARY KEY AUTOINCREMENT,
                        queue_id        TEXT NOT NULL,
                        task_id         TEXT NOT NULL,
                        worker_class    TEXT NOT NULL,
                        worker_config   TEXT,
                        retry_policy    TEXT,
                        created_at      INTEGER NOT NULL
                    )
                """.trimIndent())
            }
            // v6: no schema changes
        }
    }

    fun enqueue(
        queueId: String,
        taskId: String,
        workerClassName: String,
        workerConfig: String?,
        retryPolicy: String?
    ): Long {
        val cv = ContentValues().apply {
            put("queue_id", queueId)
            put("task_id", taskId)
            put("worker_class", workerClassName)
            put("worker_config", workerConfig)
            put("retry_policy", retryPolicy)
            put("created_at", System.currentTimeMillis())
        }
        return helper.writableDatabase.insert("offline_queue", null, cv)
    }

    fun getNextEntries(limit: Int = 10): List<QueueRecord> =
        helper.readableDatabase.rawQuery(
            "SELECT * FROM offline_queue ORDER BY created_at ASC LIMIT ?",
            arrayOf(limit.toString())
        ).use { c ->
            val list = mutableListOf<QueueRecord>()
            while (c.moveToNext()) {
                list.add(QueueRecord(
                    id = c.getLong(c.getColumnIndexOrThrow("id")),
                    queueId = c.getString(c.getColumnIndexOrThrow("queue_id")),
                    taskId = c.getString(c.getColumnIndexOrThrow("task_id")),
                    workerClassName = c.getString(c.getColumnIndexOrThrow("worker_class")),
                    workerConfig = c.getString(c.getColumnIndexOrThrow("worker_config")),
                    retryPolicy = c.getString(c.getColumnIndexOrThrow("retry_policy")),
                    createdAt = c.getLong(c.getColumnIndexOrThrow("created_at"))
                ))
            }
            list
        }

    fun deleteEntry(id: Long) {
        helper.writableDatabase.delete("offline_queue", "id = ?", arrayOf(id.toString()))
    }

    fun getQueueSize(): Int {
        val db = helper.readableDatabase
        db.rawQuery("SELECT COUNT(*) FROM offline_queue", null).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getInt(0)
        }
        return 0
    }
}
