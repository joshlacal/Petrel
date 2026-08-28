package blue.catbird.petrel.core.types

import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class SpaceRefTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun testValidSpaceRefs() {
        val validUris = listOf(
            "at://did:plc:asdf123/space/com.example.group/default",
            "at://did:plc:owner/space/blue.catbird.circle/3abc",
            "at://did:web:example.com/space/blue.catbird.circle/3abc",
            "at://did:plc:owner/space/com.atproto.simplespace.space/tid123",
            "at://did:plc:auth123/space/com.example.drive/self",
            "at://did:plc:asdf123/space/com.example.group/test-key_123",
            "at://did:plc:asdf123/space/com.example.group/2024-01-01",
            "at://did:plc:asdf123/space/com.example.group/rkey:~._-"
        )

        for (uri in validUris) {
            val spaceRef = SpaceRef.parse(uri)
            assertEquals(uri, spaceRef.toString())
            assertEquals(uri, spaceRef.value)
            assertEquals(uri, spaceRef.uriString())

            // Round-trip through JSON serialization
            val encoded = json.encodeToString(SpaceRefSerializer, spaceRef)
            assertEquals("\"$uri\"", encoded)
            val decoded = json.decodeFromString(SpaceRefSerializer, encoded)
            assertEquals(spaceRef, decoded)
            assertEquals(uri, decoded.toString())
        }

        // 512-character record key (max valid length)
        val valid512 = "at://did:plc:asdf123/space/com.example.group/" + "a".repeat(512)
        val spaceRef512 = SpaceRef.parse(valid512)
        assertEquals(valid512, spaceRef512.toString())
        val decoded512 = json.decodeFromString(SpaceRefSerializer, "\"$valid512\"")
        assertEquals(valid512, decoded512.toString())
    }

    @Test
    fun testSpaceRefCreateFromParts() {
        val ref = SpaceRef.create(
            spaceDID = "did:plc:asdf123",
            spaceType = "com.example.group",
            skey = "default"
        )
        assertEquals("did:plc:asdf123", ref.spaceDID)
        assertEquals("com.example.group", ref.spaceType)
        assertEquals("default", ref.skey)
        assertEquals("at://did:plc:asdf123/space/com.example.group/default", ref.toString())
    }

    @Test
    fun testMalformedSpaceRefsRejectedByConstructorAndDeserializer() {
        val malformedUris = listOf(
            // Scheme / prefix errors
            "https://example.com/space/blue.catbird.circle/3abc",
            "at:/did:plc:asdf123/space/com.example.group/default",
            "AT://did:plc:asdf123/space/com.example.group/default",
            // Segment count and structure errors
            "at://did:plc:asdf123",
            "at://did:plc:asdf123/space",
            "at://did:plc:asdf123/space/com.example.group",
            "at://did:plc:asdf123/space/com.example.group/default/extra",
            "at://did:plc:asdf123/space/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123",
            "at://did:plc:asdf123/com.atproto.feed.post/abc",
            "at://did:plc:asdf123/space//default",
            "at://did:plc:asdf123/space/com.example.group/",
            "at:///space/com.example.group/default",
            "at://did:plc:asdf123//com.example.group/default",
            "at://did:plc:asdf123/other/com.example.group/default",
            // Authority DID errors
            "at://user.bsky.social/space/com.example.group/default",
            "at://did::owner/space/blue.catbird.circle/3abc",
            "at://did:plc:/space/blue.catbird.circle/3abc",
            "at://invalid-did/space/blue.catbird.circle/3abc",
            // SpaceType NSID errors
            "at://did:plc:asdf123/space/short/default",
            "at://did:plc:asdf123/space/-bad.example/3abc",
            "at://did:plc:asdf123/space/com.example.-group/default",
            "at://did:plc:asdf123/space/com.example..group/default",
            "at://did:plc:asdf123/space/1com.example.group/default",
            // Skey RecordKey errors
            "at://did:plc:asdf123/space/com.example.group/.",
            "at://did:plc:asdf123/space/com.example.group/..",
            "at://did:plc:asdf123/space/com.example.group/has space",
            "at://did:plc:asdf123/space/com.example.group/has/slash",
            "at://did:plc:asdf123/space/com.example.group/has@invalid"
        )

        for (uri in malformedUris) {
            assertThrows(IllegalArgumentException::class.java, {
                SpaceRef.parse(uri)
            }, "SpaceRef.parse should reject: $uri")

            assertThrows(Exception::class.java, {
                json.decodeFromString(SpaceRefSerializer, "\"$uri\"")
            }, "Deserialization should reject: $uri")
        }

        // Skey length > 512
        val overlengthSkey = "at://did:plc:asdf123/space/com.example.group/" + "a".repeat(513)
        assertThrows(IllegalArgumentException::class.java) {
            SpaceRef.parse(overlengthSkey)
        }
        assertThrows(Exception::class.java) {
            json.decodeFromString(SpaceRefSerializer, "\"$overlengthSkey\"")
        }

        // Total length > 8192
        val overlengthUri = "at://did:plc:asdf123/space/com.example.group/" + "a".repeat(8200)
        assertThrows(IllegalArgumentException::class.java) {
            SpaceRef.parse(overlengthUri)
        }
        assertThrows(Exception::class.java) {
            json.decodeFromString(SpaceRefSerializer, "\"$overlengthUri\"")
        }
    }

    @Test
    fun testRecordKeyValidation() {
        assertTrue(RecordKey.isValidRecordKey("self"))
        assertTrue(RecordKey.isValidRecordKey("abc123"))
        assertTrue(RecordKey.isValidRecordKey("test-key_123"))
        assertTrue(RecordKey.isValidRecordKey("2024-01-01"))
        assertTrue(RecordKey.isValidRecordKey("rkey:~._-"))
        assertTrue(RecordKey.isValidRecordKey("a".repeat(512)))

        assertFalse(RecordKey.isValidRecordKey(""))
        assertFalse(RecordKey.isValidRecordKey("."))
        assertFalse(RecordKey.isValidRecordKey(".."))
        assertFalse(RecordKey.isValidRecordKey("has space"))
        assertFalse(RecordKey.isValidRecordKey("has/slash"))
        assertFalse(RecordKey.isValidRecordKey("has@invalid"))
        assertFalse(RecordKey.isValidRecordKey("a".repeat(513)))
    }
}
