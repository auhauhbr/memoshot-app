package br.com.jeffersont.memoshot

import android.app.usage.UsageEvents
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ForegroundAppSelectionPolicyTest {
    private val capture = 100_000L

    @Test
    fun `selects closest previous event and assigns temporal confidence`() {
        assertEquals("high", select(capture - 500)!!.confidenceLevel)
        assertEquals("high", select(capture - 2_000)!!.confidenceLevel)
        assertEquals("medium", select(capture - 5_000)!!.confidenceLevel)
        assertEquals("low", select(capture - 10_000)!!.confidenceLevel)
        assertNull(select(capture - 10_001))
    }

    @Test
    fun `uses close future event only when no valid previous event exists`() {
        val result = ForegroundAppSelectionPolicy.select(
            listOf(
                event("com.android.systemui", capture - 200),
                event("com.whatsapp", capture + 1_500),
            ),
            capture,
            setOf("com.android.systemui"),
        )
        assertEquals("com.whatsapp", result!!.packageName)
        assertEquals(1_500, result.deltaMilliseconds)
        assertNull(select(capture + 2_001))
    }

    @Test
    fun `selects last foreground and ignores technical packages`() {
        val result = ForegroundAppSelectionPolicy.select(
            listOf(
                event("com.whatsapp", capture - 2_000),
                event("com.android.settings", capture - 900),
                event("com.instagram.android", capture - 500),
            ),
            capture,
            setOf("com.android.settings"),
        )
        assertEquals("com.instagram.android", result!!.packageName)
    }

    @Test
    fun `maps known apps browsers and leaves unknown package technical only`() {
        val mappings = mapOf(
            "com.whatsapp" to "whatsapp",
            "com.instagram.android" to "instagram",
            "com.amazon.mShop.android.shopping" to "amazon",
            "com.brave.browser" to "brave",
            "com.android.chrome" to "chrome",
            "org.mozilla.firefox" to "firefox",
        )
        mappings.forEach { (packageName, expected) ->
            assertEquals(expected, CaptureAppPackageMapper.normalize(packageName))
        }
        assertNull(CaptureAppPackageMapper.normalize("org.example.unknown"))
    }

    private fun select(timestamp: Long) = ForegroundAppSelectionPolicy.select(
        listOf(event("com.whatsapp", timestamp)),
        capture,
        emptySet(),
    )

    private fun event(packageName: String, timestamp: Long) = ForegroundUsageEvent(
        packageName,
        timestamp,
        UsageEvents.Event.ACTIVITY_RESUMED,
    )
}
