// Lexicon: 1, ID: app.bsky.notification.putPreferences
// Set notification-related preferences for an account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationPutPreferencesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.putPreferences"
}

@Serializable
    data class AppBskyNotificationPutPreferencesInput(
        @SerialName("priority")
        val priority: Boolean    )

/**
 * Set notification-related preferences for an account. Requires auth.
 *
 * Endpoint: app.bsky.notification.putPreferences
 */
suspend fun ATProtoClient.App.Bsky.Notification.putPreferences(
input: AppBskyNotificationPutPreferencesInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.putPreferences"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
