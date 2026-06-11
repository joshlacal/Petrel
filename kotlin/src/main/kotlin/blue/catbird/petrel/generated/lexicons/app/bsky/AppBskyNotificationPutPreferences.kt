// Lexicon: 1, ID: app.bsky.notification.putPreferences
// Set notification-related preferences for an account. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyNotificationPutPreferencesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.putPreferences"
}

@Serializable
    data class AppBskyNotificationPutPreferencesInput(
        @SerialName("priority")
        val priority: Boolean    )

/**
 * Set notification-related preferences for an account. Requires auth.
 *
 * Endpoint: app.bsky.notification.putPreferences
 */
suspend fun ATProtoClient.App.Bsky.Notification.putPreferences(
input: AppBskyNotificationPutPreferencesInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.notification.putPreferences"

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
            "Accept" to "None"
        ),
        body = body
    )
}
