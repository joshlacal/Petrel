package blue.catbird.petrel.runtime.subscription

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream

class CborFramesTest {

    // -------------------------------------------------------------------------
    // Helpers to build CBOR bytes
    // -------------------------------------------------------------------------

    private fun buildHeader(op: Int = 1, t: String = "#commit"): ByteArray {
        val out = ByteArrayOutputStream()
        // Map of 2 entries: 0xa2
        out.write(0xa2)
        // Key "op" -> 0x62, 'o', 'p'
        out.write(0x62)
        out.write("op".toByteArray(Charsets.UTF_8))
        // Value op: if >= 0 unsigned int, if < 0 negative int
        if (op >= 0) {
            if (op < 24) {
                out.write(op)
            } else {
                out.write(0x18)
                out.write(op)
            }
        } else {
            val neg = -1 - op
            if (neg < 24) {
                out.write(0x20 or neg)
            } else {
                out.write(0x38)
                out.write(neg)
            }
        }
        // Key "t" -> 0x61, 't'
        out.write(0x61)
        out.write("t".toByteArray(Charsets.UTF_8))
        // Value t string
        val tBytes = t.toByteArray(Charsets.UTF_8)
        if (tBytes.size < 24) {
            out.write(0x60 or tBytes.size)
        } else {
            out.write(0x78)
            out.write(tBytes.size)
        }
        out.write(tBytes)
        return out.toByteArray()
    }

    private fun buildErrorHeader(): ByteArray {
        val out = ByteArrayOutputStream()
        // Map of 1 entry: 0xa1
        out.write(0xa1)
        out.write(0x62)
        out.write("op".toByteArray(Charsets.UTF_8))
        out.write(0x20) // -1
        return out.toByteArray()
    }

    private fun buildSimpleMapPayload(key: String = "seq", value: Long = 123L): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(0xa1)
        val kBytes = key.toByteArray(Charsets.UTF_8)
        out.write(0x60 or kBytes.size)
        out.write(kBytes)
        if (value < 24) {
            out.write(value.toInt())
        } else if (value < 256) {
            out.write(0x18)
            out.write(value.toInt())
        } else {
            out.write(0x19)
            out.write((value shr 8).toInt())
            out.write((value and 0xFF).toInt())
        }
        return out.toByteArray()
    }

    private fun buildNestedArray(depth: Int): ByteArray {
        val out = ByteArrayOutputStream()
        // Nest `depth` single-element arrays: [ [ [ ... 1 ... ] ] ]
        for (i in 0 until depth) {
            out.write(0x81) // Array of 1 item
        }
        out.write(0x01) // uint 1 at innermost level
        return out.toByteArray()
    }

    private fun buildNestedMap(depth: Int): ByteArray {
        val out = ByteArrayOutputStream()
        // Nest `depth` single-entry maps: { "a": { "a": ... 1 ... } }
        for (i in 0 until depth) {
            out.write(0xa1) // Map of 1 entry
            out.write(0x61) // key "a"
            out.write('a'.code)
        }
        out.write(0x01) // uint 1 at innermost level
        return out.toByteArray()
    }

    private fun buildNestedTags(depth: Int): ByteArray {
        val out = ByteArrayOutputStream()
        // Nest `depth` tags (tag 6): 0xc6 0xc6 ... 0x01
        for (i in 0 until depth) {
            out.write(0xc6) // Tag 6
        }
        out.write(0x01) // uint 1
        return out.toByteArray()
    }

    private fun buildArrayWithNodes(count: Int): ByteArray {
        val out = ByteArrayOutputStream()
        // Array of `count` small integers
        if (count < 24) {
            out.write(0x80 or count)
        } else if (count < 256) {
            out.write(0x98)
            out.write(count)
        } else if (count < 65536) {
            out.write(0x99)
            out.write((count shr 8) and 0xFF)
            out.write(count and 0xFF)
        } else {
            out.write(0x9a)
            out.write((count shr 24) and 0xFF)
            out.write((count shr 16) and 0xFF)
            out.write((count shr 8) and 0xFF)
            out.write(count and 0xFF)
        }
        for (i in 0 until count) {
            out.write(0x00) // uint 0 (1 byte per node)
        }
        return out.toByteArray()
    }

    private fun buildByteStringPayload(size: Int): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(0xa1) // Map of 1
        out.write(0x61) // "b"
        out.write('b'.code)
        if (size < 24) {
            out.write(0x40 or size)
        } else if (size < 256) {
            out.write(0x58)
            out.write(size)
        } else if (size < 65536) {
            out.write(0x59)
            out.write((size shr 8) and 0xFF)
            out.write(size and 0xFF)
        } else {
            out.write(0x5a)
            out.write((size shr 24) and 0xFF)
            out.write((size shr 16) and 0xFF)
            out.write((size shr 8) and 0xFF)
            out.write(size and 0xFF)
        }
        out.write(ByteArray(size))
        return out.toByteArray()
    }

    // -------------------------------------------------------------------------
    // Tests
    // -------------------------------------------------------------------------

    @Test
    fun testNormalTwoItemFrame() {
        val header = buildHeader(op = 1, t = "#commit")
        val payload = buildSimpleMapPayload("seq", 123L)
        val frame = header + payload

        val result = parseBinaryFrame(frame)
        assertNotNull(result)
        assertTrue(result is CborFrame.Message)
        val msg = result as CborFrame.Message
        assertEquals(1, msg.header.op)
        assertEquals("#commit", msg.header.t)
        assertTrue(msg.payload.containsKey("seq"))
    }

    @Test
    fun testNormalErrorFrame() {
        val header = buildErrorHeader()
        // Error payload { "error": "ConsumerTooSlow", "message": "High lag" }
        val out = ByteArrayOutputStream()
        out.write(0xa2)
        out.write(0x65)
        out.write("error".toByteArray(Charsets.UTF_8))
        out.write(0x6f)
        out.write("ConsumerTooSlow".toByteArray(Charsets.UTF_8))
        out.write(0x67)
        out.write("message".toByteArray(Charsets.UTF_8))
        out.write(0x68)
        out.write("High lag".toByteArray(Charsets.UTF_8))
        val payload = out.toByteArray()
        val frame = header + payload

        val result = parseBinaryFrame(frame)
        assertNotNull(result)
        assertTrue(result is CborFrame.Error)
        val err = result as CborFrame.Error
        assertEquals("ConsumerTooSlow", err.name)
        assertEquals("High lag", err.message)
    }

    @Test
    fun testTruncatedInputReturnsNull() {
        val header = buildHeader(op = 1, t = "#commit")
        val payload = buildSimpleMapPayload("seq", 123L)
        val frame = header + payload

        // Truncated in header
        val truncatedHeader = frame.copyOfRange(0, header.size - 2)
        assertNull(parseBinaryFrame(truncatedHeader))

        // Truncated in payload
        val truncatedPayload = frame.copyOfRange(0, frame.size - 2)
        assertNull(parseBinaryFrame(truncatedPayload))

        // Empty bytes
        assertNull(parseBinaryFrame(ByteArray(0)))
    }

    @Test
    fun testFrameSizeBoundary() {
        val customLimits = CborLimits(maxFrameBytes = 50)
        val header = buildHeader(op = 1, t = "#commit")
        val payload = buildSimpleMapPayload("seq", 123L)
        val validFrame = header + payload
        assertTrue(validFrame.size <= 50)

        // Valid frame within custom limit parses
        val result = parseBinaryFrame(validFrame, customLimits)
        assertNotNull(result)

        // Frame exceeding custom limit throws CborLimitExceeded(FRAME_SIZE)
        val oversizedFrame = ByteArray(51)
        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(oversizedFrame, customLimits)
        }
        assertEquals(CborLimitExceeded.Reason.FRAME_SIZE, ex.reason)

        // Default limit (5_000_000 bytes)
        val defaultEx = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(ByteArray(5_000_001))
        }
        assertEquals(CborLimitExceeded.Reason.FRAME_SIZE, defaultEx.reason)
    }

    @Test
    fun testDepth64PassesAndDepth65Throws() {
        val header = buildHeader(op = 1, t = "#commit")

        // Depth 64 in payload map: header is depth 1, payload root map is depth 1, nested inner is 62 levels -> total depth <= 64
        val limits = CborLimits(maxDepth = 64)

        // Nesting 62 levels inside payload map -> within maxDepth 64
        val payload62 = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1) // map of 1
            out.write(0x61) // "k"
            out.write('k'.code)
            out.write(buildNestedArray(62))
            out.toByteArray()
        }
        val frame62 = header + payload62
        val result62 = parseBinaryFrame(frame62, limits)
        assertNotNull(result62)

        // Nesting that reaches depth 65 -> throws CborLimitExceeded(DEPTH)
        val payload65 = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1)
            out.write(0x61)
            out.write('k'.code)
            out.write(buildNestedArray(65))
            out.toByteArray()
        }
        val frame65 = header + payload65
        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(frame65, limits)
        }
        assertEquals(CborLimitExceeded.Reason.DEPTH, ex.reason)
    }

    @Test
    fun testCustomDepthLimit() {
        val customLimits = CborLimits(maxDepth = 4)
        val header = buildHeader(op = 1, t = "#commit")

        // Payload with depth 5 inside payload (map -> array -> array -> array)
        val payloadDeep = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1)
            out.write(0x61)
            out.write('k'.code)
            out.write(buildNestedArray(4)) // 4 nested arrays inside map = depth 5
            out.toByteArray()
        }
        val frame = header + payloadDeep
        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(frame, customLimits)
        }
        assertEquals(CborLimitExceeded.Reason.DEPTH, ex.reason)
    }

    @Test
    fun testNestedTagsDepthBoundary() {
        val limits = CborLimits(maxDepth = 64)
        val header = buildHeader(op = 1, t = "#commit")

        // Payload with 65 nested tags -> throws CborLimitExceeded(DEPTH)
        val payloadTags = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1)
            out.write(0x61)
            out.write('k'.code)
            out.write(buildNestedTags(65))
            out.toByteArray()
        }
        val frame = header + payloadTags
        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(frame, limits)
        }
        assertEquals(CborLimitExceeded.Reason.DEPTH, ex.reason)
    }

    @Test
    fun testNode10000PassesAnd10001Throws() {
        val customLimits = CborLimits(maxNodes = 100)
        val header = buildHeader(op = 1, t = "#commit")

        // Frame with array of 50 items -> total nodes well within 100
        val payloadSmall = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1)
            out.write(0x61)
            out.write('k'.code)
            out.write(buildArrayWithNodes(50))
            out.toByteArray()
        }
        val frameSmall = header + payloadSmall
        val resultSmall = parseBinaryFrame(frameSmall, customLimits)
        assertNotNull(resultSmall)

        // Frame exceeding 100 nodes -> throws CborLimitExceeded(NODES)
        val payloadBig = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1)
            out.write(0x61)
            out.write('k'.code)
            out.write(buildArrayWithNodes(150))
            out.toByteArray()
        }
        val frameBig = header + payloadBig
        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(frameBig, customLimits)
        }
        assertEquals(CborLimitExceeded.Reason.NODES, ex.reason)
    }

    @Test
    fun testDefaultNodeLimit10000Boundary() {
        val limits = CborLimits(maxNodes = 10_000)
        val header = buildHeader(op = 1, t = "#commit")

        // Payload with array of 10_005 items -> exceeds 10,000 nodes
        val payloadOver10k = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1)
            out.write(0x61)
            out.write('k'.code)
            out.write(buildArrayWithNodes(10_005))
            out.toByteArray()
        }
        val frameOver10k = header + payloadOver10k
        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(frameOver10k, limits)
        }
        assertEquals(CborLimitExceeded.Reason.NODES, ex.reason)
    }

    @Test
    fun testDecodedBytesBoundary() {
        val customLimits = CborLimits(maxDecodedBytes = 100)
        val header = buildHeader(op = 1, t = "#commit")

        // Payload with 20-byte string (20 bytes raw + 28 bytes base64 + 10 header = 58 bytes) -> passes
        val payload20 = buildByteStringPayload(20)
        val frame20 = header + payload20
        val result20 = parseBinaryFrame(frame20, customLimits)
        assertNotNull(result20)

        // Payload with 150-byte string -> throws CborLimitExceeded(DECODED_BYTES)
        val payload150 = buildByteStringPayload(150)
        val frame150 = header + payload150
        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(frame150, customLimits)
        }
        assertEquals(CborLimitExceeded.Reason.DECODED_BYTES, ex.reason)
    }

    @Test
    fun testScannerRejectsNestedIndefiniteOrDeepStructures() {
        val customLimits = CborLimits(maxDepth = 3)
        // CBOR scanner must also enforce depth / node limits
        val deepData = buildNestedArray(10)
        val ex = assertThrows(CborLimitExceeded::class.java) {
            CborItemScanner.measureItem(deepData, 0, CborBudget(customLimits), 1)
        }
        assertEquals(CborLimitExceeded.Reason.DEPTH, ex.reason)
    }

    @Test
    fun testDefaultLimitsRejectDeepRecursionAttack() {
        val header = buildHeader(op = 1, t = "#commit")
        val deepPayload = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1) // map of 1
            out.write(0x61) // "k"
            out.write('k'.code)
            out.write(buildNestedArray(100_000))
            out.toByteArray()
        }
        val deepFrame = header + deepPayload

        // Must throw CborLimitExceeded(DEPTH) using the default single-argument entrypoint
        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(deepFrame)
        }
        assertEquals(CborLimitExceeded.Reason.DEPTH, ex.reason)
    }

    @Test
    fun testTransportFrameDispatchTerminatesAndNeverDispatchesFollowingFrameOnPoison() {
        val header = buildHeader(op = 1, t = "#commit")
        val validPayload1 = buildSimpleMapPayload("seq", 1L)
        val validFrame1 = header + validPayload1

        val poisonPayload = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1)
            out.write(0x61)
            out.write('k'.code)
            out.write(buildNestedArray(100))
            out.toByteArray()
        }
        val poisonFrame = header + poisonPayload

        val validPayload2 = buildSimpleMapPayload("seq", 2L)
        val validFrame2 = header + validPayload2

        val incomingFrames = listOf(validFrame1, poisonFrame, validFrame2)
        val dispatched = mutableListOf<CborFrame>()

        val ex = assertThrows(CborLimitExceeded::class.java) {
            for (frameBytes in incomingFrames) {
                val parsed = parseBinaryFrame(frameBytes)
                if (parsed != null) {
                    dispatched.add(parsed)
                }
            }
        }

        assertEquals(CborLimitExceeded.Reason.DEPTH, ex.reason)
        assertEquals(1, dispatched.size)
        val first = dispatched.first() as CborFrame.Message
        assertEquals(1, first.header.op)
    }

    @Test
    fun testMapHeaderSignedOverflowThrowsNodeLimit() {
        val header = buildHeader(op = 1, t = "#commit")
        // Construct a map with declared count 0x4000_0000_0000_0000L (2^62)
        val out = ByteArrayOutputStream()
        out.write(0xbb) // major type 5, additional info 27 (8-byte length)
        out.write(0x40)
        for (i in 1..7) out.write(0x00)
        val payload = out.toByteArray()
        val frame = header + payload

        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(frame)
        }
        assertEquals(CborLimitExceeded.Reason.NODES, ex.reason)
    }

    @Test
    fun testErrorFrameExceedingDepthLimitThrows() {
        val header = buildErrorHeader()
        val deepErrorPayload = run {
            val out = ByteArrayOutputStream()
            out.write(0xa1)
            out.write(0x61)
            out.write('k'.code)
            out.write(buildNestedArray(100))
            out.toByteArray()
        }
        val frame = header + deepErrorPayload

        val ex = assertThrows(CborLimitExceeded::class.java) {
            parseBinaryFrame(frame)
        }
        assertEquals(CborLimitExceeded.Reason.DEPTH, ex.reason)
    }
}
