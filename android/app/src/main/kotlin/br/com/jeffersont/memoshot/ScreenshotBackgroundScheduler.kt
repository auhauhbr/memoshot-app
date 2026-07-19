package br.com.jeffersont.memoshot

import android.content.Context
import android.os.Build
import android.provider.MediaStore
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.WorkRequest
import java.util.concurrent.TimeUnit

internal class ScreenshotBackgroundScheduler(private val context: Context) {
    private val state = NativeScreenshotMonitorState(context)
    private val workManager = WorkManager.getInstance(context)
    private val processingScheduler = BackgroundProcessingScheduler(context)
    private val inbox = BackgroundScreenshotInbox(context)

    fun activate(baseline: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        synchronized(NativeScreenshotMonitorState.lock) {
            state.enable(baseline)
            workManager.enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request(),
            )
            processingScheduler.enqueueIfEnabled()
        }
        return true
    }

    fun reconcile(marker: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        synchronized(NativeScreenshotMonitorState.lock) {
            state.enable(marker)
            workManager.enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.KEEP,
                request(),
            )
            if (inbox.pendingCount() > 0) processingScheduler.enqueueIfEnabled()
        }
        return true
    }

    fun cancel() {
        synchronized(NativeScreenshotMonitorState.lock) {
            state.disable()
            workManager.cancelUniqueWork(UNIQUE_WORK_NAME)
            processingScheduler.cancel()
        }
    }

    fun rearmFromWorker() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        synchronized(NativeScreenshotMonitorState.lock) {
            if (!state.isEnabled()) return
            workManager.enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.APPEND_OR_REPLACE,
                request(),
            )
        }
    }

    fun isAvailable(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

    private fun request(): OneTimeWorkRequest {
        val constraints = Constraints.Builder()
            .addContentUriTrigger(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true)
            .setTriggerContentUpdateDelay(CONTENT_UPDATE_DELAY_SECONDS, TimeUnit.SECONDS)
            .setTriggerContentMaxDelay(CONTENT_MAX_DELAY_SECONDS, TimeUnit.SECONDS)
            .build()
        return OneTimeWorkRequest.Builder(ScreenshotMediaWorker::class.java)
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                WorkRequest.MIN_BACKOFF_MILLIS,
                TimeUnit.MILLISECONDS,
            )
            .build()
    }

    companion object {
        private const val UNIQUE_WORK_NAME = "contexto_screenshot_media_monitor"
        private const val CONTENT_UPDATE_DELAY_SECONDS = 2L
        private const val CONTENT_MAX_DELAY_SECONDS = 12L
    }
}
