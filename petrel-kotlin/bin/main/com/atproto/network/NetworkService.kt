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
    val data: T?
)

class NetworkService(
    private val baseUrl: String = "https://bsky.social"
) {
    @PublishedApi
    internal val serviceDIDs = mutableMapOf<String, String>()
    var authenticatedDID: String? = null

    fun setServiceDID(did: String, namespace: String) {
        serviceDIDs[namespace] = did
    }

    fun getDid(): String? = authenticatedDID

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
        body: Any? = null
    ): ATProtoResponse<T> {
        try {
            val response: HttpResponse = client.request(buildUrl(endpoint, queryParams)) {
                this.method = HttpMethod.parse(method)

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
                    ATProtoResponse(statusCode, null)
                }
            } else {
                ATProtoResponse(statusCode, null)
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
    internal fun buildUrl(endpoint: String, queryParams: Map<String, String>?): String {
        val url = URLBuilder(baseUrl).apply {
            path("xrpc", endpoint)
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
