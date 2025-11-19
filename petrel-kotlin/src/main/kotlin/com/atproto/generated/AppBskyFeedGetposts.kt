// Lexicon: 1, ID: app.bsky.feed.getPosts
// Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetposts {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getPosts"

    @Serializable
    data class Parameters(
// List of post AT-URIs to return hydrated views for.        @SerialName("uris")
        val uris: List<ATProtocolURI>    )

        @Serializable
    data class Output(
        @SerialName("posts")
        val posts: List<AppBskyFeedDefs.Postview>    )

}

/**
 * Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.
 *
 * Endpoint: app.bsky.feed.getPosts
 */
suspend fun ATProtoClient.App.Bsky.Feed.getposts(
parameters: AppBskyFeedGetposts.Parameters): ATProtoResponse<AppBskyFeedGetposts.Output> {
    val endpoint = "app.bsky.feed.getPosts"

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
