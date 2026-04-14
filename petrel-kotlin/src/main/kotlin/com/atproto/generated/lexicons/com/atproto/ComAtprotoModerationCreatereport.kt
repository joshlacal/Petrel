// Lexicon: 1, ID: com.atproto.moderation.createReport
// Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoModerationCreateReportDefs {
    const val TYPE_IDENTIFIER = "com.atproto.moderation.createReport"
}

@Serializable(with = ComAtprotoModerationCreateReportInputSubjectUnionSerializer::class)
sealed interface ComAtprotoModerationCreateReportInputSubjectUnion {
    @Serializable
    data class RepoRef(val value: com.atproto.generated.ComAtprotoAdminDefsRepoRef) : ComAtprotoModerationCreateReportInputSubjectUnion

    @Serializable
    data class StrongRef(val value: com.atproto.generated.ComAtprotoRepoStrongRef) : ComAtprotoModerationCreateReportInputSubjectUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoRef")
                })
            }
            is ComAtprotoModerationCreateReportInputSubjectUnion.StrongRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoStrongRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.strongRef")
                })
            }
            is ComAtprotoModerationCreateReportInputSubjectUnion.Unexpected -> value.value
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
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoRef.serializer(), element)
            )
            "com.atproto.repo.strongRef" -> ComAtprotoModerationCreateReportInputSubjectUnion.StrongRef(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoStrongRef.serializer(), element)
            )
            else -> ComAtprotoModerationCreateReportInputSubjectUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ComAtprotoModerationCreateReportOutputSubjectUnionSerializer::class)
sealed interface ComAtprotoModerationCreateReportOutputSubjectUnion {
    @Serializable
    data class RepoRef(val value: com.atproto.generated.ComAtprotoAdminDefsRepoRef) : ComAtprotoModerationCreateReportOutputSubjectUnion

    @Serializable
    data class StrongRef(val value: com.atproto.generated.ComAtprotoRepoStrongRef) : ComAtprotoModerationCreateReportOutputSubjectUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoRef")
                })
            }
            is ComAtprotoModerationCreateReportOutputSubjectUnion.StrongRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoStrongRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.strongRef")
                })
            }
            is ComAtprotoModerationCreateReportOutputSubjectUnion.Unexpected -> value.value
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
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoRef.serializer(), element)
            )
            "com.atproto.repo.strongRef" -> ComAtprotoModerationCreateReportOutputSubjectUnion.StrongRef(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoStrongRef.serializer(), element)
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
