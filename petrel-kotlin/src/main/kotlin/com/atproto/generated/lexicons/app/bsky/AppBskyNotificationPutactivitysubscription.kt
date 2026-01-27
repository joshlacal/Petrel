// Lexicon: 1, ID: app.bsky.notification.putActivitySubscription
// Puts an activity subscription entry. The key should be omitted for creation and provided for updates. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationPutActivitySubscriptionDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.putActivitySubscription"
}

@Serializable
    data class AppBskyNotificationPutActivitySubscriptionInput(
        @SerialName("subject")
        val subject: DID,        @SerialName("activitySubscription")
        val activitySubscription: AppBskyNotificationDefsActivitySubscription    )

    @Serializable
    data class AppBskyNotificationPutActivitySubscriptionOutput(
        @SerialName("subject")
        val subject: DID,        @SerialName("activitySubscription")
        val activitySubscription: AppBskyNotificationDefsActivitySubscription? = null    )

/**
 * Puts an activity subscription entry. The key should be omitted for creation and provided for updates. Requires auth.
 *
 * Endpoint: app.bsky.notification.putActivitySubscription
 */
suspend fun ATProtoClient.App.Bsky.Notification.putActivitySubscription(
input: AppBskyNotificationPutActivitySubscriptionInput): ATProtoResponse<AppBskyNotificationPutActivitySubscriptionOutput> {
    val endpoint = "app.bsky.notification.putActivitySubscription"

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
