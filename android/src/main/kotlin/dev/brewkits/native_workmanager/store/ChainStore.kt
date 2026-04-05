package dev.brewkits.native_workmanager.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject

/**
 * Lightweight SQLite-backed store for chain state on Android.
 *
 * Mirrors iOS ChainStateManager — persists chain metadata and per-step results
 * so that:
 *  1. Chain progress survives app kills (WorkManager already persists worker
 *     enqueues; this layer adds Dart-visible chain metadata on top).
 *  2. Step results can be queried from Dart via allTasks() or chain-specific queries.
 *  3. Data can flow from step N's output into step N+1's input (stored as JSON).
 *
 * Schema:
 *   chains      (chain_id, chain_name, status, total_steps, current_step, created_at, updated_at)
 *   chain_steps (chain_id, step_index, task_id, status, result_json, updated_at)
 */
internal class ChainStore(context: Context) {

    data class ChainRecord(
        val chainId: String,
        val chainName: String?,
        val status: String,          // pending | running | completed | failed | cancelled
        val totalSteps: Int,
        val currentStep: Int,        // 0-based index of the step currently executing
        val createdAt: Long,
        val updatedAt: Long,
    )

    data class ChainStepRecord(
        val chainId: String,
        val stepIndex: Int,
        val taskId: String,
        val status: String,          // pending | running | completed | failed
        val resultJson: String?,     // output from this step (passed to next step as input)
        val updatedAt: Long,
    )

    private val dbHelper = DatabaseHelper.getInstance(context)

    // ─── Write ────────────────────────────────────────────────────────────────

    fun upsertChain(
        chainId: String,
        chainName: String?,
        totalSteps: Int,
        status: String = "pending",
    ) {
        val now = System.currentTimeMillis()
        val db = dbHelper.writableDatabase
        val cv = ContentValues().apply {
            put("chain_id", chainId)
            put("chain_name", chainName)
            put("status", status)
            put("total_steps", totalSteps)
            put("current_step", 0)
            put("created_at", now)
            put("updated_at", now)
        }
        db.insertWithOnConflict("chains", null, cv, SQLiteDatabase.CONFLICT_IGNORE)
        val updateCv = ContentValues().apply {
            put("status", status)
            put("updated_at", now)
        }
        db.update("chains", updateCv, "chain_id = ?", arrayOf(chainId))
    }

    fun addChainStep(chainId: String, stepIndex: Int, taskId: String, status: String = "pending") {
        val now = System.currentTimeMillis()
        val cv = ContentValues().apply {
            put("chain_id", chainId)
            put("step_index", stepIndex)
            put("task_id", taskId)
            put("status", status)
            put("updated_at", now)
        }
        dbHelper.writableDatabase.insertWithOnConflict("chain_steps", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun updateChainStatus(chainId: String, status: String, currentStep: Int? = null) {
        val cv = ContentValues().apply {
            put("status", status)
            put("updated_at", System.currentTimeMillis())
            if (currentStep != null) put("current_step", currentStep)
        }
        dbHelper.writableDatabase.update("chains", cv, "chain_id = ?", arrayOf(chainId))
    }

    fun updateStepStatus(chainId: String, taskId: String, status: String, resultJson: String? = null) {
        val cv = ContentValues().apply {
            put("status", status)
            put("updated_at", System.currentTimeMillis())
            if (resultJson != null) put("result_json", resultJson)
        }
        dbHelper.writableDatabase.update(
            "chain_steps", cv,
            "chain_id = ? AND task_id = ?",
            arrayOf(chainId, taskId)
        )
    }

    // ─── Read ─────────────────────────────────────────────────────────────────

    fun getChain(chainId: String): ChainRecord? =
        dbHelper.readableDatabase
            .rawQuery("SELECT * FROM chains WHERE chain_id = ?", arrayOf(chainId))
            .use { c -> if (c.moveToFirst()) c.toChainRecord() else null }

    fun getPendingChains(): List<ChainRecord> =
        dbHelper.readableDatabase
            .rawQuery("SELECT * FROM chains WHERE status IN ('pending','running') ORDER BY created_at ASC", null)
            .use { c ->
                val list = mutableListOf<ChainRecord>()
                while (c.moveToNext()) list.add(c.toChainRecord())
                list
            }

    fun getStepsForChain(chainId: String): List<ChainStepRecord> =
        dbHelper.readableDatabase
            .rawQuery(
                "SELECT * FROM chain_steps WHERE chain_id = ? ORDER BY step_index ASC",
                arrayOf(chainId)
            )
            .use { c ->
                val list = mutableListOf<ChainStepRecord>()
                while (c.moveToNext()) list.add(c.toStepRecord())
                list
            }

    /** Returns the result JSON from the last completed step before [stepIndex]. */
    fun getPreviousStepResult(chainId: String, beforeStepIndex: Int): String? =
        dbHelper.readableDatabase.rawQuery(
            """SELECT result_json FROM chain_steps
               WHERE chain_id = ? AND step_index < ? AND status = 'completed'
               ORDER BY step_index DESC LIMIT 1""",
            arrayOf(chainId, beforeStepIndex.toString())
        ).use { c -> if (c.moveToFirst()) c.getString(0) else null }

    /** Auto-prune completed/failed chains older than [olderThanMs] milliseconds. */
    fun deleteOldChains(olderThanMs: Long) {
        val threshold = System.currentTimeMillis() - olderThanMs
        val db = dbHelper.writableDatabase
        // Delete steps first (FK consistency), then headers
        db.delete(
            "chain_steps",
            "chain_id IN (SELECT chain_id FROM chains WHERE status IN ('completed','failed','cancelled') AND updated_at < ?)",
            arrayOf(threshold.toString())
        )
        db.delete(
            "chains",
            "status IN ('completed','failed','cancelled') AND updated_at < ?",
            arrayOf(threshold.toString())
        )
    }

    // ─── Cursor helpers ───────────────────────────────────────────────────────

    private fun android.database.Cursor.toChainRecord() = ChainRecord(
        chainId     = getString(getColumnIndexOrThrow("chain_id")),
        chainName   = getString(getColumnIndexOrThrow("chain_name")),
        status      = getString(getColumnIndexOrThrow("status")),
        totalSteps  = getInt(getColumnIndexOrThrow("total_steps")),
        currentStep = getInt(getColumnIndexOrThrow("current_step")),
        createdAt   = getLong(getColumnIndexOrThrow("created_at")),
        updatedAt   = getLong(getColumnIndexOrThrow("updated_at")),
    )

    private fun android.database.Cursor.toStepRecord() = ChainStepRecord(
        chainId    = getString(getColumnIndexOrThrow("chain_id")),
        stepIndex  = getInt(getColumnIndexOrThrow("step_index")),
        taskId     = getString(getColumnIndexOrThrow("task_id")),
        status     = getString(getColumnIndexOrThrow("status")),
        resultJson = getString(getColumnIndexOrThrow("result_json")),
        updatedAt  = getLong(getColumnIndexOrThrow("updated_at")),
    )
}
