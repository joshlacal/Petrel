// Lexicon: 1, ID: app.bsky.labeler.service
// A declaration of the existence of labeler service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyLabelerServiceDefs {
    const val TYPE_IDENTIFIER = "app.bsky.labeler.service"
}

@Serializable
sealed interface AppBskyLabelerServiceLabelsUnion {
    @Serializable
    @SerialName("app.bsky.labeler.service#ComAtprotoLabelDefsSelfLabels")
    data class ComAtprotoLabelDefsSelfLabels(val value: ComAtprotoLabelDefsSelfLabels) : AppBskyLabelerServiceLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyLabelerServiceLabelsUnion
}

    /**
     * A declaration of the existence of labeler service.
     */
    @Serializable
    data class AppBskyLabelerService(
        @SerialName("policies")
        val policies: AppBskyLabelerDefsLabelerPolicies,        @SerialName("labels")
        val labels: AppBskyLabelerServiceLabelsUnion? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The set of report reason 'codes' which are in-scope for this service to review and action. These usually align to policy categories. If not defined (distinct from empty array), all reason types are allowed. */        @SerialName("reasonTypes")
        val reasonTypes: List<ComAtprotoModerationDefsReasonType>? = null,/** The set of subject types (account, record, etc) this service accepts reports on. */        @SerialName("subjectTypes")
        val subjectTypes: List<ComAtprotoModerationDefsSubjectType>? = null,/** Set of record types (collection NSIDs) which can be reported to this service. If not defined (distinct from empty array), default is any record type. */        @SerialName("subjectCollections")
        val subjectCollections: List<NSID>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
