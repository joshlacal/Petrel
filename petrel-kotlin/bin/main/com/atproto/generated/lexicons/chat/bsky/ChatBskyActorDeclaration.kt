// Lexicon: 1, ID: chat.bsky.actor.declaration
// A declaration of a Bluesky chat account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyActorDeclarationDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.declaration"
}

    /**
     * A declaration of a Bluesky chat account.
     */
    @Serializable
    data class ChatBskyActorDeclaration(
        @SerialName("allowIncoming")
        val allowIncoming: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
