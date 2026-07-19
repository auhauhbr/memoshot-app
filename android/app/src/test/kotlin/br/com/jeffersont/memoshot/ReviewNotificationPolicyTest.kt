package br.com.jeffersont.memoshot

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReviewNotificationPolicyTest {
    @Test
    fun `conteudo singular e plural nao contem classificacao`() {
        assertEquals("1 print precisa de revisão", ReviewNotificationPolicy.content(1).title)
        assertEquals(
            "Toque para confirmar a organização.",
            ReviewNotificationPolicy.content(1).text,
        )
        assertEquals("4 prints precisam de revisão", ReviewNotificationPolicy.content(4).title)
        assertEquals(
            "Toque para revisar as sugestões.",
            ReviewNotificationPolicy.content(4).text,
        )
    }

    @Test
    fun `id e canal sao estaveis`() {
        assertEquals(9503, ReviewNotificationPolicy.NOTIFICATION_ID)
        assertEquals("memoshot_review", ReviewNotificationPolicy.CHANNEL_ID)
    }

    @Test
    fun `mesmo marcador nao alerta novamente`() {
        assertFalse(
            ReviewNotificationPolicy.shouldAlert(2, "20:2", 2, "20:2", false),
        )
    }

    @Test
    fun `novo marcador alerta somente fora da activity visivel`() {
        assertTrue(
            ReviewNotificationPolicy.shouldAlert(2, "30:3", 1, "20:2", false),
        )
        assertFalse(
            ReviewNotificationPolicy.shouldAlert(2, "30:3", 1, "20:2", true),
        )
    }

    @Test
    fun `mesma quantidade com marcador novo representa nova pendencia`() {
        assertTrue(
            ReviewNotificationPolicy.shouldAlert(2, "30:3", 2, "20:2", false),
        )
    }

    @Test
    fun `reducao da fila e silenciosa`() {
        assertFalse(
            ReviewNotificationPolicy.shouldAlert(1, "10:1", 2, "20:2", false),
        )
    }

    @Test
    fun `destino aceita somente fila de revisao`() {
        assertTrue(ReviewNotificationPolicy.acceptsDestination("reviewQueue"))
        assertFalse(ReviewNotificationPolicy.acceptsDestination("screenshot/1"))
        assertFalse(ReviewNotificationPolicy.acceptsDestination(null))
    }
}
