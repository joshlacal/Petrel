// Lexicon: 1, ID: app.bsky.notification.registerPush
// Register to receive push notifications, via a specified service, for the requesting account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationRegisterpush {
    const val TYPE_IDENTIFIER = "app.bsky.notification.registerPush"

    @Serializable
    data class Input(
        @SerialName("serviceDid")
        val serviceDid: DID,        @SerialName("token")
        val token: String,        @SerialName("platform")
        val platform: String,        @SerialName("appId")
        val appId: String,// Set to true when the actor is age restricted        @SerialName("ageRestricted")
        val ageRestricted: Boolean? = null    )

}

/**
 * Register to receive push notifications, via a specified service, for the requesting account. Requires auth.
 *
 * Endpoint: app.bsky.notification.registerPush
 */
suspend fun ATProtoClient.App.Bsky.Notification.registerpush(
input: AppBskyNotificationRegisterpush.Input): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.registerPush"

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
