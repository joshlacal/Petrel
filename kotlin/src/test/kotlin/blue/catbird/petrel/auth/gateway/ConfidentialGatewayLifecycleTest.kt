package blue.catbird.petrel.auth.gateway

import blue.catbird.petrel.client.ATProtoClient
import blue.catbird.petrel.client.configureGateway
import blue.catbird.petrel.client.gatewayCheckSession
import blue.catbird.petrel.client.gatewayRestoreSession
import blue.catbird.petrel.client.onSessionInvalidated
import blue.catbird.petrel.network.ATProtoResponse
import blue.catbird.petrel.network.NetworkService
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.HttpRedirect
import io.ktor.client.request.HttpSendPipeline
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.io.IOException
import java.util.logging.Handler
import java.util.logging.LogRecord
import java.util.logging.Logger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
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
                    "Bearer $sessionId",
                    "{\"error\":\"invalid_request\",\"details\":\"$marker\"}".encodeToByteArray(),
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
                    "Bearer $sessionId",
                    "{\"error\":\"invalid_session\"}".encodeToByteArray(),
                )
            }
        }

        assertNull(network.authenticatedDID)
        assertNull(network.authorizationHeader)
        assertFalse(logs.contains(marker), logs)
        assertFalse(logs.contains(sessionId), logs)
    }

    @Test
    fun `restoreSession binds network service to normalized HTTPS gateway origin and refuses cross origin`() = runTest {
        val capturedAuth = mutableListOf<String?>()
        val mockEngine = MockEngine { request ->
            capturedAuth.add(request.headers[HttpHeaders.Authorization])
            respond("""{"message":"ok"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine))
        val storage = InMemoryGatewaySessionStorage()
        val strategy = ConfidentialGatewayStrategy(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            networkService = network,
            httpClient = HttpClient(mockEngine),
        )
        storage.saveSession(did, sessionId)
        strategy.restoreSession(did)

        assertEquals("https", network.authorizedOrigin?.scheme)
        assertEquals("api.catbird.blue", network.authorizedOrigin?.host)
        assertEquals(443, network.authorizedOrigin?.port)

        // Request to authorized gateway origin carries credential
        network.performRequest<Map<String, String>>("GET", "app.bsky.actor.getProfile")
        assertEquals("Bearer $sessionId", capturedAuth[0])

        // Request to cross origin does not carry credential
        network.performRequest<Map<String, String>>("GET", "https://other.service/xrpc/app.bsky.actor.getProfile")
        assertNull(capturedAuth[1], "Cross origin request must not carry gateway bearer token")
    }

    @Test
    fun `suspend auth session response for Alice, switch to Bob then return terminal 401 - Bob session and header must survive`() = runTest {
        val aliceDid = "did:plc:alice"
        val aliceSession = "11111111-e89b-12d3-a456-426614174000"
        val bobDid = "did:plc:bob"
        val bobSession = "22222222-e89b-12d3-a456-426614174000"

        val aliceRequestStarted = CompletableDeferred<Unit>()
        val aliceResponseRelease = CompletableDeferred<Unit>()
        val invalidatedDids = mutableListOf<String>()

        val mockEngine = MockEngine { request ->
            val auth = request.headers[HttpHeaders.Authorization]
            when (auth) {
                "Bearer $aliceSession" -> {
                    aliceRequestStarted.complete(Unit)
                    aliceResponseRelease.await()
                    respond(
                        """{"error":"invalid_session","message":"Session has expired"}""",
                        HttpStatusCode.Unauthorized,
                        headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
                "Bearer $bobSession" -> {
                    respond(
                        """{"did":"$bobDid","handle":"bob.bsky.social","active":true}""",
                        HttpStatusCode.OK,
                        headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
                else -> error("Unexpected auth header: $auth")
            }
        }

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine))
        val client = ATProtoClient(network)
        client.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        client.onSessionInvalidated = { invalidatedDids.add(it) }

        storage.saveSession(aliceDid, aliceSession)
        storage.saveSession(bobDid, bobSession)

        client.gatewayRestoreSession(aliceDid)
        assertEquals(aliceDid, storage.getCurrentDid())
        assertEquals("Bearer $aliceSession", network.authorizationHeader)

        var aliceException: Throwable? = null
        val aliceCheckJob = launch {
            try {
                client.gatewayCheckSession()
            } catch (e: Throwable) {
                aliceException = e
            }
        }

        // Wait until Alice's request has actually reached MockEngine with Alice's bearer
        aliceRequestStarted.await()

        // Switch to Bob while Alice's /auth/session check is in flight
        client.gatewayRestoreSession(bobDid)
        assertEquals(bobDid, storage.getCurrentDid())
        assertEquals("Bearer $bobSession", network.authorizationHeader)

        // Resume Alice's request with terminal 401
        aliceResponseRelease.complete(Unit)
        aliceCheckJob.join()

        // Ensure actual 401 SessionExpired is observed
        assertTrue(aliceException is GatewayException.SessionExpired, "Alice must observe SessionExpired from 401")

        // Bob's active session and network state must survive Alice's terminal 401
        assertEquals(bobSession, storage.getSession(bobDid), "Bob session in storage must survive Alice's 401")
        assertEquals(bobDid, storage.getCurrentDid(), "Current DID must remain Bob")
        assertEquals(bobDid, network.authenticatedDID, "Network authenticatedDID must remain Bob")
        assertEquals("Bearer $bobSession", network.authorizationHeader, "Network authorizationHeader must remain Bob's bearer")
        assertFalse(invalidatedDids.contains(bobDid), "Bob must not be invalidated by Alice's expired session")
    }

    @Test
    fun `same DID new session must survive old 401`() = runTest {
        val aliceOldSession = "11111111-e89b-12d3-a456-426614174000"
        val aliceNewSession = "33333333-e89b-12d3-a456-426614174000"

        val oldRequestStarted = CompletableDeferred<Unit>()
        val oldResponseRelease = CompletableDeferred<Unit>()
        val invalidatedDids = mutableListOf<String>()

        val mockEngine = MockEngine { request ->
            val auth = request.headers[HttpHeaders.Authorization]
            when (auth) {
                "Bearer $aliceOldSession" -> {
                    oldRequestStarted.complete(Unit)
                    oldResponseRelease.await()
                    respond(
                        """{"error":"expiredtoken","message":"Token expired"}""",
                        HttpStatusCode.Unauthorized,
                        headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
                "Bearer $aliceNewSession" -> {
                    respond(
                        """{"did":"$did","handle":"alice.bsky.social","active":true}""",
                        HttpStatusCode.OK,
                        headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
                else -> error("Unexpected auth header: $auth")
            }
        }

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine))
        val client = ATProtoClient(network)
        client.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        client.onSessionInvalidated = { invalidatedDids.add(it) }

        storage.saveSession(did, aliceOldSession)
        client.gatewayRestoreSession(did)

        var oldException: Throwable? = null
        val oldCheckJob = launch {
            try {
                client.gatewayCheckSession()
            } catch (e: Throwable) {
                oldException = e
            }
        }

        // Wait until old session check is in flight
        oldRequestStarted.await()

        // Establish new session for the same DID while old check is in flight
        storage.saveSession(did, aliceNewSession)
        client.gatewayRestoreSession(did)
        assertEquals("Bearer $aliceNewSession", network.authorizationHeader)

        // Old check returns terminal 401
        oldResponseRelease.complete(Unit)
        oldCheckJob.join()

        // Verify old session observed SessionExpired
        assertTrue(oldException is GatewayException.SessionExpired, "Old session must observe SessionExpired from 401")

        // Alice's new session must survive the old session's 401
        assertEquals(aliceNewSession, storage.getSession(did), "New session must survive old session 401")
        assertEquals(did, storage.getCurrentDid())
        assertEquals(did, network.authenticatedDID)
        assertEquals("Bearer $aliceNewSession", network.authorizationHeader, "Network bearer must remain the new session bearer")
    }

    @Test
    fun `transient 401 preserves session consistently with classifier`() = runTest {
        val fixture = authenticatedFixture(HttpClient(MockEngine { error("unexpected request") }))
        var invalidatedCalled = false
        fixture.strategy.onSessionInvalidated = { invalidatedCalled = true }

        val transientBodies = listOf(
            """{"error":"temporarilyunavailable"}""",
            """{"error":"use_dpop_nonce"}""",
            """{"error":"upstream_error"}""",
            """{"message":"temporarily unavailable, please retry"}""",
            """{"error":"something_else","message":"invalid token audience"}""",
            "",
        )

        for (body in transientBodies) {
            assertFailsWith<GatewayException.AuthenticationRequired> {
                fixture.strategy.handleUnauthorizedResponse(
                    "api.catbird.blue",
                    "Bearer $sessionId",
                    body.encodeToByteArray(),
                )
            }

            // Session must remain intact after transient 401
            assertEquals(sessionId, fixture.storage.getSession(did), "Session must be preserved on transient 401 for body: $body")
            assertEquals(did, fixture.storage.getCurrentDid())
            assertEquals(did, fixture.network.authenticatedDID)
            assertEquals("Bearer $sessionId", fixture.network.authorizationHeader)
            assertFalse(invalidatedCalled, "onSessionInvalidated must not be called on transient 401")
        }
    }

    @Test
    fun `old in-flight XRPC 401 after switching account must not invalidate new account`() = runTest {
        val aliceDid = "did:plc:alice"
        val aliceSession = "11111111-e89b-12d3-a456-426614174000"
        val bobDid = "did:plc:bob"
        val bobSession = "22222222-e89b-12d3-a456-426614174000"

        val aliceXrpcStarted = CompletableDeferred<Unit>()
        val aliceXrpcDeferred = CompletableDeferred<Unit>()
        val invalidatedDids = mutableListOf<String>()

        val mockEngine = MockEngine { request ->
            val auth = request.headers[HttpHeaders.Authorization]
            if (auth == "Bearer $aliceSession") {
                aliceXrpcStarted.complete(Unit)
                aliceXrpcDeferred.await()
                respond(
                    """{"error":"expiredtoken","message":"Token expired"}""",
                    HttpStatusCode.Unauthorized,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                respond("""{"ok":"true"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine))
        val client = ATProtoClient(network)
        client.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        client.onSessionInvalidated = { invalidatedDids.add(it) }

        storage.saveSession(aliceDid, aliceSession)
        storage.saveSession(bobDid, bobSession)

        client.gatewayRestoreSession(aliceDid)
        assertEquals("Bearer $aliceSession", network.authorizationHeader)

        // Alice starts an in-flight XRPC call with valid serializer Map<String, String>
        var aliceResponse: ATProtoResponse<Map<String, String>>? = null
        val aliceXrpcCall = launch {
            aliceResponse = network.performRequest<Map<String, String>>("GET", "app.bsky.actor.getProfile")
        }

        // Wait until Alice's request has actually reached MockEngine with Alice's bearer
        aliceXrpcStarted.await()

        // User switches to Bob while Alice's call is in flight
        client.gatewayRestoreSession(bobDid)
        assertEquals(bobDid, storage.getCurrentDid())
        assertEquals(bobDid, network.authenticatedDID)
        assertEquals("Bearer $bobSession", network.authorizationHeader)

        // Alice's XRPC request now returns terminal 401
        aliceXrpcDeferred.complete(Unit)
        aliceXrpcCall.join()

        // Ensure actual 401 response is observed
        assertEquals(401, aliceResponse?.responseCode, "Alice's in-flight request must observe HTTP 401 response")

        // Bob's session, current DID, and network headers must survive Alice's stale 401
        assertEquals(bobSession, storage.getSession(bobDid), "Bob's stored session must survive Alice's XRPC 401")
        assertEquals(bobDid, storage.getCurrentDid(), "Current DID must remain Bob")
        assertEquals(bobDid, network.authenticatedDID, "Network DID must remain Bob")
        assertEquals("Bearer $bobSession", network.authorizationHeader, "Bob's authorization header must not be wiped")
        assertFalse(invalidatedDids.contains(bobDid), "Bob must not be invalidated by Alice's stale XRPC response")
    }

    @Test
    fun `old in-flight XRPC 401 after acquiring new session for same DID must not invalidate new session`() = runTest {
        val aliceOldSession = "11111111-e89b-12d3-a456-426614174000"
        val aliceNewSession = "33333333-e89b-12d3-a456-426614174000"

        val oldXrpcStarted = CompletableDeferred<Unit>()
        val oldXrpcDeferred = CompletableDeferred<Unit>()
        val invalidatedDids = mutableListOf<String>()

        val mockEngine = MockEngine { request ->
            val auth = request.headers[HttpHeaders.Authorization]
            if (auth == "Bearer $aliceOldSession") {
                oldXrpcStarted.complete(Unit)
                oldXrpcDeferred.await()
                respond(
                    """{"error":"expiredtoken","message":"Token expired"}""",
                    HttpStatusCode.Unauthorized,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                respond("""{"ok":"true"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine))
        val client = ATProtoClient(network)
        client.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        client.onSessionInvalidated = { invalidatedDids.add(it) }

        storage.saveSession(did, aliceOldSession)
        client.gatewayRestoreSession(did)

        var oldResponse: ATProtoResponse<Map<String, String>>? = null
        val oldXrpcCall = launch {
            oldResponse = network.performRequest<Map<String, String>>("GET", "app.bsky.actor.getProfile")
        }

        // Wait until old request is actually in flight with old bearer
        oldXrpcStarted.await()

        // Same DID acquires new session
        storage.saveSession(did, aliceNewSession)
        client.gatewayRestoreSession(did)
        assertEquals("Bearer $aliceNewSession", network.authorizationHeader)

        // Old request returns 401
        oldXrpcDeferred.complete(Unit)
        oldXrpcCall.join()

        // Ensure actual 401 response is observed
        assertEquals(401, oldResponse?.responseCode, "Old in-flight request must observe HTTP 401 response")

        // New session must survive
        assertEquals(aliceNewSession, storage.getSession(did), "New session must survive old session XRPC 401")
        assertEquals(did, storage.getCurrentDid())
        assertEquals(did, network.authenticatedDID)
        assertEquals("Bearer $aliceNewSession", network.authorizationHeader)
    }

    @Test
    fun `transient error during checkSession preserves stored session and does not invalidate`() = runTest {
        var invalidatedCalled = false
        val mockEngine = MockEngine { request ->
            val path = request.url.encodedPath
            if (path.endsWith("/auth/session")) {
                respond(
                    """{"error":"temporarily_unavailable","message":"Gateway upstream timeout"}""",
                    HttpStatusCode.ServiceUnavailable,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                respond("""{"ok":"true"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine))
        val client = ATProtoClient(network)
        client.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        client.onSessionInvalidated = { invalidatedCalled = true }

        storage.saveSession(did, sessionId)
        client.gatewayRestoreSession(did)

        // checkSession against 503 Service Unavailable throws GatewayException.InvalidSession
        assertFailsWith<GatewayException.InvalidSession> {
            client.gatewayCheckSession()
        }

        // Stored session and network state must remain intact (transient failure must NOT invalidate)
        assertEquals(sessionId, storage.getSession(did), "Session in storage must be preserved on transient 503")
        assertEquals(did, storage.getCurrentDid(), "Current DID must remain intact")
        assertEquals(did, network.authenticatedDID, "Network authenticated DID must remain intact")
        assertEquals("Bearer $sessionId", network.authorizationHeader, "Network authorization header must remain intact")
        assertFalse(invalidatedCalled, "onSessionInvalidated must not be invoked on transient failure")
    }

    @Test
    fun `network error during checkSession preserves stored session and does not invalidate`() = runTest {
        var invalidatedCalled = false
        val mockEngine = MockEngine {
            throw IOException("Connect timed out to gateway")
        }

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine))
        val client = ATProtoClient(network)
        client.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        client.onSessionInvalidated = { invalidatedCalled = true }

        storage.saveSession(did, sessionId)
        client.gatewayRestoreSession(did)

        assertFailsWith<GatewayException.NetworkError> {
            client.gatewayCheckSession()
        }

        assertEquals(sessionId, storage.getSession(did), "Session in storage must be preserved on network error")
        assertEquals(did, storage.getCurrentDid())
        assertEquals(did, network.authenticatedDID)
        assertEquals("Bearer $sessionId", network.authorizationHeader)
        assertFalse(invalidatedCalled, "onSessionInvalidated must not be invoked on network error")
    }

    @Test
    fun `terminal 401 with missing authorization cannot evict session`() = runTest {
        val fixture = authenticatedFixture(HttpClient(MockEngine { error("unexpected request") }))
        var invalidatedCalled = false
        fixture.strategy.onSessionInvalidated = { invalidatedCalled = true }

        assertFailsWith<GatewayException.SessionExpired> {
            fixture.strategy.handleUnauthorizedResponse(
                "api.catbird.blue",
                null,
                "{\"error\":\"invalid_session\"}".encodeToByteArray(),
            )
        }

        assertEquals(sessionId, fixture.storage.getSession(did), "Missing auth must not evict stored session")
        assertEquals(did, fixture.storage.getCurrentDid())
        assertEquals(did, fixture.network.authenticatedDID)
        assertEquals("Bearer $sessionId", fixture.network.authorizationHeader)
        assertFalse(invalidatedCalled, "Missing auth must not invoke onSessionInvalidated")
    }

    @Test
    fun `checkSession with transient 401 preserves stored session`() = runTest {
        var invalidatedCalled = false
        val mockEngine = MockEngine { request ->
            val path = request.url.encodedPath
            if (path.endsWith("/auth/session")) {
                respond(
                    """{"error":"temporarilyunavailable","message":"Temporary gateway failure"}""",
                    HttpStatusCode.Unauthorized,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                respond("""{"ok":"true"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine))
        val client = ATProtoClient(network)
        client.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        client.onSessionInvalidated = { invalidatedCalled = true }

        storage.saveSession(did, sessionId)
        client.gatewayRestoreSession(did)

        assertFailsWith<GatewayException.AuthenticationRequired> {
            client.gatewayCheckSession()
        }

        assertEquals(sessionId, storage.getSession(did), "Transient 401 must preserve session in storage")
        assertEquals(did, storage.getCurrentDid())
        assertEquals(did, network.authenticatedDID)
        assertEquals("Bearer $sessionId", network.authorizationHeader)
        assertFalse(invalidatedCalled, "Transient 401 must not trigger session invalidation")
    }

    @Test
    fun `cross-origin redirect 401 with stripped auth cannot invalidate unsent gateway token`() = runTest {
        val storage = InMemoryGatewaySessionStorage()
        val mockEngine = MockEngine { request ->
            when (request.url.host) {
                "api.catbird.blue" -> {
                    // Redirect to third-party host
                    respond(
                        content = "",
                        status = HttpStatusCode.Found,
                        headers = headersOf(HttpHeaders.Location, "https://thirdparty.service/xrpc/endpoint")
                    )
                }
                "thirdparty.service" -> {
                    // Third party returns 401 expiredtoken, but auth header was stripped
                    respond(
                        content = """{"error":"expiredtoken","message":"Token expired"}""",
                        status = HttpStatusCode.Unauthorized,
                        headers = headersOf(HttpHeaders.ContentType, "application/json")
                    )
                }
                else -> error("Unexpected host: ${request.url.host}")
            }
        }
        val client = HttpClient(mockEngine) {
            install(HttpRedirect)
        }
        val network = NetworkService("https://api.catbird.blue", client = client)
        val atprotoClient = ATProtoClient(network)
        atprotoClient.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        storage.saveSession(did, sessionId)
        atprotoClient.gatewayRestoreSession(did)

        val resp = network.performRequest<Map<String, String>>("GET", "endpoint")
        assertEquals(401, resp.responseCode)

        // Stored session and network state must remain intact because the 401 was from
        // a third-party host where the gateway token was NOT sent (stripped by Ktor origin sanitization).
        assertEquals(sessionId, storage.getSession(did), "Gateway session must not be evicted by third-party 401 with unsent token")
        assertEquals(did, storage.getCurrentDid())
        assertEquals(did, network.authenticatedDID)
        assertEquals("Bearer $sessionId", network.authorizationHeader)
    }

    @Test
    fun `request-plugin mutation stripping authorization ensures 401 cannot invalidate unsent token`() = runTest {
        val storage = InMemoryGatewaySessionStorage()
        val mockEngine = MockEngine { request ->
            respond(
                content = """{"error":"expiredtoken","message":"Token expired"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }
        // Client with a pipeline interceptor that strips the Authorization header before send
        val client = HttpClient(mockEngine)
        client.sendPipeline.intercept(HttpSendPipeline.State) {
            context.headers.remove(HttpHeaders.Authorization)
        }
        val network = NetworkService("https://api.catbird.blue", client = client)
        val atprotoClient = ATProtoClient(network)
        atprotoClient.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        storage.saveSession(did, sessionId)
        atprotoClient.gatewayRestoreSession(did)

        val resp = network.performRequest<Map<String, String>>("GET", "endpoint")
        assertEquals(401, resp.responseCode)

        // Session must NOT be evicted because the actual outgoing wire request had NO Authorization header!
        assertEquals(sessionId, storage.getSession(did), "Session must not be evicted when Authorization was not sent on the wire")
        assertEquals(did, storage.getCurrentDid())
        assertEquals(did, network.authenticatedDID)
        assertEquals("Bearer $sessionId", network.authorizationHeader)
    }

    @Test
    fun `deterministic latch proves builder uses captured authorization and old 401 cannot invalidate unsent token`() = runTest {
        val oldToken = "old-session-token"
        val unsentToken = "unsent-new-token"
        val storage = InMemoryGatewaySessionStorage()
        var wireAuthHeader: String? = null

        val mockEngine = MockEngine { request ->
            wireAuthHeader = request.headers[HttpHeaders.Authorization]
            respond(
                content = """{"error":"expiredtoken","message":"Token expired"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }
        val network = NetworkService("https://api.catbird.blue", client = HttpClient(mockEngine)).apply {
            authenticatedDID = did
            authorizationHeader = "Bearer $oldToken"
        }
        val atprotoClient = ATProtoClient(network)
        atprotoClient.configureGateway(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            httpClient = HttpClient(mockEngine),
        )
        storage.saveSession(did, unsentToken)

        // Case-insensitive lowercase "authorization" header overrides default header
        val resp = network.performRequest<Map<String, String>>(
            method = "GET",
            endpoint = "endpoint",
            headers = mapOf("authorization" to "Bearer $oldToken")
        )
        assertEquals(401, resp.responseCode)
        assertEquals("Bearer $oldToken", wireAuthHeader, "Wire header must be the exact explicitly provided token")
        // Stored session has unsentToken, so 401 for oldToken must NOT invalidate unsentToken
        assertEquals(unsentToken, storage.getSession(did), "Old 401 must not invalidate unsent token")
    }

    @Test
    fun `pause hydration, logout, resume old callback - no stale credentials, current pointer, or header committed`() = runTest {
        val hydrationStarted = CompletableDeferred<Unit>()
        val hydrationRelease = CompletableDeferred<Unit>()

        val client = HttpClient(MockEngine { request ->
            when (request.url.encodedPath) {
                "/auth/exchange" -> respond(
                    content = """{"session_id":"$sessionId"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json")
                )
                "/auth/session" -> {
                    hydrationStarted.complete(Unit)
                    hydrationRelease.await()
                    respond(
                        content = """{"did":"$did","handle":"alice.test","active":true}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/json")
                    )
                }
                "/auth/logout" -> respond("", HttpStatusCode.OK)
                else -> error("Unexpected request: ${request.url}")
            }
        })

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue")
        val strategy = ConfidentialGatewayStrategy(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            networkService = network,
            httpClient = client,
        )

        strategy.startOAuthFlow("alice.test")

        var callbackException: Throwable? = null
        val callbackJob = launch {
            try {
                strategy.handleOAuthCallback("https://catbird.blue/oauth/callback?code=${"A".repeat(43)}")
            } catch (e: Throwable) {
                callbackException = e
            }
        }

        // Wait until hydration (/auth/session) is paused
        hydrationStarted.await()

        // User logs out while hydration is in flight
        strategy.logout()

        // Resume hydration
        hydrationRelease.complete(Unit)
        callbackJob.join()

        // Old callback must have failed or been aborted
        assertTrue(callbackException is GatewayException, "Callback must fail when invalidated by concurrent logout")

        // No stale credentials, current pointer, or header committed!
        assertNull(storage.getSession(did), "Stale session must not be committed to storage")
        assertNull(storage.getCurrentDid(), "Current DID pointer must remain null after logout")
        assertNull(network.authenticatedDID, "Network authenticated DID must remain null")
        assertNull(network.authorizationHeader, "Network authorization header must remain null")
    }

    @Test
    fun `pause hydration, restore other account, resume old callback - other account survives`() = runTest {
        val aliceDid = "did:plc:alice"
        val aliceSession = "11111111-e89b-12d3-a456-426614174000"
        val bobDid = "did:plc:bob"
        val bobSession = "22222222-e89b-12d3-a456-426614174000"

        val hydrationStarted = CompletableDeferred<Unit>()
        val hydrationRelease = CompletableDeferred<Unit>()

        val client = HttpClient(MockEngine { request ->
            when (request.url.encodedPath) {
                "/auth/exchange" -> respond(
                    content = """{"session_id":"$aliceSession"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json")
                )
                "/auth/session" -> {
                    hydrationStarted.complete(Unit)
                    hydrationRelease.await()
                    respond(
                        content = """{"did":"$aliceDid","handle":"alice.test","active":true}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/json")
                    )
                }
                else -> error("Unexpected request: ${request.url}")
            }
        })

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue")
        val strategy = ConfidentialGatewayStrategy(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            networkService = network,
            httpClient = client,
        )

        // Bob is stored in storage
        storage.saveSession(bobDid, bobSession)

        // Alice starts login
        strategy.startOAuthFlow("alice.test")

        var callbackException: Throwable? = null
        val callbackJob = launch {
            try {
                strategy.handleOAuthCallback("https://catbird.blue/oauth/callback?code=${"A".repeat(43)}")
            } catch (e: Throwable) {
                callbackException = e
            }
        }

        // Wait until hydration (/auth/session) is paused
        hydrationStarted.await()

        // Switch/restore to Bob
        strategy.restoreSession(bobDid)
        assertEquals(bobDid, storage.getCurrentDid())
        assertEquals("Bearer $bobSession", network.authorizationHeader)

        // Resume hydration for Alice
        hydrationRelease.complete(Unit)
        callbackJob.join()

        // Alice's callback must fail due to generation mismatch
        assertTrue(callbackException is GatewayException, "Alice's callback must fail when superseded by restoreSession")

        // Alice credentials must NOT be saved, Bob must remain intact
        assertNull(storage.getSession(aliceDid), "Alice's session must not be committed to storage")
        assertEquals(bobSession, storage.getSession(bobDid), "Bob's session must remain in storage")
        assertEquals(bobDid, storage.getCurrentDid(), "Current DID must remain Bob")
        assertEquals(bobDid, network.authenticatedDID, "Network DID must remain Bob")
        assertEquals("Bearer $bobSession", network.authorizationHeader, "Network authorizationHeader must remain Bob's bearer")
    }

    @Test
    fun `new login survives late old logout`() = runTest {
        val aliceDid = "did:plc:alice"
        val aliceSession = "11111111-e89b-12d3-a456-426614174000"
        val bobDid = "did:plc:bob"
        val bobSession = "22222222-e89b-12d3-a456-426614174000"

        val logoutStarted = CompletableDeferred<Unit>()
        val logoutRelease = CompletableDeferred<Unit>()

        val client = HttpClient(MockEngine { request ->
            when (request.url.encodedPath) {
                "/auth/logout" -> {
                    logoutStarted.complete(Unit)
                    logoutRelease.await()
                    respond("", HttpStatusCode.OK)
                }
                "/auth/exchange" -> respond(
                    content = """{"session_id":"$bobSession"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json")
                )
                "/auth/session" -> respond(
                    content = """{"did":"$bobDid","handle":"bob.test","active":true}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json")
                )
                else -> error("Unexpected request: ${request.url}")
            }
        })

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue")
        val strategy = ConfidentialGatewayStrategy(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            networkService = network,
            httpClient = client,
        )

        // Alice is logged in initially
        storage.saveSession(aliceDid, aliceSession)
        strategy.restoreSession(aliceDid)
        assertEquals(aliceDid, storage.getCurrentDid())
        assertEquals("Bearer $aliceSession", network.authorizationHeader)

        // Start Alice's logout in background
        val logoutJob = launch {
            strategy.logout()
        }

        // Wait until /auth/logout request is in flight
        logoutStarted.await()

        // While logout is paused, Bob logs in!
        strategy.startOAuthFlow("bob.test")
        val bobResult = strategy.handleOAuthCallback("https://catbird.blue/oauth/callback?code=${"B".repeat(43)}")
        assertEquals(bobDid, bobResult.did)
        assertEquals(bobDid, storage.getCurrentDid())
        assertEquals("Bearer $bobSession", network.authorizationHeader)

        // Now release the late logout of Alice
        logoutRelease.complete(Unit)
        logoutJob.join()

        // Bob's new login MUST SURVIVE the late old logout!
        assertEquals(bobSession, storage.getSession(bobDid), "Bob's session must survive late old logout")
        assertEquals(bobDid, storage.getCurrentDid(), "Current DID must remain Bob")
        assertEquals(bobDid, network.authenticatedDID, "Network authenticated DID must remain Bob")
        assertEquals("Bearer $bobSession", network.authorizationHeader, "Network authorization header must remain Bob's bearer")
    }

    @Test
    fun `new login of same account survives late old logout`() = runTest {
        val aliceOldSession = "11111111-e89b-12d3-a456-426614174000"
        val aliceNewSession = "22222222-e89b-12d3-a456-426614174000"

        val logoutStarted = CompletableDeferred<Unit>()
        val logoutRelease = CompletableDeferred<Unit>()

        val client = HttpClient(MockEngine { request ->
            when (request.url.encodedPath) {
                "/auth/logout" -> {
                    logoutStarted.complete(Unit)
                    logoutRelease.await()
                    respond("", HttpStatusCode.OK)
                }
                "/auth/exchange" -> respond(
                    content = """{"session_id":"$aliceNewSession"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json")
                )
                "/auth/session" -> respond(
                    content = """{"did":"$did","handle":"alice.test","active":true}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json")
                )
                else -> error("Unexpected request: ${request.url}")
            }
        })

        val storage = InMemoryGatewaySessionStorage()
        val network = NetworkService("https://api.catbird.blue")
        val strategy = ConfidentialGatewayStrategy(
            gatewayBaseUrl = "https://api.catbird.blue",
            callbackUrl = "https://catbird.blue/oauth/callback",
            storage = storage,
            currentAccount = storage,
            networkService = network,
            httpClient = client,
        )

        // Alice is logged in initially with old session
        storage.saveSession(did, aliceOldSession)
        strategy.restoreSession(did)
        assertEquals(did, storage.getCurrentDid())
        assertEquals("Bearer $aliceOldSession", network.authorizationHeader)

        // Start Alice's logout in background
        val logoutJob = launch {
            strategy.logout()
        }

        // Wait until /auth/logout request is in flight
        logoutStarted.await()

        // While logout is paused, Alice logs in again with a new session!
        strategy.startOAuthFlow("alice.test")
        val result = strategy.handleOAuthCallback("https://catbird.blue/oauth/callback?code=${"A".repeat(43)}")
        assertEquals(did, result.did)
        assertEquals(aliceNewSession, storage.getSession(did))
        assertEquals("Bearer $aliceNewSession", network.authorizationHeader)

        // Now release the late logout of old Alice session
        logoutRelease.complete(Unit)
        logoutJob.join()

        // Alice's new session MUST SURVIVE the late old logout!
        assertEquals(aliceNewSession, storage.getSession(did), "Alice's new session must survive late old logout")
        assertEquals(did, storage.getCurrentDid(), "Current DID must remain Alice")
        assertEquals(did, network.authenticatedDID, "Network authenticated DID must remain Alice")
        assertEquals("Bearer $aliceNewSession", network.authorizationHeader, "Network authorization header must remain new session")
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
