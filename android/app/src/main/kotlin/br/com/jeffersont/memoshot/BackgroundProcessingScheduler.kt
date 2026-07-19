package br.com.jeffersont.memoshot

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.WorkRequest
import java.util.concurrent.TimeUnit

internal class BackgroundProcessingScheduler(context: Context) {
    private val appContext = context.applicationContext
    private val state = NativeScreenshotMonitorState(appContext)
    private val workManager = WorkManager.getInstance(appContext)

    fun enqueueIfEnabled(): Boolean {
        if (!state.isEnabled()) return false
        enqueue()
        return true
    }

    fun enqueueHistoricalPreparation(delayMillis: Long = 0L) {
        enqueue(delayMillis)
    }

    private fun enqueue(delayMillis: Long = 0L) {
        workManager.enqueueUniqueWork(
            UNIQUE_WORK_NAME,
            ExistingWorkPolicy.APPEND_OR_REPLACE,
            request(delayMillis),
        )
    }

    fun cancel() {
        workManager.cancelUniqueWork(UNIQUE_WORK_NAME)
    }

    private fun request(delayMillis: Long): OneTimeWorkRequest =
        OneTimeWorkRequest.Builder(MemoShotBackgroundProcessingWorker::class.java)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                WorkRequest.MIN_BACKOFF_MILLIS,
                TimeUnit.MILLISECONDS,
            )
            .setInitialDelay(delayMillis.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
            .build()

    companion object {
        internal const val UNIQUE_WORK_NAME = "memoshot_background_processing"
    }
}
