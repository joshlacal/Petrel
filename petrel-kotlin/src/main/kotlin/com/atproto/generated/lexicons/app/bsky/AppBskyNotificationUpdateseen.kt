// Lexicon: 1, ID: app.bsky.notification.updateSeen
// Notify server that the requesting account has seen notifications. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationUpdateSeenDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.updateSeen"
}

@Serializable
    data class AppBskyNotificationUpdateSeenInput(
        @SerialName("seenAt")
        val seenAt: ATProtocolDate    )

/**
 * Notify server that the requesting account has seen notifications. Requires auth.
 *
 * Endpoint: app.bsky.notification.updateSeen
 */
suspend fun ATProtoClient.App.Bsky.Notification.updateSeen(
input: AppBskyNotificationUpdateSeenInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.updateSeen"

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
