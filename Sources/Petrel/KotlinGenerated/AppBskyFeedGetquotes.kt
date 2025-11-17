// Lexicon: 1, ID: app.bsky.feed.getQuotes
// Get a list of quotes for a given post.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetquotes {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getQuotes"

    @Serializable
    data class Parameters(
// Reference (AT-URI) of post record        @SerialName("uri")
        val uri: ATProtocolURI,// If supplied, filters to quotes of specific version (by CID) of the post record.        @SerialName("cid")
        val cid: CID? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("posts")
        val posts: List<AppBskyFeedDefs.Postview>    )

}

/**
 * Get a list of quotes for a given post.
 *
 * Endpoint: app.bsky.feed.getQuotes
 */
suspend fun ATProtoClient.App.Bsky.Feed.getquotes(
parameters: AppBskyFeedGetquotes.Parameters): ATProtoResponse<AppBskyFeedGetquotes.Output> {
    val endpoint = "app.bsky.feed.getQuotes"

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
