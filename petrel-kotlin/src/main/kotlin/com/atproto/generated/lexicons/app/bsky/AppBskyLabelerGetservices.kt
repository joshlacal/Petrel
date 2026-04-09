// Lexicon: 1, ID: app.bsky.labeler.getServices
// Get information about a list of labeler services.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyLabelerGetServicesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.getServices"
}

@Serializable(with = AppBskyLabelerGetServicesOutputViewsUnionSerializer::class)
sealed interface AppBskyLabelerGetServicesOutputViewsUnion {
    @Serializable
    data class LabelerView(val value: com.atproto.generated.AppBskyLabelerDefsLabelerView) : AppBskyLabelerGetServicesOutputViewsUnion

    @Serializable
    data class LabelerViewDetailed(val value: com.atproto.generated.AppBskyLabelerDefsLabelerViewDetailed) : AppBskyLabelerGetServicesOutputViewsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyLabelerGetServicesOutputViewsUnion
}

object AppBskyLabelerGetServicesOutputViewsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyLabelerGetServicesOutputViewsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyLabelerGetServicesOutputViewsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyLabelerGetServicesOutputViewsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyLabelerGetServicesOutputViewsUnion.LabelerView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyLabelerDefsLabelerView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.labeler.defs#labelerView")
                })
            }
            is AppBskyLabelerGetServicesOutputViewsUnion.LabelerViewDetailed -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyLabelerDefsLabelerViewDetailed.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.labeler.defs#labelerViewDetailed")
                })
            }
            is AppBskyLabelerGetServicesOutputViewsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyLabelerGetServicesOutputViewsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.labeler.defs#labelerView" -> AppBskyLabelerGetServicesOutputViewsUnion.LabelerView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyLabelerDefsLabelerView.serializer(), element)
            )
            "app.bsky.labeler.defs#labelerViewDetailed" -> AppBskyLabelerGetServicesOutputViewsUnion.LabelerViewDetailed(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyLabelerDefsLabelerViewDetailed.serializer(), element)
            )
            else -> AppBskyLabelerGetServicesOutputViewsUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class AppBskyLabelerGetServicesParameters(
        @SerialName("dids")
        val dids: List<DID>,        @SerialName("detailed")
        val detailed: Boolean? = null    )

    @Serializable
    data class AppBskyLabelerGetServicesOutput(
        @SerialName("views")
        val views: List<AppBskyLabelerGetServicesOutputViewsUnion>    )

/**
 * Get information about a list of labeler services.
 *
 * Endpoint: app.bsky.labeler.getServices
 */
suspend fun ATProtoClient.App.Bsky.Labeler.getServices(
parameters: AppBskyLabelerGetServicesParameters): ATProtoResponse<AppBskyLabelerGetServicesOutput> {
    val endpoint = "app.bsky.labeler.getServices"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
