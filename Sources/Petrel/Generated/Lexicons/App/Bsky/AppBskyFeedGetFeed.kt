// Lexicon: 1, ID: app.bsky.feed.getFeed
// Get a hydrated feed from an actor's selected feed generator. Implemented by App View.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetFeedDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeed"
}

@Serializable
    data class AppBskyFeedGetFeedParameters(
        @SerialName("feed")
        val feed: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetFeedOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefsFeedViewPost>    )

sealed class AppBskyFeedGetFeedError(val name: String, val description: String?) {
        object UnknownFeed: AppBskyFeedGetFeedError("UnknownFeed", "")
    }

/**
 * Get a hydrated feed from an actor's selected feed generator. Implemented by App View.
 *
 * Endpoint: app.bsky.feed.getFeed
 */
suspend fun ATProtoClient.App.Bsky.Feed.getFeed(
parameters: AppBskyFeedGetFeedParameters): ATProtoResponse<AppBskyFeedGetFeedOutput> {
    val endpoint = "app.bsky.feed.getFeed"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
