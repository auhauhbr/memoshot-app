package br.com.jeffersont.memoshot

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.FileNotFoundException
import java.util.concurrent.Executors

internal class MediaStoreContentBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val applicationContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkAvailability" -> withValidatedReference(call, result) { uri ->
                executor.execute {
                    deliver(result, availability(uri))
                }
            }
            "loadThumbnail" -> withValidatedReference(call, result) { uri ->
                executor.execute {
                    deliver(result, thumbnail(uri))
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun withValidatedReference(
        call: MethodCall,
        result: MethodChannel.Result,
        action: (Uri) -> Unit,
    ) {
        val volumeName = call.argument<String>("volumeName").orEmpty()
        val mediaStoreId = call.argument<Number>("mediaStoreId")?.toLong() ?: -1L
        val claimedUri = call.argument<String>("contentUri").orEmpty()
        val canonical = MediaStoreReferencePolicy.canonicalUri(volumeName, mediaStoreId)
        if (canonical == null || !MediaStoreReferencePolicy.isValid(
                volumeName,
                mediaStoreId,
                claimedUri,
            )
        ) {
            result.error("invalid_media_reference", "Referência de mídia inválida.", null)
            return
        }
        action(Uri.parse(canonical))
    }

    private fun availability(uri: Uri): Map<String, Any?> = try {
        applicationContext.contentResolver.openAssetFileDescriptor(uri, "r")?.use { }
            ?: return status("unavailable")
        status("available")
    } catch (_: SecurityException) {
        status("permissionDenied")
    } catch (_: FileNotFoundException) {
        status("unavailable")
    } catch (_: Exception) {
        status("temporaryFailure")
    }

    private fun thumbnail(uri: Uri): Map<String, Any?> {
        var bitmap: Bitmap? = null
        return try {
            bitmap = loadLimitedThumbnail(uri) ?: return status("unavailable")
            val bytes = compressLimited(bitmap)
                ?: return status("temporaryFailure")
            mapOf("status" to "available", "bytes" to bytes)
        } catch (_: SecurityException) {
            status("permissionDenied")
        } catch (_: FileNotFoundException) {
            status("unavailable")
        } catch (_: Exception) {
            status("temporaryFailure")
        } finally {
            bitmap?.recycle()
        }
    }

    @Suppress("DEPRECATION")
    private fun loadLimitedThumbnail(uri: Uri): Bitmap? {
        val resolver = applicationContext.contentResolver
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            resolver.loadThumbnail(
                uri,
                Size(
                    MediaStoreReferencePolicy.MAX_THUMBNAIL_DIMENSION,
                    MediaStoreReferencePolicy.MAX_THUMBNAIL_DIMENSION,
                ),
                CancellationSignal(),
            )
        } else {
            val id = uri.lastPathSegment?.toLongOrNull() ?: return null
            MediaStore.Images.Thumbnails.getThumbnail(
                resolver,
                id,
                MediaStore.Images.Thumbnails.MINI_KIND,
                null,
            )
        }
    }

    private fun compressLimited(source: Bitmap): ByteArray? {
        var current = source
        try {
            repeat(4) { scaleAttempt ->
                for (quality in 85 downTo 45 step 10) {
                    val output = ByteArrayOutputStream()
                    current.compress(Bitmap.CompressFormat.JPEG, quality, output)
                    val bytes = output.toByteArray()
                    if (bytes.size <= MediaStoreReferencePolicy.MAX_THUMBNAIL_PAYLOAD_BYTES) {
                        return bytes
                    }
                }
                if (scaleAttempt < 3) {
                    val scaled = Bitmap.createScaledBitmap(
                        current,
                        (current.width / 2).coerceAtLeast(1),
                        (current.height / 2).coerceAtLeast(1),
                        true,
                    )
                    if (current !== source) current.recycle()
                    current = scaled
                }
            }
            return null
        } finally {
            if (current !== source) current.recycle()
        }
    }

    private fun status(value: String): Map<String, Any?> = mapOf("status" to value)

    private fun deliver(result: MethodChannel.Result, payload: Map<String, Any?>) {
        mainHandler.post { result.success(payload) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
    }

    companion object {
        const val CHANNEL = "br.com.jeffersont.memoshot/media_store_content"
    }
}
