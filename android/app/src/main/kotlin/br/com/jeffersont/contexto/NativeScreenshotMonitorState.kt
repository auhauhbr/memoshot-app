package br.com.jeffersont.contexto

import android.content.Context

internal class NativeScreenshotMonitorState(context: Context) {
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    fun isEnabled(): Boolean = preferences.getBoolean(KEY_ENABLED, false)

    fun marker(): Long = preferences.getLong(KEY_MARKER, 0L)

    fun enable(marker: Long) {
        synchronized(lock) {
            preferences.edit()
                .putBoolean(KEY_ENABLED, true)
                .putLong(KEY_MARKER, maxOf(marker(), marker))
                .putInt(KEY_SCHEDULER_VERSION, SCHEDULER_VERSION)
                .apply()
        }
    }

    fun disable() {
        synchronized(lock) {
            preferences.edit().putBoolean(KEY_ENABLED, false).apply()
        }
    }

    fun advanceMarker(candidate: Long): Long {
        synchronized(lock) {
            val next = maxOf(marker(), candidate)
            preferences.edit().putLong(KEY_MARKER, next).apply()
            return next
        }
    }

    companion object {
        internal val lock = Any()
        private const val PREFERENCES = "automatic_screenshot_monitor"
        private const val KEY_ENABLED = "monitor_enabled"
        private const val KEY_MARKER = "last_examined_media_id"
        private const val KEY_SCHEDULER_VERSION = "scheduler_version"
        private const val SCHEDULER_VERSION = 1
    }
}
