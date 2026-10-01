package blue.catbird.petrel.network

import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.HttpRedirect
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.plugins.logging.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import io.ktor.utils.io.ByteReadChannel
import io.ktor.utils.io.jvm.javaio.toInputStream
import io.ktor.utils.io.readAvailable
import java.io.BufferedInputStream
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.zip.GZIPInputStream
import java.util.zip.InflaterInputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.decodeFromStream
import kotlinx.serialization.serializer

data class ATProtoResponse<T>(
    val responseCode: Int,
    val data: T?,
    val errorBody: String? = null
)

data class NetworkOrigin(
    val scheme: String,
    val host: String,
    val port: Int,
) {
    val isSecure: Boolean get() = scheme == "https" || scheme == "wss"

    val isLoopback: Boolean get() =
        host == "127.0.0.1" || host == "::1" || host == "localhost" || host == "[::1]"

    fun matches(url: Url): Boolean {
        return this == fromUrl(url)
    }

    companion object {
        fun fromUrl(url: Url): NetworkOrigin {
            val scheme = url.protocol.name.lowercase()
            val defaultPort = when (scheme) {
                "https", "wss" -> 443
                "http", "ws" -> 80
                else -> url.port
            }
            val effectivePort = if (url.port > 0) url.port else defaultPort
            val host = url.host.lowercase().removePrefix("[").removeSuffix("]")
            return NetworkOrigin(scheme, host, effectivePort)
        }

        fun parse(urlString: String): NetworkOrigin? = runCatching {
            fromUrl(Url(urlString))
        }.getOrNull()
    }
}

data class NetworkResponseLimits(
    val maxWireBytes: Long = DEFAULT_MAX_WIRE_BYTES,
    val maxDecodedBytes: Long = DEFAULT_MAX_DECODED_BYTES,
    val maxCompressionRatio: Double = DEFAULT_MAX_COMPRESSION_RATIO,
    val maxErrorDiagnosticBytes: Long = DEFAULT_MAX_ERROR_DIAGNOSTIC_BYTES,
) {
    companion object {
        const val DEFAULT_MAX_WIRE_BYTES: Long = 10 * 1024 * 1024L // 10 MiB
        const val DEFAULT_MAX_DECODED_BYTES: Long = 10 * 1024 * 1024L // 10 MiB
        const val DEFAULT_MAX_COMPRESSION_RATIO: Double = 20.0 // 20x
        const val DEFAULT_MAX_ERROR_DIAGNOSTIC_BYTES: Long = 8 * 1024L // 8 KiB
    }
}

open class NetworkSecurityException(message: String, cause: Throwable? = null) :
    SecurityException(message, cause)

class ResponseSizeExceededException(message: String) : NetworkSecurityException(message)

class CleartextNotPermittedException(message: String) : NetworkSecurityException(message)

private class BoundedCountingInputStream(
    private val delegate: InputStream,
    private val maxBytes: Long,
) : InputStream() {
    var bytesRead: Long = 0L
        private set

    override fun read(): Int {
        val b = delegate.read()
        if (b != -1) {
            bytesRead++
            if (bytesRead > maxBytes) {
                throw ResponseSizeExceededException("Response payload exceeded limit of $maxBytes bytes")
            }
        }
        return b
    }

    override fun read(b: ByteArray, off: Int, len: Int): Int {
        val n = delegate.read(b, off, len)
        if (n > 0) {
            bytesRead += n
            if (bytesRead > maxBytes) {
                throw ResponseSizeExceededException("Response payload exceeded limit of $maxBytes bytes")
            }
        }
        return n
    }

    override fun skip(n: Long): Long {
        val skipped = delegate.skip(n)
        if (skipped > 0) {
            bytesRead += skipped
            if (bytesRead > maxBytes) {
                throw ResponseSizeExceededException("Response payload exceeded limit of $maxBytes bytes")
            }
        }
        return skipped
    }

    override fun available(): Int = delegate.available()
    override fun close() = delegate.close()
}

private class DecompressLimitingInputStream(
    private val delegate: InputStream,
    private val wireStream: BoundedCountingInputStream,
    private val maxDecodedBytes: Long,
    private val maxRatio: Double,
) : InputStream() {
    var decodedBytes: Long = 0L
        private set

    private fun checkLimits(added: Long) {
        decodedBytes += added
        if (decodedBytes > maxDecodedBytes) {
            throw ResponseSizeExceededException(
                "Decoded response ($decodedBytes bytes) exceeded limit ($maxDecodedBytes bytes)"
            )
        }
        val wireRead = wireStream.bytesRead
        if (wireRead > 0 && decodedBytes > 64 * 1024L && decodedBytes > (wireRead * maxRatio)) {
            throw ResponseSizeExceededException(
                "Decompressed response exceeded compression ratio limit of ${maxRatio}x"
            )
        }
    }

    override fun read(): Int {
        val b = delegate.read()
        if (b != -1) {
            checkLimits(1L)
        }
        return b
    }

    override fun read(b: ByteArray, off: Int, len: Int): Int {
        val n = delegate.read(b, off, len)
        if (n > 0) {
            checkLimits(n.toLong())
        }
        return n
    }

    override fun skip(n: Long): Long {
        val skipped = delegate.skip(n)
        if (skipped > 0) {
            checkLimits(skipped)
        }
        return skipped
    }

    override fun available(): Int = delegate.available()
    override fun close() = delegate.close()
}

val DEFAULT_JSON: Json = Json {
    prettyPrint = false
    isLenient = true
    ignoreUnknownKeys = true
}

private fun createDefaultHttpClient(logLevel: LogLevel, json: Json = DEFAULT_JSON): HttpClient = HttpClient(CIO) {
    install(ContentNegotiation) {
        json(json)
    }
    if (logLevel != LogLevel.NONE) {
        install(Logging) {
            logger = Logger.DEFAULT
            level = logLevel
        }
    }
    install(HttpRedirect) {
        checkHttpMethod = true
        allowHttpsDowngrade = false
    }
}

open class NetworkService(
    private val baseUrl: String = "https://bsky.social",
    private val logLevel: LogLevel = LogLevel.NONE,
    @PublishedApi
    internal val client: HttpClient = createDefaultHttpClient(logLevel),
    val responseLimits: NetworkResponseLimits = NetworkResponseLimits(),
    @PublishedApi
    internal val json: Json = DEFAULT_JSON,
) {
    @PublishedApi
    internal val serviceDIDs = mutableMapOf<String, String>()
    var authenticatedDID: String? = null
    var authorizationHeader: String? = null

    var authorizedOrigin: NetworkOrigin? = NetworkOrigin.parse(baseUrl)

    init {
        client.sendPipeline.intercept(HttpSendPipeline.State) {
            val requestUrl = context.url.build()
            val destOrigin = NetworkOrigin.fromUrl(requestUrl)
            val auth = authorizedOrigin

            if (!destOrigin.isSecure && !destOrigin.isLoopback) {
                throw CleartextNotPermittedException("Cleartext HTTP is not permitted for remote origin: $requestUrl")
            }

            if (context.headers.contains(HttpHeaders.Authorization)) {
                if (auth == null || !auth.matches(requestUrl)) {
                    context.headers.remove(HttpHeaders.Authorization)
                }
            }
        }
    }

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

    /**
     * Provider for default headers attached to outgoing requests (e.g. atproto-accept-labelers).
     */
    var defaultHeadersProvider: (() -> Map<String, String>)? = null

    fun setServiceDID(did: String, namespace: String) {
        serviceDIDs[namespace] = did
    }

    fun getDid(): String? = authenticatedDID

    fun getBaseUrl(): String = baseUrl

    suspend inline fun <reified T> performRequest(
        method: String,
        endpoint: String,
        queryParams: Map<String, String>? = null,
        headers: Map<String, String> = emptyMap(),
        body: Any? = null,
        queryItems: Any? = null
    ): ATProtoResponse<T> {
        return performRequestInternal(
            typeInfo = io.ktor.util.reflect.typeInfo<T>(),
            method = method,
            endpoint = endpoint,
            queryParams = queryParams,
            headers = headers,
            body = body,
            queryItems = queryItems
        )
    }

    @Suppress("UNCHECKED_CAST")
    open suspend fun <T> performRequestInternal(
        typeInfo: io.ktor.util.reflect.TypeInfo,
        method: String,
        endpoint: String,
        queryParams: Map<String, String>? = null,
        headers: Map<String, String> = emptyMap(),
        body: Any? = null,
        queryItems: Any? = null
    ): ATProtoResponse<T> {
        // Canonical shape: List<Pair<String, String>> preserves repeated keys
        // (needed for ATProto query params like `actors=did:plc:aaa&actors=did:plc:bbb`
        // used by getProfiles, getKeyPackages, etc.).
        val resolvedQueryItems: List<Pair<String, String>>? = when (queryItems) {
            is List<*> -> queryItems as? List<Pair<String, String>>
            is Map<*, *> -> (queryItems as? Map<String, String>)?.map { (k, v) -> k to v }
            else -> null
        }
        val resolvedParams: List<Pair<String, String>>? = queryParams
            ?.map { (k, v) -> k to v }
            ?: resolvedQueryItems

        val targetUrlString = buildUrl(endpoint, resolvedParams)
        val targetUrl = runCatching { Url(targetUrlString) }.getOrNull()
            ?: return ATProtoResponse(0, null)
        val targetOrigin = NetworkOrigin.fromUrl(targetUrl)

        if (!targetOrigin.isSecure && !targetOrigin.isLoopback) {
            return ATProtoResponse(0, null, errorBody = "Cleartext HTTP is not permitted for remote traffic")
        }

        val isOriginAuthorized = authorizedOrigin?.matches(targetUrl) == true
        val shouldAttachAuth = isOriginAuthorized && (targetOrigin.isSecure || targetOrigin.isLoopback)

        try {
            return client.prepareRequest(targetUrlString) {
                this.method = HttpMethod.parse(method)

                // Inject stored auth header if origin is authorized and no explicit Authorization provided
                if (shouldAttachAuth && !headers.containsKey("Authorization") && authorizationHeader != null) {
                    header("Authorization", authorizationHeader!!)
                }

                defaultHeadersProvider?.invoke()?.forEach { (key, value) ->
                    if (!headers.containsKey(key)) {
                        header(key, value)
                    }
                }

                headers.forEach { (key, value) ->
                    if (key.equals("Authorization", ignoreCase = true) && !shouldAttachAuth) {
                        // Strip cross-origin authorization
                    } else {
                        header(key, value)
                    }
                }

                // Add atproto-proxy header if applicable and origin is authorized
                if (isOriginAuthorized) {
                    serviceDIDs.forEach { (namespace, did) ->
                        if (endpoint.startsWith(namespace)) {
                            header("atproto-proxy", did)
                        }
                    }
                }

                body?.let {
                    when (it) {
                        is String -> setBody(it)
                        is ByteArray -> setBody(it)
                        else -> setBody(it)
                    }
                }
            }.execute { response ->
                val statusCode = response.status.value

                if (statusCode in 200..299) {
                    try {
                        val declaredLength = response.headers[HttpHeaders.ContentLength]?.toLongOrNull()
                        if (declaredLength != null && declaredLength > responseLimits.maxWireBytes) {
                            throw ResponseSizeExceededException(
                                "Declared Content-Length ($declaredLength) exceeds limit (${responseLimits.maxWireBytes})"
                            )
                        }

                        if (typeInfo.type == Unit::class) {
                            ATProtoResponse(statusCode, Unit as T)
                        } else {
                            val data = withContext(Dispatchers.IO) {
                                deserializeResponse<T>(response, typeInfo)
                            }
                            ATProtoResponse(statusCode, data)
                        }
                    } catch (e: Exception) {
                        System.err.println("[NetworkService] Processing failed for $endpoint: ${e.message}")
                        ATProtoResponse(statusCode, null)
                    }
                } else {
                    val errorText = try {
                        val errorBytes = readBoundedBytes(
                            channel = response.bodyAsChannel(),
                            maxBytes = responseLimits.maxErrorDiagnosticBytes,
                            truncate = true
                        )
                        errorBytes.decodeToString()
                    } catch (_: Exception) {
                        null
                    }
                    if (statusCode == 401) {
                        unauthorizedHandler?.let { handler ->
                            try {
                                handler(baseUrlHost, errorText?.toByteArray() ?: ByteArray(0))
                            } catch (_: Throwable) {
                                // no-op; classifier always throws, that's the contract
                            }
                        }
                    }
                    ATProtoResponse(statusCode, null, errorBody = errorText)
                }
            }
        } catch (e: Exception) {
            // Network error or security policy refusal
            return ATProtoResponse(0, null)
        }
    }

    suspend fun getServiceDID(endpoint: String): String? {
        // Placeholder - implement service DID resolution
        return null
    }

    @PublishedApi
    internal fun buildUrl(endpoint: String, queryParams: List<Pair<String, String>>?): String {
        val url = if (endpoint.startsWith("http://", ignoreCase = true) || endpoint.startsWith("https://", ignoreCase = true)) {
            URLBuilder(endpoint).apply {
                queryParams?.forEach { (key, value) ->
                    parameters.append(key, value)
                }
            }
        } else {
            URLBuilder(baseUrl).apply {
                path("xrpc", endpoint)
                queryParams?.forEach { (key, value) ->
                    parameters.append(key, value)
                }
            }
        }
        return url.buildString()
    }

    @Suppress("UNCHECKED_CAST")
    @OptIn(ExperimentalSerializationApi::class)
    private suspend fun <T> deserializeResponse(
        response: HttpResponse,
        typeInfo: io.ktor.util.reflect.TypeInfo,
    ): T? {
        val countingWireStream = BoundedCountingInputStream(
            delegate = response.bodyAsChannel().toInputStream(),
            maxBytes = responseLimits.maxWireBytes
        )
        val bufferedWireStream = BufferedInputStream(countingWireStream, 8192)

        val contentEncoding = response.headers[HttpHeaders.ContentEncoding]?.lowercase()?.trim()
        val (decompressedStream, isCompressed) = when (contentEncoding) {
            "gzip", "x-gzip" -> {
                bufferedWireStream.mark(512)
                try {
                    GZIPInputStream(bufferedWireStream) to true
                } catch (_: Exception) {
                    bufferedWireStream.reset()
                    bufferedWireStream to false
                }
            }
            "deflate" -> {
                bufferedWireStream.mark(512)
                try {
                    InflaterInputStream(bufferedWireStream) to true
                } catch (_: Exception) {
                    bufferedWireStream.reset()
                    bufferedWireStream to false
                }
            }
            else -> bufferedWireStream to false
        }

        val decodedStream: InputStream = if (isCompressed) {
            DecompressLimitingInputStream(
                delegate = decompressedStream,
                wireStream = countingWireStream,
                maxDecodedBytes = responseLimits.maxDecodedBytes,
                maxRatio = responseLimits.maxCompressionRatio
            )
        } else {
            decompressedStream
        }

        val bufferedStream = if (decodedStream is BufferedInputStream) decodedStream else BufferedInputStream(decodedStream, 8192)

        return bufferedStream.use { stream ->
            if (typeInfo.type == ByteArray::class) {
                val bytes = readAllBounded(stream, responseLimits.maxDecodedBytes)
                return@use bytes as T
            }
            if (typeInfo.type == String::class) {
                val bytes = readAllBounded(stream, responseLimits.maxDecodedBytes)
                val text = bytes.decodeToString()
                return@use text as T
            }

            stream.mark(1)
            val firstByte = stream.read()
            if (firstByte == -1) {
                return@use null
            }
            stream.reset()

            try {
                val serializer = typeInfo.kotlinType?.let {
                    json.serializersModule.serializer(it)
                } ?: kotlinx.serialization.serializer(typeInfo.type.java)
                json.decodeFromStream(serializer, stream) as T
            } catch (e: Exception) {
                System.err.println("[NetworkService] Deserialization failed: ${e.message}")
                null
            }
        }
    }

    private suspend fun readBoundedBytes(
        channel: ByteReadChannel,
        maxBytes: Long,
        truncate: Boolean = false,
        chunkSize: Int = 8192
    ): ByteArray {
        val baos = ByteArrayOutputStream()
        val buffer = ByteArray(chunkSize)
        var totalRead = 0L

        while (!channel.isClosedForRead) {
            val read = channel.readAvailable(buffer, 0, buffer.size)
            if (read < 0) break
            if (read > 0) {
                if (totalRead + read > maxBytes) {
                    if (truncate) {
                        val allowed = (maxBytes - totalRead).toInt().coerceAtLeast(0)
                        if (allowed > 0) {
                            baos.write(buffer, 0, allowed)
                        }
                        break
                    } else {
                        throw ResponseSizeExceededException("Response payload exceeded limit of $maxBytes bytes")
                    }
                }
                totalRead += read
                baos.write(buffer, 0, read)
            }
        }
        return baos.toByteArray()
    }

    private fun readAllBounded(stream: InputStream, maxBytes: Long): ByteArray {
        val baos = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var total = 0L
        while (true) {
            val read = stream.read(buffer)
            if (read < 0) break
            total += read
            if (total > maxBytes) {
                throw ResponseSizeExceededException("Decoded response ($total bytes) exceeded limit ($maxBytes bytes)")
            }
            baos.write(buffer, 0, read)
        }
        return baos.toByteArray()
    }

    fun close() {
        client.close()
    }
}
