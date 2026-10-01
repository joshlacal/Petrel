package blue.catbird.petrel.serialization

import blue.catbird.petrel.core.types.ATProtocolDate
import blue.catbird.petrel.core.types.ATProtocolURI
import blue.catbird.petrel.core.types.DID
import blue.catbird.petrel.core.types.Handle
import blue.catbird.petrel.core.types.URI
import blue.catbird.petrel.generated.AppBskyActorDefsProfileViewBasic
import blue.catbird.petrel.generated.AppBskyEmbedImagesView
import blue.catbird.petrel.generated.AppBskyEmbedImagesViewImage
import blue.catbird.petrel.generated.AppBskyFeedDefsFeedViewPost
import blue.catbird.petrel.generated.AppBskyFeedDefsFeedViewPostReasonUnion
import blue.catbird.petrel.generated.AppBskyFeedDefsFeedViewPostReasonUnionSerializer
import blue.catbird.petrel.generated.AppBskyFeedDefsPostView
import blue.catbird.petrel.generated.AppBskyFeedDefsPostViewEmbedUnion
import blue.catbird.petrel.generated.AppBskyFeedDefsPostViewEmbedUnionSerializer
import blue.catbird.petrel.generated.AppBskyFeedDefsReasonPin
import blue.catbird.petrel.generated.AppBskyFeedDefsReasonRepost
import blue.catbird.petrel.network.DEFAULT_JSON
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.SerializationException
import kotlinx.serialization.cbor.Cbor
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

class PolymorphicUnionAdversarialTest {

    private val json = DEFAULT_JSON

    // =========================================================================
    // 1. WIRE FORMAT INVARIANTS
    // =========================================================================

    @Test
    fun `serialization ALWAYS emits $type as the FIRST key in the JSON object`() {
        // Test 1: ReasonPin (empty body class)
        val pin = AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin(AppBskyFeedDefsReasonPin())
        val pinJson = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, pin)
        val pinParsed = json.parseToJsonElement(pinJson).jsonObject
        assertEquals("\$type", pinParsed.keys.first(), "First key must be \$type for ReasonPin")
        assertEquals("app.bsky.feed.defs#reasonPin", pinParsed["\$type"]?.jsonPrimitive?.content)
        assertTrue(pinJson.trim().startsWith("{\"\$type\":\"app.bsky.feed.defs#reasonPin\""), "Wire string must start with \$type")

        // Test 2: ReasonRepost with multiple properties
        val repost = AppBskyFeedDefsFeedViewPostReasonUnion.ReasonRepost(
            AppBskyFeedDefsReasonRepost(
                by = AppBskyActorDefsProfileViewBasic(
                    did = DID.parse("did:plc:alice12345"),
                    handle = Handle("alice.bsky.social")
                ),
                indexedAt = ATProtocolDate("2026-10-01T00:00:00.000Z")
            )
        )
        val repostJson = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, repost)
        val repostParsed = json.parseToJsonElement(repostJson).jsonObject
        assertEquals("\$type", repostParsed.keys.first(), "First key must be \$type for ReasonRepost")
        assertEquals("app.bsky.feed.defs#reasonRepost", repostParsed["\$type"]?.jsonPrimitive?.content)
        assertTrue(repostJson.trim().startsWith("{\"\$type\":\"app.bsky.feed.defs#reasonRepost\""), "Wire string must start with \$type")

        // Test 3: PostViewEmbedUnion.View (Images)
        val imagesEmbed = AppBskyFeedDefsPostViewEmbedUnion.View(
            AppBskyEmbedImagesView(
                images = listOf(
                    AppBskyEmbedImagesViewImage(
                        thumb = URI.parse("https://example.com/thumb.jpg"),
                        fullsize = URI.parse("https://example.com/full.jpg"),
                        alt = "Test image"
                    )
                )
            )
        )
        val embedJson = json.encodeToString(AppBskyFeedDefsPostViewEmbedUnionSerializer, imagesEmbed)
        val embedParsed = json.parseToJsonElement(embedJson).jsonObject
        assertEquals("\$type", embedParsed.keys.first(), "First key must be \$type for PostViewEmbedUnion.View")
        assertEquals("app.bsky.embed.images#view", embedParsed["\$type"]?.jsonPrimitive?.content)
        assertTrue(embedJson.trim().startsWith("{\"\$type\":\"app.bsky.embed.images#view\""), "Wire string must start with \$type")
    }

    @Test
    fun `lexicon IDs match exact type identifiers across variants`() {
        val pin = AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin(AppBskyFeedDefsReasonPin())
        val pinJson = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, pin)
        val pinParsed = json.parseToJsonElement(pinJson).jsonObject
        assertEquals("app.bsky.feed.defs#reasonPin", pinParsed["\$type"]?.jsonPrimitive?.content)

        val repost = AppBskyFeedDefsFeedViewPostReasonUnion.ReasonRepost(
            AppBskyFeedDefsReasonRepost(
                by = AppBskyActorDefsProfileViewBasic(
                    did = DID.parse("did:plc:alice12345"),
                    handle = Handle("alice.bsky.social")
                ),
                indexedAt = ATProtocolDate("2026-10-01T00:00:00.000Z")
            )
        )
        val repostJson = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, repost)
        val repostParsed = json.parseToJsonElement(repostJson).jsonObject
        assertEquals("app.bsky.feed.defs#reasonRepost", repostParsed["\$type"]?.jsonPrimitive?.content)
    }

    @Test
    fun `serializing Unexpected variant preserves underlying JsonElement transparently`() {
        // 1. Unexpected JsonObject
        val customObj = buildJsonObject {
            put("\$type", "custom.future.lexicon#entity")
            put("customField", "value123")
        }
        val unexpectedObj = AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected(customObj)
        val serializedObj = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, unexpectedObj)
        assertEquals(customObj.toString(), serializedObj)

        // 2. Unexpected JsonPrimitive string
        val unexpectedString = AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected(JsonPrimitive("raw-string"))
        val serializedString = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, unexpectedString)
        assertEquals("\"raw-string\"", serializedString)

        // 3. Unexpected JsonPrimitive number
        val unexpectedNum = AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected(JsonPrimitive(42))
        val serializedNum = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, unexpectedNum)
        assertEquals("42", serializedNum)

        // 4. Unexpected JsonArray
        val unexpectedArray = AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected(
            JsonArray(listOf(JsonPrimitive("a"), JsonPrimitive("b")))
        )
        val serializedArray = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, unexpectedArray)
        assertEquals("[\"a\",\"b\"]", serializedArray)

        // 5. Unexpected JsonNull
        val unexpectedNull = AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected(JsonNull)
        val serializedNull = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, unexpectedNull)
        assertEquals("null", serializedNull)
    }

    // =========================================================================
    // 2. DESERIALIZATION FALLBACK (ADVERSARIAL & EDGE CASES)
    // =========================================================================

    @Test
    fun `deserializing primitive JSON values safely produces Unexpected without throwing`() {
        // String primitive
        val stringResult = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "\"just a string\"")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(stringResult)
        assertEquals(JsonPrimitive("just a string"), stringResult.value)

        // Integer primitive
        val intResult = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "42")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(intResult)
        assertEquals(42, (intResult.value as JsonPrimitive).intOrNull)

        // Float primitive
        val floatResult = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "3.14159")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(floatResult)
        assertEquals("3.14159", (floatResult.value as JsonPrimitive).content)

        // Boolean primitive (true)
        val boolTrueResult = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "true")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(boolTrueResult)
        assertEquals(true, (boolTrueResult.value as JsonPrimitive).booleanOrNull)

        // Boolean primitive (false)
        val boolFalseResult = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "false")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(boolFalseResult)
        assertEquals(false, (boolFalseResult.value as JsonPrimitive).booleanOrNull)

        // Null primitive
        val nullResult = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "null")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(nullResult)
        assertEquals(JsonNull, nullResult.value)
    }

    @Test
    fun `deserializing JSON array values safely produces Unexpected without throwing`() {
        // Empty array
        val emptyArrayResult = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "[]")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(emptyArrayResult)
        assertIs<JsonArray>(emptyArrayResult.value)
        assertEquals(0, (emptyArrayResult.value as JsonArray).size)

        // Array with primitives
        val arrayWithPrims = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "[1, \"two\", false]")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(arrayWithPrims)
        assertIs<JsonArray>(arrayWithPrims.value)
        assertEquals(3, (arrayWithPrims.value as JsonArray).size)

        // Array with objects
        val arrayWithObjects = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "[{\"\$type\": \"app.bsky.feed.defs#reasonPin\"}]"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(arrayWithObjects)
        assertIs<JsonArray>(arrayWithObjects.value)
    }

    @Test
    fun `deserializing JSON object with missing $type safely produces Unexpected`() {
        // Empty object
        val emptyObjResult = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, "{}")
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(emptyObjResult)
        assertIs<JsonObject>(emptyObjResult.value)
        assertTrue((emptyObjResult.value as JsonObject).isEmpty())

        // Object with other fields but no $type
        val fieldsWithoutType = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"author\": \"alice\", \"count\": 5}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(fieldsWithoutType)
        val obj = fieldsWithoutType.value as JsonObject
        assertEquals("alice", obj["author"]?.jsonPrimitive?.content)
        assertEquals(5, obj["count"]?.jsonPrimitive?.intOrNull)

        // Misspelled 'type' instead of '$type'
        val wrongKey = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"type\": \"app.bsky.feed.defs#reasonPin\"}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(wrongKey)

        // Wrong casing '$Type'
        val wrongCasing = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"\$Type\": \"app.bsky.feed.defs#reasonPin\"}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(wrongCasing)
    }

    @Test
    fun `deserializing JSON object with non-string $type safely produces Unexpected`() {
        // Integer $type
        val intType = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"\$type\": 12345, \"data\": \"sample\"}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(intType)
        assertIs<JsonObject>(intType.value)

        // Boolean $type
        val boolType = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"\$type\": true}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(boolType)

        // Null $type
        val nullType = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"\$type\": null}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(nullType)

        // Array $type
        val arrayType = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"\$type\": [\"app.bsky.feed.defs#reasonPin\"]}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(arrayType)

        // Object $type
        val objType = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"\$type\": {\"name\": \"app.bsky.feed.defs#reasonPin\"}}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(objType)
    }

    @Test
    fun `deserializing unrecognized or future $type produces Unexpected preserving all fields`() {
        val futureJson = """
            {
                "${'$'}type": "app.bsky.feed.defs#futurePostReason2027",
                "futureField": "futureValue",
                "nested": { "count": 42 },
                "tags": ["fast", "experimental"]
            }
        """.trimIndent()

        val result = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, futureJson)
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(result)
        val obj = result.value as JsonObject
        assertEquals("app.bsky.feed.defs#futurePostReason2027", obj["\$type"]?.jsonPrimitive?.content)
        assertEquals("futureValue", obj["futureField"]?.jsonPrimitive?.content)
        assertEquals(42, obj["nested"]?.jsonObject?.get("count")?.jsonPrimitive?.intOrNull)
        assertEquals(2, (obj["tags"] as JsonArray).size)

        // Empty string $type
        val emptyTypeResult = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"\$type\": \"\"}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(emptyTypeResult)

        // Whitespace $type
        val whitespaceTypeResult = json.decodeFromString(
            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
            "{\"\$type\": \"   \"}"
        )
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(whitespaceTypeResult)
    }

    @Test
    fun `known variant with extra unknown fields succeeds under DEFAULT_JSON`() {
        val extraFieldsJson = """
            {
                "${'$'}type": "app.bsky.feed.defs#reasonPin",
                "unknownField": "shouldBeIgnored",
                "extraNumeric": 99999,
                "nestedObject": { "flag": true }
            }
        """.trimIndent()

        // DEFAULT_JSON has ignoreUnknownKeys = true
        val result = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, extraFieldsJson)
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin>(result)
        assertNotNull(result.value)

        // Strict JSON with ignoreUnknownKeys = false fails on the inner class decoding
        val strictJson = Json { ignoreUnknownKeys = false }
        assertFailsWith<SerializationException> {
            strictJson.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, extraFieldsJson)
        }
    }

    @Test
    fun `enclosing model with polymorphic union fallback handles future and malformed variants`() {
        // Enclosing model: AppBskyFeedDefsFeedViewPost containing reason: AppBskyFeedDefsFeedViewPostReasonUnion?
        val postViewJson = """
            {
                "uri": "at://did:plc:alice123/app.bsky.feed.post/3k12345",
                "cid": "bafyreitest12345",
                "author": {
                    "did": "did:plc:alice123",
                    "handle": "alice.bsky.social"
                },
                "record": {},
                "indexedAt": "2026-10-01T00:00:00.000Z"
            }
        """.trimIndent()

        // 1. Parent post with future unrecognized reason
        val feedViewWithFutureReason = """
            {
                "post": $postViewJson,
                "reason": {
                    "${'$'}type": "app.bsky.feed.defs#quantumBoost2030",
                    "boostMultiplier": 5
                }
            }
        """.trimIndent()

        val parsedFeedFuture = json.decodeFromString<AppBskyFeedDefsFeedViewPost>(feedViewWithFutureReason)
        assertNotNull(parsedFeedFuture.reason)
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(parsedFeedFuture.reason)
        val reasonObj = (parsedFeedFuture.reason as AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected).value as JsonObject
        assertEquals("app.bsky.feed.defs#quantumBoost2030", reasonObj["\$type"]?.jsonPrimitive?.content)

        // 2. Parent post with primitive reason (e.g. malformed backend)
        val feedViewWithPrimitiveReason = """
            {
                "post": $postViewJson,
                "reason": "malformedStringReason"
            }
        """.trimIndent()

        val parsedFeedPrim = json.decodeFromString<AppBskyFeedDefsFeedViewPost>(feedViewWithPrimitiveReason)
        assertNotNull(parsedFeedPrim.reason)
        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(parsedFeedPrim.reason)
        assertEquals(
            "malformedStringReason",
            ((parsedFeedPrim.reason as AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected).value as JsonPrimitive).content
        )

        // 3. Parent post with missing reason (null)
        val feedViewWithNullReason = """
            {
                "post": $postViewJson,
                "reason": null
            }
        """.trimIndent()

        val parsedFeedNull = json.decodeFromString<AppBskyFeedDefsFeedViewPost>(feedViewWithNullReason)
        assertNull(parsedFeedNull.reason)
    }

    // =========================================================================
    // 3. CODEC ASYMMETRY / NON-JSON CODEC INVESTIGATION
    // =========================================================================

    @Test
    fun `non-JsonDecoder cleanly throws SerializationException`() {
        val dummyCborBytes = byteArrayOf(0xa1.toByte(), 0x61.toByte(), 0x61.toByte(), 0x01.toByte())
        val ex = assertFailsWith<SerializationException> {
            Cbor.decodeFromByteArray(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, dummyCborBytes)
        }
        assertTrue(ex.message!!.contains("can only be deserialized from JSON"), "Should state JSON only")
    }

    @Test
    fun `non-JsonEncoder throws ClassCastException due to direct cast in serialize`() {
        val pin = AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin(AppBskyFeedDefsReasonPin())
        // Serializing with Cbor encoder uses CborEncoder, triggering `encoder as JsonEncoder`
        assertFailsWith<ClassCastException> {
            Cbor.encodeToByteArray(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, pin)
        }
    }

    // =========================================================================
    // 4. MEMORY / THROUGHPUT / CONCURRENCY VERIFICATION
    // =========================================================================

    @Test
    fun `stress test rapid serialization and deserialization across 10000 iterations without memory leaks or crashes`() {
        val iterations = 10_000

        val pin = AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin(AppBskyFeedDefsReasonPin())
        val futureJson = """{"${'$'}type":"app.bsky.feed.defs#future2027","count":42}"""
        val malformedJson = "\"unexpectedPrimitive\""

        val startTime = System.currentTimeMillis()

        for (i in 0 until iterations) {
            // 1. Serialize known variant
            val serialized = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, pin)
            assertTrue(serialized.contains("app.bsky.feed.defs#reasonPin"))

            // 2. Deserialize known variant
            val decodedPin = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, serialized)
            assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin>(decodedPin)

            // 3. Deserialize future variant
            val decodedFuture = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, futureJson)
            assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(decodedFuture)

            // 4. Deserialize primitive fallback
            val decodedMalformed = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, malformedJson)
            assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(decodedMalformed)
        }

        val elapsed = System.currentTimeMillis() - startTime
        assertTrue(elapsed < 10_000, "10,000 iterations across 4 operations took ${elapsed}ms (expected < 10s)")
    }

    @Test
    fun `concurrent serialization and deserialization under coroutines is thread-safe`() {
        runBlocking {
            val jobs = (1..100).map { workerId ->
                async(Dispatchers.Default) {
                    for (j in 1..100) {
                        val pin = AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin(AppBskyFeedDefsReasonPin())
                        val jsonStr = json.encodeToString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, pin)
                        val parsed = json.decodeFromString(AppBskyFeedDefsFeedViewPostReasonUnionSerializer, jsonStr)
                        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin>(parsed)

                        val unk = json.decodeFromString(
                            AppBskyFeedDefsFeedViewPostReasonUnionSerializer,
                            "{\"worker\": $workerId, \"iter\": $j}"
                        )
                        assertIs<AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected>(unk)
                    }
                }
            }
            jobs.awaitAll()
        }
    }
}
