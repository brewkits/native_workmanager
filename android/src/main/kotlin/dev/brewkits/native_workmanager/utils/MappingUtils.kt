package dev.brewkits.native_workmanager.utils

import dev.brewkits.kmpworkmanager.background.domain.BackoffPolicy
import dev.brewkits.kmpworkmanager.background.domain.Constraints
import dev.brewkits.kmpworkmanager.background.domain.SystemConstraint
import org.json.JSONArray
import org.json.JSONObject

/**
 * Utility class for mapping between Dart/JSON and Native/Domain models.
 */
object MappingUtils {

    fun parseConstraints(map: Map<String, Any?>?): Constraints {
        if (map == null) return Constraints()

        val requiresNetwork = map["requiresNetwork"] as? Boolean ?: false
        val requiresUnmeteredNetwork = map["requiresUnmeteredNetwork"] as? Boolean ?: false
        val requiresCharging = map["requiresCharging"] as? Boolean ?: false
        val allowWhileIdle = map["allowWhileIdle"] as? Boolean ?: false
        val isHeavyTask = map["isHeavyTask"] as? Boolean ?: false
        val backoffDelayMs = (map["backoffDelayMs"] as? Number)?.toLong() ?: 30_000L

        val backoffPolicy = when ((map["backoffPolicy"] as? String)?.lowercase()) {
            "linear" -> BackoffPolicy.LINEAR
            else -> BackoffPolicy.EXPONENTIAL
        }

        val systemConstraintNames = map["systemConstraints"] as? List<*> ?: emptyList<Any>()
        val systemConstraints: MutableSet<SystemConstraint> = systemConstraintNames
            .filterIsInstance<String>()
            .mapNotNull { name ->
                when (name) {
                    "allowLowStorage" -> SystemConstraint.ALLOW_LOW_STORAGE
                    "allowLowBattery" -> SystemConstraint.ALLOW_LOW_BATTERY
                    "requireBatteryNotLow" -> SystemConstraint.REQUIRE_BATTERY_NOT_LOW
                    "deviceIdle" -> SystemConstraint.DEVICE_IDLE
                    else -> null
                }
            }.toMutableSet()

        if (map["requiresDeviceIdle"] as? Boolean == true) systemConstraints.add(SystemConstraint.DEVICE_IDLE)
        if (map["requiresBatteryNotLow"] as? Boolean == true) systemConstraints.add(SystemConstraint.REQUIRE_BATTERY_NOT_LOW)

        return Constraints(
            requiresNetwork = requiresNetwork,
            requiresUnmeteredNetwork = requiresUnmeteredNetwork,
            requiresCharging = requiresCharging,
            allowWhileIdle = allowWhileIdle,
            isHeavyTask = isHeavyTask,
            backoffPolicy = backoffPolicy,
            backoffDelayMs = backoffDelayMs,
            systemConstraints = systemConstraints
        )
    }

    /**
     * Recursively converts a value to a stable JSON string with sorted keys.
     * Fixed: Uses JSONObject/JSONArray instead of manual string building.
     */
    fun toJson(value: Any?): String {
        return wrapValue(value).toString()
    }

    private fun wrapValue(value: Any?): Any {
        return when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> {
                val json = JSONObject()
                // Sort keys for stable HMAC signatures
                value.keys.map { it.toString() }.sorted().forEach { key ->
                    json.put(key, wrapValue(value[key]))
                }
                json
            }
            is List<*> -> {
                val json = JSONArray()
                value.forEach { json.put(wrapValue(it)) }
                json
            }
            is Boolean, is Number, is String -> value
            else -> value.toString()
        }
    }
}
