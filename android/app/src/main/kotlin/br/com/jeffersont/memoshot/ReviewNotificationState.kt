package br.com.jeffersont.memoshot

import android.content.Context

internal class ReviewNotificationState(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES,
        Context.MODE_PRIVATE,
    )

    fun isEnabled(): Boolean = preferences.getBoolean(KEY_ENABLED, false)

    fun setEnabled(enabled: Boolean) {
        preferences.edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun isPromptHandled(): Boolean = preferences.getBoolean(KEY_PROMPT_HANDLED, false)

    fun markPromptHandled() {
        preferences.edit().putBoolean(KEY_PROMPT_HANDLED, true).apply()
    }

    fun lastCount(): Int = preferences.getInt(KEY_LAST_COUNT, 0)

    fun lastMarker(): String? = preferences.getString(KEY_LAST_MARKER, null)

    fun currentCount(): Int = preferences.getInt(KEY_CURRENT_COUNT, 0)

    fun currentMarker(): String? = preferences.getString(KEY_CURRENT_MARKER, null)

    fun storeCurrent(count: Int, marker: String) {
        preferences.edit()
            .putInt(KEY_CURRENT_COUNT, count)
            .putString(KEY_CURRENT_MARKER, marker)
            .apply()
    }

    fun storeNotified(count: Int, marker: String) {
        preferences.edit()
            .putInt(KEY_LAST_COUNT, count)
            .putString(KEY_LAST_MARKER, marker)
            .putInt(KEY_CURRENT_COUNT, count)
            .putString(KEY_CURRENT_MARKER, marker)
            .apply()
    }

    fun clearQueueMarkers() {
        preferences.edit()
            .remove(KEY_LAST_COUNT)
            .remove(KEY_LAST_MARKER)
            .remove(KEY_CURRENT_COUNT)
            .remove(KEY_CURRENT_MARKER)
            .apply()
    }

    companion object {
        private const val PREFERENCES = "memoshot_review_notifications"
        private const val KEY_ENABLED = "review_notifications_enabled"
        private const val KEY_PROMPT_HANDLED = "review_notification_prompt_handled"
        private const val KEY_LAST_COUNT = "last_notified_pending_count"
        private const val KEY_LAST_MARKER = "last_notified_pending_marker"
        private const val KEY_CURRENT_COUNT = "current_pending_count"
        private const val KEY_CURRENT_MARKER = "current_pending_marker"
    }
}
