package blue.catbird.petrel.auth.gateway

import blue.catbird.petrel.network.NetworkService
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import java.io.IOException
import java.util.logging.Handler
import java.util.logging.LogRecord
import java.util.logging.Logger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlinx.coroutines.test.runTest

class ConfidentialGatewayLifecycleTest {
    private val did = "did:plc:alice"
    private val sessionId = "123e4567-e89b-12d3-a456-426614174000"

    @Test
    fun `restore wires stored session into current account and network service`() = runTest {
        val fixture = fixture(HttpClient(MockEngine { error("unexpected request") }))
        fixture.storage.saveSession(did, sessionId)

        assertEquals(sessionId, fixture.strategy.restoreSession(did))
        assertEquals(did, fixture.storage.getCurrentDid())
        assertEquals(did, fixture.network.authenticatedDID)
        assertEquals("Bearer $sessionId", fixture.network.authorizationHeader)
    }

    @Test
    fun `logout success clears all local credential state`() = runTest {
        val fixture = authenticatedFixture(HttpClient(MockEngine {
            respond("", HttpStatusCode.OK)
        }))

        fixture.strategy.logout()

        assertLocallyLoggedOut(fixture)
    }

    @Test
    fun `logout non success clears local state without logging response secrets`() = runTest {
        val fixture = authenticatedFixture(HttpClient(MockEngine {
            respond("upstream echoed $sessionId", HttpStatusCode.BadGateway)
        }))
        val logs = captureLogs {
            fixture.strategy.logout()
        }

        assertLocallyLoggedOut(fixture)
        assertFalse(logs.contains(sessionId), logs)
    }

    @Test
    fun `logout network failure clears local state without logging exception secrets`() = runTest {
        val fixture = authenticatedFixture(HttpClient(MockEngine {
            throw IOException("network failed for bearer $sessionId")
        }))
        val logs = captureLogs {
            fixture.strategy.logout()
        }

        assertLocallyLoggedOut(fixture)
        assertFalse(logs.contains(sessionId), logs)
    }

    @Test
    fun `logout clears stale network bearer when current DID is missing`() = runTest {
        val fixture = fixture(HttpClient(MockEngine { error("unexpected request") }))
        fixture.network.authenticatedDID = did
        fixture.network.authorizationHeader = "Bearer $sessionId"

        fixture.strategy.logout()

        assertNull(fixture.network.authenticatedDID)
        assertNull(fixture.network.authorizationHeader)
    }

    @Test
    fun `logout clears network bearer independently when storage cleanup throws`() = runTest {
        val storage = ThrowingStorage(
            currentDid = did,
            sessionId = sessionId,
            deleteFailure = IOException("delete failed with $sessionId"),
            setCurrentFailure = IOException("selection failed with $sessionId"),
        )
        val network = NetworkService("https://api.catbird.blue").apply {
            authenticatedDID = did
            authorizationHeader = "Bearer $sessionId"
        }
        val strategy = ConfidentialGatewayStrategy(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            networkService = network,
            httpClient = HttpClient(MockEngine { respond("", HttpStatusCode.OK) }),
        )

        val logs = captureLogs { strategy.logout() }

        assertNull(network.authenticatedDID)
        assertNull(network.authorizationHeader)
        assertFalse(logs.contains(sessionId), logs)
    }

    @Test
    fun `transient 401 does not log sensitive response body`() = runTest {
        val fixture = authenticatedFixture(HttpClient(MockEngine { error("unexpected request") }))
        val marker = "sensitive-upstream-body-$sessionId"

        val logs = captureLogs {
            assertFailsWith<GatewayException.AuthenticationRequired> {
                fixture.strategy.handleUnauthorizedResponse(
                    "api.catbird.blue",
                    "temporarily unavailable $marker".encodeToByteArray(),
                )
            }
        }

        assertFalse(logs.contains(marker), logs)
        assertFalse(logs.contains(sessionId), logs)
    }

    @Test
    fun `terminal 401 storage failure logs only error class`() = runTest {
        val marker = "sensitive-storage-message-$sessionId"
        val storage = ThrowingStorage(
            currentDid = did,
            sessionId = sessionId,
            deleteFailure = IOException(marker),
        )
        val network = NetworkService("https://api.catbird.blue").apply {
            authenticatedDID = did
            authorizationHeader = "Bearer $sessionId"
        }
        val strategy = ConfidentialGatewayStrategy(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            networkService = network,
            httpClient = HttpClient(MockEngine { error("unexpected request") }),
        )

        val logs = captureLogs {
            assertFailsWith<GatewayException.SessionExpired> {
                strategy.handleUnauthorizedResponse(
                    "api.catbird.blue",
                    "{\"error\":\"invalid_session\"}".encodeToByteArray(),
                )
            }
        }

        assertNull(network.authenticatedDID)
        assertNull(network.authorizationHeader)
        assertFalse(logs.contains(marker), logs)
        assertFalse(logs.contains(sessionId), logs)
    }

    private suspend fun authenticatedFixture(client: HttpClient): Fixture {
        val fixture = fixture(client)
        fixture.storage.saveSession(did, sessionId)
        fixture.strategy.restoreSession(did)
        return fixture
    }

    private fun fixture(client: HttpClient): Fixture {
        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue")
        return Fixture(
            storage,
            network,
            ConfidentialGatewayStrategy(
                gatewayBaseUrl = "https://api.catbird.blue",
                callbackUrl = "https://catbird.blue/oauth/callback",
                storage = storage,
                currentAccount = storage,
                networkService = network,
                httpClient = client,
            ),
        )
    }

    private suspend fun assertLocallyLoggedOut(fixture: Fixture) {
        assertNull(fixture.storage.getSession(did))
        assertNull(fixture.storage.getCurrentDid())
        assertNull(fixture.network.authenticatedDID)
        assertNull(fixture.network.authorizationHeader)
    }

    private suspend fun captureLogs(block: suspend () -> Unit): String {
        val records = mutableListOf<String>()
        val logger = Logger.getLogger("ConfidentialGatewayStrategy")
        val handler = object : Handler() {
            override fun publish(record: LogRecord) { records += record.message }
            override fun flush() = Unit
            override fun close() = Unit
        }
        logger.addHandler(handler)
        return try {
            block()
            records.joinToString("\n")
        } finally {
            logger.removeHandler(handler)
        }
    }

    private data class Fixture(
        val storage: InMemoryGatewaySessionStorage,
        val network: NetworkService,
        val strategy: ConfidentialGatewayStrategy,
    )

    private class ThrowingStorage(
        private var currentDid: String?,
        private var sessionId: String?,
        private val deleteFailure: Throwable? = null,
        private val setCurrentFailure: Throwable? = null,
    ) : GatewaySessionStorage, CurrentAccount {
        override suspend fun saveSession(did: String, sessionId: String) {
            this.sessionId = sessionId
        }

        override suspend fun getSession(did: String): String? = sessionId

        override suspend fun deleteSession(did: String) {
            deleteFailure?.let { throw it }
            sessionId = null
        }

        override suspend fun getAllDids(): List<String> = listOfNotNull(currentDid)

        override suspend fun getCurrentDid(): String? = currentDid

        override suspend fun setCurrentDid(did: String?) {
            setCurrentFailure?.let { throw it }
            currentDid = did
        }
    }
}
