// Lexicon: 1, ID: app.bsky.unspecced.getPostThreadOtherV2
// (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get additional posts under a thread e.g. replies hidden by threadgate. Based on an anchor post at any depth of the tree, returns top-level replies below that anchor. It does not include ancestors nor the anchor itself. This should be called after exhausting `app.bsky.unspecced.getPostThreadV2`. Does not require auth, but additional metadata and filtering will be applied for authed requests.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface ThreaditemValueUnion {
    @Serializable
    @SerialName("AppBskyUnspeccedDefs.Threaditempost")
    data class Threaditempost(val value: AppBskyUnspeccedDefs.Threaditempost) : ThreaditemValueUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ThreaditemValueUnion
}

object AppBskyUnspeccedGetpostthreadotherv2 {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getPostThreadOtherV2"

    @Serializable
    data class Parameters(
// Reference (AT-URI) to post record. This is the anchor post.        @SerialName("anchor")
        val anchor: ATProtocolURI,// Whether to prioritize posts from followed users. It only has effect when the user is authenticated.        @SerialName("prioritizeFollowedUsers")
        val prioritizeFollowedUsers: Boolean? = null    )

        @Serializable
    data class Output(
// A flat list of other thread items. The depth of each item is indicated by the depth property inside the item.        @SerialName("thread")
        val thread: List<Threaditem>    )

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
 * (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get additional posts under a thread e.g. replies hidden by threadgate. Based on an anchor post at any depth of the tree, returns top-level replies below that anchor. It does not include ancestors nor the anchor itself. This should be called after exhausting `app.bsky.unspecced.getPostThreadV2`. Does not require auth, but additional metadata and filtering will be applied for authed requests.
 *
 * Endpoint: app.bsky.unspecced.getPostThreadOtherV2
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getpostthreadotherv2(
parameters: AppBskyUnspeccedGetpostthreadotherv2.Parameters): ATProtoResponse<AppBskyUnspeccedGetpostthreadotherv2.Output> {
    val endpoint = "app.bsky.unspecced.getPostThreadOtherV2"

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
