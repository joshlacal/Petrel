// Lexicon: 1, ID: app.bsky.graph.list
// Record representing a list of accounts (actors). Scope includes both moderation-oriented lists and curration-oriented lists.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface AppBskyGraphListLabelsUnion {
    @Serializable
    @SerialName("ComAtprotoLabelDefs.Selflabels")
    data class Selflabels(val value: ComAtprotoLabelDefs.Selflabels) : AppBskyGraphListLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyGraphListLabelsUnion
}

object AppBskyGraphList {
    const val TYPE_IDENTIFIER = "app.bsky.graph.list"

        /**
     * Record representing a list of accounts (actors). Scope includes both moderation-oriented lists and curration-oriented lists.
     */
    @Serializable
    data class Record(
/** Defines the purpose of the list (aka, moderation-oriented or curration-oriented) */        @SerialName("purpose")
        val purpose: AppBskyGraphDefs.Listpurpose,/** Display name for list; can not be empty. */        @SerialName("name")
        val name: String,        @SerialName("description")
        val description: String? = null,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>? = null,        @SerialName("avatar")
        val avatar: Blob? = null,        @SerialName("labels")
        val labels: AppBskyGraphListLabelsUnion? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
