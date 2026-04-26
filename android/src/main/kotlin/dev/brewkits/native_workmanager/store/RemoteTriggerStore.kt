package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dev.brewkits.native_workmanager.NativeLogger

/**
 * Persistent store for remote trigger rules (FCM/APNs mappings).
 *
 * Rules are registered from Dart and stored here so that the native side
 * can look them up and execute workers when a remote message arrives.
 *
 * **Security:** Sensitive `secret_key` is stored in EncryptedSharedPreferences (Hardware-backed
 * if available). The SQLite column is preserved for backward compatibility and migration.
 */
internal class RemoteTriggerStore(private val context: Context) {

    data class RemoteTriggerRecord(
        val source: String,
        val payloadKey: String,
        val workerMappingsJson: String,
        val updatedAt: Long,
        val secretKey: String? = null
    )

    private val dbHelper = DatabaseHelper.getInstance(context)
    private val PREFS_NAME = "dev.brewkits.native_workmanager.remote_trigger_secrets"
    private val migrationLock = Any()

    private fun getEncryptedPrefs() = try {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    } catch (e: Exception) {
        NativeLogger.e("Failed to initialize EncryptedSharedPreferences", e)
        null
    }

    fun upsert(source: String, payloadKey: String, workerMappingsJson: String, secretKey: String? = null) {
        try {
            val now = System.currentTimeMillis()
            
            // SEC-001: Store secretKey in EncryptedSharedPreferences
            val prefs = getEncryptedPrefs()
            if (prefs != null) {
                if (secretKey != null) {
                    prefs.edit().putString("secret_$source", secretKey).apply()
                } else {
                    prefs.edit().remove("secret_$source").apply()
                }
            }

            val cv = ContentValues().apply {
                put("source", source)
                put("payload_key", payloadKey)
                put("worker_mappings_json", workerMappingsJson)
                put("updated_at", now)
                // Clear plain-text secret from SQLite for new/updated records
                putNull("secret_key")
            }
            dbHelper.writableDatabase.insertWithOnConflict(
                "remote_triggers",
                null,
                cv,
                SQLiteDatabase.CONFLICT_REPLACE
            )
        } catch (e: android.database.sqlite.SQLiteFullException) {
            dev.brewkits.native_workmanager.NativeWorkmanagerPlugin.emitSystemError(context, "DISK_FULL", "Cannot upsert remote trigger: Disk full")
            throw e
        }
    }

    fun getRule(source: String): RemoteTriggerRecord? {
        try {
            return dbHelper.readableDatabase.rawQuery(
                "SELECT * FROM remote_triggers WHERE source = ?",
                arrayOf(source)
            ).use { c ->
                if (c.moveToFirst()) {
                    val sqliteSecretKey = c.getString(c.getColumnIndexOrThrow("secret_key"))
                    
                    // SEC-001: Try Encrypted Prefs first, fallback to SQLite for migration
                    val prefs = getEncryptedPrefs()
                    var finalSecretKey = prefs?.getString("secret_$source", null)
                    
                    if (finalSecretKey == null && sqliteSecretKey != null) {
                        // Fixed: Lock migration to prevent race conditions (SEC-001)
                        synchronized(migrationLock) {
                            finalSecretKey = prefs?.getString("secret_$source", null)
                            if (finalSecretKey == null) {
                                finalSecretKey = sqliteSecretKey
                                prefs?.edit()?.putString("secret_$source", sqliteSecretKey)?.apply()
                            }
                        }
                    }

                    return RemoteTriggerRecord(
                        source = c.getString(c.getColumnIndexOrThrow("source")),
                        payloadKey = c.getString(c.getColumnIndexOrThrow("payload_key")),
                        workerMappingsJson = c.getString(c.getColumnIndexOrThrow("worker_mappings_json")),
                        updatedAt = c.getLong(c.getColumnIndexOrThrow("updated_at")),
                        secretKey = finalSecretKey
                    )
                } else null
            }
        } catch (e: android.database.sqlite.SQLiteFullException) {
            dev.brewkits.native_workmanager.NativeWorkmanagerPlugin.emitSystemError(context, "DISK_FULL", "Cannot read remote trigger: Disk full")
            return null
        }
    }

    fun delete(source: String) {
        try {
            getEncryptedPrefs()?.edit()?.remove("secret_$source")?.apply()
            dbHelper.writableDatabase.delete("remote_triggers", "source = ?", arrayOf(source))
        } catch (e: android.database.sqlite.SQLiteFullException) {
            dev.brewkits.native_workmanager.NativeWorkmanagerPlugin.emitSystemError(context, "DISK_FULL", "Cannot delete remote trigger: Disk full")
        }
    }
}
