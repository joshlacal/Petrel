// Lexicon: 1, ID: app.bsky.notification.putPreferencesV2
// Set notification-related preferences for an account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationPutPreferencesV2Defs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.putPreferencesV2"
}

@Serializable
    data class AppBskyNotificationPutPreferencesV2Input(
        @SerialName("chat")
        val chat: AppBskyNotificationDefsChatPreference? = null,        @SerialName("follow")
        val follow: AppBskyNotificationDefsFilterablePreference? = null,        @SerialName("like")
        val like: AppBskyNotificationDefsFilterablePreference? = null,        @SerialName("likeViaRepost")
        val likeViaRepost: AppBskyNotificationDefsFilterablePreference? = null,        @SerialName("mention")
        val mention: AppBskyNotificationDefsFilterablePreference? = null,        @SerialName("quote")
        val quote: AppBskyNotificationDefsFilterablePreference? = null,        @SerialName("reply")
        val reply: AppBskyNotificationDefsFilterablePreference? = null,        @SerialName("repost")
        val repost: AppBskyNotificationDefsFilterablePreference? = null,        @SerialName("repostViaRepost")
        val repostViaRepost: AppBskyNotificationDefsFilterablePreference? = null,        @SerialName("starterpackJoined")
        val starterpackJoined: AppBskyNotificationDefsPreference? = null,        @SerialName("subscribedPost")
        val subscribedPost: AppBskyNotificationDefsPreference? = null,        @SerialName("unverified")
        val unverified: AppBskyNotificationDefsPreference? = null,        @SerialName("verified")
        val verified: AppBskyNotificationDefsPreference? = null    )

    @Serializable
    data class AppBskyNotificationPutPreferencesV2Output(
        @SerialName("preferences")
        val preferences: AppBskyNotificationDefsPreferences    )

/**
 * Set notification-related preferences for an account. Requires auth.
 *
 * Endpoint: app.bsky.notification.putPreferencesV2
 */
suspend fun ATProtoClient.App.Bsky.Notification.putPreferencesV2(
input: AppBskyNotificationPutPreferencesV2Input): ATProtoResponse<AppBskyNotificationPutPreferencesV2Output> {
    val endpoint = "app.bsky.notification.putPreferencesV2"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
