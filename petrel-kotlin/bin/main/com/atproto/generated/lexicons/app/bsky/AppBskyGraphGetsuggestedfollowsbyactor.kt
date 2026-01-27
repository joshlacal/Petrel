// Lexicon: 1, ID: app.bsky.graph.getSuggestedFollowsByActor
// Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetSuggestedFollowsByActorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getSuggestedFollowsByActor"
}

@Serializable
    data class AppBskyGraphGetSuggestedFollowsByActorParameters(
        @SerialName("actor")
        val actor: ATIdentifier    )

    @Serializable
    data class AppBskyGraphGetSuggestedFollowsByActorOutput(
        @SerialName("suggestions")
        val suggestions: List<AppBskyActorDefsProfileView>,// If true, response has fallen-back to generic results, and is not scoped using relativeToDid        @SerialName("isFallback")
        val isFallback: Boolean? = null,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recId")
        val recId: Int? = null    )

/**
 * Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.
 *
 * Endpoint: app.bsky.graph.getSuggestedFollowsByActor
 */
suspend fun ATProtoClient.App.Bsky.Graph.getSuggestedFollowsByActor(
parameters: AppBskyGraphGetSuggestedFollowsByActorParameters): ATProtoResponse<AppBskyGraphGetSuggestedFollowsByActorOutput> {
    val endpoint = "app.bsky.graph.getSuggestedFollowsByActor"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
