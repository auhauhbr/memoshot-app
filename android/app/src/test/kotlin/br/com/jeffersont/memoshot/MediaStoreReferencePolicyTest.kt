package br.com.jeffersont.memoshot

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaStoreReferencePolicyTest {
    @Test
    fun `reconstructs only canonical MediaStore image uri`() {
        assertEquals(
            "content://media/external_primary/images/media/42",
            MediaStoreReferencePolicy.canonicalUri("external_primary", 42),
        )
        assertTrue(
            MediaStoreReferencePolicy.isValid(
                "external_primary",
                42,
                "content://media/external_primary/images/media/42",
            ),
        )
    }

    @Test
    fun `rejects file arbitrary authority invalid volume and id`() {
        assertFalse(MediaStoreReferencePolicy.isValid("external", 1, "file:///tmp/a.png"))
        assertFalse(
            MediaStoreReferencePolicy.isValid(
                "external",
                1,
                "content://example/external/images/media/1",
            ),
        )
        assertNull(MediaStoreReferencePolicy.canonicalUri("../external", 1))
        assertNull(MediaStoreReferencePolicy.canonicalUri("external", 0))
    }

    @Test
    fun `centralizes conservative thumbnail limits`() {
        assertTrue(MediaStoreReferencePolicy.MAX_THUMBNAIL_DIMENSION <= 512)
        assertTrue(MediaStoreReferencePolicy.MAX_THUMBNAIL_PAYLOAD_BYTES <= 384 * 1024)
    }
}
