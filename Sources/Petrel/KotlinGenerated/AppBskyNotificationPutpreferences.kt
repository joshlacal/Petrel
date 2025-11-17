// Lexicon: 1, ID: app.bsky.notification.putPreferences
// Set notification-related preferences for an account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationPutpreferences {
    const val TYPE_IDENTIFIER = "app.bsky.notification.putPreferences"

    @Serializable
    data class Input(
        @SerialName("priority")
        val priority: Boolean    )

}

/**
 * Set notification-related preferences for an account. Requires auth.
 *
 * Endpoint: app.bsky.notification.putPreferences
 */
suspend fun ATProtoClient.App.Bsky.Notification.putpreferences(
input: AppBskyNotificationPutpreferences.Input): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.putPreferences"

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
