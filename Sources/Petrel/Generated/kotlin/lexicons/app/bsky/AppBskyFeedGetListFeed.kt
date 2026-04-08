// Lexicon: 1, ID: app.bsky.feed.getListFeed
// Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetListFeedDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getListFeed"
}

@Serializable
    data class AppBskyFeedGetListFeedParameters(
// Reference (AT-URI) to the list record.        @SerialName("list")
        val list: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetListFeedOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefsFeedViewPost>    )

sealed class AppBskyFeedGetListFeedError(val name: String, val description: String?) {
        object UnknownList: AppBskyFeedGetListFeedError("UnknownList", "")
    }

/**
 * Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.
 *
 * Endpoint: app.bsky.feed.getListFeed
 */
suspend fun ATProtoClient.App.Bsky.Feed.getListFeed(
parameters: AppBskyFeedGetListFeedParameters): ATProtoResponse<AppBskyFeedGetListFeedOutput> {
    val endpoint = "app.bsky.feed.getListFeed"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
