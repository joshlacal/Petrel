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
        val displayName: String? = null,        @SerialName("avatar")
        val avatar: URI? = null,        @SerialName("associated")
        val associated: AppBskyActorDefsProfileAssociated? = null,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,/** Set to true when the actor cannot actively participate in conversations */        @SerialName("chatDisabled")
        val chatDisabled: Boolean? = null,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyActorDefsProfileViewBasic"
        }
    }
