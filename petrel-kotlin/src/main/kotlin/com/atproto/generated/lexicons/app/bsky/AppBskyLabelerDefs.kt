// Lexicon: 1, ID: app.bsky.labeler.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyLabelerDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.defs"
}

    @Serializable
    data class AppBskyLabelerDefsLabelerView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("creator")
        val creator: AppBskyActorDefsProfileView,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("viewer")
        val viewer: AppBskyLabelerDefsLabelerViewerState?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyLabelerDefsLabelerView"
        }
    }

    @Serializable
    data class AppBskyLabelerDefsLabelerViewDetailed(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("creator")
        val creator: AppBskyActorDefsProfileView,        @SerialName("policies")
        val policies: AppBskyLabelerDefsLabelerPolicies,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("viewer")
        val viewer: AppBskyLabelerDefsLabelerViewerState?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,/** The set of report reason 'codes' which are in-scope for this service to review and action. These usually align to policy categories. If not defined (distinct from empty array), all reason types are allowed. */        @SerialName("reasonTypes")
        val reasonTypes: List<ComAtprotoModerationDefsReasonType>?,/** The set of subject types (account, record, etc) this service accepts reports on. */        @SerialName("subjectTypes")
        val subjectTypes: List<ComAtprotoModerationDefsSubjectType>?,/** Set of record types (collection NSIDs) which can be reported to this service. If not defined (distinct from empty array), default is any record type. */        @SerialName("subjectCollections")
        val subjectCollections: List<NSID>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyLabelerDefsLabelerViewDetailed"
        }
    }

    @Serializable
    data class AppBskyLabelerDefsLabelerViewerState(
        @SerialName("like")
        val like: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyLabelerDefsLabelerViewerState"
        }
    }

    @Serializable
    data class AppBskyLabelerDefsLabelerPolicies(
/** The label values which this labeler publishes. May include global or custom labels. */        @SerialName("labelValues")
        val labelValues: List<ComAtprotoLabelDefsLabelValue>,/** Label values created by this labeler and scoped exclusively to it. Labels defined here will override global label definitions for this labeler. */        @SerialName("labelValueDefinitions")
        val labelValueDefinitions: List<ComAtprotoLabelDefsLabelValueDefinition>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyLabelerDefsLabelerPolicies"
        }
    }
