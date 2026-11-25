package blue.catbird.petrel.core.types

import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SpaceRefTest {

    @Test
    fun `SpaceRef accepts valid canonical vectors`() {
        val validURIs = listOf(
            "at:space/did:m:v/com.example.group/default",
            "at:space/did:plc:asdf123/com.example.group/default",
            "at:space/did:plc:owner/blue.catbird.circle/3abc",
            "at:space/did:web:example.com/blue.catbird.circle/3abc",
            "at:space/did:plc:owner/com.atproto.simplespace.space/tid123",
            "at:space/did:plc:auth123/com.example.drive/self",
            "at:space/did:plc:asdf123/com.example.group/test-key_123",
            "at:space/did:plc:asdf123/com.example.group/2024-01-01",
            "at:space/did:plc:asdf123/com.example.group/rkey:~._-"
        )

        for (uri in validURIs) {
            val ref = SpaceRef.parse(uri)
            assertEquals(uri, ref.value)
            assertEquals(uri, ref.toString())
            assertEquals(uri, ref.uriString())

            val json = Json.encodeToString(ref)
            assertEquals("\"$uri\"", json)
            val decoded = Json.decodeFromString<SpaceRef>(json)
            assertEquals(ref, decoded)
        }

        val did2048 = "did:plc:" + "a".repeat(2040)
        val validDID2048URI = "at:space/$did2048/com.example.group/default"
        val refDID2048 = SpaceRef.parse(validDID2048URI)
        assertEquals(validDID2048URI, refDID2048.value)

        val nsid317 = "com.example." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(49)
        val validNSID317URI = "at:space/did:plc:asdf123/$nsid317/default"
        val refNSID317 = SpaceRef.parse(validNSID317URI)
        assertEquals(validNSID317URI, refNSID317.value)

        val valid512 = "at:space/did:plc:asdf123/com.example.group/" + "a".repeat(512)
        val ref512 = SpaceRef.parse(valid512)
        assertEquals(valid512, ref512.value)
    }

    @Test
    fun `SpaceRef rejects all malformed vectors`() {
        val did2049 = "did:plc:" + "a".repeat(2041)
        val nsid318 = "com.example." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(50)

        val malformedURIs = listOf(
            // Scheme / prefix errors
            "https://example.com/space/blue.catbird.circle/3abc",
            "at:space",
            "at:/space/did:plc:asdf123/com.example.group/default",
            "at:space:did:plc:asdf123/com.example.group/default",
            "AT:SPACE/did:plc:asdf123/com.example.group/default",
            // The spaces alpha form is rejected strictly
            "at://did:plc:asdf123/space/com.example.group/default",
            "at://did:web:example.com/space/blue.catbird.circle/3abc",
            // Segment count and structure errors
            "at://did:plc:asdf123",
            "at:space/did:plc:asdf123",
            "at:space/did:plc:asdf123/com.example.group",
            "at:space/did:plc:asdf123/com.example.group/default/extra",
            "at:space/did:plc:asdf123/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123",
            "at://did:plc:asdf123/com.atproto.feed.post/abc",
            "at:space/did:plc:asdf123//default",
            "at:space/did:plc:asdf123/com.example.group/",
            "at:space//com.example.group/default",
            "at:space//did:plc:asdf123/com.example.group/default",
            "at:other/did:plc:asdf123/com.example.group/default",
            // Authority DID errors
            "at:space/user.bsky.social/com.example.group/default",
            "at:space/did::owner/blue.catbird.circle/3abc",
            "at:space/did:plc:/blue.catbird.circle/3abc",
            "at:space/invalid-did/blue.catbird.circle/3abc",
            "at:space/did:plc:ünicode/com.example.group/default",
            "at:space/$did2049/com.example.group/default",
            // SpaceType NSID errors
            "at:space/did:plc:asdf123/short/default",
            "at:space/did:plc:asdf123/-bad.example/3abc",
            "at:space/did:plc:asdf123/com.example.-group/default",
            "at:space/did:plc:asdf123/com.example..group/default",
            "at:space/did:plc:asdf123/1com.example.group/default",
            "at:space/did:plc:asdf123/$nsid318/default",
            // Skey RecordKey errors
            "at:space/did:plc:asdf123/com.example.group/.",
            "at:space/did:plc:asdf123/com.example.group/..",
            "at:space/did:plc:asdf123/com.example.group/has space",
            "at:space/did:plc:asdf123/com.example.group/has/slash",
            "at:space/did:plc:asdf123/com.example.group/has@invalid",
            "at:space/did:plc:asdf123/com.example.group/has%percent"
        )

        for (uri in malformedURIs) {
            assertFailsWith<IllegalArgumentException>("Expected parse rejection for: $uri") {
                SpaceRef.parse(uri)
            }
            assertFailsWith<SerializationException>("Expected deserialization rejection for: $uri") {
                Json.decodeFromString<SpaceRef>("\"$uri\"")
            }
        }

        val overlengthSkey = "at:space/did:plc:asdf123/com.example.group/" + "a".repeat(513)
        assertFailsWith<IllegalArgumentException> {
            SpaceRef.parse(overlengthSkey)
        }
        assertFailsWith<SerializationException> {
            Json.decodeFromString<SpaceRef>("\"$overlengthSkey\"")
        }

        val overlengthURI = "at:space/did:plc:asdf123/com.example.group/" + "a".repeat(8200)
        assertFailsWith<IllegalArgumentException> {
            SpaceRef.parse(overlengthURI)
        }
        assertFailsWith<SerializationException> {
            Json.decodeFromString<SpaceRef>("\"$overlengthURI\"")
        }
    }

    @Test
    fun `SpaceRef component factory routes through full validation`() {
        val valid = SpaceRef.create("did:m:v", "com.example.group", "default")
        assertEquals("at:space/did:m:v/com.example.group/default", valid.value)
        assertEquals("did:m:v", valid.spaceDID)
        assertEquals("com.example.group", valid.spaceType)
        assertEquals("default", valid.skey)

        val did2049 = "did:plc:" + "a".repeat(2041)
        assertFailsWith<IllegalArgumentException> {
            SpaceRef.create(did2049, "com.example.group", "default")
        }

        val nsid318 = "com.example." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(63) + "." + "a".repeat(50)
        assertFailsWith<IllegalArgumentException> {
            SpaceRef.create("did:plc:asdf123", nsid318, "default")
        }

        assertFailsWith<IllegalArgumentException> {
            SpaceRef.create("did:plc:asdf123", "com.example.group", "has%percent")
        }
        assertFailsWith<IllegalArgumentException> {
            SpaceRef.create("did:plc:asdf123", "com.example.group", ".")
        }
        assertFailsWith<IllegalArgumentException> {
            SpaceRef.create("did:plc:asdf123", "com.example.group", "..")
        }
    }

    @Test
    fun `fromLegacySpaceUri rewrites only the spaces alpha form`() {
        assertEquals(
            "at:space/did:plc:asdf123/com.example.group/default",
            SpaceRef.fromLegacySpaceUri("at://did:plc:asdf123/space/com.example.group/default")
        )
        assertEquals(
            "at:space/did:plc:asdf123/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123",
            SpaceRef.fromLegacySpaceUri(
                "at://did:plc:asdf123/space/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123"
            )
        )
        assertEquals(null, SpaceRef.fromLegacySpaceUri("at:space/did:plc:asdf123/com.example.group/default"))
        assertEquals(null, SpaceRef.fromLegacySpaceUri("at://did:plc:asdf123/com.atproto.feed.post/abc"))
        assertEquals(null, SpaceRef.fromLegacySpaceUri("at://did:plc:asdf123/space"))
    }

    @Test
    fun `RecordKey validation matches specification`() {
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
