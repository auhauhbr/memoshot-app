package br.com.jeffersont.memoshot

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScreenshotRecognitionTest {
    @Test
    fun `reconhece pastas do Android Samsung e Xiaomi HyperOS`() {
        val folders = listOf(
            "Pictures/Screenshots/",
            "DCIM/Screenshots/",
            "Pictures/Screenshot/",
            "MIUI/Screenshots/",
            "DCIM/Screen records/Screenshots/",
        )

        folders.forEach { folder ->
            assertTrue(
                folder,
                ScreenshotRecognition.isScreenshot(
                    "image/png",
                    folder,
                    folder.substringBeforeLast('/').substringAfterLast('/'),
                    "IMG_20260719.png",
                ),
            )
        }
    }

    @Test
    fun `reconhece nomes conhecidos sem diferenciar caixa ou acentos`() {
        val names = listOf(
            "Screenshot_20260719-101010.png",
            "SCREEN_CAPTURE_2026-07-19.jpg",
            "Captura de tela 2026-07-19.png",
            "captura_de_ecrã_20260719.webp",
        )

        names.forEach { name ->
            assertTrue(
                name,
                ScreenshotRecognition.isScreenshot("image/png", null, null, name),
            )
        }
    }

    @Test
    fun `rejeita foto comum e mídia que não é imagem`() {
        assertFalse(
            ScreenshotRecognition.isScreenshot(
                "image/jpeg",
                "DCIM/Camera/",
                "Camera",
                "IMG_20260719_101010.jpg",
            ),
        )
        assertFalse(
            ScreenshotRecognition.isScreenshot(
                "video/mp4",
                "Pictures/Screenshots/",
                "Screenshots",
                "Screenshot.mp4",
            ),
        )
    }
}
