// Lexicon: 1, ID: app.bsky.feed.getPosts
// Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetPostsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getPosts"
}

@Serializable
    data class AppBskyFeedGetPostsParameters(
// List of post AT-URIs to return hydrated views for.        @SerialName("uris")
        val uris: List<ATProtocolURI>    )

    @Serializable
    data class AppBskyFeedGetPostsOutput(
        @SerialName("posts")
        val posts: List<AppBskyFeedDefsPostView>    )

/**
 * Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.
 *
 * Endpoint: app.bsky.feed.getPosts
 */
suspend fun ATProtoClient.App.Bsky.Feed.getPosts(
parameters: AppBskyFeedGetPostsParameters): ATProtoResponse<AppBskyFeedGetPostsOutput> {
    val endpoint = "app.bsky.feed.getPosts"

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
