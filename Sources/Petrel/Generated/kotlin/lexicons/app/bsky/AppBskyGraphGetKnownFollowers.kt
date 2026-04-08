// Lexicon: 1, ID: app.bsky.graph.getKnownFollowers
// Enumerates accounts which follow a specified account (actor) and are followed by the viewer.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetKnownFollowersDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getKnownFollowers"
}

@Serializable
    data class AppBskyGraphGetKnownFollowersParameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetKnownFollowersOutput(
        @SerialName("subject")
        val subject: AppBskyActorDefsProfileView,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("followers")
        val followers: List<AppBskyActorDefsProfileView>    )

/**
 * Enumerates accounts which follow a specified account (actor) and are followed by the viewer.
 *
 * Endpoint: app.bsky.graph.getKnownFollowers
 */
suspend fun ATProtoClient.App.Bsky.Graph.getKnownFollowers(
parameters: AppBskyGraphGetKnownFollowersParameters): ATProtoResponse<AppBskyGraphGetKnownFollowersOutput> {
    val endpoint = "app.bsky.graph.getKnownFollowers"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
