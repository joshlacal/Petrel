// Lexicon: 1, ID: app.bsky.feed.sendInteractions
// Send information about interactions with feed items back to the feed generator that served them.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedSendInteractionsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.sendInteractions"
}

@Serializable
    data class AppBskyFeedSendInteractionsInput(
        @SerialName("feed")
        val feed: ATProtocolURI? = null,        @SerialName("interactions")
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

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
