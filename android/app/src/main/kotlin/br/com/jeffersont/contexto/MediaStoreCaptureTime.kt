package br.com.jeffersont.contexto

internal object MediaStoreCaptureTime {
    fun resolve(dateTakenMillis: Long, dateAddedSeconds: Long): Long? {
        if (isValid(dateTakenMillis)) return dateTakenMillis
        if (dateAddedSeconds <= 0 || dateAddedSeconds > Long.MAX_VALUE / 1000L) return null
        return (dateAddedSeconds * 1000L).takeIf(::isValid)
    }

    fun validate(timestampMillis: Long?): Long? = timestampMillis?.takeIf(::isValid)

    private fun isValid(timestampMillis: Long): Boolean {
        val latestReasonable = System.currentTimeMillis() + FUTURE_TOLERANCE_MS
        return timestampMillis > 0 && timestampMillis <= latestReasonable
    }

    private const val FUTURE_TOLERANCE_MS = 24L * 60 * 60 * 1000
}
