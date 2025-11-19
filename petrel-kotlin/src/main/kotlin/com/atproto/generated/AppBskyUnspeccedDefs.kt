// Lexicon: 1, ID: app.bsky.unspecced.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.defs"

        @Serializable
    data class Skeletonsearchpost(
        @SerialName("uri")
        val uri: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#skeletonsearchpost"
        }
    }

    @Serializable
    data class Skeletonsearchactor(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#skeletonsearchactor"
        }
    }

    @Serializable
    data class Skeletonsearchstarterpack(
        @SerialName("uri")
        val uri: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#skeletonsearchstarterpack"
        }
    }

    @Serializable
    data class Trendingtopic(
        @SerialName("topic")
        val topic: String,        @SerialName("displayName")
        val displayName: String?,        @SerialName("description")
        val description: String?,        @SerialName("link")
        val link: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#trendingtopic"
        }
    }

    @Serializable
    data class Skeletontrend(
        @SerialName("topic")
        val topic: String,        @SerialName("displayName")
        val displayName: String,        @SerialName("link")
        val link: String,        @SerialName("startedAt")
        val startedAt: ATProtocolDate,        @SerialName("postCount")
        val postCount: Int,        @SerialName("status")
        val status: String?,        @SerialName("category")
        val category: String?,        @SerialName("dids")
        val dids: List<DID>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#skeletontrend"
        }
    }

    @Serializable
    data class Trendview(
        @SerialName("topic")
        val topic: String,        @SerialName("displayName")
        val displayName: String,        @SerialName("link")
        val link: String,        @SerialName("startedAt")
        val startedAt: ATProtocolDate,        @SerialName("postCount")
        val postCount: Int,        @SerialName("status")
        val status: String?,        @SerialName("category")
        val category: String?,        @SerialName("actors")
        val actors: List<AppBskyActorDefs.Profileviewbasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#trendview"
        }
    }

    @Serializable
    data class Threaditempost(
        @SerialName("post")
        val post: AppBskyFeedDefs.Postview,/** This post has more parents that were not present in the response. This is just a boolean, without the number of parents. */        @SerialName("moreParents")
        val moreParents: Boolean,/** This post has more replies that were not present in the response. This is a numeric value, which is best-effort and might not be accurate. */        @SerialName("moreReplies")
        val moreReplies: Int,/** This post is part of a contiguous thread by the OP from the thread root. Many different OP threads can happen in the same thread. */        @SerialName("opThread")
        val opThread: Boolean,/** The threadgate created by the author indicates this post as a reply to be hidden for everyone consuming the thread. */        @SerialName("hiddenByThreadgate")
        val hiddenByThreadgate: Boolean,/** This is by an account muted by the viewer requesting it. */        @SerialName("mutedByViewer")
        val mutedByViewer: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threaditempost"
        }
    }

    @Serializable
    data class Threaditemnounauthenticated(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threaditemnounauthenticated"
        }
    }

    @Serializable
    data class Threaditemnotfound(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threaditemnotfound"
        }
    }

    @Serializable
    data class Threaditemblocked(
        @SerialName("author")
        val author: AppBskyFeedDefs.Blockedauthor    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threaditemblocked"
        }
    }

    /**
     * The computed state of the age assurance process, returned to the user in question on certain authenticated requests.
     */
    @Serializable
    data class Ageassurancestate(
/** The timestamp when this state was last updated. */        @SerialName("lastInitiatedAt")
        val lastInitiatedAt: ATProtocolDate?,/** The status of the age assurance process. */        @SerialName("status")
        val status: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#ageassurancestate"
        }
    }

    /**
     * Object used to store age assurance data in stash.
     */
    @Serializable
    data class Ageassuranceevent(
/** The date and time of this write operation. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The status of the age assurance process. */        @SerialName("status")
        val status: String,/** The unique identifier for this instance of the age assurance flow, in UUID format. */        @SerialName("attemptId")
        val attemptId: String,/** The email used for AA. */        @SerialName("email")
        val email: String?,/** The IP address used when initiating the AA flow. */        @SerialName("initIp")
        val initIp: String?,/** The user agent used when initiating the AA flow. */        @SerialName("initUa")
        val initUa: String?,/** The IP address used when completing the AA flow. */        @SerialName("completeIp")
        val completeIp: String?,/** The user agent used when completing the AA flow. */        @SerialName("completeUa")
        val completeUa: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#ageassuranceevent"
        }
    }

}
