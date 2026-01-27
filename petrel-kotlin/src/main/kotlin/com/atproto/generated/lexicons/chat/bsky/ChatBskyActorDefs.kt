// Lexicon: 1, ID: chat.bsky.actor.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyActorDefsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.defs"
}

    @Serializable
    data class ChatBskyActorDefsProfileViewBasic(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("associated")
        val associated: AppBskyActorDefsProfileAssociated?,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,/** Set to true when the actor cannot actively participate in conversations */        @SerialName("chatDisabled")
        val chatDisabled: Boolean?,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyActorDefsProfileViewBasic"
        }
    }
