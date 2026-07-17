package blue.catbird.petrel.auth.gateway

import blue.catbird.petrel.network.NetworkService
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.respondError
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import io.ktor.http.parameters
import io.ktor.http.toURI
import java.util.Base64
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest

class ConfidentialGatewayExchangeTest {
    private val callbackUrl = "https://catbird.blue/oauth/callback"
    private val code = "A".repeat(43)
    private val sessionId = "123e4567-e89b-12d3-a456-426614174000"

    @Test
    fun `login carries exact redirect and fresh 32-byte base64url browser nonce`() = runTest {
        val strategy = strategy()

        val first = io.ktor.http.Url(strategy.startOAuthFlow("did:plc:alice"))
        val second = io.ktor.http.Url(strategy.startOAuthFlow("did:plc:alice"))

        assertEquals(callbackUrl, first.parameters["redirect_to"])
        assertEquals("did:plc:alice", first.parameters["identifier"])
        val firstNonce = requireNotNull(first.parameters["browser_nonce"])
        val secondNonce = requireNotNull(second.parameters["browser_nonce"])
        assertEquals(43, firstNonce.length)
        assertEquals(32, Base64.getUrlDecoder().decode(firstNonce).size)
        assertTrue(firstNonce.all { it.isLetterOrDigit() || it == '-' || it == '_' })
        assertNotEquals(firstNonce, secondNonce)
    }

    @Test
    fun `callback exchanges one code with nonce and exact origin then hydrates session`() = runTest {
        val requests = mutableListOf<CapturedRequest>()
        val strategy = strategy(httpClient = exchangeClient(requests))
        val loginUrl = io.ktor.http.Url(strategy.startOAuthFlow("alice.test"))
        val nonce = requireNotNull(loginUrl.parameters["browser_nonce"])

        val result = strategy.handleOAuthCallback("$callbackUrl?code=$code")

        assertEquals("did:plc:alice", result.did)
        assertEquals(2, requests.size)
        assertEquals("/auth/exchange", requests[0].path)
        assertEquals("https://catbird.blue", requests[0].origin)
        assertTrue(requests[0].body.contains("\"code\":\"$code\""))
        assertTrue(requests[0].body.contains("\"browser_nonce\":\"$nonce\""))
        assertFalse(requests[0].body.contains("redirect_to"))
        assertEquals("/auth/session", requests[1].path)
        assertEquals("Bearer $sessionId", requests[1].authorization)
        assertEquals("Bearer $sessionId", strategyNetworkService.authorizationHeader)
        assertEquals("did:plc:alice", strategyStorage.getCurrentDid())
        assertEquals(sessionId, strategyStorage.getSession("did:plc:alice"))
    }

    @Test
    fun `callback must exactly match configured URL and contain one canonical code`() = runTest {
        val requests = mutableListOf<CapturedRequest>()
        val strategy = strategy(httpClient = exchangeClient(requests))
        strategy.startOAuthFlow()

        val invalidCallbacks = listOf(
            "https://catbird.blue.evil/oauth/callback?code=$code",
            "https://catbird.blue/other?code=$code",
            "$callbackUrl?code=$code&code=${"B".repeat(43)}",
            "$callbackUrl?code=short",
            "$callbackUrl?code=${"é".repeat(43)}",
            "$callbackUrl?code=$code&extra=1",
            "$callbackUrl?code=$code#fragment",
        )
        for (callback in invalidCallbacks) {
            assertFailsWith<GatewayException.InvalidCallbackUrl> {
                strategy.handleOAuthCallback(callback)
            }
        }
        assertTrue(requests.isEmpty())
    }

    @Test
    fun `pending nonce is consumed before exchange and failure never falls back`() = runTest {
        var exchangeCount = 0
        val client = HttpClient(MockEngine { request ->
            if (request.url.encodedPath == "/auth/exchange") {
                exchangeCount++
                respond("unauthorized", HttpStatusCode.Unauthorized)
            } else {
                error("legacy session hydration must not run")
            }
        })
        val strategy = strategy(httpClient = client)
        strategy.startOAuthFlow()

        assertFailsWith<GatewayException.InvalidSession> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertFailsWith<GatewayException.InvalidCallbackUrl> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertEquals(1, exchangeCount)
    }

    @Test
    fun `callback without an in-memory pending login fails closed`() = runTest {
        val requests = mutableListOf<CapturedRequest>()
        val strategy = strategy(httpClient = exchangeClient(requests))

        assertFailsWith<GatewayException.InvalidCallbackUrl> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertTrue(requests.isEmpty())
    }

    @Test
    fun `exchange rejects unbounded session credential before hydration or storage`() = runTest {
        val requests = mutableListOf<CapturedRequest>()
        val strategy = strategy(
            httpClient = exchangeClient(requests, exchangeSessionId = "x".repeat(257)),
        )
        strategy.startOAuthFlow()

        assertFailsWith<GatewayException.InvalidSession> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertEquals(listOf("/auth/exchange"), requests.map { it.path })
        assertNull(strategyStorage.getCurrentDid())
        assertNull(strategyNetworkService.authorizationHeader)
    }

    @Test
    fun `exchange rejects unicode session credential before hydration or storage`() = runTest {
        val requests = mutableListOf<CapturedRequest>()
        val strategy = strategy(
            httpClient = exchangeClient(requests, exchangeSessionId = "é".repeat(36)),
        )
        strategy.startOAuthFlow()

        assertFailsWith<GatewayException.InvalidSession> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertEquals(listOf("/auth/exchange"), requests.map { it.path })
        assertNull(strategyStorage.getCurrentDid())
        assertNull(strategyNetworkService.authorizationHeader)
    }

    @Test
    fun `exchange rejects oversized response declared by content length`() = runTest {
        val oversized = "{\"session_id\":\"$sessionId\",\"padding\":\"${"x".repeat(4097)}\"}"
        val client = HttpClient(MockEngine {
            respond(
                content = oversized,
                status = HttpStatusCode.OK,
                headers = headersOf(
                    HttpHeaders.ContentType to listOf("application/json"),
                    HttpHeaders.ContentLength to listOf(oversized.encodeToByteArray().size.toString()),
                ),
            )
        })
        val strategy = strategy(httpClient = client)
        strategy.startOAuthFlow()

        assertFailsWith<GatewayException.InvalidSession> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertNull(strategyNetworkService.authorizationHeader)
    }

    @Test
    fun `exchange rejects oversized response without content length`() = runTest {
        val client = HttpClient(MockEngine {
            respond(
                content = "{\"session_id\":\"$sessionId\",\"padding\":\"${"x".repeat(4097)}\"}",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        })
        val strategy = strategy(httpClient = client)
        strategy.startOAuthFlow()

        assertFailsWith<GatewayException.InvalidSession> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertNull(strategyNetworkService.authorizationHeader)
    }

    @Test
    fun `session hydration rejects oversized response without content length`() = runTest {
        val client = HttpClient(MockEngine { request ->
            when (request.url.encodedPath) {
                "/auth/exchange" -> respond(
                    content = "{\"session_id\":\"$sessionId\"}",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
                "/auth/session" -> respond(
                    content = "{\"did\":\"did:plc:alice\",\"padding\":\"${"x".repeat(8193)}\"}",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
                else -> respondError(HttpStatusCode.NotFound)
            }
        })
        val strategy = strategy(httpClient = client)
        strategy.startOAuthFlow()

        assertFailsWith<GatewayException.InvalidSession> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertNull(strategyStorage.getCurrentDid())
        assertNull(strategyNetworkService.authorizationHeader)
    }

    @Test
    fun `gateway requests time out and do not install credentials`() = runTest {
        val client = HttpClient(MockEngine {
            delay(60_000)
            respond("{}", HttpStatusCode.OK)
        })
        val strategy = strategy(httpClient = client, requestTimeoutMillis = 100)
        strategy.startOAuthFlow()

        assertFailsWith<GatewayException.NetworkError> {
            strategy.handleOAuthCallback("$callbackUrl?code=$code")
        }
        assertNull(strategyStorage.getCurrentDid())
        assertNull(strategyNetworkService.authorizationHeader)
    }

    @Test
    fun `simultaneous callbacks consume nonce once and send one exchange request`() = runTest {
        val exchangeStarted = CompletableDeferred<Unit>()
        val releaseExchange = CompletableDeferred<Unit>()
        val exchangeCount = AtomicInteger()
        val client = HttpClient(MockEngine { request ->
            when (request.url.encodedPath) {
                "/auth/exchange" -> {
                    exchangeCount.incrementAndGet()
                    exchangeStarted.complete(Unit)
                    releaseExchange.await()
                    respond(
                        content = "{\"session_id\":\"$sessionId\"}",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
                "/auth/session" -> respond(
                    content = "{\"did\":\"did:plc:alice\"}",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
                else -> error("unexpected request ${request.url}")
            }
        })
        val strategy = strategy(httpClient = client)
        strategy.startOAuthFlow()

        val first = async { runCatching { strategy.handleOAuthCallback("$callbackUrl?code=$code") } }
        exchangeStarted.await()
        val second = async { runCatching { strategy.handleOAuthCallback("$callbackUrl?code=$code") } }
        assertTrue(second.await().exceptionOrNull() is GatewayException.InvalidCallbackUrl)
        releaseExchange.complete(Unit)
        assertTrue(first.await().isSuccess)
        assertEquals(1, exchangeCount.get())
    }

    @Test
    fun `configured callback rejects credentials fragments and insecure public origins`() {
        for (invalid in listOf(
            "https://user@catbird.blue/oauth/callback",
            "https://catbird.blue/oauth/callback#fragment",
            "http://catbird.blue/oauth/callback",
            "https://catbird.blue:444/oauth/callback",
        )) {
            assertFailsWith<GatewayException.InvalidCallbackUrl> {
                strategy(callbackUrl = invalid)
            }
        }
    }

    private lateinit var strategyStorage: InMemoryGatewaySessionStorage
    private lateinit var strategyNetworkService: NetworkService

    private fun strategy(
        callbackUrl: String = this.callbackUrl,
        httpClient: HttpClient = HttpClient(MockEngine { error("unexpected request") }),
        requestTimeoutMillis: Long = 10_000,
    ): ConfidentialGatewayStrategy {
        strategyStorage = InMemoryGatewaySessionStorage()
        strategyNetworkService = NetworkService("https://api.catbird.blue")
        return ConfidentialGatewayStrategy(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = callbackUrl,
            storage = strategyStorage,
            currentAccount = strategyStorage,
            networkService = strategyNetworkService,
            httpClient = httpClient,
            requestTimeoutMillis = requestTimeoutMillis,
        )
    }

    private fun exchangeClient(
        requests: MutableList<CapturedRequest>,
        exchangeSessionId: String = sessionId,
    ): HttpClient = HttpClient(MockEngine { request ->
        requests += CapturedRequest(
            path = request.url.encodedPath,
            origin = request.headers[HttpHeaders.Origin],
            authorization = request.headers[HttpHeaders.Authorization],
            body = (request.body as? OutgoingContent.ByteArrayContent)
                ?.bytes()
                ?.decodeToString()
                .orEmpty(),
        )
        when (request.url.encodedPath) {
            "/auth/exchange" -> respond(
                content = "{\"session_id\":\"$exchangeSessionId\"}",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
            "/auth/session" -> respond(
                content = "{\"did\":\"did:plc:alice\",\"handle\":\"alice.test\"}",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
            else -> error("unexpected request ${request.url.toURI()}")
        }
    })

    private data class CapturedRequest(
        val path: String,
        val origin: String?,
        val authorization: String?,
        val body: String,
    )
}
