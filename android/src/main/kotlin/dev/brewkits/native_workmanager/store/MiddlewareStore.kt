package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase

/**
 * Persistent store for task middleware rules on Android.
 *
 * Schema:
 *   middleware (id INTEGER PK AUTOINCREMENT, type TEXT NOT NULL, config_json TEXT NOT NULL, updated_at INTEGER NOT NULL)
 */
internal class MiddlewareStore private constructor(context: Context) {

    companion object {
        @Volatile private var _instance: MiddlewareStore? = null

        fun getInstance(context: Context): MiddlewareStore =
            _instance ?: synchronized(this) {
                _instance ?: MiddlewareStore(context.applicationContext).also { _instance = it }
            }
    }

    data class MiddlewareRecord(
        val id: Long,
        val type: String,
        val configJson: String,
        val updatedAt: Long
    )

    private val dbHelper = DatabaseHelper.getInstance(context)

    fun add(type: String, configJson: String): Long {
        val db = dbHelper.writableDatabase
        db.beginTransaction()
        return try {
            // Upsert by type: remove any existing entry first so registerMiddleware
            // is idempotent — calling it twice replaces the old config instead of
            // accumulating duplicate rows that would be applied multiple times.
            db.delete("middleware", "type = ?", arrayOf(type))
            val cv = ContentValues().apply {
                put("type", type)
                put("config_json", configJson)
                put("updated_at", System.currentTimeMillis())
            }
            val id = db.insert("middleware", null, cv)
            db.setTransactionSuccessful()
            id
        } finally {
            db.endTransaction()
        }
    }

    fun getAll(): List<MiddlewareRecord> =
        dbHelper.readableDatabase.rawQuery("SELECT * FROM middleware", null).use { c ->
            val list = mutableListOf<MiddlewareRecord>()
            while (c.moveToNext()) {
                list.add(MiddlewareRecord(
                    id = c.getLong(c.getColumnIndexOrThrow("id")),
                    type = c.getString(c.getColumnIndexOrThrow("type")),
                    configJson = c.getString(c.getColumnIndexOrThrow("config_json")),
                    updatedAt = c.getLong(c.getColumnIndexOrThrow("updated_at"))
                ))
            }
            list
        }

    fun clear() {
        dbHelper.writableDatabase.delete("middleware", null, null)
    }
}
