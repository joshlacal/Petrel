// Lexicon: 1, ID: app.bsky.graph.getRelationships
// Enumerates public relationships between one account, and a list of other accounts. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetRelationshipsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getRelationships"
}

@Serializable(with = AppBskyGraphGetRelationshipsOutputRelationshipsUnionSerializer::class)
sealed interface AppBskyGraphGetRelationshipsOutputRelationshipsUnion {
    @Serializable
    data class Relationship(val value: com.atproto.generated.AppBskyGraphDefsRelationship) : AppBskyGraphGetRelationshipsOutputRelationshipsUnion

    @Serializable
    data class NotFoundActor(val value: com.atproto.generated.AppBskyGraphDefsNotFoundActor) : AppBskyGraphGetRelationshipsOutputRelationshipsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyGraphGetRelationshipsOutputRelationshipsUnion
}

object AppBskyGraphGetRelationshipsOutputRelationshipsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyGraphGetRelationshipsOutputRelationshipsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyGraphGetRelationshipsOutputRelationshipsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyGraphGetRelationshipsOutputRelationshipsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyGraphGetRelationshipsOutputRelationshipsUnion.Relationship -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyGraphDefsRelationship.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.graph.defs#relationship")
                })
            }
            is AppBskyGraphGetRelationshipsOutputRelationshipsUnion.NotFoundActor -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyGraphDefsNotFoundActor.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.graph.defs#notFoundActor")
                })
            }
            is AppBskyGraphGetRelationshipsOutputRelationshipsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyGraphGetRelationshipsOutputRelationshipsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.graph.defs#relationship" -> AppBskyGraphGetRelationshipsOutputRelationshipsUnion.Relationship(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyGraphDefsRelationship.serializer(), element)
            )
            "app.bsky.graph.defs#notFoundActor" -> AppBskyGraphGetRelationshipsOutputRelationshipsUnion.NotFoundActor(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyGraphDefsNotFoundActor.serializer(), element)
            )
            else -> AppBskyGraphGetRelationshipsOutputRelationshipsUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class AppBskyGraphGetRelationshipsParameters(
// Primary account requesting relationships for.        @SerialName("actor")
        val actor: ATIdentifier,// List of 'other' accounts to be related back to the primary.        @SerialName("others")
        val others: List<ATIdentifier>? = null    )

    @Serializable
    data class AppBskyGraphGetRelationshipsOutput(
        @SerialName("actor")
        val actor: DID? = null,        @SerialName("relationships")
        val relationships: List<AppBskyGraphGetRelationshipsOutputRelationshipsUnion>    )

sealed class AppBskyGraphGetRelationshipsError(val name: String, val description: String?) {
        object ActorNotFound: AppBskyGraphGetRelationshipsError("ActorNotFound", "the primary actor at-identifier could not be resolved")
    }

/**
 * Enumerates public relationships between one account, and a list of other accounts. Does not require auth.
 *
 * Endpoint: app.bsky.graph.getRelationships
 */
suspend fun ATProtoClient.App.Bsky.Graph.getRelationships(
parameters: AppBskyGraphGetRelationshipsParameters): ATProtoResponse<AppBskyGraphGetRelationshipsOutput> {
    val endpoint = "app.bsky.graph.getRelationships"

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
