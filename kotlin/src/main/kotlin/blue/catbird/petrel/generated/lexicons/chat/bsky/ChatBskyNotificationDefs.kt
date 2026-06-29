// Lexicon: 1, ID: chat.bsky.notification.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyNotificationDefsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.notification.defs"
}

    @Serializable
    data class ChatBskyNotificationDefsPreferences(
        @SerialName("chat")
        val chat: ChatBskyNotificationDefsChatPreference,        @SerialName("chatRequest")
        val chatRequest: ChatBskyNotificationDefsChatPreference    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyNotificationDefsPreferences"
        }
    }

    @Serializable
    data class ChatBskyNotificationDefsChatPreference(
        @SerialName("include")
        val include: String,        @SerialName("push")
        val push: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyNotificationDefsChatPreference"
        }
    }
