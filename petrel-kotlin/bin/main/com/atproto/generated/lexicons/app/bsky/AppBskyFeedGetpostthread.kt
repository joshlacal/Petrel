// Lexicon: 1, ID: app.bsky.feed.getPostThread
// Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetPostThreadDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getPostThread"
}

@Serializable
sealed interface AppBskyFeedGetPostThreadOutputThreadUnion {
    @Serializable
    @SerialName("app.bsky.feed.getPostThread#AppBskyFeedDefsThreadViewPost")
    data class AppBskyFeedDefsThreadViewPost(val value: AppBskyFeedDefsThreadViewPost) : AppBskyFeedGetPostThreadOutputThreadUnion

    @Serializable
    @SerialName("app.bsky.feed.getPostThread#AppBskyFeedDefsNotFoundPost")
    data class AppBskyFeedDefsNotFoundPost(val value: AppBskyFeedDefsNotFoundPost) : AppBskyFeedGetPostThreadOutputThreadUnion

    @Serializable
    @SerialName("app.bsky.feed.getPostThread#AppBskyFeedDefsBlockedPost")
    data class AppBskyFeedDefsBlockedPost(val value: AppBskyFeedDefsBlockedPost) : AppBskyFeedGetPostThreadOutputThreadUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedGetPostThreadOutputThreadUnion
}

@Serializable
    data class AppBskyFeedGetPostThreadParameters(
// Reference (AT-URI) to post record.        @SerialName("uri")
        val uri: ATProtocolURI,// How many levels of reply depth should be included in response.        @SerialName("depth")
        val depth: Int? = null,// How many levels of parent (and grandparent, etc) post to include.        @SerialName("parentHeight")
        val parentHeight: Int? = null    )

    @Serializable
    data class AppBskyFeedGetPostThreadOutput(
        @SerialName("thread")
        val thread: AppBskyFeedGetPostThreadOutputThreadUnion,        @SerialName("threadgate")
        val threadgate: AppBskyFeedDefsThreadgateView? = null    )

sealed class AppBskyFeedGetPostThreadError(val name: String, val description: String?) {
        object NotFound: AppBskyFeedGetPostThreadError("NotFound", "")
    }

/**
 * Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.
 *
 * Endpoint: app.bsky.feed.getPostThread
 */
suspend fun ATProtoClient.App.Bsky.Feed.getPostThread(
parameters: AppBskyFeedGetPostThreadParameters): ATProtoResponse<AppBskyFeedGetPostThreadOutput> {
    val endpoint = "app.bsky.feed.getPostThread"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
