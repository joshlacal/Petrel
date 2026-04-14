// Lexicon: 1, ID: app.bsky.graph.getFollows
// Enumerates accounts which a specified account (actor) follows.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetFollowsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getFollows"
}

@Serializable
    data class AppBskyGraphGetFollowsParameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetFollowsOutput(
        @SerialName("subject")
        val subject: AppBskyActorDefsProfileView,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("follows")
        val follows: List<AppBskyActorDefsProfileView>    )

/**
 * Enumerates accounts which a specified account (actor) follows.
 *
 * Endpoint: app.bsky.graph.getFollows
 */
suspend fun ATProtoClient.App.Bsky.Graph.getFollows(
parameters: AppBskyGraphGetFollowsParameters): ATProtoResponse<AppBskyGraphGetFollowsOutput> {
    val endpoint = "app.bsky.graph.getFollows"

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
