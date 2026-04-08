// Lexicon: 1, ID: app.bsky.feed.getActorFeeds
// Get a list of feeds (feed generator records) created by the actor (in the actor's repo).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetActorFeedsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getActorFeeds"
}

@Serializable
    data class AppBskyFeedGetActorFeedsParameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetActorFeedsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * Get a list of feeds (feed generator records) created by the actor (in the actor's repo).
 *
 * Endpoint: app.bsky.feed.getActorFeeds
 */
suspend fun ATProtoClient.App.Bsky.Feed.getActorFeeds(
parameters: AppBskyFeedGetActorFeedsParameters): ATProtoResponse<AppBskyFeedGetActorFeedsOutput> {
    val endpoint = "app.bsky.feed.getActorFeeds"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
