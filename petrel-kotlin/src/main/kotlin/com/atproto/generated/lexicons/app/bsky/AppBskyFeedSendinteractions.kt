// Lexicon: 1, ID: app.bsky.feed.sendInteractions
// Send information about interactions with feed items back to the feed generator that served them.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedSendInteractionsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.sendInteractions"
}

@Serializable
    data class AppBskyFeedSendInteractionsInput(
        @SerialName("interactions")
        val interactions: List<AppBskyFeedDefsInteraction>    )

    @Serializable
    class AppBskyFeedSendInteractionsOutput

/**
 * Send information about interactions with feed items back to the feed generator that served them.
 *
 * Endpoint: app.bsky.feed.sendInteractions
 */
suspend fun ATProtoClient.App.Bsky.Feed.sendInteractions(
input: AppBskyFeedSendInteractionsInput): ATProtoResponse<AppBskyFeedSendInteractionsOutput> {
    val endpoint = "app.bsky.feed.sendInteractions"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
