// Lexicon: 1, ID: app.bsky.notification.registerPush
// Register to receive push notifications, via a specified service, for the requesting account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationRegisterPushDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.registerPush"
}

@Serializable
    data class AppBskyNotificationRegisterPushInput(
        @SerialName("serviceDid")
        val serviceDid: DID,        @SerialName("token")
        val token: String,        @SerialName("platform")
        val platform: String,        @SerialName("appId")
        val appId: String,// Set to true when the actor is age restricted        @SerialName("ageRestricted")
        val ageRestricted: Boolean? = null    )

/**
 * Register to receive push notifications, via a specified service, for the requesting account. Requires auth.
 *
 * Endpoint: app.bsky.notification.registerPush
 */
suspend fun ATProtoClient.App.Bsky.Notification.registerPush(
input: AppBskyNotificationRegisterPushInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.registerPush"

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
