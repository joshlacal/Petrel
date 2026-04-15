package com.atproto.auth.gateway

import com.atproto.network.NetworkService
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import io.ktor.http.Url
import io.ktor.http.URLBuilder
import io.ktor.http.URLProtocol
import io.ktor.http.parseQueryString
import io.ktor.serialization.kotlinx.json.json
import java.util.logging.Logger
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Session information returned by the gateway's `GET /auth/session` endpoint.
 * Kept intentionally lenient (`handle`/`active` optional) to survive minor
 * server-side shape changes.
 */
@Serializable
data class GatewaySessionResponse(
    val did: String,
    val handle: String? = null,
    val active: Boolean? = null,
)

/** Failure modes for the gateway auth strategy. Mirrors Swift's `GatewayError`. */
sealed class GatewayException(message: String, cause: Throwable? = null) :
    Exception(message, cause) {
    class MissingSession : GatewayException("No gateway session found. Please log in again.")
    class InvalidCallbackUrl : GatewayException("Invalid OAuth callback URL from gateway.")
    class InvalidGatewayUrl : GatewayException("Invalid gateway URL configuration.")
    class InvalidSession : GatewayException("Gateway session is invalid.")
    class SessionExpired : GatewayException("Gateway session has expired. Please log in again.")

    /**
     * 401 surfaced from a non-gateway upstream while in gateway mode. Callers
     * should NOT treat this as a gateway session expiration.
     */
    class AuthenticationRequired : GatewayException("Authentication required.")
    class NetworkError(cause: Throwable) :
        GatewayException("Network error: ${cause.message}", cause)
}

/**
 * Outcome of refresh-token check. Gateway manages refresh server-side, so the
 * only states the client can observe are "session present" (still valid) and
 * "session missing" (throws).
 */
enum class GatewayRefreshOutcome { StillValid }

/** Result of OAuth callback handling — mirrors iOS's `(did, handle, pdsURL)` tuple. */
data class GatewayCallbackResult(
    val did: String,
    val handle: String?,
    val pdsUrl: String,
)

/**
 * Authentication strategy that delegates auth to a confidential gateway (nest).
 * The gateway handles ATProto OAuth (PAR, PKCE, DPoP) and token management.
 * The client only stores a gateway session UUID and attaches it as a Bearer token.
 *
 * Faithful Kotlin port of Swift's `ConfidentialGatewayStrategy` actor.
 * Thread-safe via [Mutex] — all public methods are `suspend`.
 *
 * `prepareAuthenticatedRequest` does not exist as a discrete method on the
 * Kotlin side the way it does on iOS; instead this class drives
 * [NetworkService.authorizationHeader] and [NetworkService.authenticatedDID],
 * which `NetworkService.performRequest` already consults on every outbound
 * request. This matches what the existing generated client was doing and keeps
 * the rest of the SDK unchanged.
 */
class ConfidentialGatewayStrategy(
    gatewayBaseUrl: String,
    private val storage: GatewaySessionStorage,
    private val currentAccount: CurrentAccount,
    private val networkService: NetworkService,
    httpClient: HttpClient? = null,
) {
    private val logger: Logger = Logger.getLogger("ConfidentialGatewayStrategy")

    /**
     * Base URL of the gateway, e.g. `https://api.catbird.blue`. Stored as a
     * parsed ktor [Url] so we can reliably compose paths and compare hosts
     * (see [handleUnauthorizedResponse]).
     */
    private val gatewayUrl: Url = runCatching { Url(gatewayBaseUrl) }
        .getOrElse { throw GatewayException.InvalidGatewayUrl() }

    private val gatewayHost: String = gatewayUrl.host

    /**
     * Dedicated HTTP client for gateway endpoints (`/auth/login`, `/auth/session`,
     * `/auth/logout`). Must NOT share NetworkService's XRPC client because
     * NetworkService.buildUrl hard-codes an `/xrpc/` prefix that breaks these
     * paths.
     */
    private val http: HttpClient = httpClient ?: HttpClient(CIO) {
        install(ContentNegotiation) {
            json(Json {
                isLenient = true
                ignoreUnknownKeys = true
            })
        }
    }

    /** Serializes all mutations of storage / currentAccount / networkService fields. */
    private val mutex = Mutex()

    /** Shared lenient JSON parser — created once per strategy instance. */
    private val json: Json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    // --------------------------------------------------------------------
    // AuthStrategy surface
    // --------------------------------------------------------------------

    /**
     * Build the gateway login URL. The returned URL is bare — we NEVER
     * append `redirect_to` or `client` here; the gateway's own config drives
     * the OAuth flow end-to-end.
     */
    suspend fun startOAuthFlow(identifier: String? = null): String {
        val builder = URLBuilder(gatewayUrl).apply {
            encodedPathSegments = listOf("auth", "login")
            parameters.clear()
            if (identifier != null) {
                parameters.append("identifier", identifier)
            }
        }
        return builder.buildString()
    }

    /**
     * Variant that lets the caller propose a specific PDS host for sign-up.
     */
    suspend fun startOAuthFlowForSignUp(pdsUrl: String? = null): String {
        val builder = URLBuilder(gatewayUrl).apply {
            encodedPathSegments = listOf("auth", "login")
            parameters.clear()
            if (pdsUrl != null) {
                parameters.append("pds", pdsUrl)
            }
        }
        return builder.buildString()
    }

    /**
     * Handle the gateway's redirect back to our app. Parses `session_id` from
     * the URL fragment (the gateway puts NOTHING else in the fragment), then
     * calls `GET {gateway}/auth/session` with that bearer to retrieve the
     * canonical DID / handle.
     */
    suspend fun handleOAuthCallback(callbackUrl: String): GatewayCallbackResult {
        val fragment = extractFragment(callbackUrl)
            ?: throw GatewayException.InvalidCallbackUrl()
        val sessionId = parseSessionIdFromFragment(fragment)
            ?: throw GatewayException.InvalidCallbackUrl()

        // Fetch session details FIRST so we key the local save by the server-
        // authoritative DID.
        val info = fetchSessionFromGateway(sessionId)

        mutex.withLock {
            storage.saveSession(info.did, sessionId)
            currentAccount.setCurrentDid(info.did)
            // Keep NetworkService in lockstep so every subsequent XRPC call
            // attaches the right bearer.
            networkService.authenticatedDID = info.did
            networkService.authorizationHeader = "Bearer $sessionId"
        }

        logger.info("Gateway session established for DID ${info.did.take(20)}…")
        return GatewayCallbackResult(
            did = info.did,
            handle = info.handle,
            pdsUrl = gatewayUrl.toString(),
        )
    }

    /**
     * Best-effort server-side logout, then always clear local state for the
     * current account.
     */
    suspend fun logout() {
        logger.info("Gateway logout initiated")
        val did = currentAccount.getCurrentDid()
        if (did == null) {
            logger.warning("No current account set, nothing to logout")
            return
        }
        val session = storage.getSession(did)
        if (session != null) {
            val logoutUrl = composeGatewayUrl("/auth/logout")
            try {
                val response: HttpResponse = http.post(logoutUrl) {
                    header("Authorization", "Bearer $session")
                    header("Content-Type", "application/json")
                }
                if (response.status != HttpStatusCode.OK) {
                    val body = runCatching { response.bodyAsText() }.getOrDefault("no body")
                    logger.warning("Gateway logout non-200: ${response.status.value} $body")
                }
            } catch (t: Throwable) {
                // Don't fail logout if gateway is unreachable.
                logger.warning("Gateway logout request failed (continuing): ${t.message}")
            }
        } else {
            logger.info("No gateway session for DID ${did.take(20)}…, skipping server logout")
        }

        mutex.withLock {
            storage.deleteSession(did)
            currentAccount.setCurrentDid(null)
            networkService.authenticatedDID = null
            networkService.authorizationHeader = null
        }
        logger.info("Gateway logout complete")
    }

    /**
     * Returns `true` iff a gateway session exists for the current account.
     * Analogue of Swift's `tokensExist()`.
     */
    suspend fun tokensExist(): Boolean {
        val did = currentAccount.getCurrentDid() ?: return false
        return storage.getSession(did) != null
    }

    /**
     * Restore an existing session (e.g. on app launch) and wire NetworkService.
     * Returns the populated [GatewaySessionInfo]-style struct — but as a
     * [GatewayCallbackResult] for symmetry with [handleOAuthCallback].
     */
    suspend fun restoreSession(did: String): String? = mutex.withLock {
        val sessionId = storage.getSession(did) ?: return@withLock null
        currentAccount.setCurrentDid(did)
        networkService.authenticatedDID = did
        networkService.authorizationHeader = "Bearer $sessionId"
        sessionId
    }

    // --------------------------------------------------------------------
    // AuthenticationProvider surface
    // --------------------------------------------------------------------

    /**
     * Look up the current session id and return it. Callers that build raw
     * HTTP requests (outside of NetworkService) can set
     * `Authorization: Bearer {id}` using this value.
     *
     * Throws [GatewayException.MissingSession] if nothing is stored for the
     * current account.
     */
    suspend fun currentSessionId(): String {
        val did = currentAccount.getCurrentDid()
            ?: throw GatewayException.MissingSession()
        return storage.getSession(did) ?: throw GatewayException.MissingSession()
    }

    /**
     * Decorate an existing ktor request builder-style header map with the
     * current gateway bearer. Matches iOS's `prepareAuthenticatedRequest`.
     *
     * Returns a new map with the Authorization header applied so callers can
     * forward it into `NetworkService.performRequest(headers = ...)`.
     */
    suspend fun prepareAuthenticatedHeaders(
        headers: Map<String, String> = emptyMap(),
    ): Map<String, String> {
        val sessionId = currentSessionId()
        return headers + ("Authorization" to "Bearer $sessionId")
    }

    /**
     * Gateway manages refresh automatically — this just confirms we still
     * have a session to attach. Throws [GatewayException.MissingSession] if
     * the account was cleared out from under us (e.g. 401 handler ran).
     */
    suspend fun refreshTokenIfNeeded(): GatewayRefreshOutcome {
        val did = currentAccount.getCurrentDid()
            ?: throw GatewayException.MissingSession()
        if (storage.getSession(did) == null) {
            throw GatewayException.MissingSession()
        }
        return GatewayRefreshOutcome.StillValid
    }

    /**
     * Inspect a 401 and decide whether the gateway session is dead (clear
     * local state + propagate [GatewayException.SessionExpired]) or the 401
     * is transient / from an upstream we shouldn't invalidate on
     * ([GatewayException.AuthenticationRequired]).
     *
     * @param requestHost Host the original request targeted. Only 401s from
     *                    the gateway host itself can clear the session.
     * @param responseBody The raw HTTP response body (may be empty).
     */
    suspend fun handleUnauthorizedResponse(
        requestHost: String?,
        responseBody: ByteArray,
    ): Nothing {
        if (requestHost != null && requestHost == gatewayHost) {
            when (val disposition = classifyUnauthorizedGatewayResponse(responseBody)) {
                is UnauthorizedDisposition.Terminal -> {
                    logger.warning(
                        "Gateway returned terminal auth error (${disposition.reason}) — clearing local session",
                    )
                    clearCurrentGatewaySession()
                    throw GatewayException.SessionExpired()
                }

                is UnauthorizedDisposition.Transient -> {
                    val preview = String(responseBody, Charsets.UTF_8).take(200)
                    logger.warning(
                        "Gateway returned transient 401 (${disposition.reason}) — preserving session. Body: $preview",
                    )
                    throw GatewayException.AuthenticationRequired()
                }
            }
        }

        logger.info("Received 401 from non-gateway host: $requestHost")
        throw GatewayException.AuthenticationRequired()
    }

    // --------------------------------------------------------------------
    // Private helpers
    // --------------------------------------------------------------------

    private sealed class UnauthorizedDisposition {
        data class Terminal(val reason: String) : UnauthorizedDisposition()
        data class Transient(val reason: String) : UnauthorizedDisposition()
    }

    @Serializable
    private data class GatewayErrorResponse(
        val error: String? = null,
        val message: String? = null,
    )

    /**
     * Classify a 401 body from the gateway into terminal vs transient.
     * Strings ported verbatim from Swift to guarantee behavior parity —
     * do NOT "clean up" or localize these; they must match nest's wire
     * responses and Swift's classifier byte-for-byte.
     */
    private fun classifyUnauthorizedGatewayResponse(data: ByteArray): UnauthorizedDisposition {
        if (data.isEmpty()) {
            return UnauthorizedDisposition.Transient("empty_body")
        }

        val responseBody = runCatching { String(data, Charsets.UTF_8) }.getOrDefault("")
        val bodyLower = responseBody.lowercase()

        if (bodyLower.contains("invalid token audience")) {
            return UnauthorizedDisposition.Transient("invalid_audience")
        }

        val payload = runCatching {
            json.decodeFromString(GatewayErrorResponse.serializer(), responseBody)
        }.getOrNull()
        val errorCode = (payload?.error ?: "").lowercase()
        val message = (payload?.message ?: responseBody).lowercase()

        val terminalCodes = setOf(
            "expiredtoken",
            "invalidtoken",
            "session_expired",
            "invalid_session",
            "token_refresh_failed",
        )
        if (errorCode in terminalCodes) {
            return UnauthorizedDisposition.Terminal(errorCode)
        }

        if (errorCode == "authenticationrequired" &&
            message.contains("missing authentication session")
        ) {
            return UnauthorizedDisposition.Terminal("authentication_required_missing_session")
        }

        if (message.contains("session expired") ||
            message.contains("invalid session") ||
            message.contains("please log in again") ||
            message.contains("token refresh rejected")
        ) {
            return UnauthorizedDisposition.Terminal("message_indicates_expiry")
        }

        val transientCodes = setOf(
            "temporarilyunavailable",
            "use_dpop_nonce",
            "upstream_error",
        )
        if (errorCode in transientCodes ||
            message.contains("temporarily unavailable") ||
            message.contains("please retry") ||
            message.contains("timeout")
        ) {
            return UnauthorizedDisposition.Transient(
                if (errorCode.isEmpty()) "transient_message" else errorCode,
            )
        }

        return UnauthorizedDisposition.Transient("unknown_401")
    }

    private suspend fun clearCurrentGatewaySession() = mutex.withLock {
        val did = currentAccount.getCurrentDid()
        if (did == null) {
            logger.warning("No current account available while clearing gateway session")
            return@withLock
        }
        runCatching { storage.deleteSession(did) }.onFailure {
            logger.severe("Failed to delete gateway session during 401 handling: ${it.message}")
        }
        networkService.authenticatedDID = null
        networkService.authorizationHeader = null
    }

    /**
     * Pulls `session_id` out of a URL fragment like `session_id=abc123&foo=bar`.
     * Other keys in the fragment are ignored (nest only puts `session_id`
     * there today, but we tolerate extras).
     */
    internal fun parseSessionIdFromFragment(fragment: String): String? {
        val parsed = runCatching { parseQueryString(fragment) }.getOrNull()
        val fromParser = parsed?.get("session_id")
        if (!fromParser.isNullOrEmpty()) return fromParser

        // Fallback: manual parse matches Swift's `split("&").split("=", 1)`
        // logic for pathological inputs.
        for (pair in fragment.split("&")) {
            val idx = pair.indexOf('=')
            if (idx <= 0) continue
            val key = pair.substring(0, idx)
            val value = pair.substring(idx + 1)
            if (key == "session_id" && value.isNotEmpty()) return value
        }
        return null
    }

    /** GET `{gateway}/auth/session` with the candidate bearer; parse out DID/handle. */
    private suspend fun fetchSessionFromGateway(sessionId: String): GatewaySessionResponse {
        val url = composeGatewayUrl("/auth/session")
        val response: HttpResponse = try {
            http.get(url) {
                header("Authorization", "Bearer $sessionId")
                header("Accept", "application/json")
            }
        } catch (t: Throwable) {
            throw GatewayException.NetworkError(t)
        }

        return when (response.status) {
            HttpStatusCode.OK -> {
                val text = runCatching { response.bodyAsText() }.getOrNull()
                    ?: throw GatewayException.InvalidSession()
                try {
                    json.decodeFromString(GatewaySessionResponse.serializer(), text)
                } catch (_: Throwable) {
                    throw GatewayException.InvalidSession()
                }
            }
            HttpStatusCode.Unauthorized -> throw GatewayException.SessionExpired()
            else -> throw GatewayException.InvalidSession()
        }
    }

    private fun composeGatewayUrl(path: String): String {
        val segments = path.trim('/').split('/').filter { it.isNotEmpty() }
        return URLBuilder(gatewayUrl).apply {
            encodedPathSegments = segments
            parameters.clear()
        }.buildString()
    }

    private fun extractFragment(rawUrl: String): String? {
        val hashIdx = rawUrl.indexOf('#')
        if (hashIdx < 0 || hashIdx == rawUrl.length - 1) return null
        return rawUrl.substring(hashIdx + 1)
    }

    /** Release network resources. Safe to call multiple times. */
    fun close() {
        http.close()
    }
}
