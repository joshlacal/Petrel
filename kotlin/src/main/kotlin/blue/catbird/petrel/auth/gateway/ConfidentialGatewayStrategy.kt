package blue.catbird.petrel.auth.gateway

import blue.catbird.petrel.network.NetworkService
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsChannel
import io.ktor.http.HttpStatusCode
import io.ktor.http.HttpHeaders
import io.ktor.http.Url
import io.ktor.http.URLBuilder
import io.ktor.http.URLProtocol
import io.ktor.serialization.kotlinx.json.json
import io.ktor.utils.io.readRemaining
import java.net.URI
import java.security.SecureRandom
import java.util.Base64
import java.util.logging.Logger
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.io.readByteArray
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

@Serializable
private data class GatewayExchangeRequest(
    val code: String,
    val browser_nonce: String,
)

@Serializable
private data class GatewayExchangeResponse(
    val session_id: String,
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
    callbackUrl: String,
    private val storage: GatewaySessionStorage,
    private val currentAccount: CurrentAccount,
    private val networkService: NetworkService,
    httpClient: HttpClient? = null,
    private val requestTimeoutMillis: Long = DEFAULT_GATEWAY_REQUEST_TIMEOUT_MILLIS,
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

    private val callback: CallbackConfiguration = validateCallbackUrl(callbackUrl)

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

    /** A login nonce deliberately has no persistence beyond this process. */
    private var pendingBrowserNonce: String? = null

    /** Shared lenient JSON parser — created once per strategy instance. */
    private val json: Json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    // --------------------------------------------------------------------
    // AuthStrategy surface
    // --------------------------------------------------------------------

    /**
     * Build the gateway login URL with the exact configured callback and a
     * per-login nonce retained only in this strategy instance.
     */
    suspend fun startOAuthFlow(identifier: String? = null): String {
        return buildLoginUrl("identifier", identifier)
    }

    /**
     * Variant that lets the caller propose a specific PDS host for sign-up.
     */
    suspend fun startOAuthFlowForSignUp(pdsUrl: String? = null): String {
        return buildLoginUrl("pds", pdsUrl)
    }

    private suspend fun buildLoginUrl(optionalKey: String, optionalValue: String?): String {
        val nonceBytes = newSecureNonce()
        val nonce = Base64.getUrlEncoder().withoutPadding().encodeToString(nonceBytes)
        mutex.withLock { pendingBrowserNonce = nonce }

        val builder = URLBuilder(gatewayUrl).apply {
            encodedPathSegments = listOf("auth", "login")
            parameters.clear()
            parameters.append("browser_nonce", nonce)
            parameters.append("redirect_to", callback.target)
            if (optionalValue != null) {
                parameters.append(optionalKey, optionalValue)
            }
        }
        return builder.buildString()
    }

    /**
     * Redeem the single-use callback code, then hydrate the session using the
     * existing authenticated `/auth/session` endpoint.
     */
    suspend fun handleOAuthCallback(callbackUrl: String): GatewayCallbackResult {
        val code = parseCallbackCode(callbackUrl)
        // Consume before the first suspension/network boundary. A failed or
        // cancelled exchange can never retry with the same browser binding.
        val browserNonce = mutex.withLock {
            pendingBrowserNonce.also { pendingBrowserNonce = null }
        } ?: throw GatewayException.InvalidCallbackUrl()
        val sessionId = exchangeCode(code, browserNonce)

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
        val did = runCatching { currentAccount.getCurrentDid() }
            .onFailure { logCleanupFailure("read current account", it) }
            .getOrNull()
        try {
            val session = if (did != null) {
                runCatching { storage.getSession(did) }
                    .onFailure { logCleanupFailure("read gateway session", it) }
                    .getOrNull()
            } else {
                logger.warning("No current account set; clearing any stale local credentials")
                null
            }
            if (session != null) {
                val logoutUrl = composeGatewayUrl("/auth/logout")
                try {
                    val response: HttpResponse = http.post(logoutUrl) {
                        header("Authorization", "Bearer $session")
                        header("Content-Type", "application/json")
                    }
                    if (response.status != HttpStatusCode.OK) {
                        logger.warning("Gateway logout returned HTTP ${response.status.value}")
                    }
                } catch (t: Throwable) {
                    // Don't fail logout if gateway is unreachable.
                    logger.warning("Gateway logout request failed; clearing local state")
                }
            } else if (did != null) {
                logger.info("No gateway session for selected DID; clearing local state")
            }
        } finally {
            clearLogoutState(did)
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
                    logger.warning(
                        "Gateway returned transient 401 (${disposition.reason}) — preserving session",
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

    private suspend fun clearLogoutState(did: String?) = mutex.withLock {
        try {
            if (did != null) {
                runCatching { storage.deleteSession(did) }
                    .onFailure { logCleanupFailure("delete gateway session", it) }
            }
            runCatching { currentAccount.setCurrentDid(null) }
                .onFailure { logCleanupFailure("clear current account", it) }
        } finally {
            networkService.authenticatedDID = null
            networkService.authorizationHeader = null
        }
    }

    private suspend fun clearCurrentGatewaySession() = mutex.withLock {
        try {
            val did = runCatching { currentAccount.getCurrentDid() }
                .onFailure { logCleanupFailure("read current account during 401 handling", it) }
                .getOrNull()
            if (did == null) {
                logger.warning("No current account available while clearing gateway session")
            } else {
                runCatching { storage.deleteSession(did) }
                    .onFailure { logCleanupFailure("delete gateway session during 401 handling", it) }
            }
        } finally {
            networkService.authenticatedDID = null
            networkService.authorizationHeader = null
        }
    }

    private fun logCleanupFailure(operation: String, failure: Throwable) {
        logger.severe("Failed to $operation (${failure::class.simpleName ?: "Throwable"})")
    }

    private fun parseCallbackCode(rawUrl: String): String {
        val uri = runCatching { URI(rawUrl) }
            .getOrElse { throw GatewayException.InvalidCallbackUrl() }
        if (uri.rawUserInfo != null || uri.rawFragment != null ||
            uri.scheme?.lowercase() != callback.scheme ||
            uri.host?.lowercase() != callback.host ||
            normalizedPort(uri) != callback.port ||
            (uri.rawPath.ifEmpty { "/" }) != callback.path
        ) {
            throw GatewayException.InvalidCallbackUrl()
        }
        val query = uri.rawQuery ?: throw GatewayException.InvalidCallbackUrl()
        val pairs = query.split('&')
        if (pairs.size != 1) throw GatewayException.InvalidCallbackUrl()
        val pair = pairs.single().split('=', limit = 2)
        if (pair.size != 2 || pair[0] != "code") throw GatewayException.InvalidCallbackUrl()
        val code = pair[1]
        if (code.length != EXCHANGE_CODE_LENGTH || !code.all(::isBase64UrlCharacter)) {
            throw GatewayException.InvalidCallbackUrl()
        }
        return code
    }

    private suspend fun exchangeCode(code: String, browserNonce: String): String {
        val response = try {
            withContext(Dispatchers.IO) {
                withTimeout(requestTimeoutMillis) {
                    http.post(composeGatewayUrl("/auth/exchange")) {
                        header("Origin", callback.origin)
                        header("Content-Type", "application/json")
                        header("Accept", "application/json")
                        setBody(
                            json.encodeToString(
                                GatewayExchangeRequest.serializer(),
                                GatewayExchangeRequest(code, browserNonce),
                            ),
                        )
                    }
                }
            }
        } catch (t: Throwable) {
            throw GatewayException.NetworkError(t)
        }
        if (response.status != HttpStatusCode.OK) throw GatewayException.InvalidSession()
        val payload = runCatching {
            json.decodeFromString(
                GatewayExchangeResponse.serializer(),
                readBoundedBody(response, MAX_EXCHANGE_RESPONSE_BYTES),
            )
        }.getOrElse { throw GatewayException.InvalidSession() }
        return payload.session_id.takeIf(::isValidSessionId)
            ?: throw GatewayException.InvalidSession()
    }

    /** GET `{gateway}/auth/session` with the candidate bearer; parse out DID/handle. */
    private suspend fun fetchSessionFromGateway(sessionId: String): GatewaySessionResponse {
        val url = composeGatewayUrl("/auth/session")
        val response: HttpResponse = try {
            withContext(Dispatchers.IO) {
                withTimeout(requestTimeoutMillis) {
                    http.get(url) {
                        header("Authorization", "Bearer $sessionId")
                        header("Accept", "application/json")
                    }
                }
            }
        } catch (t: Throwable) {
            throw GatewayException.NetworkError(t)
        }

        return when (response.status) {
            HttpStatusCode.OK -> {
                val text = runCatching {
                    readBoundedBody(response, MAX_SESSION_RESPONSE_BYTES)
                }.getOrNull()
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

    private suspend fun readBoundedBody(response: HttpResponse, maxBytes: Long): String {
        return withContext(Dispatchers.IO) {
            withTimeout(requestTimeoutMillis) {
                val declaredLength = response.headers[HttpHeaders.ContentLength]?.toLongOrNull()
                if (declaredLength != null && declaredLength > maxBytes) {
                    throw IllegalArgumentException("Gateway response exceeded size limit")
                }
                val packet = response.bodyAsChannel().readRemaining(maxBytes + 1)
                val bytes = packet.readByteArray()
                if (bytes.size > maxBytes) {
                    throw IllegalArgumentException("Gateway response exceeded size limit")
                }
                bytes.decodeToString()
            }
        }
    }

    private fun composeGatewayUrl(path: String): String {
        val segments = path.trim('/').split('/').filter { it.isNotEmpty() }
        return URLBuilder(gatewayUrl).apply {
            encodedPathSegments = segments
            parameters.clear()
        }.buildString()
    }

    /** Release network resources. Safe to call multiple times. */
    fun close() {
        http.close()
    }

    private data class CallbackConfiguration(
        val target: String,
        val scheme: String,
        val host: String,
        val port: Int,
        val path: String,
        val origin: String,
    )

    companion object {
        private const val NONCE_BYTE_COUNT = 32
        private const val EXCHANGE_CODE_LENGTH = 43
        private const val MIN_SESSION_ID_LENGTH = 16
        private const val MAX_SESSION_ID_LENGTH = 256
        private const val MAX_EXCHANGE_RESPONSE_BYTES = 4_096L
        private const val MAX_SESSION_RESPONSE_BYTES = 8_192L
        private const val DEFAULT_GATEWAY_REQUEST_TIMEOUT_MILLIS = 10_000L
        private val secureRandom = SecureRandom()

        private fun newSecureNonce(): ByteArray =
            ByteArray(NONCE_BYTE_COUNT).also(secureRandom::nextBytes)

        private fun isBase64UrlCharacter(character: Char): Boolean =
            character in 'A'..'Z' ||
                character in 'a'..'z' ||
                character in '0'..'9' ||
                character == '-' ||
                character == '_'

        private fun isValidSessionId(value: String): Boolean =
            value.length in MIN_SESSION_ID_LENGTH..MAX_SESSION_ID_LENGTH &&
                value.all {
                    isBase64UrlCharacter(it) || it == '.' || it == '~'
                }

        private fun validateCallbackUrl(rawUrl: String): CallbackConfiguration {
            val uri = runCatching { URI(rawUrl) }
                .getOrElse { throw GatewayException.InvalidCallbackUrl() }
            val scheme = uri.scheme?.lowercase() ?: throw GatewayException.InvalidCallbackUrl()
            val host = uri.host?.lowercase() ?: throw GatewayException.InvalidCallbackUrl()
            if (uri.rawUserInfo != null || uri.rawQuery != null || uri.rawFragment != null) {
                throw GatewayException.InvalidCallbackUrl()
            }
            val port = normalizedPort(uri)
            val allowed = when (scheme) {
                "https" -> port == 443
                "http" -> host in setOf("127.0.0.1", "::1") && uri.port in 1..65535
                else -> false
            }
            if (!allowed) throw GatewayException.InvalidCallbackUrl()
            val path = uri.rawPath.ifEmpty { "/" }
            val authorityHost = if (host.contains(':')) "[$host]" else host
            val origin = when {
                scheme == "https" -> "https://$authorityHost"
                else -> "http://$authorityHost:${uri.port}"
            }
            return CallbackConfiguration(rawUrl, scheme, host, port, path, origin)
        }

        private fun normalizedPort(uri: URI): Int = when {
            uri.port >= 0 -> uri.port
            uri.scheme.equals("https", ignoreCase = true) -> 443
            uri.scheme.equals("http", ignoreCase = true) -> 80
            else -> -1
        }
    }
}
