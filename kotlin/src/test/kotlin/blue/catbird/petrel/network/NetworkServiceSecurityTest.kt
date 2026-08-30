package blue.catbird.petrel.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.HttpRedirect
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import java.io.ByteArrayOutputStream
import java.util.zip.GZIPOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

private val testJson = Json {
    prettyPrint = true
    isLenient = true
    ignoreUnknownKeys = true
}

@Serializable
data class TestOutput(val message: String)

class NetworkServiceSecurityTest {

    @Test
    fun `exact origin receives credentials while cross origin request stays unauthenticated`() = runTest {
        val capturedAuthHeaders = mutableListOf<String?>()
        val capturedUrls = mutableListOf<String>()

        val mockEngine = MockEngine { request ->
            capturedUrls.add(request.url.toString())
            capturedAuthHeaders.add(request.headers[HttpHeaders.Authorization])
            respond(
                content = """{"message":"ok"}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(
            baseUrl = "https://bsky.social",
            client = client
        ).apply {
            authenticatedDID = "did:plc:alice"
            authorizationHeader = "Bearer secret-gateway-token"
        }

        // 1. Same-origin relative endpoint
        val resp1 = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(200, resp1.responseCode)
        assertEquals(TestOutput("ok"), resp1.data)
        assertEquals("Bearer secret-gateway-token", capturedAuthHeaders[0])

        // 2. Cross-origin absolute URL
        val resp2 = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "https://other.social/xrpc/app.bsky.actor.getProfile"
        )
        assertEquals(200, resp2.responseCode)
        assertEquals(TestOutput("ok"), resp2.data)
        assertNull(capturedAuthHeaders[1], "Cross-origin request must not carry gateway authorization header")

        // 3. Different port on same host
        val resp3 = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "https://bsky.social:8443/xrpc/app.bsky.actor.getProfile"
        )
        assertEquals(200, resp3.responseCode)
        assertEquals(TestOutput("ok"), resp3.data)
        assertNull(capturedAuthHeaders[2], "Different port must not carry gateway authorization header")
    }

    @Test
    fun `cleartext remote origin is refused and does not transmit credentials`() = runTest {
        val capturedAuthHeaders = mutableListOf<String?>()

        val mockEngine = MockEngine { request ->
            capturedAuthHeaders.add(request.headers[HttpHeaders.Authorization])
            respond(
                content = """{"message":"ok"}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(
            baseUrl = "http://insecure.social",
            client = client
        ).apply {
            authenticatedDID = "did:plc:alice"
            authorizationHeader = "Bearer secret-token"
        }

        val resp = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        // Cleartext remote request should be refused
        assertEquals(0, resp.responseCode)
        assertNull(resp.data)
        assertEquals("Cleartext HTTP is not permitted for remote traffic", resp.errorBody)
        assertTrue(capturedAuthHeaders.isEmpty(), "Cleartext request must never reach the engine")
    }

    @Test
    fun `redirect to different origin strips credentials`() = runTest {
        val capturedAuthHeaders = mutableListOf<String?>()
        val capturedUrls = mutableListOf<String>()

        val mockEngine = MockEngine { request ->
            val url = request.url.toString()
            capturedUrls.add(url)
            capturedAuthHeaders.add(request.headers[HttpHeaders.Authorization])

            if (url.startsWith("https://bsky.social/xrpc/redirect")) {
                respond(
                    content = "",
                    status = HttpStatusCode.Found,
                    headers = headersOf(HttpHeaders.Location, "https://attacker.com/xrpc/target")
                )
            } else {
                respond(
                    content = """{"message":"ok"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json")
                )
            }
        }

        val client = HttpClient(mockEngine) {
            install(HttpRedirect)
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(
            baseUrl = "https://bsky.social",
            client = client
        ).apply {
            authorizationHeader = "Bearer secret-gateway-token"
        }

        val resp = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "redirect"
        )
        assertEquals(200, resp.responseCode)
        assertEquals(TestOutput("ok"), resp.data)
        assertEquals("Bearer secret-gateway-token", capturedAuthHeaders[0])
        assertEquals(2, capturedAuthHeaders.size)
        assertNull(capturedAuthHeaders[1], "Redirect to cross-origin must strip Authorization header")
    }

    @Test
    fun `chunked response exceeding 10 MiB limit is aborted`() = runTest {
        var returnOversized = true
        val oversizedSize = 10 * 1024 * 1024 + 512 * 1024 // 10.5 MiB
        val oversizedPadding = "a".repeat(oversizedSize)
        val oversizedPayload = """{"message":"$oversizedPadding"}"""

        val controlPayload = """{"message":"valid under limit"}"""

        val mockEngine = MockEngine { request ->
            val payload = if (returnOversized) oversizedPayload else controlPayload
            respond(
                content = payload,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(
            baseUrl = "https://bsky.social",
            client = client
        )

        // 1. Oversized payload exceeding 10 MiB is refused and returns null data
        returnOversized = true
        val respOversized = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(200, respOversized.responseCode)
        assertNull(respOversized.data, "Payload exceeding 10 MiB limit must be aborted and return null data")

        // 2. Control case under 10 MiB limit successfully deserializes
        returnOversized = false
        val respControl = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(200, respControl.responseCode)
        assertEquals(TestOutput("valid under limit"), respControl.data, "Valid payload under 10 MiB must deserialize successfully")
    }

    @Test
    fun `declared content length exceeding 10 MiB limit is rejected before materializing`() = runTest {
        var includeOversizedContentLength = true
        val validJson = """{"message":"ok"}"""

        val mockEngine = MockEngine { request ->
            val headers = if (includeOversizedContentLength) {
                headersOf(
                    HttpHeaders.ContentType to listOf("application/json"),
                    HttpHeaders.ContentLength to listOf((15 * 1024 * 1024).toString())
                )
            } else {
                headersOf(
                    HttpHeaders.ContentType to listOf("application/json"),
                    HttpHeaders.ContentLength to listOf(validJson.length.toString())
                )
            }
            respond(
                content = io.ktor.utils.io.ByteReadChannel(validJson.toByteArray()),
                status = HttpStatusCode.OK,
                headers = headers
            )
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(
            baseUrl = "https://bsky.social",
            client = client
        )

        // 1. Oversized declared Content-Length (15 MiB) is rejected
        includeOversizedContentLength = true
        val respOversized = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(200, respOversized.responseCode)
        assertNull(respOversized.data, "Response with declared Content-Length > 10 MiB must be rejected and return null data")

        // 2. Control case with valid Content-Length deserializes successfully
        includeOversizedContentLength = false
        val respControl = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(200, respControl.responseCode)
        assertEquals(TestOutput("ok"), respControl.data, "Response with valid Content-Length must deserialize successfully")
    }

    @Test
    fun `compressed response exceeding 20x compression ratio limit is aborted`() = runTest {
        var returnBomb = true

        // Create 100 KiB valid JSON with repeated 'a' (> 64 KiB floor), which gzip-compresses to ~150 bytes (ratio > 600x >> 20x)
        val bombPadding = "a".repeat(100 * 1024)
        val bombJson = """{"message":"$bombPadding"}"""
        val bombCompressed = ByteArrayOutputStream().apply {
            GZIPOutputStream(this).use { it.write(bombJson.toByteArray(Charsets.UTF_8)) }
        }.toByteArray()

        // Control: valid JSON with normal compression ratio (< 20x)
        val normalJson = """{"message":"hello world"}"""
        val normalCompressed = ByteArrayOutputStream().apply {
            GZIPOutputStream(this).use { it.write(normalJson.toByteArray(Charsets.UTF_8)) }
        }.toByteArray()

        val mockEngine = MockEngine { request ->
            val body = if (returnBomb) bombCompressed else normalCompressed
            respond(
                content = body,
                status = HttpStatusCode.OK,
                headers = headersOf(
                    HttpHeaders.ContentType to listOf("application/json"),
                    HttpHeaders.ContentEncoding to listOf("gzip")
                )
            )
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(
            baseUrl = "https://bsky.social",
            client = client
        )

        // 1. Gzip compression bomb exceeding 20x ratio is aborted
        returnBomb = true
        val respBomb = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(200, respBomb.responseCode)
        assertNull(respBomb.data, "Compression bomb exceeding 20x ratio must be aborted and return null data")

        // 2. Control case with normal compression ratio deserializes successfully
        returnBomb = false
        val respControl = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(200, respControl.responseCode)
        assertEquals(TestOutput("hello world"), respControl.data, "Normal compressed response must deserialize successfully")
    }

    @Test
    fun `error diagnostics body is bounded to at most 8 KiB`() = runTest {
        // 50 KiB error body
        val largeErrorText = "E".repeat(50 * 1024)

        val mockEngine = MockEngine { request ->
            respond(
                content = largeErrorText,
                status = HttpStatusCode.InternalServerError,
                headers = headersOf(HttpHeaders.ContentType, "text/plain")
            )
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(
            baseUrl = "https://bsky.social",
            client = client
        )

        val resp = network.performRequest<TestOutput>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(500, resp.responseCode)
        assertNotNull(resp.errorBody)
        assertEquals(8192, resp.errorBody!!.toByteArray().size, "Error diagnostics body must be bounded to 8 KiB default")
    }
}
