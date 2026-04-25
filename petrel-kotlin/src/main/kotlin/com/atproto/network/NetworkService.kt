package com.atproto.network

import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.plugins.logging.*
import io.ktor.client.request.*
import io.ktor.client.call.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.json.Json

data class ATProtoResponse<T>(
    val responseCode: Int,
    val data: T?,
    val errorBody: String? = null
)

class NetworkService(
    private val baseUrl: String = "https://bsky.social"
) {
    @PublishedApi
    internal val serviceDIDs = mutableMapOf<String, String>()
    var authenticatedDID: String? = null
    var authorizationHeader: String? = null

    /**
     * Host of [baseUrl], cached once so [performRequest] can cheaply tag every
     * response with the origin it came from. Used by gateway auth strategies
     * that only want to invalidate sessions on 401s from the gateway itself.
     */
    @PublishedApi
    internal val baseUrlHost: String? = runCatching { Url(baseUrl).host }.getOrNull()

    /**
     * Called on every non-2xx response with HTTP 401. Lets an attached auth
     * strategy (e.g. `ConfidentialGatewayStrategy.handleUnauthorizedResponse`)
     * classify the 401, optionally clear its local session, and throw a typed
     * exception. `performRequest` swallows any exception this throws and
     * continues to return the 401 to the caller — the handler's only job is
     * to keep persistent auth state consistent with the server's verdict.
     */
    var unauthorizedHandler: (suspend (host: String?, body: ByteArray) -> Unit)? = null

    fun setServiceDID(did: String, namespace: String) {
        serviceDIDs[namespace] = did
    }

    fun getDid(): String? = authenticatedDID

    fun getBaseUrl(): String = baseUrl

    @PublishedApi
    internal val client = HttpClient(CIO) {
        install(ContentNegotiation) {
            json(Json {
                prettyPrint = true
                isLenient = true
                ignoreUnknownKeys = true
            })
        }
        install(Logging) {
            logger = Logger.DEFAULT
            level = LogLevel.INFO
        }
    }

    suspend inline fun <reified T> performRequest(
        method: String,
        endpoint: String,
        queryParams: Map<String, String>? = null,
        headers: Map<String, String> = emptyMap(),
        body: Any? = null,
        queryItems: Any? = null
    ): ATProtoResponse<T> {
        // Canonical shape: List<Pair<String, String>> preserves repeated keys
        // (needed for ATProto query params like `actors=did:plc:aaa&actors=did:plc:bbb`
        // used by getProfiles, getKeyPackages, etc.). Previously this was collapsed
        // via List.toMap() which silently dropped all but the last repeat — leading
        // to empty/partial responses for any XRPC method with a list parameter.
        @Suppress("UNCHECKED_CAST")
        val resolvedQueryItems: List<Pair<String, String>>? = when (queryItems) {
            is List<*> -> queryItems as? List<Pair<String, String>>
            is Map<*, *> -> (queryItems as? Map<String, String>)?.map { (k, v) -> k to v }
            else -> null
        }
        val resolvedParams: List<Pair<String, String>>? = queryParams
            ?.map { (k, v) -> k to v }
            ?: resolvedQueryItems
        try {
            val response: HttpResponse = client.request(buildUrl(endpoint, resolvedParams)) {
                this.method = HttpMethod.parse(method)

                // Inject stored auth header if no explicit Authorization provided
                if (!headers.containsKey("Authorization") && authorizationHeader != null) {
                    header("Authorization", authorizationHeader!!)
                }

                headers.forEach { (key, value) ->
                    header(key, value)
                }

                // Add atproto-proxy header if applicable
                serviceDIDs.forEach { (namespace, did) ->
                    if (endpoint.startsWith(namespace)) {
                        header("atproto-proxy", did)
                    }
                }

                body?.let {
                    when (it) {
                        is String -> setBody(it)
                        is ByteArray -> setBody(it)
                        else -> setBody(it)
                    }
                }
            }

            val statusCode = response.status.value

            return if (statusCode in 200..299) {
                try {
                    val data = response.body<T>()
                    ATProtoResponse(statusCode, data)
                } catch (e: Exception) {
                    System.err.println("[NetworkService] Deserialization failed for $endpoint: ${e.message}")
                    e.printStackTrace()
                    ATProtoResponse(statusCode, null)
                }
            } else {
                val errorText = try { response.bodyAsText() } catch (_: Exception) { null }
                if (statusCode == 401) {
                    unauthorizedHandler?.let { handler ->
                        // The strategy throws GatewayException.SessionExpired or
                        // AuthenticationRequired to signal classification. Swallow
                        // either — the 401 response body is still the source of
                        // truth returned below; the handler's side-effect of
                        // clearing the stale session is what we actually care about.
                        try {
                            handler(baseUrlHost, errorText?.toByteArray() ?: ByteArray(0))
                        } catch (_: Throwable) {
                            // no-op; classifier always throws, that's the contract
                        }
                    }
                }
                ATProtoResponse(statusCode, null, errorBody = errorText)
            }
        } catch (e: Exception) {
            // Network error
            return ATProtoResponse(0, null)
        }
    }

    suspend fun getServiceDID(endpoint: String): String? {
        // Placeholder - implement service DID resolution
        return null
    }

    @PublishedApi
    internal fun buildUrl(endpoint: String, queryParams: List<Pair<String, String>>?): String {
        val url = URLBuilder(baseUrl).apply {
            path("xrpc", endpoint)
            // parameters.append preserves repeated keys (e.g., `actors=a&actors=b`).
            queryParams?.forEach { (key, value) ->
                parameters.append(key, value)
            }
        }
        return url.buildString()
    }

    fun close() {
        client.close()
    }
}
