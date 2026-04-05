package dev.brewkits.native_workmanager

import android.content.Context

object AppContextHolder {
    @Volatile
    lateinit var appContext: Context
}
