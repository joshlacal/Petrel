// Lexicon: 1, ID: app.bsky.actor.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.defs"
}

@Serializable
sealed interface AppBskyActorDefsPreferencesPreferencesUnion {
    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsAdultContentPref")
    data class AppBskyActorDefsAdultContentPref(val value: AppBskyActorDefsAdultContentPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsContentLabelPref")
    data class AppBskyActorDefsContentLabelPref(val value: AppBskyActorDefsContentLabelPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsSavedFeedsPref")
    data class AppBskyActorDefsSavedFeedsPref(val value: AppBskyActorDefsSavedFeedsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsSavedFeedsPrefV2")
    data class AppBskyActorDefsSavedFeedsPrefV2(val value: AppBskyActorDefsSavedFeedsPrefV2) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsPersonalDetailsPref")
    data class AppBskyActorDefsPersonalDetailsPref(val value: AppBskyActorDefsPersonalDetailsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsFeedViewPref")
    data class AppBskyActorDefsFeedViewPref(val value: AppBskyActorDefsFeedViewPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsThreadViewPref")
    data class AppBskyActorDefsThreadViewPref(val value: AppBskyActorDefsThreadViewPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsInterestsPref")
    data class AppBskyActorDefsInterestsPref(val value: AppBskyActorDefsInterestsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsMutedWordsPref")
    data class AppBskyActorDefsMutedWordsPref(val value: AppBskyActorDefsMutedWordsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsHiddenPostsPref")
    data class AppBskyActorDefsHiddenPostsPref(val value: AppBskyActorDefsHiddenPostsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsBskyAppStatePref")
    data class AppBskyActorDefsBskyAppStatePref(val value: AppBskyActorDefsBskyAppStatePref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsLabelersPref")
    data class AppBskyActorDefsLabelersPref(val value: AppBskyActorDefsLabelersPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsPostInteractionSettingsPref")
    data class AppBskyActorDefsPostInteractionSettingsPref(val value: AppBskyActorDefsPostInteractionSettingsPref) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsVerificationPrefs")
    data class AppBskyActorDefsVerificationPrefs(val value: AppBskyActorDefsVerificationPrefs) : AppBskyActorDefsPreferencesPreferencesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPreferencesPreferencesUnion
}

@Serializable
sealed interface AppBskyActorDefsPreferencesUnion {
    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsAdultContentPref")
    data class AppBskyActorDefsAdultContentPref(val value: AppBskyActorDefsAdultContentPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsContentLabelPref")
    data class AppBskyActorDefsContentLabelPref(val value: AppBskyActorDefsContentLabelPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsSavedFeedsPref")
    data class AppBskyActorDefsSavedFeedsPref(val value: AppBskyActorDefsSavedFeedsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsSavedFeedsPrefV2")
    data class AppBskyActorDefsSavedFeedsPrefV2(val value: AppBskyActorDefsSavedFeedsPrefV2) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsPersonalDetailsPref")
    data class AppBskyActorDefsPersonalDetailsPref(val value: AppBskyActorDefsPersonalDetailsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsFeedViewPref")
    data class AppBskyActorDefsFeedViewPref(val value: AppBskyActorDefsFeedViewPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsThreadViewPref")
    data class AppBskyActorDefsThreadViewPref(val value: AppBskyActorDefsThreadViewPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsInterestsPref")
    data class AppBskyActorDefsInterestsPref(val value: AppBskyActorDefsInterestsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsMutedWordsPref")
    data class AppBskyActorDefsMutedWordsPref(val value: AppBskyActorDefsMutedWordsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsHiddenPostsPref")
    data class AppBskyActorDefsHiddenPostsPref(val value: AppBskyActorDefsHiddenPostsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsBskyAppStatePref")
    data class AppBskyActorDefsBskyAppStatePref(val value: AppBskyActorDefsBskyAppStatePref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsLabelersPref")
    data class AppBskyActorDefsLabelersPref(val value: AppBskyActorDefsLabelersPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsPostInteractionSettingsPref")
    data class AppBskyActorDefsPostInteractionSettingsPref(val value: AppBskyActorDefsPostInteractionSettingsPref) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyActorDefsVerificationPrefs")
    data class AppBskyActorDefsVerificationPrefs(val value: AppBskyActorDefsVerificationPrefs) : AppBskyActorDefsPreferencesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPreferencesUnion
}

@Serializable
sealed interface AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion {
    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyFeedThreadgateMentionRule")
    data class AppBskyFeedThreadgateMentionRule(val value: AppBskyFeedThreadgateMentionRule) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyFeedThreadgateFollowerRule")
    data class AppBskyFeedThreadgateFollowerRule(val value: AppBskyFeedThreadgateFollowerRule) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyFeedThreadgateFollowingRule")
    data class AppBskyFeedThreadgateFollowingRule(val value: AppBskyFeedThreadgateFollowingRule) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion

    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyFeedThreadgateListRule")
    data class AppBskyFeedThreadgateListRule(val value: AppBskyFeedThreadgateListRule) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion
}

@Serializable
sealed interface AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion {
    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyFeedPostgateDisableRule")
    data class AppBskyFeedPostgateDisableRule(val value: AppBskyFeedPostgateDisableRule) : AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion
}

@Serializable
sealed interface AppBskyActorDefsStatusViewEmbedUnion {
    @Serializable
    @SerialName("app.bsky.actor.defs#AppBskyEmbedExternalView")
    data class AppBskyEmbedExternalView(val value: AppBskyEmbedExternalView) : AppBskyActorDefsStatusViewEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyActorDefsStatusViewEmbedUnion
}

@Serializable
enum class AppBskyActorDefsMutedWordTarget {
    @SerialName("content")
    CONTENT,
    @SerialName("tag")
    TAG}

    @Serializable
    data class AppBskyActorDefsProfileViewBasic(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String?,        @SerialName("pronouns")
        val pronouns: String?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("associated")
        val associated: AppBskyActorDefsProfileAssociated?,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState?,        @SerialName("status")
        val status: AppBskyActorDefsStatusView?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileViewBasic"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileView(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("displayName")
        val displayName: String?,        @SerialName("pronouns")
        val pronouns: String?,        @SerialName("description")
        val description: String?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("associated")
        val associated: AppBskyActorDefsProfileAssociated?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate?,        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState?,        @SerialName("status")
        val status: AppBskyActorDefsStatusView?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileView"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileViewDetailed(
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
        val associated: AppBskyActorDefsProfileAssociated?,        @SerialName("joinedViaStarterPack")
        val joinedViaStarterPack: AppBskyGraphDefsStarterPackViewBasic?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate?,        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("pinnedPost")
        val pinnedPost: ComAtprotoRepoStrongRef?,        @SerialName("verification")
        val verification: AppBskyActorDefsVerificationState?,        @SerialName("status")
        val status: AppBskyActorDefsStatusView?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileViewDetailed"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileAssociated(
        @SerialName("lists")
        val lists: Int?,        @SerialName("feedgens")
        val feedgens: Int?,        @SerialName("starterPacks")
        val starterPacks: Int?,        @SerialName("labeler")
        val labeler: Boolean?,        @SerialName("chat")
        val chat: AppBskyActorDefsProfileAssociatedChat?,        @SerialName("activitySubscription")
        val activitySubscription: AppBskyActorDefsProfileAssociatedActivitySubscription?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileAssociated"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileAssociatedChat(
        @SerialName("allowIncoming")
        val allowIncoming: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileAssociatedChat"
        }
    }

    @Serializable
    data class AppBskyActorDefsProfileAssociatedActivitySubscription(
        @SerialName("allowSubscriptions")
        val allowSubscriptions: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsProfileAssociatedActivitySubscription"
        }
    }

    /**
     * Metadata about the requesting account's relationship with the subject account. Only has meaningful content for authed requests.
     */
    @Serializable
    data class AppBskyActorDefsViewerState(
        @SerialName("muted")
        val muted: Boolean?,        @SerialName("mutedByList")
        val mutedByList: AppBskyGraphDefsListViewBasic?,        @SerialName("blockedBy")
        val blockedBy: Boolean?,        @SerialName("blocking")
        val blocking: ATProtocolURI?,        @SerialName("blockingByList")
        val blockingByList: AppBskyGraphDefsListViewBasic?,        @SerialName("following")
        val following: ATProtocolURI?,        @SerialName("followedBy")
        val followedBy: ATProtocolURI?,/** This property is present only in selected cases, as an optimization. */        @SerialName("knownFollowers")
        val knownFollowers: AppBskyActorDefsKnownFollowers?,/** This property is present only in selected cases, as an optimization. */        @SerialName("activitySubscription")
        val activitySubscription: AppBskyNotificationDefsActivitySubscription?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsViewerState"
        }
    }

    /**
     * The subject's followers whom you also follow
     */
    @Serializable
    data class AppBskyActorDefsKnownFollowers(
        @SerialName("count")
        val count: Int,        @SerialName("followers")
        val followers: List<AppBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsKnownFollowers"
        }
    }

    /**
     * Represents the verification information about the user this object is attached to.
     */
    @Serializable
    data class AppBskyActorDefsVerificationState(
/** All verifications issued by trusted verifiers on behalf of this user. Verifications by untrusted verifiers are not included. */        @SerialName("verifications")
        val verifications: List<AppBskyActorDefsVerificationView>,/** The user's status as a verified account. */        @SerialName("verifiedStatus")
        val verifiedStatus: String,/** The user's status as a trusted verifier. */        @SerialName("trustedVerifierStatus")
        val trustedVerifierStatus: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsVerificationState"
        }
    }

    /**
     * An individual verification for an associated subject.
     */
    @Serializable
    data class AppBskyActorDefsVerificationView(
/** The user who issued this verification. */        @SerialName("issuer")
        val issuer: DID,/** The AT-URI of the verification record. */        @SerialName("uri")
        val uri: ATProtocolURI,/** True if the verification passes validation, otherwise false. */        @SerialName("isValid")
        val isValid: Boolean,/** Timestamp when the verification was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsVerificationView"
        }
    }

    typealias AppBskyActorDefsPreferences = List<AppBskyActorDefsPreferencesPreferencesUnion>

    @Serializable
    data class AppBskyActorDefsAdultContentPref(
        @SerialName("enabled")
        val enabled: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsAdultContentPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsContentLabelPref(
/** Which labeler does this preference apply to? If undefined, applies globally. */        @SerialName("labelerDid")
        val labelerDid: DID?,        @SerialName("label")
        val label: String,        @SerialName("visibility")
        val visibility: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsContentLabelPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsSavedFeed(
        @SerialName("id")
        val id: String,        @SerialName("type")
        val type: String,        @SerialName("value")
        val value: String,        @SerialName("pinned")
        val pinned: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsSavedFeed"
        }
    }

    @Serializable
    data class AppBskyActorDefsSavedFeedsPrefV2(
        @SerialName("items")
        val items: List<AppBskyActorDefsSavedFeed>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsSavedFeedsPrefV2"
        }
    }

    @Serializable
    data class AppBskyActorDefsSavedFeedsPref(
        @SerialName("pinned")
        val pinned: List<ATProtocolURI>,        @SerialName("saved")
        val saved: List<ATProtocolURI>,        @SerialName("timelineIndex")
        val timelineIndex: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsSavedFeedsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsPersonalDetailsPref(
/** The birth date of account owner. */        @SerialName("birthDate")
        val birthDate: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsPersonalDetailsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsFeedViewPref(
/** The URI of the feed, or an identifier which describes the feed. */        @SerialName("feed")
        val feed: String,/** Hide replies in the feed. */        @SerialName("hideReplies")
        val hideReplies: Boolean?,/** Hide replies in the feed if they are not by followed users. */        @SerialName("hideRepliesByUnfollowed")
        val hideRepliesByUnfollowed: Boolean?,/** Hide replies in the feed if they do not have this number of likes. */        @SerialName("hideRepliesByLikeCount")
        val hideRepliesByLikeCount: Int?,/** Hide reposts in the feed. */        @SerialName("hideReposts")
        val hideReposts: Boolean?,/** Hide quote posts in the feed. */        @SerialName("hideQuotePosts")
        val hideQuotePosts: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsFeedViewPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsThreadViewPref(
/** Sorting mode for threads. */        @SerialName("sort")
        val sort: String?,/** Show followed users at the top of all replies. */        @SerialName("prioritizeFollowedUsers")
        val prioritizeFollowedUsers: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsThreadViewPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsInterestsPref(
/** A list of tags which describe the account owner's interests gathered during onboarding. */        @SerialName("tags")
        val tags: List<String>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsInterestsPref"
        }
    }

    /**
     * A word that the account owner has muted.
     */
    @Serializable
    data class AppBskyActorDefsMutedWord(
        @SerialName("id")
        val id: String?,/** The muted word itself. */        @SerialName("value")
        val value: String,/** The intended targets of the muted word. */        @SerialName("targets")
        val targets: List<AppBskyActorDefsMutedWordTarget>,/** Groups of users to apply the muted word to. If undefined, applies to all users. */        @SerialName("actorTarget")
        val actorTarget: String?,/** The date and time at which the muted word will expire and no longer be applied. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsMutedWord"
        }
    }

    @Serializable
    data class AppBskyActorDefsMutedWordsPref(
/** A list of words the account owner has muted. */        @SerialName("items")
        val items: List<AppBskyActorDefsMutedWord>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsMutedWordsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsHiddenPostsPref(
/** A list of URIs of posts the account owner has hidden. */        @SerialName("items")
        val items: List<ATProtocolURI>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsHiddenPostsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsLabelersPref(
        @SerialName("labelers")
        val labelers: List<AppBskyActorDefsLabelerPrefItem>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsLabelersPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsLabelerPrefItem(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsLabelerPrefItem"
        }
    }

    /**
     * A grab bag of state that's specific to the bsky.app program. Third-party apps shouldn't use this.
     */
    @Serializable
    data class AppBskyActorDefsBskyAppStatePref(
        @SerialName("activeProgressGuide")
        val activeProgressGuide: AppBskyActorDefsBskyAppProgressGuide?,/** An array of tokens which identify nudges (modals, popups, tours, highlight dots) that should be shown to the user. */        @SerialName("queuedNudges")
        val queuedNudges: List<String>?,/** Storage for NUXs the user has encountered. */        @SerialName("nuxs")
        val nuxs: List<AppBskyActorDefsNux>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsBskyAppStatePref"
        }
    }

    /**
     * If set, an active progress guide. Once completed, can be set to undefined. Should have unspecced fields tracking progress.
     */
    @Serializable
    data class AppBskyActorDefsBskyAppProgressGuide(
        @SerialName("guide")
        val guide: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsBskyAppProgressGuide"
        }
    }

    /**
     * A new user experiences (NUX) storage object
     */
    @Serializable
    data class AppBskyActorDefsNux(
        @SerialName("id")
        val id: String,        @SerialName("completed")
        val completed: Boolean,/** Arbitrary data for the NUX. The structure is defined by the NUX itself. Limited to 300 characters. */        @SerialName("data")
        val `data`: String?,/** The date and time at which the NUX will expire and should be considered completed. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsNux"
        }
    }

    /**
     * Preferences for how verified accounts appear in the app.
     */
    @Serializable
    data class AppBskyActorDefsVerificationPrefs(
/** Hide the blue check badges for verified accounts and trusted verifiers. */        @SerialName("hideBadges")
        val hideBadges: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsVerificationPrefs"
        }
    }

    /**
     * Default post interaction settings for the account. These values should be applied as default values when creating new posts. These refs should mirror the threadgate and postgate records exactly.
     */
    @Serializable
    data class AppBskyActorDefsPostInteractionSettingsPref(
/** Matches threadgate record. List of rules defining who can reply to this users posts. If value is an empty array, no one can reply. If value is undefined, anyone can reply. */        @SerialName("threadgateAllowRules")
        val threadgateAllowRules: List<AppBskyActorDefsPostInteractionSettingsPrefThreadgateAllowRulesUnion>?,/** Matches postgate record. List of rules defining who can embed this users posts. If value is an empty array or is undefined, no particular rules apply and anyone can embed. */        @SerialName("postgateEmbeddingRules")
        val postgateEmbeddingRules: List<AppBskyActorDefsPostInteractionSettingsPrefPostgateEmbeddingRulesUnion>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsPostInteractionSettingsPref"
        }
    }

    @Serializable
    data class AppBskyActorDefsStatusView(
/** The status for the account. */        @SerialName("status")
        val status: String,        @SerialName("record")
        val record: JsonElement,/** An optional embed associated with the status. */        @SerialName("embed")
        val embed: AppBskyActorDefsStatusViewEmbedUnion?,/** The date when this status will expire. The application might choose to no longer return the status after expiration. */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate?,/** True if the status is not expired, false if it is expired. Only present if expiration was set. */        @SerialName("isActive")
        val isActive: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyActorDefsStatusView"
        }
    }
