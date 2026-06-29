// Lexicon: 1, ID: chat.bsky.notification.getPreferences
// Get the requesting account's chat notification preferences. Defaults are returned for accounts that have not set any preferences. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyNotificationGetPreferencesDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.notification.getPreferences"
}

    @Serializable
    data class ChatBskyNotificationGetPreferencesOutput(
        @SerialName("preferences")
        val preferences: ChatBskyNotificationDefsPreferences    )

/**
 * Get the requesting account's chat notification preferences. Defaults are returned for accounts that have not set any preferences. Requires auth.
 *
 * Endpoint: chat.bsky.notification.getPreferences
 */
suspend fun ATProtoClient.Chat.Bsky.Notification.getPreferences(
): ATProtoResponse<ChatBskyNotificationGetPreferencesOutput> {
    val endpoint = "chat.bsky.notification.getPreferences"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
