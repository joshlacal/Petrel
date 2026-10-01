package blue.catbird.petrel.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import io.ktor.utils.io.ByteReadChannel
import io.ktor.utils.io.jvm.javaio.toByteReadChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.Random
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.zip.DeflaterOutputStream
import java.util.zip.GZIPOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

@Serializable
private data class SamplePayload(
    val id: String = "test",
    val message: String = "ok",
    val items: List<String> = emptyList()
)

class NetworkStreamingAdversarialTest {

    private val testJson = Json {
        prettyPrint = false
        isLenient = true
        ignoreUnknownKeys = true
    }

    /**
     * An infinite or long streaming InputStream producing valid JSON structure
     * starting with `{"id":"1","message":""" followed by repeating 'A' bytes,
     * and ending with `"}` only if read up to totalVirtualBytes.
     */
    private class InfiniteJsonStream(
        val totalVirtualBytes: Long = Long.MAX_VALUE,
        val prefix: String = """{"id":"1","message":"""",
        val suffix: String = """" }"""
    ) : InputStream() {
        val bytesRead = AtomicLong(0L)
        val isClosed = AtomicBoolean(false)
        val eofHit = AtomicBoolean(false)

        private val prefixBytes = prefix.toByteArray(Charsets.UTF_8)
        private val suffixBytes = suffix.toByteArray(Charsets.UTF_8)

        override fun read(): Int {
            val current = bytesRead.get()
            if (current >= totalVirtualBytes) {
                eofHit.set(true)
                return -1
            }
            val b = when {
                current < prefixBytes.size -> prefixBytes[current.toInt()].toInt() and 0xFF
                current < totalVirtualBytes - suffixBytes.size -> 'A'.code
                else -> {
                    val idx = (current - (totalVirtualBytes - suffixBytes.size)).toInt()
                    suffixBytes[idx].toInt() and 0xFF
                }
            }
            bytesRead.incrementAndGet()
            return b
        }

        override fun read(b: ByteArray, off: Int, len: Int): Int {
            if (b.isEmpty() || len == 0) return 0
            val current = bytesRead.get()
            if (current >= totalVirtualBytes) {
                eofHit.set(true)
                return -1
            }
            val available = (totalVirtualBytes - current).coerceAtMost(len.toLong()).toInt()
            for (i in 0 until available) {
                b[off + i] = read().toByte()
            }
            return available
        }

        override fun close() {
            isClosed.set(true)
            super.close()
        }
    }

    // Helper: Instantiate private BoundedCountingInputStream via reflection
    private fun createBoundedCountingInputStream(
        delegate: InputStream,
        maxBytes: Long
    ): InputStream {
        val clazz = Class.forName("blue.catbird.petrel.network.BoundedCountingInputStream")
        val constructor = clazz.getDeclaredConstructor(InputStream::class.java, Long::class.javaPrimitiveType)
        constructor.isAccessible = true
        return constructor.newInstance(delegate, maxBytes) as InputStream
    }

    // Helper: Instantiate private DecompressLimitingInputStream via reflection
    private fun createDecompressLimitingInputStream(
        delegate: InputStream,
        wireStream: InputStream,
        maxDecodedBytes: Long,
        maxRatio: Double
    ): InputStream {
        val wireClass = Class.forName("blue.catbird.petrel.network.BoundedCountingInputStream")
        val clazz = Class.forName("blue.catbird.petrel.network.DecompressLimitingInputStream")
        val constructor = clazz.getDeclaredConstructor(
            InputStream::class.java,
            wireClass,
            Long::class.javaPrimitiveType,
            Double::class.javaPrimitiveType
        )
        constructor.isAccessible = true
        return constructor.newInstance(delegate, wireStream, maxDecodedBytes, maxRatio) as InputStream
    }

    /**
     * Helper to generate compressed bytes with a moderate compression ratio (~4x),
     * ensuring it remains strictly below the 20x compression ratio limit while
     * expanding to the target uncompressed size.
     */
    private fun generateModerateRatioCompressedJson(targetUncompressedBytes: Int): ByteArray {
        val prefix = """{"id":"1","message":"""".toByteArray(Charsets.UTF_8)
        val suffix = """" }""".toByteArray(Charsets.UTF_8)
        val middleTarget = targetUncompressedBytes - prefix.size - suffix.size

        val baos = ByteArrayOutputStream()
        GZIPOutputStream(baos).use { gz ->
            gz.write(prefix)

            // Emit semi-random 64-byte chunks repeated 4 times (yields ~4x ratio)
            val rng = Random(42)
            val chunk = ByteArray(64)
            var written = 0
            while (written < middleTarget) {
                rng.nextBytes(chunk)
                // Filter out ASCII quotes and backslashes to preserve JSON string validity
                for (i in chunk.indices) {
                    val v = chunk[i].toInt() and 0x7F
                    if (v < 32 || v == 34 || v == 92) {
                        chunk[i] = 'a'.code.toByte()
                    }
                }
                for (r in 0 until 4) {
                    val toWrite = minOf(chunk.size, middleTarget - written)
                    gz.write(chunk, 0, toWrite)
                    written += toWrite
                    if (written >= middleTarget) break
                }
            }

            gz.write(suffix)
        }
        return baos.toByteArray()
    }

    // =========================================================================
    // 1. Wire Limit Enforcement Challenges
    // =========================================================================

    @Test
    fun `BoundedCountingInputStream throws ResponseSizeExceededException and halts before EOF`() {
        val totalBytes = 25L * 1024 * 1024 // 25 MiB stream
        val limit = 10L * 1024 * 1024 // 10 MiB limit
        val underlying = InfiniteJsonStream(totalVirtualBytes = totalBytes)
        val bounded = createBoundedCountingInputStream(underlying, limit)

        val buffer = ByteArray(64 * 1024)
        var totalRead = 0L

        val ex = assertFailsWith<ResponseSizeExceededException> {
            while (true) {
                val n = bounded.read(buffer)
                if (n == -1) break
                totalRead += n
            }
        }

        assertTrue(
            ex.message!!.contains("exceeded limit"),
            "Exception message should mention limit exceeded: ${ex.message}"
        )

        // Verify it halted right at the limit, well before 25 MiB EOF
        assertTrue(
            underlying.bytesRead.get() <= limit + buffer.size,
            "Stream must halt immediately at limit; read ${underlying.bytesRead.get()} bytes vs limit $limit"
        )
        assertFalse(underlying.eofHit.get(), "EOF must NEVER be reached on oversized stream")

        bounded.close()
        assertTrue(underlying.isClosed.get(), "Underlying stream must be closed when bounded stream is closed")
    }

    @Test
    fun `NetworkService aborts streaming wire payload exceeding 10 MiB without reading to EOF`() = runTest {
        val totalBytes = 30L * 1024 * 1024 // 30 MiB
        val rawStream = InfiniteJsonStream(totalVirtualBytes = totalBytes)

        val mockEngine = MockEngine { request ->
            respond(
                content = rawStream.toByteReadChannel(),
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

        val resp = network.performRequest<SamplePayload>(
            method = "GET",
            endpoint = "app.bsky.feed.getTimeline"
        )

        assertEquals(200, resp.responseCode)
        assertNull(resp.data, "Oversized wire stream must return null data")

        // Crucial empirical verification: did it abort early without consuming the 30 MiB?
        val wireBytesConsumed = rawStream.bytesRead.get()
        assertTrue(
            wireBytesConsumed < 15L * 1024 * 1024,
            "NetworkService consumed $wireBytesConsumed bytes; must abort shortly after 10 MiB wire limit!"
        )
        assertFalse(rawStream.eofHit.get(), "Underlying stream must NOT have been read to EOF")
    }

    // =========================================================================
    // 2. Decoded Limit Enforcement Challenges
    // =========================================================================

    @Test
    fun `DecompressLimitingInputStream throws ResponseSizeExceededException when decoded bytes exceed 10 MiB`() {
        val decodedLimit = 10L * 1024 * 1024L
        val wireLimit = 10L * 1024 * 1024L
        val targetUncompressed = 11 * 1024 * 1024 // 11 MiB

        val compressedBytes = generateModerateRatioCompressedJson(targetUncompressed)
        val compressionRatio = targetUncompressed.toDouble() / compressedBytes.size

        // Verify test preconditions: ratio is under 20x bomb limit and compressed wire is under 10 MiB wire limit
        assertTrue(
            compressionRatio in 2.0..18.0,
            "Compression ratio ($compressionRatio) must be well under 20x to strictly test decoded limit"
        )
        assertTrue(
            compressedBytes.size < wireLimit,
            "Compressed wire bytes (${compressedBytes.size}) must be under 10 MiB wire limit"
        )

        val wireStream = createBoundedCountingInputStream(ByteArrayInputStream(compressedBytes), wireLimit)
        val gzIn = java.util.zip.GZIPInputStream(wireStream)
        val decompressLimited = createDecompressLimitingInputStream(
            delegate = gzIn,
            wireStream = wireStream,
            maxDecodedBytes = decodedLimit,
            maxRatio = 20.0
        )

        val readBuf = ByteArray(64 * 1024)
        var totalDecoded = 0L

        val ex = assertFailsWith<ResponseSizeExceededException> {
            while (true) {
                val n = decompressLimited.read(readBuf)
                if (n == -1) break
                totalDecoded += n
            }
        }

        assertTrue(
            ex.message!!.contains("Decoded response"),
            "Message must cite decoded response limit: ${ex.message}"
        )
        assertTrue(
            totalDecoded <= decodedLimit + readBuf.size,
            "Decoded stream must halt immediately at 10 MiB limit; decoded $totalDecoded bytes"
        )
    }

    @Test
    fun `NetworkService aborts gzipped payload expanding to greater than 10 MiB decoded bytes`() = runTest {
        val targetUncompressed = 11 * 1024 * 1024 // 11 MiB
        val compressedBytes = generateModerateRatioCompressedJson(targetUncompressed)

        val mockEngine = MockEngine { request ->
            respond(
                content = compressedBytes,
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

        val resp = network.performRequest<SamplePayload>(
            method = "GET",
            endpoint = "app.bsky.feed.getTimeline"
        )

        assertEquals(200, resp.responseCode)
        assertNull(resp.data, "Payload expanding past 10 MiB decoded limit must return null data")
    }

    // =========================================================================
    // 3. Compression Bomb Defense Challenges
    // =========================================================================

    @Test
    fun `DecompressLimitingInputStream aborts immediately past 64 KiB floor on high-ratio gzip`() {
        // Gzip bomb: 1 MiB of zero bytes compresses to ~1024 bytes (ratio ~1000x >> 20x)
        val rawBomb = ByteArray(1024 * 1024) { 0 }
        val compressed = ByteArrayOutputStream().apply {
            GZIPOutputStream(this).use { it.write(rawBomb) }
        }.toByteArray()

        val wireStream = createBoundedCountingInputStream(ByteArrayInputStream(compressed), 10 * 1024 * 1024L)
        val gzIn = java.util.zip.GZIPInputStream(wireStream)
        val decompressLimited = createDecompressLimitingInputStream(
            delegate = gzIn,
            wireStream = wireStream,
            maxDecodedBytes = 10 * 1024 * 1024L,
            maxRatio = 20.0
        )

        val readBuf = ByteArray(8192)
        var totalDecoded = 0L

        val ex = assertFailsWith<ResponseSizeExceededException> {
            while (true) {
                val n = decompressLimited.read(readBuf)
                if (n == -1) break
                totalDecoded += n
            }
        }

        assertTrue(
            ex.message!!.contains("compression ratio limit"),
            "Message must cite compression ratio limit: ${ex.message}"
        )

        // Verify defense fired immediately after crossing the 64 KiB floor, NOT at 10 MiB!
        assertTrue(
            totalDecoded <= 64 * 1024 + readBuf.size,
            "Bomb must be stopped immediately past 64 KiB floor; decoded only $totalDecoded bytes!"
        )
    }

    @Test
    fun `Compression bomb with deflate encoding is also caught and aborted`() = runTest {
        // High ratio with deflate encoding
        val bombContent = """{"message":"""" + "a".repeat(200 * 1024) + """" }"""
        val deflatedBaos = ByteArrayOutputStream()
        DeflaterOutputStream(deflatedBaos).use { def ->
            def.write(bombContent.toByteArray(Charsets.UTF_8))
        }
        val deflatedBytes = deflatedBaos.toByteArray()

        val mockEngine = MockEngine { request ->
            respond(
                content = deflatedBytes,
                status = HttpStatusCode.OK,
                headers = headersOf(
                    HttpHeaders.ContentType to listOf("application/json"),
                    HttpHeaders.ContentEncoding to listOf("deflate")
                )
            )
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(baseUrl = "https://bsky.social", client = client)

        val resp = network.performRequest<SamplePayload>(
            method = "GET",
            endpoint = "app.bsky.actor.getProfile"
        )
        assertEquals(200, resp.responseCode)
        assertNull(resp.data, "Deflate bomb exceeding 20x ratio must be aborted and return null data")
    }

    // =========================================================================
    // 4. Truncated & Malformed Stream Challenges
    // =========================================================================

    @Test
    fun `stream truncated mid-JSON closes cleanly without thread or resource leak`() = runTest {
        val streamClosed = AtomicBoolean(false)
        val truncatedJson = """{"id":"123","message":"incomplete payload"""

        val trackingStream = object : ByteArrayInputStream(truncatedJson.toByteArray(Charsets.UTF_8)) {
            override fun close() {
                streamClosed.set(true)
                super.close()
            }
        }

        val mockEngine = MockEngine { request ->
            respond(
                content = trackingStream.toByteReadChannel(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) { json(testJson) }
        }
        val network = NetworkService(baseUrl = "https://bsky.social", client = client)

        val threadCountBefore = Thread.activeCount()

        val resp = network.performRequest<SamplePayload>(
            method = "GET",
            endpoint = "app.bsky.feed.getPostThread"
        )

        assertEquals(200, resp.responseCode)
        assertNull(resp.data, "Truncated stream must fail deserialization and return null data")

        // Verify stream resource is not leaked
        assertTrue(streamClosed.get(), "Underlying input stream must be closed even when JSON is truncated")

        // Verify thread safety and no thread leak
        val threadCountAfter = Thread.activeCount()
        assertTrue(
            threadCountAfter <= threadCountBefore + 2,
            "Thread count should remain stable (before: $threadCountBefore, after: $threadCountAfter)"
        )
    }

    @Test
    fun `stream truncated after opening brace returns null and closes stream`() = runTest {
        val streamClosed = AtomicBoolean(false)
        val trackingStream = object : ByteArrayInputStream("{".toByteArray(Charsets.UTF_8)) {
            override fun close() {
                streamClosed.set(true)
                super.close()
            }
        }

        val mockEngine = MockEngine {
            respond(
                content = trackingStream.toByteReadChannel(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = HttpClient(mockEngine) { install(ContentNegotiation) { json(testJson) } }
        val network = NetworkService(baseUrl = "https://bsky.social", client = client)

        val resp = network.performRequest<SamplePayload>("GET", "test")
        assertEquals(200, resp.responseCode)
        assertNull(resp.data)
        assertTrue(streamClosed.get(), "Stream must be closed on truncation after opening brace")
    }

    @Test
    fun `empty stream with zero bytes returns null and closes stream`() = runTest {
        val streamClosed = AtomicBoolean(false)
        val trackingStream = object : ByteArrayInputStream(ByteArray(0)) {
            override fun close() {
                streamClosed.set(true)
                super.close()
            }
        }

        val mockEngine = MockEngine {
            respond(
                content = trackingStream.toByteReadChannel(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = HttpClient(mockEngine) { install(ContentNegotiation) { json(testJson) } }
        val network = NetworkService(baseUrl = "https://bsky.social", client = client)

        val resp = network.performRequest<SamplePayload>("GET", "test")
        assertEquals(200, resp.responseCode)
        assertNull(resp.data)
        assertTrue(streamClosed.get(), "Empty stream must be closed properly")
    }

    @Test
    fun `malformed JSON token syntax fails deserialization gracefully`() = runTest {
        val streamClosed = AtomicBoolean(false)
        val malformedJson = """{"id": [unquoted, invalid array notation}"""
        val trackingStream = object : ByteArrayInputStream(malformedJson.toByteArray(Charsets.UTF_8)) {
            override fun close() {
                streamClosed.set(true)
                super.close()
            }
        }

        val mockEngine = MockEngine {
            respond(
                content = trackingStream.toByteReadChannel(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = HttpClient(mockEngine) { install(ContentNegotiation) { json(testJson) } }
        val network = NetworkService(baseUrl = "https://bsky.social", client = client)

        val resp = network.performRequest<SamplePayload>("GET", "test")
        assertEquals(200, resp.responseCode)
        assertNull(resp.data)
        assertTrue(streamClosed.get(), "Stream must be closed after JSON syntax error")
    }

    @Test
    fun `truncated gzip stream header is safely handled without crash or hang`() = runTest {
        // Gzip header magic is 0x1F, 0x8B - supply incomplete 2-byte truncated gzip payload
        val corruptedGzip = byteArrayOf(0x1F.toByte(), 0x8B.toByte())

        val mockEngine = MockEngine {
            respond(
                content = corruptedGzip,
                status = HttpStatusCode.OK,
                headers = headersOf(
                    HttpHeaders.ContentType to listOf("application/json"),
                    HttpHeaders.ContentEncoding to listOf("gzip")
                )
            )
        }

        val client = HttpClient(mockEngine) { install(ContentNegotiation) { json(testJson) } }
        val network = NetworkService(baseUrl = "https://bsky.social", client = client)

        val resp = network.performRequest<SamplePayload>("GET", "test")
        assertEquals(200, resp.responseCode)
        assertNull(resp.data, "Corrupted gzip header must be handled safely and return null data")
    }
}
