package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * Persistent task storage for Android using SQLite.
 *
 * Uses built-in Android SQLite Framework (no third-party dependencies).
 * Features:
 * - WAL (Write-Ahead Logging) mode for concurrent read/write.
 * - Atomic transactions for data integrity.
 * - Automatic sensitive data redaction (Sanitization).
 * - "Zombie" task recovery (resets tasks stuck in 'running' state).
 */
internal class TaskStore(context: Context) {

    data class TaskRecord(
        val taskId: String,
        val tag: String?,
        val status: String,
        val workerClassName: String,
        val workerConfig: String?,
        val createdAt: Long,
        val updatedAt: Long,
        val resultData: String?,
        val constraintsJson: String? = null
    )

    private val helper = object : SQLiteOpenHelper(context, "native_workmanager.db", null, 8) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS tasks (
                    task_id          TEXT PRIMARY KEY,
                    tag              TEXT,
                    status           TEXT NOT NULL,
                    worker_class     TEXT NOT NULL,
                    worker_config    TEXT,
                    created_at       INTEGER NOT NULL,
                    updated_at       INTEGER NOT NULL,
                    result_data      TEXT,
                    constraints_json TEXT
                )
            """.trimIndent())
        }

        override fun onConfigure(db: SQLiteDatabase) {
            super.onConfigure(db)
            // ✅ PERFORMANCE: Enable Write-Ahead Logging for better concurrency.
            // Allows reading from the DB while a write transaction is in progress.
            db.enableWriteAheadLogging()
        }

        override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {
            if (old < 2) db.execSQL("ALTER TABLE tasks ADD COLUMN result_data TEXT")
            if (old < 7) db.execSQL("ALTER TABLE tasks ADD COLUMN constraints_json TEXT")
        }
    }

    /**
     * Recover "Zombie" tasks that are stuck in 'running' state.
     * 
     * FIX #03: Added Heartbeat check. Only recover tasks that have been in 'running'
     * state without any update for more than 5 minutes. This prevents killing
     * tasks that were just started by the OS during app launch.
     */
    fun recoverZombieTasks() {
        val now = System.currentTimeMillis()
        val timeoutMs = 5 * 60 * 1000L // 5 minutes heartbeat timeout
        val threshold = now - timeoutMs

        val cv = ContentValues().apply {
            put("status", "failed")
            put("result_data", "{\"message\": \"Process died or hung (heartbeat timeout)\", \"shouldRetry\": true}")
            put("updated_at", now)
        }
        
        // Only update where status is running AND updated_at is older than 5 minutes
        val count = helper.writableDatabase.update(
            "tasks", 
            cv, 
            "status = 'running' AND updated_at < ?", 
            arrayOf(threshold.toString())
        )
        
        if (count > 0) {
            Log.d("TaskStore", "Recovered $count zombie tasks (heartbeat based)")
        }
    }

    fun upsert(
        taskId: String,
        tag: String?,
        status: String,
        workerClassName: String,
        workerConfig: String?,
        constraintsJson: String? = null
    ) {
        val now = System.currentTimeMillis()
        val db = helper.writableDatabase
        
        // ✅ SECURITY: Sanitize config before persisting to prevent token leakage.
        val sanitizedConfig = sanitizeConfig(workerConfig)
        
        db.beginTransaction()
        try {
            val existingCreatedAt = db.rawQuery(
                "SELECT created_at FROM tasks WHERE task_id = ?", arrayOf(taskId)
            ).use { c -> if (c.moveToFirst()) c.getLong(0) else now }

            val cv = ContentValues().apply {
                put("task_id", taskId)
                put("tag", tag)
                put("status", status)
                put("worker_class", workerClassName)
                put("worker_config", sanitizedConfig)
                put("created_at", existingCreatedAt)
                put("updated_at", now)
                put("constraints_json", constraintsJson)
            }
            db.insertWithOnConflict("tasks", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun updateStatus(taskId: String, status: String, resultData: String? = null) {
        val cv = ContentValues().apply {
            put("status", status)
            put("updated_at", System.currentTimeMillis())
            if (resultData != null) put("result_data", resultData)
        }
        helper.writableDatabase.update("tasks", cv, "task_id = ?", arrayOf(taskId))
    }

    fun getTask(taskId: String): TaskRecord? =
        helper.readableDatabase.rawQuery("SELECT * FROM tasks WHERE task_id = ?", arrayOf(taskId))
            .use { c -> if (c.moveToFirst()) c.toRecord() else null }

    fun getTasksByTag(tag: String): List<TaskRecord> =
        helper.readableDatabase.rawQuery("SELECT * FROM tasks WHERE tag = ? ORDER BY updated_at DESC", arrayOf(tag))
            .use { c ->
                val list = mutableListOf<TaskRecord>()
                while (c.moveToNext()) list.add(c.toRecord())
                list
            }

    fun getAllTasks(): List<TaskRecord> =
        helper.readableDatabase.rawQuery("SELECT * FROM tasks ORDER BY updated_at DESC", null)
            .use { c ->
                val list = mutableListOf<TaskRecord>()
                while (c.moveToNext()) list.add(c.toRecord())
                list
            }

    fun delete(taskId: String) {
        helper.writableDatabase.delete("tasks", "task_id = ?", arrayOf(taskId))
    }

    fun deleteCompleted(olderThanMs: Long = 0L) {
        val threshold = if (olderThanMs > 0) System.currentTimeMillis() - olderThanMs else Long.MAX_VALUE
        helper.writableDatabase.delete(
            "tasks",
            "status IN ('completed','failed','cancelled') AND updated_at < ?",
            arrayOf(threshold.toString())
        )
    }

    private fun android.database.Cursor.toRecord(): TaskRecord {
        val constraintsColIdx = getColumnIndex("constraints_json")
        return TaskRecord(
            taskId          = getString(getColumnIndexOrThrow("task_id")),
            tag             = getString(getColumnIndexOrThrow("tag")),
            status          = getString(getColumnIndexOrThrow("status")),
            workerClassName = getString(getColumnIndexOrThrow("worker_class")),
            workerConfig    = getString(getColumnIndexOrThrow("worker_config")),
            createdAt       = getLong(getColumnIndexOrThrow("created_at")),
            updatedAt       = getLong(getColumnIndexOrThrow("updated_at")),
            resultData      = getString(getColumnIndexOrThrow("result_data")),
            constraintsJson = if (constraintsColIdx >= 0) getString(constraintsColIdx) else null
        )
    }

    companion object {
        private val SENSITIVE_KEYS = setOf(
            "authToken", "authorization", "cookies", "password", "secret",
            "accessToken", "refreshToken", "apiKey", "token", "bearer"
        )

        fun sanitizeConfig(json: String?): String? {
            if (json == null) return null
            return try {
                val obj = org.json.JSONObject(json)
                sanitizeObject(obj)
                obj.toString()
            } catch (_: Exception) { json }
        }

        private fun sanitizeObject(obj: org.json.JSONObject) {
            val keys = obj.keys().asSequence().toList()
            for (key in keys) {
                if (SENSITIVE_KEYS.any { it.equals(key, ignoreCase = true) }) {
                    obj.put(key, "[REDACTED]")
                } else {
                    when (val value = obj.opt(key)) {
                        is org.json.JSONObject -> sanitizeObject(value)
                        is org.json.JSONArray  -> sanitizeArray(value)
                        else -> { }
                    }
                }
            }
        }

        private fun sanitizeArray(arr: org.json.JSONArray) {
            for (i in 0 until arr.length()) {
                when (val item = arr.opt(i)) {
                    is org.json.JSONObject -> sanitizeObject(item)
                    is org.json.JSONArray  -> sanitizeArray(item)
                    else -> { }
                }
            }
        }
    }

    fun getActiveTaskCount(): Int {
        val db = helper.readableDatabase
        db.rawQuery("SELECT COUNT(*) FROM tasks WHERE status IN ('pending', 'running')", null).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getInt(0)
        }
        return 0
    }

    fun getFailedTaskCount(): Int {
        val db = helper.readableDatabase
        db.rawQuery("SELECT COUNT(*) FROM tasks WHERE status = 'failed'", null).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getInt(0)
        }
        return 0
    }

    fun getCompletedTaskCount(): Int {
        val db = helper.readableDatabase
        db.rawQuery("SELECT COUNT(*) FROM tasks WHERE status = 'success'", null).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getInt(0)
        }
        return 0
    }

    fun TaskRecord.toFlutterMap(): Map<String, Any?> = mapOf(
        "taskId"          to taskId,
        "tag"             to tag,
        "status"          to status,
        "workerClassName" to workerClassName,
        "createdAt"       to createdAt,
        "updatedAt"       to updatedAt,
        "resultData"      to resultData
    )
}
