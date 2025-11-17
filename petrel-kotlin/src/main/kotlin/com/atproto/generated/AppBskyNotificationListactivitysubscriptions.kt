// Lexicon: 1, ID: app.bsky.notification.listActivitySubscriptions
// Enumerate all accounts to which the requesting account is subscribed to receive notifications for. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationListactivitysubscriptions {
    const val TYPE_IDENTIFIER = "app.bsky.notification.listActivitySubscriptions"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("subscriptions")
        val subscriptions: List<AppBskyActorDefs.Profileview>    )

}

/**
 * Enumerate all accounts to which the requesting account is subscribed to receive notifications for. Requires auth.
 *
 * Endpoint: app.bsky.notification.listActivitySubscriptions
 */
suspend fun ATProtoClient.App.Bsky.Notification.listactivitysubscriptions(
parameters: AppBskyNotificationListactivitysubscriptions.Parameters): ATProtoResponse<AppBskyNotificationListactivitysubscriptions.Output> {
    val endpoint = "app.bsky.notification.listActivitySubscriptions"

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
