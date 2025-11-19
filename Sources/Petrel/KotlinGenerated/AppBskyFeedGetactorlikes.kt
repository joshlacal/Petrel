// Lexicon: 1, ID: app.bsky.feed.getActorLikes
// Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetactorlikes {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getActorLikes"

    @Serializable
    data class Parameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefs.Feedviewpost>    )

    sealed class Error(val name: String, val description: String?) {
        object Blockedactor: Error("BlockedActor", "")
        object Blockedbyactor: Error("BlockedByActor", "")
    }

}

/**
 * Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.
 *
 * Endpoint: app.bsky.feed.getActorLikes
 */
suspend fun ATProtoClient.App.Bsky.Feed.getactorlikes(
parameters: AppBskyFeedGetactorlikes.Parameters): ATProtoResponse<AppBskyFeedGetactorlikes.Output> {
    val endpoint = "app.bsky.feed.getActorLikes"

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
