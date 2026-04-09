// Lexicon: 1, ID: place.stream.ingest.getIngestUrls
// Get ingest URLs for a Streamplace station.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamIngestGetIngestUrlsDefs {
    const val TYPE_IDENTIFIER = "place.stream.ingest.getIngestUrls"
}

@Serializable(with = PlaceStreamIngestGetIngestUrlsOutputIngestsUnionSerializer::class)
sealed interface PlaceStreamIngestGetIngestUrlsOutputIngestsUnion {
    @Serializable
    data class Ingest(val value: com.atproto.generated.PlaceStreamIngestDefsIngest) : PlaceStreamIngestGetIngestUrlsOutputIngestsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : PlaceStreamIngestGetIngestUrlsOutputIngestsUnion
}

object PlaceStreamIngestGetIngestUrlsOutputIngestsUnionSerializer : kotlinx.serialization.KSerializer<PlaceStreamIngestGetIngestUrlsOutputIngestsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("PlaceStreamIngestGetIngestUrlsOutputIngestsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: PlaceStreamIngestGetIngestUrlsOutputIngestsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is PlaceStreamIngestGetIngestUrlsOutputIngestsUnion.Ingest -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamIngestDefsIngest.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.ingest.defs#ingest")
                })
            }
            is PlaceStreamIngestGetIngestUrlsOutputIngestsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): PlaceStreamIngestGetIngestUrlsOutputIngestsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "place.stream.ingest.defs#ingest" -> PlaceStreamIngestGetIngestUrlsOutputIngestsUnion.Ingest(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamIngestDefsIngest.serializer(), element)
            )
            else -> PlaceStreamIngestGetIngestUrlsOutputIngestsUnion.Unexpected(element)
        }
    }
}

@Serializable
    class PlaceStreamIngestGetIngestUrlsParameters

    @Serializable
    data class PlaceStreamIngestGetIngestUrlsOutput(
        @SerialName("ingests")
        val ingests: List<PlaceStreamIngestGetIngestUrlsOutputIngestsUnion>    )

/**
 * Get ingest URLs for a Streamplace station.
 *
 * Endpoint: place.stream.ingest.getIngestUrls
 */
suspend fun ATProtoClient.Place.Stream.Ingest.getIngestUrls(
parameters: PlaceStreamIngestGetIngestUrlsParameters): ATProtoResponse<PlaceStreamIngestGetIngestUrlsOutput> {
    val endpoint = "place.stream.ingest.getIngestUrls"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
