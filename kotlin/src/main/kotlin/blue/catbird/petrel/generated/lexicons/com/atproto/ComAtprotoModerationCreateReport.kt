// Lexicon: 1, ID: com.atproto.moderation.createReport
// Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoModerationCreateReportDefs {
    const val TYPE_IDENTIFIER = "com.atproto.moderation.createReport"
}

@Serializable(with = ComAtprotoModerationCreateReportInputSubjectUnionSerializer::class)
sealed interface ComAtprotoModerationCreateReportInputSubjectUnion {
    @Serializable
    data class RepoRef(val value: blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef) : ComAtprotoModerationCreateReportInputSubjectUnion

    @Serializable
    data class StrongRef(val value: blue.catbird.petrel.generated.ComAtprotoRepoStrongRef) : ComAtprotoModerationCreateReportInputSubjectUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoModerationCreateReportInputSubjectUnion
}

object ComAtprotoModerationCreateReportInputSubjectUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoModerationCreateReportInputSubjectUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoModerationCreateReportInputSubjectUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoModerationCreateReportInputSubjectUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoModerationCreateReportInputSubjectUnion.RepoRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoRef")
                })
            }
            is ComAtprotoModerationCreateReportInputSubjectUnion.StrongRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoRepoStrongRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.strongRef")
                })
            }
            is ComAtprotoModerationCreateReportInputSubjectUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoModerationCreateReportInputSubjectUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.admin.defs#repoRef" -> ComAtprotoModerationCreateReportInputSubjectUnion.RepoRef(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef.serializer(), element)
            )
            "com.atproto.repo.strongRef" -> ComAtprotoModerationCreateReportInputSubjectUnion.StrongRef(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoRepoStrongRef.serializer(), element)
            )
            else -> ComAtprotoModerationCreateReportInputSubjectUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ComAtprotoModerationCreateReportOutputSubjectUnionSerializer::class)
sealed interface ComAtprotoModerationCreateReportOutputSubjectUnion {
    @Serializable
    data class RepoRef(val value: blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef) : ComAtprotoModerationCreateReportOutputSubjectUnion

    @Serializable
    data class StrongRef(val value: blue.catbird.petrel.generated.ComAtprotoRepoStrongRef) : ComAtprotoModerationCreateReportOutputSubjectUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoModerationCreateReportOutputSubjectUnion
}

object ComAtprotoModerationCreateReportOutputSubjectUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoModerationCreateReportOutputSubjectUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoModerationCreateReportOutputSubjectUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoModerationCreateReportOutputSubjectUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoModerationCreateReportOutputSubjectUnion.RepoRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoRef")
                })
            }
            is ComAtprotoModerationCreateReportOutputSubjectUnion.StrongRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ComAtprotoRepoStrongRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.strongRef")
                })
            }
            is ComAtprotoModerationCreateReportOutputSubjectUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoModerationCreateReportOutputSubjectUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.admin.defs#repoRef" -> ComAtprotoModerationCreateReportOutputSubjectUnion.RepoRef(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoAdminDefsRepoRef.serializer(), element)
            )
            "com.atproto.repo.strongRef" -> ComAtprotoModerationCreateReportOutputSubjectUnion.StrongRef(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ComAtprotoRepoStrongRef.serializer(), element)
            )
            else -> ComAtprotoModerationCreateReportOutputSubjectUnion.Unexpected(element)
        }
    }
}

    /**
     * Moderation tool information for tracing the source of the action
     */
    @Serializable
    data class ComAtprotoModerationCreateReportModTool(
/** Name/identifier of the source (e.g., 'bsky-app/android', 'bsky-web/chrome') */        @SerialName("name")
        val name: String,/** Additional arbitrary metadata about the source */        @SerialName("meta")
        val meta: JsonElement? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoModerationCreateReportModTool"
        }
    }

@Serializable
    data class ComAtprotoModerationCreateReportInput(
// Indicates the broad category of violation the report is for.        @SerialName("reasonType")
        val reasonType: ComAtprotoModerationDefsReasonType,// Additional context about the content and violation.        @SerialName("reason")
        val reason: String? = null,        @SerialName("subject")
        val subject: ComAtprotoModerationCreateReportInputSubjectUnion,        @SerialName("modTool")
        val modTool: ComAtprotoModerationCreateReportModTool? = null    )

    @Serializable
    data class ComAtprotoModerationCreateReportOutput(
        @SerialName("id")
        val id: Int,        @SerialName("reasonType")
        val reasonType: ComAtprotoModerationDefsReasonType,        @SerialName("reason")
        val reason: String? = null,        @SerialName("subject")
        val subject: ComAtprotoModerationCreateReportOutputSubjectUnion,        @SerialName("reportedBy")
        val reportedBy: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    )

/**
 * Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.
 *
 * Endpoint: com.atproto.moderation.createReport
 */
suspend fun ATProtoClient.Com.Atproto.Moderation.createReport(
input: ComAtprotoModerationCreateReportInput): ATProtoResponse<ComAtprotoModerationCreateReportOutput> {
    val endpoint = "com.atproto.moderation.createReport"

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
