package dev.brewkits.native_workmanager.workers.utils

import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dev.brewkits.native_workmanager.AppContextHolder
import java.util.UUID

/**
 * Secure password vault backed by Android Keystore + EncryptedSharedPreferences.
 *
 * WorkManager persists all input Data to an unencrypted Room database. Passing an
 * encryption password as a direct field would store it in plaintext on disk, defeating
 * the purpose of the encryption. This vault stores the password under a random UUID key
 * in EncryptedSharedPreferences (AES-256-GCM, hardware-backed on supported devices).
 *
 * Usage flow:
 *   1. Before enqueue: `val key = KeystorePasswordVault.store(password)`
 *   2. Pass `key` (UUID) in worker input instead of the raw password.
 *   3. In the worker: `val password = KeystorePasswordVault.retrieveAndDelete(key)`
 */
object KeystorePasswordVault {
    private const val TAG = "KeystorePasswordVault"
    private const val PREFS_NAME = "native_wm_crypto_vault"

    private val prefs by lazy {
        val context = AppContextHolder.appContext
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
    }

    /**
     * Store [secret] securely; returns the UUID key to pass to the worker.
     */
    fun store(secret: String): String {
        val key = UUID.randomUUID().toString()
        prefs.edit().putString(key, secret).apply()
        Log.d(TAG, "Secret stored under key=$key")
        return key
    }

    /**
     * Retrieve and immediately delete [key] from the vault.
     * Returns null if the key is not found (e.g. vault cleared between retries).
     */
    fun retrieveAndDelete(key: String): String? {
        val value = prefs.getString(key, null)
        if (value != null) {
            prefs.edit().remove(key).apply()
            Log.d(TAG, "Secret retrieved and deleted: key=$key")
        } else {
            Log.w(TAG, "Secret not found in vault: key=$key")
        }
        return value
    }

    /** Delete without retrieving (for cancel/cleanup paths). */
    fun delete(key: String) {
        prefs.edit().remove(key).apply()
    }
}
