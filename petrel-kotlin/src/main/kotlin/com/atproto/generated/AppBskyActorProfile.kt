// Lexicon: 1, ID: app.bsky.actor.profile
// A declaration of a Bluesky account profile.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface AppBskyActorProfileLabelsUnion {
    @Serializable
    @SerialName("ComAtprotoLabelDefs.Selflabels")
    data class Selflabels(val value: ComAtprotoLabelDefs.Selflabels) : AppBskyActorProfileLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorProfileLabelsUnion
}

object AppBskyActorProfile {
    const val TYPE_IDENTIFIER = "app.bsky.actor.profile"

        /**
     * A declaration of a Bluesky account profile.
     */
    @Serializable
    data class Record(
        @SerialName("displayName")
        val displayName: String? = null,/** Free-form profile description text. */        @SerialName("description")
        val description: String? = null,/** Free-form pronouns text. */        @SerialName("pronouns")
        val pronouns: String? = null,        @SerialName("website")
        val website: URI? = null,/** Small image to be displayed next to posts from account. AKA, 'profile picture' */        @SerialName("avatar")
        val avatar: Blob? = null,/** Larger horizontal image to display behind profile view. */        @SerialName("banner")
        val banner: Blob? = null,/** Self-label values, specific to the Bluesky application, on the overall account. */        @SerialName("labels")
        val labels: AppBskyActorProfileLabelsUnion? = null,        @SerialName("joinedViaStarterPack")
        val joinedViaStarterPack: ComAtprotoRepoStrongref? = null,        @SerialName("pinnedPost")
        val pinnedPost: ComAtprotoRepoStrongref? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
