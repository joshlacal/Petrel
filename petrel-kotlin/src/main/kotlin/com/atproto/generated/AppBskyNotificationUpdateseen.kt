// Lexicon: 1, ID: app.bsky.notification.updateSeen
// Notify server that the requesting account has seen notifications. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationUpdateseen {
    const val TYPE_IDENTIFIER = "app.bsky.notification.updateSeen"

    @Serializable
    data class Input(
        @SerialName("seenAt")
        val seenAt: ATProtocolDate    )

}

/**
 * Notify server that the requesting account has seen notifications. Requires auth.
 *
 * Endpoint: app.bsky.notification.updateSeen
 */
suspend fun ATProtoClient.App.Bsky.Notification.updateseen(
input: AppBskyNotificationUpdateseen.Input): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.updateSeen"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
