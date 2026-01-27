// Lexicon: 1, ID: app.bsky.notification.unregisterPush
// The inverse of registerPush - inform a specified service that push notifications should no longer be sent to the given token for the requesting account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationUnregisterPushDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.unregisterPush"
}

@Serializable
    data class AppBskyNotificationUnregisterPushInput(
        @SerialName("serviceDid")
        val serviceDid: DID,        @SerialName("token")
        val token: String,        @SerialName("platform")
        val platform: String,        @SerialName("appId")
        val appId: String    )

/**
 * The inverse of registerPush - inform a specified service that push notifications should no longer be sent to the given token for the requesting account. Requires auth.
 *
 * Endpoint: app.bsky.notification.unregisterPush
 */
suspend fun ATProtoClient.App.Bsky.Notification.unregisterPush(
input: AppBskyNotificationUnregisterPushInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.unregisterPush"

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
