package dev.brewkits.native_workmanager.engine

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

object TaskEventBus {
    data class Event(
        val taskId: String,
        val taskName: String,
        val success: Boolean,
        val message: String?,
        val outputData: String?
    )

    private val _events = MutableSharedFlow<Event>(replay = 0, extraBufferCapacity = 64)
    val events: SharedFlow<Event> = _events.asSharedFlow()

    suspend fun emit(event: Event) {
        _events.emit(event)
    }
}
