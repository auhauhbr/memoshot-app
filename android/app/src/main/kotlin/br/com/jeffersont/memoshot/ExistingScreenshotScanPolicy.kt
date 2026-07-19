package br.com.jeffersont.memoshot

internal data class ExistingScreenshotScanCursor(
    val volumeName: String,
    val mediaStoreId: Long,
)

internal object ExistingScreenshotScanPolicy {
    const val PAGE_SIZE = 200

    fun volumesAfter(
        volumes: Collection<String>,
        cursor: ExistingScreenshotScanCursor?,
    ): List<String> = volumes
        .distinct()
        .sorted()
        .filter { cursor == null || it >= cursor.volumeName }

    fun startId(volumeName: String, cursor: ExistingScreenshotScanCursor?): Long =
        if (cursor?.volumeName == volumeName) cursor.mediaStoreId else 0L

    fun sourceKey(volumeName: String, mediaStoreId: Long): String =
        "$volumeName:$mediaStoreId"
}
