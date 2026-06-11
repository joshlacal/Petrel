// Lexicon: 1, ID: app.bsky.labeler.getServices
// Get information about a list of labeler services.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyLabelerGetServicesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.getServices"
}

@Serializable(with = AppBskyLabelerGetServicesOutputViewsUnionSerializer::class)
sealed interface AppBskyLabelerGetServicesOutputViewsUnion {
    @Serializable
    data class LabelerView(val value: blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerView) : AppBskyLabelerGetServicesOutputViewsUnion

    @Serializable
    data class LabelerViewDetailed(val value: blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerViewDetailed) : AppBskyLabelerGetServicesOutputViewsUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.labeler.defs#labelerView")
                })
            }
            is AppBskyLabelerGetServicesOutputViewsUnion.LabelerViewDetailed -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerViewDetailed.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.labeler.defs#labelerViewDetailed")
                })
            }
            is AppBskyLabelerGetServicesOutputViewsUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyLabelerGetServicesOutputViewsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.labeler.defs#labelerView" -> AppBskyLabelerGetServicesOutputViewsUnion.LabelerView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerView.serializer(), element)
            )
            "app.bsky.labeler.defs#labelerViewDetailed" -> AppBskyLabelerGetServicesOutputViewsUnion.LabelerViewDetailed(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyLabelerDefsLabelerViewDetailed.serializer(), element)
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
