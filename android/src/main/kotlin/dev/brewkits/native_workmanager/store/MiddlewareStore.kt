package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

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

    private val helper = object : SQLiteOpenHelper(context, "native_workmanager.db", null, 6) {
        override fun onCreate(db: SQLiteDatabase) {
            // Tables from previous versions...
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS middleware (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    type        TEXT NOT NULL,
                    config_json TEXT NOT NULL,
                    updated_at  INTEGER NOT NULL
                )
            """.trimIndent())
        }

        override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {
            if (old < 6) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS middleware (
                        id          INTEGER PRIMARY KEY AUTOINCREMENT,
                        type        TEXT NOT NULL,
                        config_json TEXT NOT NULL,
                        updated_at  INTEGER NOT NULL
                    )
                """.trimIndent())
            }
        }
    }

    fun add(type: String, configJson: String): Long {
        val cv = ContentValues().apply {
            put("type", type)
            put("config_json", configJson)
            put("updated_at", System.currentTimeMillis())
        }
        return helper.writableDatabase.insert("middleware", null, cv)
    }

    fun getAll(): List<MiddlewareRecord> =
        helper.readableDatabase.rawQuery("SELECT * FROM middleware", null).use { c ->
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
        helper.writableDatabase.delete("middleware", null, null)
    }
}
