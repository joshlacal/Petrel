// Lexicon: 1, ID: app.bsky.labeler.service
// A declaration of the existence of labeler service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface AppBskyLabelerServiceLabelsUnion {
    @Serializable
    @SerialName("ComAtprotoLabelDefs.Selflabels")
    data class Selflabels(val value: ComAtprotoLabelDefs.Selflabels) : AppBskyLabelerServiceLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyLabelerServiceLabelsUnion
}

object AppBskyLabelerService {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.service"

        /**
     * A declaration of the existence of labeler service.
     */
    @Serializable
    data class Record(
        @SerialName("policies")
        val policies: AppBskyLabelerDefs.Labelerpolicies,        @SerialName("labels")
        val labels: AppBskyLabelerServiceLabelsUnion? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The set of report reason 'codes' which are in-scope for this service to review and action. These usually align to policy categories. If not defined (distinct from empty array), all reason types are allowed. */        @SerialName("reasonTypes")
        val reasonTypes: List<ComAtprotoModerationDefs.Reasontype>? = null,/** The set of subject types (account, record, etc) this service accepts reports on. */        @SerialName("subjectTypes")
        val subjectTypes: List<ComAtprotoModerationDefs.Subjecttype>? = null,/** Set of record types (collection NSIDs) which can be reported to this service. If not defined (distinct from empty array), default is any record type. */        @SerialName("subjectCollections")
        val subjectCollections: List<NSID>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
