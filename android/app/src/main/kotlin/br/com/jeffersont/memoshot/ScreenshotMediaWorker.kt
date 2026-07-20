package br.com.jeffersont.memoshot

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters

internal class ScreenshotMediaWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    private val state = NativeScreenshotMonitorState(appContext)
    private val scheduler = ScreenshotBackgroundScheduler(appContext)
    private val processingScheduler = BackgroundProcessingScheduler(appContext)
    private val inbox = BackgroundScreenshotInbox(appContext)
    private val foregroundAppBridge = ForegroundAppAtCaptureBridge(appContext)

    override fun doWork(): Result {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || !state.isEnabled()) {
            return Result.success()
        }
        if (!hasFullImageAccess()) {
            state.disable()
            return Result.success()
        }
        return try {
            val transientFailure = collectNewScreenshots()
            scheduleProcessingSafely()
            if (transientFailure && runAttemptCount < MAX_TRANSIENT_ATTEMPTS) {
                Result.retry()
            } else {
                rearmSafely()
                Result.success()
            }
        } catch (_: Exception) {
            scheduleProcessingSafely()
            if (runAttemptCount < MAX_TRANSIENT_ATTEMPTS) {
                Result.retry()
            } else {
                rearmSafely()
                Result.success()
            }
        }
    }

    private fun scheduleProcessingSafely() {
        try {
            if (inbox.pendingCount() > 0) processingScheduler.enqueueIfEnabled()
        } catch (_: Exception) {
            // O próximo gatilho de conteúdo ou abertura retomará a inbox.
        }
    }

    private fun rearmSafely() {
        try {
            scheduler.rearmFromWorker()
        } catch (_: Exception) {
            // Uma próxima abertura reconcilia o scheduler com o estado visível.
        }
    }

    private fun collectNewScreenshots(): Boolean {
        val initialMarker = state.marker()
        var safeMarker = initialMarker
        var unresolvedItemFound = false
        var transientFailure = false
        val projection = mutableListOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.MIME_TYPE,
            MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.DATE_TAKEN,
        ).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(MediaStore.Images.Media.RELATIVE_PATH)
                add(MediaStore.Images.Media.IS_PENDING)
            }
        }.toTypedArray()
        applicationContext.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            "${MediaStore.Images.Media._ID} > ?",
            arrayOf(initialMarker.toString()),
            "${MediaStore.Images.Media._ID} ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
            val addedIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
            val takenIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_TAKEN)
            val pathIndex = cursor.getColumnIndex(MediaStore.Images.Media.RELATIVE_PATH)
            val pendingIndex = cursor.getColumnIndex(MediaStore.Images.Media.IS_PENDING)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idIndex)
                val isPending = pendingIndex >= 0 && cursor.getInt(pendingIndex) != 0
                if (isPending) {
                    unresolvedItemFound = true
                    transientFailure = true
                    continue
                }
                val mimeType = cursor.getString(mimeIndex)
                val displayName = cursor.getString(nameIndex).orEmpty()
                val relativePath = if (pathIndex >= 0) cursor.getString(pathIndex).orEmpty() else ""
                val isScreenshot = ScreenshotRecognition.isScreenshot(
                    mimeType,
                    relativePath,
                    null,
                    displayName,
                )
                var examined = true
                if (isScreenshot && !inbox.containsMediaId(id)) {
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        id,
                    )
                    val capturedAt = MediaStoreCaptureTime.resolve(
                        cursor.getLong(takenIndex),
                        cursor.getLong(addedIndex),
                    )
                    val captureAppContext = capturedAt?.let {
                        foregroundAppBridge.findForegroundAppAt(it)
                    }
                    examined = try {
                        applicationContext.contentResolver.openInputStream(uri)?.use { input ->
                            inbox.write(id, mimeType, capturedAt, captureAppContext, input) != null
                        } ?: false
                    } catch (_: Exception) {
                        false
                    }
                }
                if (!examined) {
                    if (runAttemptCount >= MAX_TRANSIENT_ATTEMPTS) {
                        examined = true
                    } else {
                        unresolvedItemFound = true
                        transientFailure = true
                    }
                }
                if (examined && !unresolvedItemFound) {
                    safeMarker = id
                }
            }
        }
        state.advanceMarker(safeMarker)
        return transientFailure
    }

    private fun hasFullImageAccess(): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return ContextCompat.checkSelfPermission(
            applicationContext,
            permission,
        ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        private const val MAX_TRANSIENT_ATTEMPTS = 3
    }
}
