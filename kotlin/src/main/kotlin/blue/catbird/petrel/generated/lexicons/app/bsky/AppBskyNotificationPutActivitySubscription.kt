// Lexicon: 1, ID: app.bsky.notification.putActivitySubscription
// Puts an activity subscription entry. The key should be omitted for creation and provided for updates. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
