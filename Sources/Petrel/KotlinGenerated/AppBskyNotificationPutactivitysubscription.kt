// Lexicon: 1, ID: app.bsky.notification.putActivitySubscription
// Puts an activity subscription entry. The key should be omitted for creation and provided for updates. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationPutactivitysubscription {
    const val TYPE_IDENTIFIER = "app.bsky.notification.putActivitySubscription"

    @Serializable
    data class Input(
        @SerialName("subject")
        val subject: DID,        @SerialName("activitySubscription")
        val activitySubscription: AppBskyNotificationDefs.Activitysubscription    )

        @Serializable
    data class Output(
        @SerialName("subject")
        val subject: DID,        @SerialName("activitySubscription")
        val activitySubscription: AppBskyNotificationDefs.Activitysubscription? = null    )

}

/**
 * Puts an activity subscription entry. The key should be omitted for creation and provided for updates. Requires auth.
 *
 * Endpoint: app.bsky.notification.putActivitySubscription
 */
suspend fun ATProtoClient.App.Bsky.Notification.putactivitysubscription(
input: AppBskyNotificationPutactivitysubscription.Input): ATProtoResponse<AppBskyNotificationPutactivitysubscription.Output> {
    val endpoint = "app.bsky.notification.putActivitySubscription"

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
