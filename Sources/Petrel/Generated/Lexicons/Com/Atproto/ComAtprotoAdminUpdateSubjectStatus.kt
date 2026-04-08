// Lexicon: 1, ID: com.atproto.admin.updateSubjectStatus
// Update the service-specific admin status of a subject (account, record, or blob).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminUpdateSubjectStatusDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateSubjectStatus"
}

@Serializable(with = ComAtprotoAdminUpdateSubjectStatusInputSubjectUnionSerializer::class)
sealed interface ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion {
    @Serializable
    data class RepoRef(val value: com.atproto.generated.ComAtprotoAdminDefsRepoRef) : ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion

    @Serializable
    data class StrongRef(val value: com.atproto.generated.ComAtprotoRepoStrongRef) : ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion

    @Serializable
    data class RepoBlobRef(val value: com.atproto.generated.ComAtprotoAdminDefsRepoBlobRef) : ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion
}

object ComAtprotoAdminUpdateSubjectStatusInputSubjectUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion.RepoRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoRef")
                })
            }
            is ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion.StrongRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoStrongRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.strongRef")
                })
            }
            is ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion.RepoBlobRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoBlobRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoBlobRef")
                })
            }
            is ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.admin.defs#repoRef" -> ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion.RepoRef(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoRef.serializer(), element)
            )
            "com.atproto.repo.strongRef" -> ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion.StrongRef(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoStrongRef.serializer(), element)
            )
            "com.atproto.admin.defs#repoBlobRef" -> ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion.RepoBlobRef(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoBlobRef.serializer(), element)
            )
            else -> ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnionSerializer::class)
sealed interface ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion {
    @Serializable
    data class RepoRef(val value: com.atproto.generated.ComAtprotoAdminDefsRepoRef) : ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion

    @Serializable
    data class StrongRef(val value: com.atproto.generated.ComAtprotoRepoStrongRef) : ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion

    @Serializable
    data class RepoBlobRef(val value: com.atproto.generated.ComAtprotoAdminDefsRepoBlobRef) : ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion
}

object ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion.RepoRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoRef")
                })
            }
            is ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion.StrongRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoRepoStrongRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.repo.strongRef")
                })
            }
            is ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion.RepoBlobRef -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoBlobRef.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.admin.defs#repoBlobRef")
                })
            }
            is ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.admin.defs#repoRef" -> ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion.RepoRef(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoRef.serializer(), element)
            )
            "com.atproto.repo.strongRef" -> ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion.StrongRef(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoRepoStrongRef.serializer(), element)
            )
            "com.atproto.admin.defs#repoBlobRef" -> ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion.RepoBlobRef(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoAdminDefsRepoBlobRef.serializer(), element)
            )
            else -> ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class ComAtprotoAdminUpdateSubjectStatusInput(
        @SerialName("subject")
        val subject: ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefsStatusAttr? = null,        @SerialName("deactivated")
        val deactivated: ComAtprotoAdminDefsStatusAttr? = null    )

    @Serializable
    data class ComAtprotoAdminUpdateSubjectStatusOutput(
        @SerialName("subject")
        val subject: ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefsStatusAttr? = null    )

/**
 * Update the service-specific admin status of a subject (account, record, or blob).
 *
 * Endpoint: com.atproto.admin.updateSubjectStatus
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateSubjectStatus(
input: ComAtprotoAdminUpdateSubjectStatusInput): ATProtoResponse<ComAtprotoAdminUpdateSubjectStatusOutput> {
    val endpoint = "com.atproto.admin.updateSubjectStatus"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
