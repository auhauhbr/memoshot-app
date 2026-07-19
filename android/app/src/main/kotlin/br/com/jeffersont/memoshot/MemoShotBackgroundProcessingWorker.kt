package br.com.jeffersont.memoshot

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

internal class MemoShotBackgroundProcessingWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : CoroutineWorker(appContext, workerParams) {
    private val scheduler = BackgroundProcessingScheduler(appContext)

    override suspend fun doWork(): Result {
        if (FlutterEngineRuntimeState.isUiEngineAttached()) return Result.success()

        var session: HeadlessEngineSession? = null
        return try {
            val createdSession = withTimeout(ENGINE_INITIALIZATION_TIMEOUT_MS) {
                createSession()
            }
            session = createdSession
            val terminal = withTimeout(DART_RESPONSE_TIMEOUT_MS) {
                createdSession.terminal.await()
            }
            mapResult(terminal)
        } catch (_: TimeoutCancellationException) {
            retryOrFailure("engineOrRunnerTimeout")
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            retryOrFailure("engineOrRunnerUnavailable")
        } finally {
            withContext(NonCancellable + Dispatchers.Main) {
                session?.dispose()
            }
        }
    }

    private suspend fun createSession(): HeadlessEngineSession =
        withContext(Dispatchers.Main) {
            val loader = FlutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)

            val engine = FlutterEngine(applicationContext, null, false)
            GeneratedPluginRegistrant.registerWith(engine)
            val inboxBridge = BackgroundScreenshotInboxBridge(
                applicationContext,
                engine.dartExecutor.binaryMessenger,
            )
            val preferencesBridge = AppPreferencesBridge(
                applicationContext,
                engine.dartExecutor.binaryMessenger,
            )
            val notificationBridge = ReviewNotificationBridge(
                applicationContext,
                engine.dartExecutor.binaryMessenger,
            )
            val mediaStoreContentBridge = MediaStoreContentBridge(
                applicationContext,
                engine.dartExecutor.binaryMessenger,
            )
            val mediaStoreOcrInputBridge = MediaStoreOcrInputBridge(
                applicationContext,
                engine.dartExecutor.binaryMessenger,
            )
            val localVisualAnalyzerBridge = LocalVisualAnalyzerBridge(
                applicationContext,
                engine.dartExecutor.binaryMessenger,
            )
            val terminal = CompletableDeferred<HeadlessTerminalMessage>()
            val channel = MethodChannel(
                engine.dartExecutor.binaryMessenger,
                BACKGROUND_PROCESSING_CHANNEL,
            )
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> result.success(null)
                    "completed", "retryableFailure", "terminalFailure", "cancelled" -> {
                        val payload = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        terminal.complete(
                            HeadlessTerminalMessage(
                                method = call.method,
                                pendingImmediateWork =
                                    (payload["pendingImmediateWork"] as? Number)?.toInt() == 1,
                                resultCode = payload["resultCode"] as? String ?: "unknown",
                                nextHistoricalRunAtMillis =
                                    (payload["nextHistoricalRunAtMillis"] as? Number)?.toLong(),
                            ),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    DART_ENTRYPOINT,
                ),
            )
            HeadlessEngineSession(
                engine,
                inboxBridge,
                notificationBridge,
                mediaStoreContentBridge,
                mediaStoreOcrInputBridge,
                localVisualAnalyzerBridge,
                preferencesBridge,
                channel,
                terminal,
            )
        }

    private fun mapResult(message: HeadlessTerminalMessage): Result {
        if (message.pendingImmediateWork) {
            scheduler.enqueueHistoricalPreparation()
        } else if (message.nextHistoricalRunAtMillis != null) {
            scheduler.enqueueHistoricalPreparation(
                message.nextHistoricalRunAtMillis
                    .minus(System.currentTimeMillis())
                    .coerceAtLeast(0L),
            )
        }
        return when (message.method) {
            "completed" -> Result.success(
                Data.Builder().putString("resultCode", message.resultCode).build(),
            )
            "retryableFailure" -> retryOrFailure(message.resultCode)
            "terminalFailure" -> Result.failure(
                Data.Builder().putString("resultCode", message.resultCode).build(),
            )
            "cancelled" -> Result.success()
            else -> retryOrFailure("unknownResponse")
        }
    }

    private fun retryOrFailure(resultCode: String): Result {
        return if (runAttemptCount < MAX_WORK_MANAGER_ATTEMPTS) {
            Result.retry()
        } else {
            Result.failure(Data.Builder().putString("resultCode", resultCode).build())
        }
    }

    private data class HeadlessTerminalMessage(
        val method: String,
        val pendingImmediateWork: Boolean,
        val resultCode: String,
        val nextHistoricalRunAtMillis: Long?,
    )

    private class HeadlessEngineSession(
        private val engine: FlutterEngine,
        private val inboxBridge: BackgroundScreenshotInboxBridge,
        private val notificationBridge: ReviewNotificationBridge,
        private val mediaStoreContentBridge: MediaStoreContentBridge,
        private val mediaStoreOcrInputBridge: MediaStoreOcrInputBridge,
        private val localVisualAnalyzerBridge: LocalVisualAnalyzerBridge,
        private val preferencesBridge: AppPreferencesBridge,
        private val channel: MethodChannel,
        val terminal: CompletableDeferred<HeadlessTerminalMessage>,
    ) {
        fun dispose() {
            channel.setMethodCallHandler(null)
            inboxBridge.dispose()
            notificationBridge.dispose()
            mediaStoreContentBridge.dispose()
            mediaStoreOcrInputBridge.dispose()
            localVisualAnalyzerBridge.dispose()
            preferencesBridge.dispose()
            engine.destroy()
        }
    }

    companion object {
        private const val BACKGROUND_PROCESSING_CHANNEL =
            "br.com.jeffersont.memoshot/background_processing"
        private const val DART_ENTRYPOINT = "memoshotBackgroundEntrypoint"
        private const val ENGINE_INITIALIZATION_TIMEOUT_MS = 30_000L
        private const val DART_RESPONSE_TIMEOUT_MS = 9L * 60 * 1000
        private const val MAX_WORK_MANAGER_ATTEMPTS = 3
    }
}
