package br.com.jeffersont.memoshot

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OriginalMediaViewerPolicyTest {
    @Test
    fun `aceita somente MIME de imagem permitido e divergencia e rejeitada`() {
        assertEquals(
            "image/png",
            OriginalMediaViewerPolicy.resolveMime("image/png", "image/png"),
        )
        assertNull(OriginalMediaViewerPolicy.resolveMime("image/png", "image/jpeg"))
        assertNull(OriginalMediaViewerPolicy.resolveMime("application/pdf", null))
        assertNull(OriginalMediaViewerPolicy.resolveMime(null, "image/gif"))
    }

    @Test
    fun `infere MIME conservador somente pela extensao interna permitida`() {
        assertEquals(
            "image/jpeg",
            OriginalMediaViewerPolicy.mimeFromInternalName("screenshot_1.JPEG"),
        )
        assertNull(OriginalMediaViewerPolicy.mimeFromInternalName("screenshot_1.gif"))
        assertNull(OriginalMediaViewerPolicy.mimeFromInternalName("screenshot_1"))
    }

    @Test
    fun `aceita arquivo diretamente na raiz privada`() {
        val root = Files.createTempDirectory("memoshot-private-root").toFile()
        try {
            val file = File(root, "screenshot_1.png").apply { writeBytes(byteArrayOf(1)) }
            assertEquals(file.canonicalFile, OriginalMediaViewerPolicy.resolvePrivateFile(root, file.name))
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun `rejeita traversal diretorio e symlink que escapa da raiz`() {
        val parent = Files.createTempDirectory("memoshot-private-parent").toFile()
        val root = File(parent, "screenshots").apply { mkdir() }
        val outside = File(parent, "outside.png").apply { writeBytes(byteArrayOf(1)) }
        try {
            assertNull(OriginalMediaViewerPolicy.resolvePrivateFile(root, "../outside.png"))
            assertNull(OriginalMediaViewerPolicy.resolvePrivateFile(root, "."))
            val link = File(root, "screenshot_link.png").toPath()
            runCatching { Files.createSymbolicLink(link, outside.toPath()) }
            if (Files.isSymbolicLink(link)) {
                assertNull(OriginalMediaViewerPolicy.resolvePrivateFile(root, link.fileName.toString()))
            } else {
                assertTrue(true)
            }
        } finally {
            parent.deleteRecursively()
        }
    }
}
