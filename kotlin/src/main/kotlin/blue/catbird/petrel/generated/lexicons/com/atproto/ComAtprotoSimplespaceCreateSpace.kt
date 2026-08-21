// Lexicon: 1, ID: com.atproto.simplespace.createSpace
// Create a new space managed by the simplespace implementation. The space is anchored on the authenticated user's DID, who becomes the space owner. Requires auth, implemented by PDS.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSimplespaceCreateSpaceDefs {
    const val TYPE_IDENTIFIER = "com.atproto.simplespace.createSpace"
}

@Serializable(with = ComAtprotoSimplespaceCreateSpaceInputPolicyUnionSerializer::class)
sealed interface ComAtprotoSimplespaceCreateSpaceInputPolicyUnion {
    @Serializable
    data class PublicPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy) : ComAtprotoSimplespaceCreateSpaceInputPolicyUnion

    @Serializable
    data class MemberListPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy) : ComAtprotoSimplespaceCreateSpaceInputPolicyUnion

    @Serializable
    data class ManagingAppPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy) : ComAtprotoSimplespaceCreateSpaceInputPolicyUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoSimplespaceCreateSpaceInputPolicyUnion
}

object ComAtprotoSimplespaceCreateSpaceInputPolicyUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoSimplespaceCreateSpaceInputPolicyUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoSimplespaceCreateSpaceInputPolicyUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoSimplespaceCreateSpaceInputPolicyUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoSimplespaceCreateSpaceInputPolicyUnion.PublicPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#publicPolicy")
                })
            }
            is ComAtprotoSimplespaceCreateSpaceInputPolicyUnion.MemberListPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#memberListPolicy")
                })
            }
            is ComAtprotoSimplespaceCreateSpaceInputPolicyUnion.ManagingAppPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#managingAppPolicy")
                })
            }
            is ComAtprotoSimplespaceCreateSpaceInputPolicyUnion.Unexpected -> value.value
            // Synthetic variants (e.g. <Union>Error / <Union>Unexpected added by
            // subscription codegen) are runtime-only sentinels; JSON round-trip
            // serialises them as an empty object tagged with the variant class
            // name. Consumers should filter these before JSON serialisation.
            else -> kotlinx.serialization.json.buildJsonObject {
                put("\$type", kotlinx.serialization.json.JsonPrimitive(value::class.simpleName ?: "Unknown"))
            }
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoSimplespaceCreateSpaceInputPolicyUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.simplespace.defs#publicPolicy" -> ComAtprotoSimplespaceCreateSpaceInputPolicyUnion.PublicPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy.serializer(), element)
            )
            "com.atproto.simplespace.defs#memberListPolicy" -> ComAtprotoSimplespaceCreateSpaceInputPolicyUnion.MemberListPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy.serializer(), element)
            )
            "com.atproto.simplespace.defs#managingAppPolicy" -> ComAtprotoSimplespaceCreateSpaceInputPolicyUnion.ManagingAppPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy.serializer(), element)
            )
            else -> ComAtprotoSimplespaceCreateSpaceInputPolicyUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ComAtprotoSimplespaceCreateSpaceInputAppAccessUnionSerializer::class)
sealed interface ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion {
    @Serializable
    data class Open(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsOpen) : ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion

    @Serializable
    data class AllowList(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsAllowList) : ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion
}

object ComAtprotoSimplespaceCreateSpaceInputAppAccessUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion.Open -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsOpen.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#open")
                })
            }
            is ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion.AllowList -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsAllowList.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#allowList")
                })
            }
            is ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion.Unexpected -> value.value
            // Synthetic variants (e.g. <Union>Error / <Union>Unexpected added by
            // subscription codegen) are runtime-only sentinels; JSON round-trip
            // serialises them as an empty object tagged with the variant class
            // name. Consumers should filter these before JSON serialisation.
            else -> kotlinx.serialization.json.buildJsonObject {
                put("\$type", kotlinx.serialization.json.JsonPrimitive(value::class.simpleName ?: "Unknown"))
            }
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.simplespace.defs#open" -> ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion.Open(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsOpen.serializer(), element)
            )
            "com.atproto.simplespace.defs#allowList" -> ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion.AllowList(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsAllowList.serializer(), element)
            )
            else -> ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class ComAtprotoSimplespaceCreateSpaceInput(
// The NSID of the space type, describing the modality of the space (e.g. app.bsky.group, app.bsky.personal).        @SerialName("type")
        val type: NSID,// The space key. Used to differentiate multiple spaces of the same type under the same owner. Same syntax requirements as a record key. If not provided, one will be auto-generated (TID).        @SerialName("skey")
        val skey: String? = null,// How the authority decides whether to authorize a requesting user.        @SerialName("policy")
        val policy: ComAtprotoSimplespaceCreateSpaceInputPolicyUnion,// How the authority decides whether to authorize a requesting app.        @SerialName("appAccess")
        val appAccess: ComAtprotoSimplespaceCreateSpaceInputAppAccessUnion    )

    @Serializable
    data class ComAtprotoSimplespaceCreateSpaceOutput(
// URI of the created space.        @SerialName("uri")
        val uri: SpaceRef    )

sealed class ComAtprotoSimplespaceCreateSpaceError(val name: String, val description: String?) {
        object SpaceAlreadyExists: ComAtprotoSimplespaceCreateSpaceError("SpaceAlreadyExists", "A space with this owner, type, and skey already exists. A space that was previously deleted may be created again.")
        object UnsupportedPolicy: ComAtprotoSimplespaceCreateSpaceError("UnsupportedPolicy", "The requested policy is not one the host implements.")
        object UnsupportedAppAccess: ComAtprotoSimplespaceCreateSpaceError("UnsupportedAppAccess", "The requested appAccess variant is not one the host implements. A host will not store an app access policy it cannot enforce.")
    }

/**
 * Create a new space managed by the simplespace implementation. The space is anchored on the authenticated user's DID, who becomes the space owner. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.simplespace.createSpace
 */
suspend fun ATProtoClient.Com.Atproto.Simplespace.createSpace(
input: ComAtprotoSimplespaceCreateSpaceInput): ATProtoResponse<ComAtprotoSimplespaceCreateSpaceOutput> {
    val endpoint = "com.atproto.simplespace.createSpace"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
