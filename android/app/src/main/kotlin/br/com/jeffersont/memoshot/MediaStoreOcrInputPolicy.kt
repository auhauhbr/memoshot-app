package br.com.jeffersont.memoshot

import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

internal object MediaStoreOcrInputPolicy {
    const val DIRECTORY_NAME = "memoshot_ocr"
    const val MAX_TEMPORARY_BYTES = 40L * 1024L * 1024L
    const val ABANDONED_AFTER_MILLIS = 60L * 60L * 1000L
    const val MAX_CLEANUP_FILES = 32
    private const val BUFFER_SIZE = 32 * 1024
    private val tokenPattern = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")

    fun extensionForMime(mimeType: String?): String? = when (mimeType?.lowercase()) {
        "image/png" -> "png"
        "image/jpeg" -> "jpg"
        else -> null
    }

    fun newToken(): String = UUID.randomUUID().toString()

    fun isOpaqueToken(token: String): Boolean = tokenPattern.matches(token)

    fun temporaryFile(directory: File, token: String, extension: String): File? {
        if (!isOpaqueToken(token) || extension !in setOf("png", "jpg")) return null
        val candidate = File(directory, "$token.$extension")
        return if (candidate.parentFile?.canonicalFile == directory.canonicalFile) candidate else null
    }

    fun copyLimited(
        input: InputStream,
        output: OutputStream,
        maximumBytes: Long = MAX_TEMPORARY_BYTES,
    ): Long {
        require(maximumBytes >= 0)
        val buffer = ByteArray(BUFFER_SIZE)
        var total = 0L
        while (true) {
            val read = input.read(buffer)
            if (read < 0) return total
            total += read
            if (total > maximumBytes) throw MediaStoreOcrSourceTooLargeException()
            output.write(buffer, 0, read)
        }
    }

    fun copyToTemporary(input: InputStream, temporary: File): Long = try {
        val fileOutput = try {
            temporary.outputStream().buffered()
        } catch (error: IOException) {
            throw MediaStoreOcrTemporaryFileException(error)
        }
        fileOutput.use { destination ->
            copyLimited(input, TemporaryOutputStream(destination))
        }
    } catch (error: Exception) {
        temporary.delete()
        throw error
    }

    fun cleanupAbandoned(
        directory: File,
        activeTokens: Set<String>,
        nowMillis: Long = System.currentTimeMillis(),
    ): Int {
        val files = directory.listFiles()?.asSequence() ?: return 0
        var removed = 0
        for (file in files.take(MAX_CLEANUP_FILES)) {
            if (!file.isFile) continue
            val token = file.name.substringBeforeLast('.', missingDelimiterValue = "")
            if (!isOpaqueToken(token) || token in activeTokens) continue
            if (nowMillis - file.lastModified() <= ABANDONED_AFTER_MILLIS) continue
            if (file.delete()) removed++
        }
        return removed
    }
}

internal class MediaStoreOcrSourceTooLargeException : Exception()
internal class MediaStoreOcrTemporaryFileException(cause: Throwable) : Exception(cause)

internal class MediaStoreOcrTemporaryRegistry {
    private val files = ConcurrentHashMap<String, File>()

    val activeTokens: Set<String>
        get() = files.keys.toSet()

    fun register(token: String, file: File) {
        require(MediaStoreOcrInputPolicy.isOpaqueToken(token))
        files[token] = file
    }

    fun release(token: String): Boolean {
        if (!MediaStoreOcrInputPolicy.isOpaqueToken(token)) return false
        val file = files.remove(token) ?: return false
        file.delete()
        return true
    }

    fun releaseAll() {
        for (token in activeTokens) release(token)
    }
}

private class TemporaryOutputStream(private val delegate: OutputStream) : OutputStream() {
    override fun write(value: Int) = writeSafely { delegate.write(value) }

    override fun write(buffer: ByteArray, offset: Int, length: Int) =
        writeSafely { delegate.write(buffer, offset, length) }

    override fun flush() = writeSafely { delegate.flush() }

    private fun writeSafely(action: () -> Unit) {
        try {
            action()
        } catch (error: IOException) {
            throw MediaStoreOcrTemporaryFileException(error)
        }
    }
}
