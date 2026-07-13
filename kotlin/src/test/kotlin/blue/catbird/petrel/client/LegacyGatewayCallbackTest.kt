package blue.catbird.petrel.client

import blue.catbird.petrel.network.NetworkService
import kotlin.test.Test
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class LegacyGatewayCallbackTest {
    @Suppress("DEPRECATION")
    @Test
    fun `legacy callback refuses session credentials from URL fragments`() {
        val network = NetworkService("https://api.catbird.blue")
        val client = ATProtoClient(network)

        assertFailsWith<UnsupportedOperationException> {
            client.handleGatewayCallback(
                "https://catbird.blue/oauth/callback#session_id=attacker-controlled-session",
            )
        }

        assertNull(client.currentGatewaySessionId())
        assertNull(network.authenticatedDID)
        assertNull(network.authorizationHeader)
    }
}
