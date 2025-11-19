// Lexicon: 1, ID: app.bsky.notification.getUnreadCount
// Count the number of unread notifications for the requesting account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationGetunreadcount {
    const val TYPE_IDENTIFIER = "app.bsky.notification.getUnreadCount"

    @Serializable
    data class Parameters(
        @SerialName("priority")
        val priority: Boolean? = null,        @SerialName("seenAt")
        val seenAt: ATProtocolDate? = null    )

        @Serializable
    data class Output(
        @SerialName("count")
        val count: Int    )

}

/**
 * Count the number of unread notifications for the requesting account. Requires auth.
 *
 * Endpoint: app.bsky.notification.getUnreadCount
 */
suspend fun ATProtoClient.App.Bsky.Notification.getunreadcount(
parameters: AppBskyNotificationGetunreadcount.Parameters): ATProtoResponse<AppBskyNotificationGetunreadcount.Output> {
    val endpoint = "app.bsky.notification.getUnreadCount"

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
