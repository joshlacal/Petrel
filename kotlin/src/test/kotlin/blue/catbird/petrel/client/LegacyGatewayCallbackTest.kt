package blue.catbird.petrel.client

import blue.catbird.petrel.network.NetworkService
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertNull

class LegacyGatewayCallbackTest {
    @Test
    fun `client uses secure strategy-backed gateway API and legacy shims are removed`() {
        val network = NetworkService("https://api.catbird.blue")
        val client = ATProtoClient(network)

        // Verify legacy shims are removed from ATProtoClient class surface
        val methods = client::class.java.methods.map { it.name }
        assertFalse(methods.contains("restoreGatewaySession"))
        assertFalse(methods.contains("clearGatewaySession"))
        assertFalse(methods.contains("currentGatewaySessionId"))
        assertFalse(methods.contains("createGatewayLoginUrl"))
        assertFalse(methods.contains("handleGatewayCallback"))
        assertFalse(methods.contains("gatewayLogout"))

        assertNull(client.getActiveDid())
        assertNull(network.authenticatedDID)
        assertNull(network.authorizationHeader)
    }
}
