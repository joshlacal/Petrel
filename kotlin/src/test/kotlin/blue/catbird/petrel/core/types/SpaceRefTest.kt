package blue.catbird.petrel.core.types

import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class SpaceRefTest {

    @Test
    fun `SpaceRef accepts valid canonical vectors`() {
        val validURIs = listOf(
            "at://did:plc:asdf123/space/com.example.group/default",
            "at://did:plc:owner/space/blue.catbird.circle/3abc",
            "at://did:web:example.com/space/blue.catbird.circle/3abc",
            "at://did:plc:owner/space/com.atproto.simplespace.space/tid123",
            "at://did:plc:auth123/space/com.example.drive/self",
            "at://did:plc:asdf123/space/com.example.group/test-key_123",
            "at://did:plc:asdf123/space/com.example.group/2024-01-01",
            "at://did:plc:asdf123/space/com.example.group/rkey:~._-"
        )

        for (uri in validURIs) {
            val ref = SpaceRef.parse(uri)
            assertEquals(uri, ref.value)
            assertEquals(uri, ref.toString())

            val json = Json.encodeToString(ref)
            assertEquals("\"$uri\"", json)
            val decoded = Json.decodeFromString<SpaceRef>(json)
            assertEquals(ref, decoded)
        }

        val valid512 = "at://did:plc:asdf123/space/com.example.group/" + "a".repeat(512)
        val ref512 = SpaceRef.parse(valid512)
        assertEquals(valid512, ref512.value)
    }

    @Test
    fun `SpaceRef rejects all malformed vectors`() {
        val malformedURIs = listOf(
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

        for (uri in malformedURIs) {
            assertFailsWith<IllegalArgumentException>("Expected parse rejection for: $uri") {
                SpaceRef.parse(uri)
            }
            assertFailsWith<SerializationException>("Expected deserialization rejection for: $uri") {
                Json.decodeFromString<SpaceRef>("\"$uri\"")
            }
        }

        val overlengthSkey = "at://did:plc:asdf123/space/com.example.group/" + "a".repeat(513)
        assertFailsWith<IllegalArgumentException> {
            SpaceRef.parse(overlengthSkey)
        }
        assertFailsWith<SerializationException> {
            Json.decodeFromString<SpaceRef>("\"$overlengthSkey\"")
        }

        val overlengthURI = "at://did:plc:asdf123/space/com.example.group/" + "a".repeat(8200)
        assertFailsWith<IllegalArgumentException> {
            SpaceRef.parse(overlengthURI)
        }
        assertFailsWith<SerializationException> {
            Json.decodeFromString<SpaceRef>("\"$overlengthURI\"")
        }
    }
}
