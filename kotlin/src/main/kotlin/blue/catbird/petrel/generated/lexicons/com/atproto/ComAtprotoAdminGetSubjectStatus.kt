// Lexicon: 1, ID: com.atproto.admin.getSubjectStatus
// Get the service-specific admin status of a subject (account, record, or blob).
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminGetSubjectStatusDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getSubjectStatus"
}

@Serializable(with = ComAtprotoAdminGetSubjectStatusOutputSubjectUnionSerializer::class)
sealed interface ComAtprotoAdminGetSubjectStatusOutputSubjectUnion {
    @Serializable
    data class RepoRef(val value: blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef) : ComAtprotoAdminGetSubjectStatusOutputSubjectUnion

    @Serializable
    data class StrongRef(val value: blue.catbird.petrel.generated.ComAtprotoRepoStrongRef) : ComAtprotoAdminGetSubjectStatusOutputSubjectUnion

    @Serializable
    data class RepoBlobRef(val value: blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoBlobRef) : ComAtprotoAdminGetSubjectStatusOutputSubjectUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoAdminGetSubjectStatusOutputSubjectUnion
}

object ComAtprotoAdminGetSubjectStatusOutputSubjectUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoAdminGetSubjectStatusOutputSubjectUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoAdminGetSubjectStatusOutputSubjectUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoAdminGetSubjectStatusOutputSubjectUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoAdminGetSubjectStatusOutputSubjectUnion.RepoRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoRef")
                })
            }
            is ComAtprotoAdminGetSubjectStatusOutputSubjectUnion.StrongRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoRepoStrongRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.strongRef")
                })
            }
            is ComAtprotoAdminGetSubjectStatusOutputSubjectUnion.RepoBlobRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoBlobRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoBlobRef")
                })
            }
            is ComAtprotoAdminGetSubjectStatusOutputSubjectUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoAdminGetSubjectStatusOutputSubjectUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.admin.defs#repoRef" -> ComAtprotoAdminGetSubjectStatusOutputSubjectUnion.RepoRef(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef.serializer(), element)
            )
            "com.atproto.repo.strongRef" -> ComAtprotoAdminGetSubjectStatusOutputSubjectUnion.StrongRef(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoRepoStrongRef.serializer(), element)
            )
            "com.atproto.admin.defs#repoBlobRef" -> ComAtprotoAdminGetSubjectStatusOutputSubjectUnion.RepoBlobRef(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoBlobRef.serializer(), element)
            )
            else -> ComAtprotoAdminGetSubjectStatusOutputSubjectUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class ComAtprotoAdminGetSubjectStatusParameters(
        @SerialName("did")
        val did: DID? = null,        @SerialName("uri")
        val uri: ATProtocolURI? = null,        @SerialName("blob")
        val blob: CID? = null    )

    @Serializable
    data class ComAtprotoAdminGetSubjectStatusOutput(
        @SerialName("subject")
        val subject: ComAtprotoAdminGetSubjectStatusOutputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefsStatusAttr? = null,        @SerialName("deactivated")
        val deactivated: ComAtprotoAdminDefsStatusAttr? = null    )

/**
 * Get the service-specific admin status of a subject (account, record, or blob).
 *
 * Endpoint: com.atproto.admin.getSubjectStatus
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getSubjectStatus(
parameters: ComAtprotoAdminGetSubjectStatusParameters): ATProtoResponse<ComAtprotoAdminGetSubjectStatusOutput> {
    val endpoint = "com.atproto.admin.getSubjectStatus"

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
