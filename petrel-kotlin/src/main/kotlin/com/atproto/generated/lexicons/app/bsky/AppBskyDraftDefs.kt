// Lexicon: 1, ID: app.bsky.draft.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyDraftDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.draft.defs"
}

@Serializable
sealed interface AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion {
    @Serializable
    @SerialName("app.bsky.draft.defs#AppBskyFeedPostgateDisableRule")
    data class AppBskyFeedPostgateDisableRule(val value: AppBskyFeedPostgateDisableRule) : AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion
}

@Serializable
sealed interface AppBskyDraftDefsDraftThreadgateAllowUnion {
    @Serializable
    @SerialName("app.bsky.draft.defs#AppBskyFeedThreadgateMentionRule")
    data class AppBskyFeedThreadgateMentionRule(val value: AppBskyFeedThreadgateMentionRule) : AppBskyDraftDefsDraftThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.draft.defs#AppBskyFeedThreadgateFollowerRule")
    data class AppBskyFeedThreadgateFollowerRule(val value: AppBskyFeedThreadgateFollowerRule) : AppBskyDraftDefsDraftThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.draft.defs#AppBskyFeedThreadgateFollowingRule")
    data class AppBskyFeedThreadgateFollowingRule(val value: AppBskyFeedThreadgateFollowingRule) : AppBskyDraftDefsDraftThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.draft.defs#AppBskyFeedThreadgateListRule")
    data class AppBskyFeedThreadgateListRule(val value: AppBskyFeedThreadgateListRule) : AppBskyDraftDefsDraftThreadgateAllowUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyDraftDefsDraftThreadgateAllowUnion
}

@Serializable
sealed interface AppBskyDraftDefsDraftPostLabelsUnion {
    @Serializable
    @SerialName("app.bsky.draft.defs#ComAtprotoLabelDefsSelfLabels")
    data class ComAtprotoLabelDefsSelfLabels(val value: ComAtprotoLabelDefsSelfLabels) : AppBskyDraftDefsDraftPostLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyDraftDefsDraftPostLabelsUnion
}

    /**
     * A draft with an identifier, used to store drafts in private storage (stash).
     */
    @Serializable
    data class AppBskyDraftDefsDraftWithId(
/** A TID to be used as a draft identifier. */        @SerialName("id")
        val id: String,        @SerialName("draft")
        val draft: AppBskyDraftDefsDraft    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftWithId"
        }
    }

    /**
     * A draft containing an array of draft posts.
     */
    @Serializable
    data class AppBskyDraftDefsDraft(
/** UUIDv4 identifier of the device that created this draft. */        @SerialName("deviceId")
        val deviceId: String?,/** The device and/or platform on which the draft was created. */        @SerialName("deviceName")
        val deviceName: String?,/** Array of draft posts that compose this draft. */        @SerialName("posts")
        val posts: List<AppBskyDraftDefsDraftPost>,/** Indicates human language of posts primary text content. */        @SerialName("langs")
        val langs: List<Language>?,/** Embedding rules for the postgates to be created when this draft is published. */        @SerialName("postgateEmbeddingRules")
        val postgateEmbeddingRules: List<AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion>?,/** Allow-rules for the threadgate to be created when this draft is published. */        @SerialName("threadgateAllow")
        val threadgateAllow: List<AppBskyDraftDefsDraftThreadgateAllowUnion>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraft"
        }
    }

    /**
     * One of the posts that compose a draft.
     */
    @Serializable
    data class AppBskyDraftDefsDraftPost(
/** The primary post content. */        @SerialName("text")
        val text: String,/** Self-label values for this post. Effectively content warnings. */        @SerialName("labels")
        val labels: AppBskyDraftDefsDraftPostLabelsUnion?,        @SerialName("embedImages")
        val embedImages: List<AppBskyDraftDefsDraftEmbedImage>?,        @SerialName("embedVideos")
        val embedVideos: List<AppBskyDraftDefsDraftEmbedVideo>?,        @SerialName("embedExternals")
        val embedExternals: List<AppBskyDraftDefsDraftEmbedExternal>?,        @SerialName("embedRecords")
        val embedRecords: List<AppBskyDraftDefsDraftEmbedRecord>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftPost"
        }
    }

    /**
     * View to present drafts data to users.
     */
    @Serializable
    data class AppBskyDraftDefsDraftView(
/** A TID to be used as a draft identifier. */        @SerialName("id")
        val id: String,        @SerialName("draft")
        val draft: AppBskyDraftDefsDraft,/** The time the draft was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The time the draft was last updated. */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftView"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedLocalRef(
/** Local, on-device ref to file to be embedded. Embeds are currently device-bound for drafts. */        @SerialName("path")
        val path: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedLocalRef"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedCaption(
        @SerialName("lang")
        val lang: Language,        @SerialName("content")
        val content: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedCaption"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedImage(
        @SerialName("localRef")
        val localRef: AppBskyDraftDefsDraftEmbedLocalRef,        @SerialName("alt")
        val alt: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedImage"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedVideo(
        @SerialName("localRef")
        val localRef: AppBskyDraftDefsDraftEmbedLocalRef,        @SerialName("alt")
        val alt: String?,        @SerialName("captions")
        val captions: List<AppBskyDraftDefsDraftEmbedCaption>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedVideo"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedExternal(
        @SerialName("uri")
        val uri: URI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedExternal"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedRecord(
        @SerialName("record")
        val record: ComAtprotoRepoStrongRef    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedRecord"
        }
    }
