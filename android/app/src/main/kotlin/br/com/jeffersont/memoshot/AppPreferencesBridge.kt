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
        private const val HISTORICAL_NOT_STARTED = "notStarted"
        private val HISTORICAL_STATES =
            setOf("notStarted", "active", "paused", "completed")

        fun isHistoricalPreparationActive(context: Context): Boolean =
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .getString(KEY_HISTORICAL_PREPARATION_STATE, HISTORICAL_NOT_STARTED) ==
                "active"
    }
}
