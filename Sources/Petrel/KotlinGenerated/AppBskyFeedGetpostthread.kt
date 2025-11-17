// Lexicon: 1, ID: app.bsky.feed.getPostThread
// Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface OutputThreadUnion {
    @Serializable
    @SerialName("AppBskyFeedDefs.Threadviewpost")
    data class Threadviewpost(val value: AppBskyFeedDefs.Threadviewpost) : OutputThreadUnion

    @Serializable
    @SerialName("AppBskyFeedDefs.Notfoundpost")
    data class Notfoundpost(val value: AppBskyFeedDefs.Notfoundpost) : OutputThreadUnion

    @Serializable
    @SerialName("AppBskyFeedDefs.Blockedpost")
    data class Blockedpost(val value: AppBskyFeedDefs.Blockedpost) : OutputThreadUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputThreadUnion
}

object AppBskyFeedGetpostthread {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getPostThread"

    @Serializable
    data class Parameters(
// Reference (AT-URI) to post record.        @SerialName("uri")
        val uri: ATProtocolURI,// How many levels of reply depth should be included in response.        @SerialName("depth")
        val depth: Int? = null,// How many levels of parent (and grandparent, etc) post to include.        @SerialName("parentHeight")
        val parentHeight: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("thread")
        val thread: OutputThreadUnion,        @SerialName("threadgate")
        val threadgate: AppBskyFeedDefs.Threadgateview? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Notfound: Error("NotFound", "")
    }

}

/**
 * Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.
 *
 * Endpoint: app.bsky.feed.getPostThread
 */
suspend fun ATProtoClient.App.Bsky.Feed.getpostthread(
parameters: AppBskyFeedGetpostthread.Parameters): ATProtoResponse<AppBskyFeedGetpostthread.Output> {
    val endpoint = "app.bsky.feed.getPostThread"

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
