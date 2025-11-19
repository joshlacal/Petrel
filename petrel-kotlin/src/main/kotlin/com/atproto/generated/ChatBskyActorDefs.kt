// Lexicon: 1, ID: chat.bsky.actor.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyActorDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.defs"

        @Serializable
    data class Profileviewbasic(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("associated")
        val associated: AppBskyActorDefs.Profileassociated?,        @SerialName("viewer")
        val viewer: AppBskyActorDefs.Viewerstate?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,/** Set to true when the actor cannot actively participate in conversations */        @SerialName("chatDisabled")
        val chatDisabled: Boolean?,        @SerialName("verification")
        val verification: AppBskyActorDefs.Verificationstate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#profileviewbasic"
        }
    }

}
