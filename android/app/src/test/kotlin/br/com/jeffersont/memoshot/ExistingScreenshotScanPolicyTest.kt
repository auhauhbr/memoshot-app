package br.com.jeffersont.memoshot

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ExistingScreenshotScanPolicyTest {
    @Test
    fun `pagina usa limite pequeno e centralizado`() {
        assertTrue(ExistingScreenshotScanPolicy.PAGE_SIZE in 100..250)
    }

    @Test
    fun `cursor pagina por id dentro do volume`() {
        val cursor = ExistingScreenshotScanCursor("external_primary", 2400)

        assertEquals(
            2400,
            ExistingScreenshotScanPolicy.startId("external_primary", cursor),
        )
        assertEquals(0, ExistingScreenshotScanPolicy.startId("sdcard", cursor))
    }

    @Test
    fun `volumes e chaves evitam duplicidade para mesmo id`() {
        val volumes = ExistingScreenshotScanPolicy.volumesAfter(
            listOf("sdcard", "external_primary", "sdcard"),
            ExistingScreenshotScanCursor("external_primary", 7),
        )

        assertEquals(listOf("external_primary", "sdcard"), volumes)
        assertEquals("external_primary:7", ExistingScreenshotScanPolicy.sourceKey("external_primary", 7))
        assertEquals("sdcard:7", ExistingScreenshotScanPolicy.sourceKey("sdcard", 7))
    }
}
