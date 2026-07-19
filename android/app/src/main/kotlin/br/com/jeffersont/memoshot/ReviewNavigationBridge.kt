package br.com.jeffersont.memoshot

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class ReviewNavigationBridge(
    messenger: BinaryMessenger,
    initialIntent: Intent?,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private var pendingDestination: String? = destinationFrom(initialIntent)
    private var pendingIntent: Intent? = initialIntent.takeIf {
        pendingDestination != null
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "consumePendingDestination" -> {
                val value = pendingDestination
                pendingDestination = null
                pendingIntent?.removeExtra(ReviewNotificationBridge.EXTRA_DESTINATION)
                if (pendingIntent?.action == ReviewNotificationBridge.ACTION_OPEN_REVIEW_QUEUE) {
                    pendingIntent?.action = null
                }
                pendingIntent = null
                result.success(value)
            }
            else -> result.notImplemented()
        }
    }

    fun handleIntent(intent: Intent?) {
        val destination = destinationFrom(intent) ?: return
        pendingDestination = destination
        pendingIntent = intent
        channel.invokeMethod("destinationAvailable", null)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun destinationFrom(intent: Intent?): String? {
        if (intent?.action != ReviewNotificationBridge.ACTION_OPEN_REVIEW_QUEUE) return null
        val value = intent.getStringExtra(ReviewNotificationBridge.EXTRA_DESTINATION)
        return value?.takeIf(ReviewNotificationPolicy::acceptsDestination)
    }

    companion object {
        const val CHANNEL = "br.com.jeffersont.memoshot/review_navigation"
    }
}
