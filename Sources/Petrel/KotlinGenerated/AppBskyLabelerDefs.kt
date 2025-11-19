// Lexicon: 1, ID: app.bsky.labeler.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyLabelerDefs {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.defs"

        @Serializable
    data class Labelerview(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("creator")
        val creator: AppBskyActorDefs.Profileview,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("viewer")
        val viewer: Labelerviewerstate?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#labelerview"
        }
    }

    @Serializable
    data class Labelerviewdetailed(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("creator")
        val creator: AppBskyActorDefs.Profileview,        @SerialName("policies")
        val policies: AppBskyLabelerDefs.Labelerpolicies,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("viewer")
        val viewer: Labelerviewerstate?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,/** The set of report reason 'codes' which are in-scope for this service to review and action. These usually align to policy categories. If not defined (distinct from empty array), all reason types are allowed. */        @SerialName("reasonTypes")
        val reasonTypes: List<ComAtprotoModerationDefs.Reasontype>?,/** The set of subject types (account, record, etc) this service accepts reports on. */        @SerialName("subjectTypes")
        val subjectTypes: List<ComAtprotoModerationDefs.Subjecttype>?,/** Set of record types (collection NSIDs) which can be reported to this service. If not defined (distinct from empty array), default is any record type. */        @SerialName("subjectCollections")
        val subjectCollections: List<NSID>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#labelerviewdetailed"
        }
    }

    @Serializable
    data class Labelerviewerstate(
        @SerialName("like")
        val like: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#labelerviewerstate"
        }
    }

    @Serializable
    data class Labelerpolicies(
/** The label values which this labeler publishes. May include global or custom labels. */        @SerialName("labelValues")
        val labelValues: List<ComAtprotoLabelDefs.Labelvalue>,/** Label values created by this labeler and scoped exclusively to it. Labels defined here will override global label definitions for this labeler. */        @SerialName("labelValueDefinitions")
        val labelValueDefinitions: List<ComAtprotoLabelDefs.Labelvaluedefinition>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#labelerpolicies"
        }
    }

}
