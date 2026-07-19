package br.com.jeffersont.memoshot

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.File
import java.io.InputStream
import java.nio.file.Files

class MediaStoreOcrInputPolicyTest {
    @Test
    fun `accepts only validated OCR mime types`() {
        assertEquals("png", MediaStoreOcrInputPolicy.extensionForMime("image/png"))
        assertEquals("jpg", MediaStoreOcrInputPolicy.extensionForMime("image/jpeg"))
        assertNull(MediaStoreOcrInputPolicy.extensionForMime("image/webp"))
        assertNull(MediaStoreOcrInputPolicy.extensionForMime("image/gif"))
        assertNull(MediaStoreOcrInputPolicy.extensionForMime("video/mp4"))
        assertNull(MediaStoreOcrInputPolicy.extensionForMime(null))
        assertNull(MediaStoreOcrInputPolicy.extensionForMime("application/octet-stream"))
    }

    @Test
    fun `copies in streaming without changing input`() {
        val bytes = ByteArray(128 * 1024) { (it % 251).toByte() }
        val output = java.io.ByteArrayOutputStream()

        val copied = MediaStoreOcrInputPolicy.copyLimited(
            ByteArrayInputStream(bytes),
            output,
        )

        assertEquals(bytes.size.toLong(), copied)
        assertArrayEquals(bytes, output.toByteArray())
    }

    @Test
    fun `enforces 40 MiB limit without loading source in memory`() {
        val source = RepeatingInputStream(MediaStoreOcrInputPolicy.MAX_TEMPORARY_BYTES + 1)
        val sink = CountingOutputStream()

        val error = runCatching {
            MediaStoreOcrInputPolicy.copyLimited(source, sink)
        }.exceptionOrNull()

        assertTrue(error is MediaStoreOcrSourceTooLargeException)
        assertTrue(sink.count <= MediaStoreOcrInputPolicy.MAX_TEMPORARY_BYTES)
    }

    @Test
    fun `deletes partial temporary after copy failure`() {
        withTemporaryDirectory { directory ->
            val token = MediaStoreOcrInputPolicy.newToken()
            val file = MediaStoreOcrInputPolicy.temporaryFile(directory, token, "png")!!

            runCatching {
                MediaStoreOcrInputPolicy.copyToTemporary(
                    RepeatingInputStream(MediaStoreOcrInputPolicy.MAX_TEMPORARY_BYTES + 1),
                    file,
                )
            }

            assertFalse(file.exists())
        }
    }

    @Test
    fun `creates opaque distinct tokens and controlled filenames`() {
        withTemporaryDirectory { directory ->
            val first = MediaStoreOcrInputPolicy.newToken()
            val second = MediaStoreOcrInputPolicy.newToken()
            val file = MediaStoreOcrInputPolicy.temporaryFile(directory, first, "jpg")

            assertNotEquals(first, second)
            assertTrue(MediaStoreOcrInputPolicy.isOpaqueToken(first))
            assertNotNull(file)
            assertEquals(directory.canonicalFile, file!!.parentFile!!.canonicalFile)
            assertEquals("$first.jpg", file.name)
            assertFalse(file.name.contains("sourceKey"))
            assertFalse(file.name.contains("original"))
            assertNull(MediaStoreOcrInputPolicy.temporaryFile(directory, "../escape", "png"))
        }
    }

    @Test
    fun `cleanup removes only expired controlled files and preserves recent and active`() {
        withTemporaryDirectory { directory ->
            val oldToken = MediaStoreOcrInputPolicy.newToken()
            val recentToken = MediaStoreOcrInputPolicy.newToken()
            val activeToken = MediaStoreOcrInputPolicy.newToken()
            val old = create(directory, oldToken)
            val recent = create(directory, recentToken)
            val active = create(directory, activeToken)
            val unrelated = File(directory, "private-library.png").apply { writeBytes(byteArrayOf(4)) }
            val now = System.currentTimeMillis()
            old.setLastModified(now - MediaStoreOcrInputPolicy.ABANDONED_AFTER_MILLIS - 1)
            active.setLastModified(now - MediaStoreOcrInputPolicy.ABANDONED_AFTER_MILLIS - 1)
            recent.setLastModified(now)
            unrelated.setLastModified(0)

            val removed = MediaStoreOcrInputPolicy.cleanupAbandoned(
                directory,
                setOf(activeToken),
                now,
            )

            assertEquals(1, removed)
            assertFalse(old.exists())
            assertTrue(recent.exists())
            assertTrue(active.exists())
            assertTrue(unrelated.exists())
        }
    }

    @Test
    fun `registry releases by opaque token and repeated or unknown release is safe`() {
        withTemporaryDirectory { directory ->
            val registry = MediaStoreOcrTemporaryRegistry()
            val firstToken = MediaStoreOcrInputPolicy.newToken()
            val secondToken = MediaStoreOcrInputPolicy.newToken()
            val first = create(directory, firstToken)
            val second = create(directory, secondToken)
            registry.register(firstToken, first)
            registry.register(secondToken, second)

            assertTrue(registry.release(firstToken))
            assertFalse(first.exists())
            assertFalse(registry.release(firstToken))
            assertFalse(registry.release(MediaStoreOcrInputPolicy.newToken()))
            assertTrue(second.exists())

            registry.releaseAll()
            assertFalse(second.exists())
            assertTrue(registry.activeTokens.isEmpty())
        }
    }

    private fun create(directory: File, token: String): File =
        MediaStoreOcrInputPolicy.temporaryFile(directory, token, "png")!!.apply {
            writeBytes(byteArrayOf(1, 2, 3))
        }

    private fun withTemporaryDirectory(block: (File) -> Unit) {
        val directory = Files.createTempDirectory("memoshot_ocr_policy_").toFile()
        try {
            block(directory)
        } finally {
            directory.deleteRecursively()
        }
    }

    private class RepeatingInputStream(private var remaining: Long) : InputStream() {
        override fun read(): Int = if (remaining-- > 0) 1 else -1

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            if (remaining <= 0) return -1
            val count = minOf(length.toLong(), remaining).toInt()
            buffer.fill(1, offset, offset + count)
            remaining -= count
            return count
        }
    }

    private class CountingOutputStream : java.io.OutputStream() {
        var count = 0L

        override fun write(value: Int) {
            count++
        }

        override fun write(buffer: ByteArray, offset: Int, length: Int) {
            count += length
        }
    }
}
