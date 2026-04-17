package dev.brewkits.native_workmanager.store

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * Centralized SQLite helper for the native_workmanager plugin.
 */
internal class DatabaseHelper(context: Context) : 
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME = "native_workmanager_v2.db"
        const val DATABASE_VERSION = 3

        @Volatile
        private var instance: DatabaseHelper? = null

        fun getInstance(context: Context): DatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: DatabaseHelper(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) {
        Log.d("DatabaseHelper", "onCreate() - creating all tables in $DATABASE_NAME")
        
        // --- TaskStore tables ---
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
                constraints_json TEXT,
                last_progress_json TEXT
            )
        """.trimIndent())

        // --- MiddlewareStore tables ---
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS middleware (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                type        TEXT NOT NULL,
                config_json TEXT NOT NULL,
                updated_at  INTEGER NOT NULL
            )
        """.trimIndent())

        // --- OfflineQueueStore tables ---
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

        // --- RemoteTriggerStore tables ---
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS remote_triggers (
                source               TEXT PRIMARY KEY,
                payload_key          TEXT NOT NULL,
                worker_mappings_json TEXT NOT NULL,
                updated_at           INTEGER NOT NULL,
                secret_key           TEXT
            )
        """.trimIndent())

        // --- ChainStore tables ---
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS chains (
                chain_id      TEXT PRIMARY KEY,
                chain_name    TEXT,
                status        TEXT NOT NULL DEFAULT 'pending',
                total_steps   INTEGER NOT NULL DEFAULT 0,
                current_step  INTEGER NOT NULL DEFAULT 0,
                created_at    INTEGER NOT NULL,
                updated_at    INTEGER NOT NULL
            )
        """.trimIndent())
        
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS chain_steps (
                chain_id    TEXT NOT NULL,
                step_index  INTEGER NOT NULL,
                task_id     TEXT NOT NULL,
                status      TEXT NOT NULL DEFAULT 'pending',
                result_json TEXT,
                updated_at  INTEGER NOT NULL,
                PRIMARY KEY (chain_id, task_id)
            )
        """.trimIndent())
    }

    override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {
        if (old < 2) {
            try {
                db.execSQL("ALTER TABLE tasks ADD COLUMN last_progress_json TEXT")
            } catch (_: Exception) {}
        }
        if (old < 3) {
            try {
                db.execSQL("ALTER TABLE remote_triggers ADD COLUMN secret_key TEXT")
            } catch (_: Exception) {}
        }
        onCreate(db)
    }
}
