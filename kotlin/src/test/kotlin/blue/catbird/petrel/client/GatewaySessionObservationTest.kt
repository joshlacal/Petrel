package blue.catbird.petrel.client

import blue.catbird.petrel.auth.gateway.ConfidentialGatewayStrategy
import blue.catbird.petrel.auth.gateway.GatewayException
import blue.catbird.petrel.auth.gateway.InMemoryGatewaySessionStorage
import blue.catbird.petrel.network.NetworkService
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.io.IOException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlinx.coroutines.test.runTest

class GatewaySessionObservationTest {
    private val did = "did:plc:alice"
    private val otherDid = "did:plc:bob"
    private val sessionId = "123e4567-e89b-12d3-a456-426614174000"
    private val otherSessionId = "123e4567-e89b-12d3-a456-426614174001"

    @Test
    fun `client session check uses the stored bearer and preserves account state`() = runTest {
        var requests = 0
        val fixture = fixture(HttpClient(MockEngine { request ->
            requests++
            assertEquals(HttpMethod.Get, request.method)
            assertEquals("https://api.catbird.blue/auth/session", request.url.toString())
            assertEquals("Bearer $sessionId", request.headers[HttpHeaders.Authorization])
            assertEquals("application/json", request.headers[HttpHeaders.Accept])
            respond(
                """{"did":"$did","handle":"alice.example","active":true}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }))
        fixture.use {
            val invalidated = mutableListOf<String>()
            it.client.onSessionInvalidated = invalidated::add

            val response = it.client.gatewayCheckSession()

            assertEquals(did, response.did)
            assertEquals("alice.example", response.handle)
            assertEquals(true, response.active)
            assertEquals(1, requests)
            assertEquals(emptyList(), invalidated)
            assertSessionRetained(it)
        }
    }

    @Test
    fun `session check without a stored session fails before network access`() = runTest {
        val fixture = fixture(HttpClient(MockEngine { error("unexpected request") }), authenticated = false)
        fixture.use {
            assertFailsWith<GatewayException.MissingSession> { it.client.gatewayCheckSession() }
            assertNull(it.storage.getCurrentDid())
            assertNull(it.network.authorizationHeader)
        }
    }

    @Test
    fun `client session check requires a configured gateway`() = runTest {
        val http = HttpClient(MockEngine { error("unexpected request") })
        try {
            val client = ATProtoClient(NetworkService("https://api.catbird.blue", client = http))
            assertFailsWith<IllegalStateException> { client.gatewayCheckSession() }
        } finally {
            http.close()
        }
    }

    @Test
    fun `session check reports expiry without taking ownership of local invalidation`() = runTest {
        val fixture = fixture(HttpClient(MockEngine { respond("", HttpStatusCode.Unauthorized) }))
        fixture.use {
            val invalidated = mutableListOf<String>()
            it.client.onSessionInvalidated = invalidated::add

            assertFailsWith<GatewayException.SessionExpired> { it.client.gatewayCheckSession() }

            assertEquals(emptyList(), invalidated)
            assertSessionRetained(it)
        }
    }

    @Test
    fun `session check rejects oversized and malformed responses without clearing credentials`() = runTest {
        for (body in listOf("x".repeat(8193), """{"did":[]}""")) {
            val fixture = fixture(HttpClient(MockEngine {
                respond(body, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }))
            fixture.use {
                assertFailsWith<GatewayException.InvalidSession> { it.client.gatewayCheckSession() }
                assertSessionRetained(it)
            }
        }
    }

    @Test
    fun `terminal gateway invalidation notifies the affected account after clearing network credentials`() = runTest {
        val fixture = fixture(HttpClient(MockEngine { error("unexpected request") }))
        fixture.use {
            it.storage.saveSession(otherDid, otherSessionId)
            val invalidated = mutableListOf<String>()
            val credentialsAtNotification = mutableListOf<Pair<String?, String?>>()
            it.client.onSessionInvalidated = { invalidatedDid ->
                invalidated += invalidatedDid
                credentialsAtNotification += it.network.authenticatedDID to it.network.authorizationHeader
            }

            assertFailsWith<GatewayException.SessionExpired> {
                it.strategy.handleUnauthorizedResponse(
                    "api.catbird.blue", """{"error":"invalid_session"}""".encodeToByteArray(),
                )
            }

            assertEquals(listOf(did), invalidated)
            assertEquals(listOf<Pair<String?, String?>>(null to null), credentialsAtNotification)
            assertNull(it.storage.getSession(did))
            assertEquals(otherSessionId, it.storage.getSession(otherDid))
        }
    }

    @Test
    fun `transient and foreign origin 401 responses do not notify or clear the gateway session`() = runTest {
        val fixture = fixture(HttpClient(MockEngine { error("unexpected request") }))
        fixture.use {
            val invalidated = mutableListOf<String>()
            it.client.onSessionInvalidated = invalidated::add
            val responses = listOf(
                "api.catbird.blue" to """{"error":"temporarilyunavailable"}""",
                "other.example" to """{"error":"invalid_session"}""",
                null to """{"error":"invalid_session"}""",
            )
            for ((host, body) in responses) {
                assertFailsWith<GatewayException.AuthenticationRequired> {
                    it.strategy.handleUnauthorizedResponse(host, body.encodeToByteArray())
                }
                assertSessionRetained(it)
            }
            assertEquals(emptyList(), invalidated)
        }
    }

    @Test
    fun `listener failures cannot suppress terminal expiry or retain network credentials`() = runTest {
        val fixture = fixture(HttpClient(MockEngine { error("unexpected request") }))
        fixture.use {
            var notifiedDid: String? = null
            it.client.onSessionInvalidated = { invalidatedDid ->
                notifiedDid = invalidatedDid
                throw IOException("listener unavailable")
            }

            assertFailsWith<GatewayException.SessionExpired> {
                it.strategy.handleUnauthorizedResponse(
                    "api.catbird.blue", """{"error":"invalid_session"}""".encodeToByteArray(),
                )
            }

            assertEquals(did, notifiedDid)
            assertNull(it.storage.getSession(did))
            assertNull(it.network.authenticatedDID)
            assertNull(it.network.authorizationHeader)
        }
    }

    private suspend fun fixture(http: HttpClient, authenticated: Boolean = true): Fixture {
        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue", client = http)
        val client = ATProtoClient(network)
        val strategy = client.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = http,
        )
        if (authenticated) {
            storage.saveSession(did, sessionId)
            client.gatewayRestoreSession(did)
        }
        return Fixture(storage, network, client, strategy)
    }

    private suspend fun assertSessionRetained(fixture: Fixture) {
        assertEquals(sessionId, fixture.storage.getSession(did))
        assertEquals(did, fixture.storage.getCurrentDid())
        assertEquals(did, fixture.network.authenticatedDID)
        assertEquals("Bearer $sessionId", fixture.network.authorizationHeader)
    }

    private data class Fixture(
        val storage: InMemoryGatewaySessionStorage,
        val network: NetworkService,
        val client: ATProtoClient,
        val strategy: ConfidentialGatewayStrategy,
    ) : AutoCloseable {
        override fun close() = strategy.close()
    }
}
