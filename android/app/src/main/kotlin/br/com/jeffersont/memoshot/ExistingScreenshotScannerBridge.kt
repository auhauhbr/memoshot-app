package br.com.jeffersont.memoshot

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference

internal class ExistingScreenshotScannerBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val applicationContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val activeSession = AtomicReference<String?>(null)
    private val cancelRequestedSession = AtomicReference<String?>(null)
    private val cancellationSignal = AtomicReference<CancellationSignal?>(null)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "beginScan" -> {
                val sessionId = UUID.randomUUID().toString()
                activeSession.set(sessionId)
                cancelRequestedSession.set(null)
                cancellationSignal.getAndSet(null)?.cancel()
                result.success(mapOf("sessionId" to sessionId))
            }
            "scanPage" -> {
                val sessionId = call.argument<String>("sessionId").orEmpty()
                val cursor = decodeCursor(call.argument<Map<String, Any?>>("cursor"))
                scanPage(sessionId, cursor, result)
            }
            "cancelScan" -> {
                cancelRequestedSession.set(activeSession.get())
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun scanPage(
        sessionId: String,
        cursor: ExistingScreenshotScanCursor?,
        result: MethodChannel.Result,
    ) {
        if (sessionId.isEmpty() || activeSession.get() != sessionId) {
            result.error("scan_cancelled", "Mapeamento cancelado.", null)
            return
        }
        if (cancelRequestedSession.get() == sessionId) {
            result.error("scan_cancelled", "Mapeamento cancelado.", null)
            return
        }
        executor.execute {
            val signal = CancellationSignal()
            cancellationSignal.set(signal)
            try {
                val page = queryPage(sessionId, cursor, signal)
                mainHandler.post { result.success(page) }
            } catch (_: Exception) {
                if (activeSession.get() != sessionId || signal.isCanceled) {
                    mainHandler.post {
                        result.error("scan_cancelled", "Mapeamento cancelado.", null)
                    }
                } else {
                    mainHandler.post {
                        result.error(
                            "media_store_unavailable",
                            "Mapeamento indisponível.",
                            null,
                        )
                    }
                }
            } finally {
                cancellationSignal.compareAndSet(signal, null)
            }
        }
    }

    private fun queryPage(
        sessionId: String,
        cursor: ExistingScreenshotScanCursor?,
        signal: CancellationSignal,
    ): Map<String, Any?> {
        val volumes = availableVolumes()
        var examined = 0
        val candidates = mutableListOf<Map<String, Any?>>()
        var nextCursor: ExistingScreenshotScanCursor? = null
        var hasNext = false

        for (volumeName in ExistingScreenshotScanPolicy.volumesAfter(volumes, cursor)) {
            ensureActive(sessionId, signal)
            val startId = ExistingScreenshotScanPolicy.startId(volumeName, cursor)
            val uri = imagesUri(volumeName)
            query(uri, startId, signal)?.use { mediaCursor ->
                val indexes = ColumnIndexes(mediaCursor)
                while (mediaCursor.moveToNext()) {
                    ensureActive(sessionId, signal)
                    val id = mediaCursor.getLong(indexes.id)
                    if (examined == ExistingScreenshotScanPolicy.PAGE_SIZE) {
                        hasNext = true
                        break
                    }
                    examined++
                    nextCursor = ExistingScreenshotScanCursor(volumeName, id)
                    if (indexes.pending >= 0 && mediaCursor.getInt(indexes.pending) != 0) continue
                    val mimeType = mediaCursor.stringOrNull(indexes.mimeType)
                    val displayName = mediaCursor.stringOrNull(indexes.displayName)
                    val relativePath = mediaCursor.stringOrNull(indexes.relativePath)
                    val bucket = mediaCursor.stringOrNull(indexes.bucketDisplayName)
                    if (!ScreenshotRecognition.isScreenshot(
                            mimeType,
                            relativePath,
                            bucket,
                            displayName,
                        )
                    ) continue
                    candidates += candidatePayload(
                        uri = uri,
                        volumeName = volumeName,
                        id = id,
                        mimeType = mimeType,
                        cursor = mediaCursor,
                        indexes = indexes,
                    )
                }
            }
            if (hasNext || examined == ExistingScreenshotScanPolicy.PAGE_SIZE) {
                hasNext = true
                break
            }
            nextCursor = ExistingScreenshotScanCursor(volumeName, Long.MAX_VALUE)
        }

        val lastVolume = nextCursor?.volumeName
        if (!hasNext && lastVolume != null) {
            hasNext = volumes.sorted().any { it > lastVolume }
        }
        return mapOf(
            "examinedCount" to examined,
            "recognizedCount" to candidates.size,
            "hasNext" to hasNext,
            "nextCursor" to nextCursor?.let(::cursorPayload),
            "items" to candidates,
        )
    }

    private fun query(
        uri: Uri,
        afterId: Long,
        signal: CancellationSignal,
    ): Cursor? {
        val resolver = applicationContext.contentResolver
        val selection = "${MediaStore.Images.Media._ID} > ?"
        val args = arrayOf(afterId.toString())
        val limit = ExistingScreenshotScanPolicy.PAGE_SIZE + 1
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val queryArgs = Bundle().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                putStringArray(
                    ContentResolver.QUERY_ARG_SORT_COLUMNS,
                    arrayOf(MediaStore.Images.Media._ID),
                )
                putInt(
                    ContentResolver.QUERY_ARG_SORT_DIRECTION,
                    ContentResolver.QUERY_SORT_DIRECTION_ASCENDING,
                )
                putInt(ContentResolver.QUERY_ARG_LIMIT, limit)
            }
            resolver.query(uri, projection(), queryArgs, signal)
        } else {
            @Suppress("DEPRECATION")
            resolver.query(
                uri,
                projection(),
                selection,
                args,
                "${MediaStore.Images.Media._ID} ASC LIMIT $limit",
            )
        }
    }

    private fun projection(): Array<String> = mutableListOf(
        MediaStore.Images.Media._ID,
        MediaStore.Images.Media.DISPLAY_NAME,
        MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
        MediaStore.Images.Media.MIME_TYPE,
        MediaStore.Images.Media.DATE_ADDED,
        MediaStore.Images.Media.DATE_TAKEN,
        MediaStore.Images.Media.DATE_MODIFIED,
        MediaStore.Images.Media.SIZE,
        MediaStore.Images.Media.WIDTH,
        MediaStore.Images.Media.HEIGHT,
    ).apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            add(MediaStore.Images.Media.RELATIVE_PATH)
            add(MediaStore.Images.Media.IS_PENDING)
        }
    }.toTypedArray()

    private fun candidatePayload(
        uri: Uri,
        volumeName: String,
        id: Long,
        mimeType: String?,
        cursor: Cursor,
        indexes: ColumnIndexes,
    ): Map<String, Any?> = mapOf(
        "sourceKey" to ExistingScreenshotScanPolicy.sourceKey(volumeName, id),
        "mediaStoreId" to id,
        "volumeName" to volumeName,
        "contentUri" to ContentUris.withAppendedId(uri, id).toString(),
        "mimeType" to mimeType,
        "capturedAt" to MediaStoreCaptureTime.resolve(
            cursor.longOrZero(indexes.dateTaken),
            cursor.longOrZero(indexes.dateAdded),
        ),
        "dateModified" to secondsToMilliseconds(cursor.longOrZero(indexes.dateModified)),
        "sizeBytes" to cursor.longOrNull(indexes.size),
        "width" to cursor.intOrNull(indexes.width),
        "height" to cursor.intOrNull(indexes.height),
    )

    private fun availableVolumes(): Set<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.getExternalVolumeNames(applicationContext)
        } else {
            setOf("external")
        }

    private fun imagesUri(volumeName: String): Uri =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(volumeName)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

    private fun decodeCursor(value: Map<String, Any?>?): ExistingScreenshotScanCursor? {
        val volume = value?.get("volumeName") as? String ?: return null
        val id = (value["mediaStoreId"] as? Number)?.toLong() ?: return null
        return ExistingScreenshotScanCursor(volume, id)
    }

    private fun cursorPayload(cursor: ExistingScreenshotScanCursor): Map<String, Any> = mapOf(
        "volumeName" to cursor.volumeName,
        "mediaStoreId" to cursor.mediaStoreId,
    )

    private fun ensureActive(sessionId: String, signal: CancellationSignal) {
        if (activeSession.get() != sessionId || signal.isCanceled) {
            throw IllegalStateException("scan_cancelled")
        }
    }

    private fun secondsToMilliseconds(value: Long): Long? =
        if (value <= 0 || value > Long.MAX_VALUE / 1000L) null else value * 1000L

    fun dispose() {
        activeSession.set(null)
        cancelRequestedSession.set(null)
        cancellationSignal.getAndSet(null)?.cancel()
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
    }

    private class ColumnIndexes(cursor: Cursor) {
        val id = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
        val displayName = cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
        val bucketDisplayName = cursor.getColumnIndex(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
        val mimeType = cursor.getColumnIndex(MediaStore.Images.Media.MIME_TYPE)
        val dateAdded = cursor.getColumnIndex(MediaStore.Images.Media.DATE_ADDED)
        val dateTaken = cursor.getColumnIndex(MediaStore.Images.Media.DATE_TAKEN)
        val dateModified = cursor.getColumnIndex(MediaStore.Images.Media.DATE_MODIFIED)
        val size = cursor.getColumnIndex(MediaStore.Images.Media.SIZE)
        val width = cursor.getColumnIndex(MediaStore.Images.Media.WIDTH)
        val height = cursor.getColumnIndex(MediaStore.Images.Media.HEIGHT)
        val relativePath = cursor.getColumnIndex(MediaStore.Images.Media.RELATIVE_PATH)
        val pending = cursor.getColumnIndex(MediaStore.Images.Media.IS_PENDING)
    }

    companion object {
        const val CHANNEL = "br.com.jeffersont.memoshot/existing_screenshot_inventory"
    }
}

private fun Cursor.stringOrNull(index: Int): String? =
    if (index < 0 || isNull(index)) null else getString(index)

private fun Cursor.longOrZero(index: Int): Long =
    if (index < 0 || isNull(index)) 0L else getLong(index)

private fun Cursor.longOrNull(index: Int): Long? =
    if (index < 0 || isNull(index)) null else getLong(index)

private fun Cursor.intOrNull(index: Int): Int? =
    if (index < 0 || isNull(index)) null else getInt(index)
