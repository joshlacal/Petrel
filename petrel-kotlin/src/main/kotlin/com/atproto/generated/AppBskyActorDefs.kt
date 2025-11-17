// Lexicon: 1, ID: app.bsky.actor.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface AppBskyActorDefsPreferencesUnion {
    @Serializable
    @SerialName("app.bsky.actor.defs#Adultcontentpref")
    data class Adultcontentpref(val value: Adultcontentpref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Contentlabelpref")
    data class Contentlabelpref(val value: Contentlabelpref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Savedfeedspref")
    data class Savedfeedspref(val value: Savedfeedspref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Savedfeedsprefv2")
    data class Savedfeedsprefv2(val value: Savedfeedsprefv2) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Personaldetailspref")
    data class Personaldetailspref(val value: Personaldetailspref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Feedviewpref")
    data class Feedviewpref(val value: Feedviewpref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Threadviewpref")
    data class Threadviewpref(val value: Threadviewpref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Interestspref")
    data class Interestspref(val value: Interestspref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Mutedwordspref")
    data class Mutedwordspref(val value: Mutedwordspref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Hiddenpostspref")
    data class Hiddenpostspref(val value: Hiddenpostspref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Bskyappstatepref")
    data class Bskyappstatepref(val value: Bskyappstatepref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Labelerspref")
    data class Labelerspref(val value: Labelerspref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Postinteractionsettingspref")
    data class Postinteractionsettingspref(val value: Postinteractionsettingspref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#Verificationprefs")
    data class Verificationprefs(val value: Verificationprefs) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPreferencesUnion
}

@Serializable
sealed interface PostinteractionsettingsprefThreadgateallowrulesUnion {
    @Serializable
    @SerialName("AppBskyFeedThreadgate.Mentionrule")
    data class Mentionrule(val value: AppBskyFeedThreadgate.Mentionrule) : PostinteractionsettingsprefThreadgateallowrulesUnion

    @Serializable
    @SerialName("AppBskyFeedThreadgate.Followerrule")
    data class Followerrule(val value: AppBskyFeedThreadgate.Followerrule) : PostinteractionsettingsprefThreadgateallowrulesUnion

    @Serializable
    @SerialName("AppBskyFeedThreadgate.Followingrule")
    data class Followingrule(val value: AppBskyFeedThreadgate.Followingrule) : PostinteractionsettingsprefThreadgateallowrulesUnion

    @Serializable
    @SerialName("AppBskyFeedThreadgate.Listrule")
    data class Listrule(val value: AppBskyFeedThreadgate.Listrule) : PostinteractionsettingsprefThreadgateallowrulesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : PostinteractionsettingsprefThreadgateallowrulesUnion
}

@Serializable
sealed interface PostinteractionsettingsprefPostgateembeddingrulesUnion {
    @Serializable
    @SerialName("AppBskyFeedPostgate.Disablerule")
    data class Disablerule(val value: AppBskyFeedPostgate.Disablerule) : PostinteractionsettingsprefPostgateembeddingrulesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : PostinteractionsettingsprefPostgateembeddingrulesUnion
}

@Serializable
sealed interface StatusviewEmbedUnion {
    @Serializable
    @SerialName("AppBskyEmbedExternal.View")
    data class View(val value: AppBskyEmbedExternal.View) : StatusviewEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : StatusviewEmbedUnion
}

@Serializable
enum class Mutedwordtarget {
    @SerialName("content")
    CONTENT,    @SerialName("tag")
    TAG}

object AppBskyActorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.defs"

        @Serializable
    data class Profileviewbasic(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String?,        @SerialName("pronouns")
        val pronouns: String?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("associated")
        val associated: Profileassociated?,        @SerialName("viewer")
        val viewer: Viewerstate?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,        @SerialName("verification")
        val verification: Verificationstate?,        @SerialName("status")
        val status: Statusview?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#profileviewbasic"
        }
    }

    @Serializable
    data class Profileview(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String?,        @SerialName("pronouns")
        val pronouns: String?,        @SerialName("description")
        val description: String?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("associated")
        val associated: Profileassociated?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate?,        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,        @SerialName("viewer")
        val viewer: Viewerstate?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("verification")
        val verification: Verificationstate?,        @SerialName("status")
        val status: Statusview?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#profileview"
        }
    }

    @Serializable
    data class Profileviewdetailed(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String?,        @SerialName("description")
        val description: String?,        @SerialName("pronouns")
        val pronouns: String?,        @SerialName("website")
        val website: URI?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("banner")
        val banner: URI?,        @SerialName("followersCount")
        val followersCount: Int?,        @SerialName("followsCount")
        val followsCount: Int?,        @SerialName("postsCount")
        val postsCount: Int?,        @SerialName("associated")
        val associated: Profileassociated?,        @SerialName("joinedViaStarterPack")
        val joinedViaStarterPack: AppBskyGraphDefs.Starterpackviewbasic?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate?,        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,        @SerialName("viewer")
        val viewer: Viewerstate?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("pinnedPost")
        val pinnedPost: ComAtprotoRepoStrongref?,        @SerialName("verification")
        val verification: Verificationstate?,        @SerialName("status")
        val status: Statusview?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#profileviewdetailed"
        }
    }

    @Serializable
    data class Profileassociated(
        @SerialName("lists")
        val lists: Int?,        @SerialName("feedgens")
        val feedgens: Int?,        @SerialName("starterPacks")
        val starterPacks: Int?,        @SerialName("labeler")
        val labeler: Boolean?,        @SerialName("chat")
        val chat: Profileassociatedchat?,        @SerialName("activitySubscription")
        val activitySubscription: Profileassociatedactivitysubscription?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#profileassociated"
        }
    }

    @Serializable
    data class Profileassociatedchat(
        @SerialName("allowIncoming")
        val allowIncoming: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#profileassociatedchat"
        }
    }

    @Serializable
    data class Profileassociatedactivitysubscription(
        @SerialName("allowSubscriptions")
        val allowSubscriptions: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#profileassociatedactivitysubscription"
        }
    }

    /**
     * Metadata about the requesting account's relationship with the subject account. Only has meaningful content for authed requests.
     */
    @Serializable
    data class Viewerstate(
        @SerialName("muted")
        val muted: Boolean?,        @SerialName("mutedByList")
        val mutedByList: AppBskyGraphDefs.Listviewbasic?,        @SerialName("blockedBy")
        val blockedBy: Boolean?,        @SerialName("blocking")
        val blocking: ATProtocolURI?,        @SerialName("blockingByList")
        val blockingByList: AppBskyGraphDefs.Listviewbasic?,        @SerialName("following")
        val following: ATProtocolURI?,        @SerialName("followedBy")
        val followedBy: ATProtocolURI?,/** This property is present only in selected cases, as an optimization. */        @SerialName("knownFollowers")
        val knownFollowers: Knownfollowers?,/** This property is present only in selected cases, as an optimization. */        @SerialName("activitySubscription")
        val activitySubscription: AppBskyNotificationDefs.Activitysubscription?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#viewerstate"
        }
    }

    /**
     * The subject's followers whom you also follow
     */
    @Serializable
    data class Knownfollowers(
        @SerialName("count")
        val count: Int,        @SerialName("followers")
        val followers: List<Profileviewbasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#knownfollowers"
        }
    }

    /**
     * Represents the verification information about the user this object is attached to.
     */
    @Serializable
    data class Verificationstate(
/** All verifications issued by trusted verifiers on behalf of this user. Verifications by untrusted verifiers are not included. */        @SerialName("verifications")
        val verifications: List<Verificationview>,/** The user's status as a verified account. */        @SerialName("verifiedStatus")
        val verifiedStatus: String,/** The user's status as a trusted verifier. */        @SerialName("trustedVerifierStatus")
        val trustedVerifierStatus: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#verificationstate"
        }
    }

    /**
     * An individual verification for an associated subject.
     */
    @Serializable
    data class Verificationview(
/** The user who issued this verification. */        @SerialName("issuer")
        val issuer: DID,/** The AT-URI of the verification record. */        @SerialName("uri")
        val uri: ATProtocolURI,/** True if the verification passes validation, otherwise false. */        @SerialName("isValid")
        val isValid: Boolean,/** Timestamp when the verification was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#verificationview"
        }
    }

    @Serializable
    data class Adultcontentpref(
        @SerialName("enabled")
        val enabled: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#adultcontentpref"
        }
    }

    @Serializable
    data class Contentlabelpref(
/** Which labeler does this preference apply to? If undefined, applies globally. */        @SerialName("labelerDid")
        val labelerDid: DID?,        @SerialName("label")
        val label: String,        @SerialName("visibility")
        val visibility: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#contentlabelpref"
        }
    }

    @Serializable
    data class Savedfeed(
        @SerialName("id")
        val id: String,        @SerialName("type")
        val type: String,        @SerialName("value")
        val value: String,        @SerialName("pinned")
        val pinned: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#savedfeed"
        }
    }

    @Serializable
    data class Savedfeedsprefv2(
        @SerialName("items")
        val items: List<AppBskyActorDefs.Savedfeed>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#savedfeedsprefv2"
        }
    }

    @Serializable
    data class Savedfeedspref(
        @SerialName("pinned")
        val pinned: List<ATProtocolURI>,        @SerialName("saved")
        val saved: List<ATProtocolURI>,        @SerialName("timelineIndex")
        val timelineIndex: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#savedfeedspref"
        }
    }

    @Serializable
    data class Personaldetailspref(
/** The birth date of account owner. */        @SerialName("birthDate")
        val birthDate: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#personaldetailspref"
        }
    }

    @Serializable
    data class Feedviewpref(
/** The URI of the feed, or an identifier which describes the feed. */        @SerialName("feed")
        val feed: String,/** Hide replies in the feed. */        @SerialName("hideReplies")
        val hideReplies: Boolean?,/** Hide replies in the feed if they are not by followed users. */        @SerialName("hideRepliesByUnfollowed")
        val hideRepliesByUnfollowed: Boolean?,/** Hide replies in the feed if they do not have this number of likes. */        @SerialName("hideRepliesByLikeCount")
        val hideRepliesByLikeCount: Int?,/** Hide reposts in the feed. */        @SerialName("hideReposts")
        val hideReposts: Boolean?,/** Hide quote posts in the feed. */        @SerialName("hideQuotePosts")
        val hideQuotePosts: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#feedviewpref"
        }
    }

    @Serializable
    data class Threadviewpref(
/** Sorting mode for threads. */        @SerialName("sort")
        val sort: String?,/** Show followed users at the top of all replies. */        @SerialName("prioritizeFollowedUsers")
        val prioritizeFollowedUsers: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threadviewpref"
        }
    }

    @Serializable
    data class Interestspref(
/** A list of tags which describe the account owner's interests gathered during onboarding. */        @SerialName("tags")
        val tags: List<String>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#interestspref"
        }
    }

    /**
     * A word that the account owner has muted.
     */
    @Serializable
    data class Mutedword(
        @SerialName("id")
        val id: String?,/** The muted word itself. */        @SerialName("value")
        val value: String,/** The intended targets of the muted word. */        @SerialName("targets")
        val targets: List<AppBskyActorDefs.Mutedwordtarget>,/** Groups of users to apply the muted word to. If undefined, applies to all users. */        @SerialName("actorTarget")
        val actorTarget: String?,/** The date and time at which the muted word will expire and no longer be applied. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#mutedword"
        }
    }

    @Serializable
    data class Mutedwordspref(
/** A list of words the account owner has muted. */        @SerialName("items")
        val items: List<AppBskyActorDefs.Mutedword>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#mutedwordspref"
        }
    }

    @Serializable
    data class Hiddenpostspref(
/** A list of URIs of posts the account owner has hidden. */        @SerialName("items")
        val items: List<ATProtocolURI>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#hiddenpostspref"
        }
    }

    @Serializable
    data class Labelerspref(
        @SerialName("labelers")
        val labelers: List<Labelerprefitem>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#labelerspref"
        }
    }

    @Serializable
    data class Labelerprefitem(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#labelerprefitem"
        }
    }

    /**
     * A grab bag of state that's specific to the bsky.app program. Third-party apps shouldn't use this.
     */
    @Serializable
    data class Bskyappstatepref(
        @SerialName("activeProgressGuide")
        val activeProgressGuide: Bskyappprogressguide?,/** An array of tokens which identify nudges (modals, popups, tours, highlight dots) that should be shown to the user. */        @SerialName("queuedNudges")
        val queuedNudges: List<String>?,/** Storage for NUXs the user has encountered. */        @SerialName("nuxs")
        val nuxs: List<AppBskyActorDefs.Nux>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#bskyappstatepref"
        }
    }

    /**
     * If set, an active progress guide. Once completed, can be set to undefined. Should have unspecced fields tracking progress.
     */
    @Serializable
    data class Bskyappprogressguide(
        @SerialName("guide")
        val guide: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#bskyappprogressguide"
        }
    }

    /**
     * A new user experiences (NUX) storage object
     */
    @Serializable
    data class Nux(
        @SerialName("id")
        val id: String,        @SerialName("completed")
        val completed: Boolean,/** Arbitrary data for the NUX. The structure is defined by the NUX itself. Limited to 300 characters. */        @SerialName("data")
        val `data`: String?,/** The date and time at which the NUX will expire and should be considered completed. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#nux"
        }
    }

    /**
     * Preferences for how verified accounts appear in the app.
     */
    @Serializable
    data class Verificationprefs(
/** Hide the blue check badges for verified accounts and trusted verifiers. */        @SerialName("hideBadges")
        val hideBadges: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#verificationprefs"
        }
    }

    /**
     * Default post interaction settings for the account. These values should be applied as default values when creating new posts. These refs should mirror the threadgate and postgate records exactly.
     */
    @Serializable
    data class Postinteractionsettingspref(
/** Matches threadgate record. List of rules defining who can reply to this users posts. If value is an empty array, no one can reply. If value is undefined, anyone can reply. */        @SerialName("threadgateAllowRules")
        val threadgateAllowRules: List<PostinteractionsettingsprefThreadgateallowrulesUnion>?,/** Matches postgate record. List of rules defining who can embed this users posts. If value is an empty array or is undefined, no particular rules apply and anyone can embed. */        @SerialName("postgateEmbeddingRules")
        val postgateEmbeddingRules: List<PostinteractionsettingsprefPostgateembeddingrulesUnion>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#postinteractionsettingspref"
        }
    }

    @Serializable
    data class Statusview(
/** The status for the account. */        @SerialName("status")
        val status: String,        @SerialName("record")
        val record: JsonElement,/** An optional embed associated with the status. */        @SerialName("embed")
        val embed: StatusviewEmbedUnion?,/** The date when this status will expire. The application might choose to no longer return the status after expiration. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate?,/** True if the status is not expired, false if it is expired. Only present if expiration was set. */        @SerialName("isActive")
        val isActive: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#statusview"
        }
    }

}
