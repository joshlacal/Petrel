// Lexicon: 1, ID: app.bsky.graph.getRelationships
// Enumerates public relationships between one account, and a list of other accounts. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface OutputRelationshipsUnion {
    @Serializable
    @SerialName("AppBskyGraphDefs.Relationship")
    data class Relationship(val value: AppBskyGraphDefs.Relationship) : OutputRelationshipsUnion

    @Serializable
    @SerialName("AppBskyGraphDefs.Notfoundactor")
    data class Notfoundactor(val value: AppBskyGraphDefs.Notfoundactor) : OutputRelationshipsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputRelationshipsUnion
}

object AppBskyGraphGetrelationships {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getRelationships"

    @Serializable
    data class Parameters(
// Primary account requesting relationships for.        @SerialName("actor")
        val actor: ATIdentifier,// List of 'other' accounts to be related back to the primary.        @SerialName("others")
        val others: List<ATIdentifier>? = null    )

        @Serializable
    data class Output(
        @SerialName("actor")
        val actor: DID? = null,        @SerialName("relationships")
        val relationships: List<OutputRelationshipsUnion>    )

    sealed class Error(val name: String, val description: String?) {
        object Actornotfound: Error("ActorNotFound", "the primary actor at-identifier could not be resolved")
    }

}

/**
 * Enumerates public relationships between one account, and a list of other accounts. Does not require auth.
 *
 * Endpoint: app.bsky.graph.getRelationships
 */
suspend fun ATProtoClient.App.Bsky.Graph.getrelationships(
parameters: AppBskyGraphGetrelationships.Parameters): ATProtoResponse<AppBskyGraphGetrelationships.Output> {
    val endpoint = "app.bsky.graph.getRelationships"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
