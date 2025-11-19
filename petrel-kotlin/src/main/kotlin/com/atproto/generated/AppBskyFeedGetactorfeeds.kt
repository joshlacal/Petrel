// Lexicon: 1, ID: app.bsky.feed.getActorFeeds
// Get a list of feeds (feed generator records) created by the actor (in the actor's repo).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetactorfeeds {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getActorFeeds"

    @Serializable
    data class Parameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefs.Generatorview>    )

}

/**
 * Get a list of feeds (feed generator records) created by the actor (in the actor's repo).
 *
 * Endpoint: app.bsky.feed.getActorFeeds
 */
suspend fun ATProtoClient.App.Bsky.Feed.getactorfeeds(
parameters: AppBskyFeedGetactorfeeds.Parameters): ATProtoResponse<AppBskyFeedGetactorfeeds.Output> {
    val endpoint = "app.bsky.feed.getActorFeeds"

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
