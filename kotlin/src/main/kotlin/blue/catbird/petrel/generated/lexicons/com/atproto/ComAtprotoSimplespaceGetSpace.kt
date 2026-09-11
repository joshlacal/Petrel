// Lexicon: 1, ID: com.atproto.simplespace.getSpace
// Describe a space managed by the simplespace implementation, including its configuration. Served by the space host. Requires either OAuth (for a caller with an account on this host) or a space credential (for a member hosted elsewhere); either way the caller must be authorized for the space.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSimplespaceGetSpaceDefs {
    const val TYPE_IDENTIFIER = "com.atproto.simplespace.getSpace"
}

@Serializable(with = ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnionSerializer::class)
sealed interface ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion {
    @Serializable
    data class PublicPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy) : ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion

    @Serializable
    data class MemberListPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy) : ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion

    @Serializable
    data class ManagingAppPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy) : ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion
}

object ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion.PublicPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#publicPolicy")
                })
            }
            is ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion.MemberListPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#memberListPolicy")
                })
            }
            is ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion.ManagingAppPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#managingAppPolicy")
                })
            }
            is ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.simplespace.defs#publicPolicy" -> ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion.PublicPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy.serializer(), element)
            )
            "com.atproto.simplespace.defs#memberListPolicy" -> ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion.MemberListPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy.serializer(), element)
            )
            "com.atproto.simplespace.defs#managingAppPolicy" -> ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion.ManagingAppPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy.serializer(), element)
            )
            else -> ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnionSerializer::class)
sealed interface ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion {
    @Serializable
    data class PublicPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy) : ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion

    @Serializable
    data class MemberListPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy) : ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion

    @Serializable
    data class ManagingAppPolicy(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy) : ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion
}

object ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion.PublicPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#publicPolicy")
                })
            }
            is ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion.MemberListPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#memberListPolicy")
                })
            }
            is ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion.ManagingAppPolicy -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#managingAppPolicy")
                })
            }
            is ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.simplespace.defs#publicPolicy" -> ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion.PublicPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsPublicPolicy.serializer(), element)
            )
            "com.atproto.simplespace.defs#memberListPolicy" -> ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion.MemberListPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsMemberListPolicy.serializer(), element)
            )
            "com.atproto.simplespace.defs#managingAppPolicy" -> ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion.ManagingAppPolicy(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsManagingAppPolicy.serializer(), element)
            )
            else -> ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ComAtprotoSimplespaceGetSpaceOutputAppAccessUnionSerializer::class)
sealed interface ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion {
    @Serializable
    data class Open(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsOpen) : ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion

    @Serializable
    data class AllowList(val value: blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsAllowList) : ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion
}

object ComAtprotoSimplespaceGetSpaceOutputAppAccessUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion.Open -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsOpen.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#open")
                })
            }
            is ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion.AllowList -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsAllowList.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.simplespace.defs#allowList")
                })
            }
            is ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.simplespace.defs#open" -> ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion.Open(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsOpen.serializer(), element)
            )
            "com.atproto.simplespace.defs#allowList" -> ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion.AllowList(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoSimplespaceDefsAllowList.serializer(), element)
            )
            else -> ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class ComAtprotoSimplespaceGetSpaceParameters(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef    )

    @Serializable
    data class ComAtprotoSimplespaceGetSpaceOutput(
// URI of the space.        @SerialName("uri")
        val uri: SpaceRef,// How the authority decides whether to authorize a user to read the space.        @SerialName("readPolicy")
        val readPolicy: ComAtprotoSimplespaceGetSpaceOutputReadPolicyUnion,// How the authority decides whether to track and forward a user's write notifications.        @SerialName("writePolicy")
        val writePolicy: ComAtprotoSimplespaceGetSpaceOutputWritePolicyUnion,// How the authority decides whether to authorize a requesting app.        @SerialName("appAccess")
        val appAccess: ComAtprotoSimplespaceGetSpaceOutputAppAccessUnion    )

sealed class ComAtprotoSimplespaceGetSpaceError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSimplespaceGetSpaceError("SpaceNotFound", "")
    }

/**
 * Describe a space managed by the simplespace implementation, including its configuration. Served by the space host. Requires either OAuth (for a caller with an account on this host) or a space credential (for a member hosted elsewhere); either way the caller must be authorized for the space.
 *
 * Endpoint: com.atproto.simplespace.getSpace
 */
suspend fun ATProtoClient.Com.Atproto.Simplespace.getSpace(
parameters: ComAtprotoSimplespaceGetSpaceParameters): ATProtoResponse<ComAtprotoSimplespaceGetSpaceOutput> {
    val endpoint = "com.atproto.simplespace.getSpace"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
