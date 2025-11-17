// Lexicon: 1, ID: app.bsky.notification.putPreferencesV2
// Set notification-related preferences for an account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationPutpreferencesv2 {
    const val TYPE_IDENTIFIER = "app.bsky.notification.putPreferencesV2"

    @Serializable
    data class Input(
        @SerialName("chat")
        val chat: AppBskyNotificationDefs.Chatpreference? = null,        @SerialName("follow")
        val follow: AppBskyNotificationDefs.Filterablepreference? = null,        @SerialName("like")
        val like: AppBskyNotificationDefs.Filterablepreference? = null,        @SerialName("likeViaRepost")
        val likeViaRepost: AppBskyNotificationDefs.Filterablepreference? = null,        @SerialName("mention")
        val mention: AppBskyNotificationDefs.Filterablepreference? = null,        @SerialName("quote")
        val quote: AppBskyNotificationDefs.Filterablepreference? = null,        @SerialName("reply")
        val reply: AppBskyNotificationDefs.Filterablepreference? = null,        @SerialName("repost")
        val repost: AppBskyNotificationDefs.Filterablepreference? = null,        @SerialName("repostViaRepost")
        val repostViaRepost: AppBskyNotificationDefs.Filterablepreference? = null,        @SerialName("starterpackJoined")
        val starterpackJoined: AppBskyNotificationDefs.Preference? = null,        @SerialName("subscribedPost")
        val subscribedPost: AppBskyNotificationDefs.Preference? = null,        @SerialName("unverified")
        val unverified: AppBskyNotificationDefs.Preference? = null,        @SerialName("verified")
        val verified: AppBskyNotificationDefs.Preference? = null    )

        @Serializable
    data class Output(
        @SerialName("preferences")
        val preferences: AppBskyNotificationDefs.Preferences    )

}

/**
 * Set notification-related preferences for an account. Requires auth.
 *
 * Endpoint: app.bsky.notification.putPreferencesV2
 */
suspend fun ATProtoClient.App.Bsky.Notification.putpreferencesv2(
input: AppBskyNotificationPutpreferencesv2.Input): ATProtoResponse<AppBskyNotificationPutpreferencesv2.Output> {
    val endpoint = "app.bsky.notification.putPreferencesV2"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
