// Lexicon: 1, ID: app.bsky.actor.status
// A declaration of a Bluesky account status.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface AppBskyActorStatusEmbedUnion {
    @Serializable
    @SerialName("app.bsky.actor.status#AppBskyEmbedExternal")
    data class AppBskyEmbedExternal(val value: AppBskyEmbedExternal) : AppBskyActorStatusEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorStatusEmbedUnion
}

object AppBskyActorStatus {
    const val TYPE_IDENTIFIER = "app.bsky.actor.status"

        /**
     * A declaration of a Bluesky account status.
     */
    @Serializable
    data class Record(
/** The status for the account. */        @SerialName("status")
        val status: String,/** An optional embed associated with the status. */        @SerialName("embed")
        val embed: AppBskyActorStatusEmbedUnion? = null,/** The duration of the status in minutes. Applications can choose to impose minimum and maximum limits. */        @SerialName("durationMinutes")
        val durationMinutes: Int? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
