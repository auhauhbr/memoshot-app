package br.com.jeffersont.memoshot

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process

internal data class CaptureAppContextData(
    val packageName: String,
    val normalizedAppKey: String?,
    val eventTimestamp: Long,
    val captureTimestamp: Long,
    val deltaMilliseconds: Long,
    val confidenceLevel: String,
)

internal data class ForegroundUsageEvent(
    val packageName: String,
    val timestamp: Long,
    val eventType: Int,
)

internal object ForegroundAppSelectionPolicy {
    const val BEFORE_WINDOW_MILLIS = 10_000L
    const val FUTURE_FALLBACK_MILLIS = 2_000L
    const val RECENT_CAPTURE_WINDOW_MILLIS = 30_000L

    fun select(
        events: List<ForegroundUsageEvent>,
        capturedAt: Long,
        excludedPackages: Set<String>,
    ): CaptureAppContextData? {
        if (capturedAt <= 0) return null
        val candidates = events.filter { event ->
            event.packageName.isNotBlank() &&
                event.packageName !in excludedPackages &&
                isForegroundEvent(event.eventType)
        }
        val event = candidates
            .filter { it.timestamp in (capturedAt - BEFORE_WINDOW_MILLIS)..capturedAt }
            .maxByOrNull { it.timestamp }
            ?: candidates
                .filter { it.timestamp in (capturedAt + 1)..(capturedAt + FUTURE_FALLBACK_MILLIS) }
                .minByOrNull { it.timestamp }
            ?: return null
        val delta = kotlin.math.abs(capturedAt - event.timestamp)
        val confidence = when {
            delta <= 2_000L -> "high"
            delta <= 5_000L -> "medium"
            delta <= 10_000L -> "low"
            else -> return null
        }
        return CaptureAppContextData(
            packageName = event.packageName,
            normalizedAppKey = CaptureAppPackageMapper.normalize(event.packageName),
            eventTimestamp = event.timestamp,
            captureTimestamp = capturedAt,
            deltaMilliseconds = delta,
            confidenceLevel = confidence,
        )
    }

    private fun isForegroundEvent(type: Int): Boolean =
        type == UsageEvents.Event.ACTIVITY_RESUMED ||
            type == UsageEvents.Event.MOVE_TO_FOREGROUND
}

internal object CaptureAppPackageMapper {
    fun normalize(packageName: String): String? = when (packageName) {
        "com.whatsapp", "com.whatsapp.w4b" -> "whatsapp"
        "com.instagram.android" -> "instagram"
        "com.amazon.mShop.android.shopping" -> "amazon"
        "com.mercadolibre", "com.mercadolibre.android" -> "mercadoLivre"
        "com.mercadopago.wallet" -> "mercadoPago"
        "com.linkedin.android" -> "linkedin"
        "com.github.android" -> "github"
        "com.brave.browser", "com.brave.browser_beta", "com.brave.browser_nightly" -> "brave"
        "com.android.chrome", "com.chrome.beta", "com.chrome.dev" -> "chrome"
        "org.mozilla.firefox", "org.mozilla.firefox_beta" -> "firefox"
        "com.android.browser" -> "browser"
        else -> null
    }
}

internal class ForegroundAppAtCaptureBridge(context: Context) {
    private val appContext = context.applicationContext

    fun isAvailable(): Boolean =
        appContext.getSystemService(Context.USAGE_STATS_SERVICE) is UsageStatsManager

    fun checkUsageAccess(): Boolean {
        val manager = appContext.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return false
        return manager.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            appContext.packageName,
        ) == AppOpsManager.MODE_ALLOWED
    }

    fun findForegroundAppAt(timestamp: Long): CaptureAppContextData? {
        if (!AppPreferencesBridge.isUsageContextEnabled(appContext) || !checkUsageAccess()) {
            return null
        }
        if (timestamp <= 0 || kotlin.math.abs(System.currentTimeMillis() - timestamp) >
            ForegroundAppSelectionPolicy.RECENT_CAPTURE_WINDOW_MILLIS
        ) return null
        val manager = appContext.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return null
        return try {
            val usageEvents = manager.queryEvents(
                timestamp - ForegroundAppSelectionPolicy.BEFORE_WINDOW_MILLIS,
                timestamp + ForegroundAppSelectionPolicy.FUTURE_FALLBACK_MILLIS,
            ) ?: return null
            val events = mutableListOf<ForegroundUsageEvent>()
            val event = UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                    event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
                ) {
                    events += ForegroundUsageEvent(event.packageName.orEmpty(), event.timeStamp, event.eventType)
                }
            }
            ForegroundAppSelectionPolicy.select(events, timestamp, excludedPackages())
        } catch (_: Exception) {
            null
        }
    }

    private fun excludedPackages(): Set<String> {
        val homePackage = appContext.packageManager.resolveActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            0,
        )?.activityInfo?.packageName
        return setOfNotNull(
            appContext.packageName,
            homePackage,
            "com.android.systemui",
            "com.android.settings",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.google.android.documentsui",
            "com.android.documentsui",
            "com.google.android.apps.photos",
            "com.android.gallery3d",
            "com.sec.android.gallery3d",
            "com.miui.gallery",
            "com.oneplus.gallery",
            "com.motorola.gallery",
            "com.google.android.apps.nexuslauncher",
            "com.android.launcher3",
        )
    }
}
