package br.com.jeffersont.memoshot

import java.text.Normalizer
import java.util.Locale

internal object ScreenshotRecognition {
    fun isScreenshot(
        mimeType: String?,
        relativePath: String?,
        bucketDisplayName: String?,
        displayName: String?,
    ): Boolean {
        if (!mimeType.orEmpty().lowercase(Locale.ROOT).startsWith("image/")) return false

        val folder = normalize("${relativePath.orEmpty()} ${bucketDisplayName.orEmpty()}")
        if (folderSignals.any(folder::contains)) return true

        val name = normalize(displayName.orEmpty())
        return nameSignals.any(name::contains)
    }

    private fun normalize(value: String): String {
        val decomposed = Normalizer.normalize(value, Normalizer.Form.NFD)
        return decomposed
            .replace(Regex("\\p{M}+"), "")
            .lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9\\p{L}]+"), "")
    }

    private val folderSignals = listOf(
        "screenshots",
        "screenshot",
        "screenrecordscreenshots",
        "capturasdetela",
        "capturadetela",
        "capturasdeecran",
        "capturadeecra",
        "截屏",
        "截图",
    )

    private val nameSignals = listOf(
        "screenshot",
        "screenshotted",
        "screencapture",
        "capturadetela",
        "capturasdetela",
        "capturadeecra",
        "capturasdeecran",
        "截屏",
        "截图",
    )
}
