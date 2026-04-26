package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
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
        val constraintsJson: String? = null,
        val lastProgressJson: String? = null
    )

    private val dbHelper = DatabaseHelper.getInstance(context)

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
        val count = dbHelper.writableDatabase.update(
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
        val db = dbHelper.writableDatabase
        
        // Sanitize config before persisting to prevent token leakage.
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
        Log.d("TaskStore", "Updating task $taskId status to $status, resultData length: ${resultData?.length ?: 0}")
        val cv = ContentValues().apply {
            put("status", status)
            put("updated_at", System.currentTimeMillis())
            if (resultData != null) put("result_data", resultData)
        }
        dbHelper.writableDatabase.update("tasks", cv, "task_id = ?", arrayOf(taskId))
    }

    fun updateProgress(taskId: String, progressJson: String) {
        val cv = ContentValues().apply {
            put("last_progress_json", progressJson)
            put("updated_at", System.currentTimeMillis())
        }
        dbHelper.writableDatabase.update("tasks", cv, "task_id = ?", arrayOf(taskId))
    }

    fun getTask(taskId: String): TaskRecord? =
        dbHelper.readableDatabase.rawQuery("SELECT * FROM tasks WHERE task_id = ?", arrayOf(taskId))
            .use { c -> if (c.moveToFirst()) c.toRecord() else null }

    fun getTasksByTag(tag: String): List<TaskRecord> =
        dbHelper.readableDatabase.rawQuery("SELECT * FROM tasks WHERE tag = ? ORDER BY updated_at DESC", arrayOf(tag))
            .use { c ->
                val list = mutableListOf<TaskRecord>()
                while (c.moveToNext()) list.add(c.toRecord())
                list
            }

    fun getAllTasks(): List<TaskRecord> =
        dbHelper.readableDatabase.rawQuery("SELECT * FROM tasks ORDER BY updated_at DESC", null)
            .use { c ->
                val list = mutableListOf<TaskRecord>()
                while (c.moveToNext()) list.add(c.toRecord())
                list
            }

    fun delete(taskId: String) {
        dbHelper.writableDatabase.delete("tasks", "task_id = ?", arrayOf(taskId))
    }

    fun deleteCompleted(olderThanMs: Long = 0L, batchSize: Int = 1000) {
        val threshold = if (olderThanMs > 0) System.currentTimeMillis() - olderThanMs else Long.MAX_VALUE
        // Batch delete to avoid holding a long write-lock that blocks concurrent upsert calls.
        // Repeat until fewer rows than batchSize are deleted (i.e. no more rows to clean).
        do {
            val deleted = dbHelper.writableDatabase.delete(
                "tasks",
                "task_id IN (SELECT task_id FROM tasks WHERE status IN ('completed','failed','cancelled') AND updated_at < ? LIMIT ?)",
                arrayOf(threshold.toString(), batchSize.toString())
            )
            if (deleted < batchSize) break
        } while (true)
    }

    private fun android.database.Cursor.toRecord(): TaskRecord {
        val constraintsColIdx = getColumnIndex("constraints_json")
        val progressColIdx = getColumnIndex("last_progress_json")
        return TaskRecord(
            taskId          = getString(getColumnIndexOrThrow("task_id")),
            tag             = getString(getColumnIndexOrThrow("tag")),
            status          = getString(getColumnIndexOrThrow("status")),
            workerClassName = getString(getColumnIndexOrThrow("worker_class")),
            workerConfig    = getString(getColumnIndexOrThrow("worker_config")),
            createdAt       = getLong(getColumnIndexOrThrow("created_at")),
            updatedAt       = getLong(getColumnIndexOrThrow("updated_at")),
            resultData      = getString(getColumnIndexOrThrow("result_data")),
            constraintsJson = if (constraintsColIdx >= 0) getString(constraintsColIdx) else null,
            lastProgressJson = if (progressColIdx >= 0) getString(progressColIdx) else null
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
        val db = dbHelper.readableDatabase
        db.rawQuery("SELECT COUNT(*) FROM tasks WHERE status IN ('pending', 'running')", null).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getInt(0)
        }
        return 0
    }

    fun getFailedTaskCount(): Int {
        val db = dbHelper.readableDatabase
        db.rawQuery("SELECT COUNT(*) FROM tasks WHERE status = 'failed'", null).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getInt(0)
        }
        return 0
    }

    fun getCompletedTaskCount(): Int {
        val db = dbHelper.readableDatabase
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
        "workerConfig"    to workerConfig,
        "createdAt"       to createdAt,
        "updatedAt"       to updatedAt,
        "resultData"      to try {
            resultData?.let { org.json.JSONObject(it).toMap() }
        } catch (_: Exception) {
            null
        }
    )

    private fun org.json.JSONObject.toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = keys()
        while (keys.hasNext()) {
            val key = keys.next()
            var value = get(key)
            if (value is org.json.JSONArray) {
                value = value.toList()
            } else if (value is org.json.JSONObject) {
                value = value.toMap()
            }
            if (value == org.json.JSONObject.NULL) value = null
            map[key] = value
        }
        return map
    }

    private fun org.json.JSONArray.toList(): List<Any?> {
        val list = mutableListOf<Any?>()
        for (i in 0 until length()) {
            var value = get(i)
            if (value is org.json.JSONArray) {
                value = value.toList()
            } else if (value is org.json.JSONObject) {
                value = value.toMap()
            }
            if (value == org.json.JSONObject.NULL) value = null
            list.add(value)
        }
        return list
    }
}
