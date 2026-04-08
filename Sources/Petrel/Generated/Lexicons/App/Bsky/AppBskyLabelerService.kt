// Lexicon: 1, ID: app.bsky.labeler.service
// A declaration of the existence of labeler service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyLabelerServiceDefs {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.service"
}

@Serializable(with = AppBskyLabelerServiceLabelsUnionSerializer::class)
sealed interface AppBskyLabelerServiceLabelsUnion {
    @Serializable
    data class SelfLabels(val value: com.atproto.generated.ComAtprotoLabelDefsSelfLabels) : AppBskyLabelerServiceLabelsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyLabelerServiceLabelsUnion
}

object AppBskyLabelerServiceLabelsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyLabelerServiceLabelsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyLabelerServiceLabelsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyLabelerServiceLabelsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyLabelerServiceLabelsUnion.SelfLabels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.defs#selfLabels")
                })
            }
            is AppBskyLabelerServiceLabelsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyLabelerServiceLabelsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.defs#selfLabels" -> AppBskyLabelerServiceLabelsUnion.SelfLabels(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), element)
            )
            else -> AppBskyLabelerServiceLabelsUnion.Unexpected(element)
        }
    }
}

    /**
     * A declaration of the existence of labeler service.
     */
    @Serializable
    data class AppBskyLabelerService(
        @SerialName("policies")
        val policies: AppBskyLabelerDefsLabelerPolicies,        @SerialName("labels")
        val labels: AppBskyLabelerServiceLabelsUnion? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The set of report reason 'codes' which are in-scope for this service to review and action. These usually align to policy categories. If not defined (distinct from empty array), all reason types are allowed. */        @SerialName("reasonTypes")
        val reasonTypes: List<ComAtprotoModerationDefsReasonType>? = null,/** The set of subject types (account, record, etc) this service accepts reports on. */        @SerialName("subjectTypes")
        val subjectTypes: List<ComAtprotoModerationDefsSubjectType>? = null,/** Set of record types (collection NSIDs) which can be reported to this service. If not defined (distinct from empty array), default is any record type. */        @SerialName("subjectCollections")
        val subjectCollections: List<NSID>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
