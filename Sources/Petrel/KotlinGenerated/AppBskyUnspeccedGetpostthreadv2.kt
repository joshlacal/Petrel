// Lexicon: 1, ID: app.bsky.unspecced.getPostThreadV2
// (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get posts in a thread. It is based in an anchor post at any depth of the tree, and returns posts above it (recursively resolving the parent, without further branching to their replies) and below it (recursive replies, with branching to their replies). Does not require auth, but additional metadata and filtering will be applied for authed requests.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface ThreaditemValueUnion {
    @Serializable
    @SerialName("AppBskyUnspeccedDefs.Threaditempost")
    data class Threaditempost(val value: AppBskyUnspeccedDefs.Threaditempost) : ThreaditemValueUnion

    @Serializable
    @SerialName("AppBskyUnspeccedDefs.Threaditemnounauthenticated")
    data class Threaditemnounauthenticated(val value: AppBskyUnspeccedDefs.Threaditemnounauthenticated) : ThreaditemValueUnion

    @Serializable
    @SerialName("AppBskyUnspeccedDefs.Threaditemnotfound")
    data class Threaditemnotfound(val value: AppBskyUnspeccedDefs.Threaditemnotfound) : ThreaditemValueUnion

    @Serializable
    @SerialName("AppBskyUnspeccedDefs.Threaditemblocked")
    data class Threaditemblocked(val value: AppBskyUnspeccedDefs.Threaditemblocked) : ThreaditemValueUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ThreaditemValueUnion
}

object AppBskyUnspeccedGetpostthreadv2 {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getPostThreadV2"

    @Serializable
    data class Parameters(
// Reference (AT-URI) to post record. This is the anchor post, and the thread will be built around it. It can be any post in the tree, not necessarily a root post.        @SerialName("anchor")
        val anchor: ATProtocolURI,// Whether to include parents above the anchor.        @SerialName("above")
        val above: Boolean? = null,// How many levels of replies to include below the anchor.        @SerialName("below")
        val below: Int? = null,// Maximum of replies to include at each level of the thread, except for the direct replies to the anchor, which are (NOTE: currently, during unspecced phase) all returned (NOTE: later they might be paginated).        @SerialName("branchingFactor")
        val branchingFactor: Int? = null,// Whether to prioritize posts from followed users. It only has effect when the user is authenticated.        @SerialName("prioritizeFollowedUsers")
        val prioritizeFollowedUsers: Boolean? = null,// Sorting for the thread replies.        @SerialName("sort")
        val sort: String? = null    )

        @Serializable
    data class Output(
// A flat list of thread items. The depth of each item is indicated by the depth property inside the item.        @SerialName("thread")
        val thread: List<Threaditem>,        @SerialName("threadgate")
        val threadgate: AppBskyFeedDefs.Threadgateview? = null,// Whether this thread has additional replies. If true, a call can be made to the `getPostThreadOtherV2` endpoint to retrieve them.        @SerialName("hasOtherReplies")
        val hasOtherReplies: Boolean    )

        @Serializable
    data class Threaditem(
        @SerialName("uri")
        val uri: ATProtocolURI,/** The nesting level of this item in the thread. Depth 0 means the anchor item. Items above have negative depths, items below have positive depths. */        @SerialName("depth")
        val depth: Int,        @SerialName("value")
        val value: ThreaditemValueUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threaditem"
        }
    }

}

/**
 * (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get posts in a thread. It is based in an anchor post at any depth of the tree, and returns posts above it (recursively resolving the parent, without further branching to their replies) and below it (recursive replies, with branching to their replies). Does not require auth, but additional metadata and filtering will be applied for authed requests.
 *
 * Endpoint: app.bsky.unspecced.getPostThreadV2
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getpostthreadv2(
parameters: AppBskyUnspeccedGetpostthreadv2.Parameters): ATProtoResponse<AppBskyUnspeccedGetpostthreadv2.Output> {
    val endpoint = "app.bsky.unspecced.getPostThreadV2"

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
