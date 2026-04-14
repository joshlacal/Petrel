// Lexicon: 1, ID: app.bsky.feed.getQuotes
// Get a list of quotes for a given post.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetQuotesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getQuotes"
}

@Serializable
    data class AppBskyFeedGetQuotesParameters(
// Reference (AT-URI) of post record        @SerialName("uri")
        val uri: ATProtocolURI,// If supplied, filters to quotes of specific version (by CID) of the post record.        @SerialName("cid")
        val cid: CID? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetQuotesOutput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("posts")
        val posts: List<AppBskyFeedDefsPostView>    )

/**
 * Get a list of quotes for a given post.
 *
 * Endpoint: app.bsky.feed.getQuotes
 */
suspend fun ATProtoClient.App.Bsky.Feed.getQuotes(
parameters: AppBskyFeedGetQuotesParameters): ATProtoResponse<AppBskyFeedGetQuotesOutput> {
    val endpoint = "app.bsky.feed.getQuotes"

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
