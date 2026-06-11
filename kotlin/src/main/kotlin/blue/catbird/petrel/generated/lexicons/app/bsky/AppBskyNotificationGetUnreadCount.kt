// Lexicon: 1, ID: app.bsky.notification.getUnreadCount
// Count the number of unread notifications for the requesting account. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyNotificationGetUnreadCountDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.getUnreadCount"
}

@Serializable
    data class AppBskyNotificationGetUnreadCountParameters(
        @SerialName("priority")
        val priority: Boolean? = null,        @SerialName("seenAt")
        val seenAt: ATProtocolDate? = null    )

    @Serializable
    data class AppBskyNotificationGetUnreadCountOutput(
        @SerialName("count")
        val count: Int    )

/**
 * Count the number of unread notifications for the requesting account. Requires auth.
 *
 * Endpoint: app.bsky.notification.getUnreadCount
 */
suspend fun ATProtoClient.App.Bsky.Notification.getUnreadCount(
parameters: AppBskyNotificationGetUnreadCountParameters): ATProtoResponse<AppBskyNotificationGetUnreadCountOutput> {
    val endpoint = "app.bsky.notification.getUnreadCount"

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
