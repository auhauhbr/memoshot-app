package br.com.jeffersont.memoshot

internal object MediaStoreReferencePolicy {
    const val MAX_THUMBNAIL_DIMENSION = 512
    const val MAX_THUMBNAIL_PAYLOAD_BYTES = 384 * 1024

    private val volumePattern = Regex("^[A-Za-z0-9_-]+$")

    fun canonicalUri(volumeName: String, mediaStoreId: Long): String? {
        if (!volumePattern.matches(volumeName) || mediaStoreId <= 0L) return null
        return "content://media/$volumeName/images/media/$mediaStoreId"
    }

    fun isValid(
        volumeName: String,
        mediaStoreId: Long,
        contentUri: String,
    ): Boolean = canonicalUri(volumeName, mediaStoreId) == contentUri
}
