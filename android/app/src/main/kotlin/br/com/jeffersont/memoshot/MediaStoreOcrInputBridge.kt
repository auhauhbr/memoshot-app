package br.com.jeffersont.memoshot

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal class MediaStoreOcrInputBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val applicationContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val registry = MediaStoreOcrTemporaryRegistry()
    private val closed = AtomicBoolean(false)
    private val directory = File(applicationContext.cacheDir, MediaStoreOcrInputPolicy.DIRECTORY_NAME)

    init {
        channel.setMethodCallHandler(this)
        executor.execute { cleanupIgnoringFailures() }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> prepare(call, result)
            "release" -> release(call, result)
            else -> result.notImplemented()
        }
    }

    private fun prepare(call: MethodCall, result: MethodChannel.Result) {
        if (closed.get()) {
            result.error(REFERENCED_SOURCE_TEMPORARY_FAILURE, null, null)
            return
        }
        val volumeName = call.argument<String>("volumeName").orEmpty()
        val mediaStoreId = call.argument<Number>("mediaStoreId")?.toLong() ?: -1L
        val canonical = MediaStoreReferencePolicy.canonicalUri(volumeName, mediaStoreId)
        if (canonical == null) {
            result.error(REFERENCED_SOURCE_INVALID, null, null)
            return
        }
        executor.execute {
            cleanupIgnoringFailures()
            val prepared = prepare(Uri.parse(canonical))
            mainHandler.post {
                if (closed.get()) return@post
                prepared.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error(controlledCode(it), null, null) },
                )
            }
        }
    }

    private fun prepare(uri: Uri): Result<Map<String, String>> = runCatching {
        val resolver = applicationContext.contentResolver
        val extension = MediaStoreOcrInputPolicy.extensionForMime(resolver.getType(uri))
            ?: throw UnsupportedReferencedMimeTypeException()
        if (!directory.exists() && !directory.mkdirs()) throw TemporaryFileException()
        val token = MediaStoreOcrInputPolicy.newToken()
        val temporary = MediaStoreOcrInputPolicy.temporaryFile(directory, token, extension)
            ?: throw TemporaryFileException()
        try {
            val input = resolver.openInputStream(uri) ?: throw FileNotFoundException()
            input.use { source ->
                MediaStoreOcrInputPolicy.copyToTemporary(source, temporary)
            }
            if (closed.get()) {
                temporary.delete()
                throw TemporaryFileException()
            }
            registry.register(token, temporary)
            mapOf("token" to token, "localPath" to temporary.absolutePath)
        } catch (error: Exception) {
            temporary.delete()
            throw error
        }
    }

    private fun release(call: MethodCall, result: MethodChannel.Result) {
        val token = call.argument<String>("token").orEmpty()
        if (!MediaStoreOcrInputPolicy.isOpaqueToken(token)) {
            result.success(null)
            return
        }
        executor.execute {
            registry.release(token)
            mainHandler.post { result.success(null) }
        }
    }

    private fun controlledCode(error: Throwable): String = when (error) {
        is SecurityException -> REFERENCED_SOURCE_PERMISSION_DENIED
        is FileNotFoundException -> REFERENCED_SOURCE_UNAVAILABLE
        is MediaStoreOcrSourceTooLargeException -> REFERENCED_SOURCE_TOO_LARGE
        is UnsupportedReferencedMimeTypeException -> UNSUPPORTED_REFERENCED_MIME_TYPE
        is TemporaryFileException, is MediaStoreOcrTemporaryFileException -> TEMPORARY_FILE_FAILURE
        is IOException -> REFERENCED_SOURCE_TEMPORARY_FAILURE
        else -> REFERENCED_SOURCE_TEMPORARY_FAILURE
    }

    private fun cleanupIgnoringFailures() {
        try {
            if (!directory.exists()) directory.mkdirs()
            MediaStoreOcrInputPolicy.cleanupAbandoned(directory, registry.activeTokens)
        } catch (_: Exception) {
            // Limpeza auxiliar nunca impede uma preparação posterior.
        }
    }

    fun dispose() {
        if (!closed.compareAndSet(false, true)) return
        channel.setMethodCallHandler(null)
        registry.releaseAll()
        executor.shutdownNow()
    }

    private class UnsupportedReferencedMimeTypeException : Exception()
    private class TemporaryFileException : Exception()

    companion object {
        const val CHANNEL = "br.com.jeffersont.memoshot/media_store_ocr_input"
        private const val REFERENCED_SOURCE_UNAVAILABLE = "referencedSourceUnavailable"
        private const val REFERENCED_SOURCE_PERMISSION_DENIED = "referencedSourcePermissionDenied"
        private const val REFERENCED_SOURCE_TOO_LARGE = "referencedSourceTooLarge"
        private const val REFERENCED_SOURCE_INVALID = "referencedSourceInvalid"
        private const val REFERENCED_SOURCE_TEMPORARY_FAILURE = "referencedSourceTemporaryFailure"
        private const val TEMPORARY_FILE_FAILURE = "temporaryFileFailure"
        private const val UNSUPPORTED_REFERENCED_MIME_TYPE = "unsupportedReferencedMimeType"
    }
}
