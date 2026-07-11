package blue.catbird.petrel.core.types

import blue.catbird.petrel.generated.ComAtprotoRepoCreateRecordInput
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.encodeToString
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Regression test for the ATIdentifier serialization bug that produced
 * `"repo":"DIDIdentifier(did=did:plc:...)"` on the wire and caused every
 * createRecord write (like/repost/post) to 400 with InvalidRequest.
 *
 * Root cause: a `data class` subclass of a sealed base gets a compiler-generated
 * toString() that shadows the base override unless the base override is `final`.
 * ATIdentifierSerializer previously encoded value.toString().
 */
class ATIdentifierSerializerTest {

    @Test
    fun `DIDIdentifier serializes to bare DID string`() {
        val id = ATIdentifier.parse("did:plc:abc")
        val json = Json.encodeToString(ATIdentifierSerializer, id)
        assertEquals("\"did:plc:abc\"", json)
        assertFalse(json.contains("DIDIdentifier("), "must not leak data-class toString")
    }

    @Test
    fun `HandleIdentifier serializes to bare handle string`() {
        val id = ATIdentifier.parse("alice.bsky.social")
        val json = Json.encodeToString(ATIdentifierSerializer, id)
        assertEquals("\"alice.bsky.social\"", json)
        assertFalse(json.contains("HandleIdentifier("), "must not leak data-class toString")
    }

    @Test
    fun `ATIdentifier toString on DID subclass returns bare DID`() {
        // The compiler-generated data-class toString must be suppressed by the
        // final base override.
        assertEquals("did:plc:abc", ATIdentifier.parse("did:plc:abc").toString())
    }

    @Test
    fun `createRecord input emits bare DID for repo field`() {
        val input = ComAtprotoRepoCreateRecordInput(
            repo = ATIdentifier.parse("did:plc:34x52srgxttjewbke5hguloh"),
            collection = NSID.parse("app.bsky.feed.like"),
            record = buildJsonObject {
                put("\$type", "app.bsky.feed.like")
            }
        )
        val body = Json.encodeToString(input)
        assertTrue(
            body.contains("\"repo\":\"did:plc:34x52srgxttjewbke5hguloh\""),
            "repo must serialize as a bare DID, got: $body"
        )
        assertFalse(body.contains("DIDIdentifier("), "must not leak data-class toString: $body")
    }
}
