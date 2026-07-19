package br.com.jeffersont.memoshot

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class AppPreferencesBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isOnboardingCompleted" -> result.success(
                preferences.getBoolean(KEY_ONBOARDING_COMPLETED, false),
            )
            "completeOnboarding" -> {
                preferences.edit().putBoolean(KEY_ONBOARDING_COMPLETED, true).apply()
                result.success(null)
            }
            "recentFolderIds" -> result.success(
                preferences.getStringSet(KEY_RECENT_FOLDER_IDS, emptySet())
                    .orEmpty()
                    .mapNotNull { value ->
                        val parts = value.split(RECENT_FOLDER_SEPARATOR, limit = 2)
                        if (parts.size != 2) null else {
                            val order = parts[0].toIntOrNull()
                            val id = parts[1].toIntOrNull()
                            if (order == null || id == null) null else order to id
                        }
                    }
                    .sortedBy { it.first }
                    .map { it.second },
            )
            "setRecentFolderIds" -> {
                val ids = call.argument<List<Int>>("ids").orEmpty()
                    .filter { it > 0 }
                    .distinct()
                    .take(MAXIMUM_RECENT_FOLDERS)
                val encoded = ids.mapIndexed { index, id ->
                    "$index$RECENT_FOLDER_SEPARATOR$id"
                }.toSet()
                preferences.edit().putStringSet(KEY_RECENT_FOLDER_IDS, encoded).apply()
                result.success(null)
            }
            "historicalPreparationState" -> result.success(
                preferences.getString(
                    KEY_HISTORICAL_PREPARATION_STATE,
                    HISTORICAL_NOT_STARTED,
                ),
            )
            "setHistoricalPreparationState" -> {
                val state = call.argument<String>("state")
                if (state !in HISTORICAL_STATES) {
                    result.error("invalid_state", "Estado técnico inválido.", null)
                    return
                }
                preferences.edit()
                    .putString(KEY_HISTORICAL_PREPARATION_STATE, state)
                    .apply()
                result.success(null)
            }
            "scheduleHistoricalPreparation" -> {
                BackgroundProcessingScheduler(context).enqueueHistoricalPreparation()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val CHANNEL = "br.com.jeffersont.memoshot/preferences"
        private const val PREFERENCES = "memoshot_preferences"
        private const val KEY_ONBOARDING_COMPLETED = "onboarding_completed"
        private const val KEY_HISTORICAL_PREPARATION_STATE =
            "historical_preparation_state"
        private const val KEY_RECENT_FOLDER_IDS = "recent_folder_ids"
        private const val RECENT_FOLDER_SEPARATOR = ":"
        private const val MAXIMUM_RECENT_FOLDERS = 6
        private const val HISTORICAL_NOT_STARTED = "notStarted"
        private val HISTORICAL_STATES =
            setOf("notStarted", "active", "paused", "completed")

        fun isHistoricalPreparationActive(context: Context): Boolean =
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .getString(KEY_HISTORICAL_PREPARATION_STATE, HISTORICAL_NOT_STARTED) ==
                "active"
    }
}
