// Lexicon: 1, ID: app.bsky.notification.listActivitySubscriptions
// Enumerate all accounts to which the requesting account is subscribed to receive notifications for. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationListActivitySubscriptionsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.listActivitySubscriptions"
}

@Serializable
    data class AppBskyNotificationListActivitySubscriptionsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyNotificationListActivitySubscriptionsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("subscriptions")
        val subscriptions: List<AppBskyActorDefsProfileView>    )

/**
 * Enumerate all accounts to which the requesting account is subscribed to receive notifications for. Requires auth.
 *
 * Endpoint: app.bsky.notification.listActivitySubscriptions
 */
suspend fun ATProtoClient.App.Bsky.Notification.listActivitySubscriptions(
parameters: AppBskyNotificationListActivitySubscriptionsParameters): ATProtoResponse<AppBskyNotificationListActivitySubscriptionsOutput> {
    val endpoint = "app.bsky.notification.listActivitySubscriptions"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
