package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

internal class TaskStore(context: Context) {

    data class TaskRecord(
        val taskId: String,
        val tag: String?,
        val status: String,
        val workerClassName: String,
        val workerConfig: String?,
        val createdAt: Long,
        val updatedAt: Long,
        val resultData: String?
    )

    private val helper = object : SQLiteOpenHelper(context, "native_workmanager.db", null, 2) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS tasks (
                    task_id         TEXT PRIMARY KEY,
                    tag             TEXT,
                    status          TEXT NOT NULL,
                    worker_class    TEXT NOT NULL,
                    worker_config   TEXT,
                    created_at      INTEGER NOT NULL,
                    updated_at      INTEGER NOT NULL,
                    result_data     TEXT
                )
            """.trimIndent())
        }
        override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {
            db.execSQL("DROP TABLE IF EXISTS tasks")
            onCreate(db)
        }
    }

    fun upsert(
        taskId: String,
        tag: String?,
        status: String,
        workerClassName: String,
        workerConfig: String?
    ) {
        val now = System.currentTimeMillis()
        val cv = ContentValues().apply {
            put("task_id", taskId)
            put("tag", tag)
            put("status", status)
            put("worker_class", workerClassName)
            put("worker_config", workerConfig)
            put("created_at", now)
            put("updated_at", now)
        }
        helper.writableDatabase.insertWithOnConflict("tasks", null, cv, SQLiteDatabase.CONFLICT_IGNORE)
        // Update mutable fields if row already existed
        val updateCv = ContentValues().apply {
            put("status", status)
            put("updated_at", now)
            if (tag != null) put("tag", tag)
        }
        helper.writableDatabase.update("tasks", updateCv, "task_id = ?", arrayOf(taskId))
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

    fun getAllTasks(): List<TaskRecord> =
        helper.readableDatabase.rawQuery("SELECT * FROM tasks ORDER BY updated_at DESC", null)
            .use { c ->
                val list = mutableListOf<TaskRecord>()
                while (c.moveToNext()) list.add(c.toRecord())
                list
            }

    fun getTasksByTag(tag: String): List<TaskRecord> =
        helper.readableDatabase.rawQuery("SELECT * FROM tasks WHERE tag = ? ORDER BY updated_at DESC", arrayOf(tag))
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

    private fun android.database.Cursor.toRecord() = TaskRecord(
        taskId       = getString(getColumnIndexOrThrow("task_id")),
        tag          = getString(getColumnIndexOrThrow("tag")),
        status       = getString(getColumnIndexOrThrow("status")),
        workerClassName = getString(getColumnIndexOrThrow("worker_class")),
        workerConfig = getString(getColumnIndexOrThrow("worker_config")),
        createdAt    = getLong(getColumnIndexOrThrow("created_at")),
        updatedAt    = getLong(getColumnIndexOrThrow("updated_at")),
        resultData   = getString(getColumnIndexOrThrow("result_data"))
    )

    fun TaskRecord.toFlutterMap(): Map<String, Any?> = mapOf(
        "taskId"          to taskId,
        "tag"             to tag,
        "status"          to status,
        "workerClassName" to workerClassName,
        "createdAt"       to createdAt,
        "updatedAt"       to updatedAt,
        "resultData"      to resultData  // null or JSON string — Dart side parses
    )
}
