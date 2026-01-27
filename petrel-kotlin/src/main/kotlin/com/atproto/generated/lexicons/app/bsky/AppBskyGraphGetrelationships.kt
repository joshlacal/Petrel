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

@Serializable
sealed interface AppBskyGraphGetRelationshipsOutputRelationshipsUnion {
    @Serializable
    @SerialName("app.bsky.graph.getRelationships#AppBskyGraphDefsRelationship")
    data class AppBskyGraphDefsRelationship(val value: AppBskyGraphDefsRelationship) : AppBskyGraphGetRelationshipsOutputRelationshipsUnion

    @Serializable
    @SerialName("app.bsky.graph.getRelationships#AppBskyGraphDefsNotFoundActor")
    data class AppBskyGraphDefsNotFoundActor(val value: AppBskyGraphDefsNotFoundActor) : AppBskyGraphGetRelationshipsOutputRelationshipsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyGraphGetRelationshipsOutputRelationshipsUnion
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
