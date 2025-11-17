// Lexicon: 1, ID: app.bsky.feed.sendInteractions
// Send information about interactions with feed items back to the feed generator that served them.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedSendinteractions {
    const val TYPE_IDENTIFIER = "app.bsky.feed.sendInteractions"

    @Serializable
    data class Input(
        @SerialName("interactions")
        val interactions: List<AppBskyFeedDefs.Interaction>    )

        @Serializable
    data class Output(
    )

}

/**
 * Send information about interactions with feed items back to the feed generator that served them.
 *
 * Endpoint: app.bsky.feed.sendInteractions
 */
suspend fun ATProtoClient.App.Bsky.Feed.sendinteractions(
input: AppBskyFeedSendinteractions.Input): ATProtoResponse<AppBskyFeedSendinteractions.Output> {
    val endpoint = "app.bsky.feed.sendInteractions"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
