// Lexicon: 1, ID: app.bsky.notification.updateSeen
// Notify server that the requesting account has seen notifications. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyNotificationUpdateSeenDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.updateSeen"
}

@Serializable
    data class AppBskyNotificationUpdateSeenInput(
        @SerialName("seenAt")
        val seenAt: ATProtocolDate    )

/**
 * Notify server that the requesting account has seen notifications. Requires auth.
 *
 * Endpoint: app.bsky.notification.updateSeen
 */
suspend fun ATProtoClient.App.Bsky.Notification.updateSeen(
input: AppBskyNotificationUpdateSeenInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.updateSeen"

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
            "Accept" to "None"
        ),
        body = body
    )
}
