// Lexicon: 1, ID: chat.bsky.actor.declaration
// A declaration of a Bluesky chat account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
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
        val allowIncoming: String,/** [NOTE: This is under active development and should be considered unstable while this note is here]. Declaration about group chat invitation preferences for the record owner. */        @SerialName("allowGroupInvites")
        val allowGroupInvites: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
