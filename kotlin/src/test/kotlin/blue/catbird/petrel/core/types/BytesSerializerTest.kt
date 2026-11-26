package blue.catbird.petrel.core.types

import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/**
 * `$bytes` interop. The official TypeScript PDS and Petrel Rust emit
 * unpadded standard base64; Swift Petrel and Jacquard emit padded; some
 * peers use the URL-safe alphabet. Every one must decode.
 */
class BytesSerializerTest {

    private val expected = byteArrayOf(0xfb.toByte(), 0xff.toByte(), 0xbf.toByte(), 0x01)

    private fun decode(base64: String): Bytes =
        Json.decodeFromString(BytesSerializer, """{"${'$'}bytes":"$base64"}""")

    @Test
    fun `decodes padded, unpadded and url-safe base64`() {
        for (text in listOf("+/+/AQ==", "+/+/AQ", "-_-_AQ==", "-_-_AQ")) {
            assertContentEquals(expected, decode(text).data, text)
        }
    }

    @Test
    fun `ignores non-zero trailing bits like the other implementations`() {
        // The official interop vector `lexicon/record-data-valid.json`.
        assertContentEquals(byteArrayOf(0xd7.toByte(), 0x6d), decode("123").data)
    }

    @Test
    fun `refuses malformed padding and mixed alphabets`() {
        for (text in listOf("AA=", "AA===", "A", "+_+_AQ")) {
            assertFailsWith<IllegalArgumentException>(text) { decode(text) }
        }
    }

    @Test
    fun `encodes padded standard base64 as before`() {
        val json = Json.encodeToString(BytesSerializer, Bytes(expected))
        assertEquals("""{"${'$'}bytes":"+/+/AQ=="}""", json)
    }
}
