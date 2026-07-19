package br.com.jeffersont.memoshot

internal data class ReviewNotificationContent(
    val title: String,
    val text: String,
)

internal object ReviewNotificationPolicy {
    const val NOTIFICATION_ID = 9503
    const val CHANNEL_ID = "memoshot_review"
    const val DESTINATION_REVIEW_QUEUE = "reviewQueue"

    fun content(pendingCount: Int): ReviewNotificationContent =
        if (pendingCount == 1) {
            ReviewNotificationContent(
                title = "1 print precisa de revisão",
                text = "Toque para confirmar a organização.",
            )
        } else {
            ReviewNotificationContent(
                title = "$pendingCount prints precisam de revisão",
                text = "Toque para revisar as sugestões.",
            )
        }

    fun shouldAlert(
        pendingCount: Int,
        marker: String,
        lastCount: Int,
        lastMarker: String?,
        activityVisible: Boolean,
    ): Boolean {
        if (activityVisible || pendingCount <= 0 || marker.isEmpty()) return false
        if (pendingCount < lastCount) return false
        return marker != lastMarker
    }

    fun acceptsDestination(value: String?): Boolean =
        value == DESTINATION_REVIEW_QUEUE
}
