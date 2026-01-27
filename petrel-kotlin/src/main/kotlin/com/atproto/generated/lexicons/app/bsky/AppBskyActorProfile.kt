// Lexicon: 1, ID: app.bsky.actor.profile
// A declaration of a Bluesky account profile.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorProfileDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.profile"
}

@Serializable
sealed interface AppBskyActorProfileLabelsUnion {
    @Serializable
    @SerialName("app.bsky.actor.profile#ComAtprotoLabelDefsSelfLabels")
    data class ComAtprotoLabelDefsSelfLabels(val value: ComAtprotoLabelDefsSelfLabels) : AppBskyActorProfileLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorProfileLabelsUnion
}

    /**
     * A declaration of a Bluesky account profile.
     */
    @Serializable
    data class AppBskyActorProfile(
        @SerialName("displayName")
        val displayName: String? = null,/** Free-form profile description text. */        @SerialName("description")
        val description: String? = null,/** Free-form pronouns text. */        @SerialName("pronouns")
        val pronouns: String? = null,        @SerialName("website")
        val website: URI? = null,/** Small image to be displayed next to posts from account. AKA, 'profile picture' */        @SerialName("avatar")
        val avatar: Blob? = null,/** Larger horizontal image to display behind profile view. */        @SerialName("banner")
        val banner: Blob? = null,/** Self-label values, specific to the Bluesky application, on the overall account. */        @SerialName("labels")
        val labels: AppBskyActorProfileLabelsUnion? = null,        @SerialName("joinedViaStarterPack")
        val joinedViaStarterPack: ComAtprotoRepoStrongRef? = null,        @SerialName("pinnedPost")
        val pinnedPost: ComAtprotoRepoStrongRef? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
