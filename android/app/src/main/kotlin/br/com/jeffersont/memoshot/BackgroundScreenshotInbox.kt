package br.com.jeffersont.memoshot

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.UUID

internal data class BackgroundInboxEntry(
    val entryId: String,
    val mediaStoreId: Long,
    val imagePath: String,
    val mimeType: String?,
    val capturedAt: Long?,
    val captureAppContext: CaptureAppContextData?,
)

internal class BackgroundScreenshotInbox(context: Context) {
    private val directory = File(context.filesDir, DIRECTORY_NAME)

    fun containsMediaId(mediaStoreId: Long): Boolean = synchronized(lock) {
        listEntriesUnlocked().any { it.mediaStoreId == mediaStoreId }
    }

    fun pendingCount(): Int = synchronized(lock) { listEntriesUnlocked().size }

    fun write(
        mediaStoreId: Long,
        mimeType: String?,
        capturedAt: Long?,
        captureAppContext: CaptureAppContextData?,
        input: InputStream,
    ): BackgroundInboxEntry? = synchronized(lock) {
        directory.mkdirs()
        if (listEntriesUnlocked().any { it.mediaStoreId == mediaStoreId }) {
            return@synchronized null
        }
        val entryId = UUID.randomUUID().toString()
        val extension = when (mimeType) {
            "image/png" -> ".png"
            "image/webp" -> ".webp"
            else -> ".jpg"
        }
        val imageName = "$entryId$extension"
        val imagePart = File(directory, "$imageName.part")
        val imageFinal = File(directory, imageName)
        val metadataPart = File(directory, "$entryId.json.part")
        val metadataFinal = File(directory, "$entryId.json")
        return try {
            syncCopy(input, imagePart)
            if (!imagePart.renameTo(imageFinal)) error("image_commit_failed")
            val metadata = JSONObject()
                .put("format_version", FORMAT_VERSION)
                .put("entry_id", entryId)
                .put("media_store_id", mediaStoreId)
                .put("image_file", imageName)
                .put("mime_type", mimeType ?: JSONObject.NULL)
                .put(
                    "captured_at",
                    MediaStoreCaptureTime.validate(capturedAt) ?: JSONObject.NULL,
                )
                .apply {
                    captureAppContext?.let { context ->
                        put("capture_app_context", JSONObject()
                            .put("package_name", context.packageName)
                            .put("normalized_app_key", context.normalizedAppKey ?: JSONObject.NULL)
                            .put("event_timestamp", context.eventTimestamp)
                            .put("capture_timestamp", context.captureTimestamp)
                            .put("delta_milliseconds", context.deltaMilliseconds)
                            .put("confidence_level", context.confidenceLevel))
                    }
                }
            syncBytes(metadata.toString().toByteArray(Charsets.UTF_8), metadataPart)
            if (!metadataPart.renameTo(metadataFinal)) error("metadata_commit_failed")
            BackgroundInboxEntry(
                entryId,
                mediaStoreId,
                imageFinal.absolutePath,
                mimeType,
                MediaStoreCaptureTime.validate(capturedAt),
                captureAppContext,
            )
        } catch (_: Exception) {
            imagePart.delete()
            imageFinal.delete()
            metadataPart.delete()
            metadataFinal.delete()
            null
        }
    }

    fun listEntries(): List<BackgroundInboxEntry> = synchronized(lock) {
        listEntriesUnlocked()
    }

    private fun listEntriesUnlocked(): List<BackgroundInboxEntry> {
        directory.mkdirs()
        val metadataFiles = directory.listFiles { file -> file.name.endsWith(".json") }
            .orEmpty()
        val entries = metadataFiles
            .mapNotNull(::readEntry)
            .sortedWith(compareBy<BackgroundInboxEntry> { it.mediaStoreId }.thenBy { it.entryId })
        cleanupIncompleteFiles(entries, metadataFiles.toList())
        return entries
    }

    fun remove(entryId: String): Boolean = synchronized(lock) {
        val entry = listEntriesUnlocked().firstOrNull { it.entryId == entryId }
        val metadata = safeChild("$entryId.json") ?: return@synchronized false
        val imageRemoved = entry?.let { File(it.imagePath).delete() || !File(it.imagePath).exists() } ?: true
        val metadataRemoved = metadata.delete() || !metadata.exists()
        imageRemoved && metadataRemoved
    }

    private fun readEntry(metadataFile: File): BackgroundInboxEntry? {
        return try {
            val json = JSONObject(metadataFile.readText(Charsets.UTF_8))
            if (json.getInt("format_version") != FORMAT_VERSION) return null
            val entryId = json.getString("entry_id")
            if (metadataFile.name != "$entryId.json") return null
            val image = safeChild(json.getString("image_file")) ?: return null
            if (!image.isFile) return null
            BackgroundInboxEntry(
                entryId = entryId,
                mediaStoreId = json.getLong("media_store_id"),
                imagePath = image.absolutePath,
                mimeType = json.optString("mime_type").takeIf { it.isNotEmpty() && it != "null" },
                capturedAt = MediaStoreCaptureTime.validate(
                    if (!json.has("captured_at") || json.isNull("captured_at")) {
                        null
                    } else {
                        json.optLong("captured_at")
                    },
                ),
                captureAppContext = readCaptureAppContext(json),
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun readCaptureAppContext(json: JSONObject): CaptureAppContextData? {
        val value = json.optJSONObject("capture_app_context") ?: return null
        return runCatching {
            CaptureAppContextData(
                packageName = value.getString("package_name"),
                normalizedAppKey = value.optString("normalized_app_key")
                    .takeIf { it.isNotBlank() && it != "null" },
                eventTimestamp = value.getLong("event_timestamp"),
                captureTimestamp = value.getLong("capture_timestamp"),
                deltaMilliseconds = value.getLong("delta_milliseconds"),
                confidenceLevel = value.getString("confidence_level"),
            )
        }.getOrNull()
    }

    private fun cleanupIncompleteFiles(
        entries: List<BackgroundInboxEntry>,
        metadataFiles: List<File>,
    ) {
        val referenced = entries.map { File(it.imagePath).name }.toSet()
        val validMetadata = entries.map { "${it.entryId}.json" }.toSet()
        metadataFiles.filterNot { it.name in validMetadata }.forEach(File::delete)
        directory.listFiles()?.forEach { file ->
            if (file.name.endsWith(".part") ||
                (!file.name.endsWith(".json") && file.name !in referenced)
            ) {
                file.delete()
            }
        }
    }

    private fun safeChild(name: String): File? {
        val root = directory.canonicalFile
        val child = File(root, name).canonicalFile
        return child.takeIf { it.parentFile == root }
    }

    private fun syncCopy(input: InputStream, target: File) {
        FileOutputStream(target).use { output ->
            input.copyTo(output)
            output.fd.sync()
        }
    }

    private fun syncBytes(bytes: ByteArray, target: File) {
        FileOutputStream(target).use { output ->
            output.write(bytes)
            output.fd.sync()
        }
    }

    companion object {
        private val lock = Any()
        private const val DIRECTORY_NAME = "background_screenshot_inbox"
        private const val FORMAT_VERSION = 1
    }
}
