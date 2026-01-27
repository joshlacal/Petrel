// Lexicon: 1, ID: app.bsky.graph.getFollowers
// Enumerates accounts which follow a specified account (actor).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetFollowersDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getFollowers"
}

@Serializable
    data class AppBskyGraphGetFollowersParameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetFollowersOutput(
        @SerialName("subject")
        val subject: AppBskyActorDefsProfileView,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("followers")
        val followers: List<AppBskyActorDefsProfileView>    )

/**
 * Enumerates accounts which follow a specified account (actor).
 *
 * Endpoint: app.bsky.graph.getFollowers
 */
suspend fun ATProtoClient.App.Bsky.Graph.getFollowers(
parameters: AppBskyGraphGetFollowersParameters): ATProtoResponse<AppBskyGraphGetFollowersOutput> {
    val endpoint = "app.bsky.graph.getFollowers"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
