// Lexicon: 1, ID: chat.bsky.notification.putPreferences
// Set the requesting account's chat notification preferences. Only the provided preferences are updated; omitted preferences are left unchanged.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyNotificationPutPreferencesDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.notification.putPreferences"
}

@Serializable
    data class ChatBskyNotificationPutPreferencesInput(
        @SerialName("chat")
        val chat: ChatBskyNotificationDefsChatPreference? = null,        @SerialName("chatRequest")
        val chatRequest: ChatBskyNotificationDefsChatPreference? = null    )

    @Serializable
    data class ChatBskyNotificationPutPreferencesOutput(
        @SerialName("preferences")
        val preferences: ChatBskyNotificationDefsPreferences    )

/**
 * Set the requesting account's chat notification preferences. Only the provided preferences are updated; omitted preferences are left unchanged.
 *
 * Endpoint: chat.bsky.notification.putPreferences
 */
suspend fun ATProtoClient.Chat.Bsky.Notification.putPreferences(
input: ChatBskyNotificationPutPreferencesInput): ATProtoResponse<ChatBskyNotificationPutPreferencesOutput> {
    val endpoint = "chat.bsky.notification.putPreferences"

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
