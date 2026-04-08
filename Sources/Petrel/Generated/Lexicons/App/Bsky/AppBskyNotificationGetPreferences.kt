// Lexicon: 1, ID: app.bsky.notification.getPreferences
// Get notification-related preferences for an account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationGetPreferencesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.getPreferences"
}

@Serializable
    class AppBskyNotificationGetPreferencesParameters

    @Serializable
    data class AppBskyNotificationGetPreferencesOutput(
        @SerialName("preferences")
        val preferences: AppBskyNotificationDefsPreferences    )

/**
 * Get notification-related preferences for an account. Requires auth.
 *
 * Endpoint: app.bsky.notification.getPreferences
 */
suspend fun ATProtoClient.App.Bsky.Notification.getPreferences(
parameters: AppBskyNotificationGetPreferencesParameters): ATProtoResponse<AppBskyNotificationGetPreferencesOutput> {
    val endpoint = "app.bsky.notification.getPreferences"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
