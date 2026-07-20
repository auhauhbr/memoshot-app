package br.com.jeffersont.memoshot

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

internal const val AUTOMATIC_SCREENSHOTS_METHODS_CHANNEL =
    "br.com.jeffersont.memoshot/automatic_screenshots/methods"

internal class BackgroundScreenshotInboxHandler(context: Context) {
    private val inbox = BackgroundScreenshotInbox(context.applicationContext)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "listBackgroundInbox" -> runInBackground(result) {
                inbox.listEntries().map { entry ->
                    mapOf(
                        "entryId" to entry.entryId,
                        "mediaId" to entry.mediaStoreId,
                        "privatePath" to entry.imagePath,
                        "mimeType" to entry.mimeType,
                        "capturedAt" to entry.capturedAt,
                        "captureAppContext" to entry.captureAppContext?.let { context ->
                            mapOf(
                                "packageName" to context.packageName,
                                "normalizedAppKey" to context.normalizedAppKey,
                                "eventTimestamp" to context.eventTimestamp,
                                "captureTimestamp" to context.captureTimestamp,
                                "deltaMilliseconds" to context.deltaMilliseconds,
                                "confidenceLevel" to context.confidenceLevel,
                            )
                        },
                    )
                }
            }
            "backgroundInboxPendingCount" -> runInBackground(result) {
                inbox.pendingCount()
            }
            "acknowledgeBackgroundInbox", "rejectBackgroundInbox" -> {
                val entryId = call.argument<String>("entryId").orEmpty()
                runInBackground(result) { inbox.remove(entryId) }
            }
            else -> return false
        }
        return true
    }

    private fun runInBackground(result: MethodChannel.Result, block: () -> Any) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (_: Exception) {
                mainHandler.post {
                    result.error("inbox_unavailable", "Inbox indisponível.", null)
                }
            }
        }
    }

    fun dispose() {
        executor.shutdownNow()
    }
}

internal class BackgroundScreenshotInboxBridge(
    context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, AUTOMATIC_SCREENSHOTS_METHODS_CHANNEL)
    private val handler = BackgroundScreenshotInboxHandler(context)

    init {
        channel.setMethodCallHandler { call, result ->
            if (!handler.handle(call, result)) result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        handler.dispose()
    }
}
