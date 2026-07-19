package br.com.jeffersont.memoshot

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

internal class OriginalMediaViewerBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "openOriginalMedia") {
            result.notImplemented()
            return
        }
        val outcome = when (call.argument<String>("storageKind")) {
            "privateFile" -> openPrivate(call)
            "mediaStoreReference" -> openMediaStore(call)
            else -> OpenResult.INVALID_REFERENCE
        }
        result.success(outcome.code)
    }

    private fun openMediaStore(call: MethodCall): OpenResult {
        val volumeName = call.argument<String>("volumeName")
            ?: return OpenResult.INVALID_REFERENCE
        val mediaStoreId = call.argument<Number>("mediaStoreId")?.toLong()
            ?: return OpenResult.INVALID_REFERENCE
        val canonical = MediaStoreReferencePolicy.canonicalUri(volumeName, mediaStoreId)
            ?: return OpenResult.INVALID_REFERENCE
        val uri = Uri.parse(canonical)
        if (uri.scheme != "content" || uri.authority != "media") {
            return OpenResult.INVALID_REFERENCE
        }
        return try {
            val resolvedMime = appContext.contentResolver.getType(uri)
            val mime = OriginalMediaViewerPolicy.resolveMime(
                persistedMime = call.argument("mimeType"),
                resolvedMime = resolvedMime,
            ) ?: return OpenResult.INVALID_REFERENCE
            appContext.contentResolver.openAssetFileDescriptor(uri, "r")?.use { }
                ?: return OpenResult.UNAVAILABLE
            launch(uri, mime)
        } catch (_: SecurityException) {
            OpenResult.PERMISSION_DENIED
        } catch (_: java.io.FileNotFoundException) {
            OpenResult.UNAVAILABLE
        } catch (_: Exception) {
            OpenResult.TEMPORARY_FAILURE
        }
    }

    private fun openPrivate(call: MethodCall): OpenResult {
        val internalName = call.argument<String>("internalName")
            ?: return OpenResult.INVALID_PRIVATE_FILE
        val mime = OriginalMediaViewerPolicy.resolveMime(
            persistedMime = call.argument("mimeType"),
            resolvedMime = null,
        ) ?: OriginalMediaViewerPolicy.mimeFromInternalName(internalName)
        ?: return OpenResult.INVALID_PRIVATE_FILE
        val root = File(appContext.applicationInfo.dataDir, PRIVATE_SCREENSHOTS_DIRECTORY)
        val file = OriginalMediaViewerPolicy.resolvePrivateFile(root, internalName)
            ?: return OpenResult.INVALID_PRIVATE_FILE
        if (!file.exists() || !file.isFile) return OpenResult.UNAVAILABLE
        return try {
            val uri = FileProvider.getUriForFile(
                appContext,
                "${appContext.packageName}.original_media",
                file,
            )
            launch(uri, mime)
        } catch (_: IllegalArgumentException) {
            OpenResult.INVALID_PRIVATE_FILE
        } catch (_: SecurityException) {
            OpenResult.PERMISSION_DENIED
        } catch (_: Exception) {
            OpenResult.TEMPORARY_FAILURE
        }
    }

    private fun launch(uri: Uri, mime: String): OpenResult {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            clipData = ClipData.newRawUri("original", uri)
        }
        if (intent.resolveActivity(appContext.packageManager) == null) {
            return OpenResult.NO_COMPATIBLE_APP
        }
        return try {
            appContext.startActivity(intent)
            OpenResult.OPENED
        } catch (_: ActivityNotFoundException) {
            OpenResult.NO_COMPATIBLE_APP
        } catch (_: SecurityException) {
            OpenResult.PERMISSION_DENIED
        } catch (_: Exception) {
            OpenResult.TEMPORARY_FAILURE
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private enum class OpenResult(val code: String) {
        OPENED("opened"),
        UNAVAILABLE("unavailable"),
        PERMISSION_DENIED("permissionDenied"),
        NO_COMPATIBLE_APP("noCompatibleApp"),
        INVALID_REFERENCE("invalidReference"),
        INVALID_PRIVATE_FILE("invalidPrivateFile"),
        TEMPORARY_FAILURE("temporaryFailure"),
    }

    companion object {
        private const val CHANNEL_NAME =
            "br.com.jeffersont.memoshot/original_media_viewer"
        private const val PRIVATE_SCREENSHOTS_DIRECTORY =
            "app_flutter/screenshots"
    }
}

internal object OriginalMediaViewerPolicy {
    private val allowedMimeTypes = setOf(
        "image/png",
        "image/jpeg",
        "image/webp",
        "image/heic",
        "image/heif",
    )
    private val internalNamePattern = Regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")

    fun resolveMime(persistedMime: String?, resolvedMime: String?): String? {
        val persisted = persistedMime?.lowercase()?.takeIf(allowedMimeTypes::contains)
        val resolved = resolvedMime?.lowercase()?.takeIf(allowedMimeTypes::contains)
        if (resolvedMime != null && resolved == null) return null
        if (persisted != null && resolved != null && persisted != resolved) return null
        return resolved ?: persisted
    }

    fun mimeFromInternalName(internalName: String): String? = when {
        internalName.endsWith(".png", ignoreCase = true) -> "image/png"
        internalName.endsWith(".jpg", ignoreCase = true) ||
            internalName.endsWith(".jpeg", ignoreCase = true) -> "image/jpeg"
        internalName.endsWith(".webp", ignoreCase = true) -> "image/webp"
        internalName.endsWith(".heic", ignoreCase = true) -> "image/heic"
        internalName.endsWith(".heif", ignoreCase = true) -> "image/heif"
        else -> null
    }

    fun resolvePrivateFile(root: File, internalName: String): File? {
        if (!internalNamePattern.matches(internalName) ||
            internalName.contains('/') || internalName.contains('\\') ||
            internalName == "." || internalName == ".."
        ) return null
        val canonicalRoot = try {
            root.canonicalFile
        } catch (_: Exception) {
            return null
        }
        val candidate = try {
            File(canonicalRoot, internalName).canonicalFile
        } catch (_: Exception) {
            return null
        }
        if (candidate.parentFile != canonicalRoot) return null
        return candidate
    }
}
