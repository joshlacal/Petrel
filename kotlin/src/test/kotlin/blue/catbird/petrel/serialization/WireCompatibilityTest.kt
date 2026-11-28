package blue.catbird.petrel.serialization

import blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerPolicies
import blue.catbird.petrel.generated.AppBskyRichtextFacetByteSlice
import blue.catbird.petrel.generated.ComAtprotoLabelDefsLabelValue
import blue.catbird.petrel.generated.ComAtprotoModerationDefsReasonType
import blue.catbird.petrel.generated.NetworkBskyJetstreamPlanSnapshotInputKinds
import blue.catbird.petrel.generated.NetworkBskyJetstreamPlanSnapshotInputKindsSerializer
import blue.catbird.petrel.network.DEFAULT_JSON
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlinx.serialization.SerializationException
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Wire compatibility with deployed peers, matching the Rust and Swift tests:
 * a lexicon `enum` value a newer peer added, and floats in untyped positions.
 */
class WireCompatibilityTest {
    private val kinds = ListSerializer(NetworkBskyJetstreamPlanSnapshotInputKindsSerializer)

    @Test
    fun anEnumValueANewerPeerAddedDecodesAndIsWrittenBackUnchanged() {
        val decoded = DEFAULT_JSON.decodeFromString(kinds, """["commit","futureKind"]""")
        assertEquals(NetworkBskyJetstreamPlanSnapshotInputKinds.value_commit, decoded[0])
        assertIs<NetworkBskyJetstreamPlanSnapshotInputKinds.Unknown>(decoded[1])
        assertEquals("futureKind", decoded[1].value)
        assertEquals("""["commit","futureKind"]""", DEFAULT_JSON.encodeToString(kinds, decoded))
    }

    @Test
    fun enumEqualityFollowsTheWireString() {
        val unknownCommit = NetworkBskyJetstreamPlanSnapshotInputKinds.Unknown("commit")
        assertEquals<NetworkBskyJetstreamPlanSnapshotInputKinds>(NetworkBskyJetstreamPlanSnapshotInputKinds.value_commit, unknownCommit)
        assertEquals(NetworkBskyJetstreamPlanSnapshotInputKinds.value_commit.hashCode(), unknownCommit.hashCode())
        assertEquals(NetworkBskyJetstreamPlanSnapshotInputKinds.value_sync, NetworkBskyJetstreamPlanSnapshotInputKinds.fromValue("sync"))
        assertEquals(4, NetworkBskyJetstreamPlanSnapshotInputKinds.knownValues.size)
    }

    // A named `knownValues` string is open by definition: a labeler that advertises a
    // report reason this build does not know must not fail the whole labeler view.

    @Test
    fun aKnownValuesStringThisBuildDoesNotKnowDecodesAndIsWrittenBackUnchanged() {
        val reasons = ListSerializer(ComAtprotoModerationDefsReasonType.serializer())
        val json = """["com.atproto.moderation.defs#reasonSpam","tools.ozone.report.defs#reasonFuture"]"""
        val decoded = DEFAULT_JSON.decodeFromString(reasons, json)
        assertEquals(ComAtprotoModerationDefsReasonType.COM_ATPROTO_MODERATION_DEFS_REASONSPAM, decoded[0])
        assertIs<ComAtprotoModerationDefsReasonType.Unknown>(decoded[1])
        assertEquals("tools.ozone.report.defs#reasonFuture", decoded[1].value)
        assertEquals(json, DEFAULT_JSON.encodeToString(reasons, decoded))
        assertEquals<ComAtprotoModerationDefsReasonType>(
            ComAtprotoModerationDefsReasonType.COM_ATPROTO_MODERATION_DEFS_REASONSPAM,
            ComAtprotoModerationDefsReasonType.Unknown("com.atproto.moderation.defs#reasonSpam"),
        )
    }

    @Test
    fun aLabelerPolicyWithACustomLabelValueStillDecodes() {
        // labelValues is a knownValues list too; a labeler's own label is not in it.
        val policies = DEFAULT_JSON.decodeFromString(
            AppBskyLabelerDefsLabelerPolicies.serializer(),
            """{"labelValues":["spam","my-custom-label"],"labelValueDefinitions":[]}""",
        )
        assertEquals("spam", policies.labelValues[0].value)
        assertIs<ComAtprotoLabelDefsLabelValue.Unknown>(policies.labelValues[1])
        assertEquals("my-custom-label", policies.labelValues[1].value)
    }

    // Pinning: Kotlin keeps untyped positions as JsonElement, so a fractional number
    // there already survives decode and re-encode; typed integer fields refuse one.

    @Test
    fun aFractionalNumberInAnUntypedPositionSurvives() {
        val json = """{"error":"X","unknownField":{"list":[1,2.5],"score":0.75}}"""
        val element = DEFAULT_JSON.decodeFromString(JsonElement.serializer(), json)
        val inner = element.jsonObject["unknownField"]!!.jsonObject
        assertEquals("0.75", inner["score"]!!.jsonPrimitive.content)
        assertEquals(json, DEFAULT_JSON.encodeToString(JsonElement.serializer(), element))
        assertIs<JsonObject>(element)
        assertIs<JsonPrimitive>(inner["score"])
    }

    @Test
    fun aFractionalNumberInATypedIntegerFieldIsStillAnError() {
        assertFailsWith<SerializationException> {
            DEFAULT_JSON.decodeFromString(AppBskyRichtextFacetByteSlice.serializer(), """{"byteStart":1.5,"byteEnd":2}""")
        }
    }
}
