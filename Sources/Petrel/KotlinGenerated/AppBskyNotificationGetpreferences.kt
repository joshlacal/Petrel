// Lexicon: 1, ID: app.bsky.notification.getPreferences
// Get notification-related preferences for an account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationGetpreferences {
    const val TYPE_IDENTIFIER = "app.bsky.notification.getPreferences"

    @Serializable
    data class Parameters(
    )

        @Serializable
    data class Output(
        @SerialName("preferences")
        val preferences: AppBskyNotificationDefs.Preferences    )

}

/**
 * Get notification-related preferences for an account. Requires auth.
 *
 * Endpoint: app.bsky.notification.getPreferences
 */
suspend fun ATProtoClient.App.Bsky.Notification.getpreferences(
parameters: AppBskyNotificationGetpreferences.Parameters): ATProtoResponse<AppBskyNotificationGetpreferences.Output> {
    val endpoint = "app.bsky.notification.getPreferences"

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
