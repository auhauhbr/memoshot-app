package br.com.jeffersont.memoshot

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeler
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

internal class LocalVisualAnalyzerBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var labeler: ImageLabeler? = createLabeler()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "analyze" -> analyze(call, result)
            "close" -> {
                closeLabeler()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun analyze(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("localPath")
        val file = path?.let(::File)
        if (file == null || !isControlledLocalFile(file) || !file.isFile) {
            result.error("visualSourceUnavailable", null, null)
            return
        }
        val activeLabeler = labeler
        if (activeLabeler == null) {
            result.error("visualAnalyzerClosed", null, null)
            return
        }
        val input = try {
            InputImage.fromFilePath(appContext, Uri.fromFile(file))
        } catch (_: Exception) {
            result.error("visualUnsupportedInput", null, null)
            return
        }
        activeLabeler.process(input)
            .addOnSuccessListener { labels ->
                result.success(
                    labels.map { label ->
                        mapOf(
                            "key" to label.text,
                            "confidence" to label.confidence.toDouble(),
                            "index" to label.index,
                        )
                    },
                )
            }
            .addOnFailureListener {
                result.error("visualTemporaryFailure", null, null)
            }
    }

    private fun isControlledLocalFile(file: File): Boolean {
        val candidate = try {
            file.canonicalFile
        } catch (_: Exception) {
            return false
        }
        return isInside(candidate, appContext.filesDir) ||
            isInside(candidate, appContext.cacheDir) ||
            appContext.getExternalFilesDirs(null).filterNotNull().any { root ->
                isInside(candidate, root)
            }
    }

    private fun isInside(candidate: File, root: File): Boolean {
        val canonicalRoot = try {
            root.canonicalFile
        } catch (_: Exception) {
            return false
        }
        return candidate.path == canonicalRoot.path ||
            candidate.path.startsWith(canonicalRoot.path + File.separator)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        closeLabeler()
    }

    private fun closeLabeler() {
        labeler?.close()
        labeler = null
    }

    private fun createLabeler(): ImageLabeler = ImageLabeling.getClient(
        ImageLabelerOptions.Builder()
            .setConfidenceThreshold(MINIMUM_LABEL_CONFIDENCE)
            .build(),
    )

    companion object {
        private const val CHANNEL_NAME =
            "br.com.jeffersont.memoshot/local_visual_analyzer"
        private const val MINIMUM_LABEL_CONFIDENCE = 0.50f
    }
}
